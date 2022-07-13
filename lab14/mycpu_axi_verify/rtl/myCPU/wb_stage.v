`include "mycpu.h"

module wb_stage#(
    parameter TLBNUM = 16
)(  output fs_tlb_ex,
    output tlb_map_stop,
    output change_da_pg,
    output wb_tlb_reflush,
    output [5:0] wb_tlb_op,
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
    //write port
    output we, //w(rite) e(nable)
    output [$clog2(TLBNUM)-1:0] w_index,
    output           w_e     ,
    output [18:0]    w_vppn  ,
    output [ 5:0]    w_ps    ,
    output [ 9:0]    w_asid  ,
    output           w_g     ,
    output [19:0]    w_ppn0  ,
    output [ 1:0]    w_plv0  ,
    output [ 1:0]    w_mat0  ,
    output           w_d0    ,
    output           w_v0    ,
    output [19:0]    w_ppn1  ,
    output [ 1:0]    w_plv1  ,
    output [ 1:0]    w_mat1  ,
    output           w_d1    ,
    output           w_v1    ,
    // read port
    output [$clog2(TLBNUM)-1:0] r_index,
    input          r_e     ,
    input [18:0]   r_vppn  ,
    input [ 5:0]   r_ps    ,
    input [ 9:0]   r_asid  ,
    input          r_g     ,
    input [19:0]   r_ppn0  ,
    input [ 1:0]   r_plv0  ,
    input [ 1:0]   r_mat0  ,
    input          r_d0    ,
    input          r_v0    ,
    input [19:0]   r_ppn1  ,
    input [ 1:0]   r_plv1  ,
    input [ 1:0]   r_mat1  ,
    input          r_d1    ,
    input          r_v1    ,
    output         tlb_refill,
    input [31:0]   csr_tlbidx_rvalue,
    input [31:0]   csr_estat_rvalue,
    input [31:0]   csr_asid_rvalue,
    input [31:0]   csr_tlbehi_rvalue,
    input [31:0]   csr_tlbelo0_rvalue,
    input [31:0]   csr_tlbelo1_rvalue,     
    input [31:0]   csr_tlbrentry_rvalue,
    output         csr_tlbrd,
    output[31:0]   csr_asid_wvalue,
    output [31:0]  csr_tlbidx_wvalue,
    output [31:0]  csr_tlbelo0_wvalue,
    output [31:0]  csr_tlbelo1_wvalue,
    output [31:0]  csr_tlbehi_wvalue,
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
    wire exec_ADEM;
    wire es_tlb_refill_ex  ;
    wire es_tlb_st_ex      ;
    wire es_tlb_ld_ex      ;
    wire es_tlb_mod_ex     ;
    wire es_tlb_plv_ex     ;
    wire fs_tlb_refill_ex  ;
    wire fs_tlb_insfetch_ex;
    wire fs_tlb_plv_ex     ; 
    //wire tlb_refill;
    assign tlb_refill = es_tlb_refill_ex || fs_tlb_refill_ex;
//inst
    wire inst_rdcntid;
//pipeline
wire        ws_go;
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
                {6{exec_ADEF||exec_ADEM}} & `ECODE_ADE |
                {6{exec_INE }} & `ECODE_INE |
                {6{exec_ALE }} & `ECODE_ALE |
                {6{es_tlb_refill_ex||fs_tlb_refill_ex}}& `ECODE_TLBR|
                {6{fs_tlb_insfetch_ex}}                & `ECODE_PIF |
                {6{es_tlb_st_ex}}                      & `ECODE_PIS |
                {6{es_tlb_ld_ex}}                      & `ECODE_PIL |
                {6{es_tlb_plv_ex   ||fs_tlb_plv_ex  }} & `ECODE_PPI |
                {6{es_tlb_mod_ex}}                     & `ECODE_PME ;       
assign wb_esubcode = {8{exec_ADEF}} & `ESUBCODE_ADEF|
                     {8{exec_ADEM}} & `ESUBCODE_ADEM;
assign wb_ex = ws_valid & 
                (
                    exec_INT  | exec_SYS  | exec_BRK  |
                    exec_ADEF |exec_ADEM | exec_INE  | exec_ALE  |
                    es_tlb_refill_ex|fs_tlb_refill_ex|
                    fs_tlb_insfetch_ex|
                    es_tlb_st_ex|
                    es_tlb_ld_ex|
                    es_tlb_plv_ex|
                    fs_tlb_plv_ex|
                    es_tlb_mod_ex|
                    wb_tlb_reflush
                );
reg  tlb_refill_flag;
always @(posedge clk) begin
    if(reset)
        tlb_refill_flag <= 1'b0;
    else if(es_tlb_refill_ex||fs_tlb_refill_ex)
        tlb_refill_flag <= 1'b1;
    else if(ertn_flush_wb_temp)
        tlb_refill_flag <= 1'b0;
