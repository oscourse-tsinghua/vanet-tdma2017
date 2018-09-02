
`timescale 1 ns / 1 ps

	module axi_tdma_ath9k_middleware #
	(
        parameter integer DATA_WIDTH = 32,
        parameter integer ADDR_WIDTH = 32,

		// Parameters of Axi Master Bus Interface M00_AXI
        parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR    = 32'h40000000,
        parameter integer C_M00_AXI_BURST_LEN    = 32,
        parameter integer C_M00_AXI_ID_WIDTH    = 1,
        //parameter integer C_M00_AXI_ADDR_WIDTH    = 32,
        //parameter integer C_M00_AXI_DATA_WIDTH    = 32,
        parameter integer C_M00_AXI_AWUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_ARUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_WUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_RUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_BUSER_WIDTH    = 0,
        
        //parameters of axi_master_burst
        parameter integer C_ADDR_PIPE_DEPTH = 1,
        //parameter integer C_NATIVE_DATA_WIDTH = 32,
        parameter integer C_LENGTH_WIDTH = 12,
        
        // Parameters of AXI MASTER LITE IP core
        //parameter integer C_M00_AXI_LITE_ADDR_WIDTH = 32,
        //parameter integer C_M00_AXI_LITE_DATA_WIDTH = 32,

		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 7,
		
		//RxDesc��12 Beats���ٷ���200�ֽڵ����ݰ�����Ϊ50 Beats��һ��62 Beats = 1984 �ֽڣ�����Ҫע��4k���䣬���Զ�2048�ֽ�
		parameter integer C_PKT_LEN = 256,
        parameter integer FRAME_SLOT_NUM_DEFAULT = 4,
        parameter integer OCCUPIER_LIFE_FRAME = 3,
        parameter integer SLOT_US = 1000,
        parameter integer TX_GUARD_US = 70, // 70 us
        parameter integer BCH_CANDIDATE_C3HOP_THRES_S1 = 3,
        parameter integer ADJ_FRAME_LOWER_BOUND_DEFAULT = 4,
        parameter integer ADJ_FRAME_UPPER_BOUND_DEFAULT = 8
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line
        
         ///clock and resets
        input wire axi_aclk,
        input wire axi_aresetn,
        input wire clk_150M,
        ///Master Detected Error output
        output wire m00_md_error, 
        ///AXI4 Read Channels
        ////    AXI4 Read Address Channel
        input wire m00_axi_lite_arready,
        output wire m00_axi_lite_arvalid,
        output wire [ADDR_WIDTH-1 : 0] m00_axi_lite_araddr,
        output wire [2:0] m00_axi_lite_arprot,
        ////    AXI4 Read Data Channel
        output wire m00_axi_lite_rready,
        input wire m00_axi_lite_rvalid,
        input wire [DATA_WIDTH-1 : 0] m00_axi_lite_rdata,
        input wire [1:0] m00_axi_lite_rresp,
        //AXI4 Write Channels
        ////    AXI4 Write Address Channel
        input wire m00_axi_lite_awready,
        output wire m00_axi_lite_awvalid,
        output wire [ADDR_WIDTH-1 : 0] m00_axi_lite_awaddr,
        output wire [2:0] m00_axi_lite_awprot,
        ////    AXI4 Write Data Channel
        input wire m00_axi_lite_wready,
        output wire m00_axi_lite_wvalid,
        output wire [DATA_WIDTH-1 : 0] m00_axi_lite_wdata,
        output wire [(DATA_WIDTH/8)-1 : 0] m00_axi_lite_wstrb,
        ////    AXI4 Write Response Channel
        output wire m00_axi_lite_bready,
        input wire m00_axi_lite_bvalid,
        input wire [1:0] m00_axi_lite_bresp,

		// Ports of Axi Slave Bus Interface S00_AXI
		output wire s_axi_error,
		
		//input wire  s00_axi_aclk,
        //input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

        // Ports of Axi Master Bus Interface M00_AXI
        //input wire  m00_axi_init_axi_txn,
        //output wire  m00_axi_txn_done,
        output wire  m00_axi_error,
        //input wire  m_axi_aclk,
        //input wire  m_axi_aresetn,
        output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_awid,
        output wire [ADDR_WIDTH-1 : 0] m00_axi_awaddr,
        output wire [7 : 0] m00_axi_awlen,
        output wire [2 : 0] m00_axi_awsize,
        output wire [1 : 0] m00_axi_awburst,
        output wire  m00_axi_awlock,
        output wire [3 : 0] m00_axi_awcache,
        output wire [2 : 0] m00_axi_awprot,
        output wire [3 : 0] m00_axi_awqos,
        output wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] m00_axi_awuser,
        output wire  m00_axi_awvalid,
        input wire  m00_axi_awready,
        output wire [DATA_WIDTH-1 : 0] m00_axi_wdata,
        output wire [DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
        output wire  m00_axi_wlast,
        output wire [C_M00_AXI_WUSER_WIDTH-1 : 0] m00_axi_wuser,
        output wire  m00_axi_wvalid,
        input wire  m00_axi_wready,
        input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_bid,
        input wire [1 : 0] m00_axi_bresp,
        input wire [C_M00_AXI_BUSER_WIDTH-1 : 0] m00_axi_buser,
        input wire  m00_axi_bvalid,
        output wire  m00_axi_bready,
        output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_arid,
        output wire [ADDR_WIDTH-1 : 0] m00_axi_araddr,
        output wire [7 : 0] m00_axi_arlen,
        output wire [2 : 0] m00_axi_arsize,
        output wire [1 : 0] m00_axi_arburst,
        output wire  m00_axi_arlock,
        output wire [3 : 0] m00_axi_arcache,
        output wire [2 : 0] m00_axi_arprot,
        output wire [3 : 0] m00_axi_arqos,
        output wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] m00_axi_aruser,
        output wire  m00_axi_arvalid,
        input wire  m00_axi_arready,
        input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_rid,
        input wire [DATA_WIDTH-1 : 0] m00_axi_rdata,
        input wire [1 : 0] m00_axi_rresp,
        input wire  m00_axi_rlast,
        input wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m00_axi_ruser,
        input wire  m00_axi_rvalid,
        output wire  m00_axi_rready,

		// GPS TimePulse 1 and 2
		input wire gps_timepulse_1,
		input wire gps_timepulse_2,
		output wire [31:0] gps_pulse1_counter,
		output wire [31:0] gps_pulse2_counter,
		        		
		// Port of Debug GPIOs
		output wire [3 : 0] debug_gpio,
		output wire [7:0] debug_ports,
		output reg [1:0] timepulse_debug,
		input wire test_sendpkt,
		output wire recv_pkt_pulse,
		output wire [31:0] lastpkt_txok_timemark1,
        output wire [31:0] lastpkt_txok_timemark2,
        output wire tdma_tx_enable_debug,
		
        input wire open_loop,
        input wire start_ping,
        //output result
        output wire [31:0] res_seq,
        output wire [31:0] res_delta_t,

		// IRQ input and output
		input wire irq_in,
		output wire irq_out
	);
	
    //GPS timepulse debug.
    always @( posedge axi_aclk )
    begin
       timepulse_debug[0] <= gps_timepulse_1;
       timepulse_debug[1] <= gps_timepulse_2;
    end
    
	//////////////////////////
	// IPIC state machine
	/////////////////////////
    wire [5:0] curr_ipic_state;
    
    wire [2:0]ipic_type_dp;
    wire ipic_start_dp;
    wire ipic_done_dp;
    wire [ADDR_WIDTH-1 : 0] read_addr_dp;
    wire [C_LENGTH_WIDTH-1 : 0] read_length_dp;
    wire [ADDR_WIDTH-1 : 0] write_addr_dp;
    wire [DATA_WIDTH-1 : 0] write_data_dp;
    wire [C_LENGTH_WIDTH-1 : 0] write_length_dp;

    wire [2:0]ipic_type_tc;
    wire ipic_start_tc;
    wire ipic_done_tc;
    wire [ADDR_WIDTH-1 : 0] read_addr_tc;
    wire [ADDR_WIDTH-1 : 0] write_addr_tc;
    wire [DATA_WIDTH-1 : 0] write_data_tc;
    wire [C_LENGTH_WIDTH-1 : 0] write_length_tc;
    
    wire [15:0] ptr_checksum; //tc
    
    wire [DATA_WIDTH-1 : 0] single_read_data;
//    wire [2047 : 0] bunch_read_data;
//    wire [1023 : 0] bunch_write_data;
	//////////////////////////
	// IPIC LITE state machine
	/////////////////////////
	wire [3:0] curr_ipic_lite_state;
    wire [DATA_WIDTH-1 : 0] single_read_data_lite;
    wire [2:0]ipic_type_lite_dp;
    wire ipic_start_lite_dp;
    wire ipic_ack_lite_dp;
    wire ipic_done_lite_dp;
    wire [ADDR_WIDTH-1 : 0] read_addr_lite_dp;
    wire [ADDR_WIDTH-1 : 0] write_addr_lite_dp;
    wire [DATA_WIDTH-1 : 0] write_data_lite_dp;
    wire [2:0]ipic_type_lite_tc;
    wire ipic_start_lite_tc;
    wire ipic_ack_lite_tc;
    wire ipic_done_lite_tc;
    wire [ADDR_WIDTH-1 : 0] read_addr_lite_tc;
    wire [ADDR_WIDTH-1 : 0] write_addr_lite_tc;
    wire [DATA_WIDTH-1 : 0] write_data_lite_tc;    
///////////////////////////////////////////////////////////////////////////////////////
////////////////////       IPIC_LITE       /////////////////
///////////////////////////////////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////
    //
    // ip2bus signals 
    //
    //////////////////////////////////////////////////////////
    //  IP Master Request/Qualifers
    wire lite_ip2bus_mstrd_req;
    wire lite_ip2bus_mstwr_req;
    wire [ADDR_WIDTH-1 : 0] lite_ip2bus_mst_addr;
    wire [(DATA_WIDTH/8)-1 : 0] lite_ip2bus_mst_be;
    wire lite_ip2bus_mst_lock;
    wire lite_ip2bus_mst_reset;
    
    //  IP Request Status Reply
    wire lite_bus2ip_mst_cmdack;
    wire lite_bus2ip_mst_cmplt;
    wire lite_bus2ip_mst_error;
    wire lite_bus2ip_mst_rearbitrate;
    wire lite_bus2ip_mst_cmd_timeout;
    
    //  IPIC Read data
    wire [DATA_WIDTH-1 : 0] lite_bus2ip_mstrd_d;
    wire lite_bus2ip_mstrd_src_rdy_n;
    
    //  IPIC Write data
    wire [DATA_WIDTH-1 : 0] lite_ip2bus_mstwr_d;
    wire lite_bus2ip_mstwr_dst_rdy_n;

///////////////////////////////////////////////////////////////////////////////////////
////////////////////       IPIC_BURST_MASTER       /////////////////
///////////////////////////////////////////////////////////////////////////////////////

	//-----------------------------------------------------------------------------------------
    //-- IPIC Request/Qualifiers (ALL INPUT)
    //-----------------------------------------------------------------------------------------
    wire ip2bus_mstrd_req;
    wire ip2bus_mstwr_req;
    wire [ADDR_WIDTH-1 : 0] ip2bus_mst_addr;
    wire [C_LENGTH_WIDTH-1 : 0] ip2bus_mst_length;
    wire [(DATA_WIDTH/8)-1 : 0] ip2bus_mst_be;
    wire ip2bus_mst_type;
    wire ip2bus_mst_lock;
    wire ip2bus_mst_reset;
    //-----------------------------------------------------------------------------------------
    //-- IPIC Request Status Reply (ALL OUT)
    //-----------------------------------------------------------------------------------------
    wire bus2ip_mst_cmdack;
    wire bus2ip_mst_cmplt;
    wire bus2ip_mst_error;
    wire bus2ip_mst_rearbitrate;
    wire bus2ip_mst_cmd_timeout;
    //-----------------------------------------------------------------------------------------
    //-- IPIC Read LocalLink Channel
    //-----------------------------------------------------------------------------------------
    //OUT 
    wire [DATA_WIDTH-1 : 0] bus2ip_mstrd_d;
    wire [(DATA_WIDTH/8)-1 : 0] bus2ip_mstrd_rem;
    wire bus2ip_mstrd_sof_n;
    wire bus2ip_mstrd_eof_n;
    wire bus2ip_mstrd_src_rdy_n;
    wire bus2ip_mstrd_src_dsc_n;
    //IN
    wire ip2bus_mstrd_dst_rdy_n;
    wire ip2bus_mstrd_dst_dsc_n;
    //-----------------------------------------------------------------------------------------
    //-- IPIC Write LocalLink Channel
    //-----------------------------------------------------------------------------------------
    //IN
    wire [DATA_WIDTH-1 : 0] ip2bus_mstwr_d;
    wire [(DATA_WIDTH/8)-1 : 0] ip2bus_mstwr_rem;
    wire ip2bus_mstwr_sof_n;
    wire ip2bus_mstwr_eof_n;
    wire ip2bus_mstwr_src_rdy_n;
    wire ip2bus_mstwr_src_dsc_n;
    //OUT
    wire bus2ip_mstwr_dst_rdy_n;
    wire bus2ip_mstwr_dst_dsc_n;



    // IRQ 
    wire irq_readed_linux;
    //wire [31:0] fpga_irq_out_reg;
    //wire [31:0] fpga_async_cause;
	wire [5:0] curr_irq_state;

    // Port of FIFO write
    wire fifo_full;
    wire [63 : 0] fifo_dwrite;
    wire fifo_wr_en;
    wire fifo_almost_full;
    
    wire rxfifo_full;
    wire [DATA_WIDTH-1 : 0] rxfifo_dwrite;
    wire rxfifo_wr_en;
    wire rxfifo_almost_full;
    
    wire txfifo_full;
    wire [DATA_WIDTH-1 : 0] txfifo_dwrite;
    wire txfifo_wr_en;
    wire txfifo_almost_full;
    
    wire irqfifo_full;
    wire [DATA_WIDTH-1 : 0] irqfifo_dwrite;
    wire irqfifo_wr_en;
    wire irqfifo_almost_full;
    
    // Port of FIFO read
    wire fifo_empty;
    wire [63 : 0] fifo_dread;
    wire fifo_rd_en;
    wire fifo_almost_empty;

    wire rxfifo_empty;
    wire [DATA_WIDTH-1 : 0] rxfifo_dread;
    wire rxfifo_rd_en;
    wire rxfifo_almost_empty;
 
    wire txfifo_empty;
    wire [DATA_WIDTH-1 : 0] txfifo_dread;
    wire txfifo_rd_en;
    wire txfifo_almost_empty;

    wire irqfifo_empty;
    wire [DATA_WIDTH-1 : 0] irqfifo_dread;
    wire irqfifo_rd_en;
    wire irqfifo_almost_empty;
               
    // Port of FIFO status
    wire fifo_wr_ack;
    wire fifo_overflow;
    wire fifo_underflow;
    wire fifo_valid;
    
    wire rxfifo_wr_ack;
    wire rxfifo_overflow;
    wire rxfifo_underflow;
    wire rxfifo_valid; 
    
    wire txfifo_wr_ack;
    wire txfifo_overflow;
    wire txfifo_underflow;
    wire txfifo_valid;
    
    // Port of rx fifo write machine.
    // S-axi
    wire rxfifo_linux_wr_start;
    wire [DATA_WIDTH-1:0] rxfifo_linux_wr_data;
    //desc_processor
    wire rxfifo_desc_wr_start;
    wire [DATA_WIDTH-1:0] rxfifo_desc_wr_data;
    //done (wired to both modules)
    wire rxfifo_wr_done;

    // Port of tx fifo write machine.
    // S-axi
    wire txfifo_linux_wr_start;
    wire [DATA_WIDTH-1:0] txfifo_linux_wr_data;
    //tdma_control
    wire txfifo_tc_wr_start;
    wire [DATA_WIDTH-1:0] txfifo_tc_wr_data;
    //done 
    wire txfifo_wr_done;
       
    wire srst;
    assign srst = !axi_aresetn;
    wire fifo_reset;
    
    wire [31:0] utc_sec_32bit;

    //-----------------------------------------------------------------------------------------
    //-- PING state machine signals and registers
    //-----------------------------------------------------------------------------------------        
    wire recv_ping;//dp
    wire [31:0] recv_seq;//dp
    wire recv_ack_ping;//dp
    wire [31:0] recv_sec;//dp
    wire [31:0] recv_counter2;//dp
//    wire open_loop;//axi_s00
//    wire start_ping;//axi_s00
//    //output result
//    wire [31:0] res_seq; //axi_s00
//    wire [31:0] res_delta_t; //axi_s00

    //-----------------------------------------------------------------------------------------
    //-- TDMA controls
    //-----------------------------------------------------------------------------------------  
    wire [7:0] global_sid;
    wire [1:0] global_priority;
    wire [8:0] bch_candidate_c3hop_thres_s1;
    wire [DATA_WIDTH/2 -1:0] bch_user_pointer;
    wire tdma_tx_enable;
    assign tdma_tx_enable_debug = tdma_tx_enable;
    wire tdma_function_enable;
    wire [9:0] slot_pulse2_counter;
    wire [31:0] bch_control_time_ns;
    wire [9:0] curr_frame_len;
    wire [7:0] default_frame_len_user;
    wire frame_adj_ena;
    wire slot_adj_ena;
    wire [8:0] adj_frame_lower_bound;
    wire [8:0] adj_frame_upper_bound;
    wire [8:0] input_random;
    wire frame_len_exp_dp;
    wire randon_bch_if_single;

    wire [31:0] frame_count;
    wire [31:0] fi_send_count;
    wire [31:0] fi_recv_count;
    wire [15:0] no_avail_count;
    wire [15:0] request_fail_count;
    wire [15:0] collision_count;
    
    //-----------------------------------------------------------------------------------------
    //-- block memorys
    //-----------------------------------------------------------------------------------------  
    // blk mem for received pkt        
    wire [8:0] blk_mem_rcvpkt_addra; //32 bits * 512 
    wire [31:0] blk_mem_rcvpkt_dina;
    wire blk_mem_rcvpkt_wea;
    wire [8:0] blk_mem_rcvpkt_addrb;
    wire [31:0] blk_mem_rcvpkt_doutb;

    // blk mem for sending pkt        
    wire [8:0] blk_mem_sendpkt_addra; //32 bits * 512 
    wire [31:0] blk_mem_sendpkt_dina;
    wire blk_mem_sendpkt_wea;
    wire [8:0] blk_mem_sendpkt_addrb;
    wire [31:0] blk_mem_sendpkt_doutb;
    
    // blk mem for slot status 64 bits * 128
    wire [6:0] blk_mem_slot_status_addr_dp;
    wire [63:0] blk_mem_slot_status_din_dp;
    wire [63:0] blk_mem_slot_status_dout_dp;
    wire blk_mem_slot_status_we_dp;
    wire [6:0] blk_mem_slot_status_addr_tc;
    wire [63:0] blk_mem_slot_status_din_tc;
    wire [63:0] blk_mem_slot_status_dout_tc;
    wire blk_mem_slot_status_we_tc;
        
    fifo_64bit desc_fifo_64bit_inst (
      .clk(axi_aclk),                // input wire clk
      .rst(fifo_reset),
      .din(fifo_dwrite),                // input wire [31 : 0] din
      .wr_en(fifo_wr_en),            // input wire wr_en
      .rd_en(fifo_rd_en),            // input wire rd_en
      .dout(fifo_dread),              // output wire [31 : 0] dout
      .full(fifo_full),              // output wire full
      .wr_ack(fifo_wr_ack),          // output wire wr_ack
      .empty(fifo_empty),            // output wire empty
      .valid(fifo_valid)            // output wire valid  
    );
    
    cmd_fifo rx_fifo_inst (
      .clk(axi_aclk),                // input wire clk
      .rst(fifo_reset),
      .din(rxfifo_dwrite),                // input wire [31 : 0] din
      .wr_en(rxfifo_wr_en),            // input wire wr_en
      .rd_en(rxfifo_rd_en),            // input wire rd_en
      .dout(rxfifo_dread),              // output wire [31 : 0] dout
      .full(rxfifo_full),              // output wire full
      .wr_ack(rxfifo_wr_ack),          // output wire wr_ack
      .empty(rxfifo_empty),            // output wire empty
      .valid(rxfifo_valid)            // output wire valid  
    );
    
    cmd_fifo tx_fifo_inst (
      .clk(axi_aclk),                // input wire clk
      .rst(srst), //tx fifo will not be cleared then the ath9k resets.
      .din(txfifo_dwrite),                // input wire [31 : 0] din
      .wr_en(txfifo_wr_en),            // input wire wr_en
      .rd_en(txfifo_rd_en),            // input wire rd_en
      .dout(txfifo_dread),              // output wire [31 : 0] dout
      .full(txfifo_full),              // output wire full
      .wr_ack(txfifo_wr_ack),          // output wire wr_ack
      .empty(txfifo_empty),            // output wire empty
      .valid(txfifo_valid)            // output wire valid  
    );   

    cmd_fifo irq_fifo_inst (
      .clk(axi_aclk),                // input wire clk
      .rst(srst),
      .din(irqfifo_dwrite),                // input wire [31 : 0] din
      .wr_en(irqfifo_wr_en),            // input wire wr_en
      .rd_en(irqfifo_rd_en),            // input wire rd_en
      .dout(irqfifo_dread),              // output wire [31 : 0] dout
      .full(irqfifo_full),              // output wire full
      .wr_ack(irqfifo_wr_ack),          // output wire wr_ack
      .empty(irqfifo_empty),            // output wire empty
      .valid(irqfifo_valid)            // output wire valid  
    );
        
    rxfifo_wr_machine # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) rxfifo_wr_machine_inst (
        .clk(axi_aclk),                // input wire clk
        .reset_n(axi_aresetn),
        .rxfifo_full(rxfifo_full),
        .rxfifo_wr_en(rxfifo_wr_en),
        .rxfifo_dwrite(rxfifo_dwrite),
        .rxfifo_wr_ack(rxfifo_wr_ack),
        .rxfifo_overflow(rxfifo_overflow),
        .linux_wr_start(rxfifo_linux_wr_start),
        .linux_wr_data(rxfifo_linux_wr_data),
        .desc_wr_start(rxfifo_desc_wr_start),
        .desc_wr_data(rxfifo_desc_wr_data),
        .wr_done(rxfifo_wr_done)
    );
    
    txfifo_wr_machine # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) txfifo_wr_machine_inst (
        .clk(axi_aclk),                // input wire clk
        .reset_n(axi_aresetn),
        .txfifo_full(txfifo_full),
        .txfifo_wr_en(txfifo_wr_en),
        .txfifo_dwrite(txfifo_dwrite),
        .txfifo_wr_ack(txfifo_wr_ack),
        .txfifo_overflow(txfifo_overflow),
        .linux_wr_start(txfifo_linux_wr_start),
        .linux_wr_data(txfifo_linux_wr_data),
        .tc_wr_start(txfifo_tc_wr_start),
        .tc_wr_data(txfifo_tc_wr_data),
        .wr_done(txfifo_wr_done)
    );    
    
    blk_mem_32bit_512dept_SD blk_mem_rcvpkt_inst (
        .clka(axi_aclk),
        .addra(blk_mem_rcvpkt_addra), //ipic_state_machine
        .dina(blk_mem_rcvpkt_dina), //ipic_state_machine
        .wea(blk_mem_rcvpkt_wea), //ipic_state_machine
        .clkb(axi_aclk),
        .addrb(blk_mem_rcvpkt_addrb), //dp
        .doutb(blk_mem_rcvpkt_doutb) //dp
    );
    
    blk_mem_32bit_512dept_SD blk_mem_sendpkt_inst (
        .clka(axi_aclk),
        .addra(blk_mem_sendpkt_addra), //tc
        .dina(blk_mem_sendpkt_dina), //tc
        .wea(blk_mem_sendpkt_wea), //tc
        .clkb(axi_aclk),
        .addrb(blk_mem_sendpkt_addrb), //ipic_state_machine
        .doutb(blk_mem_sendpkt_doutb) //ipic_state_machine    
    );
    
    /********************
    * slot_status (5 bits)      0~4     : nothing (0), decide_req (1), req (2), fi (3), decide_adj (4), adj (5), 
    * slot_seq (11 bits)        5~15
    * Busy1 & Busy2 (2 bits)    16~17
    * occupier_sid (8 bits)     18~25
    * count_2hop (8 bits)       26~34
    * count_3hop (9 bits)       35~43
    * PSF (2 bits)              44~45
    * life (10 bits)            46~55
    * 
    *********************/
    blk_mem_64bit_128dept_TD blk_mem_slot_status_inst (
        .clka(axi_aclk),
        .addra(blk_mem_slot_status_addr_dp),
        .dina(blk_mem_slot_status_din_dp),
        .douta(blk_mem_slot_status_dout_dp),
        .wea(blk_mem_slot_status_we_dp),
        .clkb(axi_aclk),
        .addrb(blk_mem_slot_status_addr_tc),
        .dinb(blk_mem_slot_status_din_tc),
        .doutb(blk_mem_slot_status_dout_tc),
        .web(blk_mem_slot_status_we_tc)       
    );
    
// Instantiation of Axi Bus Interface S00_AXI
	axi_S00 # ( 
		.DATA_WIDTH(DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH),
		.BCH_CANDIDATE_C3HOP_THRES_S1(BCH_CANDIDATE_C3HOP_THRES_S1),
		.ADJ_FRAME_LOWER_BOUND_DEFAULT(ADJ_FRAME_LOWER_BOUND_DEFAULT),
        .ADJ_FRAME_UPPER_BOUND_DEFAULT(ADJ_FRAME_UPPER_BOUND_DEFAULT)
	) axi_S00_inst (
		.S_AXI_ACLK(axi_aclk),
		.S_AXI_ARESETN(axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		.s_axi_error(s_axi_error),
		
		.S_FIFO_FULL(fifo_full),
		.S_FIFO_WR_EN(fifo_wr_en),
		.S_FIFO_DWRITE(fifo_dwrite),
		.S_FIFO_WR_ACK(fifo_wr_ack),
		.S_FIFO_OVERFLOW(fifo_overflow),
        
        .S_FIFO_RST(fifo_reset),
        
        .rxfifo_wr_start(rxfifo_linux_wr_start),
        .rxfifo_wr_data(rxfifo_linux_wr_data),
        .rxfifo_wr_done(rxfifo_wr_done),

        .txfifo_wr_start(txfifo_linux_wr_start),
        .txfifo_wr_data(txfifo_linux_wr_data),
        .txfifo_wr_done(txfifo_wr_done),
        
        .irq_readed_linux(irq_readed_linux),
        //.fpga_irq_out_reg(fpga_irq_out_reg),
        //.fpga_async_cause(fpga_async_cause),
        .irqfifo_dread(irqfifo_dread),
        .irqfifo_rd_en(irqfifo_rd_en),
        .irqfifo_empty(irqfifo_empty),
        .irqfifo_valid(irqfifo_valid),
        
        .utc_sec_32bit(utc_sec_32bit),
        .tdma_function_enable(tdma_function_enable),
        .bch_user_pointer(bch_user_pointer), 
        
        .global_sid(global_sid),
        .global_priority(global_priority),
        .bch_candidate_c3hop_thres_s1(bch_candidate_c3hop_thres_s1),
        .frame_adj_ena(frame_adj_ena),//tc
        .slot_adj_ena(slot_adj_ena),//axi_s00
        .adj_frame_lower_bound(adj_frame_lower_bound),//tc
        .adj_frame_upper_bound(adj_frame_upper_bound),//tc
        .input_random(input_random),//tc
        .default_frame_len_user(default_frame_len_user),//tc
        .randon_bch_if_single(randon_bch_if_single),//tc
        
        .frame_count(frame_count),//tc
        .fi_send_count(fi_send_count),//tc
        .fi_recv_count(fi_recv_count),//dp
        .no_avail_count(no_avail_count),//tc
        .request_fail_count(request_fail_count),//tc
        .collision_count(collision_count),//tc
        .curr_frame_len(curr_frame_len),
//        .open_loop(open_loop),//axi_s00
//        .start_ping(start_ping),//axi_s00
//        //output result
//        .res_seq(res_seq), //axi_s00
//        .res_delta_t(res_delta_t), //axi_s00
                		
		.S_DEBUG_GPIO(debug_gpio[0])
		//.S_IRQ_READED_LINUX(irq_readed_linux)
	);
	
// Instantiation of Axi Bus Interface axi_master_lite
	axi_master_lite # (      
        // AXI4-Lite Parameters 
        
        .C_M_AXI_LITE_ADDR_WIDTH (ADDR_WIDTH),  
        // width of AXI4 Address Bus (in bits)
                 
        .C_M_AXI_LITE_DATA_WIDTH (DATA_WIDTH),  
          //  Width of the AXI4 Data Bus (in bits)
                 
        // FPGA Family Parameter      
        .C_FAMILY ("virtex7")
          // Select the target architecture type
          // see the family.vhd package in the proc_common
          // library
    ) axi_master_lite_inst (
        
        //-----------------------------------------------------------------------
        // Clock Input
        //-----------------------------------------------------------------------
        .m_axi_lite_aclk(axi_aclk),    //-- AXI4  
        //-----------------------------------------------------------------------
        ////-- Reset Input (active low) 
        //-----------------------------------------------------------------------
        .m_axi_lite_aresetn(axi_aresetn), //-- AXI4   
        //-----------------------------------------------------------------------
        ////-- Master Detected Error output 
        //-----------------------------------------------------------------------
        .md_error(m00_md_error),                           //-- Discrete Out

        //----------------------------------------------------------------------------
        ////-- AXI4 Read Channels
        //----------------------------------------------------------------------------
        ////--  AXI4 Read Address Channel                                          //-- AXI4
        .m_axi_lite_arready(m00_axi_lite_arready),  //-- AXI4
        .m_axi_lite_arvalid(m00_axi_lite_arvalid),//-- AXI4
        .m_axi_lite_araddr(m00_axi_lite_araddr), //-- AXI4
        .m_axi_lite_arprot(m00_axi_lite_arprot), //-- AXI4
                                                                               //-- AXI4
        ////--  AXI4 Read Data Channel                                             //-- AXI4
        .m_axi_lite_rready(m00_axi_lite_rready), //-- AXI4
        .m_axi_lite_rvalid(m00_axi_lite_rvalid),   //-- AXI4
        .m_axi_lite_rdata(m00_axi_lite_rdata), //-- AXI4
        .m_axi_lite_rresp(m00_axi_lite_rresp), //-- AXI4

        //-----------------------------------------------------------------------------
        ////-- AXI4 Write Channels
        //-----------------------------------------------------------------------------
        ////-- AXI4 Write Address Channel
        .m_axi_lite_awready(m00_axi_lite_awready),     //-- AXI4
        .m_axi_lite_awvalid(m00_axi_lite_awvalid),   //-- AXI4
        .m_axi_lite_awaddr(m00_axi_lite_awaddr),//-- AXI4
        .m_axi_lite_awprot(m00_axi_lite_awprot),   //-- AXI4
                                                                                  //-- AXI4
        ////-- AXI4 Write Data Channel                                                //-- AXI4
        .m_axi_lite_wready(m00_axi_lite_wready),      //-- AXI4
        .m_axi_lite_wvalid(m00_axi_lite_wvalid),    //-- AXI4
        .m_axi_lite_wdata(m00_axi_lite_wdata),    //-- AXI4
        .m_axi_lite_wstrb(m00_axi_lite_wstrb),//-- AXI4
                                                                                  //-- AXI4
        ////-- AXI4 Write Response Channel                                            //-- AXI4
        .m_axi_lite_bready(m00_axi_lite_bready),    //-- AXI4
        .m_axi_lite_bvalid(m00_axi_lite_bvalid),      //-- AXI4
        .m_axi_lite_bresp(m00_axi_lite_bresp),    //-- AXI4
    
        //-----------------------------------------------------------------------------
        ////-- IP Master Request/Qualifers (ALL INPUT)
        //-----------------------------------------------------------------------------
        .ip2bus_mstrd_req(lite_ip2bus_mstrd_req),                                           //-- IPIC
        .ip2bus_mstwr_req(lite_ip2bus_mstwr_req),                                           //-- IPIC
        .ip2bus_mst_addr(lite_ip2bus_mst_addr),    //-- IPIC
        .ip2bus_mst_be(lite_ip2bus_mst_be),//-- IPIC     
        .ip2bus_mst_lock(lite_ip2bus_mst_lock),                                            //-- IPIC
        .ip2bus_mst_reset(lite_ip2bus_mst_reset),                                           //-- IPIC
                                                                                              //-- IPIC
        //-----------------------------------------------------------------------------
        //-- IP Request Status Reply  (ALL OUTPUT)                                                          
        //-----------------------------------------------------------------------------
        .bus2ip_mst_cmdack(lite_bus2ip_mst_cmdack),                                                //-- IPIC
        .bus2ip_mst_cmplt(lite_bus2ip_mst_cmplt),                                                 //-- IPIC
        .bus2ip_mst_error(lite_bus2ip_mst_error),                                                 //-- IPIC
        .bus2ip_mst_rearbitrate(lite_bus2ip_mst_rearbitrate),                                           //-- IPIC
        .bus2ip_mst_cmd_timeout(lite_bus2ip_mst_cmd_timeout),                                           //-- IPIC
                                                                                //-- IPIC
        //-----------------------------------------------------------------------------
        //-- IPIC Read data  (ALL OUTPUT)                                                                   
        //-----------------------------------------------------------------------------
        .bus2ip_mstrd_d(lite_bus2ip_mstrd_d),                                                   //-- IPIC
        .bus2ip_mstrd_src_rdy_n(lite_bus2ip_mstrd_src_rdy_n),                                           //-- IPIC
                                                                                              //-- IPIC
        //-----------------------------------------------------------------------------
        //-- IPIC Write data                                                                    
        //-----------------------------------------------------------------------------
        .ip2bus_mstwr_d(lite_ip2bus_mstwr_d), //input                                                  //-- IPIC
        .bus2ip_mstwr_dst_rdy_n(lite_bus2ip_mstwr_dst_rdy_n) //output                                          //-- IPIC                                           
    );
 
 	axi_master_burst # (
        .C_M_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_MAX_BURST_LEN(C_M00_AXI_BURST_LEN),
        .C_ADDR_PIPE_DEPTH(C_ADDR_PIPE_DEPTH),
        .C_NATIVE_DATA_WIDTH(DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH)
    ) axi_master_burst_inst(
        //----------------------------------------------------------------------------
        //-- Primary Clock
        //----------------------------------------------------------------------------
        .m_axi_aclk(axi_aclk),
        //----------------------------------------------------------------------------
        //-- Primary Reset Input (active low)
        //----------------------------------------------------------------------------
        .m_axi_aresetn(axi_aresetn),
        //-----------------------------------------------------------------------
        //-- Master Detected Error output
        //-----------------------------------------------------------------------
        .md_error(m00_axi_error),
        //----------------------------------------------------------------------------
        //-- AXI4 Master Read Channel
        //----------------------------------------------------------------------------
        //-- MMap Read Address Channel                                          -- AXI4
        .m_axi_arready(m00_axi_awready),
        .m_axi_arvalid(m00_axi_arvalid),
        .m_axi_araddr(m00_axi_araddr),
        .m_axi_arlen(m00_axi_arlen),
        .m_axi_arsize(m00_axi_arsize),
        .m_axi_arburst(m00_axi_arburst),
        .m_axi_arprot(m00_axi_arprot),
        .m_axi_arcache(m00_axi_arcache),                                                                         
        //-- MMap Read Data Channel                                             -- AXI4
        .m_axi_rready(m00_axi_rready),
        .m_axi_rvalid(m00_axi_rvalid),
        .m_axi_rdata(m00_axi_rdata),
        .m_axi_rresp(m00_axi_rresp),
        .m_axi_rlast(m00_axi_rlast),
        //-----------------------------------------------------------------------------
        //-- AXI4 Master Write Channel
        //-----------------------------------------------------------------------------
        //-- Write Address Channel                                               -- AXI4
        .m_axi_awready(m00_axi_awready),
        .m_axi_awvalid(m00_axi_awvalid),
        .m_axi_awaddr(m00_axi_awaddr),
        .m_axi_awlen(m00_axi_awlen),
        .m_axi_awsize(m00_axi_awsize),
        .m_axi_awburst(m00_axi_awburst),
        .m_axi_awprot(m00_axi_awprot),
        .m_axi_awcache(m00_axi_awcache),                                                                     
        //-- Write Data Channel                                                  -- AXI4
        .m_axi_wready(m00_axi_wready),
        .m_axi_wvalid(m00_axi_wvalid),
        .m_axi_wdata(m00_axi_wdata),
        .m_axi_wstrb(m00_axi_wstrb),
        .m_axi_wlast(m00_axi_wlast),
        //-- Write Response Channel                                              -- AXI4
        .m_axi_bready(m00_axi_bready),
        .m_axi_bvalid(m00_axi_bvalid),
        .m_axi_bresp(m00_axi_bresp),
        //-----------------------------------------------------------------------------------------
        //-- IPIC Request/Qualifiers
        //-----------------------------------------------------------------------------------------
        .ip2bus_mstrd_req(ip2bus_mstrd_req),
        .ip2bus_mstwr_req(ip2bus_mstwr_req),
        .ip2bus_mst_addr(ip2bus_mst_addr),
        .ip2bus_mst_length(ip2bus_mst_length),
        .ip2bus_mst_be(ip2bus_mst_be),
        .ip2bus_mst_type(ip2bus_mst_type),
        .ip2bus_mst_lock(ip2bus_mst_lock),
        .ip2bus_mst_reset(ip2bus_mst_reset),
        //-----------------------------------------------------------------------------------------
        //-- IPIC Request Status Reply
        //-----------------------------------------------------------------------------------------
        .bus2ip_mst_cmdack(bus2ip_mst_cmdack),
        .bus2ip_mst_cmplt(bus2ip_mst_cmplt),
        .bus2ip_mst_error(bus2ip_mst_error),
        .bus2ip_mst_rearbitrate(bus2ip_mst_rearbitrate),
        .bus2ip_mst_cmd_timeout(bus2ip_mst_cmd_timeout),
        //-----------------------------------------------------------------------------------------
        //-- IPIC Read LocalLink Channel
        //-----------------------------------------------------------------------------------------
        .bus2ip_mstrd_d(bus2ip_mstrd_d),
        .bus2ip_mstrd_rem(bus2ip_mstrd_rem),
        .bus2ip_mstrd_sof_n(bus2ip_mstrd_sof_n),
        .bus2ip_mstrd_eof_n(bus2ip_mstrd_eof_n),
        .bus2ip_mstrd_src_rdy_n(bus2ip_mstrd_src_rdy_n),
        .bus2ip_mstrd_src_dsc_n(bus2ip_mstrd_src_dsc_n),
        .ip2bus_mstrd_dst_rdy_n(ip2bus_mstrd_dst_rdy_n),
        .ip2bus_mstrd_dst_dsc_n(ip2bus_mstrd_dst_dsc_n),
        //-----------------------------------------------------------------------------------------
        //-- IPIC Write LocalLink Channel
        //-----------------------------------------------------------------------------------------
        .ip2bus_mstwr_d(ip2bus_mstwr_d),
        .ip2bus_mstwr_rem(ip2bus_mstwr_rem),
        .ip2bus_mstwr_sof_n(ip2bus_mstwr_sof_n),
        .ip2bus_mstwr_eof_n(ip2bus_mstwr_eof_n),
        .ip2bus_mstwr_src_rdy_n(ip2bus_mstwr_src_rdy_n),
        .ip2bus_mstwr_src_dsc_n(ip2bus_mstwr_src_dsc_n),
        .bus2ip_mstwr_dst_rdy_n(bus2ip_mstwr_dst_rdy_n),
        .bus2ip_mstwr_dst_dsc_n(bus2ip_mstwr_dst_dsc_n)
    );
    
    ipic_state_machine # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH),
        .C_PKT_LEN(C_PKT_LEN)
    )ipic_state_machine_inst(
        .clk(axi_aclk),
        .reset_n(axi_aresetn),
        //axi_master_burst IPIC ports
        .ip2bus_mstrd_req(ip2bus_mstrd_req),
        .ip2bus_mstwr_req(ip2bus_mstwr_req),
        .ip2bus_mst_addr(ip2bus_mst_addr),
        .ip2bus_mst_length(ip2bus_mst_length),
        .ip2bus_mst_be(ip2bus_mst_be),
        .ip2bus_mst_type(ip2bus_mst_type),
        .ip2bus_mst_lock(ip2bus_mst_lock),
        .ip2bus_mst_reset(ip2bus_mst_reset),
    
        .bus2ip_mst_cmdack(bus2ip_mst_cmdack),
        .bus2ip_mst_cmplt(bus2ip_mst_cmplt),
        .bus2ip_mst_error(bus2ip_mst_error),
        .bus2ip_mst_rearbitrate(bus2ip_mst_rearbitrate),
        .bus2ip_mst_cmd_timeout(bus2ip_mst_cmd_timeout),
        
        .bus2ip_mstrd_d(bus2ip_mstrd_d),
        .bus2ip_mstrd_rem(bus2ip_mstrd_rem),
        .bus2ip_mstrd_sof_n(bus2ip_mstrd_sof_n),
        .bus2ip_mstrd_eof_n(bus2ip_mstrd_eof_n),
        .bus2ip_mstrd_src_rdy_n(bus2ip_mstrd_src_rdy_n),
        .bus2ip_mstrd_src_dsc_n(bus2ip_mstrd_src_dsc_n),
    
        .ip2bus_mstrd_dst_rdy_n(ip2bus_mstrd_dst_rdy_n),
        .ip2bus_mstrd_dst_dsc_n(ip2bus_mstrd_dst_dsc_n),
        
        .ip2bus_mstwr_d(ip2bus_mstwr_d),
        .ip2bus_mstwr_rem(ip2bus_mstwr_rem),
        .ip2bus_mstwr_sof_n(ip2bus_mstwr_sof_n),
        .ip2bus_mstwr_eof_n(ip2bus_mstwr_eof_n),
        .ip2bus_mstwr_src_rdy_n(ip2bus_mstwr_src_rdy_n),
        .ip2bus_mstwr_src_dsc_n(ip2bus_mstwr_src_dsc_n),
    
        .bus2ip_mstwr_dst_rdy_n(bus2ip_mstwr_dst_rdy_n),
        .bus2ip_mstwr_dst_dsc_n(bus2ip_mstwr_dst_dsc_n),

        .ipic_type_dp(ipic_type_dp),
        .ipic_start_dp(ipic_start_dp),
        .ipic_ack_dp(ipic_ack_dp),
        .ipic_done_dp(ipic_done_dp),
        .read_addr_dp(read_addr_dp),
        .read_length_dp(read_length_dp),
        .write_addr_dp(write_addr_dp),
        .write_data_dp(write_data_dp),
        .write_length_dp(write_length_dp), 
        
        .ipic_type_tc(ipic_type_tc),
        .ipic_start_tc(ipic_start_tc),
        .ipic_ack_tc(ipic_ack_tc),
        .ipic_done_tc(ipic_done_tc),
        .read_addr_tc(read_addr_tc),
        .ptr_checksum(ptr_checksum),
        .write_addr_tc(write_addr_tc),
        .write_data_tc(write_data_tc),
        .write_length_tc(write_length_tc),   
        
        .single_read_data(single_read_data),
//        .bunch_read_data(bunch_read_data),  
//        .bunch_write_data(bunch_write_data),
        
        //block memory for received pkt
        .blk_mem_rcvpkt_addra(blk_mem_rcvpkt_addra),
        .blk_mem_rcvpkt_dina(blk_mem_rcvpkt_dina),
        .blk_mem_rcvpkt_wea(blk_mem_rcvpkt_wea),
        //block memory for modifying pkt
        .blk_mem_sendpkt_addrb(blk_mem_sendpkt_addrb), 
        .blk_mem_sendpkt_doutb(blk_mem_sendpkt_doutb),
        
        .curr_ipic_state(curr_ipic_state)      
    ); 
    
    ipic_lite_state_machine # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH)
    )ipic_lite_state_machine_inst(
        .clk(axi_aclk),
        .reset_n(axi_aresetn),
        //IPIC LITE interface
        .ip2bus_mstrd_req(lite_ip2bus_mstrd_req),                                           //-- IPIC
        .ip2bus_mstwr_req(lite_ip2bus_mstwr_req),                                           //-- IPIC
        .ip2bus_mst_addr(lite_ip2bus_mst_addr),    //-- IPIC
        .ip2bus_mst_be(lite_ip2bus_mst_be),//-- IPIC     
        .ip2bus_mst_lock(lite_ip2bus_mst_lock),                                            //-- IPIC
        .ip2bus_mst_reset(lite_ip2bus_mst_reset),                                           //-- IPIC
        .bus2ip_mst_cmdack(lite_bus2ip_mst_cmdack),                                                //-- IPIC
        .bus2ip_mst_cmplt(lite_bus2ip_mst_cmplt),                                                 //-- IPIC
        .bus2ip_mst_error(lite_bus2ip_mst_error),                                                 //-- IPIC
        .bus2ip_mst_rearbitrate(lite_bus2ip_mst_rearbitrate),                                           //-- IPIC
        .bus2ip_mst_cmd_timeout(lite_bus2ip_mst_cmd_timeout),                                           //-- IPIC
        .bus2ip_mstrd_d(lite_bus2ip_mstrd_d),                                                   //-- IPIC
        .bus2ip_mstrd_src_rdy_n(lite_bus2ip_mstrd_src_rdy_n),                                           //-- IPIC
        .ip2bus_mstwr_d(lite_ip2bus_mstwr_d), //input                                                  //-- IPIC
        .bus2ip_mstwr_dst_rdy_n(lite_bus2ip_mstwr_dst_rdy_n), //output                                          //-- IPIC  

        .single_read_data(single_read_data_lite),
        .ipic_type_dp(ipic_type_lite_dp),
        .ipic_start_dp(ipic_start_lite_dp),
        .ipic_ack_dp(ipic_ack_lite_dp),
        .ipic_done_dp(ipic_done_lite_dp),
        .read_addr_dp(read_addr_lite_dp),
        .write_addr_dp(write_addr_lite_dp),
        .write_data_dp(write_data_lite_dp),

        .ipic_type_tc(ipic_type_lite_tc),
        .ipic_start_tc(ipic_start_lite_tc),
        .ipic_ack_tc(ipic_ack_lite_tc),
        .ipic_done_tc(ipic_done_lite_tc),
        .read_addr_tc(read_addr_lite_tc),
        .write_addr_tc(write_addr_lite_tc),
        .write_data_tc(write_data_lite_tc),
                
        .curr_ipic_state(curr_ipic_lite_state)
    );

    //wire test_sendpkt;
    
    tdma_control # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH),
        .FRAME_SLOT_NUM_DEFAULT(FRAME_SLOT_NUM_DEFAULT),
        .SLOT_US(SLOT_US),
        .TX_GUARD_NS(TX_GUARD_US * 1000),
        .TIME_PER_BYTE_12M_NS(700)
    ) tdma_control_inst (
        .clk(axi_aclk),
        .reset_n(axi_aresetn),

        .curr_ipic_lite_state(curr_ipic_lite_state),
        .single_read_data_lite(single_read_data_lite),
        .ipic_type_lite(ipic_type_lite_tc),
        .ipic_start_lite(ipic_start_lite_tc),
        .ipic_ack_lite(ipic_ack_lite_tc),
        .ipic_done_lite_wire(ipic_done_lite_tc),
        .read_addr_lite(read_addr_lite_tc),
        .write_addr_lite(write_addr_lite_tc),
        .write_data_lite(write_data_lite_tc),
        
        .curr_ipic_state(curr_ipic_state),
        .ipic_type(ipic_type_tc),
        .ipic_start(ipic_start_tc),
        .ipic_ack(ipic_ack_tc),
        .ipic_done_wire(ipic_done_tc),
        .read_addr(read_addr_tc),
        .ptr_checksum(ptr_checksum),
        .write_addr(write_addr_tc),
        .write_data(write_data_tc),
        .write_length(write_length_tc),   
        .single_read_data(single_read_data),
//        .bunch_write_data(bunch_write_data),
        .blk_mem_sendpkt_addra(blk_mem_sendpkt_addra), //tc
        .blk_mem_sendpkt_dina(blk_mem_sendpkt_dina), //tc
        .blk_mem_sendpkt_wea(blk_mem_sendpkt_wea), //tc
        
        .txfifo_dread(txfifo_dread),
        .txfifo_rd_en(txfifo_rd_en),
        .txfifo_empty(txfifo_empty),
        .txfifo_valid(txfifo_valid),
        .txfifo_wr_start(txfifo_tc_wr_start),
        .txfifo_wr_data(txfifo_tc_wr_data),
        .txfifo_wr_done(txfifo_wr_done),
        
        .desc_irq_state(curr_irq_state),
        .test_sendpkt(test_sendpkt),
        .gps_timepulse_1(timepulse_debug[0]),
        .gps_timepulse_2(timepulse_debug[1]),
        .utc_sec_32bit(utc_sec_32bit),
        .gps_pulse1_counter(gps_pulse1_counter),
        .gps_pulse2_counter(gps_pulse2_counter),
        
        .recv_ping(recv_ping),//dp
        .recv_seq(recv_seq),//dp
        .recv_ack_ping(recv_ack_ping),//dp
        .recv_sec(recv_sec),//dp
        .recv_counter2(recv_counter2),//dp
        .open_loop(open_loop),//axi_s00
        .start_ping(start_ping),//axi_s00
        //output result
        .res_seq(res_seq), //axi_s00
        .res_delta_t(res_delta_t), //axi_s00
        
        //-----------------------------------------------------------------------------------------
        //-- block memory stores slot status. 64bits 128dept.
        //-----------------------------------------------------------------------------------------   
        .blk_mem_slot_status_addr(blk_mem_slot_status_addr_tc),
        .blk_mem_slot_status_din(blk_mem_slot_status_din_tc),
        .blk_mem_slot_status_dout(blk_mem_slot_status_dout_tc),
        .blk_mem_slot_status_we(blk_mem_slot_status_we_tc),
        
        //-----------------------------------------------------------------------------------------
        //-- TDMA controls
        //----------------------------------------------------------------------------------------- 
        .global_sid(global_sid),
        .global_priority(global_priority),
        .bch_candidate_c3hop_thres_s1(bch_candidate_c3hop_thres_s1),
        .tdma_function_enable(tdma_function_enable), //axi_s00
        .bch_user_pointer(bch_user_pointer), //axi_s00
        .slot_pulse2_counter(slot_pulse2_counter), //dp
        .tdma_tx_enable(tdma_tx_enable), //dp
        .bch_control_time_ns(bch_control_time_ns), //dp
        .curr_frame_len(curr_frame_len),//dp
        .default_frame_len_user(default_frame_len_user), //axi_s00
        .frame_adj_ena(frame_adj_ena),//axi_s00
        .slot_adj_ena(slot_adj_ena),//axi_s00
        .adj_frame_lower_bound(adj_frame_lower_bound),//axi_s00
        .adj_frame_upper_bound(adj_frame_upper_bound),//axi_s00
        .input_random(input_random),//axi_s00
        .frame_len_exp_dp(frame_len_exp_dp),//dp
        .randon_bch_if_single(randon_bch_if_single),//axi_S00
        .frame_count(frame_count),//axi_S00
        .fi_send_count(fi_send_count),//axi_S00
        .no_avail_count(no_avail_count),//axi_S00
        .request_fail_count(request_fail_count),//axi_S00
        .collision_count(collision_count)//axi_S00
    );        
 //Instantiation of process logic
    desc_processor # (
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH),
        .C_PKT_LEN(C_PKT_LEN),
        .OCCUPIER_LIFE_FRAME(OCCUPIER_LIFE_FRAME),
        .SLOT_NS(SLOT_US * 1000),
        .TX_GUARD_NS(TX_GUARD_US * 1000),
        .TIME_PER_BYTE_12M_NS(700)
    ) desc_processor_inst (
        //CLK
        .clk(axi_aclk),
        .reset_n(axi_aresetn),
        .fifo_reset(fifo_reset),
        //FIFO read interface
        .fifo_empty(fifo_empty),
        .fifo_dread(fifo_dread),
        .fifo_rd_en(fifo_rd_en),
        .fifo_valid(fifo_valid),
        .fifo_underflow(fifo_underflow),

        .rxfifo_empty(rxfifo_empty),
        .rxfifo_dread(rxfifo_dread),
        .rxfifo_rd_en(rxfifo_rd_en),
        .rxfifo_valid(rxfifo_valid),
        .rxfifo_underflow(rxfifo_underflow),
        
        .rxfifo_wr_start(rxfifo_desc_wr_start),
        .rxfifo_wr_data(rxfifo_desc_wr_data),
        .rxfifo_wr_done(rxfifo_wr_done),
        //-----------------------------------------------------------------------------------------
        //-- IRQ Wires.
        //----------------------------------------------------------------------------------------- 
        .irq_in(irq_in),
        .irq_out(irq_out),
        .irq_readed_linux(irq_readed_linux),
        //.fpga_irq_out_reg(fpga_irq_out_reg),
        //.fpga_async_cause(fpga_async_cause),
        .irqfifo_full(irqfifo_full),
        .irqfifo_wr_en(irqfifo_wr_en),
        .irqfifo_dwrite(irqfifo_dwrite),
        .irqfifo_wr_ack(irqfifo_wr_ack),
        .irqfifo_empty(irqfifo_empty),
        
        //-----------------------------------------------------------------------------------------
        //-- IPIC (Burst) STATE MACHINE 
        //-----------------------------------------------------------------------------------------     
        .curr_ipic_state(curr_ipic_state),
        .ipic_type(ipic_type_dp),
        .ipic_start(ipic_start_dp),   
        .ipic_ack(ipic_ack_dp),
        .ipic_done_wire(ipic_done_dp),
        .read_addr(read_addr_dp),
        .read_length(read_length_dp), 
        .single_read_data(single_read_data),
//        .bunch_read_data(bunch_read_data),
        .write_addr(write_addr_dp),  
        .write_data(write_data_dp),
        .write_length(write_length_dp),  
        .blk_mem_rcvpkt_addrb(blk_mem_rcvpkt_addrb), 
        .blk_mem_rcvpkt_doutb(blk_mem_rcvpkt_doutb), 

        //-----------------------------------------------------------------------------------------
        //-- IPIC (Lite) STATE MACHINE 
        //-----------------------------------------------------------------------------------------     
        .curr_ipic_lite_state(curr_ipic_lite_state),
        .ipic_type_lite(ipic_type_lite_dp),
        .ipic_start_lite(ipic_start_lite_dp),
        .ipic_ack_lite(ipic_ack_lite_dp),   
        .ipic_done_lite_wire(ipic_done_lite_dp),
        .read_addr_lite(read_addr_lite_dp),
        .single_read_data_lite(single_read_data_lite),
        .write_addr_lite(write_addr_lite_dp),  
        .write_data_lite(write_data_lite_dp),
        
        //-----------------------------------------------------------------------------------------
        //-- block memory for storing slot status. 64bits 128dept.
        //-----------------------------------------------------------------------------------------   
        .blk_mem_slot_status_addr(blk_mem_slot_status_addr_dp),
        .blk_mem_slot_status_din(blk_mem_slot_status_din_dp),
        .blk_mem_slot_status_dout(blk_mem_slot_status_dout_dp),
        .blk_mem_slot_status_we(blk_mem_slot_status_we_dp),
         
        //Tdma control
        .global_sid(global_sid),
        .global_priority(global_priority),
        .tdma_function_enable(tdma_function_enable), //axi_s00
        .tdma_tx_enable(tdma_tx_enable),
        .slot_pulse2_counter(slot_pulse2_counter),
        .bch_control_time_ns(bch_control_time_ns),
        
        .curr_frame_len(curr_frame_len),//dp
        .frame_len_exp_dp(frame_len_exp_dp),//dp
        .fi_recv_count(fi_recv_count),
        
        //Status Debug Ports
        .curr_irq_state_wire(curr_irq_state), 
                  
        .debug_gpio(debug_gpio[3:1]),
        .recv_pkt_pulse(recv_pkt_pulse),     
        .lastpkt_txok_timemark1(lastpkt_txok_timemark1),
        .lastpkt_txok_timemark2(lastpkt_txok_timemark2),  
        
        .gps_pulse1_counter(gps_pulse1_counter),
        .gps_pulse2_counter(gps_pulse2_counter),  
       //Test
       .recv_ping(recv_ping),//dp
       .recved_seq(recv_seq),//dp
       .recv_ack_ping(recv_ack_ping),//dp
       .recved_sec(recv_sec),//dp
       .recved_counter2(recv_counter2),//dp

       //.test_sendpkt(test_sendpkt),
       //singals Debug Ports
       .debug_port_8bits(debug_ports)
    );

 
	// Add user logic here

	// User logic ends

	endmodule
