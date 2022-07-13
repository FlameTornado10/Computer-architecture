`include "mycpu.h"

module if_stage(
    //Like SRAM
    output fs_go,
    output req,
    input addr_ok_if,
    input data_ok_if,
    //CSR
    input  clear_w,
    input  ertn_flush_wb,
    input [31:0] ertn_era_if,
    input [31:0] eentry_wb,
    input wb_ex,
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    // output        inst_sram_en   ,
    // output [ 3:0] inst_sram_wen  ,
    output          inst_sram_req,      //M
    output          inst_sram_wr,       
    output [1 :0]   inst_sram_size,     //M
    output [3 :0]   inst_sram_wstrb,    
    output [31:0]   inst_sram_addr,     //M
    output [31:0]   inst_sram_wdata,
    input           inst_sram_addr_ok,  //M
    input           inst_sram_data_ok,  //M
    input  [31:0]   inst_sram_rdata     //M
);
reg do_fs;
wire do_w;
reg do_r;
wire do = do_w | do_r;
reg clear_r;
wire clear;
wire        fs_allowin;
wire        fs_ready_go;
assign inst_sram_size = 2'h2;
wire [31:0] fs_inst;
reg [31:0] fs_inst_cache;
reg if_handshake_r;
reg pre_if_handshake_r;
wire if_handshake_w = inst_sram_data_ok  & !if_handshake_r;
wire pre_if_handshake_w = inst_sram_req & inst_sram_addr_ok  & !pre_if_handshake_r;
reg flag_if_id;
reg flag_preif_if;
reg flag_addr_ok;
reg flag_change;
wire if_handshake = if_handshake_w || if_handshake_r;
wire pre_if_handshake = pre_if_handshake_w || pre_if_handshake_r;
//exeception
wire exec_ADEF;
//pipeline
wire        pre_if_ready_go = pre_if_handshake;
reg         fs_valid;
wire        to_fs_valid;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire [31:0] nextpc_temp;
reg [31:0] nextpc_r;
wire         br_stall;
wire         br_taken;
wire [ 31:0] br_target;

reg  [31:0] fs_pc;
wire [31:0] fs_inst_mux;
assign fs_inst_mux = flag_if_id ? fs_inst_cache : fs_inst;
assign fs_to_ds_bus = {
                    do_fs, 
                    nextpc,
                    exec_ADEF,
                    fs_inst_mux ,
                    fs_pc   };
assign inst_sram_wr = 1'b0;
always @(posedge clk) begin
    if(reset)begin
        do_r <= 1'b0;
        clear_r <= 1'b0;
    end
    else begin
        if(clear_w)begin
            clear_r <= 1'b1;
        end
        if(to_fs_valid)begin
            clear_r <= 1'b0;
        end
        if(do_w)begin
            do_r <= 1'b1;
        end
        if(fs_go && !clear)begin
            do_r <= 1'b0;
        end
    end
end
assign clear = clear_w | clear_r;
always @(posedge clk) begin
    if(reset)begin
        flag_change <= 1'b0;
        flag_addr_ok <= 1'b0;
    end
    else begin
        if(inst_sram_addr_ok)begin
            flag_addr_ok <= 1'b1;
        end
        else begin
            flag_addr_ok <= 1'b0;
        end 
        if(br_taken || ertn_flush_wb || wb_ex)begin
            flag_change <= 1'b1;
            nextpc_r <= nextpc_temp;
        end
        if(to_fs_valid && fs_allowin && !clear)
            flag_change <= 1'b0;
    end
end
reg clear_flag;
always @(posedge clk) begin
    if(reset)
        clear_flag <= 1'b0;
    else begin
        if(fs_go)begin
            if(clear)
                clear_flag <= 1'b1;
            else 
                clear_flag <= 1'b0;
        end        
    end
end
always @(posedge clk) begin
    if(reset)begin
        flag_if_id <= 1'b0;
    end 
    else if(fs_ready_go & !ds_allowin &!flag_if_id)begin
        flag_if_id <= 1'b1;
        fs_inst_cache <= fs_inst;
    end
    else if(fs_ready_go & ds_allowin)begin
        flag_if_id <= 1'b0;
    end
    if(fs_go)
        flag_if_id <= 1'b0;
    if(clear)
        flag_if_id <= 1'b0;
end
//pre-if 
assign inst_sram_req = (!pre_if_handshake_r & fs_allowin) &~reset & !br_stall;
always @(posedge clk) begin
    if(reset)begin
        if_handshake_r <= 1'b0;
        pre_if_handshake_r <= 1'b0;
    end
    else begin
        if(if_handshake_w)
            if_handshake_r <= 1'b1;
        if(pre_if_handshake_w)
            pre_if_handshake_r <= 1'b1;
        if(fs_go)begin
            if_handshake_r <= 1'b0;
            pre_if_handshake_r <= 1'b0;
        end 
        if(!fs_valid && fs_allowin)
            pre_if_handshake_r <= 1'b0;
    end
end
assign {br_stall,br_taken,br_target} = br_bus;
// pre-IF stage
assign to_fs_valid  = ~reset && pre_if_ready_go;
assign seq_pc       = fs_pc + 3'h4;

wire normal_situation_if = !ertn_flush_wb && !wb_ex && !br_taken;
assign nextpc_temp       =   ertn_flush_wb? (ertn_era_if):
                    ( ( wb_ex    ? eentry_wb:
                    ( ( br_taken ? br_target:
                    (   seq_pc  )))));                     
assign do_w = ertn_flush_wb || wb_ex || br_taken;  //保证必要执行的访存指令不被mem阶段异常取消   
                        //{32{ertn_flush_wb   }}    & (ertn_era_if)    |         //下划线？？？
                        //{32{wb_ex           }}    & (eentry_wb)      |
                        //{32{br_taken & !wb_ex}}   & br_target        |
                        //{32{normal_situation_if}} & seq_pc;
assign nextpc = flag_change ? nextpc_r : nextpc_temp;
// IF stage
assign fs_ready_go    = if_handshake;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !clear && !clear_flag;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin && !clear) begin
        fs_pc <= nextpc;
        do_fs <= do;
    end
end
assign fs_go = to_fs_valid && fs_allowin;
assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;
assign exec_ADEF = (fs_pc[1:0] != 2'b0);

endmodule
