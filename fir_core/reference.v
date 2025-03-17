`timescale 1ns / 1ps
`include "bram11.v"
module reference 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter Data_Num    = 600
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


	//AXI-LITE

	reg awready_reg;
	reg wready_reg;
	reg arready_reg;
	reg rvalid_reg;
	
	always @(posedge axis_clk or negedge axis_rst_n) begin
		if (!axis_rst_n) begin
			awready_reg <= 0;
			wready_reg <= 0;
			arready_reg <= 0;
			rvalid_reg <= 0;
		end
		else begin
            rvalid_reg  <= (arvalid | rvalid & ~rready)? 1 : 0;
            arready_reg <= (arvalid)?                    1 : 0;
            awready_reg <= (awvalid && wvalid)?          1 : 0;
            wready_reg  <= (awvalid && wvalid)?          1 : 0;
		end
	end

    //0x10-0x14- data-length
   //data_length count
	reg  [9:0] tlast_cnt;    
	reg [31:0] data_length;
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
			data_length <= 32'b0;
		end
		else begin
			if (awaddr ==8'h10)begin
				data_length <= wdata;
			end
			else begin
				data_length <= data_length;
			end
		end
	end
		    
	always @(posedge axis_clk or negedge axis_rst_n) begin
		if (!axis_rst_n) begin
		    tlast_cnt <= 10'd0;
		end
		else begin
            if (tlast_cnt == data_length)begin
                tlast_cnt <= 10'd0;
            end
            else begin  
                if ( awaddr >= 8'h80 && awvalid && wvalid)begin
                   tlast_cnt <= tlast_cnt + 1;
                end
                else begin
                    tlast_cnt <= tlast_cnt;
                end
           end
        end
	end
	
	
	

	//Configuration Register Address Map
	//0x00-
	reg [2:0] ap_ctrl;
	reg [2:0] ctrl_cs;
	reg [2:0] ctrl_ns;
									
	parameter AP_IDLE  = 3'b100;
	parameter AP_START = 3'b001;
	parameter AP_DONE  = 3'b010;

	always@(posedge axis_clk or negedge axis_rst_n )begin
		if (!axis_rst_n) begin
			ctrl_cs <= AP_IDLE;
		end
		else begin
			ctrl_cs <= ctrl_ns;
		end
	end
	
	always@* begin
		case (ctrl_cs)
			AP_IDLE:
			begin
				if(awaddr == 12'b0 && wdata[0] ==1)begin//当 awaddr == 0x00 且 wdata[0] == 1，主机请求启动 FIR 计算
					ctrl_ns = AP_START;
				end
				else begin
					ctrl_ns = AP_IDLE;
				end
			end
			
			AP_START:
			begin
				if( tlast_cnt == data_length)begin
					ctrl_ns = AP_DONE;
				end
				else begin
					ctrl_ns = AP_START;
				end
			end
			
			AP_DONE:
			begin
				if(awaddr == 12'b0 && wdata[0] ==1)begin
					ctrl_ns = AP_IDLE;
				end
				else begin
					ctrl_ns =AP_DONE;
				end
			end
			
			default:ctrl_ns =AP_IDLE;
		endcase
	end
	
	always@* begin
		if(ctrl_cs == AP_IDLE)begin
			ap_ctrl=3'b100;
		end
		else begin
			ap_ctrl=3'b000;
		end
		
		if(ctrl_cs == AP_START )begin
			ap_ctrl=3'b001;
		end
		else begin
			ap_ctrl=3'b000;
		end		
		
		if(ctrl_cs == AP_DONE || (sm_tvalid && sm_tlast) )begin
			ap_ctrl=3'b010;
		end
		else begin
			ap_ctrl=3'b000;
		end
	end
		

	
	
	// 0x14-18: number of taps
	reg  [31:0] number_of_taps;

	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
			number_of_taps <= 32'b0;
		end
		else begin
			if (awaddr ==8'h14)begin
				number_of_taps <= wdata;
			end
			else begin
				number_of_taps <= number_of_taps;
			end
		end
	end

    
    assign awready = awready_reg;
	assign wready = wready_reg;
	assign arready = arready_reg;
	assign rvalid = rvalid_reg;
	assign rdata = (araddr[11:0] == 8'h00) ? ap_ctrl :
				   (araddr[11:0] == 8'h10) ? data_length :
				   (araddr[11:0] == 8'h14) ? number_of_taps :
				   tap_Do; 
    
	//0x80-0xFF- Tap parameters
	
	assign tap_WE = ( ((awvalid && wvalid) ||(awready && wready))  && awaddr>=12'h80 )? 4'b1111:4'd0000;
	assign tap_EN = 1;
	assign tap_Di = ( ((awvalid && wvalid) ||(awready && wready))  && awaddr>=12'h80 )? wdata : 0;
	assign tap_A =  ( ((awvalid && wvalid) ||(awready && wready))  && awaddr>=12'h80 ) ?  {awaddr[11:2], 2'b00} : 0;


	//AXI-Stream 
	//INPUT X FSM
	reg ss_available;
	
	parameter SS_IDLE  = 2'b01;
	parameter SS_DONE  = 2'b10;
	
	reg[1:0] ss_cs;
	reg[1:0] ss_ns;
	
	always @(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
			ss_cs<=SS_DONE;
		end
		else begin
			ss_cs<=ss_ns;
		end
	end
	
	always @* begin
		case(ss_cs)
			SS_IDLE:
			begin
				if(ss_tvalid && ss_tlast)begin
					ss_ns = SS_DONE;
					ss_available = 1;
				end
				else begin
					ss_ns = SS_IDLE;
					ss_available = 1;
				end
			end
			
			SS_DONE:
			begin
				if(ss_tvalid)begin
					ss_ns = SS_IDLE;
					ss_available = 1;
				end
				else begin
					ss_ns = SS_DONE;
					ss_available = 0;
				end
			end
			
			default:
			begin
				if(ss_tvalid)begin
					ss_ns = SS_IDLE;
					ss_available = 1;
				end
				else begin
					ss_ns = SS_DONE;
					ss_available = 0;
				end
			end
		endcase
	end
	
	//AXI-Stream_in signals
	assign ss_tready = (ap_ctrl[2] == 0 )?1'b1:1'b0;
	//FIR处于非空闲态，即FIR运行中
	
	
	//ADDR_GEN for data_RAM,在非空闲态自动递增x[t]的地址写入data_RAM
	
	reg[3:0] t;
	reg[3:0] t_tmp;
	wire[6:0] data_A_GEN;
	
	always @(*)begin
		if(ap_ctrl[2] == 0)begin
            if(t != 4'd10)begin
                t_tmp <= t+4'd1;
            end
            else begin
                t_tmp <= 4'd0;
            end
        end
		else begin
			t_tmp <= 0;
		end
	end
	
	always@(posedge axis_clk or negedge axis_rst_n) begin
	   if(!axis_rst_n)begin
	       t <= 4'b0;
	   end
	   else begin
	       t <= t_tmp;
	   end
    end

	assign data_A_GEN = 4 * t;
		
	//data_RAM signals
	assign data_WE = (ss_tready  && ss_available)?4'b1111:4'b0000;
	assign data_EN = ss_tvalid;
	assign data_Di = ss_tdata;
	assign data_A =  data_A_GEN;
	
	//AXI-Stream 
	//OUTPUT Y FSM	
	reg sm_tlast_reg;

	parameter SM_IDLE = 2'b01;
	parameter SM_DONE = 2'b10;
	
	reg [2:0] sm_cs;
	reg [2:0] sm_ns;
	
	always @(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
			sm_cs <= SM_DONE;
		end
		else begin
			sm_cs <= sm_ns;
		end
	end
	
	always @* begin
		case(sm_cs)
			SM_IDLE:
			begin
				if(tlast_cnt== data_length )begin
					sm_tlast_reg = 1'b1;
					sm_ns = SM_DONE;
				end
				else begin
					sm_tlast_reg = 1'b0;
					sm_ns = SM_IDLE;
				end
			end
			
			SM_DONE:
			begin
				if(sm_tvalid == 1'b1) begin
					sm_tlast_reg = 1'b0;
					sm_ns = SM_IDLE;
				end
				else begin
					sm_tlast_reg = 1'b0;
					sm_ns = SM_DONE;
				end
			end
		endcase
	end

		
	//FIR compute Engine
	//由于Data_Do和Tap_Do不同时到达，所以考虑采用双fifo缓冲分别存储x和h，待两边存满11个数据后再进行计算

	reg [31:0] x_fifo [1:11];
	reg [31:0] h_fifo [1:11];
	reg [31:0] x_val;
	reg [31:0] h_val;
	
	//写指针
	reg [3:0] x_wr_ptr,h_wr_ptr;
	//读指针
	
	reg [3:0] x_rd_ptr,h_rd_ptr;
	//计数器
	reg [3:0] pair_count;
	//累加器
	reg [31:0] m;
	reg [31:0] y_acc;
	//结果输出
	reg [31:0] y_out;
	reg y_valid;
	
	reg wvalid_reg;
	integer idx;
	
	//fifo的写入
	always @(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
		  for (idx = 1; idx < 12; idx = idx + 1) begin
              x_fifo[idx] <= 32'b0;
              h_fifo[idx] <= 32'b0;
          end
			x_wr_ptr <= 1;
			h_wr_ptr <= 1;
		end
		else begin
			wvalid_reg <= wvalid;
			
			if( data_WE == 4'b1111 )begin
				x_fifo[x_wr_ptr] = data_Do;
				x_wr_ptr = (x_wr_ptr == 4'd11)? 1 : x_wr_ptr + 1;
			end
			else begin
			    x_fifo[x_wr_ptr] <= x_fifo[x_wr_ptr];
				x_wr_ptr <= x_wr_ptr;
			end
			
			if( wvalid_reg == 0 && wvalid == 1  && awaddr >= 8'h80 )begin
				h_fifo[h_wr_ptr] = tap_Do;
				h_wr_ptr = (h_wr_ptr == 4'd11)? 1 : h_wr_ptr + 1;
			end
			else begin
			    h_fifo[h_wr_ptr] <= h_fifo[h_wr_ptr]; 
				h_wr_ptr <= h_wr_ptr;
			end
		end
	end
	
	//配对与读取
	always @(posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n)begin
			x_rd_ptr <= 1;
			h_rd_ptr <= 1;
			pair_count <= 0;
			y_acc <= 0;
			y_out <= 0;
			y_valid <= 0;
			m <= 0;
		end
		else begin
			if ((x_rd_ptr != x_wr_ptr) && (h_rd_ptr != h_wr_ptr))begin
				x_val = x_fifo[x_rd_ptr];
				h_val = h_fifo[h_rd_ptr];
				m = x_val * h_val;
				
				y_acc = (^m !== 1'bx) ?  y_acc + m : 0 ;
			
				x_rd_ptr <= (x_rd_ptr == 4'd11)? 1: x_rd_ptr + 1;
				h_rd_ptr <= (h_rd_ptr == 4'd11)? 1: h_rd_ptr + 1;
            
				pair_count <= pair_count + 1;
			end
			
			if (pair_count == 4'd12) begin
				y_out <= y_acc;
				y_valid <= 1;
				pair_count <= 0;
			end 
			else begin
				y_valid <= 0;
			end
			
		end
	end


	
	//AXI-Stream_out signals
	assign sm_tvalid = y_valid;
	assign sm_tdata  = y_out;
	assign sm_tlast  = sm_tlast_reg;
	
	
endmodule