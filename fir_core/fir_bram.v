`include "bram11.v"
module fir_bram #(
    parameter N = 11,       // 滤波器阶数
    parameter WIDTH = 32    // 数据宽度
)(
    input clk,
    input rst,
    input signed [WIDTH-1:0] x_in,   // 输入信号
    output reg signed [WIDTH-1:0] y_out,// 滤波器输出

    input [31:0] tap_ram_in,
    input [3:0] tap_ram_we
);  

    // RAM 接口信号定义
    reg [11:0] data_ram_addr;  // 数据 RAM 地址
    reg [11:0] tap_ram_addr;   // 系数 RAM 地址 
    reg [31:0] data_ram_in;    // 数据 RAM 输入
    reg [3:0] data_ram_we;     // 数据 RAM 写使能
    reg data_ram_en;           // 数据 RAM 使能
    reg tap_ram_en;            // 系数 RAM 使能
    wire [31:0] data_ram_out;  
    wire [31:0] tap_ram_out;   

    // 实例化 data_ram
    bram11 data_ram_inst (
        .CLK(clk),
        .WE(data_ram_we),
        .EN(data_ram_en),
        .Di(data_ram_in),
        .Do(data_ram_out),
        .A(data_ram_addr)
    );

    // 实例化 tap_ram
    bram11 tap_ram_inst (
        .CLK(clk),
        .WE(tap_ram_we),
        .EN(tap_ram_en),
        .Di(tap_ram_in),
        .Do(tap_ram_out),
        .A(tap_ram_addr)
    );
    // 内部信号
    reg signed [WIDTH-1:0] y_acc;  // 累加器
    integer i;
    //滑动窗口指针
    reg [11:0] write_ptr;  // 当前写入地址
    // 滤波器逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位时清零
            write_ptr <= 0;
            y_acc <= 0;
            y_out <= 0;
        end else begin
            // 累加器清零
            y_acc = 0;  // 使用阻塞赋值，用于在同一周期内计算

            // 写入新输入到 data_ram
            data_ram_en <= 1;       // 启用 data_ram
            data_ram_we <= 4'b1111; // 开启所有字节写入
            data_ram_in <= x_in;    // 输入写入 data_ram
            data_ram_addr <= write_ptr;     // 写入地址为 0

            // 更新写指针（循环地址）
            write_ptr <= (write_ptr + 1) % N;

            // 累加计算
            for (i = 0; i < N; i = i + 1) begin
                // 读取 data_ram 和 tap_ram
                data_ram_addr <= (write_ptr - i + N) % N;  // 循环读取滑动窗口数据
                tap_ram_addr <= write_ptr;  // 读取对应系数
                data_ram_en <= 1'b1;
                tap_ram_en <= 1'b1;

                // 等待读取完成（假设组合逻辑读取）
                y_acc = y_acc + $signed(data_ram_out) * $signed(tap_ram_out);
            end

            // 输出结果
            y_out <= y_acc;  // 非阻塞赋值，确保输出在下一个周期更新
        end
    end
endmodule