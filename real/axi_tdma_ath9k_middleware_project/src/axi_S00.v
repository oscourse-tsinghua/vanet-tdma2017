
`timescale 1 ns / 1 ps

	module axi_S00 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 7,
		parameter integer BCH_CANDIDATE_C3HOP_THRES_S1 = 3,
		parameter integer ADJ_FRAME_LOWER_BOUND_DEFAULT = 4,
		parameter integer ADJ_FRAME_UPPER_BOUND_DEFAULT = 8
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY,
		
		output wire s_axi_error,
		
		// FIFO signals
		input wire  S_FIFO_FULL,
        output wire  S_FIFO_WR_EN,
        output wire [63 : 0] S_FIFO_DWRITE,
        input wire  S_FIFO_WR_ACK,
        input wire  S_FIFO_OVERFLOW,
        
        output wire S_FIFO_RST,
        
        output reg rxfifo_wr_start,
        output reg [DATA_WIDTH-1:0] rxfifo_wr_data,
        input wire rxfifo_wr_done,

        output reg txfifo_wr_start,
        output reg [DATA_WIDTH-1:0] txfifo_wr_data,
        input wire txfifo_wr_done,
        
        // UTC Second.
        output reg [31:0] utc_sec_32bit,
        
        //IRQ related.
        //input wire [31:0] fpga_irq_out_reg,
        //input wire [31:0] fpga_async_cause,
        output reg irq_readed_linux,
        input wire [DATA_WIDTH-1:0] irqfifo_dread,
        output reg irqfifo_rd_en,
        input wire irqfifo_empty,
        input wire irqfifo_valid,
        
        //Switch of TDMA function
        output reg tdma_function_enable,
        //user assigned BCH slot pointer.
        output reg [DATA_WIDTH/2 -1:0] bch_user_pointer,
        
        //Global sid (8bits) of this node
        output reg [7:0] global_sid,
        output reg [1:0] global_priority,
        output reg [8:0] bch_candidate_c3hop_thres_s1,
        
        output reg frame_adj_ena,
        output reg slot_adj_ena,
        output reg [8:0] adj_frame_lower_bound,
        output reg [8:0] adj_frame_upper_bound,
        output reg [8:0] input_random,
        output reg [7:0] default_frame_len_user,
        output reg randon_bch_if_single,
        
        input wire [31:0] frame_count,
        input wire [31:0] fi_send_count,
        input wire [31:0] fi_recv_count,
        input wire [15:0] no_avail_count,
        input wire [15:0] request_fail_count,
        input wire [15:0] collision_count,
        input wire [9:0] curr_frame_len,
//        output reg open_loop,
//        output reg start_ping,
//        //output result
//        input wire [31:0] res_seq,
//        input wire [31:0] res_delta_t,
                      
        output wire  S_DEBUG_GPIO
        //output reg S_IRQ_READED_LINUX
	);
    // ERROR
    reg s_axi_error1;
    reg s_axi_error2;
    assign s_axi_error = s_axi_error1 || s_axi_error2;
    

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

    // FIFO signals
    reg [63 : 0] fifo_dwrite;
    reg fifo_wr_en = 1'b0;      
    
    reg fifo_rst;
        
    reg debug_gpio;
    
	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 4;
	//----------------------------------------------
	////-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 24
	reg [DATA_WIDTH-1:0]	slv_reg0;
	reg [DATA_WIDTH-1:0]	slv_reg1;
	reg [DATA_WIDTH-1:0]	slv_reg2;
	reg [DATA_WIDTH-1:0]	slv_reg3;
	reg [DATA_WIDTH-1:0]	slv_reg4;
	reg [DATA_WIDTH-1:0]	slv_reg5;
	reg [DATA_WIDTH-1:0]	slv_reg6;
	reg [DATA_WIDTH-1:0]	slv_reg7;
	reg [DATA_WIDTH-1:0]	slv_reg8;
	reg [DATA_WIDTH-1:0]	slv_reg9;
	reg [DATA_WIDTH-1:0]	slv_reg10;
	reg [DATA_WIDTH-1:0]	slv_reg11;
	reg [DATA_WIDTH-1:0]	slv_reg12;
	reg [DATA_WIDTH-1:0]	slv_reg13;
	reg [DATA_WIDTH-1:0]	slv_reg14;
	reg [DATA_WIDTH-1:0]	slv_reg15;
	reg [DATA_WIDTH-1:0]	slv_reg16;
	reg [DATA_WIDTH-1:0]	slv_reg17;
	reg [DATA_WIDTH-1:0]	slv_reg18;
	reg [DATA_WIDTH-1:0]	slv_reg19;
	reg [DATA_WIDTH-1:0]	slv_reg20;
	reg [DATA_WIDTH-1:0]	slv_reg21;
	reg [DATA_WIDTH-1:0]	slv_reg22;
	reg [DATA_WIDTH-1:0]	slv_reg23;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	
	// FIFO I/Os
	assign S_FIFO_DWRITE = fifo_dwrite;
	assign S_FIFO_WR_EN = fifo_wr_en;
	
	assign S_FIFO_RST = fifo_rst;
		
	assign S_DEBUG_GPIO = debug_gpio;
	
	
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	        end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    reg [2:0]fifo_write_status;

    reg fifo_write_enable;
    reg fifo_write_cpl_pulse;
    reg isAddr;
    reg rxfifo_write_enable;
    reg txfifo_write_enable;
    //reg txfifo_write_cpl_pulse;
    //reg irq_readed_linux;
//    reg irq_done;
    reg irq_readed_linux_set;
    
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      slv_reg4 <= 0;
	      slv_reg5 <= 0;
	      slv_reg6 <= 0;
	      slv_reg7 <= 16'hffff;//bch_user_slot
	      slv_reg8 <= 0;
	      slv_reg9 <= 0;
	      slv_reg10 <= 0;
	      slv_reg11 <= 0;
	      slv_reg12 <= 0;
	      slv_reg13 <= 0;
	      slv_reg14 <= 0;
	      slv_reg15 <= 0;
	      slv_reg16 <= 0;
	      slv_reg17 <= 0;
	      slv_reg18 <= 0;
	      slv_reg19 <= 0;
	      slv_reg20 <= 0;
	      slv_reg21 <= 0;
	      slv_reg22 <= 0;
	      slv_reg23 <= 0;
	      isAddr <= 0;
	      s_axi_error1 <= 0;
	      fifo_write_enable <= 0;
	      rxfifo_write_enable <= 0;
	      txfifo_write_enable <= 0;
	      fifo_rst <= 0;
	      irq_readed_linux <= 0;
	      irq_readed_linux_set <= 0;
	      irqfifo_rd_en <= 0;
	    end 
	  else begin
        if (fifo_rst)
            fifo_rst <= 0;

        if ( fifo_write_enable && fifo_write_cpl_pulse ) begin
            fifo_write_enable <= 0;
        end
        if ( rxfifo_wr_start ) begin
            rxfifo_write_enable <= 0;
        end
        
        if ( txfifo_wr_start ) begin
            txfifo_write_enable <= 0;
        end
        
        //DeBug OUTPUT
        slv_reg15[31:0] <= frame_count[31:0];
        slv_reg16[31:0] <= fi_send_count[31:0];
        slv_reg17[31:0] <= fi_recv_count[31:0];
        slv_reg18[31:16] <= no_avail_count[15:0];
        slv_reg18[15:0] <= request_fail_count[15:0];
        slv_reg19[31:16] <= curr_frame_len;
        slv_reg19[15:0] <= collision_count[15:0];
        
        //IRQ reg
        if (irqfifo_valid)
            slv_reg20[31:0] <= irqfifo_dread[31:0];
        else
            slv_reg20[31:0] <= 0;
        
        if (irq_readed_linux_set) begin
            irq_readed_linux <= 1;
            irqfifo_rd_en <= 1;
            irq_readed_linux_set <= 0;
        end else begin
            irq_readed_linux <= 0;
            irqfifo_rd_en <= 0;
        end
                  	    
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          5'h00: begin //write Queue addr for the TX desc to this reg
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
                isAddr = 1'b1;
              end
	          5'h01: begin //write TX desc DMA addr to this reg
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
                end
                isAddr <= 1'b0;
                fifo_write_enable <= 1;
              end
	          5'h02: begin //empty RX buffers for the receiving of FPGA.
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	              
                rxfifo_write_enable <= 1;
              end
	          5'h03:// a write to this reg resets all FIFOs
	          begin
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	            end	  
	            
	            fifo_rst <= 1;          
              end
	          5'h04: begin //empty TX descs (pkt HDRs are loaded by software)
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
                end
                txfifo_write_enable <= 1;
              end
	          5'h05: //slv_reg5 stores valid flag of the UTC time.
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h06: //slv_reg6 stores the UTC-sec
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 6
	                slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h07: begin // this reg stores bch_user_pointer
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
              end
	          5'h08: //switch of the TDMA function:
	                 // 0: tdma_enable
	                 // 1: slot_adj_ena
	                 // 2: frame_adj_ena
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 8
	                slv_reg8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h09: //Stores ID of this node. Last 8 bits are Short-ID.
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 9
	                slv_reg9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h0A: //Stores threshold of count_3hop of a bch candidate. 
	                 //16 bits of LSB stores S1, (bch_candidate_c3hop_thres_s1)
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 10
	                slv_reg10[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h0B: //LSB 2bits stores PSF of this node.
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 11
	                slv_reg11[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h0C: // 16bits LSB: adj_frame_lower_bound,
                     // 16bits MSB: adj_frame_upper_bound,
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 12
	                slv_reg12[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h0D: //input_random
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 13
	                slv_reg13[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h0E: // default_frame_len_user
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 14
	                slv_reg14[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end              
	          5'h0F: begin end//frame_count
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 15
//	                slv_reg15[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h10: begin end//fi_send_count
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 16
//	                slv_reg16[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h11: begin end//fi_recv_count
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 17
//	                slv_reg17[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h12: begin end//[31:16]: no_avail_count [15:0]:request_fail_count
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 18
//	                slv_reg18[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h13: begin end//[31:16]curr_frame_len, [15:0] collision_count
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 19
//	                slv_reg19[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h14: //fpga_irq_out_reg, write any to set irq_readed_linux
                irq_readed_linux_set <= 1;
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 20
//	                slv_reg20[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end
	          5'h15: begin end //fpga_async_cause
//	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                // Respective byte enables are asserted as per write strobes 
//	                // Slave register 21
//	                slv_reg21[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          5'h16:
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 22
	                slv_reg22[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h17:
	            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 23
	                slv_reg23[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                      slv_reg4 <= slv_reg4;
	                      slv_reg5 <= slv_reg5;
	                      slv_reg6 <= slv_reg6;
	                      slv_reg7 <= slv_reg7;
	                      slv_reg8 <= slv_reg8;
	                      slv_reg9 <= slv_reg9;
	                      slv_reg10 <= slv_reg10;
	                      slv_reg11 <= slv_reg11;
	                      slv_reg12 <= slv_reg12;
	                      slv_reg13 <= slv_reg13;
	                      slv_reg14 <= slv_reg14;
	                      slv_reg15 <= slv_reg15;
	                      slv_reg16 <= slv_reg16;
	                      slv_reg17 <= slv_reg17;
	                      slv_reg18 <= slv_reg18;
	                      slv_reg19 <= slv_reg19;
	                      slv_reg20 <= slv_reg20;
	                      slv_reg21 <= slv_reg21;
	                      slv_reg22 <= slv_reg22;
	                      slv_reg23 <= slv_reg23;
	                    end
	        endcase
	      end
	  end
	end    
    
    always @ (*)
    begin
         // 0: tdma_enable
        // 1: slot_adj_ena
        // 2: frame_adj_ena
        // 3: randon_bch_if_single
        tdma_function_enable = slv_reg8[0];
        slot_adj_ena = slv_reg8[1];
        frame_adj_ena = slv_reg8[2];
        randon_bch_if_single = slv_reg8[3];
        
        global_sid = slv_reg9[7:0];
        global_priority = slv_reg11[1:0];
        bch_user_pointer[DATA_WIDTH/2 -1:0] = slv_reg7[DATA_WIDTH/2 -1:0];
        if (slv_reg10[15:0] == 0)
            bch_candidate_c3hop_thres_s1 = BCH_CANDIDATE_C3HOP_THRES_S1;
        else
            bch_candidate_c3hop_thres_s1 = slv_reg10[8:0];
        	       // 16bits LSB: adj_frame_lower_bound,
                   // 16bits MSB: adj_frame_upper_bound,
        if (slv_reg12[15:0] == 0)
            adj_frame_lower_bound = ADJ_FRAME_LOWER_BOUND_DEFAULT;
        else
            adj_frame_lower_bound = slv_reg12[15:0];
        if (slv_reg12[31:16] == 0)
            adj_frame_upper_bound = ADJ_FRAME_UPPER_BOUND_DEFAULT;
        else
            adj_frame_upper_bound = slv_reg12[31:16];
        
        input_random = slv_reg13;
        default_frame_len_user = slv_reg14;
        
        if (slv_reg5 == 1)
            utc_sec_32bit = slv_reg6;
        else
            utc_sec_32bit = 0; 
            
    end
    
    reg [1:0] rxfifo_enable_state;
    always @ (posedge S_AXI_ACLK)
    begin
        if ( S_AXI_ARESETN == 0 ) begin
            rxfifo_wr_start <= 0;
            rxfifo_enable_state <= 0;
        end else begin
            if (rxfifo_enable_state == 0 && rxfifo_write_enable) begin
                rxfifo_wr_data <= slv_reg2;
                rxfifo_wr_start <= 1;
                rxfifo_enable_state <= 1;
            end
            else if (rxfifo_enable_state == 1) begin
                rxfifo_enable_state <= 2;
            end
            else if (rxfifo_enable_state == 2) begin
                rxfifo_wr_start <= 0;
                rxfifo_enable_state <= 0;
            end            
        end
    end

    /**
     * Tx Buf FIFO
     **/
    reg [1:0] txfifo_enable_state;
     always @ (posedge S_AXI_ACLK)
     begin
         if ( S_AXI_ARESETN == 0 ) begin
             txfifo_wr_start <= 0;
             txfifo_enable_state <= 0;
         end else begin
             if (txfifo_enable_state == 0 && txfifo_write_enable) begin
                 txfifo_wr_data <= slv_reg4;
                 txfifo_wr_start <= 1;
                 txfifo_enable_state <= 1;
             end
             else if (txfifo_enable_state == 1) begin
                 txfifo_enable_state <= 2;
             end
             else if (txfifo_enable_state == 2) begin
                 txfifo_wr_start <= 0;
                 txfifo_enable_state <= 0;
             end            
         end
     end
        
    /**
     * ����TxDesc��FIFO
     **/
	always @( posedge S_AXI_ACLK )
     begin
         if ( S_AXI_ARESETN == 1'b0 ) begin
            fifo_write_status <= 0;
            fifo_write_cpl_pulse <= 1'b0;
            s_axi_error2 <= 1'b0;
            
         end
          else begin 
             if ( fifo_write_enable && fifo_write_status == 0 && !S_FIFO_FULL ) begin
                 fifo_dwrite[31 : 0] <= slv_reg0[DATA_WIDTH-1 : 0];     
                 fifo_dwrite[63 : 32] <= slv_reg1[DATA_WIDTH-1 : 0];
                 fifo_write_status <= 1;
                 fifo_wr_en <= 1;
             end
             else if ( fifo_write_status == 1 ) begin
                 fifo_wr_en <= 0;  
                 fifo_write_cpl_pulse <= 1;
                 fifo_write_status <= 2;
             end
             else if ( fifo_write_status == 2 ) begin
                 fifo_write_status <= 0;
                 fifo_write_cpl_pulse <= 0;
             end
         end
     end
    
    
	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        5'h00   : reg_data_out <= slv_reg0;
	        5'h01   : reg_data_out <= slv_reg1;
	        5'h02   : reg_data_out <= slv_reg2;
	        5'h03   : reg_data_out <= slv_reg3;
	        5'h04   : reg_data_out <= slv_reg4;
	        5'h05   : reg_data_out <= slv_reg5;
	        5'h06   : reg_data_out <= slv_reg6;
	        5'h07   : reg_data_out <= slv_reg7;
	        5'h08   : reg_data_out <= slv_reg8;
	        5'h09   : reg_data_out <= slv_reg9;
	        5'h0A   : reg_data_out <= slv_reg10;
	        5'h0B   : reg_data_out <= slv_reg11;
	        5'h0C   : reg_data_out <= slv_reg12;
	        5'h0D   : reg_data_out <= slv_reg13;
	        5'h0E   : reg_data_out <= slv_reg14;
	        5'h0F   : reg_data_out <= slv_reg15;
	        5'h10   : reg_data_out <= slv_reg16;
	        5'h11   : reg_data_out <= slv_reg17;
	        5'h12   : reg_data_out <= slv_reg18;
	        5'h13   : reg_data_out <= slv_reg19;
	        5'h14   : reg_data_out <= slv_reg20;
	        5'h15   : reg_data_out <= slv_reg21;
	        5'h16   : reg_data_out <= slv_reg22;
	        5'h17   : reg_data_out <= slv_reg23;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// Add user logic here

	// User logic ends

	endmodule
