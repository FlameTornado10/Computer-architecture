`include "mycpu.h"

module mem_stage(
    output [13:0] csr_num_mem,
    output csr_we_mem,
    input  clear,
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
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to DATA_RISK_BUS
    output [4                  :0] mem_waddr     ,
    output [31                 :0] mem_mem_result,
    //from data-sram
    input  [31                 :0] data_sram_rdata
);
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
assign mem_ex = (mem_ecode != 6'b0) & ms_valid;


reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        ms_mem_we;
wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign mem_waddr = ms_dest & {5{ms_gr_we || ms_res_from_mem}} & {5{ms_to_ws_valid}};
assign mem_mem_result = ms_final_result;

wire [2:0] ld_code;
wire [1:0] st_code;
wire [1:0] ld_off;
wire [31:0] mem_vaddr;
assign csr_num_mem = csr_num_mem_temp & {14{ms_to_ws_valid}};
assign {
        nextpc_mem,         //262:231
        inst_rdcntid,       //230
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
assign inst_rdcntid_mem = inst_rdcntid & ms_valid;
assign ms_to_ws_bus = {
                        nextpc_mem,         //253:222
                        inst_rdcntid,       //221
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
                        ms_gr_we       ,    //69
                        ms_dest        ,    //68:64
                        ms_final_result,    //63:32
                        ms_pc               //31:0
                      };

assign ms_ready_go    = 1'b1;
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
assign ms_final_result =  {32{csr_re_mem}} & csr_rvalue_mem     |
                          {32{ms_res_from_mem}} & mem_result    |
                          {32{other_situation}} & ms_alu_result;

endmodule
