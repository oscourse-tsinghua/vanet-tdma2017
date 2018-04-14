`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/02/15 13:07:07
// Design Name: 
// Module Name: txdesc_processor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

(* DONT_TOUCH = "yes" *)
module desc_processor # (
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer C_LENGTH_WIDTH = 12,
    parameter integer C_PKT_LEN = 256,
    parameter integer FRAME_SLOT_NUM = 64,
    parameter integer OCCUPIER_LIFE_FRAME = 3,
    parameter integer SLOT_NS = 1000000, //1 ms
    parameter integer TX_GUARD_NS = 70000, // 70 us
    parameter integer TIME_PER_BYTE_12M_NS = 700 // 700 ns per byte under 12 Mbps
)
(
    // CLK
    input wire clk,
    input wire reset_n,
    input wire fifo_reset,
    output reg tx_proc_error,
    // FIFO signals
    input wire  fifo_empty,
    input wire [63 : 0] fifo_dread,
    output reg fifo_rd_en,
    input wire  fifo_valid,
    input wire  fifo_underflow,

    input wire  rxfifo_empty,
    input wire [DATA_WIDTH-1 : 0] rxfifo_dread,
    output reg rxfifo_rd_en,
    input wire  rxfifo_valid,
    input wire  rxfifo_underflow,
    
    output reg rxfifo_wr_start,
    output reg [DATA_WIDTH-1:0] rxfifo_wr_data,
    input wire rxfifo_wr_done,
        
    // IRQ input and output
    input wire irq_in,
    output reg irq_out,
    //input wire irq_readed_linux,
    
    //Debug
    output reg [2 : 0] debug_gpio,
    output wire [7:0] debug_port_8bits,
    output reg recv_pkt_pulse,
    output reg [31:0] lastpkt_txok_timemark1,
    output reg [31:0] lastpkt_txok_timemark2,
   
    input wire [31:0] gps_pulse1_counter,
    input wire [31:0] gps_pulse2_counter, 
    
    output reg recv_ping,
    output reg [31:0] recved_seq,
    output reg recv_ack_ping,
    output reg [31:0] recved_sec,
    output reg [31:0] recved_counter2,
    
    //output reg test_sendpkt,
    // IPIC LITE

    //-----------------------------------------------------------------------------------------
    //-- IPIC STATE MACHINE
    //-----------------------------------------------------------------------------------------     
    input wire [5:0] curr_ipic_state,
    output reg [2:0] ipic_type,
    output reg ipic_start,
    input wire ipic_ack,
    input wire ipic_done_wire,
    output reg [ADDR_WIDTH-1 : 0] read_addr,
    output reg [C_LENGTH_WIDTH-1 : 0] read_length, 
    input wire [DATA_WIDTH-1 : 0] single_read_data,
//    input wire [2047 :0] bunch_read_data, 
    output reg [ADDR_WIDTH-1 : 0] write_addr,  
    output reg [DATA_WIDTH-1 : 0] write_data,
    output reg [C_LENGTH_WIDTH-1 : 0] write_length,

    output reg [8:0] blk_mem_rcvpkt_addrb,
    input wire [31:0] blk_mem_rcvpkt_doutb,

    //-----------------------------------------------------------------------------------------
    //-- IPIC LITE STATE MACHINE
    //-----------------------------------------------------------------------------------------     
    input wire [3:0] curr_ipic_lite_state,
    output reg [2:0] ipic_type_lite,
    output reg ipic_start_lite,   
    input wire ipic_ack_lite,
    input wire ipic_done_lite_wire,
    output reg [ADDR_WIDTH-1 : 0] read_addr_lite, 
    input wire [DATA_WIDTH-1 : 0] single_read_data_lite,
    output reg [ADDR_WIDTH-1 : 0] write_addr_lite,  
    output reg [DATA_WIDTH-1 : 0] write_data_lite,
    
    //-----------------------------------------------------------------------------------------
    //-- block memory for storing slot status. 64bits 128dept.
    //-----------------------------------------------------------------------------------------     
    output reg [6:0] blk_mem_slot_status_addr,
    output reg [63:0] blk_mem_slot_status_din,
    input wire [63:0] blk_mem_slot_status_dout,
    output reg blk_mem_slot_status_we,
    
    input wire [7:0] global_sid,
    input wire [1:0] global_priority,
    input wire tdma_function_enable,
    input wire tdma_tx_enable,
    input wire [9:0] slot_pulse2_counter, //pulse2 counter in curr slot
    input wire [31:0] bch_control_time_ns,
    //IRQ Status
    output wire [5:0] curr_irq_state_wire
);

    wire used_rxfifo_full;
    reg [DATA_WIDTH-1 : 0] used_rxfifo_dwrite;
    reg used_rxfifo_wr_en;
    //wire used_rxfifo_almost_full;
    wire used_rxfifo_empty;
    wire [DATA_WIDTH-1 : 0] used_rxfifo_dread;
    reg used_rxfifo_rd_en;
    //wire used_rxfifo_almost_empty;
    wire used_rxfifo_wr_ack;
    //wire used_rxfifo_overflow;
    //wire used_rxfifo_underflow;
    wire used_rxfifo_valid;
    
    cmd_fifo used_rxfifo_inst (
      .clk(clk),                // input wire clk
      .rst(fifo_reset),
      .din(used_rxfifo_dwrite),                // input wire [31 : 0] din
      .wr_en(used_rxfifo_wr_en),            // input wire wr_en
      .rd_en(used_rxfifo_rd_en),            // input wire rd_en
      .dout(used_rxfifo_dread),              // output wire [31 : 0] dout
      .full(used_rxfifo_full),              // output wire full
      .wr_ack(used_rxfifo_wr_ack),          // output wire wr_ack
      .empty(used_rxfifo_empty),            // output wire empty
      .valid(used_rxfifo_valid)            // output wire valid  
    );  

    //-----------------------------------------------------------------------------------------
    //--IPIC transaction state machine:
    ////0: burst read transaction
    ////1: burst write transaction
    ////2: single read transaction
    ////3: single write transaction
    //-----------------------------------------------------------------------------------------
    `define BURST_RD 0
    `define BURST_WR 1
    `define SINGLE_RD 2
    `define SINGLE_WR 3
    `define SET_ZERO 4

    `define UR 0
    `define IRQ 1
    `define TXFR 2
    `define PIRQ 3
    `define ESDUR 4
    /////////////////////////////////////////////////////////////
    // IPIC Burst Interface
    /////////////////////////////////////////////////////////////
    reg [2:0] ipic_dispatch_type;
    reg [2:0] ipic_type_irq;   
    reg ipic_start_irq;
    reg ipic_ack_irq;
    reg [C_LENGTH_WIDTH-1 : 0] read_length_irq;
    reg [ADDR_WIDTH-1 : 0] read_addr_irq;
    reg [C_LENGTH_WIDTH-1 : 0] write_length_irq;
    reg [ADDR_WIDTH-1 : 0] write_addr_irq;
    
    reg [2:0] ipic_type_ur;
    reg ipic_start_ur;
    reg ipic_ack_ur;
    reg [C_LENGTH_WIDTH-1 : 0] write_length_ur;
    reg [ADDR_WIDTH-1 : 0] write_addr_ur;
    
    reg [2:0] ipic_type_esdur;   
    reg ipic_start_esdur;
    reg ipic_ack_esdur;
    reg [ADDR_WIDTH-1 : 0] read_addr_esdur;
      
    reg [2:0] ipic_start_state; 
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_start <= 0;
            ipic_type <= 0;
            read_addr <= 0;
            read_length <= 0;            
            write_addr <= 0;
            write_length <= 0;     
            ipic_start_state <= 0;       
            ipic_ack_irq <= 0;
            ipic_ack_ur <= 0;
            ipic_ack_esdur <= 0;
        end else begin
            case(ipic_start_state)
                0:begin
                    if (ipic_start_irq) begin
                        //ipic_ack_irq <= 1;
                        ipic_dispatch_type <= `IRQ;
                        ipic_type <= ipic_type_irq;
                        read_addr <= read_addr_irq;
                        read_length <= read_length_irq;
                        write_addr <= write_addr_irq;
                        write_length <= write_length_irq;
                        ipic_start <= 1;
                        ipic_start_state <= 1; 
                    end else if (ipic_start_ur) begin
                        //ipic_ack_ur <= 1;
                        ipic_dispatch_type <= `UR;
                        ipic_type <= ipic_type_ur;
                        write_addr <= write_addr_ur;
                        write_length <= write_length_ur;
                        ipic_start <= 1;
                        ipic_start_state <= 1;                     
                    end else if (ipic_start_esdur) begin
                        ipic_dispatch_type <= `ESDUR;
                        ipic_type <= ipic_type_esdur;
                        read_addr <= read_addr_esdur;
                        ipic_start <= 1;
                        ipic_start_state <= 1; 
                    end
                end
                1: begin
                    if (ipic_ack) begin
                        case (ipic_dispatch_type)
                            `IRQ: ipic_ack_irq <= 1;
                            `UR: ipic_ack_ur <= 1;
                            `ESDUR: ipic_ack_esdur <= 1;
                            default: begin 
                                ipic_ack_irq <= 0;
                                ipic_ack_ur <= 0;
                                ipic_ack_esdur <= 0;
                            end
                        endcase
                        ipic_start_state <= 2; 
                    end
                end
                2: begin
                    ipic_start <= 0;
                    ipic_start_state <= 0; 
                    ipic_ack_irq <= 0;
                    ipic_ack_ur <= 0;
                    ipic_ack_esdur <= 0;
                    if (ipic_done_wire) begin
                        ipic_start_state <= 0; 
                    end
                end
                default: begin end
            endcase
        end        
    end
    
    /////////////////////////////////////////////////////////////
    // IPIC Lite Interface
    /////////////////////////////////////////////////////////////
    reg [2:0] ipic_dispatch_type_lite;
    reg [2:0] ipic_type_lite_irq;  
    reg ipic_start_lite_irq;
    reg ipic_ack_lite_irq;
    reg [ADDR_WIDTH-1 : 0] read_addr_lite_irq;
    reg [ADDR_WIDTH-1 : 0] write_addr_lite_irq;
    reg [DATA_WIDTH-1 : 0] write_data_lite_irq;

    reg [2:0] ipic_type_lite_ur;  
    reg ipic_start_lite_ur;
    reg ipic_ack_lite_ur;
    reg [ADDR_WIDTH-1 : 0] write_addr_lite_ur;
    reg [DATA_WIDTH-1 : 0] write_data_lite_ur;    
    
    reg [2:0] ipic_type_lite_pirq;  
    reg ipic_start_lite_pirq;
    reg ipic_ack_lite_pirq;
    reg [ADDR_WIDTH-1 : 0] write_addr_lite_pirq;
    reg [DATA_WIDTH-1 : 0] write_data_lite_pirq;  
    
    reg [2:0] ipic_type_lite_txfr;
    reg ipic_start_lite_txfr;
    reg ipic_ack_lite_txfr;     
    reg [ADDR_WIDTH-1 : 0] write_addr_lite_txfr;
    reg [DATA_WIDTH-1 : 0] write_data_lite_txfr;
     
    reg [2:0] ipic_start_lite_state;     
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_start_lite <= 0;
            ipic_type_lite <= 0;
            read_addr_lite <= 0;          
            write_addr_lite <= 0; 
            ipic_start_lite_state <= 0;  
            ipic_ack_lite_irq <= 0;
            ipic_ack_lite_txfr <= 0;     
            ipic_ack_lite_ur <= 0;
            ipic_ack_lite_pirq <= 0;
        end else begin
            case(ipic_start_lite_state)
                0:begin
                    if (ipic_start_lite_irq) begin
                        //ipic_ack_lite_irq <= 1;
                        ipic_dispatch_type_lite <= `IRQ;
                        ipic_type_lite <= ipic_type_lite_irq;
                        read_addr_lite <= read_addr_lite_irq;
                        write_addr_lite <= write_addr_lite_irq;
                        write_data_lite <= write_data_lite_irq;
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1; 
                    end else if (ipic_start_lite_txfr) begin 
                        //ipic_ack_lite_txfr <= 1;
                        ipic_dispatch_type_lite <= `TXFR;
                        ipic_type_lite <= ipic_type_lite_txfr;
                        write_addr_lite <= write_addr_lite_txfr;
                        write_data_lite <= write_data_lite_txfr;
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1;                         
                    end else if (ipic_start_lite_ur) begin
                        //ipic_ack_lite_ur <= 1;
                        ipic_dispatch_type_lite <= `UR;
                        ipic_type_lite <= ipic_type_lite_ur;
                        write_addr_lite <= write_addr_lite_ur;
                        write_data_lite <= write_data_lite_ur;
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1;  
                    end else if (ipic_start_lite_pirq) begin
                        //ipic_ack_lite_pirq <= 1;
                        ipic_dispatch_type_lite <= `PIRQ;
                        ipic_type_lite <= ipic_type_lite_pirq;
                        write_addr_lite <= write_addr_lite_pirq;
                        write_data_lite <= write_data_lite_pirq;  
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1;                        
                    end
                end
                1: begin
                    if (ipic_ack_lite) begin
                        case (ipic_dispatch_type_lite)
                            `IRQ: ipic_ack_lite_irq <= 1;
                            `UR: ipic_ack_lite_ur <= 1;
                            `TXFR: ipic_ack_lite_txfr <= 1;
                            `PIRQ: ipic_ack_lite_pirq <= 1;
                            default: begin 
                                ipic_ack_lite_irq <= 0;
                                ipic_ack_lite_txfr <= 0;     
                                ipic_ack_lite_ur <= 0;
                                ipic_ack_lite_pirq <= 0;
                            end
                        endcase
                        ipic_start_lite_state <= 2; 
                    end
                end
                2: begin
                    ipic_ack_lite_irq <= 0;
                    ipic_ack_lite_txfr <= 0;     
                    ipic_ack_lite_ur <= 0;
                    ipic_ack_lite_pirq <= 0;
                    ipic_start_lite <= 0;
                    if (ipic_done_lite_wire) begin
                        ipic_start_lite_state <= 0; 
                    end
                end
                default: begin end
            endcase
        end        
    end

    localparam PCIECTL_BASE_ADDR = 32'h50000000;
    localparam PCIECTL_INT_DECODE = 32'h138;
    localparam PCIECTL_INT_FIFO_REG1 = 32'h158;
    
    localparam ATH9K_BASE_ADDR  =    32'h60000000;
    localparam AR_IER  =    32'h0024;
    localparam AR_IER_ENABLE  =    32'h00000001;
    localparam AR_IER_DISABLE  =    32'h00000000;
    localparam AR_INTR_ASYNC_CAUSE = 32'h4038;
    localparam AR_INTR_SYNC_CAUSE = 32'h4028; 
    localparam AR_RTC_STATUS = 32'h7044;
    localparam AR_ISR = 32'h0080;
    localparam AR_ISR_RAC = 32'h00c0; //Read-to-clear ISR_P
    localparam AR_ISR_S0 = 32'h0084; //TXOK per QCU isr register 
    
    localparam AR_INTR_MAC_IRQ = 32'h00000002;
    localparam AR_RTC_STATUS_M = 32'h0000000f;
    localparam AR_RTC_STATUS_ON = 32'h00000002;
    localparam AR_ISR_LP_RXOK = 32'h00000002;
    localparam AR_ISR_HP_RXOK = 32'h00000001;
    localparam AR_ISR_RXINTM = 32'h80000000;
    localparam AR_ISR_RXMINTR = 32'h01000000;
    localparam AR_ISR_TXOK = 32'h00000040;
    
    localparam FPGA_QCU = 32'h040;
    
    localparam RX_DONE_ADDR = 11; //ar9003_rxs->status11
    localparam RX_TYPE_ADDR = 20;
    localparam AR_RxDone = 32'h00000001;
    
    localparam AR_HP_RXDP = 32'h0074;
    
    localparam IEEE80211_FCTL_FTYPE	= 32'h000c;
    localparam IEEE80211_FCTL_STYPE = 32'h00f0;
    localparam IEEE80211_FTYPE_CTL = 32'h0004;
    localparam IEEE80211_STYPE_TDMA	= 0;
    localparam IEEE80211_STYPE_TDMA1 = 32'h0010;
    
    `define PING        1
    `define ACK_PING    2
    `define BCH_REQ     3
    `define BCH_FI      4
    `define BCH_ADJ     5
    `define BCH_BAN     6
  
    parameter PIRQ_IDLE = 0, 
                PIRQ_CLR_START = 1, PIRQ_CLR_MID = 2, PIRQ_CLR_WAIT = 3,
                PIRQ_CLR_FIFO_START = 4, PIRQ_CLR_FIFO_MID = 5, PIRQ_CLR_FIFO_WAIT = 6,
                PIRQ_DONE = 7, PIRQ_ERROR = 8;
    reg [3:0] curr_pirq_state;
    reg [3:0] next_pirq_state;

    reg irq_start_clr_pirq;
    reg pirq_done;
  
    always @ (posedge clk)
    begin
        if ( reset_n == 0 )
            curr_pirq_state <= PIRQ_IDLE;           
        else
            curr_pirq_state <= next_pirq_state; 
    end 
    
    always @ (curr_pirq_state)
    begin
        case (curr_pirq_state)
            PIRQ_IDLE:
                if (irq_start_clr_pirq)
                    next_pirq_state <= PIRQ_CLR_START;
                else
                    next_pirq_state <= PIRQ_IDLE;
            PIRQ_CLR_START: next_pirq_state <= PIRQ_CLR_MID;
            PIRQ_CLR_MID:
                if (ipic_ack_lite_pirq)
                    next_pirq_state <= PIRQ_CLR_WAIT;
                else
                    next_pirq_state <= PIRQ_CLR_MID;
            PIRQ_CLR_WAIT: 
                if (ipic_done_lite_wire)
                    next_pirq_state <= PIRQ_CLR_FIFO_START;
                else
                    next_pirq_state <= PIRQ_CLR_WAIT;
            PIRQ_CLR_FIFO_START: next_pirq_state <= PIRQ_CLR_FIFO_MID;
            PIRQ_CLR_FIFO_MID:
                if (ipic_ack_lite_pirq)
                    next_pirq_state <= PIRQ_CLR_FIFO_WAIT;
                else
                    next_pirq_state <= PIRQ_CLR_FIFO_MID;    
            PIRQ_CLR_FIFO_WAIT:
                if (ipic_done_lite_wire)
                    if (irq_in)
                        next_pirq_state <= PIRQ_CLR_START;
                    else
                        next_pirq_state <= PIRQ_DONE;
                else
                    next_pirq_state <= PIRQ_CLR_FIFO_WAIT;
            PIRQ_DONE: next_pirq_state <= PIRQ_IDLE;
            default: next_pirq_state <= PIRQ_ERROR;
        endcase
    end
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            pirq_done <= 0;
            ipic_start_lite_pirq <= 0;
        end else begin
            case (next_pirq_state)
                PIRQ_IDLE: pirq_done <= 0;
                PIRQ_CLR_START: begin
                    write_addr_lite_pirq <= PCIECTL_BASE_ADDR + PCIECTL_INT_DECODE;
                    write_data_lite_pirq <= 32'h10000;
                    ipic_type_lite_pirq <= `SINGLE_WR;
                    ipic_start_lite_pirq <= 1;                  
                end
                //PIRQ_CLR_MID:
                PIRQ_CLR_WAIT: ipic_start_lite_pirq <= 0;
                PIRQ_CLR_FIFO_START: begin
                    write_addr_lite_pirq <= PCIECTL_BASE_ADDR + PCIECTL_INT_FIFO_REG1;
                    write_data_lite_pirq <= 32'hffffffff;
                    ipic_type_lite_pirq <= `SINGLE_WR;
                    ipic_start_lite_pirq <= 1;                
                end
                //PIRQ_CLR_FIFO_MID:
                PIRQ_CLR_FIFO_WAIT: ipic_start_lite_pirq <= 0;
                PIRQ_DONE: pirq_done <= 1; 
                default: begin end           
            endcase
        end
    end
            
    
    parameter UR_IDLE = 0, UR_JUDGE = 8, UR_DONE = 9,
                UR_CLR_BUF = 1, UR_HW_PUSHBACK_START = 2, UR_HW_PUSHBACK_MID=7, 
                UR_WAIT_CLR = 4, UR_WAIT_PUSHBACK = 5, UR_ERROR = 6;
    reg [3:0] curr_used_rxfifo_state;
    reg [3:0] next_used_rxfifo_state;
    
    reg [DATA_WIDTH-1:0] current_ur_addr;
    reg irq_start_pushback;
    reg ur_done;
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 )
            curr_used_rxfifo_state <= UR_IDLE;           
        else
            curr_used_rxfifo_state <= next_used_rxfifo_state; 
    end 

    /**
     */
    always @ (curr_used_rxfifo_state)//tlflag or ipic_done_wire or proc_done or  testing_done or curr_py_state)
    begin
        case (curr_used_rxfifo_state)
            UR_IDLE: 
                if ( irq_start_pushback )
                    next_used_rxfifo_state <= UR_JUDGE;
                else
                    next_used_rxfifo_state <= UR_IDLE;                
            UR_JUDGE:
                if ( used_rxfifo_valid && !used_rxfifo_empty )
                    next_used_rxfifo_state <= UR_CLR_BUF;
                else
                    next_used_rxfifo_state <= UR_DONE;
            UR_CLR_BUF: next_used_rxfifo_state <= UR_HW_PUSHBACK_START;
            UR_HW_PUSHBACK_START: next_used_rxfifo_state <= UR_HW_PUSHBACK_MID;
            UR_HW_PUSHBACK_MID: 
                if (ipic_ack_lite_ur)
                    next_used_rxfifo_state <= UR_WAIT_CLR;
                else
                    next_used_rxfifo_state <= UR_HW_PUSHBACK_MID;
            UR_WAIT_CLR: 
                if ( ipic_done_wire )
                    next_used_rxfifo_state <= UR_WAIT_PUSHBACK;
                else
                    next_used_rxfifo_state <= UR_WAIT_CLR;
            UR_WAIT_PUSHBACK:
                if ( curr_ipic_lite_state == 0 )
                    next_used_rxfifo_state <= UR_JUDGE;
                else
                    next_used_rxfifo_state <= UR_WAIT_PUSHBACK;
            UR_DONE: next_used_rxfifo_state <= UR_IDLE;
            default: next_used_rxfifo_state <= UR_ERROR;
        endcase
    end
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin
            used_rxfifo_rd_en <= 0;
            ipic_start_lite_ur <= 0;
            ur_done <= 0;
        end else begin
            case (next_used_rxfifo_state)
                UR_IDLE: ur_done <= 0;
                //UR_JUDGE:
                UR_CLR_BUF: begin
                    used_rxfifo_rd_en <= 1;   
                    write_addr_ur <= used_rxfifo_dread;
                    current_ur_addr <= used_rxfifo_dread;
                    write_length_ur <= C_PKT_LEN;
                    ipic_type_ur <= `SET_ZERO;
                    ipic_start_ur <= 1;  //!!!!Remeber to clear ipic_start_ur bit!!!!!     
                end
                UR_HW_PUSHBACK_START: begin
                    used_rxfifo_rd_en <= 0;
                    //Push the processed buf addr back to HP QUEUE of HW.  
                    write_addr_lite_ur <= ATH9K_BASE_ADDR + AR_HP_RXDP;
                    write_data_lite_ur <= current_ur_addr;
                    ipic_type_lite_ur <= `SINGLE_WR;
                    ipic_start_lite_ur <= 1; //!!!!Remeber to clear ipic_start_lite_irq bit!!!!!                       
                end
                UR_HW_PUSHBACK_MID: ipic_start_ur <= 0;
                UR_WAIT_CLR: ipic_start_lite_ur <= 0;
                //UR_WAIT_PUSHBACK:
                UR_DONE: ur_done <= 1;
                default: begin end
            endcase
        end
    end    

    /********************
    * slot_status (5 bits)      0~4     : nothing (0), decide_req (1), req (2), fi (3), decide_adj (4), adj (5), 
    * Busy1 & Busy2 (2 bits)    5~6
    * occupier_sid (8 bits)     7~14
    * count_2hop (8 bits)       15~22
    * count_3hop (9 bits)       23~31
    * PSF (2 bits)              32~33
    * life (10 bits)            34~43
    * c3hop_n                   44      //valid when we need to accumulate count_3hop from a 2-hop neighbor. 
    *                                   //  set, indicates that this neighbor has accumulated to count_3hop.
    *                                   //  clear, otherwise.
    *********************/
    localparam STATUS_LSB = 0, STATUS_MSB = 4;
    localparam STATUS_NOTHING = 0, STATUS_DECIDE_REQ = 1, STATUS_REQ = 2, STATUS_FI = 3, STATUS_DECIDE_ADJ = 4, STATUS_ADJ = 5;
    localparam BUSY_LSB = 5, BUSY_MSB = 6;
    localparam OCCUPIER_SID_LSB = 7, OCCUPIER_SID_MSB = 14;
    localparam COUNT_2HOP_LSB = 15, COUNT_2HOP_MSB = 22;
    localparam COUNT_3HOP_LSB = 23, COUNT_3HOP_MSB = 31;
    localparam PSF_LSB = 32, PSF_MSB = 33;
    localparam LIFE_LSB = 34, LIFE_MSB = 43;
    localparam C3HOP_N = 44;
    
    localparam FI_PER_SLOT_BITSNUM = 20;
    
    /*************************
    * FI Packet:
    * pkt_type: 0~4
    * sender_sid: 5~12
    * status per slot: 13~
    *   busy1/2:        0~1
    *   slot-occupier:  2~9   
    *   count:          10~17
    *   psf:            18~19
    **************************/
    localparam PKT_TYPE_MSB = 4, PKT_TYPE_LSB = 0;
    localparam FI_SENDER_SID_MSB = 12, FI_SENDER_SID_LSB = 5;
    localparam FI_S_PERSLOT_BUSY_MSB = 1, FI_S_PERSLOT_BUSY_LSB = 0;
    localparam FI_S_PERSLOT_OCCUPIER_SID_MSB = 9, FI_S_PERSLOT_OCCUPIER_SID_LSB = 2;
    localparam FI_S_PERSLOT_COUNT_MSB = 17, FI_S_PERSLOT_COUNT_LSB = 10;
    localparam FI_S_PERSLOT_PSF_MSB = 19, FI_S_PERSLOT_PSF_LSB = 18;
    
    /*************************
    * REQ Pakcet
    * pkt_type: 0~4
    * sender_sid: 5~12
    * req_psf:  13~14
    * req_target_slot: 15~22
    **************************/
    localparam REQ_SENDER_SID_MSB = 12, REQ_SENDER_SID_LSB = 5;
    localparam REQ_PSF_MSB = 14, REQ_PSF_LSB = 13;
    localparam REQ_TARGET_SLOT_MSB = 22, REQ_TARGET_SLOT_LSB = 15;

    /*************************
    * ADJ Pakcet
    * pkt_type: 0~4
    * sender_sid: 5~12
    * req_psf:  13~14
    * req_target_slot: 15~22
    **************************/
    localparam ADJ_SENDER_SID_MSB = 12, ADJ_SENDER_SID_LSB = 5;
    localparam ADJ_PSF_MSB = 14, ADJ_PSF_LSB = 13;
    localparam ADJ_TARGET_SLOT_MSB = 22, ADJ_TARGET_SLOT_LSB = 15;

    /*************************
    * BAN Pakcet
    * pkt_type: 0~4
    * sender_sid: 5~12
    * req_psf:  13~14
    * req_target_slot: 15~22
    **************************/
    localparam BAN_SENDER_SID_MSB = 12, BAN_SENDER_SID_LSB = 5;
    localparam BAN_PSF_MSB = 14, BAN_PSF_LSB = 13;
    localparam BAN_TARGET_SLOT_MSB = 22, BAN_TARGET_SLOT_LSB = 15;
        
    reg blk_mem_rcvpkt_en_stu;
    reg [8:0] blk_mem_rcvpkt_addrb_stu;
    reg [8:0] blk_mem_rcvpkt_addrb_irq;
    /////////////////////////////////////////////////////////////
    // Logic for accessing blk_mem_sendpkt
    /////////////////////////////////////////////////////////////
    always @ (*) //Only one of the enabling signals will be set at same time.
    begin
        if (blk_mem_rcvpkt_en_stu) begin
            blk_mem_rcvpkt_addrb = blk_mem_rcvpkt_addrb_stu;          
        end else begin
            blk_mem_rcvpkt_addrb = blk_mem_rcvpkt_addrb_irq;
        end
    end
    
    /////////////////////////////////////////////////////////////
    // State machine for updating the slot table. (STU_STATE_UPDATER MACHINE)
    // LOOP��blk_mem_slot_status_addr
    //  1. read slot status; judge; write back.
    /////////////////////////////////////////////////////////////
    parameter STU_IDLE = 0, STU_DISPATCH = 1,
            STU_FI_LOOP_1 = 2, STU_FI_LOOP_1_SETADDR = 3, STU_FI_LOOP_2 = 4, STU_FI_LOOP_2_CLR = 5,
            STU_REQ_PRE = 6, STU_REQ_START = 7, STU_REQ_END = 8,
            STU_BAN_START = 9, STU_BAN_END = 10,
            STU_END = 14, STU_ERROR = 15;
    (* mark_debug = "true" *) reg [3:0] stu_state;
    
    reg stu_start;
    reg stu_done;
    (* mark_debug = "true" *) reg [4:0] stu_type;
    (* mark_debug = "true" *)reg [6:0] bit_index;
    (* mark_debug = "true" *)reg [10:0] stu_index;
    (* mark_debug = "true" *)reg [FI_PER_SLOT_BITSNUM - 1 : 0] fi_per_slot;
    (* mark_debug = "true" *)reg [4:0] fi_per_slot_index;
    reg [7:0] stu_sender_sid;
    reg [7:0] stu_req_slot;
    reg [1:0] stu_req_psf;
    reg [7:0] stu_ban_slot;
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            stu_state <= STU_IDLE;
            stu_type <= 0;
            blk_mem_slot_status_we <= 0;
            blk_mem_rcvpkt_en_stu <= 0;
            fi_per_slot_index <= 0;
            stu_done <= 0;
        end else begin
            case (stu_state)
                STU_IDLE: begin
                    stu_done <= 0;
                    if (stu_start) begin
                        
                        blk_mem_rcvpkt_en_stu <= 1;
                        blk_mem_rcvpkt_addrb_stu <= RX_TYPE_ADDR;
                        stu_state <= STU_DISPATCH;
                    end
                end
                STU_DISPATCH: 
                    if (blk_mem_rcvpkt_doutb[PKT_TYPE_MSB : PKT_TYPE_LSB] == `BCH_REQ 
                            || blk_mem_rcvpkt_doutb[PKT_TYPE_MSB : PKT_TYPE_LSB] == `BCH_ADJ ) begin
                        stu_index <= 23;
                        
                        blk_mem_slot_status_addr <= blk_mem_rcvpkt_doutb[REQ_TARGET_SLOT_MSB : REQ_TARGET_SLOT_LSB];
                        stu_sender_sid <= blk_mem_rcvpkt_doutb[REQ_SENDER_SID_MSB : REQ_SENDER_SID_LSB];
                        stu_req_slot <= blk_mem_rcvpkt_doutb[REQ_TARGET_SLOT_MSB : REQ_TARGET_SLOT_LSB];
                        stu_req_psf <= blk_mem_rcvpkt_doutb[REQ_PSF_MSB : REQ_PSF_LSB];
                        stu_state <= STU_REQ_PRE;
                        
                    end else if (blk_mem_rcvpkt_doutb[PKT_TYPE_MSB : PKT_TYPE_LSB] == `BCH_FI) begin
                        stu_index <= 13;
                        blk_mem_slot_status_addr <= 0;
                        fi_per_slot_index <= 0;
                        stu_sender_sid <= blk_mem_rcvpkt_doutb[FI_SENDER_SID_MSB : FI_SENDER_SID_LSB];
                        stu_state <= STU_FI_LOOP_1;
                    end else if (blk_mem_rcvpkt_doutb[PKT_TYPE_MSB : PKT_TYPE_LSB] == `BCH_BAN) begin
                        blk_mem_slot_status_addr <= blk_mem_rcvpkt_doutb[BAN_TARGET_SLOT_MSB : BAN_TARGET_SLOT_LSB];
                        stu_sender_sid <= blk_mem_rcvpkt_doutb[BAN_SENDER_SID_MSB : BAN_SENDER_SID_LSB];                        
                        stu_ban_slot <= blk_mem_rcvpkt_doutb[BAN_TARGET_SLOT_MSB : BAN_TARGET_SLOT_LSB];
                        stu_state <= STU_BAN_START;
                    end else begin
                        stu_state <= STU_END;
                    end
                STU_BAN_START: begin
                    stu_state <= STU_BAN_END;
                    if (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] == stu_sender_sid) begin
                        //clear..
                        blk_mem_slot_status_we <= 1;
                        blk_mem_slot_status_din[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                        blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= 0;
                        blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 0;
                        blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= 0;
                    end
                end
                STU_BAN_END: begin
                    blk_mem_slot_status_we <= 0;
                    stu_state <= STU_END;                
                end
                STU_REQ_PRE: begin
                    blk_mem_slot_status_din <= blk_mem_slot_status_dout;
                    stu_state <= STU_REQ_START;
                end
                STU_REQ_START: begin
                    stu_state <= STU_REQ_END;
                    if (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] == 0) begin
                        blk_mem_slot_status_we <= 1;
                        blk_mem_slot_status_din[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= stu_sender_sid;
                        blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= stu_req_psf;
                        blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                        blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                        blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1;
                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                    end else begin //collision, not likely.
                        if (blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_REQ
                            || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_FI
                            || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_ADJ
                            || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_DECIDE_ADJ) 
                        begin
                            if (stu_req_psf <= global_priority) begin
                                //our priority is higher, maintain our bch.
                                stu_type <= 1;
                            end else begin
                                //our priority is lower, we should give up our bch.
                                stu_type <= 2;
                                blk_mem_slot_status_we <= 1;
                                /*other bits of blk_mem_slot_status_din remains the same (we have load the pre value in the previous state). */
                                blk_mem_slot_status_din[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                                blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= stu_req_psf;
                                blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                            end
                        end else begin
                            if (stu_req_psf <= blk_mem_slot_status_dout[PSF_MSB : PSF_LSB]) begin
                                //the old status's priority is higher, maintain the status.
                                //no need for updating anything.
                                stu_type <= 3;
                            end else begin
                                //the old status's priority is lower, we should update the status.
                                stu_type <= 4;
                                blk_mem_slot_status_we <= 1;
                                
                                blk_mem_slot_status_din[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= stu_sender_sid;
                                blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= stu_req_psf;
                                //because we can not know the node which caused collision, so the node should be a new neighbor of ours. 
                                blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] + 1;
                                blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] + 1;
                                blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                            end                        
                        end
                    end
                end
                STU_REQ_END: begin
                    stu_type <= 0;
                    blk_mem_slot_status_we <= 0;
                    stu_state <= STU_END;
                end
                STU_FI_LOOP_1: begin
                    blk_mem_slot_status_we <= 0;
                    
                    if (fi_per_slot_index == 20) begin
                        fi_per_slot_index = 0;
                        blk_mem_slot_status_din <= blk_mem_slot_status_dout;
                        stu_state = STU_FI_LOOP_2;
                    end else begin
                        bit_index = stu_index % DATA_WIDTH;
                        if (bit_index == 0) begin
                            blk_mem_rcvpkt_addrb_stu = blk_mem_rcvpkt_addrb_stu + 1;
                            stu_state = STU_FI_LOOP_1_SETADDR;
                        end else begin
                            fi_per_slot[fi_per_slot_index] = blk_mem_rcvpkt_doutb[bit_index];
                            fi_per_slot_index = fi_per_slot_index + 1;
                            stu_index = stu_index + 1;
                            if (stu_index == (FRAME_SLOT_NUM * 20 + 13)) //�ǲ���Ҫ�����һ���أ���������
                                stu_state = STU_END;
                        end
                    end
                end
                STU_FI_LOOP_1_SETADDR: begin
                    fi_per_slot[fi_per_slot_index] = blk_mem_rcvpkt_doutb[bit_index];
                    fi_per_slot_index = fi_per_slot_index + 1;
                    stu_index = stu_index + 1;
                    if (stu_index == (FRAME_SLOT_NUM * 20 + 13)) //�ǲ���Ҫ�����һ���أ���������
                        stu_state = STU_END; 
                    else
                        stu_state <= STU_FI_LOOP_1;
                end
                STU_FI_LOOP_2: begin //��ȷ��һ��bch����ʱ�Ƿ��¼���Լ�����Ϣ����
                    stu_state <= STU_FI_LOOP_2_CLR;
                    
                    if (blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_REQ
                        || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_FI
                        || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_ADJ
                        || blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB] == STATUS_DECIDE_ADJ) 
                    begin
                        if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] != global_sid) begin
                            if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                if (fi_per_slot[FI_S_PERSLOT_PSF_MSB : FI_S_PERSLOT_PSF_LSB] <= global_priority) begin
                                    //our priority is higher, maintain our bch.
                                    stu_type <= 1;
                                end else begin
                                    //our priority is lower, we should give up our bch.
                                    stu_type <= 2;
                                    blk_mem_slot_status_we <= 1;
                                    /*other bits of blk_mem_slot_status_din remains the same (we have load the pre value in the previous state). */
                                    blk_mem_slot_status_din[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                                    //because we can not know the node which caused collision, so the node should be a new neighbor of ours. 
                                    blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] + 1;
                                    blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                    if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == stu_sender_sid) begin
                                        blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                        blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= fi_per_slot[FI_S_PERSLOT_PSF_MSB : FI_S_PERSLOT_PSF_LSB];
                                        blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                                    end else begin
                                        blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b01; 
                                        blk_mem_slot_status_din[C3HOP_N] <= 1;
                                    end
                                end
                            end else if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b01 )begin //need count 3hop.
                                stu_type <= 3;
                                blk_mem_slot_status_we <= 1;
                                blk_mem_slot_status_din[C3HOP_N] <= 1;
                                blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                            + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                            end else begin //fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b00
                                //the sender of FI should be a new neighbor.
                                //we do nothing here.
                                stu_type <= 4;
                            end
                        end else begin //fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == global_sid
                            stu_type <= 5;
                            
                        end
                    end else begin //slot status is Nothing/Decide_REQ
                        //old status: this slot is occupied by our direct neighbor.
                        if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10) begin
                            if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] 
                                == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) begin
                                if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                    stu_type <= 6;
                                    
                                    if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == stu_sender_sid) begin
                                        //1. refresh life time.
                                        blk_mem_slot_status_we <= 1;
                                        blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                                        //2. update count-2hop/3hop
                                        blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] + 1;
                                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                    + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                    end
                                end else if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b01 ) begin // need count 3hop
                                    stu_type <= 7;
                                    blk_mem_slot_status_we <= 1;
                                    //  update count-3hop
                                    if (blk_mem_slot_status_dout[C3HOP_N] == 0) begin
                                        blk_mem_slot_status_din[C3HOP_N] <= 1;
                                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                    + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                    end
                                end else begin //fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b00 // it is not possible though.
                                    //we do nothing here.
                                    stu_type <= 8;
                                end
                            end else begin //STI-slot-local != STI-slot and (0,0)
                                if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                    if (fi_per_slot[FI_S_PERSLOT_PSF_MSB : FI_S_PERSLOT_PSF_LSB] 
                                            <= blk_mem_slot_status_dout[PSF_MSB : PSF_LSB]) begin
                                        //the old status's priority is higher, maintain the status.
                                        //no need for updating anything.
                                        stu_type <= 9;
                                    end else begin
                                        //the old status's priority is lower, we should update the status.
                                        stu_type <= 10;
                                        blk_mem_slot_status_we <= 1;
                                        
                                        blk_mem_slot_status_din[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]
                                            <= fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB];
                                        blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= fi_per_slot[FI_S_PERSLOT_PSF_MSB : FI_S_PERSLOT_PSF_LSB];
                                        //because we can not know the node which caused collision, so the node should be a new neighbor of ours. 
                                        blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] + 1;
                                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                        if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == stu_sender_sid) begin
                                            blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                            blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                                        end else begin
                                            blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b01; 
                                            blk_mem_slot_status_din[C3HOP_N] <= 1;
                                        end
                                    end
                                end else if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b01 ) begin // need count 3hop 
                                    stu_type <= 11;
                                    //!!!!!!!!!!!!!!!!!!!!!TODO: redundancy.
                                    blk_mem_slot_status_we <= 1;
                                    blk_mem_slot_status_din[C3HOP_N] <= 1;
                                    blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                end else begin //fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b00
                                    // the FI sender must be a new neighbor of ours. otherwise the alg is error.
                                    stu_type <= 12;
                                end                                    
                            end // the occupier checking.
                        //old status: this slot is occupied by our 2-hop neighbor.
                        end else if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b01) begin
                            if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] 
                                    == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])
                            begin
                                if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                    stu_type <= 13;

                                    if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == stu_sender_sid) begin
                                        // 1. update status.
                                        blk_mem_slot_status_we <= 1;
                                        blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                        blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                                        blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] + 1;
                                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                    + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];                                        
                                    end 
                                end else if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b01) begin
                                    stu_type <= 14;
                                    if (blk_mem_slot_status_dout[C3HOP_N] == 0) begin
                                        blk_mem_slot_status_we <= 1;
                                        blk_mem_slot_status_din[C3HOP_N] <= 1;
                                        blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                   + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB]; 
                                    end
                                end else begin //blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b00
                                    // this branch is not possible.
                                    stu_type <= 15;
                                end
                            end else begin//STI-slot-local != STI-slot and (0,0)
                                if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                    stu_type <= 16;
                                    //!!!!!!!!!!!!!!!!!!!!!TODO: redundancy.
                                    blk_mem_slot_status_we <= 1;
                                    blk_mem_slot_status_din[C3HOP_N] <= 1;
                                    blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                end else if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b01) begin
                                    stu_type <= 17;
                                    blk_mem_slot_status_we <= 1;
                                    blk_mem_slot_status_din[C3HOP_N] <= 1;
                                    blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB]
                                                                                                + fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];                                    
                                end else begin //blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b00
                                    //we do nothing here.
                                    stu_type <= 18;
                                end
                            end
                        end else begin //old status: this slot is free.
                            if (fi_per_slot[FI_S_PERSLOT_BUSY_MSB : FI_S_PERSLOT_BUSY_LSB] == 2'b10) begin
                                stu_type <= 19;
                                blk_mem_slot_status_we <= 1;
                                blk_mem_slot_status_din[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]
                                    <= fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB];
                                blk_mem_slot_status_din[PSF_MSB : PSF_LSB] <= fi_per_slot[FI_S_PERSLOT_PSF_MSB : FI_S_PERSLOT_PSF_LSB];
                                blk_mem_slot_status_din[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1;
                                blk_mem_slot_status_din[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= fi_per_slot[FI_S_PERSLOT_COUNT_MSB : FI_S_PERSLOT_COUNT_LSB];
                                if (fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB : FI_S_PERSLOT_OCCUPIER_SID_LSB] == stu_sender_sid) begin
                                    blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b10;
                                    blk_mem_slot_status_din[LIFE_MSB : LIFE_LSB] <= OCCUPIER_LIFE_FRAME;
                                end else begin
                                    blk_mem_slot_status_din[BUSY_MSB : BUSY_LSB] <= 2'b01;
                                    blk_mem_slot_status_din[C3HOP_N] <= 1;
                                end
                            end else if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b01) begin
                                //do nothing here.
                                stu_type <= 20;
                            end else begin //blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b00
                                //do nothing here.
                                stu_type <= 21;
                            end
                        end                            
                    end
                end
                STU_FI_LOOP_2_CLR: begin
                    stu_type <= 0;
                    blk_mem_slot_status_we <= 0;
                    blk_mem_slot_status_addr <= blk_mem_slot_status_addr + 1;
                    fi_per_slot <= 0;
                    stu_state <= STU_FI_LOOP_1;
                end
                
                STU_END: begin
                    blk_mem_rcvpkt_en_stu <= 0;
                    stu_done <= 1;
                    stu_state <= STU_IDLE;
                end

            endcase
        end
    end

    parameter IRQ_IDLE=0, IRQ_JUDGE = 1,
            IRQ_GET_ISR_START = 2, IRQ_GET_ISR_MID = 3, IRQ_GET_ISR_WAIT = 4, 
            IRQ_ISR_JUDGE_RXHP= 5, IRQ_ISR_JUDGE_TXOK = 6,
            IRQ_DISABLE_JUDGE = 7, IRQ_DISABLE_START = 8, IRQ_DISABLE_MID = 9, IRQ_DISABLE_WAIT = 10, 
            IRQ_ENABLE_START = 11, IRQ_ENABLE_MID = 12, IRQ_ENABLE_WAIT = 13,
            IRQ_HANDLE_TXOK_START = 14, IRQ_HANDLE_TXOK_MID = 15, IRQ_HANDLE_TXOK_WAIT = 16, IRQ_HANDLE_TXOK_END = 17,
            IRQ_PEEK_PKT_START = 18, IRQ_PEEK_PKT_MID = 19, IRQ_PEEK_PKT_WAIT = 20, IRQ_PEEK_PKT_SETADDR = 44, IRQ_PEEK_PKT_JUDGE = 45,
            IRQ_RXFIFO_DEQUEUE_PUSHBACK_START = 21, IRQ_RXFIFO_DEQUEUE_PUSHBACK_END = 22,  
            IRQ_HANDLE_PING_START = 36, IRQ_HANDLE_PING_RD_SEQ = 37, IRQ_HANDLE_PING_RD_SEC = 38, IRQ_HANDLE_PING_RD_COUNTER2 = 39,
            IRQ_HANDLE_ACKPING_START = 40, IRQ_HANDLE_ACKPING_RD_SEQ = 41, IRQ_HANDLE_ACKPING_RD_SEC = 42, IRQ_HANDLE_ACKPING_RD_COUNTER2 = 43,
            IRQ_HANDLE_TDMA_CTL_START = 23, IRQ_HANDLE_TDMA_CTL_WAIT = 46, IRQ_HANDLE_TDMA_CTL_END = 24,
            IRQ_CLEAR_JUDGE = 25, IRQ_CLEAR_START = 26, IRQ_CLEAR_MID = 27, IRQ_CLEAR_WAIT = 28,
            IRQ_PASS_JUDGE = 29, IRQ_PASS_START = 30, IRQ_PASS_WAIT = 31, 
            IRQ_CLR_PIRQ_START = 32, IRQ_CLR_PIRQ_WAIT = 33,
            IRQ_PUSHBACK_HW_START = 34, IRQ_PUSHBACK_HW_WAIT = 35,
            IRQ_ERROR=63;
            
    
    reg [5:0] curr_irq_state;
    assign curr_irq_state_wire[5:0] = curr_irq_state[5:0];
    reg [5:0] next_irq_state;
    
    reg [ADDR_WIDTH-1 : 0] current_rxbuf_addr;
    reg pass_flag;
    reg clear_rxhp_flag;
    reg rxhp_only;
    reg clear_txok_flag; 
    
    reg [DATA_WIDTH-1 : 0] isr_p;
    //reg [DATA_WIDTH-1 : 0] isr_s0;
        
    //IRQ logic
    reg [2:0] irq_counter = 0;
    reg [2:0] current_irq_counter = 0;
    
    assign debug_port_8bits[7:5] = irq_counter[2:0];
    assign debug_port_8bits[2:0] = current_irq_counter[2:0];

    always @ (posedge irq_in or negedge reset_n)
    begin
        if ( reset_n == 0 )
            irq_counter <= 0;
        else irq_counter <= irq_counter + 1'b1;
    end
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 )
            curr_irq_state <= IRQ_IDLE;           
        else
            curr_irq_state <= next_irq_state; 
    end 

    /**
     */
    always @ (curr_irq_state)//tlflag or ipic_done_wire or proc_done or  testing_done or curr_py_state)
    begin
        case (curr_irq_state)
            IRQ_IDLE: begin
                if (irq_in) 
                    next_irq_state <= IRQ_JUDGE;
                else
                    next_irq_state <= IRQ_IDLE;
            end
            IRQ_JUDGE: begin
                if (current_irq_counter[2:0] != irq_counter[2:0])
                    next_irq_state <= IRQ_GET_ISR_START;
                else
                    next_irq_state <= IRQ_IDLE;
            end      

            IRQ_GET_ISR_START: next_irq_state <= IRQ_GET_ISR_MID;
            IRQ_GET_ISR_MID: 
                if (ipic_ack_lite_irq)
                    next_irq_state <= IRQ_GET_ISR_WAIT;
                else
                    next_irq_state <= IRQ_GET_ISR_MID;
            IRQ_GET_ISR_WAIT: 
                if (ipic_done_lite_wire)
                    next_irq_state <= IRQ_ISR_JUDGE_RXHP;
                else
                    next_irq_state <= IRQ_GET_ISR_WAIT;                
            IRQ_ISR_JUDGE_RXHP: 
                if (single_read_data_lite & AR_ISR_HP_RXOK )
                    next_irq_state <= IRQ_PEEK_PKT_START;
                else
                    next_irq_state <= IRQ_ISR_JUDGE_TXOK;                 
            /**
             * 1. Peek fifo, whether the pkt is valid ?
             *   1. if TRUE, Dequeue, ???skb->data???N??????????12 beats ??RxDesc??TDMA???????е?????
             **/
            IRQ_PEEK_PKT_START: next_irq_state <= IRQ_PEEK_PKT_MID;
            IRQ_PEEK_PKT_MID: 
                if (ipic_ack_irq)
                    next_irq_state <= IRQ_PEEK_PKT_WAIT;
                else
                    next_irq_state <= IRQ_PEEK_PKT_MID;
            IRQ_PEEK_PKT_WAIT: 
                if (ipic_done_wire)
                    next_irq_state <= IRQ_PEEK_PKT_SETADDR;    
                else
                    next_irq_state <= IRQ_PEEK_PKT_WAIT;      
            IRQ_PEEK_PKT_SETADDR: next_irq_state <= IRQ_PEEK_PKT_JUDGE;
            IRQ_PEEK_PKT_JUDGE:
//                if (bunch_read_data[383:352] & AR_RxDone) // 11*32 +: 32 , ar9003_rxs->status11
                if (blk_mem_rcvpkt_doutb & AR_RxDone)
                    next_irq_state <= IRQ_RXFIFO_DEQUEUE_PUSHBACK_START;
                else       
                    next_irq_state <= IRQ_ISR_JUDGE_TXOK;//IRQ_PASS_JUDGE;                 

            IRQ_RXFIFO_DEQUEUE_PUSHBACK_START: //Push the processed buf addr back to HP QUEUE of HW and our own fifo.
                if (rxfifo_empty)
                    next_irq_state <= IRQ_ERROR;
                else
                    next_irq_state <= IRQ_RXFIFO_DEQUEUE_PUSHBACK_END;
            // 1. lens of RXS is 12 * 4 = 48 bytes. [0~383]
            // 2. lens of the 802.11 MAC header is 30 bytes [384~623]
            // So the frame body starts from 79 bytes [624~ ] plus 2 bytes padding [640~]                   
            IRQ_RXFIFO_DEQUEUE_PUSHBACK_END: 
                if (blk_mem_rcvpkt_doutb[4:0] == `PING) // blk_mem_rcvpkt_addrb has been set in the IRQ_RXFIFO_DEQUEUE_PUSHBACK_START
                    next_irq_state <= IRQ_HANDLE_PING_START;
                else if (blk_mem_rcvpkt_doutb[4:0] == `ACK_PING)
                    next_irq_state <= IRQ_HANDLE_ACKPING_START;
                else
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_START;
            IRQ_HANDLE_PING_START: next_irq_state <= IRQ_HANDLE_PING_RD_SEQ;
            IRQ_HANDLE_PING_RD_SEQ: next_irq_state <= IRQ_HANDLE_PING_RD_SEC;
            IRQ_HANDLE_PING_RD_SEC: next_irq_state <= IRQ_HANDLE_PING_RD_COUNTER2;
            IRQ_HANDLE_PING_RD_COUNTER2: next_irq_state <= IRQ_PEEK_PKT_START;

            IRQ_HANDLE_ACKPING_START: next_irq_state <= IRQ_HANDLE_ACKPING_RD_SEQ;
            IRQ_HANDLE_ACKPING_RD_SEQ: next_irq_state <= IRQ_HANDLE_ACKPING_RD_SEC;
            IRQ_HANDLE_ACKPING_RD_SEC: next_irq_state <= IRQ_HANDLE_ACKPING_RD_COUNTER2;
            IRQ_HANDLE_ACKPING_RD_COUNTER2: next_irq_state <= IRQ_PEEK_PKT_START;
                     
            IRQ_HANDLE_TDMA_CTL_START: begin 
                if (tdma_function_enable)
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_WAIT; 
                else
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_END; 
            end
            IRQ_HANDLE_TDMA_CTL_WAIT:
                if (stu_done)
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_END;
                else
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_WAIT;
            IRQ_HANDLE_TDMA_CTL_END:begin
                next_irq_state <= IRQ_PEEK_PKT_START; //LOOP !
            end

            IRQ_ISR_JUDGE_TXOK:
                if (isr_p & AR_ISR_TXOK )
                    next_irq_state <= IRQ_HANDLE_TXOK_START;
                else
                    next_irq_state <= IRQ_CLEAR_JUDGE; 
            //Read ISR_S0: TXOK for which QCU ?
            IRQ_HANDLE_TXOK_START: next_irq_state <= IRQ_HANDLE_TXOK_MID;
            IRQ_HANDLE_TXOK_MID:
                if (ipic_ack_lite_irq)
                    next_irq_state <= IRQ_HANDLE_TXOK_WAIT;
                else
                    next_irq_state <= IRQ_HANDLE_TXOK_MID;     
            IRQ_HANDLE_TXOK_WAIT:
                if (ipic_done_lite_wire)
                    next_irq_state <= IRQ_HANDLE_TXOK_END;
                else
                    next_irq_state <= IRQ_HANDLE_TXOK_WAIT;
            IRQ_HANDLE_TXOK_END: next_irq_state <= IRQ_CLEAR_JUDGE;
            
            IRQ_CLEAR_JUDGE: next_irq_state <= IRQ_DISABLE_JUDGE;
            IRQ_DISABLE_JUDGE:
                if (!pass_flag)
                    next_irq_state <= IRQ_DISABLE_START;
                else
                    next_irq_state <= IRQ_CLEAR_START;
            IRQ_DISABLE_START: next_irq_state <= IRQ_DISABLE_MID;
            IRQ_DISABLE_MID: 
                if (ipic_ack_lite_irq)
                    next_irq_state <= IRQ_DISABLE_WAIT;
                else
                    next_irq_state <= IRQ_DISABLE_MID;
            IRQ_DISABLE_WAIT: 
                if (ipic_done_lite_wire)
                    next_irq_state <= IRQ_CLEAR_START;
                else
                    next_irq_state <= IRQ_DISABLE_WAIT;
            IRQ_CLEAR_START: next_irq_state <= IRQ_CLEAR_MID;
            IRQ_CLEAR_MID:
                if (ipic_ack_lite_irq)
                    next_irq_state <= IRQ_CLEAR_WAIT;
                else
                    next_irq_state <= IRQ_CLEAR_MID;   
            IRQ_CLEAR_WAIT:
                if (ipic_done_lite_wire)
                    next_irq_state <= IRQ_PASS_JUDGE;
                else
                    next_irq_state <= IRQ_CLEAR_WAIT;                

            IRQ_PASS_JUDGE: begin //After we clear HP_RXOK bit, there may exist other irq sources.
                if (pass_flag)
                    next_irq_state <= IRQ_PASS_START;
                else
                    next_irq_state <= IRQ_ENABLE_START;//IRQ_IDLE;
            end
            IRQ_ENABLE_START: next_irq_state <= IRQ_ENABLE_MID;
            IRQ_ENABLE_MID: 
                if (ipic_ack_lite_irq)
                    next_irq_state <= IRQ_ENABLE_WAIT;
                else
                    next_irq_state <= IRQ_ENABLE_MID;              
            IRQ_ENABLE_WAIT:
                if (ipic_done_lite_wire)
                    next_irq_state <= IRQ_CLR_PIRQ_START;
                else
                    next_irq_state <= IRQ_ENABLE_WAIT;             
            IRQ_CLR_PIRQ_START: next_irq_state <= IRQ_CLR_PIRQ_WAIT;
            IRQ_CLR_PIRQ_WAIT: 
                if (pirq_done)
                    next_irq_state <= IRQ_PUSHBACK_HW_START;
                else
                    next_irq_state <= IRQ_CLR_PIRQ_WAIT;
            IRQ_PUSHBACK_HW_START: next_irq_state <= IRQ_PUSHBACK_HW_WAIT;
            IRQ_PUSHBACK_HW_WAIT:
                if (ur_done)
                    next_irq_state <= IRQ_IDLE;
                else
                    next_irq_state <= IRQ_PUSHBACK_HW_WAIT;                
            IRQ_PASS_START: next_irq_state <= IRQ_PASS_WAIT;
            
            IRQ_PASS_WAIT: begin
                //if (irq_readed_linux)
                if (!irq_in)
                    next_irq_state <= IRQ_IDLE;
                else
                    next_irq_state <= IRQ_PASS_WAIT;
            end
            
            default: next_irq_state <= IRQ_ERROR;
        endcase
    end
        
    always @ ( posedge clk )
    begin
        if ( reset_n == 0 ) begin
            irq_out <= 0;
            ipic_start_irq <= 0;
            read_addr_irq <= 0;
            ipic_type_irq <= 0;
            read_length_irq <= 0;
            debug_gpio[2] <= 1;       
            current_irq_counter <= 0;     
            current_rxbuf_addr <= 0;
            pass_flag <= 0;
            rxfifo_rd_en <= 0;
            rxfifo_wr_start <= 0;
            used_rxfifo_wr_en <= 0;
            irq_start_clr_pirq <= 0;
            irq_start_pushback <= 0;
            clear_rxhp_flag <= 0;
            rxhp_only <= 0;
            clear_txok_flag <= 0;    
            recv_pkt_pulse <= 0;
            //test_sendpkt <= 0;
            recv_ping <= 0;
            recved_seq <= 0;
            recv_ack_ping <= 0;
            recved_sec <= 0;
            recved_counter2 <= 0;
            lastpkt_txok_timemark1 <= 0;
            lastpkt_txok_timemark2 <= 0;
            stu_start <= 0;
        end else begin
            case (next_irq_state)      
                IRQ_IDLE: begin
                    irq_out <= 0;
                    clear_txok_flag <= 0;
                    clear_rxhp_flag <= 0;
                    rxhp_only <= 0;
                end 
                IRQ_GET_ISR_START: begin
                    current_irq_counter[2:0] <= irq_counter[2:0]; // Caution!!!
                
                    read_addr_lite_irq <= ATH9K_BASE_ADDR + AR_ISR;
                    ipic_type_lite_irq <= `SINGLE_RD;
                    ipic_start_lite_irq <= 1;  
                end
                //IRQ_GET_ISR_MID: 
                IRQ_GET_ISR_WAIT: ipic_start_lite_irq <= 0;
                IRQ_ISR_JUDGE_RXHP: begin
                    isr_p <= single_read_data_lite;
                    if (single_read_data_lite & AR_ISR_HP_RXOK) begin//contains HPRXOK
                        clear_rxhp_flag <= 1;                      
                        if (single_read_data_lite & AR_ISR_LP_RXOK) //decide if we clear 0x81xxxxxx
                            rxhp_only <= 0;    
                        else 
                            rxhp_only <= 1;                            
                    end else begin 
                        clear_rxhp_flag <= 0;
                        rxhp_only <= 0;                     
                    end
                end
                /**  
                 * 1. Peek fifo, whether the pkt is valid ?
                 *   1. if TRUE, Dequeue
                 **/
                IRQ_PEEK_PKT_START: begin                             
                    read_addr_irq <= rxfifo_dread;
                    current_rxbuf_addr <= rxfifo_dread;
                    read_length_irq <= C_PKT_LEN; 
                    ipic_type_irq <= `BURST_RD;
                    ipic_start_irq <= 1;
                    
                    recv_ack_ping <= 0;
                    recv_ping <= 0;
                end
                //IRQ_PEEK_PKT_MID: 
                IRQ_PEEK_PKT_WAIT: ipic_start_irq <= 0;
                IRQ_PEEK_PKT_SETADDR: blk_mem_rcvpkt_addrb_irq <= RX_DONE_ADDR;
                //IRQ_CLEAR_HP_RXOK_WAIT
            
                IRQ_RXFIFO_DEQUEUE_PUSHBACK_START: begin                     
                    //Push the processed buf addr back to Used rxfifo.  
                    used_rxfifo_wr_en <= 1;
                    used_rxfifo_dwrite <= current_rxbuf_addr;
                    //Push the processed buf addr back to Our own RX FIFO
                    rxfifo_wr_start <= 1;
                    rxfifo_wr_data <= current_rxbuf_addr; 
                    //Dequeue                    
                    rxfifo_rd_en <= 1;
                    
                    //set blk_mem_rcvpkt_addrb for next state.
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR;
                end           
                IRQ_RXFIFO_DEQUEUE_PUSHBACK_END: begin
                    rxfifo_wr_start <= 0;
                    used_rxfifo_wr_en <= 0;
                    rxfifo_rd_en <= 0;
                    ipic_start_irq <= 0; // Clear the bit asserted in IRQ_CLEAR_BUF
                end
                //the frame body starts from 79 bytes [624~ ] plus 2 bytes padding [640~]    
                //// 640 flag(32bit) 671, 672 test_seq (32bit) 703, 704 utc_sec(32bit) 735, 736 gps_counter2(32bit) 767
                IRQ_HANDLE_PING_START: begin
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 1;
//                    recved_seq[31:0] <= bunch_read_data[703:672];
//                    recved_sec[31:0] <= bunch_read_data[735:704];
//                    recved_counter2[31:0] <= bunch_read_data[767:736];
                end
                IRQ_HANDLE_PING_RD_SEQ: begin
                    recved_seq[31:0] <= blk_mem_rcvpkt_doutb;
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 2;
                end
                IRQ_HANDLE_PING_RD_SEC: begin
                    recved_sec[31:0] <= blk_mem_rcvpkt_doutb;
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 3;
                end
                IRQ_HANDLE_PING_RD_COUNTER2: begin
                    recved_counter2[31:0] <= blk_mem_rcvpkt_doutb;
                    recv_ping <= 1;
                end
                IRQ_HANDLE_ACKPING_START: begin
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 1;
                end
                IRQ_HANDLE_ACKPING_RD_SEQ: begin
                    recved_seq[31:0] <= blk_mem_rcvpkt_doutb;
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 2;
                end
                IRQ_HANDLE_ACKPING_RD_SEC: begin
                    recved_sec[31:0] <= blk_mem_rcvpkt_doutb;
                    blk_mem_rcvpkt_addrb_irq <= RX_TYPE_ADDR + 3;
                end
                IRQ_HANDLE_ACKPING_RD_COUNTER2: begin
                    recved_counter2[31:0] <= blk_mem_rcvpkt_doutb;
                    recv_ack_ping <= 1;
                end
                IRQ_HANDLE_TDMA_CTL_START: begin         
                    //ipic_start_lite_irq <= 0; //Clear the bit asserted in IRQ_RXFIFO_DEQUEUE_PUSHBACK_START.
                    //test_sendpkt <= 1;
                    if (tdma_function_enable)
                        stu_start <= 1;
                    recv_pkt_pulse <= 1;
                    debug_gpio[2] <= !debug_gpio[2];
                end
                IRQ_HANDLE_TDMA_CTL_WAIT: begin
                    stu_start <= 0;
                end
                IRQ_HANDLE_TDMA_CTL_END: begin
                    //test_sendpkt <= 0;
                    recv_pkt_pulse <= 0;
                end

                //IRQ_ISR_JUDGE_TXOK:     
                
                //IRQ_GET_ISR_END: 
                //Read ISR_S0: TXOK for which QCU ?
                IRQ_HANDLE_TXOK_START: begin
                    read_addr_lite_irq <= ATH9K_BASE_ADDR + AR_ISR_S0;
                    ipic_type_lite_irq <= `SINGLE_RD;
                    ipic_start_lite_irq <= 1;                  
                end
                //IRQ_HANDLE_TXOK_MID: 
                IRQ_HANDLE_TXOK_WAIT: ipic_start_lite_irq <= 0;
                IRQ_HANDLE_TXOK_END: begin
                    //isr_s0 <= single_read_data_lite;
                    if (single_read_data_lite == FPGA_QCU) begin
                        clear_txok_flag <= 1; //Clear TXOK 
                        lastpkt_txok_timemark1 <= gps_pulse1_counter;
                        lastpkt_txok_timemark2 <= gps_pulse2_counter;
                    end else 
                        clear_txok_flag <= 0; // Must note that we don't clear TXOK that contains both ath9k's pkt and ours, which is unlikely to happen.                
                end
                IRQ_CLEAR_JUDGE: begin
                    if (clear_rxhp_flag && (isr_p == (AR_ISR_HP_RXOK | AR_ISR_RXINTM | AR_ISR_RXMINTR)))
                        pass_flag <= 0;
                    else if (clear_txok_flag && clear_rxhp_flag && (isr_p == (AR_ISR_HP_RXOK | AR_ISR_RXINTM | AR_ISR_RXMINTR | AR_ISR_TXOK)))
                        pass_flag <= 0;
                    else if (clear_txok_flag && (isr_p == AR_ISR_TXOK))
                        pass_flag <= 0;
                    else
                        pass_flag <= 1;
                end
                //disable IRQ, set disable flag.
                //IRQ_DISABLE_JUDGE
                IRQ_DISABLE_START: begin 
                    write_addr_lite_irq <= ATH9K_BASE_ADDR + AR_IER;
                    write_data_lite_irq <= AR_IER_DISABLE;
                    ipic_type_lite_irq <= `SINGLE_WR;
                    ipic_start_lite_irq <= 1;
                end
                //IRQ_DISABLE_MID:
                IRQ_DISABLE_WAIT: ipic_start_lite_irq <= 0;                
                //set the pass_flag.  We do not wait the write action. It takes about 130 circles.
                IRQ_CLEAR_START: begin
                    write_addr_lite_irq <= ATH9K_BASE_ADDR + AR_ISR;
                    write_data_lite_irq <= ((clear_txok_flag?AR_ISR_TXOK:32'h0) | 
                                            (clear_rxhp_flag?AR_ISR_HP_RXOK:32'h0) | 
                                            (rxhp_only?(AR_ISR_RXINTM | AR_ISR_RXMINTR):32'h0));
                    ipic_type_lite_irq <= `SINGLE_WR;
                    ipic_start_lite_irq <= 1;              
                end
                //IRQ_CLEAR_MID:
                IRQ_CLEAR_WAIT: ipic_start_lite_irq <= 0;
                        
                //IRQ_PASS_JUDGE: 
                IRQ_ENABLE_START: begin
                    write_addr_lite_irq <= ATH9K_BASE_ADDR + AR_IER;
                    write_data_lite_irq <= AR_IER_ENABLE;
                    ipic_type_lite_irq <= `SINGLE_WR;
                    ipic_start_lite_irq <= 1;
                end
                //IRQ_ENABLE_MID:
                IRQ_ENABLE_WAIT: ipic_start_lite_irq <= 0;
                
                IRQ_CLR_PIRQ_START: irq_start_clr_pirq <= 1;
                IRQ_CLR_PIRQ_WAIT: irq_start_clr_pirq <= 0;
                IRQ_PUSHBACK_HW_START: irq_start_pushback <= 1;
                IRQ_PUSHBACK_HW_WAIT: irq_start_pushback <= 0;
    
                IRQ_PASS_START: begin
                    irq_out <= 1;
                end
                //IRQ_PASS_WAIT: 

                default: begin end
            endcase
        end
    end

    //localparam ESDUR_IDLE=0, 
    (* mark_debug = "true" *) reg [3:0] esdur_state;
    reg [11:0] next_pktlen;
    reg [31:0] next_pkt_es_duration_ns;
    reg next_pkt_es_duration_valid;
    reg init_flag;
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin
            esdur_state <= 0;
            init_flag <= 1;
            next_pktlen <= 0;
            next_pkt_es_duration_valid <= 0;
            next_pkt_es_duration_ns <= 0;
        end else begin
            case (esdur_state)
                0: begin
                    if ((init_flag || fifo_rd_en) && fifo_valid) begin
                        esdur_state <= 2;
                        next_pkt_es_duration_valid <= 0;
                        init_flag <= 0;
                    end else if (fifo_empty) begin
                        next_pkt_es_duration_valid <= 0;
                        esdur_state <= 1;
                    end 
                end
                1: begin
                    if (fifo_valid) begin
                        esdur_state <= 2;
                    end
                end
                2: begin
                    if (!fifo_rd_en) begin// wait the fifo read operation. we will read the frame lens from the next tx-desc.
                        if (fifo_valid) begin
                            read_addr_esdur <= fifo_dread[63 : 32] + 44; //refer to ar9003_txc
                            ipic_type_esdur <= `SINGLE_RD;
                            ipic_start_esdur <= 1; 
                            esdur_state <= 3;  
                        end else
                            esdur_state <= 1;  
                    end
                end
                3: begin
                    if (ipic_ack_esdur) begin
                        ipic_start_esdur <= 0;
                        esdur_state <= 4;
                    end
                end
                4: begin
                    if (ipic_done_wire) begin
                        next_pktlen <= single_read_data & 32'hfff;
                        esdur_state <= 5;
                    end
                end
                5: begin
                    next_pkt_es_duration_ns <= (next_pktlen * TIME_PER_BYTE_12M_NS) + TX_GUARD_NS;
                    next_pkt_es_duration_valid <= 1;
                    esdur_state <= 0;
                end
                default: begin end
            endcase
        end
    end
    
    reg [31:0] ns_used_in_curr_slot;
    reg txslot_enough_flag;
    always @ (posedge clk)
    begin
        if ( reset_n == 0 || tdma_function_enable == 0) begin
            txslot_enough_flag <= 1;
        end else begin
            if (next_pkt_es_duration_ns > (SLOT_NS - bch_control_time_ns - (slot_pulse2_counter * 1000) - ns_used_in_curr_slot))
                txslot_enough_flag <= 0;
            else
                txslot_enough_flag <= 1;
        end
    end
    
    parameter TXFR_IDLE=0, TXFR_WR_PCIE_START=4, 
            TXFR_WR_PCIE_MID=5, TXFR_WR_PCIE_WAIT=6, TXFR_ERROR=7;
    reg [3:0] current_txf_read_status;
    reg [3:0] next_txf_read_status;
    
    reg write_trans_start;
    reg write_trans_cpl_pulse;

    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 )
            current_txf_read_status <= TXFR_IDLE;           
        else
            current_txf_read_status <= next_txf_read_status; 
    end 
    
    always @ (current_txf_read_status)
    begin
        case (current_txf_read_status)
            TXFR_IDLE: begin
                if ( !fifo_empty && fifo_valid && tdma_tx_enable) 
                    if (tdma_function_enable == 0)
                        next_txf_read_status = TXFR_WR_PCIE_START;
                    else if (tdma_function_enable && next_pkt_es_duration_valid && txslot_enough_flag)
                        next_txf_read_status = TXFR_WR_PCIE_START;
                    else
                        next_txf_read_status = TXFR_IDLE;
                else
                    next_txf_read_status = TXFR_IDLE;
            end
            TXFR_WR_PCIE_START: next_txf_read_status = TXFR_WR_PCIE_MID;
            TXFR_WR_PCIE_MID: 
                if (ipic_ack_lite_txfr)
                    next_txf_read_status = TXFR_WR_PCIE_WAIT;
                else
                    next_txf_read_status = TXFR_WR_PCIE_MID;
            TXFR_WR_PCIE_WAIT: begin
                if ( ipic_done_lite_wire )
                    next_txf_read_status = TXFR_IDLE;
                else
                    next_txf_read_status = TXFR_WR_PCIE_WAIT;
            end
            default: next_txf_read_status = TXFR_ERROR;
        endcase
    end

    always @ ( posedge clk )
    begin
        if ( reset_n == 0 ) begin
            debug_gpio[0] <= 1;
            fifo_rd_en <= 0;
            ipic_start_lite_txfr <= 0;
            ns_used_in_curr_slot <= 0;
        end else begin
            case (next_txf_read_status)
                TXFR_IDLE: begin
                    fifo_rd_en <= 0;
                    if (tdma_tx_enable == 0)
                        ns_used_in_curr_slot <= 0;
                end
                TXFR_WR_PCIE_START: begin
                    fifo_rd_en <= 1;
                    write_addr_lite_txfr[ADDR_WIDTH-1 : 0] <= fifo_dread[31 : 0];
                    write_data_lite_txfr[ADDR_WIDTH-1 : 0] <= fifo_dread[63 : 32];
                    ipic_type_lite_txfr <= `SINGLE_WR;
                    ipic_start_lite_txfr <= 1;
                    ns_used_in_curr_slot <= ns_used_in_curr_slot + next_pkt_es_duration_ns;
                    debug_gpio[0] <= !debug_gpio[0]; 
                end
                TXFR_WR_PCIE_MID: begin
                    fifo_rd_en <= 0;
                end
                TXFR_WR_PCIE_WAIT: ipic_start_lite_txfr <= 0;
                default: begin end
            endcase
         end
     end
     
endmodule