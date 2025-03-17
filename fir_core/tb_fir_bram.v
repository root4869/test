`timescale 1ns / 1ps
`include "fir_bram.v"
module fir_bram_tb;

    // 参数定义
    parameter CLK_PERIOD = 10;  // 时钟周期为 10ns
    parameter N = 11;           // 滤波器阶数
    parameter WIDTH = 32;       // 数据宽度
    parameter TRIANGLE_AMPLITUDE = 20; // 三角波幅值（范围 -10 到 10）
    parameter TRIANGLE_STEP = 1;      // 三角波步长

    // 测试信号
    reg clk;
    reg rst;
    reg signed [WIDTH-1:0] x_in;   // 输入信号
    wire signed [WIDTH-1:0] y_out; // 输出信号
    reg [31:0] tap_ram_in;         // 系数输入
    reg [3:0] tap_ram_we;          // 系数写使能
    reg [31:0] coeffs [0:N-1];
    reg direction;
    // 实例化被测模块
    fir_bram #(
        .N(N),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .x_in(x_in),
        .y_out(y_out),
        .tap_ram_in(tap_ram_in),
        .tap_ram_we(tap_ram_we)
    );

    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // 初始块
    initial begin
    $dumpfile("fir_bram_tb.vcd");
    $dumpvars(0, fir_bram_tb);
        // 初始化信号
        clk = 0;
        rst = 1;
        x_in = 0;
        tap_ram_in = 0;

        // 复位
        #(2 * CLK_PERIOD);
        rst = 0;

        // 初始化系数（按指定模式）
     
        coeffs[0]  = 16'sd1;   
        coeffs[1]  = 16'sd2;  
        coeffs[2]  = 16'sd3;   
        coeffs[3]  = 16'sd4;
        coeffs[4]  = 16'sd5;   
        coeffs[5]  = 16'sd6;  
        coeffs[6]  = 16'sd5;   
        coeffs[7]  = 16'sd4;
        coeffs[8]  = 16'sd3;   
        coeffs[9]  = 16'sd2;  
        coeffs[10] = 16'sd1;  
        tap_ram_we = 4'b1111; // 写入系数到 tap_ram
        // 写入系数到 tap_ram
        for (integer i = 0; i < N; i = i + 1) begin
            @(posedge clk);
            tap_ram_in = coeffs[i]; // 写入系数
        end

        $display("Starting test with triangular wave input...");
        x_in = 0;
        direction = 1; // 方向标志：1 表示递增，0 表示递减

        for (integer i = 0; i < 50; i = i + 1) begin
            @(posedge clk);

            // 更新三角波值
            if (direction == 1) begin
                x_in = x_in + TRIANGLE_STEP;
                if (x_in >= TRIANGLE_AMPLITUDE) begin
                    direction = 0; // 切换方向
                end
            end else begin
                x_in = x_in - TRIANGLE_STEP;
                if (x_in <= 0) begin
                    direction = 1; // 切换方向
                end
            end
            // 打印当前时间、输入值和输出值
            $display("Time %0t: x_in = %d, y_out = %d", $time, x_in, y_out);
        end

        // 运行一段时间后结束仿真
        #(100 * CLK_PERIOD);
        $stop;
    end

endmodule