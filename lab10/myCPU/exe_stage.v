`include "mycpu.h"

module exe_stage(
    input ds_go,
    output es_go,
    output [31:0] es_pc             ,
    output exe_go,
    input [31:0]    csr_rvalue_cntvl,
    input [31:0]    csr_rvalue_cntvh,
    input         mem_ex,
    input         wb_ex,
    input  clear_w,
    input ertn_flush_mem,
    output [13:0] csr_num_exe,
    output csr_we_exe,
    output        exe_ex,
    output [5:0]  exe_ecode,
    output [8:0]  exe_esubcode,
    output inst_rdcntid_exe,

    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to DATA_RISK_BUS
    output [ 4:0] exe_waddr      ,
    output        exe_mem_load     ,
    output [ 4:0] exe_mem_waddr  ,
    output [31:0] exe_wdata ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output          data_sram_req, //
    output          data_sram_wr,  //
    output [1 :0]   data_sram_size,//
    output [3 :0]   data_sram_wstrb,//
    output [31:0]   data_sram_addr,//
    output [31:0]   data_sram_wdata,//
    input           data_sram_addr_ok//
);
wire do_exe;
wire clear;
reg clear_r;
reg es_valid_r;
reg es_to_ms_valid_r;
wire [4:0] exe_mem_waddr_w;
reg [4:0] exe_mem_waddr_r;
wire exe_handshake_w;
wire exe_handshake;
reg exe_handshake_r;
//CSR
    wire [13:0] csr_num_exe_temp;
    wire ertn_flush_exe;
    wire [31:0] csr_wmask_exe;
    wire [31:0] csr_rvalue_exe;
    wire [31:0] csr_rvalue_exe_temp;
    wire [31:0] csr_wvalue_exe;
    wire csr_re_exe_temp;
    wire csr_re_exe;
    wire exec_ADEF;
    wire exec_INE;
    wire exec_ALE;
    wire exec_SYS;
    wire exec_INT;
    wire exec_BRK;
//ld & st code
    wire op_ld_w ;
    wire op_ld_b ;
    wire op_ld_bu;
    wire op_ld_h ;
    wire op_ld_hu;
    wire op_st_b ;    
    wire op_st_h ;
    wire op_st_w ;    
reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [2:0 ] es_mul_div    ;
wire [12:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [1:0] ld_off = data_sram_addr[1:0];
wire        es_res_from_mem;
wire addr_zero = data_sram_addr[1:0] == 2'h0;
wire addr_one = data_sram_addr[1:0] == 2'h1;
wire addr_two = data_sram_addr[1:0] == 2'h2;
wire addr_three = data_sram_addr[1:0] == 2'h3;
wire st_ld_b = op_ld_b | op_ld_bu | op_st_b;
wire st_ld_h = op_ld_h | op_ld_hu | op_st_h;
wire st_ld_w = op_ld_w | op_st_w;
assign data_sram_size = 
            {2{st_ld_w}} & 2'h2 |
            {2{st_ld_h}} & 2'h1 |
            {2{st_ld_b}} & 2'h0; 
assign data_sram_req = data_sram_en & ms_allowin;
assign data_sram_wr = |data_sram_wen;
assign data_sram_wstrb = data_sram_wen;
assign exe_handshake_w = data_sram_en & (data_sram_req & data_sram_addr_ok & !exe_handshake_r || exec_ALE) |
                         !data_sram_en;
assign exe_handshake = exe_handshake_r || exe_handshake_w;
always @(posedge clk) begin
    if(reset)begin
        exe_handshake_r <= 1'b0;
    end
    else begin
        if(exe_handshake_w)
            exe_handshake_r <= 1'b1;
        if(exe_go)
            exe_handshake_r <= 1'b0;
    end
end

always @(posedge clk) begin
    if(reset)begin
        clear_r <= 1'b0;
    end
    else begin
        if(clear_w)begin
            clear_r <= 1'b1;
        end
        if(ds_to_es_valid)begin
            clear_r <= 1'b0;
        end
    end
end
assign clear = clear_r || clear_w;
assign exe_ecode = 
                {6{exec_SYS }} & `ECODE_SYS |            
                {6{exec_BRK }} & `ECODE_BRK |
                {6{exec_ADEF}} & `ECODE_ADE |
                {6{exec_INE }} & `ECODE_INE |
                {6{exec_INT }} & `ECODE_INT |
                {6{exec_ALE }} & `ECODE_ALE ;        
assign exe_esubcode = {8{exec_ADEF}} & `ESUBCODE_ADEF;
assign exe_ex = (exec_SYS   | exec_BRK  | exec_ADEF |
                 exec_INE  | exec_INT | exec_ALE) & es_valid;


