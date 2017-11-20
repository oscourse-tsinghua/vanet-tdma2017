
`timescale 1 ns / 1 ps

	module axi_tdma_ath9k_middleware #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Master Bus Interface M00_AXI
        parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR    = 32'h40000000,
        parameter integer C_M00_AXI_BURST_LEN    = 32,
        parameter integer C_M00_AXI_ID_WIDTH    = 1,
        parameter integer C_M00_AXI_ADDR_WIDTH    = 32,
        parameter integer C_M00_AXI_DATA_WIDTH    = 32,
        parameter integer C_M00_AXI_AWUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_ARUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_WUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_RUSER_WIDTH    = 0,
        parameter integer C_M00_AXI_BUSER_WIDTH    = 0,
        
        //parameters of axi_master_burst
        parameter integer C_ADDR_PIPE_DEPTH = 1,
        parameter integer C_NATIVE_DATA_WIDTH = 32,
        parameter integer C_LENGTH_WIDTH = 12,
        
        // Parameters of AXI MASTER LITE IP core
        parameter integer C_M00_AXI_LITE_ADDR_WIDTH = 32,
        parameter integer C_M00_AXI_LITE_DATA_WIDTH = 32,

		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line
        
         ///clock and resets
        input wire axi_aclk,
        input wire axi_aresetn,
        
        ///Master Detected Error output
        output wire m00_md_error, 
        ///AXI4 Read Channels
        ////    AXI4 Read Address Channel
        input wire m00_axi_lite_arready,
        output wire m00_axi_lite_arvalid,
        output wire [C_M00_AXI_LITE_ADDR_WIDTH-1 : 0] m00_axi_lite_araddr,
        output wire [2:0] m00_axi_lite_arprot,
        ////    AXI4 Read Data Channel
        output wire m00_axi_lite_rready,
        input wire m00_axi_lite_rvalid,
        input wire [C_M00_AXI_LITE_DATA_WIDTH-1 : 0] m00_axi_lite_rdata,
        input wire [1:0] m00_axi_lite_rresp,
        //AXI4 Write Channels
        ////    AXI4 Write Address Channel
        input wire m00_axi_lite_awready,
        output wire m00_axi_lite_awvalid,
        output wire [C_M00_AXI_LITE_ADDR_WIDTH-1 : 0] m00_axi_lite_awaddr,
        output wire [2:0] m00_axi_lite_awprot,
        ////    AXI4 Write Data Channel
        input wire m00_axi_lite_wready,
        output wire m00_axi_lite_wvalid,
        output wire [C_M00_AXI_LITE_DATA_WIDTH-1 : 0] m00_axi_lite_wdata,
        output wire [(C_M00_AXI_LITE_DATA_WIDTH/8)-1 : 0] m00_axi_lite_wstrb,
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
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
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
        output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
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
        output wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
        output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
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
        output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr,
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
        input wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata,
        input wire [1 : 0] m00_axi_rresp,
        input wire  m00_axi_rlast,
        input wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m00_axi_ruser,
        input wire  m00_axi_rvalid,
        output wire  m00_axi_rready,
        		
		// Port of Debug GPIOs
		output wire [3 : 0] debug_gpio,
		output wire [7:0] debug_ports,
		output wire [31:0] single_read,
		
		// IRQ input and output
		input wire irq_in,
		output wire irq_out,
		
        // Ports of Status
        output wire [4:0] curr_irq_state,
        output wire [5:0] curr_ipic_state
	);
	
	//////////////////////////
	// IPIC state machine
	/////////////////////////
    wire [2:0]ipic_type;
    wire ipic_start;
    wire ipic_done;
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] read_addr;
    wire [C_LENGTH_WIDTH-1 : 0] read_length;
    wire [C_NATIVE_DATA_WIDTH-1 : 0] single_read_data;
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] write_addr;
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] write_data;
    wire [C_LENGTH_WIDTH-1 : 0] write_beat_length;

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
    wire [C_M00_AXI_LITE_ADDR_WIDTH-1 : 0] lite_ip2bus_mst_addr;
    wire [(C_M00_AXI_LITE_DATA_WIDTH/8)-1 : 0] lite_ip2bus_mst_be;
    wire lite_ip2bus_mst_lock;
    wire lite_ip2bus_mst_reset;
    
    //  IP Request Status Reply
    wire lite_bus2ip_mst_cmdack;
    wire lite_bus2ip_mst_cmplt;
    wire lite_bus2ip_mst_error;
    wire lite_bus2ip_mst_rearbitrate;
    wire lite_bus2ip_mst_cmd_timeout;
    
    //  IPIC Read data
    wire [C_M00_AXI_LITE_DATA_WIDTH-1 : 0] lite_bus2ip_mstrd_d;
    wire lite_bus2ip_mstrd_src_rdy_n;
    
    //  IPIC Write data
    wire [C_M00_AXI_LITE_DATA_WIDTH-1 : 0] lite_ip2bus_mstwr_d;
    wire lite_bus2ip_mstwr_dst_rdy_n;

///////////////////////////////////////////////////////////////////////////////////////
////////////////////       IPIC_BURST_MASTER       /////////////////
///////////////////////////////////////////////////////////////////////////////////////

	//-----------------------------------------------------------------------------------------
    //-- IPIC Request/Qualifiers (ALL INPUT)
    //-----------------------------------------------------------------------------------------
    wire ip2bus_mstrd_req;
    wire ip2bus_mstwr_req;
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] ip2bus_mst_addr;
    wire [C_LENGTH_WIDTH-1 : 0] ip2bus_mst_length;
    wire [(C_NATIVE_DATA_WIDTH/8)-1 : 0] ip2bus_mst_be;
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
    wire [C_NATIVE_DATA_WIDTH-1 : 0] bus2ip_mstrd_d;
    wire [(C_NATIVE_DATA_WIDTH/8)-1 : 0] bus2ip_mstrd_rem;
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
    wire [C_NATIVE_DATA_WIDTH-1 : 0] ip2bus_mstwr_d;
    wire [(C_NATIVE_DATA_WIDTH/8)-1 : 0] ip2bus_mstwr_rem;
    wire ip2bus_mstwr_sof_n;
    wire ip2bus_mstwr_eof_n;
    wire ip2bus_mstwr_src_rdy_n;
    wire ip2bus_mstwr_src_dsc_n;
    //OUT
    wire bus2ip_mstwr_dst_rdy_n;
    wire bus2ip_mstwr_dst_dsc_n;



    // IRQ 
    wire irq_readed_linux;

    // Port of FIFO write
    wire fifo_full;
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] fifo_dwrite;
    wire fifo_wr_en;
    wire fifo_almost_full;
    
    // Port of FIFO read
    wire fifo_empty;
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] fifo_dread;
    wire fifo_rd_en;
    wire fifo_almost_empty;
    
    // Port of FIFO status
    wire fifo_wr_ack;
    wire fifo_overflow;
    wire fifo_underflow;
    wire fifo_valid;
    wire srst;
    assign srst = !axi_aresetn;
   
    cmd_fifo cmd_fifo_inst (
      .clk(axi_aclk),                // input wire clk
      .srst(srst),
      .din(fifo_dwrite),                // input wire [31 : 0] din
      .wr_en(fifo_wr_en),            // input wire wr_en
      .rd_en(fifo_rd_en),            // input wire rd_en
      .dout(fifo_dread),              // output wire [31 : 0] dout
      .full(fifo_full),              // output wire full
      .wr_ack(fifo_wr_ack),          // output wire wr_ack
      .empty(fifo_empty),            // output wire empty
      .valid(fifo_valid)            // output wire valid  
    );
    
// Instantiation of Axi Bus Interface S00_AXI
	axi_S00 # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
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
		
		.S_DEBUG_GPIO(debug_gpio[0]),
		.S_IRQ_READED_LINUX(irq_readed_linux)
	);
	
// Instantiation of Axi Bus Interface axi_master_lite
	axi_master_lite # (      
        // AXI4-Lite Parameters 
        
        .C_M_AXI_LITE_ADDR_WIDTH (C_M00_AXI_LITE_ADDR_WIDTH),  
        // width of AXI4 Address Bus (in bits)
                 
        .C_M_AXI_LITE_DATA_WIDTH (C_M00_AXI_LITE_DATA_WIDTH),  
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
        .C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
        .C_MAX_BURST_LEN(C_M00_AXI_BURST_LEN),
        .C_ADDR_PIPE_DEPTH(C_ADDR_PIPE_DEPTH),
        .C_NATIVE_DATA_WIDTH(C_NATIVE_DATA_WIDTH),
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
        .C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
        .C_NATIVE_DATA_WIDTH(C_NATIVE_DATA_WIDTH),
        .C_LENGTH_WIDTH(C_LENGTH_WIDTH)
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

        .ipic_type(ipic_type),
        .ipic_start(ipic_start),
        .ipic_done(ipic_done),
        .read_addr(read_addr),
        .read_length(read_length),
        .single_read_data(single_read_data),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_beat_length(write_beat_length),
        //.write_length(write_length_01),     
        .curr_ipic_state(curr_ipic_state),
        
        .single_read_debug(single_read)        
    ); 
        
 //Instantiation of process logic
    desc_processor # (
        .C_ADDR_WIDTH(C_M00_AXI_LITE_ADDR_WIDTH),
        .C_DATA_WIDTH(C_M00_AXI_LITE_DATA_WIDTH)
    ) desc_processor_inst (
        //CLK
        .clk(axi_aclk),
        .reset_n(axi_aresetn),
        //FIFO read interface
        .fifo_empty(fifo_empty),
        .fifo_dread(fifo_dread),
        .fifo_rd_en(fifo_rd_en),
        .fifo_valid(fifo_valid),
        .fifo_underflow(fifo_underflow),
        
        .irq_in(irq_in),
        .irq_out(irq_out),
        .irq_readed_linux(irq_readed_linux),
        
        .debug_gpio(debug_gpio[3:1]),
           
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
        
        //-----------------------------------------------------------------------------------------
        //-- IPIC STATE MACHINE 
        //-----------------------------------------------------------------------------------------     
        .ipic_type(ipic_type),
        .ipic_start(ipic_start),   
        .ipic_done_wire(ipic_done),
        .read_addr(read_addr),
        .read_length(read_length), 
        .single_read_data(single_read_data),
        .write_addr(write_addr),  
        .write_data(write_data),
        .write_beat_length(write_beat_length),
       
       //Status Debug Ports
       .curr_irq_state_wire(curr_irq_state),
       
       //singals Debug Ports
       .debug_port_8bits(debug_ports)
    );

 
	// Add user logic here

	// User logic ends

	endmodule
