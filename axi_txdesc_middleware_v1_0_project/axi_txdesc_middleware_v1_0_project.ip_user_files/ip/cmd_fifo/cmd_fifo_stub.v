// Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2016.2 (win64) Build 1577090 Thu Jun  2 16:32:40 MDT 2016
// Date        : Fri Oct 20 14:27:48 2017
// Host        : wu-T430s running 64-bit Service Pack 1  (build 7601)
// Command     : write_verilog -force -mode synth_stub
//               E:/work/FPGA/zedboard/Vivado/axi_txdesc_middleware_v1_0_project/axi_txdesc_middleware_v1_0_project.srcs/sources_1/ip/cmd_fifo/cmd_fifo_stub.v
// Design      : cmd_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z015clg485-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_1_1,Vivado 2016.2" *)
module cmd_fifo(clk, srst, din, wr_en, rd_en, dout, full, almost_full, wr_ack, overflow, empty, almost_empty, valid, underflow)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[31:0],wr_en,rd_en,dout[31:0],full,almost_full,wr_ack,overflow,empty,almost_empty,valid,underflow" */;
  input clk;
  input srst;
  input [31:0]din;
  input wr_en;
  input rd_en;
  output [31:0]dout;
  output full;
  output almost_full;
  output wr_ack;
  output overflow;
  output empty;
  output almost_empty;
  output valid;
  output underflow;
endmodule