assign exe_mem_load = es_res_from_mem;
assign exe_mem_waddr_w = es_dest & {5{es_res_from_mem}} & {5{es_valid || es_valid_r}};
reg ds_go_count;
always @(posedge clk) begin
    if(reset)begin
        exe_mem_waddr_r <= 5'b0;
    end
    if(exe_mem_waddr_w != 5'b0)begin
        exe_mem_waddr_r <= exe_mem_waddr_w;
    end
    if(ds_go)begin
        ds_go_count <= 1'b1;
    end
    else if(ds_go_count)begin
        ds_go_count <= 1'b0;
        exe_mem_waddr_r <= 5'b0;
    end

end
assign exe_mem_waddr = exe_mem_waddr_w;// | exe_mem_waddr_r;
assign exe_waddr = es_dest & {5{es_gr_we}} & {5{es_to_ms_valid}};
wire [31:0] div_result;
wire [2:0] ld_code;
wire [1:0] st_code;
assign csr_num_exe = csr_num_exe_temp & {14{es_to_ms_valid}};
wire inst_rdcntvh_w;
wire inst_rdcntvl_w;
wire [31:0] nextpc_exe;
wire inst_rdcntid;
assign csr_re_cntvl = inst_rdcntvh_w;
assign csr_re_cntvh = inst_rdcntvl_w;
wire inst_rdcntid_exe_w;
assign {
        do_exe,                 //280
        nextpc_exe,             //279:248
        inst_rdcntid_exe_w,     //247
        inst_rdcntvh_w,         //246
        inst_rdcntvl_w,         //245
        exec_INT,               //244
        ertn_flush_exe,         //243
        csr_wmask_exe,          //242:211 
        csr_rvalue_exe_temp,    //210:179
        csr_re_exe_temp,        //178
        csr_we_exe,             //177
        csr_num_exe_temp,       //176:163
        exec_SYS,               //162
        exec_BRK,               //161
        exec_ADEF,              //160
        exec_INE,               //159
        ld_code  ,              //158:156
        st_code  ,              //155:154
        es_mul_div     ,        //153:151
        es_alu_op      ,        //150:138
        es_res_from_mem,        //137:137
        es_src1_is_pc  ,        //136:136
        es_src2_is_imm ,        //135:135
        es_gr_we       ,        //134:134
        es_mem_we      ,        //133:133
        es_dest        ,        //132:128
        es_imm         ,        //127:96
        es_rj_value    ,        //95 :64
        es_rkd_value   ,        //63 :32
        es_pc                   //31 :0
       } = ds_to_es_bus_r;
reg inst_rdcntid_exe_r;
always @(posedge clk) begin
    if(reset)begin
        inst_rdcntid_exe_r <= 1'b0;
    end
    else begin
        if(inst_rdcntid_exe_w)begin
            inst_rdcntid_exe_r <= 1'b1;
        end
        if(es_go)begin
            inst_rdcntid_exe_r <= 1'b0;
        end
    end
end
assign inst_rdcntid_exe = inst_rdcntid_exe_w & es_valid;
//TO NOTE
    assign csr_re_exe = csr_re_exe_temp || inst_rdcntvh_w || inst_rdcntvl_w;
    assign csr_wvalue_exe = es_rkd_value;
    assign csr_rvalue_exe = {32{!inst_rdcntvl_w && !inst_rdcntvh_w}}  & csr_rvalue_exe_temp |
                            {32{inst_rdcntvh_w}}    & csr_rvalue_cntvh  |
                            {32{inst_rdcntvl_w}}    & csr_rvalue_cntvl;
    wire div_w   = (es_mul_div == 3'd4 );
    wire mod_w   = (es_mul_div == 3'd5 );  
    wire div_wu  = (es_mul_div == 3'd6 ); 
    wire mod_wu  = (es_mul_div == 3'd7 );  
    wire sdiv = div_w | mod_w;
    wire udiv = div_wu| mod_wu;
    wire div = div_w  | mod_w | div_wu  | mod_wu;

    wire [31:0] es_alu_src1   ;
    wire [31:0] es_alu_src2   ;
    wire [31:0] es_alu_result ;
    assign exe_wdata =  {32{csr_re_exe}} & csr_rvalue_exe |
                        {32{!csr_re_exe}} &  es_alu_result;//for data risk, maybe csr_rvalue
    wire [31:0] alu_div = div? div_result : es_alu_result;


//assign es_res_from_mem = es_load_op;
wire [31:0] exe_vaddr = es_alu_result;
assign es_to_ms_bus = {
                        nextpc_exe,         //262:231
                        inst_rdcntid_exe_w,       //230
                        exec_INT,           //229
                        csr_rvalue_exe,     //228:197  //rvalue
                        ertn_flush_exe,     //196
                        csr_wmask_exe,      //195:164  
                        csr_wvalue_exe,     //163:132  //wvalue
                        csr_re_exe,         //131
                        csr_we_exe,         //130
                        csr_num_exe_temp,   //129:116
                        exe_vaddr,          //115:84
                        exec_SYS,           //83
                        exec_BRK,           //82
                        exec_ADEF,          //81
                        exec_INE,           //80
                        exec_ALE,           //79
                        ld_off  ,           //78:77
                        ld_code  ,          //76:74
                        st_code  ,          //73:72
                       es_mem_we      ,     //71:71
                       es_res_from_mem,     //70:70
                       es_gr_we       ,     //69:69
                       es_dest        ,     //68:64
                       alu_div        ,     //63:32
                       es_pc                //31:0
                      };    
//DECLARE division
    //handshake
    reg dividend_handshake_r;
    reg divisor_handshake_r;
    reg udividend_handshake_r;
    reg udivisor_handshake_r;     
    //signed div
    wire m_axis_dout_tvalid;
    wire s_axis_divisor_tvalid = !divisor_handshake_r & sdiv;
    wire s_axis_divisor_tready;
    wire s_axis_dividend_tvalid = !dividend_handshake_r & sdiv;
    wire s_axis_dividend_tready;  
    //unsigned div
    wire um_axis_dout_tvalid;
    wire us_axis_divisor_tvalid = !udivisor_handshake_r & udiv;
    wire us_axis_divisor_tready;
    wire us_axis_dividend_tvalid = !udividend_handshake_r & udiv;
    wire us_axis_dividend_tready;
    reg mul_delay;
    reg mul_flag;
    always @(posedge clk) begin
        if(reset)
            mul_flag <= 1'b0;
        else if(es_mul_div == 3'd1 || es_mul_div == 3'd2 || es_mul_div == 3'd3)
            mul_flag <= 1'b1;
        if(exe_go)
            mul_flag <= 1'b0;
    end
always @(posedge clk) begin
    if(reset)begin
        mul_delay <= 1'b0;
    end
    else if((es_mul_div == 3'd1 || es_mul_div == 3'd2 || es_mul_div == 3'd3) & !mul_flag)
        mul_delay <= 1'b1;
    else mul_delay <= 1'b0;
end
assign es_ready_go    = exe_handshake & !mul_delay & 
                      (!div     & 1'b1  |
                        div     & (sdiv & m_axis_dout_tvalid | udiv & um_axis_dout_tvalid)  |
                        clear);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid = !clear && es_valid && es_ready_go;
always @(posedge clk) begin
    if(reset)begin
        es_to_ms_valid_r <= 1'b0;
        es_valid_r <= 1'b0;
    end
    else begin
        if(es_valid)begin
            es_valid_r <= 1'b1;
        end
        if(es_to_ms_valid)begin
            es_to_ms_valid_r <= 1'b1;
        end
        if(es_go)begin
            es_to_ms_valid_r <= 1'b0;
            es_valid_r <= 1'b0;
        end
    end
end
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end
    if (reset) begin
        ds_to_es_bus_r <= 300'b0;
    end
    else if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end
assign es_go = ds_to_es_valid && es_allowin;
assign exe_go = ds_to_es_valid && es_allowin;

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

assign op_ld_w    = (ld_code == 3'b000) & es_res_from_mem;    //load
assign op_ld_b    = (ld_code == 3'b001) & es_res_from_mem;    //load
assign op_ld_bu   = (ld_code == 3'b010) & es_res_from_mem;    //load
assign op_ld_h    = (ld_code == 3'b011) & es_res_from_mem;    //load
assign op_ld_hu   = (ld_code == 3'b100) & es_res_from_mem;    //load
alu u_alu(
    .clk        (clk          ),
    .mul_div    (es_mul_div   ),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

assign op_st_b = (st_code == 2'b01) & es_mem_we;      //store
assign op_st_h = (st_code == 2'b10) & es_mem_we;      //store
assign op_st_w = (st_code == 2'b00) & es_mem_we;      //store
wire [3:0] st_wen_b = 1'b1 << data_sram_addr[1:0];
wire [3:0] st_wen_h = 2'b11<< data_sram_addr[1:0];
wire [3:0] st_wen_w = 4'b1111;
wire [3:0] st_wen = {4{op_st_b}} & st_wen_b |
                    {4{op_st_h}} & st_wen_h |
                    {4{op_st_w}} & st_wen_w ;
//很多情况下要取消对数据SRAM的写或读
//当前mem和wb有异常
//当前访存地址错误
//当前mem是ertn
assign data_sram_en    = (es_res_from_mem || es_mem_we) && es_valid && (!mem_ex && !wb_ex && !ertn_flush_mem || do_exe) && !exec_ALE;
assign data_sram_wen   = es_mem_we ? st_wen : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = {32{op_st_b}} & {4{es_rkd_value[7:0]}}      |
                         {32{op_st_h}} & {2{es_rkd_value[15:0]}}     |
                         {32{op_st_w}} & es_rkd_value                ;
assign exec_ALE =  (es_alu_result[0] != 1'b0) & (op_st_h  | op_ld_h | op_ld_hu) |
                (es_alu_result[1:0]!=2'b0)  & (op_st_w  | op_ld_w );
                 

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
/////////////////////         SPECIAL PART FOR DIVISON      ///////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk) begin
    if(reset)begin
        divisor_handshake_r <= 1'b0;
        dividend_handshake_r <= 1'b0;
    end
    else begin
        if(s_axis_divisor_tready & s_axis_divisor_tvalid)
            divisor_handshake_r <= 1'b1;
        if(exe_go & divisor_handshake_r)
            divisor_handshake_r <= 1'b0;
        if(s_axis_dividend_tready & s_axis_dividend_tvalid)
            dividend_handshake_r <= 1'b1;
        if(exe_go & dividend_handshake_r)
            dividend_handshake_r <= 1'b0;
    end
end
wire [31:0] s_axis_divisor_tdata  = es_alu_src2;
wire [31:0] s_axis_dividend_tdata = es_alu_src1;
wire [63:0] m_axis_dout_tdata;
mydiv_signed your_instance_name (
  .aclk(clk),                                       // input wire aclk
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(s_axis_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(s_axis_divisor_tdata),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(s_axis_dividend_tdata),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata)            // output wire [63 : 0] m_axis_dout_tdata
);
wire [31:0] sdiv_result = {32{div_w}} & m_axis_dout_tdata[63:32]    |
                          {32{mod_w}} & m_axis_dout_tdata[31:0]     ;
/*============================================================================================================*/

always @(posedge clk) begin
    if(reset)begin
        udivisor_handshake_r <= 1'b0;
        udividend_handshake_r <= 1'b0;
    end
    else begin
        if(us_axis_divisor_tready & us_axis_divisor_tvalid)
            udivisor_handshake_r <= 1'b1;
        if(exe_go & udivisor_handshake_r)
            udivisor_handshake_r <= 1'b0;
        if(us_axis_dividend_tready & us_axis_dividend_tvalid)
            udividend_handshake_r <= 1'b1;
        if(exe_go & udividend_handshake_r)
            udividend_handshake_r <= 1'b0;
    end
end
wire [31:0] us_axis_divisor_tdata  = es_alu_src2;
wire [31:0] us_axis_dividend_tdata = es_alu_src1;
wire [63:0] um_axis_dout_tdata;
mydiv_unsigned hello_unsigned (
  .aclk(clk),                                        // input wire aclk
  .s_axis_divisor_tvalid(us_axis_divisor_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(us_axis_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(us_axis_divisor_tdata),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(us_axis_dividend_tvalid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(us_axis_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(us_axis_dividend_tdata),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(um_axis_dout_tvalid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(um_axis_dout_tdata)             // output wire [63 : 0] m_axis_dout_tdata
);
wire [31:0] udiv_result = {32{div_wu}} & um_axis_dout_tdata[63:32]    |
                          {32{mod_wu}} & um_axis_dout_tdata[31:0]     ;

assign div_result = {32{sdiv}} & sdiv_result   |
                    {32{udiv}} & udiv_result   ;

endmodule
