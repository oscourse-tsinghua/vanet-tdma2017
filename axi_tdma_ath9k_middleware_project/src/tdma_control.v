(* DONT_TOUCH = "yes" *)
module tdma_control # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer C_LENGTH_WIDTH = 14,
    parameter integer FRAME_SLOT_NUM = 100,
    parameter integer SLOT_US = 1000
)
(
    input wire clk,
    input wire reset_n,

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
    //-- IPIC Burst STATE MACHINE
    //-----------------------------------------------------------------------------------------   
    input wire [5:0] curr_ipic_state,
    output reg [2:0] ipic_type,
    output reg ipic_start,
    input wire ipic_ack,
    input wire ipic_done_wire,
    output reg [ADDR_WIDTH-1 : 0] read_addr,
    output reg [ADDR_WIDTH-1 : 0] write_addr,
    output reg [DATA_WIDTH-1 : 0] write_data,
    output reg [C_LENGTH_WIDTH-1 : 0] write_length,   
    output reg [1023:0] bunch_write_data,
    input wire [DATA_WIDTH-1 : 0] single_read_data,
    output reg [8:0] blk_mem_sendpkt_addra, //32 bit * 512 
    output reg [31:0] blk_mem_sendpkt_dina,
    output reg blk_mem_sendpkt_wea,
    
    //Tx fifo Read
    input wire [DATA_WIDTH-1:0] txfifo_dread,
    output reg txfifo_rd_en,
    input wire txfifo_empty,
    input wire txfifo_valid,
    //Tx fifo Write
    output reg txfifo_wr_start,
    output reg [DATA_WIDTH-1:0] txfifo_wr_data,
    input wire txfifo_wr_done,
    
    input wire [5:0] desc_irq_state,
    input wire test_sendpkt,
    
    // GPS TimePulse 1 and 2
    input wire gps_timepulse_1,
    input wire gps_timepulse_2,
    input wire [31:0] utc_sec_32bit,
    
    //-----------------------------------------------------------------------------------------
    //-- GPS Time Counters 
    //-----------------------------------------------------------------------------------------    
    output wire [31:0] gps_pulse1_counter,
    output wire [31:0] gps_pulse2_counter,
    
    //-----------------------------------------------------------------------------------------
    //-- PING state machine signals and registers
    //-----------------------------------------------------------------------------------------    
    //input signals
    input wire recv_ping,
    input wire [31:0] recv_seq,
    input wire recv_ack_ping,
    input wire [31:0] recv_sec,
    input wire [31:0] recv_counter2,
    input wire open_loop,
    input wire start_ping,
    //output result
    output reg [31:0] res_seq,
    output reg [31:0] res_delta_t,
    
    //-----------------------------------------------------------------------------------------
    //-- TDMA controls
    //-----------------------------------------------------------------------------------------  
    input wire tdma_function_enable,   
    input wire [DATA_WIDTH/2 -1:0] bch_user_pointer,
    output reg [9:0] slot_pulse2_counter,
    output reg tdma_tx_enable
);

    /////////////////////////////////////////////////////////////
    // GPS TimePulse Logic
    /////////////////////////////////////////////////////////////
    // 1. TimePulse_1 pulses per 1 UTC-Sec. This is for the UTC time,
    // UTC time can be readed from a specific register after a pulse.
    // 2. We count TimePulse_2 to maintain an accurate and sync time.
    // The 32bit-counter clears every 1 UTC-sec.
    /////////////////////////////////////////////////////////////
    `define MAX_COUNTER2 32'hf423f
    
    reg [31:0] pulse1_counter;
    reg [31:0] pulse2_counter;
    reg [31:0] curr_pulse1_counter;
    reg [31:0] curr_utc_sec;
    assign gps_pulse1_counter[31:0] = pulse1_counter[31:0];
    assign gps_pulse2_counter[31:0] = pulse2_counter[31:0];
    
    always @ (posedge gps_timepulse_1 or negedge reset_n)
    begin
        if ( reset_n == 0 ) begin
            pulse1_counter <= 0;
            curr_utc_sec <= 0;
        end else begin
            pulse1_counter <= pulse1_counter + 1'b1;
            curr_utc_sec <= utc_sec_32bit;
        end
    end
    
    always @ (posedge gps_timepulse_2 or negedge reset_n)
    begin
        if ( reset_n == 0 ) begin
            pulse2_counter <= 0;
            curr_pulse1_counter <= 0;
        end else begin
            if (pulse1_counter[31:0] != curr_pulse1_counter[31:0]) begin
                curr_pulse1_counter[31:0] <= pulse1_counter[31:0];
                pulse2_counter <= 0;
            end else begin
                pulse2_counter <= pulse2_counter + 1;
            end
        end
    end
    
    /////////////////////////////////////////////////////////////
    // Time slot pointer (1ms per slot, 1 frame contains 100 slots)
    /////////////////////////////////////////////////////////////
    reg [31:0] curr_pulse1_counter2;
    
    (* mark_debug = "true" *) reg [DATA_WIDTH/2 -1:0] slot_pointer;
    always @ (posedge gps_timepulse_2 or negedge reset_n)
    begin
        if ( reset_n == 0 ) begin
            slot_pointer <= 0;
            slot_pulse2_counter <= 0;
            curr_pulse1_counter2 <= 0;
        end else begin
            if (pulse1_counter[31:0] != curr_pulse1_counter2[31:0]) begin
                curr_pulse1_counter2[31:0] <= pulse1_counter[31:0];
                slot_pointer <= 0;
                slot_pulse2_counter <= 0;
            end else begin
                if (slot_pulse2_counter == (SLOT_US - 1)) begin // 1ms
                    slot_pulse2_counter <= 0;
                    if (slot_pointer == (FRAME_SLOT_NUM - 1)) // a frame contains FRAME_SLOT_NUM slots
                        slot_pointer <= 0;
                    else
                        slot_pointer <= slot_pointer + 1; 
                end else
                    slot_pulse2_counter = slot_pulse2_counter + 1;
            end
        end        
    end

    /////////////////////////////////////////////////////////////
    // BCH accessing state machine (To do)
    /////////////////////////////////////////////////////////////       
    
    /////////////////////////////////////////////////////////////
    // BCH pointer assignment
    /////////////////////////////////////////////////////////////
    // Input: time slot state (to do)
    //        bch_user_pointer
    /////////////////////////////////////////////////////////////
    reg [DATA_WIDTH/2 -1:0] bch_slot_pointer;
    reg bch_accessible_flag;
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            bch_slot_pointer <= 16'hffff;
            bch_accessible_flag <= 0;
        end else begin
            if (bch_user_pointer != 16'hffff) begin
                bch_slot_pointer <= bch_user_pointer;
                bch_accessible_flag <= 1;
            end else begin
                bch_slot_pointer <= 16'hffff;
                bch_accessible_flag <= 0;            
            end
        end
    end
    
    /////////////////////////////////////////////////////////////
    // Time slot enabling: enable TX in our own BCH
    /////////////////////////////////////////////////////////////    
    // Input: bch_accessible_flag
    //        bch_pointer
    /////////////////////////////////////////////////////////////  
    always @ (posedge clk)
    begin
        if (reset_n == 0 || tdma_function_enable == 0) begin
            tdma_tx_enable <= 1;
        end else begin
            if ( bch_accessible_flag && bch_slot_pointer == slot_pointer )
                tdma_tx_enable <= 1;
            else
                tdma_tx_enable <= 0;
        end
    end
    
    `define BURST_RD 0
    `define BURST_WR 1
    `define SINGLE_RD 2
    `define SINGLE_WR 3
    
    reg [DATA_WIDTH-1:0] curr_skbdata_addr;
    reg send_ping;

    localparam ATH9K_BASE_ADDR  =    32'h60000000;
    localparam integer AR_Q1_TXDP = 32'h0804;
    localparam integer AR_Q6_TXDP = 32'h0818;
    
    `define EX 0
    `define MO 1

    /////////////////////////////////////////////////////////////
    // IPIC Burst Interface
    /////////////////////////////////////////////////////////////
    reg [2:0] ipic_dispatch_type;
    reg [2:0] ipic_type_ex;   
    reg ipic_start_ex;
    reg ipic_ack_ex;
    reg [ADDR_WIDTH-1 : 0] read_addr_ex;
    
    reg [2:0] ipic_type_mo;
    reg ipic_start_mo;
    reg ipic_ack_mo;
    reg [C_LENGTH_WIDTH-1 : 0] write_length_mo;
    reg [ADDR_WIDTH-1 : 0] write_addr_mo;
      
    reg [2:0] ipic_start_state; 
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_start <= 0;
            ipic_type <= 0;
            read_addr <= 0;      
            write_addr <= 0;
            write_length <= 0;     
            ipic_start_state <= 0;       
            ipic_ack_ex <= 0;
            ipic_ack_mo <= 0;
        end else begin
            case(ipic_start_state)
                0:begin
                    if (ipic_start_ex) begin
                        //ipic_ack_irq <= 1;
                        ipic_dispatch_type <= `EX;
                        ipic_type <= ipic_type_ex;
                        read_addr <= read_addr_ex;
                        ipic_start <= 1;
                        ipic_start_state <= 1; 
                    end else if (ipic_start_mo) begin
                        //ipic_ack_ur <= 1;
                        ipic_dispatch_type <= `MO;
                        ipic_type <= ipic_type_mo;
                        write_addr <= write_addr_mo;
                        write_length <= write_length_mo;
                        ipic_start <= 1;
                        ipic_start_state <= 1;                     
                    end
                end
                1: begin
                    if (ipic_ack) begin
                        case (ipic_dispatch_type)
                            `EX: ipic_ack_ex <= 1;
                            `MO: ipic_ack_mo <= 1;
                            default: begin 
                                ipic_ack_ex <= 0;
                                ipic_ack_mo <= 0;
                            end
                        endcase
                        ipic_start_state <= 2; 
                    end
                end
                2: begin
                    ipic_start <= 0;
                    ipic_start_state <= 0; 
                    ipic_ack_ex <= 0;
                    ipic_ack_mo <= 0;
                    if (ipic_done_wire) begin
                        ipic_start_state <= 0; 
                    end
                end
                default: begin end
            endcase
        end        
    end
    
    reg [4:0] sendpkt_counter;
    reg [4:0] current_sendpkt_counter;
    wire sendpkt;
    assign sendpkt = test_sendpkt || send_ping;
    
    always @ (posedge sendpkt or negedge reset_n)
    begin
        if ( reset_n == 0 ) begin 
            sendpkt_counter <= 0;
        end else begin
            sendpkt_counter <= sendpkt_counter + 1;
        end
    end
    
    reg [3:0] pktsend_status;
    always @ (posedge clk)
    begin
    if (reset_n == 0) begin
        txfifo_rd_en <= 0;
        txfifo_wr_start <= 0;
        pktsend_status <= 0;
        current_sendpkt_counter <= 0;
    end else begin 
        case (pktsend_status)
//            0: begin
//                if (test_sendpkt || send_ping) 
//                    pktsend_status<= 1;
//            end
            0: begin
                if (tdma_tx_enable && sendpkt_counter != current_sendpkt_counter)
                    pktsend_status<= 2;
                else
                    pktsend_status<= 0;
            end
            2: begin
                current_sendpkt_counter <= current_sendpkt_counter + 1;
                if (txfifo_valid && desc_irq_state == 0) begin
                    txfifo_rd_en <= 1;
                    write_addr_lite[ADDR_WIDTH-1 : 0] <= ATH9K_BASE_ADDR + AR_Q6_TXDP;
                    write_data_lite[DATA_WIDTH-1 : 0] <= txfifo_dread[DATA_WIDTH-1 : 0];
                    txfifo_wr_data[DATA_WIDTH-1 : 0] <= txfifo_dread[DATA_WIDTH-1 : 0];
                    ipic_type_lite <= `SINGLE_WR;
                    
                    pktsend_status <= 3;
                end
            end
            3: begin //the used desc must be push back to the tx fifo.
                txfifo_rd_en <= 0;

                if (curr_ipic_lite_state == 0) begin
                    txfifo_wr_start <= 1;
                    ipic_start_lite <= 1;
                    pktsend_status<= 4;
                end
                
            end
            4: begin
                if (ipic_ack_lite) begin
                    pktsend_status<= 5;
                end
            end
            5: begin
                txfifo_wr_start <= 0;
                ipic_start_lite <= 0;
                if ( ipic_done_lite_wire ) begin
                    pktsend_status <= 0;
                end
            end

            default:begin end
        endcase
        end
    end
    /////////////////////////////////////////////////////////////
    // Read Skb->data addr from Desc
    /////////////////////////////////////////////////////////////
    reg [2:0] exaddr_state;
    reg init_flag;
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            exaddr_state <= 0;
            init_flag <= 1;
            curr_skbdata_addr <= 0;
            ipic_start_ex <= 0;
        end else begin  
            case (exaddr_state)
                0: begin
                    if ((init_flag || txfifo_rd_en) && txfifo_valid) begin
                        exaddr_state <= 1;
                        init_flag <= 0;
                    end
                end
                1: exaddr_state <= 2;
                2: begin
                    if (!txfifo_rd_en) begin// wait the fifo read operation. we will read the skb-pointer from the next tx-desc.
                        read_addr_ex <= txfifo_dread[DATA_WIDTH-1 : 0] + 8; //refer to ar9003_txc
                        ipic_type_ex <= `SINGLE_RD;
                        ipic_start_ex <= 1; 
                        exaddr_state <= 3;                        
                    end
                end
                3: begin
                    if (ipic_ack_ex) begin
                        ipic_start_ex <= 0;
                        exaddr_state <= 4;
                    end
                end
                4: begin
                    if (ipic_done_wire) begin
                        curr_skbdata_addr <= single_read_data;
                        exaddr_state <= 0;
                    end
                end
            endcase
        end
    end
    
    `define PING 1
    `define ACK_PING 2
    
    // lens of the 802.11 MAC header is 30 bytes. 2 bytes for padding.
    `define PAYLOAD_OFFSET 32'h20
    
    reg [31:0] test_seq;
    reg [5:0] pkt_type_flag;
    reg [31:0] pkt_sec;
    reg [31:0] pkt_counter2;
    /////////////////////////////////////////////////////////////
    // Modify packets 
    /////////////////////////////////////////////////////////////
    //    input wire recv_ping,
    //    input wire recv_ack_ping,
    //    input wire start_ping
    // 1. flag(32bit), test_seq (32bit),  utc_sec(32bit), gps_counter2(32bit)
    /////////////////////////////////////////////////////////////
    localparam MO_IDLE=0, MO_WAIT_TXEN=1, MO_PROCESS_ACKPING=2,
                MO_SETPKT_START=3, MO_SETPKT_WR_SEQ = 4, MO_SETPKT_WR_SEC = 5, MO_SETPKT_WR_COUNTER2 = 6, MO_SETPKT_MID=7, MO_SETPKT_WAIT=8,
                MO_END=9, MO_ERROR = 10;
                
    (* mark_debug = "true" *) reg [3:0] mo_state;
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            mo_state <= MO_IDLE;
            test_seq <= 0;
            pkt_type_flag <= 0;
            send_ping <= 0;
            res_seq <= 0;
            res_delta_t <= 0;
            ipic_start_mo <= 0;
            bunch_write_data <= 0;
            blk_mem_sendpkt_wea <= 0;
        end else begin
            case (mo_state)
                MO_IDLE: begin
                    if (start_ping) begin
                        mo_state <= MO_WAIT_TXEN;
                    end else if (recv_ping) begin
                        test_seq <= recv_seq;
                        pkt_type_flag <= `ACK_PING;
                        pkt_sec <= recv_sec;
                        pkt_counter2 <= recv_counter2;
                        mo_state <= MO_SETPKT_START;
                    end else if ( recv_ack_ping)
                        mo_state <= MO_PROCESS_ACKPING;
                end
                MO_WAIT_TXEN: begin
                    if (tdma_tx_enable) begin
                        test_seq <= 1;
                        res_seq <= 0;
                        res_delta_t <= 0;
                        pkt_type_flag <= `PING;
                        pkt_sec <= curr_utc_sec;
                        pkt_counter2 <= pulse2_counter;
                        mo_state <= MO_SETPKT_START;
                    end
                end
                MO_PROCESS_ACKPING: begin
                    //calulate 
                    res_seq <= recv_seq;
                    res_delta_t <= ((recv_sec == curr_utc_sec) ? 
                                    (pulse2_counter - recv_counter2) : 
                                    (pulse2_counter + `MAX_COUNTER2 - recv_counter2));
                    //loopback?
                    if (open_loop) begin
                        pkt_type_flag <= `PING;
                        test_seq <= test_seq + 1;
                        pkt_sec <= curr_utc_sec;
                        pkt_counter2 <= pulse2_counter;
                        mo_state <= MO_SETPKT_START;
                    end else begin
                        mo_state <= MO_IDLE;
                        send_ping <= 0;
                    end
                end
                MO_SETPKT_START: begin //open_loop &&
                    // flag(32bit), test_seq (32bit), utc_sec(32bit), gps_counter2(32bit)
                    blk_mem_sendpkt_wea <= 1;
                    blk_mem_sendpkt_addra <= 0;
                    blk_mem_sendpkt_dina <= pkt_type_flag[5:0];
                    bunch_write_data[127:0] <= {pkt_counter2[31:0], pkt_sec[31:0],test_seq[31:0], 26'b0, pkt_type_flag[5:0] };// 32'h66666666, 32'h55555555, 32'h44444444
                    mo_state <= MO_SETPKT_WR_SEQ;
                end
                MO_SETPKT_WR_SEQ: begin
                    blk_mem_sendpkt_addra <= 1;
                    blk_mem_sendpkt_dina <= test_seq[31:0];
                    mo_state <= MO_SETPKT_WR_SEC;
                end
                MO_SETPKT_WR_SEC: begin
                    blk_mem_sendpkt_addra <= 2;
                    blk_mem_sendpkt_dina <= pkt_sec[31:0];
                    mo_state <= MO_SETPKT_WR_COUNTER2;
                end  
                MO_SETPKT_WR_COUNTER2: begin
                    blk_mem_sendpkt_addra <= 3;
                    blk_mem_sendpkt_dina <= pkt_counter2[31:0];
                    
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `BURST_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    write_length_mo <= 16;
                    mo_state <= MO_SETPKT_MID;
                end                               
                MO_SETPKT_MID: begin
                    blk_mem_sendpkt_wea <= 0;
                    if (ipic_ack_mo) begin
                        mo_state <= MO_SETPKT_WAIT;
                        ipic_start_mo <= 0; 
                    end
                end
                MO_SETPKT_WAIT:
                    if (ipic_done_wire) begin
                        mo_state <= MO_END;
                        send_ping <= 1;
                    end
                MO_END: begin
                    send_ping <= 0;
                    mo_state <= MO_IDLE;
                end
            endcase
        end
    end
    

endmodule