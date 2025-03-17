    `timescale 1ns / 1ps
    `include "reference.v "
    module reference_tb
    #(  parameter pADDR_WIDTH = 12,
        parameter pDATA_WIDTH = 32,
        parameter Tape_Num    = 11,
        parameter Data_Num    = 11  
    )();
    
    //---------------------- AXI-Lite信号 ----------------------
    wire                        awready;
    wire                        wready;
    reg                         awvalid;
    reg   [(pADDR_WIDTH-1):0]   awaddr;
    reg                         wvalid;
    reg  signed [(pDATA_WIDTH-1):0] wdata;
    
    wire                        arready;
    reg                         rready;
    reg                         arvalid;
    reg   [(pADDR_WIDTH-1):0]   araddr;
    wire                        rvalid;
    wire signed [(pDATA_WIDTH-1):0] rdata;
    
    //---------------------- AXI-Stream信号 ----------------------
    reg                         ss_tvalid;
    reg  signed [(pDATA_WIDTH-1):0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    
    reg                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(pDATA_WIDTH-1):0] sm_tdata;
    wire                        sm_tlast;
    
    //---------------------- 时钟与复位 ----------------------
    reg                         axis_clk;
    reg                         axis_rst_n;
    
    //---------------------- BRAM接口 ----------------------
    // Tap RAM
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;
    
    // Data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;
    
    //---------------------- DUT实例化 ----------------------
    reference #(
        .pADDR_WIDTH(pADDR_WIDTH),
        .pDATA_WIDTH(pDATA_WIDTH),
        .Tape_Num(Tape_Num),
        .Data_Num(Data_Num)
    ) fir_DUT (
        // AXI-Lite
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        // AXI-Stream
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),
        // Tap RAM
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),
        // Data RAM
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),
        // Clock & Reset
        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)
    );
    
    //---------------------- BRAM 实例化 ----------------------
    bram11 tap_RAM (
        .CLK(axis_clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );
    
    bram11 data_RAM(
        .CLK(axis_clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );
    
    //---------------------- 时钟 & 复位产生 ----------------------
    initial begin
        $dumpfile("reference.vcd");
        $dumpvars(0, reference_tb);
        axis_clk = 1'b0;
        forever #5 axis_clk = ~axis_clk;  // 10ns周期
    end
    
    initial begin
        axis_rst_n = 1'b0;
        #20;          // 保持复位一段时间
        axis_rst_n = 1'b1;
    end
    
    //---------------------- 手动定义：11个系数/输入/期望输出 ----------------------
    // 1) 系数
    reg signed [31:0] coef [0:11];
    initial begin
        coef[0]  =  32'd1;
        coef[1]  =  32'd2;
        coef[2]  =  32'd3;
        coef[3]  =  32'd4;
        coef[4]  =  32'd5;
        coef[5]  =  32'd6;
        coef[6]  =  32'd7;
        coef[7]  =  32'd8;
        coef[8]  =  32'd9;
        coef[9]  =  32'd10;
        coef[10] =  32'd11;
        coef[11] =  32'd12;
    end
    
    // 2) 输入数据
    reg signed [31:0] data_in [0:11];
    initial begin
        data_in[0]  =  32'd1;
        data_in[1]  =  32'd2;
        data_in[2]  =  32'd3;
        data_in[3]  =  32'd4;
        data_in[4]  =  32'd5;
        data_in[5]  =  32'd6;
        data_in[6]  =  32'd7;
        data_in[7]  =  32'd8;
        data_in[8]  =  32'd9;
        data_in[9]  =  32'd10;
        data_in[10] =  32'd11;
        data_in[11] =  32'd12;
    end
    
   
    //---------------------- 主测试流程 ----------------------
    integer i;
    integer j;
    
    // 1) 配置 & 系数写入 & 启动
    initial begin

        // 默认拉低AXI-Lite信号
        awvalid = 0; wvalid = 0; arvalid = 0; rready = 0; awaddr = 0; wdata = 0; araddr=0;
        sm_tready = 1;  // 随时准备接收输出
        ss_tvalid = 0; ss_tlast=0; ss_tdata=0;
    
        wait(axis_rst_n);  // 等待复位结束
        #10;
        $display("---- START FIR ----");
        config_write(12'h00, 32'd1);
            
        $display("---- Write data_length = 11 ----");
        config_write(12'h10, 32'd11);
        
        $display("---- Write number of taps = 11 ----");
        config_write(12'h14, 32'd11);
    
        $display("---- Write 11 Taps (0x80, 0x84, ...) ----");
        for(j=0; j<12; j=j+1) begin
            config_write(12'h80 + 4*j, coef[j]);
        end

    end
    
    // 2) AXI-Stream 输入数据
    initial begin
        wait(axis_rst_n);
        #50;
        $display("---- Send 11 input samples via AXI-Stream ----");
    
        for(i=0; i<11; i=i+1) begin
            ss_tlast = 0;
            ss_send_data(data_in[i]);
        end
        // 最后一个数据带 tlast=1
        ss_tlast = 1;
        ss_send_data(data_in[10]);
    
        $display("---- All input data sent ----");
        ss_tvalid = 0;
        ss_tlast  = 0;
    end
    
  
    
    //---------------------- 任务(task)：AXI-Lite写/读+比较, AXI-Stream发送/接收 ----------------------
    task config_write;
        input [11:0] addr;
        input [31:0] data;
    begin
        @(posedge axis_clk);
        awvalid <= 1; awaddr <= addr;
        wvalid  <= 1; wdata  <= data;
        
         @(posedge axis_clk);
        
        // **等待 `wready` 信号**
        while (!wready) @(posedge axis_clk);
        
        awvalid <= 0;
        wvalid <= 0;
    end
    endtask

    // 发送一拍AXI-Stream数据
    task ss_send_data;
        input signed [31:0] dval;
    begin
        ss_tvalid <= 1;
        ss_tdata  <= dval;
        
         @(posedge axis_clk);
        
        while (!ss_tready) @(posedge axis_clk);
        
        ss_tvalid <= 0;
    end
    endtask

    integer timeout = 100000;
    initial begin
        while(timeout>0) begin
            @(posedge axis_clk);
            timeout = timeout -1;
        end
        $display("** TIMEOUT: Simulation hangs **");
        $finish;
    end

    
    endmodule