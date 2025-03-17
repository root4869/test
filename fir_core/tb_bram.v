`timescale 1ns/1ps
`include "bram11.v"
module tb_bram;

    // Parameters
    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 11;

    // Testbench signals
    reg CLK;
    reg [3:0] WE;
    reg EN;
    reg [DATA_WIDTH-1:0] Di;
    wire [DATA_WIDTH-1:0] Do;
    reg [ADDR_WIDTH-1:0] A;

    // Instantiate the memory module
    bram11 uut (
        .CLK(CLK),
        .WE(WE),
        .EN(EN),
        .Di(Di),
        .Do(Do),
        .A(A)
    );

    // Clock generation (50 MHz)
    initial CLK = 0;
    always #20 CLK = ~CLK; // Clock period = 20 ns

    // Testbench logic
    initial begin
        $dumpfile("tb_bram.vcd");
        $dumpvars(0, tb_bram);
        // Initialize signals
        WE = 4'b0000;
        EN = 0;
        Di = 32'b0;
        A = 12'b0;

        // Wait for reset
        #100;

        // Write increasing data to memory
        for (integer i = 0; i < DEPTH; i = i + 1) begin
            @(posedge CLK);
            EN = 1;
            WE = 4'b1111;          // Enable all byte writes
            Di = i;                // Data is the current index
            A = i << 2;            // Address is word-aligned
        end

        // Disable write enable
        @(posedge CLK);
        WE = 4'b0000;
        EN = 0;

        // Read data from memory and verify
        for (integer i = 0; i < DEPTH; i = i + 1) begin
            @(posedge CLK);
            EN = 1;
            A = i << 2;            // Address is word-aligned

            @(posedge CLK);
            $display("Read Address: %d, Data: %d", i, Do);
            if (Do != i) begin
                $display("ERROR: Data mismatch at Address %d, Expected: %d, Got: %d", i, i, Do);
            end
        end

        // End simulation
        $display("Testbench completed.");
        $stop;
    end

endmodule