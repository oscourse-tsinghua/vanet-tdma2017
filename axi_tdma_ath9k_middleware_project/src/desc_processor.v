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


module desc_processor # (
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_NATIVE_DATA_WIDTH = 32,
    parameter integer C_LENGTH_WIDTH = 12,
    parameter integer C_ADDR_WIDTH = 32,
    parameter integer C_DATA_WIDTH = 32,
    parameter integer C_PKT_LEN = 2048,
    
    parameter ATH9K_BASE_ADDR  =    32'h60000000,
    parameter AR_INTR_ASYNC_CAUSE = 32'h4038,
    parameter AR_INTR_SYNC_CAUSE = 32'h4028,
    parameter AR_RTC_STATUS = 32'h7044,
    parameter AR_ISR = 32'h0080,
    
    
    parameter AR_INTR_MAC_IRQ = 32'h00000002,
    parameter AR_RTC_STATUS_M = 32'h0000000f,
    parameter AR_RTC_STATUS_ON = 32'h00000002,
    parameter AR_ISR_LP_RXOK = 32'h00000002,
    parameter AR_ISR_HP_RXOK = 32'h00000001,
    
    parameter AR_RxDone = 32'h00000001,
    
    parameter IEEE80211_FCTL_FTYPE	= 32'h000c,
    parameter IEEE80211_FCTL_STYPE = 32'h00f0,
    parameter IEEE80211_FTYPE_CTL = 32'h0004,
    parameter IEEE80211_STYPE_TDMA	= 0,
    parameter IEEE80211_STYPE_TDMA1 = 32'h0010
)
(
    // CLK
    input wire clk,
    input wire reset_n,
    output reg tx_proc_error,
    // FIFO signals
    input wire  fifo_empty,
    input wire [C_DATA_WIDTH-1 : 0] fifo_dread,
    output reg fifo_rd_en,
    input wire  fifo_valid,
    input wire  fifo_underflow,

    input wire  rxfifo_empty,
    input wire [C_DATA_WIDTH-1 : 0] rxfifo_dread,
    output reg rxfifo_rd_en,
    input wire  rxfifo_valid,
    input wire  rxfifo_underflow,
        
    // IRQ input and output
    input wire irq_in,
    output reg irq_out,
    //input wire irq_readed_linux,
    
    //Debug
    output reg [2 : 0] debug_gpio,
    output wire [7:0] debug_port_8bits,
    
    // IPIC LITE

    
    //-----------------------------------------------------------------------------------------
    //-- IPIC STATE MACHINE
    //-----------------------------------------------------------------------------------------     
    output reg [2:0] ipic_type,
    output reg ipic_start,   
    input wire ipic_done_wire,
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr,
    output reg [C_LENGTH_WIDTH-1 : 0] read_length, 
    input wire [C_NATIVE_DATA_WIDTH-1 : 0] single_read_data,
    input wire [C_PKT_LEN-1:0] bunch_read_data, 
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_addr,  
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_data,
    output reg [C_LENGTH_WIDTH-1 : 0] write_beat_length,

    //-----------------------------------------------------------------------------------------
    //-- IPIC LITE STATE MACHINE
    //-----------------------------------------------------------------------------------------     
    output reg [2:0] ipic_type_lite,
    output reg ipic_start_lite,   
    input wire ipic_done_lite_wire,
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr_lite, 
    input wire [C_NATIVE_DATA_WIDTH-1 : 0] single_read_data_lite,
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_addr_lite,  
    output reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_data_lite, 
    // Status Registers
    output wire [4:0] curr_irq_state_wire
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

    reg [1:0] ipic_type_irq;   
    reg ipic_start_irq;
    reg [C_LENGTH_WIDTH-1 : 0] read_length_irq;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr_irq;
 
    reg [1:0] ipic_start_state; 
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_start <= 0;
            ipic_type <= 0;
            read_addr <= 0;
            read_length <= 0;            
            write_addr <= 0;
            write_beat_length <= 0;     
            ipic_start_state <= 0;       
        end else begin
            case(ipic_start_state)
                0:begin
                    if (ipic_start_irq) begin
                        ipic_type <= ipic_type_irq;
                        read_addr <= read_addr_irq;
                        read_length <= read_length_irq;
                        //write_addr <= write_addr_irq;
                        //write_length <= write_length_irq;
                        ipic_start <= 1;
                        ipic_start_state <= 1; 
                    end
                end
                1: begin
                    ipic_start <= 0;
                    ipic_start_state <= 0; 
                end
                default: begin end
            endcase
        end        
    end
    
    reg [1:0] ipic_type_lite_irq;  
    reg ipic_start_lite_irq;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr_lite_irq;
    
    reg [1:0] ipic_type_lite_txfr;
    reg ipic_start_lite_txfr;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_addr_lite_txfr;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] write_data_lite_txfr;
     
    reg [1:0] ipic_start_lite_state;     
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_start_lite <= 0;
            ipic_type_lite <= 0;
            read_addr_lite <= 0;          
            write_addr_lite <= 0; 
            ipic_start_lite_state <= 0;       
        end else begin
            case(ipic_start_lite_state)
                0:begin
                    if (ipic_start_lite_irq) begin
                        ipic_type_lite <= ipic_type_lite_irq;
                        read_addr_lite <= read_addr_lite_irq;
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1; 
                    end
                    if (ipic_start_lite_txfr) begin 
                        ipic_type_lite <= ipic_type_lite_txfr;
                        write_addr_lite <= write_addr_lite_txfr;
                        write_data_lite <= write_data_lite_txfr;
                        ipic_start_lite <= 1;
                        ipic_start_lite_state <= 1;                         
                    end
                end
                1: begin
                    ipic_start_lite <= 0;
                    ipic_start_lite_state <= 0; 
                end
                default: begin end
            endcase
        end        
    end
        
    parameter IRQ_IDLE=0, IRQ_JUDGE = 23,
            IRQ_GET_ASYNC_CAUSE_START=1,IRQ_GET_ASYNC_CAUSE_MID=2, IRQ_GET_ASYNC_CAUSE_WAIT=3,
            IRQ_GET_RTC_STATUS_START = 5, IRQ_GET_RTC_STATUS_MID = 6, IRQ_GET_RTC_STATUS_WAIT = 7, 
            IRQ_GET_ISR_START = 9, IRQ_GET_ISR_MID = 10, IRQ_GET_ISR_WAIT = 11,
            IRQ_PEEK_PKT_START = 13, IRQ_PEEK_PKT_MID = 14, IRQ_PEEK_PKT_WAIT = 15,
            IRQ_RXFIFO_DEQUEUE_START = 16, IRQ_RXFIFO_DEQUEUE_END = 17,  IRQ_HANDLE_TDMA_CTL_START = 18,
            
            IRQ_PASS_START = 21, IRQ_PASS_WAIT = 22,
            IRQ_ERROR=31;
    
    reg [4:0] curr_irq_state;
    assign curr_irq_state_wire = curr_irq_state;
    reg [4:0] next_irq_state;
    
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
     *  ��IRQ�����߼�����Ҫ��ɣ�?
     *  1. �յ�IRQ��Ч�źź󣬲�ѯ�ж����ݡ�
     *  2. ����ж�ΪRX������Ҫ�鿴�����ݰ��Ƿ�Ϊʱ϶���Ʊ��ġ�
     *    2a. ����ǿ��Ʊ��ģ��򲻲���irq_out�źţ�������жϼĴ���?
     *    2b. ������ǣ������irq_out�ź�
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
                    next_irq_state <= IRQ_GET_ASYNC_CAUSE_START;
                else
                    next_irq_state <= IRQ_IDLE;
            end
            IRQ_GET_ASYNC_CAUSE_START: begin
                next_irq_state <= IRQ_GET_ASYNC_CAUSE_MID;
            end
            IRQ_GET_ASYNC_CAUSE_MID: next_irq_state <= IRQ_GET_ASYNC_CAUSE_WAIT;
            IRQ_GET_ASYNC_CAUSE_WAIT: begin
                if (ipic_done_lite_wire)
                    if (single_read_data_lite & AR_INTR_MAC_IRQ)
                        next_irq_state <= IRQ_GET_ISR_START;//IRQ_GET_RTC_STATUS_START;
                    else
                        next_irq_state <= IRQ_PASS_START; //�ⲻ������Ҫ���жϣ����ݸ�������д���?
                else
                    next_irq_state <= IRQ_GET_ASYNC_CAUSE_WAIT;
            end
