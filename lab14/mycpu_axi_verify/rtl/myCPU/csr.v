`include "mycpu.h"

    
module CSR(
    input            clk,
    input            reset,
    input            csr_re,
    input            csr_we,
    input            ertn_flush,
    output           has_int,
    input  [7:0]     hw_int_in,                  
    input            ipi_int_in,
    input  [5:0]     wb_ecode,
    input  [8:0]     wb_esubcode,
    input  [31:0]    wb_pc,
    input            wb_ex,
    input  [31:0]    wb_vaddr,
    input  [13:0]    csr_num_r,
    input  [13:0]    csr_num,
    output [31:0]    csr_rvalue,
    input  [31:0]    csr_wvalue,
    output [31:0]    csr_rvalue_cntvl,
    output [31:0]    csr_rvalue_cntvh,
    output [31:0]    csr_rvalue_cntid,
    output [31:0]    csr_rvalue_eentry,
    input  [31:0]    csr_wmask,
    input            change_da_pg,
    //tlb
    input          fs_tlb_ex,
    input          tlb_refill,
    input  [5:0]   tlb_op_bus,
    input          tlbsrch_hit,
    input          csr_tlbrd,
    input  [31: 0] csr_tlbidx_wvalue,
    input  [31: 0] csr_tlbidx_wvalue_ex,
    input  [31: 0] csr_tlbehi_wvalue,
    input  [31: 0] csr_tlbelo0_wvalue,
    input  [31: 0] csr_tlbelo1_wvalue,
    input  [31: 0] csr_asid_wvalue,
    output [31:0]  CRMD,
    output [31: 0] TLBIDX,
    output [31: 0] TLBEHI,
    output [31: 0] TLBELO0,
    output [31: 0] TLBELO1,
    output [31: 0] ASID,
    output [31: 0] DMW0,
    output [31: 0] DMW1,
    output [31: 0] ESTAT,
    output [31: 0] TLBRENTRY
);
//declare
//wire [31:0] CRMD;
    reg [1:0]  csr_crmd_datm;
    reg [1:0]  csr_crmd_datf;
    reg        csr_crmd_pg;//
    reg        csr_crmd_da;//
    reg        csr_crmd_ie;    
    reg [1:0]  csr_crmd_plv;
wire [31:0] PRMD; 
    reg       csr_prmd_pie;
    reg [1:0] csr_prmd_pplv;
wire [31:0] ECFG;
    reg [12:0]  csr_ecfg_lie;
//wire [31:0] ESTAT;
    reg [8:0]   csr_estat_esubcode;      //what if [30:22]
    reg [5:0]   csr_estat_ecode;
    reg [12:0]  csr_estat_is;
wire [31:0] ERA;
    reg [31:0] csr_era_pc;
wire [31:0] BADV;
    reg [31:0] csr_badv_vaddr;
wire [31:0] EENTRY;
    reg [25:0] csr_eentry_va;
wire [31:0] TID;
    reg [31:0] csr_tid_tid;
wire [31:0] TCFG;
    reg [29:0]  csr_tcfg_initval;
    reg csr_tcfg_periodic;
    reg csr_tcfg_en;
wire [31:0] TVAL;
    wire [31:0] csr_tval;
    wire [31:0] tcfg_next_value;
    reg [31:0] timer_cnt;
wire [31:0] TICLR;
    wire csr_ticlr_clr = 1'b0;

/*wire [31:0] TLBIDX;
wire [31:0] TLBEHI;
wire [31:0] TLBELO0;
wire [31:0] TLBELO1;
wire [31:0] ASID;
wire [31:0] TLBRENTRY;
wire [31:0] DMW0;
wire [31:0] DMW1;*/
//TLBIDX
reg  [3 : 0] csr_tlbidx_index;
reg  [29:24] csr_tlbidx_ps;
reg          csr_tlbidx_ne;

//TLBEHI
reg  [31:13] csr_tlbehi_vppn;

//TLBELO
reg          csr_tlbelo0_v;
reg          csr_tlbelo0_d;
reg  [3 : 2] csr_tlbelo0_plv;
reg  [5 : 4] csr_tlbelo0_mat;
reg          csr_tlbelo0_g;
reg  [31: 8] csr_tlbelo0_ppn;
reg          csr_tlbelo1_v;
reg          csr_tlbelo1_d;
reg  [3 : 2] csr_tlbelo1_plv;
reg  [5 : 4] csr_tlbelo1_mat;
reg          csr_tlbelo1_g;
reg  [31: 8] csr_tlbelo1_ppn;

//TLBRENTRY
reg  [31: 6] csr_tlbrentry_pa;
//wire [31: 0] csr_tlbrentry_rvalue;

//ASID
reg  [9 : 0] csr_asid_asid;
wire [7 : 0] csr_asid_asidbits = 8'd10;

//DMW
reg          csr_dmw0_plv0;
reg          csr_dmw0_plv3;
reg  [5 : 4] csr_dmw0_mat;
reg  [27:25] csr_dmw0_pseg;
reg  [31:29] csr_dmw0_vseg; 
reg          csr_dmw1_plv0;
reg          csr_dmw1_plv3;
reg  [5 : 4] csr_dmw1_mat;
reg  [27:25] csr_dmw1_pseg;
reg  [31:29] csr_dmw1_vseg; 

//CRMD
    assign CRMD = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    always @(posedge clk) begin
        if (reset)begin
            csr_crmd_plv <= 2'b00;
            csr_crmd_ie <= 1'b0;
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if (wb_ex)begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
            if (wb_ecode == `ECODE_TLBR)begin
                csr_crmd_da <= 1'b1;
                csr_crmd_pg <= 1'b0;
            end
        end
        else if (ertn_flush)begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
            if(change_da_pg)begin
                csr_crmd_da <= 1'b0;
                csr_crmd_pg <= 1'b1;
            end
        end
        else if (csr_we && csr_num==`CSR_CRMD)begin
            csr_crmd_plv<= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] | ~csr_wmask[`CSR_CRMD_PLV]   & csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE] | ~csr_wmask[`CSR_CRMD_PIE]   & csr_crmd_ie;
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA ] & csr_wvalue[`CSR_CRMD_DA ] | ~csr_wmask[`CSR_CRMD_DA ]   & csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG ] & csr_wvalue[`CSR_CRMD_PG ] | ~csr_wmask[`CSR_CRMD_PG ]   & csr_crmd_pg;
        end
    end
//PRMD
    assign PRMD = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]   | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]     | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
    end
//ECFG
    assign ECFG = {19'b0, csr_ecfg_lie};
    always @(posedge clk) begin   
        if (reset)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]  | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end
//ESTAT
    assign ESTAT = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    wire [31:0] is_11_w = (csr_wmask[`CSR_TICLR_CLR] & csr_wvalue[`CSR_TICLR_CLR]);
    
    wire is_11 = |is_11_w;
    always @(posedge clk) begin
        if(reset)begin
            csr_estat_is[1:0] <= 2'b0;
            csr_estat_is <= 13'b0;
        end
        else if(csr_we && csr_num==`CSR_ESTAT)begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
            csr_estat_is[9:2] <= hw_int_in[7:0];
            csr_estat_is[10] <= 1'b0;
        end
        if (csr_tcfg_en && timer_cnt[31:0]==32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num==`CSR_TICLR && is_11 )
            csr_estat_is[11] <= 1'b0;

        csr_estat_is[12] <= ipi_int_in;
    end
    //ECODE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
//ERA
    assign ERA = csr_era_pc;
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
//BADV
    assign BADV = csr_badv_vaddr;
    ////TODO
    wire wb_ex_addr_err = (wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE || wb_ecode == `ECODE_TLBR || wb_ecode == `ECODE_PIL ||wb_ecode == `ECODE_PIS ||wb_ecode == `ECODE_PIF ||wb_ecode == `ECODE_PME || wb_ecode == `ECODE_PPI);
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF||fs_tlb_ex ) ? wb_pc : wb_vaddr;
        /*if (fs_tlb_ex)
            csr_badv_vaddr <= fs_nextpc;*/
    end
//EENTRY
    assign EENTRY = {csr_eentry_va, 6'b0};
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] 
                        | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end
//SAVE REGISTERS
    wire [31:0] SAVE0;
    wire [31:0] SAVE1;
    wire [31:0] SAVE2;
    wire [31:0] SAVE3;
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    assign SAVE0  = csr_save0_data;    
    assign SAVE1  = csr_save1_data;
    assign SAVE2  = csr_save2_data;     
    assign SAVE3  = csr_save3_data;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
    end
//TID
    assign TID = csr_tid_tid;

    wire [31:0] coreid_in = 32'b0;

    always @(posedge clk) begin
        if (reset)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                         | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
    end
//TCFG
    assign TCFG = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                         | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
        
        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]    & csr_wvalue[`CSR_TCFG_PERIOD]
                                | ~csr_wmask[`CSR_TCFG_PERIOD]  & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV]     & csr_wvalue[`CSR_TCFG_INITV]
                                | ~csr_wmask[`CSR_TCFG_INITV]   & csr_tcfg_initval;
        end
    end

//TVAL
    assign csr_tval = timer_cnt[31:0];
    assign TVAL = csr_tval;
    assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]   | ~csr_wmask[31:0] &{csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (reset)
        timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
//TICLR
    assign TICLR = {31'b0, csr_ticlr_clr};

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);
//TLBIDX
    assign TLBIDX = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,20'b0,csr_tlbidx_index};
    always @(posedge clk ) begin
        if(reset) begin
            csr_tlbidx_index <= 4'b0;
        end
        else if(tlb_op_bus[4] && tlbsrch_hit) begin
            csr_tlbidx_index <= csr_tlbidx_wvalue_ex[`CSR_TLBIDX_INDEX];
        end
        else if(csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                            | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
        end
    end

    always @(posedge clk ) begin
        if(reset) begin
            csr_tlbidx_ps <= 6'b0;
        end
        else if(csr_tlbrd) begin
            csr_tlbidx_ps <= csr_tlbidx_wvalue[`CSR_TLBIDX_PS];
        end
        else if(csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                        | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        end
    end

    always @(posedge clk ) begin
        if(reset) begin
            csr_tlbidx_ne <= 1'b0;
        end
        else if(tlb_op_bus[4]) begin
            if(tlbsrch_hit) begin
                csr_tlbidx_ne <= 1'b0;
            end
            else begin
                csr_tlbidx_ne <= 1'b1;
            end
        end
        else if(tlb_op_bus[3]) begin
            csr_tlbidx_ne <= csr_tlbidx_wvalue[`CSR_TLBIDX_NE];
        end
        else if(csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                        | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne; 
        end
    end

//TLBEHI
    assign TLBEHI = {csr_tlbehi_vppn,13'b0};
    always @(posedge clk ) begin
        if(reset) begin
            csr_tlbehi_vppn <= 19'b0;
        end
        else if(csr_tlbrd) begin
            csr_tlbehi_vppn <= csr_tlbehi_wvalue[`CSR_TLBEHI_VPPN];
        end
        else if(wb_ecode == `ECODE_TLBR || wb_ecode == `ECODE_PIL ||wb_ecode == `ECODE_PIS ||wb_ecode == `ECODE_PIF ||wb_ecode == `ECODE_PME || wb_ecode == `ECODE_PPI)begin
            csr_tlbehi_vppn <= fs_tlb_ex ? wb_pc[31:13] : wb_vaddr[31:13];
        end
        else if(csr_we && csr_num == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                            | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;   
        end
    end

//TLBELO01
assign TLBELO0 = {csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};
always @(posedge clk ) begin
    if(reset) begin
        csr_tlbelo0_v   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_ppn <= 24'b0;
    end
    else if (csr_tlbrd) begin
        csr_tlbelo0_v   <= csr_tlbelo0_wvalue[`CSR_TLBELO_V];
        csr_tlbelo0_d   <= csr_tlbelo0_wvalue[`CSR_TLBELO_D];
        csr_tlbelo0_plv <= csr_tlbelo0_wvalue[`CSR_TLBELO_PLV];
        csr_tlbelo0_mat <= csr_tlbelo0_wvalue[`CSR_TLBELO_MAT];
        csr_tlbelo0_ppn <= csr_tlbelo0_wvalue[`CSR_TLBELO_PPN];
        csr_tlbelo0_g   <= csr_tlbelo0_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO0) begin
        csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo0_v; 
        csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo0_g;    
    end
end
assign TLBELO1 = {csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};
always @(posedge clk ) begin
    if(reset) begin
        csr_tlbelo1_v   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_ppn <= 24'b0;
    end
    else if (csr_tlbrd) begin
        csr_tlbelo1_v   <= csr_tlbelo1_wvalue[`CSR_TLBELO_V];
        csr_tlbelo1_d   <= csr_tlbelo1_wvalue[`CSR_TLBELO_D];
        csr_tlbelo1_plv <= csr_tlbelo1_wvalue[`CSR_TLBELO_PLV];
        csr_tlbelo1_mat <= csr_tlbelo1_wvalue[`CSR_TLBELO_MAT];
        csr_tlbelo1_ppn <= csr_tlbelo1_wvalue[`CSR_TLBELO_PPN];
        csr_tlbelo1_g   <= csr_tlbelo1_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO1) begin
        csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo1_v; 
        csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo1_g;    
    end
end

//TLBRENTRY
assign TLBRENTRY = {csr_tlbrentry_pa,6'b0};
always @(posedge clk ) begin
    if(reset)begin
        csr_tlbrentry_pa <= 26'b0;
    end 
    else if(csr_we && csr_num == `CSR_TLBRENTRY) begin
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                         | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa; 
    end
end

//ASID
assign ASID = {8'b0,8'd10,6'b0,csr_asid_asid};
always @(posedge clk ) begin
    if(reset) begin
        csr_asid_asid <= 10'b0;
    end
    else if(csr_tlbrd) begin
        csr_asid_asid <= csr_asid_wvalue[`CSR_ASID_ASID];
    end
    else if(csr_we && csr_num == `CSR_ASID)begin
        csr_asid_asid  <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                       | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid; 
    end
end

//DMW01
assign DMW0 = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};
assign DMW1 = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};
always @(posedge clk ) begin
    if(reset) begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW0)begin
        csr_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0; 
        csr_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3; 
        csr_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat; 
        csr_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
        csr_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;   
    end
