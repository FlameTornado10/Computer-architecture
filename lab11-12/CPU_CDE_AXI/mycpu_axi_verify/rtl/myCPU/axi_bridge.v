module axi_warp_bridge (
    input          aclk,
    input          aresetn,

    input          inst_sram_req,
    input          inst_sram_wr,
    input [1 :0]   inst_sram_size,
    input [3 :0]   inst_sram_wstrb,
    input [31:0]   inst_sram_addr,
    input [31:0]   inst_sram_wdata,
    output         inst_sram_addr_ok,
    output         inst_sram_data_ok,
    output[31:0]   inst_sram_rdata, 

    input          data_sram_req,
    input          data_sram_wr,
    input [1 :0]   data_sram_size,
    input [3 :0]   data_sram_wstrb,
    input [31:0]   data_sram_addr,
    input [31:0]   data_sram_wdata,
    output         data_sram_addr_ok,
    output         data_sram_data_ok,
    output[31:0]   data_sram_rdata, 
//读请求
    output [3 :0]  arid,
    output [31:0]  araddr,
    output [7 :0]  arlen,
    output [2 :0]  arsize,
    output [1 :0]  arburst,
    output [1 :0]  arlock,
    output [3 :0]  arcache,
    output [2 :0]  arprot,
    output         arvalid,
    input          arready,
//读响应
    input [3 :0]   rid,
    input [31:0]   rdata,
    input [1 :0]   rresp,
    input          rlast,
    input          rvalid,
    output         rready,
//写请求
    output [3 :0]  awid,
    output [31:0]  awaddr,
    output [7 :0]  awlen,
    output [2 :0]  awsize,
    output [1 :0]  awburst,
    output [1 :0]  awlock,
    output [3 :0]  awcache,
    output [2 :0]  awprot,
    output         awvalid,
    input          awready,
//写数据
    output [3 :0]  wid,
    output [31:0]  wdata,
    output [3 :0]  wstrb,
    output         wlast,
    output         wvalid,
    input          wready,
//写响应
    input [3 :0]   bid,
    input [1 :0]   bresp,
    input          bvalid,
    output         bready
);
    //read request 读请求
    reg inst_wait; //have request  inst_sram and wait for response
    wire inst_read;
    wire data_read;
    //write request 写请求
    reg aw_finish;
    reg w_finish;
    wire data_write;
    wire aw_shaking;
    wire w_shaking;


    assign inst_read = inst_sram_req && !inst_sram_wr;
    assign data_read = data_sram_req && !data_sram_wr;
    always @(posedge aclk) begin
        if (!aresetn)
            inst_wait <= 1'b0;
        else if(inst_read && !data_read && !arready)
            inst_wait <= 1'b1;
        else if(arready)
            inst_wait <= 1'b0;
    end
    assign arid     = inst_wait? 4'd0 :
                    data_read? 4'd1 : 4'd0;
    assign araddr   = inst_wait? inst_sram_addr :
                    data_read? data_sram_addr : inst_sram_addr;
    assign arlen    = 8'd0;
    assign arsize   = inst_wait? {1'b0, inst_sram_size} :
                    data_read? {1'b0, data_sram_size} : {1'b0, inst_sram_size};
    assign arburst  = 2'b01;
    assign arlock   = 2'd0;
    assign arcache  = 4'd0;
    assign arprot   = 3'd0;
    assign arvalid  = aresetn && (inst_read || data_read);
    assign inst_sram_addr_ok = (arid == 4'd0) && arready;
    assign data_sram_addr_ok = (arid == 4'd1) && arready || (awready || aw_finish) && (wready || w_finish);

    //read and write response 读响应 写相应
    assign inst_sram_data_ok = (rid == 4'd0) && rvalid;
    assign data_sram_data_ok = (rid == 4'd1) && rvalid || (bid == 4'd1) && bvalid;
    assign inst_sram_rdata = {32{rid == 4'd0}} & rdata;
    assign data_sram_rdata = {32{rid == 4'd1}} & rdata;
    assign rready = 1'b1;
    assign bready = 1'b1;

    //write request 写请求
    always @(posedge aclk) begin
        if(!aresetn)
            aw_finish <= 1'b0;
        else if(aw_shaking && !w_shaking && !w_finish)
            aw_finish <= 1'b1;
        else if(w_shaking)
            aw_finish <= 1'b0;
    end
    always @(posedge aclk) begin
        if(!aresetn)
            w_finish <= 1'b0;
        else if(w_shaking && !aw_shaking && !aw_finish)
            w_finish <= 1'b1;
        else if(aw_shaking)
            w_finish <= 1'b0;
    end
    assign data_write = data_sram_req && data_sram_wr;
    assign aw_shaking = awvalid && awready;
    assign w_shaking = wvalid && wready;
    assign awid     = 4'd1;
    assign awaddr   = data_sram_addr;
    assign awlen    = 8'd0;
    assign awsize   = {1'b0, data_sram_size};
    assign awburst  = 2'b01;
    assign awlock   = 2'd0;
    assign awcache  = 4'd0;
    assign awprot   = 3'd0;
    assign awvalid  = aresetn && data_write && !aw_finish;
    assign wid      = 4'd1;
    assign wdata    = data_sram_wdata;
    assign wstrb    = data_sram_wstrb;
    assign wlast    = 1'b1;
    assign wvalid   = aresetn && data_write && !w_finish;

endmodule