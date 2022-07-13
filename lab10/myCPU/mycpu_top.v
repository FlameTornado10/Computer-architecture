`include "mycpu.h"
module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output          inst_sram_req,
    output          inst_sram_wr,
    output [1 :0]   inst_sram_size,
    output [3 :0]   inst_sram_wstrb,
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,
    input           inst_sram_addr_ok,
    input           inst_sram_data_ok,
    input  [31:0]   inst_sram_rdata,    
    // output          inst_sram_en,
    // output [ 3:0]   inst_sram_wen,

    // data sram interface
    output          data_sram_req,
    output          data_sram_wr,
    output [1 :0]   data_sram_size,
    output [3 :0]   data_sram_wstrb,
    output [31:0]   data_sram_addr,
    output [31:0]   data_sram_wdata,
    input           data_sram_addr_ok,
    input           data_sram_data_ok,
    input  [31:0]   data_sram_rdata,    
    // output          data_sram_en,
    // output [ 3:0]   data_sram_wen,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn; 
//handshake
    wire         ds_allowin;
    wire         es_allowin;
    wire         ms_allowin;
    wire         ws_allowin;
    wire         fs_to_ds_valid;
    wire         ds_to_es_valid;
    wire         es_to_ms_valid;
    wire         ms_to_ws_valid;
//BUS
    wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
    wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
    wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
    wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
    wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
    wire [`BR_BUS_WD       -1:0] br_bus;
    wire [`DATA_RISK_BUS   -1:0] DATA_RISK_BUS;
//DATA RISK
    wire [4:0]  exe_waddr;
    wire [4:0]  mem_waddr;
    wire [4:0]  wb_waddr;
    wire        exe_mem_load;
    wire [4:0]  exe_mem_waddr;
    wire [31:0] exe_wdata;
    wire [31:0] mem_mem_result;
    assign DATA_RISK_BUS = {exe_waddr, 
                            mem_waddr, 
                            wb_waddr, 
                            exe_mem_load, 
                            exe_mem_waddr, 
                            exe_wdata, 
                            mem_mem_result, 
                            debug_wb_rf_wdata};
                        //   5          5          5          1           5                32              32                32
//CSR
    //READ & WRITE
    wire [31:0] csr_rvalue_cntid_top;
wire csr_re_id;
wire has_int_top;
wire [7:0] hw_int_in_top = 8'b0;
wire ipi_int_in_top = 1'b0;
wire [31:0] csr_rvalue;
wire [31:0] csr_rvalue_cntvl_top;
wire [31:0] csr_rvalue_cntvh_top;
wire [31:0] csr_rvalue_eentry_top;
wire [31:0] csr_wmask;
wire [13:0] csr_num_exe;
wire [13:0] csr_num_mem;
wire csr_re_cntvl_top;
wire csr_re_cntvh_top;
wire csr_we_exe;
wire csr_we_mem;
wire csr_we_wb;
wire [13:0] csr_num_id_top;
wire [31:0] csr_wvalue_wb;
wire [13:0] csr_num_wb;
wire [31:0] csr_wmask_wb;
wire [31:0] ertn_era_wb;
wire [31:0] eentry_wb;
wire [31:0] wb_vaddr;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;
wire [31:0] wb_pc;
wire ertn_flush_wb_top;
wire wb_ex_top;
wire clear_top = ertn_flush_wb_top || wb_ex_top;

wire mem_ex_top;
wire exe_ex_top;
wire clear_exe_top = mem_ex_top || wb_ex_top || ertn_flush_wb_top;
wire ertn_flush_mem_top;
wire inst_rdcntid_exe_top;
wire inst_rdcntid_mem_top;
wire inst_rdcntid_wb_top;
wire id_risk_rdcntid_top =  inst_rdcntid_exe_top | 
                            inst_rdcntid_mem_top | 
                            inst_rdcntid_wb_top ;
wire go_top;
wire ds_go_top;
wire exe_go_top;
wire [31:0] if_pc_top;
wire [31:0] id_pc_top;
wire [31:0] exe_pc_top;
wire [31:0] mem_pc_top;
wire [31:0] wb_pc_top;
wire flag_data_ok_top;
// CSR
    CSR CSR(
        .csr_rvalue_eentry  (csr_rvalue_eentry_top  ),
        .csr_rvalue_cntid   (csr_rvalue_cntid_top   ),
        .csr_rvalue_cntvl   (csr_rvalue_cntvl_top   ),
        .csr_rvalue_cntvh   (csr_rvalue_cntvh_top   ),
        .clk                (clk                    ),
        .ertn_flush         (ertn_flush_wb_top      ),
        .reset              (reset                  ),
        .csr_re             (csr_re_id              ),
        .csr_we             (csr_we_wb              ),
        .has_int            (has_int_top            ),
        .hw_int_in          (hw_int_in_top          ),
        .ipi_int_in         (ipi_int_in_top         ),
        .wb_vaddr           (wb_vaddr               ),
        .wb_ecode           (wb_ecode               ),
        .wb_esubcode        (wb_esubcode            ),
        .wb_pc              (wb_pc                  ),
        .wb_ex              (wb_ex_top              ),
        .csr_num_r          (csr_num_id_top         ),
        .csr_num            (csr_num_wb             ),
        .csr_rvalue         (csr_rvalue             ),
        .csr_wvalue         (csr_wvalue_wb          ),
        .csr_wmask          (csr_wmask_wb           ) 
    );
// IF stage
    if_stage if_stage(
        .ertn_era_if    (ertn_era_wb        ),  
        .eentry_wb      (eentry_wb          ),
        .clear_w        (clear_top          ),
        .wb_ex          (wb_ex_top          ),
        .ertn_flush_wb  (ertn_flush_wb_top  ),

        .clk            (clk                ),
        .reset          (reset              ),
        //allowin
        .ds_allowin     (ds_allowin         ),
        //brbus
        .br_bus         (br_bus             ),
        //outputs
        .fs_to_ds_valid (fs_to_ds_valid     ),
        .fs_to_ds_bus   (fs_to_ds_bus       ),
        // inst sram interface
        // .inst_sram_en   (inst_sram_en       ),
        // .inst_sram_wen  (inst_sram_wen      ),
        .inst_sram_req    (inst_sram_req    ),
        .inst_sram_wr     (inst_sram_wr     ),
        .inst_sram_size   (inst_sram_size   ),
        .inst_sram_wstrb  (inst_sram_wstrb  ),
        .inst_sram_addr   (inst_sram_addr   ),
        .inst_sram_wdata  (inst_sram_wdata  ),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata  (inst_sram_rdata  )        
    );
// ID stage
    wire [13:0] csr_num_exe_risk = csr_num_exe & {14{csr_we_exe}};
    wire [13:0] csr_num_mem_risk = csr_num_mem & {14{csr_we_mem}};
    wire [13:0] csr_num_wb_risk = csr_num_wb  & {14{csr_we_wb}};
    id_stage id_stage(
        .inst_rdcntid_exe (inst_rdcntid_exe_top),
        .inst_rdcntid_mem (inst_rdcntid_mem_top),
        .inst_rdcntid_wb  (inst_rdcntid_wb_top ),
        .flag_data_ok   (flag_data_ok_top   ),
        .ds_go          (ds_go_top          ),
        .data_sram_data_ok (data_sram_data_ok),
        .ms_pc          (mem_pc_top         ),
        .es_pc          (exe_pc_top         ),
        .ws_pc          (wb_pc_top          ),
        .ds_pc          (id_pc_top          ),
        .exe_go         (exe_go_top         ),
    //CSR
        //in
        .has_int        (has_int_top        ),
        .mem_ex         (mem_ex_top         ),
        .exe_ex         (exe_ex_top         ),
        .csr_we_exe     (csr_we_exe         ),
        .csr_we_mem     (csr_we_mem         ),
        .csr_we_wb      (csr_we_wb          ),
        .clear_w        (clear_top          ),
        .csr_num_exe    (csr_num_exe_risk   ),
        .csr_num_mem    (csr_num_mem_risk   ),
        //out
        .csr_rvalue     (csr_rvalue         ),
        .csr_num_id     (csr_num_id_top     ),
        .csr_num_wb     (csr_num_wb_risk    ),
    //DATA_RISK_BUS
        .DATA_RISK_BUS  (DATA_RISK_BUS      ),
        .clk            (clk                ),
        .reset          (reset              ),
    //allowin
        .es_allowin     (es_allowin         ),
        .ds_allowin     (ds_allowin         ),
    //from fs
        .fs_to_ds_valid (fs_to_ds_valid     ),
        .fs_to_ds_bus   (fs_to_ds_bus       ),
    //to es
        .ds_to_es_valid (ds_to_es_valid     ),
        .ds_to_es_bus   (ds_to_es_bus       ),
    //to fs
        .br_bus         (br_bus             ),
    //to rf: for write back
        .ws_to_rf_bus   (ws_to_rf_bus       )
    );
// EXE stage
    exe_stage exe_stage(
        .ds_go              (ds_go_top          ),
        .es_pc              (exe_pc_top         ),
        .exe_go             (exe_go_top         ),
        //out
        .inst_rdcntid_exe   (inst_rdcntid_exe_top),
        .csr_rvalue_cntvh   (csr_rvalue_cntvh_top),
        .csr_rvalue_cntvl   (csr_rvalue_cntvl_top),
        .exe_ex         (exe_ex_top         ),
        .csr_we_exe     (csr_we_exe         ),
        .csr_num_exe    (csr_num_exe        ),
        //in
        .ertn_flush_mem (ertn_flush_mem_top ),
        .mem_ex         (mem_ex_top         ),
        .wb_ex          (wb_ex_top          ),
        .clear_w        (clear_exe_top      ),
        //DATA_RISK_BUS
        .exe_waddr      (exe_waddr      ),
        .exe_mem_load   (exe_mem_load   ),
        .exe_mem_waddr  (exe_mem_waddr  ),
        .exe_wdata (exe_wdata ),
        .clk            (clk            ),
        .reset          (reset          ),
        //allowin
        .ms_allowin     (ms_allowin     ),
        .es_allowin     (es_allowin     ),
        //from ds
        .ds_to_es_valid (ds_to_es_valid ),
        .ds_to_es_bus   (ds_to_es_bus   ),
        //to ms
        .es_to_ms_valid (es_to_ms_valid ),
        .es_to_ms_bus   (es_to_ms_bus   ),
        // data sram interface
        // .data_sram_en   (data_sram_en   ),
        // .data_sram_wen  (data_sram_wen  ),
        .data_sram_req    (data_sram_req    ),
        .data_sram_wr     (data_sram_wr     ),
        .data_sram_size   (data_sram_size   ),
        .data_sram_wstrb  (data_sram_wstrb  ),
        .data_sram_addr   (data_sram_addr   ),
        .data_sram_wdata  (data_sram_wdata  ),
        .data_sram_addr_ok(data_sram_addr_ok)
    );
// MEM stage
    //0x000d0000 and d01d0000 ??
    mem_stage mem_stage(        
        .flag_data_ok_w     (flag_data_ok_top   ),
        .ms_pc              (mem_pc_top),
        .inst_rdcntid_mem   (inst_rdcntid_mem_top),
        .ertn_flush_mem (ertn_flush_mem_top ),
        .mem_ex         (mem_ex_top     ),
        .clear_w        (clear_top      ),
        .csr_we_mem     (csr_we_mem ),
        .csr_num_mem    (csr_num_mem),
        //DATA_RISK_BUS
        .mem_waddr      (mem_waddr      ),
        .mem_mem_result (mem_mem_result ),
        .clk            (clk            ),
        .reset          (reset          ),
        //allowin
        .ws_allowin     (ws_allowin     ),
        .ms_allowin     (ms_allowin     ),
        //from es
        .es_to_ms_valid (es_to_ms_valid ),
        .es_to_ms_bus   (es_to_ms_bus   ),
        //to ws
        .ms_to_ws_valid (ms_to_ws_valid ),
        .ms_to_ws_bus   (ms_to_ws_bus   ),
        //from data-sram
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata  (data_sram_rdata  )
    );
// WB stage
    wb_stage wb_stage(
        .ws_pc                  (wb_pc_top              ),
        //to CSR
            //out
            .inst_rdcntid_wb   (inst_rdcntid_wb_top),
            .csr_rvalue_eentry  (csr_rvalue_eentry_top  ),
            .eentry_wb          (eentry_wb              ),
            .wb_ex              (wb_ex_top              ),
            .csr_wmask_wb       (csr_wmask_wb           ),
            .csr_we_wb          (csr_we_wb              ),
            .csr_num_wb         (csr_num_wb             ),
            .csr_wvalue_wb      (csr_wvalue_wb          ),
            .ertn_era_wb        (ertn_era_wb            ),
            .ertn_flush_wb      (ertn_flush_wb_top      ),
            .wb_vaddr           (wb_vaddr               ),
            .wb_pc              (wb_pc                  ),
            .wb_ecode           (wb_ecode               ),
            .wb_esubcode        (wb_esubcode            ),
            //in
            .csr_rvalue_cntid   (csr_rvalue_cntid_top),
        //DATA_RISK_BUS
        .wb_waddr       (wb_waddr       ),
        .clk            (clk            ),
        .reset          (reset          ),
        //allowin
        .ws_allowin     (ws_allowin     ),
        //from ms
        .ms_to_ws_valid (ms_to_ws_valid ),
        .ms_to_ws_bus   (ms_to_ws_bus   ),
        //to rf: for write back
        .ws_to_rf_bus   (ws_to_rf_bus   ),
        //trace debug interface
        .debug_wb_pc      (debug_wb_pc      ),
        .debug_wb_rf_wen  (debug_wb_rf_wen  ),
        .debug_wb_rf_wnum (debug_wb_rf_wnum ),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

endmodule