//            IRQ_GET_RTC_STATUS_START: next_irq_state <= IRQ_GET_RTC_STATUS_MID;
//            IRQ_GET_RTC_STATUS_MID: next_irq_state <= IRQ_GET_RTC_STATUS_WAIT;
//            IRQ_GET_RTC_STATUS_WAIT: begin
//                if (ipic_done_lite_wire)
//                    if ((single_read_data_lite  & AR_RTC_STATUS_M) == AR_RTC_STATUS_ON)
//                        next_irq_state <= IRQ_GET_ISR_START;
//                    else
//                        next_irq_state <= IRQ_IDLE; //����Ӧ���ǳ����ˣ�ֱ�Ӳ�������
//                else
//                    next_irq_state <= IRQ_GET_RTC_STATUS_WAIT;
//            end            

            IRQ_GET_ISR_START: next_irq_state <= IRQ_GET_ISR_MID;
            IRQ_GET_ISR_MID: next_irq_state <= IRQ_GET_ISR_WAIT;
            IRQ_GET_ISR_WAIT: begin
                if (ipic_done_lite_wire)
                    if (single_read_data_lite & (AR_ISR_HP_RXOK | AR_ISR_LP_RXOK)) 
                        next_irq_state <= IRQ_PEEK_PKT_START;//��ȡ���ݰ�
                    else
                        next_irq_state <= IRQ_PASS_START; //�ⲻ������Ҫ���жϣ����ݸ�������д���?                
                else
                    next_irq_state <= IRQ_GET_ISR_WAIT;                
            end
            
            /**
             * 1. Peek fifo, whether the pkt is valid ?
             *   1. if TRUE, Dequeue, ȡ��skb->data��ǰN���ֽڣ�����12 beats ��RxDesc��TDMA���ư�Ӧ�еĳ��ȡ�
             **/
            IRQ_PEEK_PKT_START: next_irq_state <= IRQ_PEEK_PKT_MID;
            IRQ_PEEK_PKT_MID: next_irq_state <= IRQ_PEEK_PKT_WAIT;
            IRQ_PEEK_PKT_WAIT: begin
                if (ipic_done_wire)
                    if (bunch_read_data[383:352] & AR_RxDone) // 11*32 +: 32 , ar9003_rxs->status11
                        next_irq_state <= IRQ_RXFIFO_DEQUEUE_START;
                    else
                        next_irq_state <= IRQ_PASS_START;
                else
                    next_irq_state <= IRQ_PEEK_PKT_WAIT;             
            end
            IRQ_RXFIFO_DEQUEUE_START: begin
                if (rxfifo_empty)
                    next_irq_state <= IRQ_ERROR;
                else
                    next_irq_state <= IRQ_RXFIFO_DEQUEUE_END;
            end
            IRQ_RXFIFO_DEQUEUE_END: begin
                if ((bunch_read_data[399:383] & (IEEE80211_FCTL_FTYPE | IEEE80211_FCTL_STYPE)) ==
                    (IEEE80211_FTYPE_CTL | IEEE80211_STYPE_TDMA)) //�ж� frame_control �ֶΡ�ar9003_rxs��ĵ�һ��?16λ���� frame_control
                    next_irq_state <= IRQ_HANDLE_TDMA_CTL_START;
                else
                    next_irq_state <= IRQ_PEEK_PKT_START; //LOOP !
            end
            IRQ_HANDLE_TDMA_CTL_START: begin 
                //��ʱ�Ȳ�ʵ�֣���һ���ƴ��棬�ж���Ȼ����linux�жϡ�
                next_irq_state <= IRQ_PEEK_PKT_START; //LOOP !
            end
            
            
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
            debug_gpio[2] <= 1;       
            current_irq_counter <= 0;     
            rxfifo_rd_en <= 0;
        end else begin
            case (next_irq_state) 
                IRQ_IDLE: begin
                    irq_out <= 0;
                end 
                IRQ_GET_ASYNC_CAUSE_START: begin
                    current_irq_counter[2:0] <= irq_counter[2:0];
                    read_addr_lite_irq <= ATH9K_BASE_ADDR + AR_INTR_ASYNC_CAUSE;
                    ipic_type_lite_irq <= `SINGLE_RD;
                    ipic_start_lite_irq <= 1;                 
                end
                //IRQ_GET_ASYNC_CAUSE_MID:
                IRQ_GET_ASYNC_CAUSE_WAIT: ipic_start_lite_irq <= 0;
                IRQ_GET_RTC_STATUS_START: begin
                    read_addr_lite_irq <= ATH9K_BASE_ADDR + AR_RTC_STATUS;
                    ipic_type_lite_irq <= `SINGLE_RD;
                    ipic_start_lite_irq <= 1;                          
                end
                //IRQ_GET_RTC_STATUS_MID: 
                IRQ_GET_RTC_STATUS_WAIT: ipic_start_lite_irq <= 0;
                //IRQ_GET_RTC_STATUS_END:
                IRQ_GET_ISR_START: begin
                    read_addr_lite_irq <= ATH9K_BASE_ADDR + AR_ISR;
                    ipic_type_lite_irq <= `SINGLE_RD;
                    ipic_start_lite_irq <= 1;  
                end
                //IRQ_GET_ISR_MID: 
                IRQ_GET_ISR_WAIT: ipic_start_lite_irq <= 0;
                //IRQ_GET_ISR_END: 

                /**
                 * 1. Peek fifo, whether the pkt is valid ?
                 *   1. if TRUE, Dequeue, ȡ��skb->data��ǰN���ֽڣ�����12 beats ��RxDesc��TDMA���ư�Ӧ�еĳ��ȡ�
                 **/
                IRQ_PEEK_PKT_START: begin
                    read_addr_irq <= rxfifo_dread;
                    read_length_irq <= C_PKT_LEN; 
                    ipic_type_irq <= `BURST_RD;
                    ipic_start_irq <= 1;
                end
                //IRQ_PEEK_PKT_MID: 
                IRQ_PEEK_PKT_WAIT: ipic_start_irq <= 0;
                IRQ_RXFIFO_DEQUEUE_START: rxfifo_rd_en <= 1;
                IRQ_RXFIFO_DEQUEUE_END: rxfifo_rd_en <= 0;
                IRQ_HANDLE_TDMA_CTL_START: begin 
                    //��ʱ�Ȳ�ʵ�֣���һ���ƴ��棬�ж���Ȼ����linux�жϡ�
                    debug_gpio[2] <= !debug_gpio[2];
                end
                
                IRQ_PASS_START: irq_out <= 1;
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
                if ( !fifo_empty && fifo_valid )
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
                    write_addr_lite_txfr[C_M_AXI_ADDR_WIDTH-1 : 0] <= fifo_dread[C_M_AXI_ADDR_WIDTH-1 : 0];
                end
                TXFR_WAIT_DATA: fifo_rd_en <= 0;
                TXFR_RD_DATA_WR_PCIE_START: begin
                    fifo_rd_en <= 1;
                    write_data_lite_txfr[C_M_AXI_ADDR_WIDTH-1 : 0] <= fifo_dread[C_M_AXI_ADDR_WIDTH-1 : 0];
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
