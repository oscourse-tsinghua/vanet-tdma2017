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
    parameter integer C_PKT_LEN = 256
)
(
    // CLK
    input wire clk,
    input wire reset_n,
    input wire fifo_reset,
    output reg tx_proc_error,
    // FIFO signals
    input wire  fifo_empty,
    input wire [DATA_WIDTH-1 : 0] fifo_dread,
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
    input wire [2047 :0] bunch_read_data, 
    output reg [ADDR_WIDTH-1 : 0] write_addr,  
    output reg [DATA_WIDTH-1 : 0] write_data,
    output reg [C_LENGTH_WIDTH-1 : 0] write_length,


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
    
    input wire tdma_tx_enable,
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
                    end
                end
                1: begin
                    if (ipic_ack) begin
                        case (ipic_dispatch_type)
                            `IRQ: ipic_ack_irq <= 1;
                            `UR: ipic_ack_ur <= 1;
                            default: begin 
                                ipic_ack_irq <= 0;
                                ipic_ack_ur <= 0;
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
    
    localparam AR_RxDone = 32'h00000001;
    
    localparam AR_HP_RXDP = 32'h0074;
    
    localparam IEEE80211_FCTL_FTYPE	= 32'h000c;
    localparam IEEE80211_FCTL_STYPE = 32'h00f0;
    localparam IEEE80211_FTYPE_CTL = 32'h0004;
    localparam IEEE80211_STYPE_TDMA	= 0;
    localparam IEEE80211_STYPE_TDMA1 = 32'h0010;
    
    `define PING 1
    `define ACK_PING 2
  
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
                             
    parameter IRQ_IDLE=0, IRQ_JUDGE = 1,
            IRQ_GET_ISR_START = 2, IRQ_GET_ISR_MID = 3, IRQ_GET_ISR_WAIT = 4, 
            IRQ_ISR_JUDGE_RXHP= 5, IRQ_ISR_JUDGE_TXOK = 6,
            IRQ_DISABLE_JUDGE = 7, IRQ_DISABLE_START = 8, IRQ_DISABLE_MID = 9, IRQ_DISABLE_WAIT = 10, 
            IRQ_ENABLE_START = 11, IRQ_ENABLE_MID = 12, IRQ_ENABLE_WAIT = 13,
            IRQ_HANDLE_TXOK_START = 14, IRQ_HANDLE_TXOK_MID = 15, IRQ_HANDLE_TXOK_WAIT = 16, IRQ_HANDLE_TXOK_END = 17,
            IRQ_HANDLE_PING_START = 36, IRQ_HANDLE_PING_END = 37, IRQ_HANDLE_ACKPING_START = 38, IRQ_HANDLE_ACKPING_END = 39,
            IRQ_PEEK_PKT_START = 18, IRQ_PEEK_PKT_MID = 19, IRQ_PEEK_PKT_WAIT = 20,
            IRQ_RXFIFO_DEQUEUE_PUSHBACK_START = 21, IRQ_RXFIFO_DEQUEUE_PUSHBACK_END = 22,  IRQ_HANDLE_TDMA_CTL_START = 23, IRQ_HANDLE_TDMA_CTL_END = 24,
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
                    if (bunch_read_data[383:352] & AR_RxDone) // 11*32 +: 32 , ar9003_rxs->status11
                        next_irq_state <= IRQ_RXFIFO_DEQUEUE_PUSHBACK_START;
                    else       
                        next_irq_state <= IRQ_ISR_JUDGE_TXOK;//IRQ_PASS_JUDGE;     
                else
                    next_irq_state <= IRQ_PEEK_PKT_WAIT;                       

            IRQ_RXFIFO_DEQUEUE_PUSHBACK_START: //Push the processed buf addr back to HP QUEUE of HW and our own fifo.
                if (rxfifo_empty)
                    next_irq_state <= IRQ_ERROR;
                else
                    next_irq_state <= IRQ_RXFIFO_DEQUEUE_PUSHBACK_END;
            // 1. lens of RXS is 12 * 4 = 48 bytes. [0~383]
            // 2. lens of the 802.11 MAC header is 30 bytes [384~623]
            // So the frame body starts from 79 bytes [624~ ] plus 2 bytes padding [640~]                   
            IRQ_RXFIFO_DEQUEUE_PUSHBACK_END: 
//                if ((bunch_read_data[399:384] & (IEEE80211_FCTL_FTYPE | IEEE80211_FCTL_STYPE)) ==
//                    (IEEE80211_FTYPE_CTL | IEEE80211_STYPE_TDMA)) //?ж? frame_control ??Ρ?ar9003_rxs?????????16λ???? frame_control
//                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_START;
//                else
//                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_START;//For DEBUG!! //IRQ_ERROR; //The HP QUEUE contains pkts we dont want.
                if (bunch_read_data[671:640] == `PING)
                    next_irq_state <= IRQ_HANDLE_PING_START;
                else if (bunch_read_data[671:640] == `ACK_PING)
                    next_irq_state <= IRQ_HANDLE_ACKPING_START;
                else
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_START;
            IRQ_HANDLE_PING_START: next_irq_state <= IRQ_HANDLE_PING_END;
            IRQ_HANDLE_PING_END: next_irq_state <= IRQ_PEEK_PKT_START;
            IRQ_HANDLE_ACKPING_START: next_irq_state <= IRQ_HANDLE_ACKPING_END;
            IRQ_HANDLE_ACKPING_END: next_irq_state <= IRQ_PEEK_PKT_START;            
            IRQ_HANDLE_TDMA_CTL_START: begin 
                next_irq_state <= IRQ_HANDLE_TDMA_CTL_END; 
            end
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
                end
                //IRQ_PEEK_PKT_MID: 
                IRQ_PEEK_PKT_WAIT: ipic_start_irq <= 0;
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
                    recv_ping <= 1;
                    recved_seq[31:0] <= bunch_read_data[703:672];
                    recved_sec[31:0] <= bunch_read_data[735:704];
                    recved_counter2[31:0] <= bunch_read_data[767:736];
                end
                IRQ_HANDLE_PING_END: recv_ping <= 0;
                IRQ_HANDLE_ACKPING_START: begin
                    recv_ack_ping <= 1;
                    recved_seq[31:0] <= bunch_read_data[703:672];
                    recved_sec <= bunch_read_data[735:704];
                    recved_counter2 <= bunch_read_data[767:736];
                end
                IRQ_HANDLE_ACKPING_END: recv_ack_ping <= 0;
                IRQ_HANDLE_TDMA_CTL_START: begin         
                    //ipic_start_lite_irq <= 0; //Clear the bit asserted in IRQ_RXFIFO_DEQUEUE_PUSHBACK_START.
                    //test_sendpkt <= 1;
                    recv_pkt_pulse <= 1;
                    debug_gpio[2] <= !debug_gpio[2];
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



    parameter TXFR_IDLE=0, TXFR_RD_MAGIC=1, TXFR_RD_ADDR=2, TXFR_WAIT_DATA=3, TXFR_RD_DATA_WR_PCIE_START=4, 
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
                if ( !fifo_empty && fifo_valid && tdma_tx_enable) //TO DO: estimate pkt sending time.
                    next_txf_read_status = TXFR_RD_ADDR;
                else
                    next_txf_read_status = TXFR_IDLE;
            end
//            TXFR_RD_MAGIC: begin
//                if ( fifo_dread[C_DATA_WIDTH-1 : 0] == 0 )
//                    next_txf_read_status = TXFR_RD_ADDR;
//                else
//                    next_txf_read_status = TXFR_IDLE;
//            end
            TXFR_RD_ADDR: next_txf_read_status = TXFR_WAIT_DATA;
            TXFR_WAIT_DATA: begin
                if ( fifo_valid )
                    next_txf_read_status = TXFR_RD_DATA_WR_PCIE_START;
                else
                    next_txf_read_status = TXFR_WAIT_DATA;
            end
            TXFR_RD_DATA_WR_PCIE_START: next_txf_read_status = TXFR_WR_PCIE_MID;
            TXFR_WR_PCIE_MID: next_txf_read_status = TXFR_WR_PCIE_WAIT;
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
        end else begin
            case (next_txf_read_status)
                TXFR_IDLE: fifo_rd_en <= 0;
                TXFR_RD_ADDR: begin
                    fifo_rd_en <= 1;
                    write_addr_lite_txfr[ADDR_WIDTH-1 : 0] <= fifo_dread[DATA_WIDTH-1 : 0];
                end
                TXFR_WAIT_DATA: fifo_rd_en <= 0;
                TXFR_RD_DATA_WR_PCIE_START: begin
                    fifo_rd_en <= 1;
                    write_data_lite_txfr[ADDR_WIDTH-1 : 0] <= fifo_dread[DATA_WIDTH-1 : 0];
                    ipic_type_lite_txfr <= `SINGLE_WR;
                    ipic_start_lite_txfr <= 1;
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