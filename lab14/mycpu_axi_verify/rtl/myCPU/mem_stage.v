`include "mycpu.h"

module mem_stage(
    output [5:0] mem_tlb_op,
    output flag_data_ok_w,
    output ms_go,
    output [31:0] ms_pc,
    output [13:0] csr_num_mem,
    output csr_we_mem,
    input  clear_w,
    output        mem_ex,
    output [5:0]  mem_ecode,
    output [8:0]  mem_esubcode,
    output ertn_flush_mem,
    output inst_rdcntid_mem,
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input                          ertn_flush_wb,//change
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to DATA_RISK_BUS
    output [4                  :0] mem_waddr     ,
    output [31                 :0] mem_mem_result,
    //from data-sram
    input           data_sram_data_ok,
    input  [31:0]   data_sram_rdata
);
wire mem_tlb_reflush;
wire clear;
reg clear_r;
reg flag_data_ok;
assign flag_data_ok_w = flag_data_ok;
reg mem_handshake_r;
wire mem_handshake_w = data_sram_data_ok & !mem_handshake_r || mem_ex||ertn_flush_wb;//change
wire mem_handshake;
wire [31:0] nextpc_mem;
//CSR
    wire [13:0] csr_num_mem_temp;
    wire [31:0] csr_wmask_mem;
    wire [31:0] csr_wvalue_mem;
    wire [31:0] csr_rvalue_mem;
    wire        csr_re_mem;
    wire        exec_ADEF;
    wire        exec_INE;
    wire        exec_ALE;
    wire        exec_SYS;
    wire        exec_BRK;
    wire        exec_INT;
    wire        exec_ADEM;
//inst
    wire inst_rdcntid;
reg         ms_valid;
wire        ms_ready_go;

assign mem_ecode = 
                {6{exec_SYS }} & `ECODE_SYS |            
                {6{exec_BRK }} & `ECODE_BRK |
                {6{exec_ADEF}} & `ECODE_ADE |
                {6{exec_INE }} & `ECODE_INE |
                {6{exec_ALE }} & `ECODE_ALE ;        
