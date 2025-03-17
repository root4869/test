`timescale 1ns / 1ps
`include "fir.v"
module fir_tb;

    // 参数定义
    parameter N = 11;        // 滤波器阶数 + 1
    parameter WIDTH = 32;    // 数据宽度
    parameter CLK_PERIOD = 10; // 时钟周期为10ns
    parameter TRIANGLE_AMPLITUDE = 20; // 三角波幅值（范围 -10 到 10）
    parameter TRIANGLE_STEP = 1;      // 三角波步长

    // 测试信号
    reg clk;
    reg rst;
    reg direction;
    reg signed [WIDTH-1:0] x_in;
    wire signed [WIDTH-1:0] y_out;

    // 实例化被测模块
    fir #(
        .N(N),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .x_in(x_in),
        .y_out(y_out)
    );

    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // 测试过程
    initial begin
    $dumpfile("fir_tb.vcd");
    $dumpvars(0, fir_tb);
        // 初始化信号
        clk = 0;
        rst = 1;
        x_in = 0;

        // 复位一段时间
        #(CLK_PERIOD * 2);
        rst = 0;

        // 生成三角波输入信号
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

        // 等待几个周期以观察输出稳定
        #(CLK_PERIOD * 5);

        // 结束仿真
        $display("Test completed.");
        $stop;
    end

endmodule