end
wire change_da_pg;
assign change_da_pg = tlb_refill_flag && ertn_flush_wb_temp;
wire fs_tlb_ex;
assign fs_tlb_ex = fs_tlb_plv_ex|fs_tlb_insfetch_ex|fs_tlb_refill_ex;
reg tlb_ex_flag;
always @(posedge clk) begin
    if(reset)
        tlb_ex_flag <= 1'b0;
    else if(fs_tlb_insfetch_ex|es_tlb_st_ex|es_tlb_ld_ex|es_tlb_plv_ex|fs_tlb_plv_ex|es_tlb_mod_ex)
        tlb_ex_flag <= 1'b1;
    else if (ertn_flush_wb_temp)
        tlb_ex_flag <= 1'b0;
end
wire tlb_map_stop;
assign tlb_map_stop = tlb_ex_flag && ertn_flush_wb_temp;
assign csr_num_wb = csr_num_wb_temp & {14{ws_valid}};
wire ertn_flush_wb_temp; 
assign ertn_flush_wb = ertn_flush_wb_temp & ws_valid;
wire csr_we_wb_temp;
assign csr_we_wb = csr_we_wb_temp & count_1_wb;
wire [31:0] nextpc_wb;
wire inst_rdcntid_wb_w;
wire wb_tlb_op_5_temp;
assign wb_tlb_op[5] = wb_tlb_op_5_temp & ws_valid;
assign {
        es_tlb_refill_ex  ,
        es_tlb_st_ex      ,
        es_tlb_ld_ex      ,
        es_tlb_mod_ex     ,
        es_tlb_plv_ex     ,
        fs_tlb_refill_ex  ,
        fs_tlb_insfetch_ex,
        fs_tlb_plv_ex     ,
        wb_tlb_reflush,         //260
        wb_tlb_op_5_temp,
        wb_tlb_op[4:0],              //259:254
        nextpc_wb,              //253:222
        inst_rdcntid_wb_w,          //221
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
        exec_ADEM,
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
assign eentry_wb = fs_tlb_refill_ex||es_tlb_refill_ex ? csr_tlbrentry_rvalue: 
                                                        csr_rvalue_eentry;

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
assign ws_go = ms_to_ws_valid && ws_allowin;
assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;
//tlb
reg  [3:0] tlbfill_index;
//write
assign we     = wb_tlb_op[1] | wb_tlb_op [2];
assign w_index= wb_tlb_op[2]? csr_tlbidx_rvalue[3:0]:
                ( wb_tlb_op[1] ? tlbfill_index[3:0]:
                        4'b0);
assign w_asid = csr_asid_rvalue[9:0];
assign w_e    = (csr_estat_rvalue[21:16]==6'h3f) || ~csr_tlbidx_rvalue[31];
assign w_ps   = csr_tlbidx_rvalue[29:24];
assign w_vppn = csr_tlbehi_rvalue[31:13];
assign w_v0   = csr_tlbelo0_rvalue [0];
assign w_d0   = csr_tlbelo0_rvalue [1];
assign w_plv0 = csr_tlbelo0_rvalue [3:2];
assign w_mat0 = csr_tlbelo0_rvalue [5:4];
assign w_ppn0 = csr_tlbelo0_rvalue [31:8];
assign w_v1   = csr_tlbelo1_rvalue [0];
assign w_d1   = csr_tlbelo1_rvalue [1];
assign w_plv1 = csr_tlbelo1_rvalue [3:2];
assign w_mat1 = csr_tlbelo1_rvalue [5:4];
assign w_ppn1 = csr_tlbelo1_rvalue [31:8];
assign w_g = csr_tlbelo1_rvalue[6] &  csr_tlbelo0_rvalue [6]; 
//read
assign csr_tlbrd = r_e & ws_valid & wb_tlb_op[3];
assign r_index = csr_tlbidx_rvalue[3:0];
assign csr_tlbidx_wvalue = {~r_e,
                            1'b0,
                            r_ps,
                            20'b0,
                            4'b0
                            };
assign  csr_tlbelo0_wvalue = {r_ppn0,
                              1'b0,
                              r_g,
                              r_mat0,
                              r_plv0,
                              r_d0, 
                              r_v0
                             };
assign  csr_tlbelo1_wvalue = {r_ppn1,
                              1'b0,
                              r_g,
                              r_mat1,
                              r_plv1,
                              r_d1,
                              r_v1                            
                              };
assign csr_asid_wvalue[9:0] = r_asid;
assign csr_tlbehi_wvalue = {r_vppn,
                            13'b0
                            };
always @(posedge clk)begin
    if(reset)begin
        tlbfill_index <= 4'b0;
    end
    else if(wb_tlb_op[1]&ws_valid) begin
        if(tlbfill_index == 4'd15) begin
            tlbfill_index <= 4'b0;
        end
        else begin
            tlbfill_index <= tlbfill_index + 4'b1;
        end
    end
end
// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule