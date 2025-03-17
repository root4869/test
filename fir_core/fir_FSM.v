module fir_filter #(
    parameter N = 11,       // 滤波器阶数 + 1
    parameter WIDTH = 32    // 数据宽度
)(
    input clk,
    input rst,
    input signed [WIDTH-1:0] x_in,   // 输入信号
    output reg signed [WIDTH-1:0] y_out // 滤波器输出
);

    // 定义状态机状态
    typedef enum reg [2:0] {
        IDLE,           // 空闲状态
        LOAD_INPUT,     // 加载输入数据
        READ_COEFFS,    // 读取滤波器系数
        COMPUTE_OUTPUT, // 计算输出
        OUTPUT_RESULT   // 输出结果
    } state_t;
    state_t state, next_state;

    // 定义累加器
    reg signed [WIDTH-1:0] y_acc;
    integer i;

    // RAM 接口信号
    wire [31:0] data_ram_out;  // data_ram 的输出
    wire [31:0] tap_ram_out;   // tap_ram 的输出
    reg [31:0] data_ram_in;    // data_ram 的输入
    reg [31:0] tap_ram_in;     // tap_ram 的输入
    reg [11:0] data_ram_addr;  // data_ram 地址
    reg [11:0] tap_ram_addr;   // tap_ram 地址
    reg [3:0] data_ram_we;     // data_ram 写使能
    reg [3:0] tap_ram_we;      // tap_ram 写使能
    reg data_ram_en;           // data_ram 使能
    reg tap_ram_en;            // tap_ram 使能

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

    // 状态机逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位状态
            state <= IDLE;
        end else begin
            // 状态转移
            state <= next_state;
        end
    end

    always @(*) begin
        // 默认状态保持
        next_state = state;
        case (state)
            IDLE: begin
                // 空闲状态，等待输入信号
                next_state = LOAD_INPUT;
            end
            LOAD_INPUT: begin
                // 加载输入数据
                next_state = READ_COEFFS;
            end
            READ_COEFFS: begin
                // 读取滤波器系数
                next_state = COMPUTE_OUTPUT;
            end
            COMPUTE_OUTPUT: begin
                // 累加计算
                next_state = OUTPUT_RESULT;
            end
            OUTPUT_RESULT: begin
                // 输出结果
                next_state = IDLE;
            end
        endcase
    end

    // 控制逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位时清零
            y_acc <= 0;
            y_out <= 0;

            // RAM 控制信号复位
            data_ram_we <= 4'b0000;
            tap_ram_we <= 4'b0000;
            data_ram_en <= 0;
            tap_ram_en <= 0;

            data_ram_addr <= 0;
            tap_ram_addr <= 0;
        end else begin
            // 状态机操作
            case (state)
                IDLE: begin
                    // 清除控制信号
                    data_ram_we <= 4'b0000;
                    tap_ram_we <= 4'b0000;
                    data_ram_en <= 0;
                    tap_ram_en <= 0;
                end
                LOAD_INPUT: begin
                    // 将输入数据写入 data_ram
                    data_ram_en <= 1;
                    data_ram_we <= 4'b1111;
                    data_ram_in <= x_in;
                    data_ram_addr <= 0;

                    // 滑动窗口更新
                    for (i = N-1; i > 0; i = i - 1) begin
                        data_ram_addr <= i-1;
                        data_ram_en <= 1;
                        data_ram_we <= 4'b1111;
                        data_ram_in <= data_ram_out;
                        data_ram_addr <= i;
                    end
                end
                READ_COEFFS: begin
                    // 设置 tap_ram 地址，准备读取系数
                    tap_ram_en <= 1;
                    tap_ram_addr <= 0;
                end
                COMPUTE_OUTPUT: begin
                    // FIR 滤波计算
                    y_acc = 0;
                    for (i = 0; i < N; i = i + 1) begin
                        data_ram_addr <= i;
                        tap_ram_addr <= i;
                        y_acc = y_acc + data_ram_out * tap_ram_out;
                    end
                end
                OUTPUT_RESULT: begin
                    // 输出计算结果
                    y_out <= y_acc;

                    // 清除控制信号
                    data_ram_en <= 0;
                    tap_ram_en <= 0;
                    data_ram_we <= 4'b0000;
                    tap_ram_we <= 4'b0000;
                end
            endcase
        end
    end
endmodule