end

always @(posedge clk ) begin
    if(reset) begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW1)begin
        csr_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0; 
        csr_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3; 
        csr_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat; 
        csr_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
        csr_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;   
    end
end
//CSR READ
assign csr_rvalue = {32{csr_num_r == `CSR_CRMD  }}   & CRMD     |
                    {32{csr_num_r == `CSR_PRMD  }}   & PRMD     |
                    {32{csr_num_r == `CSR_ECFG  }}   & ECFG     |
                    {32{csr_num_r == `CSR_ESTAT }}   & ESTAT    |
                    {32{csr_num_r == `CSR_ERA   }}   & ERA      |
                    {32{csr_num_r == `CSR_BADV  }}   & BADV     |
                    {32{csr_num_r == `CSR_EENTRY}}   & EENTRY   |
                    {32{csr_num_r == `CSR_SAVE0 }}   & SAVE0    |
                    {32{csr_num_r == `CSR_SAVE1 }}   & SAVE1    |
                    {32{csr_num_r == `CSR_SAVE2 }}   & SAVE2    |
                    {32{csr_num_r == `CSR_SAVE3 }}   & SAVE3    |
                    {32{csr_num_r == `CSR_TID   }}   & TID      |
                    {32{csr_num_r == `CSR_TCFG  }}   & TCFG     |
                    {32{csr_num_r == `CSR_TVAL  }}   & TVAL     |
                    {32{csr_num_r == `CSR_TICLR }}   & TICLR    |
                    {32{csr_num_r == `CSR_TLBIDX}}   & TLBIDX   |
                    {32{csr_num_r == `CSR_TLBEHI}}   & TLBEHI   |
                    {32{csr_num_r == `CSR_TLBELO0}}  & TLBELO0  |
                    {32{csr_num_r == `CSR_TLBELO1}}  & TLBELO1  |
                    {32{csr_num_r == `CSR_TLBRENTRY}}& TLBRENTRY|
                    {32{csr_num_r == `CSR_ASID}}     & ASID     |
                    {32{csr_num_r == `CSR_DMW0}}     & DMW0     |
                    {32{csr_num_r == `CSR_DMW1}}     & DMW1     ;
reg [63:0] timer;
wire timer_low = timer[31:0];
wire timer_high = timer[63:32];
always @(posedge clk ) begin
    if(reset)
        timer <= 64'b0;
    else begin
        timer <= timer + 64'b1;
    end
end
assign csr_rvalue_cntvl = timer_low; 
assign csr_rvalue_cntvh = timer_high;
assign csr_rvalue_cntid = TID;
assign csr_rvalue_eentry = EENTRY;
endmodule