assign mem_esubcode = {8{exec_ADEF}} & `ESUBCODE_ADEF;
assign mem_ex = (exec_SYS || exec_BRK || exec_ADEF||exec_ADEM || exec_INE || exec_ALE||exec_INT||
                es_tlb_refill_ex  ||
                es_tlb_st_ex      ||
                es_tlb_ld_ex      ||
                es_tlb_mod_ex     ||
                es_tlb_plv_ex     ||
                fs_tlb_refill_ex  ||
                fs_tlb_insfetch_ex
                ) & ms_valid;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire        ms_mem_we;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
//HANDSHAKE
assign mem_handshake = (ms_res_from_mem || ms_mem_we) & (mem_handshake_w || mem_handshake_r) ||
                      (!ms_res_from_mem && !ms_mem_we);
assign mem_waddr = ms_dest & {5{ms_gr_we || ms_res_from_mem}} & {5{ms_to_ws_valid}};
assign mem_mem_result = ms_final_result;

wire [2:0] ld_code;
wire [1:0] st_code;

always @(posedge clk) begin
    if(reset)begin
        clear_r <= 1'b0;
    end
    else begin
        if(clear_w)begin
            clear_r <= 1'b1;
        end
        if(es_to_ms_valid)begin
            clear_r <= 1'b0;
        end
    end
end
assign clear = clear_r || clear_w;
wire [1:0] ld_off;
wire [31:0] mem_vaddr;
always @(posedge clk) begin
    if(reset)begin
        flag_data_ok <= 1'b0;
    end
    else if(data_sram_data_ok)begin
        flag_data_ok <= 1'b1;
    end
    if(ms_go)begin
        flag_data_ok <= 1'b0;
    end
end
always @(posedge clk) begin
    if(reset)begin
        mem_handshake_r <= 1'b0;
    end
    else begin
        if(mem_handshake_w)begin
            mem_handshake_r <= 1'b1;
        end
        if(ms_ready_go)begin
            mem_handshake_r <= 1'b0;
        end
    end
end
assign csr_num_mem = csr_num_mem_temp & {14{ms_to_ws_valid}};
wire inst_rdcntid_mem_w;
wire mem_tlb_op_5_temp;
assign mem_tlb_op[5] = mem_tlb_op_5_temp & ms_valid;
wire   es_tlb_refill_ex  ;
wire   es_tlb_st_ex      ;
wire   es_tlb_ld_ex      ;
wire   es_tlb_mod_ex     ;
wire   es_tlb_plv_ex     ;
wire   fs_tlb_refill_ex  ;
wire   fs_tlb_insfetch_ex;
wire   fs_tlb_plv_ex     ;   
wire [31:0] mem_mul_result;
wire mem_mul;
assign {
        mem_mul,
        mem_mul_result,
        es_tlb_refill_ex  ,  //277
        es_tlb_st_ex      ,  //276
        es_tlb_ld_ex      ,  //275
        es_tlb_mod_ex     ,  //274
        es_tlb_plv_ex     ,  //273
        fs_tlb_refill_ex  ,  //272
        fs_tlb_insfetch_ex,  //271
        fs_tlb_plv_ex     ,  //270
        mem_tlb_reflush,     //269
        mem_tlb_op_5_temp,
        mem_tlb_op[4:0],     //268:263
        nextpc_mem,          //262:231
        inst_rdcntid_mem_w,  //230
        exec_INT,           //229
        csr_rvalue_mem,     //228:197
        ertn_flush_mem,     //196
        csr_wmask_mem,      //195:164
        csr_wvalue_mem,     //163:132
        csr_re_mem,         //131
        csr_we_mem,         //130
        csr_num_mem_temp,   //129:116
        mem_vaddr,          //115:84
        exec_SYS,           //83
        exec_BRK,           //82
        exec_ADEF,          //81
        exec_INE,           //80
        exec_ALE,           //79
        exec_ADEM,
        ld_off  ,           //78:77
        ld_code  ,          //76:74
        st_code  ,          //73:72
        ms_mem_we      ,    //71:71
        ms_res_from_mem,    //70:70
        ms_gr_we       ,    //69:69
        ms_dest        ,    //68:64
        ms_alu_result  ,    //63:32
        ms_pc               //31:0
       } = es_to_ms_bus_r;
reg inst_rdcntid_mem_r;
always @(posedge clk) begin
    if(reset)begin
        inst_rdcntid_mem_r <= 1'b0;
    end
    else begin
        if(inst_rdcntid_mem_w)begin
            inst_rdcntid_mem_r <= 1'b1;
        end
        if(ms_go)begin
            inst_rdcntid_mem_r <= 1'b0;
        end
    end
end
assign inst_rdcntid_mem = inst_rdcntid_mem_w & ms_valid;
assign ms_to_ws_bus = {
                        es_tlb_refill_ex  ,
                        es_tlb_st_ex      ,
                        es_tlb_ld_ex      ,
                        es_tlb_mod_ex     ,
                        es_tlb_plv_ex     ,
                        fs_tlb_refill_ex  ,
                        fs_tlb_insfetch_ex,
                        fs_tlb_plv_ex     ,
                        mem_tlb_reflush,    //260
                        mem_tlb_op,         //259:254
                        nextpc_mem,         //253:222
                        inst_rdcntid_mem_w,       //221
                        exec_INT,           //220
                        csr_wvalue_mem,     //219:188
                        csr_rvalue_mem,     //187:156
                        ertn_flush_mem,     //155
                        csr_wmask_mem,      //154:123
                        csr_re_mem,         //122
                        csr_we_mem,         //121
                        csr_num_mem_temp,   //120:107
                        mem_vaddr,          //106:75
                        exec_SYS,           //74
                        exec_BRK,           //73
                        exec_ADEF,          //72
                        exec_INE,           //71
                        exec_ALE,           //70
                        exec_ADEM,
                        ms_gr_we       ,    //69
                        ms_dest        ,    //68:64
                        ms_final_result,    //63:32
                        ms_pc               //31:0
                      };

assign ms_ready_go    = 1'b1 & mem_handshake;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid =   !clear && ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (reset) begin    
        es_to_ms_bus_r <= 300'b0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
assign ms_go = es_to_ms_valid && ms_allowin;
wire srdata_sb = data_sram_rdata[7]; 
wire srdata_sh = data_sram_rdata[15]; 
wire ld_w    = (ld_code == 3'b000);
wire ld_b    = (ld_code == 3'b001);
wire ld_bu   = (ld_code == 3'b010);
wire ld_h    = (ld_code == 3'b011);
wire ld_hu   = (ld_code == 3'b100);
wire [7:0] sram_rdata_b   = { 8{ld_off == 2'b00}} & data_sram_rdata[7:0]   |
                            { 8{ld_off == 2'b01}} & data_sram_rdata[15:8]  |
                            { 8{ld_off == 2'b10}} & data_sram_rdata[23:16] |
                            { 8{ld_off == 2'b11}} & data_sram_rdata[31:24] ;
wire [15:0] sram_rdata_h  = {16{ld_off == 2'b00}} & data_sram_rdata[15:0]   |
                            {16{ld_off == 2'b01}} & data_sram_rdata[23:8]  |
                            {16{ld_off == 2'b10}} & data_sram_rdata[31:16] ;

assign mem_result = {32{(ld_w)}}  &  data_sram_rdata    |
                    {32{(ld_b)}}  &  {{24{sram_rdata_b[7]}} , sram_rdata_b}       |
                    {32{(ld_bu)}} &  {        24'b0         , sram_rdata_b}       |
                    {32{(ld_h)}}  &  {{16{sram_rdata_h[15]}}, sram_rdata_h}       |
                    {32{(ld_hu)}} &  {        16'b0         , sram_rdata_h}       ;
wire other_situation = !csr_re_mem && !ms_res_from_mem;
assign ms_final_result =  {32{csr_re_mem}} & csr_rvalue_mem                     |
                          {32{ms_res_from_mem && !mem_mul}} & mem_result        |
                          {32{ms_res_from_mem && mem_mul}} & mem_mul_result     |
                          {32{other_situation}} & ms_alu_result;

endmodule