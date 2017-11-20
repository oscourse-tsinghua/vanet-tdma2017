
`timescale 1 ns / 1 ps

	module axi_S00 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 4
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
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
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
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
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
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_FIFO_DWRITE,
        input wire  S_FIFO_WR_ACK,
        input wire  S_FIFO_OVERFLOW,
        
        output wire  S_DEBUG_GPIO,
        output reg S_IRQ_READED_LINUX
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
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

    // FIFO signals
    reg [C_S_AXI_DATA_WIDTH-1 : 0] fifo_dwrite;
    reg fifo_wr_en = 1'b0;    
    
    reg debug_gpio;
    
	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;
	//----------------------------------------------
	////-- Signals for user logic register space example
	//------------------------------------------------
	////-- Number of Slave Registers 4
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
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
    reg [2:0]fifo_write_status = 3'b000;
    // fifo空闲为起始，写第一个数据时使用 fifo_write_enable_latched 信号，
    // 第一个数据没有写完又来了第二个数据时使用 fifo_write_enable 信号
    reg fifo_write_enable;
    reg fifo_write_enable_latched;
    reg fifo_write_cpl_pulse = 1'b0;
    reg isAddr = 1'b0;
    reg [1:0]fifo_write_enable_status = 2'b00;
    //reg fifo_write_enable_latched_status = 1'b0;

    reg irq_readed_linux;
    reg irq_done;
    
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      //slv_reg3 <= 0;
	      isAddr <= 1'b0;
	      s_axi_error1 <= 1'b0;
	      fifo_write_enable <= 1'b0;
	      fifo_write_enable_latched <= 1'b0;
	      fifo_write_enable_status <= 0;
	      //fifo_write_enable_latched_status <= 1'b0;
	      irq_readed_linux <= 0;
	      
	    end 
	  else begin

        if ( fifo_write_enable_latched && fifo_write_cpl_pulse ) begin
            fifo_write_enable_latched <= 1'b0;
        end

        // fifo_write_enable 信号维持 3个周期。
        if( fifo_write_enable_status == 1 ) begin
            fifo_write_enable_status <= 2;
        end
        else if ( fifo_write_enable_status == 2 ) begin
            fifo_write_enable_status <= 3;
        end
        else if ( fifo_write_enable_status == 3 ) begin
            fifo_write_enable_status <= 0;
            fifo_write_enable <= 0;
        end
        
        if (irq_done && irq_readed_linux)
            irq_readed_linux <= 0;
                    
        	    
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          2'h0: begin //用来存地址，驱动程序必须要保证先写地址后写数据。
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
                isAddr = 1'b1;
                // 下面这么写的意义在于，万一从axi到达数据的速度快于往fifo写入的数据（不太可能发生），
                // 第一个数据正常写入的同时第二个数据抵达，则此时fifo_write_status != 0 
                // 且 fifo_write_enable_latched 为 1. 则第二个数据可以等一会儿再写入。如果第一个数据未完成的
                // 情况下第三个数据又抵达了，此时fifo_write_status != 0且fifo_write_enable(和latched） != 0.
                // 这种情况下数据就会丢失或错乱。
                if ( fifo_write_status != 0 && fifo_write_enable_latched && fifo_write_enable ) begin
                    s_axi_error1 = 1;
                end
                else if ( fifo_write_status != 0 && fifo_write_enable_latched && !fifo_write_enable ) begin 
                    fifo_write_enable <= 1'b1;
                    fifo_write_enable_status <= 1;   
                end
                else begin
                    fifo_write_enable_latched <= 1'b1;
                end
              end
	          2'h1: begin //用来存数据
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
                end
                isAddr <= 1'b0;
                
                if ( fifo_write_status != 0 && fifo_write_enable_latched && fifo_write_enable ) begin
                    s_axi_error1 = 1;
                end
                else if ( fifo_write_status != 0 && fifo_write_enable_latched && !fifo_write_enable ) begin 
                    fifo_write_enable <= 1'b1;
                    fifo_write_enable_status <= 1;   
                end
                else begin
                    fifo_write_enable_latched <= 1'b1;
                end
              end
	          2'h2: begin //用来表示已经读取中断，需要清除由FPGA发出的中断
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
                
                irq_readed_linux <= 1; 
              end
	          2'h3:
	          begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                //slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	            end	            
              end
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      //slv_reg3 <= slv_reg3;
	                    end
	        endcase
	      end
	  end
	end    
	
    // 寄存器2和3用来测试内存映射的正确性
    always @( posedge S_AXI_ACLK )
    begin
       slv_reg3 <= slv_reg2;
    end    	
    
    reg [2:0] irq_status;
	always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            irq_status <= 0;
            irq_done <= 1;
            S_IRQ_READED_LINUX <= 0;
            debug_gpio <= 1'b1;
        end
        else begin 	
            case (irq_status)
            0: 
                if (irq_readed_linux) begin
                    irq_done <= 0;
                    S_IRQ_READED_LINUX <= 1;
                    irq_status <= 1;
                    debug_gpio <= !debug_gpio; 
                end
            1: begin
                irq_status <= 2;
                irq_done <= 1;
            end
            2: begin
                irq_status <= 0;
                S_IRQ_READED_LINUX <= 0;
            end
            endcase
        end
    end
    
	always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
           fifo_write_status <= 0;
           fifo_write_cpl_pulse <= 1'b0;
           s_axi_error2 <= 1'b0;
           
        end
        else begin 
            if ( (fifo_write_enable_latched || fifo_write_enable) && fifo_write_status == 0 && !S_FIFO_FULL ) begin
                if ( isAddr ) begin
                    // write a magic word to fifo 
                    fifo_dwrite[C_S_AXI_DATA_WIDTH-1 : 0] <= 0;
                    fifo_write_status <= 1;
                end
                else begin
                    fifo_dwrite[C_S_AXI_DATA_WIDTH-1 : 0] <= slv_reg1[C_S_AXI_DATA_WIDTH-1 : 0];
                    fifo_write_status <= 3;
                    
                end
                fifo_wr_en <= 1'b1;
            end
            else if ( fifo_write_status == 1 && S_FIFO_WR_ACK ) begin
                //fifo_wr_en <= 1'b0;
                fifo_write_status <= 2;   
                // write addr to fifo
                fifo_dwrite[C_S_AXI_DATA_WIDTH-1 : 0] <= slv_reg0[C_S_AXI_DATA_WIDTH-1 : 0];            
            end
            else if ( fifo_write_status == 2  ) begin
                //fifo_wr_en <= 1'b1;
                fifo_write_status <= 3;
                //debug_gpio <= !debug_gpio; 
            end
            else if ( fifo_write_status == 3 && S_FIFO_WR_ACK ) begin
                fifo_wr_en <= 1'b0;  
                fifo_write_status <= 4;
                fifo_write_cpl_pulse <= 1;
            end
            else if ( fifo_write_status == 4 ) begin
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
	        2'h0   : reg_data_out <= slv_reg0;
	        2'h1   : reg_data_out <= slv_reg1;
	        2'h2   : reg_data_out <= slv_reg2;
	        2'h3   : reg_data_out <= slv_reg3;
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
