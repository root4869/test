module fir #(
    parameter N = 11,       // 滤波器阶数 + 1
    parameter WIDTH = 32   // 数据宽度
)(
    input clk,
    input rst,
    input signed [WIDTH-1:0] x_in,   // 输入信号（有符号数）
    output reg signed [WIDTH-1:0] y_out // 滤波器输出（有符号数）
);

    // 系数定义（可以根据需求更改）
    reg signed [WIDTH-1:0] coeffs [0:N-1];
    initial begin
        coeffs[0] = 16'sd1;   
        coeffs[1] = 16'sd2;  
        coeffs[2] = 16'sd3;   
        coeffs[3] = 16'sd4;
        coeffs[4] = 16'sd5;   
        coeffs[5] = 16'sd6;  
        coeffs[6] = 16'sd5;   
        coeffs[7] = 16'sd4;
        coeffs[8] = 16'sd3;   
        coeffs[9] = 16'sd2;  
        coeffs[10] = 16'sd1;    
    end

    // 滑动窗口的寄存器，用于存储最近的 N 个输入值
    reg signed [WIDTH-1:0] shift_reg [0:N-1];
    reg signed [WIDTH-1:0] y_acc;  // 累加器（有符号数）
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位时清零
            for (i = 0; i < N; i = i + 1) begin
                shift_reg[i] <= 0;
            end
            y_acc <= 0;
            y_out <= 0;
        end else begin
            // 累加器清零
            y_acc = 0;  // 使用阻塞赋值，确保在同一周期内清零

            // 滑动窗口更新
            for (i = N-1; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= x_in;

            // 计算累加结果
            for (i = 0; i < N; i = i + 1) begin
                y_acc = y_acc + coeffs[i] * shift_reg[i];  // 使用阻塞赋值
            end

            // 输出结果
            y_out <= y_acc;  // 非阻塞赋值，确保输出在下一个周期更新
        end
    end
endmodule