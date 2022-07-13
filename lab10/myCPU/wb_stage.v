`include "mycpu.h"

module wb_stage(
    output [31:0]  ws_pc,
    output [13:0]  csr_num_wb   ,
    output [31:0]  ertn_era_wb,
    output [31:0]  eentry_wb,
    output [31:0]  csr_wvalue_wb   ,
    output [31:0]  csr_wmask_wb,
    output csr_we_wb,
    output ertn_flush_wb,
    output wb_ex,
    input [31:0] csr_rvalue_cntid,
    input [31:0] csr_rvalue_eentry,
    output inst_rdcntid_wb,
    //to CSR
    output [31:0] wb_vaddr,
    output [31:0] wb_pc,
    output [5:0]  wb_ecode,
    output [8:0]  wb_esubcode,
    
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //to DATA_RISK_BUS
    output [4 :0] wb_waddr        ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
//CSR
    //wire [13:0]  csr_num_wb   
    //wire [31:0]  csr_wvalue_wb
    //wire [31:0]  csr_wmask_wb
    //wire csr_we_wb
    wire [13:0] csr_num_wb_temp;
    wire [31:0] csr_rvalue_wb;
    wire csr_re_wb;
    wire exec_ADEF;
    wire exec_INE;
    wire exec_ALE;
    wire exec_SYS;
    wire exec_BRK;
    wire exec_INT;
//inst
    wire inst_rdcntid;
//pipeline
reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
reg count_1_wb;
wire        ws_gr_we;
wire        ws_gr_we_temp;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_final_result_temp;
assign wb_pc = ws_pc;
assign wb_ecode = 
                {6{exec_INT }} & `ECODE_INT |
                {6{exec_SYS }} & `ECODE_SYS |            
                {6{exec_BRK }} & `ECODE_BRK |
                {6{exec_ADEF}} & `ECODE_ADE |
                {6{exec_INE }} & `ECODE_INE |
                {6{exec_ALE }} & `ECODE_ALE ;        
assign wb_esubcode = {8{exec_ADEF}} & `ESUBCODE_ADEF;
assign wb_ex = ws_valid & 
                (
                    exec_INT  | exec_SYS  | exec_BRK  |
                    exec_ADEF | exec_INE  | exec_ALE  
                );
assign csr_num_wb = csr_num_wb_temp & {14{ws_valid}};
wire ertn_flush_wb_temp; 
assign ertn_flush_wb = ertn_flush_wb_temp & ws_valid;
wire csr_we_wb_temp;
assign csr_we_wb = csr_we_wb_temp & count_1_wb;
wire [31:0] nextpc_wb;
wire inst_rdcntid_wb_w;
assign {
        nextpc_wb,              //253:222
        inst_rdcntid_wb_w,           //221
        exec_INT,               //220
        csr_wvalue_wb,          //219:188
        csr_rvalue_wb,          //187:156
        ertn_flush_wb_temp,     //155
        csr_wmask_wb,           //154:123
        csr_re_wb,              //122
        csr_we_wb_temp,              //121
        csr_num_wb_temp,        //120:107
        wb_vaddr,               //106:75
        exec_SYS,               //74
        exec_BRK,               //73
        exec_ADEF,              //72
        exec_INE,               //71
        exec_ALE,               //70
        ws_gr_we_temp,          //69
        ws_dest        ,        //68:64
        ws_final_result_temp,        //63:32
        ws_pc                   //31:0
       } = ms_to_ws_bus_r;
reg inst_rdcntid_wb_r;
always @(posedge clk) begin
    if(reset)begin
        inst_rdcntid_wb_r <= 1'b0;
    end
    else begin
        if(inst_rdcntid_wb_w)begin
            inst_rdcntid_wb_r <= 1'b1;
        end
        if(ms_to_ws_valid && ws_allowin)begin
            inst_rdcntid_wb_r <= 1'b0;
        end
    end
end
assign inst_rdcntid_wb = inst_rdcntid_wb_w & ws_valid;
assign ws_gr_we = ws_gr_we_temp & !wb_ex;
assign ws_final_result = {32{inst_rdcntid_wb}} & csr_rvalue_cntid  |
                        {32{!inst_rdcntid_wb}} & ws_final_result_temp;
assign ertn_era_wb = csr_rvalue_wb;
assign eentry_wb = csr_rvalue_eentry;

assign wb_waddr = ws_dest & {5{ws_gr_we}} & {5{ws_valid}};
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
    if (reset) begin    
        ms_to_ws_bus_r <= 70'b0;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
        count_1_wb <= 1'b1;
    end
    else count_1_wb <= 1'b0;
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
