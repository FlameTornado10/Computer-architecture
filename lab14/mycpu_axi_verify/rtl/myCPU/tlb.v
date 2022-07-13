`define TLBNNN 16
module tlb #(
    parameter TLBNUM = 16
)(
    input clk,
// search port 0 (for fetch)
    input  [ 18:0]              s0_vppn     ,
    input                       s0_va_bit12 ,
    input  [ 9:0]               s0_asid     ,
    output                      s0_found    ,
    output [$clog2(TLBNUM)-1:0] s0_index    ,
    output [ 19:0]              s0_ppn      ,
    output [ 5:0]               s0_ps       ,
    output [ 1:0]               s0_plv      ,
    output [ 1:0]               s0_mat      ,
    output                      s0_d        ,
    output                      s0_v        ,
// search port 1 (for load/store)
    input [18:0]    s1_vppn,
    input           s1_va_bit12 ,
    input [ 9:0]    s1_asid,
    output          s1_found    ,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [19:0]   s1_ppn      ,
    output [ 5:0]   s1_ps       ,
    output [ 1:0]   s1_plv      ,
    output [ 1:0]   s1_mat      ,
    output          s1_d        ,
    output          s1_v        ,
// invtlb opcode
    input [ 4:0]    invtlb_op   ,
    input           invtlb_valid,
// write port
    input we, //w(rite) e(nable)
    input [$clog2(TLBNUM)-1:0] w_index,
    input           w_e     ,
    input [18:0]    w_vppn  ,
    input [ 5:0]    w_ps    ,
    input [ 9:0]    w_asid  ,
    input           w_g     ,
    input [19:0]    w_ppn0  ,
    input [ 1:0]    w_plv0  ,
    input [ 1:0]    w_mat0  ,
    input           w_d0    ,
    input           w_v0    ,
    input [19:0]    w_ppn1  ,
    input [ 1:0]    w_plv1  ,
    input [ 1:0]    w_mat1  ,
    input           w_d1    ,
    input           w_v1    ,
// read port
    input [$clog2(TLBNUM)-1:0] r_index,
    output          r_e     ,
    output [18:0]   r_vppn  ,
    output [ 5:0]   r_ps    ,
    output [ 9:0]   r_asid  ,
    output          r_g     ,
    output [19:0]   r_ppn0  ,
    output [ 1:0]   r_plv0  ,
    output [ 1:0]   r_mat0  ,
    output          r_d0    ,
    output          r_v0    ,
    output [19:0]   r_ppn1  ,
    output [ 1:0]   r_plv1  ,
    output [ 1:0]   r_mat1  ,
    output          r_d1    ,
    output          r_v1
);

reg         tlb_e       [TLBNUM-1:0];
reg         tlb_ps4MB   [TLBNUM-1:0]; //pagesize 1:4MB, 0:4KB
reg [18:0]  tlb_vppn    [TLBNUM-1:0];
reg [ 5:0]  tlb_ps      [TLBNUM-1:0]; 
reg [ 9:0]  tlb_asid    [TLBNUM-1:0];
reg         tlb_g       [TLBNUM-1:0];
reg [19:0]  tlb_ppn0    [TLBNUM-1:0];
reg [ 1:0]  tlb_plv0    [TLBNUM-1:0];       //???
reg [ 1:0]  tlb_mat0    [TLBNUM-1:0];
reg         tlb_d0      [TLBNUM-1:0];
reg         tlb_v0      [TLBNUM-1:0];
reg [19:0]  tlb_ppn1    [TLBNUM-1:0];
reg [ 1:0]  tlb_plv1    [TLBNUM-1:0];
reg [ 1:0]  tlb_mat1    [TLBNUM-1:0];
reg         tlb_d1      [TLBNUM-1:0];
reg         tlb_v1      [TLBNUM-1:0];
// VPPN(19)  PS(6)  G(1)  ASID(10) E(1)  [PPN0(20)  PLV(2)  MAT(2)  D(1) V(1)]

//WRITE
    always @(posedge clk) begin
        if (we) begin
            tlb_ps4MB[w_index] <=  (w_ps == 6'h16);
            tlb_ps   [w_index] <=   w_ps    ;
            tlb_vppn [w_index] <=   w_vppn  ;
            tlb_asid [w_index] <=   w_asid  ;
            tlb_g    [w_index] <=   w_g     ;
            tlb_ppn0 [w_index] <=   w_ppn0  ;
            tlb_plv0 [w_index] <=   w_plv0  ;
            tlb_ppn0 [w_index] <=   w_ppn0  ; 
            tlb_plv0 [w_index] <=   w_plv0  ; 
            tlb_mat0 [w_index] <=   w_mat0  ; 
            tlb_d0   [w_index] <=   w_d0    ; 
            tlb_v0   [w_index] <=   w_v0    ; 
            tlb_ppn1 [w_index] <=   w_ppn1  ; 
            tlb_plv1 [w_index] <=   w_plv1  ; 
            tlb_mat1 [w_index] <=   w_mat1  ; 
            tlb_d1   [w_index] <=   w_d1    ; 
            tlb_v1   [w_index] <=   w_v1    ; 
        end 
    end
//READ
    assign r_e     =  tlb_e     [r_index]; 
    assign r_vppn  =  tlb_vppn  [r_index] & {19{r_e}}; 
    assign r_ps    =  tlb_ps    [r_index] & { 6{r_e}}; 
    assign r_asid  =  tlb_asid  [r_index] & { 10{r_e}}; 
    assign r_g     =  tlb_g     [r_index] & {  {r_e}}; 
    assign r_ppn0  =  tlb_ppn0  [r_index] & {20{r_e}}; 
    assign r_plv0  =  tlb_plv0  [r_index] & { 2{r_e}}; 
    assign r_mat0  =  tlb_mat0  [r_index] & { 2{r_e}}; 
    assign r_d0    =  tlb_d0    [r_index] & {  {r_e}}; 
    assign r_v0    =  tlb_v0    [r_index] & {  {r_e}}; 
    assign r_ppn1  =  tlb_ppn1  [r_index] & {20{r_e}}; 
    assign r_plv1  =  tlb_plv1  [r_index] & { 2{r_e}}; 
    assign r_mat1  =  tlb_mat1  [r_index] & { 2{r_e}}; 
    assign r_d1    =  tlb_d1    [r_index] & {  {r_e}}; 
    assign r_v1    =  tlb_v1    [r_index] & {  {r_e}};
//SEARCH & {{r_e[0]}}
wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;
genvar i;
generate
    for(i = 0; i < TLBNUM; i = i + 1) begin: lable0
        assign match0[i] = (s0_vppn[18:10] == tlb_vppn[i][18:10]) 
                        && (tlb_ps4MB[i] || s0_vppn[9:0] == tlb_vppn[i][9:0]) 
                        && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
    end
endgenerate
assign s0_found = (match0 != 16'b0);
assign s0_index = {4{match0[4'h0]}} & 4'h0 |
                  {4{match0[4'h1]}} & 4'h1 |
                  {4{match0[4'h2]}} & 4'h2 |
                  {4{match0[4'h3]}} & 4'h3 |
                  {4{match0[4'h4]}} & 4'h4 |
                  {4{match0[4'h5]}} & 4'h5 |
                  {4{match0[4'h6]}} & 4'h6 |
                  {4{match0[4'h7]}} & 4'h7 |
                  {4{match0[4'h8]}} & 4'h8 |
                  {4{match0[4'h9]}} & 4'h9 |
                  {4{match0[4'ha]}} & 4'ha |
                  {4{match0[4'hb]}} & 4'hb |
                  {4{match0[4'hc]}} & 4'hc |
                  {4{match0[4'hd]}} & 4'hd |
                  {4{match0[4'he]}} & 4'he |
                  {4{match0[4'hf]}} & 4'hf ;

wire   sel_12_bit_s0;
assign sel_12_bit_s0 = s0_ps == 6'h0c;
assign s0_plv = sel_12_bit_s0 ? (s0_va_bit12 ? tlb_plv1 [s0_index] : tlb_plv0[s0_index]):
                                (s0_vppn[9]  ? tlb_plv1 [s0_index] : tlb_plv0[s0_index]);
assign s0_ppn = sel_12_bit_s0 ? (s0_va_bit12 ? tlb_ppn1 [s0_index] : tlb_ppn0[s0_index]):
                                (s0_vppn[9]  ? tlb_ppn1 [s0_index] : tlb_ppn0[s0_index]);
assign s0_ps  = tlb_ps   [s0_index];
assign s0_mat = sel_12_bit_s0 ? (s0_va_bit12 ? tlb_mat1 [s0_index] : tlb_mat0[s0_index]):
                                (s0_vppn[9]  ? tlb_mat1 [s0_index] : tlb_mat0[s0_index]);
assign s0_d   = sel_12_bit_s0 ? (s0_va_bit12 ? tlb_d1   [s0_index] : tlb_d0  [s0_index]):
                                (s0_vppn[9]  ? tlb_d1   [s0_index] : tlb_d0  [s0_index]);
assign s0_v   = sel_12_bit_s0 ? (s0_va_bit12 ? tlb_v1   [s0_index] : tlb_v0  [s0_index]):
                                (s0_vppn[9]  ? tlb_v1   [s0_index] : tlb_v0  [s0_index]);
                  
generate
    for(i = 0; i < TLBNUM; i = i + 1) begin: lable1
        assign match1[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) 
                        && (tlb_ps4MB[i] || s1_vppn[9:0] == tlb_vppn[i][9:0]) 
                        && ((s1_asid == tlb_asid[i]) || tlb_g[i]);                              
    end
endgenerate
assign s1_found = (match1 != 16'b0);
assign s1_index = {4{match1[4'h0]}} & 4'h0 |
                  {4{match1[4'h1]}} & 4'h1 |
                  {4{match1[4'h2]}} & 4'h2 |
                  {4{match1[4'h3]}} & 4'h3 |
                  {4{match1[4'h4]}} & 4'h4 |
                  {4{match1[4'h5]}} & 4'h5 |
                  {4{match1[4'h6]}} & 4'h6 |
                  {4{match1[4'h7]}} & 4'h7 |
                  {4{match1[4'h8]}} & 4'h8 |
                  {4{match1[4'h9]}} & 4'h9 |
                  {4{match1[4'ha]}} & 4'ha |
                  {4{match1[4'hb]}} & 4'hb |
                  {4{match1[4'hc]}} & 4'hc |
                  {4{match1[4'hd]}} & 4'hd |
                  {4{match1[4'he]}} & 4'he |
                  {4{match1[4'hf]}} & 4'hf ;

wire   sel_12_bit_s1;
assign sel_12_bit_s1 = s1_ps == 6'h0c;

assign s1_plv     = sel_12_bit_s1 ? (s1_va_bit12 ? tlb_plv1 [s1_index] : tlb_plv0[s1_index]):
                                    (s1_vppn[9]  ? tlb_plv1 [s1_index] : tlb_plv0[s1_index]);
assign s1_ppn     = sel_12_bit_s1 ? (s1_va_bit12 ? tlb_ppn1 [s1_index] : tlb_ppn0[s1_index]):
                                    (s1_vppn[9]  ? tlb_ppn1 [s1_index] : tlb_ppn0[s1_index]);
assign s1_ps      = tlb_ps   [s1_index];
assign s1_mat     = sel_12_bit_s1 ? (s1_va_bit12 ? tlb_mat1 [s1_index] : tlb_mat0[s1_index]):
                                    (s1_vppn[9]  ? tlb_mat1 [s1_index] : tlb_mat0[s1_index]);
assign s1_d       = sel_12_bit_s1 ? (s1_va_bit12 ? tlb_d1   [s1_index] : tlb_d0  [s1_index]):
                                    (s1_vppn[9]  ? tlb_d1   [s1_index] : tlb_d0  [s1_index]);
assign s1_v       = sel_12_bit_s1 ? (s1_va_bit12 ? tlb_v1   [s1_index] : tlb_v0  [s1_index]):
                                    (s1_vppn[9]  ? tlb_v1   [s1_index] : tlb_v0  [s1_index]);
//invalid_tlb
wire [          3: 0]     cond      [TLBNUM-1:0];
wire [TLBNUM - 1 : 0]     inv_match;
genvar tlb_index;
generate 
    for(tlb_index = 0;tlb_index<TLBNUM;tlb_index=tlb_index+1)
    begin
//invtlab
        assign cond[tlb_index][0] =~tlb_g[tlb_index];
        assign cond[tlb_index][1] = tlb_g[tlb_index];
        assign cond[tlb_index][2] = s1_asid == tlb_asid[tlb_index];
        assign cond[tlb_index][3] = (s1_vppn[18:10]==tlb_vppn[tlb_index][18:10]) 
            && (tlb_ps4MB[tlb_index]||s1_vppn[9:0]==tlb_vppn[tlb_index][ 9: 0]);
        assign inv_match[tlb_index] = ((invtlb_op==0||invtlb_op==1) & (cond[tlb_index][0] || cond[tlb_index][1]))
                                        ||((invtlb_op==2) & (cond[tlb_index][1]))
                                        ||((invtlb_op==3) & (cond[tlb_index][0]))
                                        ||((invtlb_op==4) & (cond[tlb_index][0]) & (cond[tlb_index][2]))
                                        ||((invtlb_op==5) & (cond[tlb_index][0]) & cond[tlb_index][2] & cond[tlb_index][3])
                                        ||((invtlb_op==6) & (cond[tlb_index][1] | cond[tlb_index][2]) & cond[tlb_index][3]);   
//write
        always @(posedge clk )begin
            if(we && tlb_index == w_index)begin
                tlb_e    [tlb_index] <=   w_e     ;
            end
            else if(inv_match[tlb_index] & invtlb_valid)begin
                tlb_e    [tlb_index] <= 1'b0;
            end 
        end
    end 
endgenerate
endmodule