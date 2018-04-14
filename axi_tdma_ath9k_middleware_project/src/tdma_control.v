(* DONT_TOUCH = "yes" *)
module tdma_control # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer C_LENGTH_WIDTH = 14,
    parameter integer FRAME_SLOT_NUM = 64,
    parameter integer SLOT_US = 1000,
    parameter integer TX_GUARD_NS = 70000, // 70 us
    parameter integer TIME_PER_BYTE_12M_NS = 700 // 700 ns per byte under 12 Mbps
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
    input wire [15:0] ptr_checksum,
    output reg [ADDR_WIDTH-1 : 0] write_addr,
    output reg [DATA_WIDTH-1 : 0] write_data,
    output reg [C_LENGTH_WIDTH-1 : 0] write_length,   
//    output reg [1023:0] bunch_write_data,
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
    //-- block memory stores slot status. 64bits 128dept.
    //-----------------------------------------------------------------------------------------     
    output reg [6:0] blk_mem_slot_status_addr,
    output reg [63:0] blk_mem_slot_status_din,
    input wire [63:0] blk_mem_slot_status_dout,
    output reg blk_mem_slot_status_we,
        
    //-----------------------------------------------------------------------------------------
    //-- TDMA controls
    //-----------------------------------------------------------------------------------------  
    input wire [7:0] global_sid,
    input wire [1:0] global_priority,
    input wire [8:0] bch_candidate_c3hop_thres_s1,
    input wire [8:0] bch_candidate_c3hop_thres_s2,
    input wire tdma_function_enable,   
    input wire [DATA_WIDTH/2 -1:0] bch_user_pointer,
    output reg [9:0] slot_pulse2_counter,
    output reg tdma_tx_enable,
    output reg [31:0] bch_control_time_ns
);

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
    localparam FI_PKT_LEN = ((FRAME_SLOT_NUM >> 1) * 5 + 2); // FRAME_SLOT_NUM * 20 bits / 8 + 2
    localparam REQ_PKT_LEN = (FRAME_SLOT_NUM >> 3 + 3);
    localparam ADJ_PKT_LEN = 3; // bytes.
    localparam BAN_PKT_LEN = 3;
    
    localparam FI_PKT_TIME_NS = TIME_PER_BYTE_12M_NS * (FI_PKT_LEN + 4) + TX_GUARD_NS; //4 bytes FCS.
    localparam REQ_PKT_TIME_NS = TIME_PER_BYTE_12M_NS * (REQ_PKT_LEN + 4) + TX_GUARD_NS;
    localparam ADJ_PKT_TIME_NS = TIME_PER_BYTE_12M_NS * (ADJ_PKT_LEN + 4) + TX_GUARD_NS;
    localparam BAN_PKT_TIME_NS = TIME_PER_BYTE_12M_NS * (BAN_PKT_LEN + 4) + TX_GUARD_NS;
    
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
    localparam FI_PKT_TYPE_MSB = 4, FI_PKT_TYPE_LSB = 0;
    localparam FI_SENDER_SID_MSB = 12, FI_SENDER_SID_LSB = 5;
    localparam FI_S_PERSLOT_BUSY_MSB = 1, FI_S_PERSLOT_BUSY_LSB = 0;
    localparam FI_S_PERSLOT_OCCUPIER_SID_MSB = 9, FI_S_PERSLOT_OCCUPIER_SID_LSB = 2;
    localparam FI_S_PERSLOT_COUNT_MSB = 17, FI_S_PERSLOT_COUNT_LSB = 10;
    localparam FI_S_PERSLOT_PSF_MSB = 19, FI_S_PERSLOT_PSF_LSB = 18;
    
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
    // Time slot pointer (1ms per slot, 1 frame contains FRAME_SLOT_NUM slots)
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
        
    reg [15:0] fifo_fcb_dwrite;
    wire [15:0] fifo_fcb_dread_s1;
    reg fifo_fcb_srst;
    reg fifo_fcb_wr_en_s1;
    reg fifo_fcb_rd_en_s1;
    wire fifo_fcb_wr_ack_s1;
    wire fifo_fcb_full_s1;
    wire fifo_fcb_empty_s1;
    wire fifo_fcb_valid_s1;
    wire [7:0] fifo_fcb_data_count_s1;
    fifo_16bits_128dept fifo_fcb_candidates_s1_inst (
        .clk(clk),
        .srst(fifo_fcb_srst),
        .din(fifo_fcb_dwrite),              
        .wr_en(fifo_fcb_wr_en_s1),            
        .rd_en(fifo_fcb_rd_en_s1),            
        .dout(fifo_fcb_dread_s1),              
        .full(fifo_fcb_full_s1),            
        .wr_ack(fifo_fcb_wr_ack_s1),         
        .empty(fifo_fcb_empty_s1),           
        .valid(fifo_fcb_valid_s1),
        .data_count(fifo_fcb_data_count_s1)
    );
    
    wire [15:0] fifo_fcb_dread_s2;
    reg fifo_fcb_wr_en_s2;
    reg fifo_fcb_rd_en_s2;
    wire fifo_fcb_wr_ack_s2;
    wire fifo_fcb_full_s2;
    wire fifo_fcb_empty_s2;
    wire fifo_fcb_valid_s2;
    wire [7:0] fifo_fcb_data_count_s2;
    fifo_16bits_128dept fifo_fcb_candidates_s2_inst (
        .clk(clk),
        .srst(fifo_fcb_srst),
        .din(fifo_fcb_dwrite),              
        .wr_en(fifo_fcb_wr_en_s2),            
        .rd_en(fifo_fcb_rd_en_s2),            
        .dout(fifo_fcb_dread_s2),              
        .full(fifo_fcb_full_s2),            
        .wr_ack(fifo_fcb_wr_ack_s2),         
        .empty(fifo_fcb_empty_s2),           
        .valid(fifo_fcb_valid_s2),
        .data_count(fifo_fcb_data_count_s2)
    );

    reg blk_mem_sendpkt_en_mo;
    reg blk_mem_sendpkt_en_fi;
    reg [8:0] blk_mem_sendpkt_addr_mo;
    reg [31:0] blk_mem_sendpkt_din_mo;
    reg blk_mem_sendpkt_we_mo;  
//    reg [8:0] blk_mem_sendpkt_addr_bch;
//    reg [31:0] blk_mem_sendpkt_din_bch;
//    reg blk_mem_sendpkt_we_bch;
    reg [8:0] blk_mem_sendpkt_addr_fi;
    reg [31:0] blk_mem_sendpkt_din_fi;
    reg blk_mem_sendpkt_we_fi;
    /////////////////////////////////////////////////////////////
    // Logic for accessing blk_mem_sendpkt
    /////////////////////////////////////////////////////////////
    always @ (*) //Only one of the enabling signals will be set at same time.
    begin
        if (blk_mem_sendpkt_en_mo) begin
            blk_mem_sendpkt_addra = blk_mem_sendpkt_addr_mo;
            blk_mem_sendpkt_dina = blk_mem_sendpkt_din_mo;
            blk_mem_sendpkt_wea = blk_mem_sendpkt_we_mo;            
        end else begin// if (blk_mem_sendpkt_en_fi) begin
            blk_mem_sendpkt_addra = blk_mem_sendpkt_addr_fi;
            blk_mem_sendpkt_dina = blk_mem_sendpkt_din_fi;
            blk_mem_sendpkt_wea = blk_mem_sendpkt_we_fi;            
        end 
//        else begin
//            blk_mem_sendpkt_addra = blk_mem_sendpkt_addr_bch;
//            blk_mem_sendpkt_dina = blk_mem_sendpkt_din_bch;
//            blk_mem_sendpkt_wea = blk_mem_sendpkt_we_bch;
//        end
    end
            
    reg divider_enable;
    wire divider_done;
    reg [31:0] dividend;
    reg [31:0] divisor;
    wire [31:0] divider_result;
    wire [31:0] divider_remainder;

    simple_divider simple_divider_inst (
        .clk(clk),
        .rst_n(reset_n),        
        .enable(divider_enable),
        .a(dividend),
        .b(divisor),
        .yshang(divider_result),
        .yyushu(divider_remainder),
        .done(divider_done)
    );
    
    reg fcb_inprogress;
    reg fcb_start;
    reg fcb_done;
    reg fcb_fail;
    reg fcb_strict;
    reg [6:0] slot_status_addr_fcb;
    
    reg blk_mem_slot_status_en_mo;
    reg blk_mem_slot_status_en_fi;
    reg [6:0] slot_status_addr_mo;
    reg [6:0] slot_status_addr_fi;
    reg [6:0] slot_status_addr_bch;
    reg [63:0] slot_status_din_fi;
    reg [63:0] slot_status_din_bch;
    reg slot_status_we_fi;
    reg slot_status_we_bch;
    
    /////////////////////////////////////////////////////////////
    // Logic for accessing blk_mem_slot_status
    /////////////////////////////////////////////////////////////
    always @ ( * ) //Only one of the enabling signals will be set at same time.
    begin
        if (fcb_inprogress) begin
            blk_mem_slot_status_addr = slot_status_addr_fcb;
            blk_mem_slot_status_din = slot_status_din_bch; //meaningless.
            blk_mem_slot_status_we = 0;
        end else if (blk_mem_slot_status_en_mo) begin
            blk_mem_slot_status_addr = slot_status_addr_mo;
            blk_mem_slot_status_din = slot_status_din_bch; //meaningless
            blk_mem_slot_status_we = 0;
        end else if (blk_mem_slot_status_en_fi) begin
            blk_mem_slot_status_addr = slot_status_addr_fi;  
            blk_mem_slot_status_din = slot_status_din_fi;
            blk_mem_slot_status_we = slot_status_we_fi;
        end else begin
            blk_mem_slot_status_addr = slot_status_addr_bch;   
            blk_mem_slot_status_din = slot_status_din_bch;   
            blk_mem_slot_status_we = slot_status_we_bch;  
        end
    end
    
    /////////////////////////////////////////////////////////////
    // State machine for finding a candidate BCH (fcb)
    /////////////////////////////////////////////////////////////
    localparam FCB_IDLE = 0, FCB_START = 1, FCB_RD_LOOP = 2, FCB_RD_LOOP_2 = 3, 
                FCB_SEL_RAN_START = 4, FCB_SEL_RAN_WAIT_1 = 5, FCB_SEL_RAN_WAIT_2 = 6,
                FCB_DONE = 7;
    
    (* mark_debug = "true" *) reg [3:0] fcb_state;
    reg [15:0] fcb_bch_candidate;
    reg [5:0] fcb_ran_idx;
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin
            fcb_state <= FCB_IDLE;
            fcb_done <= 0;
            fcb_fail <= 0;
            fcb_inprogress <= 0;
            fifo_fcb_wr_en_s1 <= 0;
            fifo_fcb_rd_en_s1 <= 0;
            fifo_fcb_wr_en_s2 <= 0;
            fifo_fcb_rd_en_s1 <= 0;
            fcb_bch_candidate <= 16'hffff;
            divider_enable <= 0;
            fifo_fcb_srst <= 0;
            fcb_ran_idx <= 0;
            fifo_fcb_dwrite <= 0;
        end else begin
            case (fcb_state)
                FCB_IDLE: begin
                    fcb_done <= 0;
                    if (fcb_start) begin
                        fcb_inprogress <= 1;
                        fcb_fail <= 0;
                        slot_status_addr_fcb <= 0;
                        fcb_bch_candidate <= 16'hffff;
                        fcb_state <= FCB_START;
                    end
                end
                FCB_START: fcb_state <= FCB_RD_LOOP;
                FCB_RD_LOOP: // pick up slots those count_3hop is less than the threshold. 
                    if (slot_status_addr_fcb == FRAME_SLOT_NUM) begin
                        fifo_fcb_wr_en_s1 <= 0;
                        fifo_fcb_wr_en_s2 <= 0;
                        fcb_state <= FCB_SEL_RAN_START;
                    end else begin
                        if ( blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] < bch_candidate_c3hop_thres_s1
                            && (blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] == 0)) begin
                            fifo_fcb_wr_en_s1 <= 1;
                            fifo_fcb_dwrite <= slot_status_addr_fcb;
                        end else if ( !fcb_strict && blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] < bch_candidate_c3hop_thres_s2 
                            && (blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] == 0)) begin
                            fifo_fcb_wr_en_s2 <= 1;
                            fifo_fcb_dwrite <= slot_status_addr_fcb; // two fifos share one write bus.
                        end else begin
                            fifo_fcb_wr_en_s1 <= 0;
                            fifo_fcb_wr_en_s2 <= 0;
                        end
                        slot_status_addr_fcb <= slot_status_addr_fcb + 1;
                    end
                FCB_SEL_RAN_START: begin// randomly select a slot from the candidata fifo. Seed: pulse2_counter, pulse1_counter
                    if (!fifo_fcb_empty_s1) begin
                        dividend <= pulse2_counter[5:0];
                        divisor <= fifo_fcb_data_count_s1;
                        divider_enable <= 1;
                        fcb_state <= FCB_SEL_RAN_WAIT_1;
                    end else if (!fifo_fcb_empty_s2) begin
                        dividend <= pulse2_counter[5:0];
                        divisor <= fifo_fcb_data_count_s2;
                        divider_enable <= 1;
                        fcb_state <= FCB_SEL_RAN_WAIT_1;                    
                    end else begin
                        fcb_fail <= 1; // we cannot find a bch candidate.
                        fcb_state <= FCB_DONE; 
                    end
                end
                FCB_SEL_RAN_WAIT_1: begin
                    divider_enable <= 0;
                    if (divider_done) begin
                        fcb_ran_idx <= divider_remainder;
                        if (fifo_fcb_valid_s1)
                            fcb_bch_candidate <= fifo_fcb_dread_s1; //incase that fcb_ran_idx is 0
                        else if (fifo_fcb_valid_s2)
                            fcb_bch_candidate <= fifo_fcb_dread_s2; //incase that fcb_ran_idx is 0
                        fcb_state <= FCB_SEL_RAN_WAIT_2;
                    end
                end
                FCB_SEL_RAN_WAIT_2: begin
                    if (fifo_fcb_valid_s1 && fcb_ran_idx) begin
                        fifo_fcb_rd_en_s1 <= 1;
                        fcb_bch_candidate <= fifo_fcb_dread_s1;
                        fcb_ran_idx = fcb_ran_idx - 1;
                    end else if (fifo_fcb_valid_s2 && fcb_ran_idx) begin
                        fifo_fcb_rd_en_s2 <= 1;
                        fcb_bch_candidate <= fifo_fcb_dread_s2;
                        fcb_ran_idx = fcb_ran_idx - 1;
                    end else begin
                        fifo_fcb_rd_en_s1 <= 0;
                        fifo_fcb_rd_en_s2 <= 0;
                        fcb_inprogress <= 0;
                        fifo_fcb_srst <= 1; // reset fifos.
                        fcb_state <= FCB_DONE;
                    end
                end
                FCB_DONE: begin
                    fcb_done <= 1;
                    fifo_fcb_srst <= 0;
                    fcb_state <= FCB_IDLE;
                end  
            endcase
        end
    end
    /////////////////////////////////////////////////////////////
    // BCH accessing state machine
    /////////////////////////////////////////////////////////////
    parameter BCH_IDLE = 0,
            BCH_LIS_DECIDE_REQ = 1, BCH_LIS_WAIT_NEXT_SLOT = 2, BCH_LIS_WAIT_NEXT_SLOT_2 = 3, BCH_LIS_WAIT_NEXT_FRAME = 4, 
            BCH_LIS_FCB_START = 5, BCH_LIS_FCB_WAIT = 6,  BCH_LIS_FCB_DONE = 7, 
            BCH_WAIT_REQ_WAIT = 8,
            BCH_WAIT_REQ_SEND_START = 9, BCH_WAIT_REQ_SEND_WAIT = 10, BCH_WAIT_REQ_SEND_DONE = 11, 
            BCH_WAIT_REQ_FCB_START = 12, BCH_WAIT_REQ_FCB_WAIT = 13, BCH_WAIT_REQ_FCB_DONE = 14, BCH_WAIT_REQ_FCB_SET_STATUS = 15,
            BCH_REQ_WAIT = 16, BCH_WORK_FI_INIT_START = 17, BCH_WORK_FI_INIT_WAIT = 18, BCH_WORK_FI_WAIT = 19, BCH_WORK_FI_SEND_FI_START = 20,  BCH_WORK_FI_SEND_FI_WAIT = 21,
            BCH_WORK_FI_FCB_START = 22, BCH_WORK_FI_FCB_WAIT = 23, BCH_WORK_FI_FCB_DONE = 24, BCH_WORK_ENA_TX = 25, BCH_WORK_DISA_TX = 26, 
            BCH_WORK_FI_SEND_ADJ_START = 27, BCH_WORK_FI_SEND_ADJ_WAIT = 28, BCH_WORK_ADJ_WAIT = 29, 
            BCH_WORK_ADJ_SEND_FI_START = 30, BCH_WORK_ADJ_SEND_FI_WAIT = 31, 
            BCH_WORK_ADJ_DECIDE_ADJ = 32, BCH_WORK_ADJ_SET_STATUS = 33, BCH_WORK_ADJ_SEND_BAN_START = 34, BCH_WORK_ADJ_SEND_BAN_WAIT = 35,
            BCH_WORK_ADJ_RETREAT_1 = 36, BCH_WORK_ADJ_RETREAT_2 = 37,
            BCH_WORK_ADJ_BCH_INVALID = 38, BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID = 39, 
            BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID = 40, BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID = 41, BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID = 42, 
            BCH_WORK_ADJ_FREE_1_BCH_INVALID = 43, BCH_WORK_ADJ_FREE_2_BCH_INVALID = 44, BCH_WORK_ADJ_FREE_3_BCH_INVALID = 45,
            
            BCH_END = 62, BCH_ERROR = 63;
    
    (* mark_debug = "true" *) reg [5:0] curr_bch_state;
    reg [5:0] next_bch_state;
    
    reg send_req_start;
    reg send_req_done;
    
    reg init_fi_start;
    reg init_fi_done;
    reg send_fi_start;
    reg send_fi_done;
    
    reg send_adj_start;
    reg send_adj_done;
    
    reg send_ban_start;
    reg send_ban_done;
    
    reg bch_adj_flag;

    (* mark_debug = "true" *) reg [DATA_WIDTH/2 -1:0] bch_decide_req;
    (* mark_debug = "true" *) reg [DATA_WIDTH/2 -1:0] bch_decide_adj;
    (* mark_debug = "true" *) reg [DATA_WIDTH/2 -1:0] bch_work_pointer;
    
    reg bch_accessible_flag;
    
    always @ (posedge clk)
    begin
        if ( reset_n == 0 )
            curr_bch_state <= BCH_IDLE;           
        else
            curr_bch_state <= next_bch_state; 
    end 
    
    always @ (curr_bch_state)
    begin
        case (curr_bch_state)
            BCH_IDLE: 
                if (tdma_function_enable && bch_user_pointer == 16'hffff)
                    next_bch_state = BCH_LIS_DECIDE_REQ;
                else
                    next_bch_state = BCH_IDLE;
            BCH_LIS_DECIDE_REQ: next_bch_state = BCH_LIS_WAIT_NEXT_SLOT;
            BCH_LIS_WAIT_NEXT_SLOT:
                if (bch_decide_req != (slot_pointer + 1) % FRAME_SLOT_NUM) //we need to wait for the next slot (as BCH_LIS_DECIDE_REQ has set bch_decide_req to its current slot_pointer + 1).
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT_2;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT;
            BCH_LIS_WAIT_NEXT_SLOT_2:
                if (bch_decide_req != slot_pointer)  // wait another slot.
                    next_bch_state = BCH_LIS_WAIT_NEXT_FRAME;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT_2;
            BCH_LIS_WAIT_NEXT_FRAME:
                if (bch_decide_req == slot_pointer) //Wait one frmae.
                    next_bch_state = BCH_LIS_FCB_START;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_FRAME;
            BCH_LIS_FCB_START: next_bch_state = BCH_LIS_FCB_WAIT;
            BCH_LIS_FCB_WAIT: 
                if (fcb_done)
                    next_bch_state = BCH_LIS_FCB_DONE;
                else
                    next_bch_state = BCH_LIS_FCB_WAIT;
            BCH_LIS_FCB_DONE: //set bch_decide_req, set slot_status_addr_bch and status (decide_req) in the blk_mem accordingly
                if (fcb_fail)
                    next_bch_state = BCH_IDLE;
                else
                    next_bch_state = BCH_WAIT_REQ_WAIT;
            BCH_WAIT_REQ_WAIT: //set slot status (decide_req) in the blk_mem accordingly
                if (slot_pointer == bch_decide_req) begin//wait until bch_decide_req slot.
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                        || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_LIS_FCB_DONE
                        next_bch_state = BCH_WAIT_REQ_SEND_START;
                    else
                        next_bch_state = BCH_WAIT_REQ_FCB_START;
                end else
                    next_bch_state = BCH_WAIT_REQ_WAIT;
            BCH_WAIT_REQ_SEND_START: next_bch_state = BCH_WAIT_REQ_SEND_WAIT; //Construct REQ and send it.
            BCH_WAIT_REQ_SEND_WAIT:
                if (send_req_done)
                    next_bch_state = BCH_WAIT_REQ_SEND_DONE;
                else
                    next_bch_state = BCH_WAIT_REQ_SEND_WAIT;            
            BCH_WAIT_REQ_SEND_DONE: 
                if (slot_pointer != bch_decide_req) //wait for the next slot.
                    next_bch_state = BCH_REQ_WAIT;
                else
                    next_bch_state = BCH_WAIT_REQ_SEND_DONE;
            //the decide_req slot (and bch_work_pointer) is unusable, we should reset the status of this slot, and re-run the FCB process.
            BCH_WAIT_REQ_FCB_START: next_bch_state = BCH_WAIT_REQ_FCB_WAIT; 
            BCH_WAIT_REQ_FCB_WAIT:
                if (fcb_done)
                    next_bch_state = BCH_WAIT_REQ_FCB_DONE;
                else
                    next_bch_state = BCH_WAIT_REQ_FCB_WAIT;
            //1. set bch_decide_req, set slot_status_addr_bch.
            //2. status (decide_req) will be set in BCH_WAIT_REQ_SEND_START                    
            BCH_WAIT_REQ_FCB_DONE: 
                if (fcb_fail)
                    next_bch_state = BCH_IDLE;
                else
                    next_bch_state = BCH_WAIT_REQ_WAIT;
            BCH_REQ_WAIT:
                if (slot_pointer == bch_decide_req)
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                        || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_REQ_WAIT
                        next_bch_state = BCH_WORK_FI_INIT_START;
                    else
                        next_bch_state = BCH_WAIT_REQ_FCB_START;  
                else
                    next_bch_state = BCH_REQ_WAIT;
            // 1. set bch_work_pointer�� set slot_status_addr_bch and status in the blk_mem accordingly
            // 2. notify FI_state_machine to initial FI pkt for the first time.
            BCH_WORK_FI_INIT_START: next_bch_state = BCH_WORK_FI_INIT_WAIT;
            BCH_WORK_FI_INIT_WAIT:
                if (init_fi_done)
                    next_bch_state = BCH_WORK_FI_WAIT;
                else
                    next_bch_state = BCH_WORK_FI_INIT_WAIT;
            //��BCH_REQ_WAIT�����Ժ���Ҫ�ٵ�һ��֡
            //set slot_status_addr_bch
            BCH_WORK_FI_WAIT: 
                if (slot_pointer == bch_work_pointer)
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                        || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_WORK_FI_INIT_START and BCH_WORK_FI_WAIT
                        next_bch_state = BCH_WORK_FI_SEND_FI_START;
                    else
                        next_bch_state = BCH_WAIT_REQ_FCB_START;
                else
                    next_bch_state = BCH_WORK_FI_WAIT;
            BCH_WORK_FI_SEND_FI_START: next_bch_state = BCH_WORK_FI_SEND_FI_WAIT;
            BCH_WORK_FI_SEND_FI_WAIT:
                if (send_fi_done)
                    if (blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] > bch_candidate_c3hop_thres_s1)
                        next_bch_state = BCH_WORK_FI_FCB_START;
                    else
                        next_bch_state = BCH_WORK_ENA_TX;
                else
                    next_bch_state = BCH_WORK_FI_SEND_FI_WAIT;
            //set fcb_strict: we only want candidate whose value lower than thres_s1.
            BCH_WORK_FI_FCB_START: next_bch_state = BCH_WORK_FI_FCB_WAIT;
            BCH_WORK_FI_FCB_WAIT:
                if (fcb_done)
                    next_bch_state = BCH_WORK_FI_FCB_DONE;
                else
                    next_bch_state = BCH_WORK_FI_FCB_WAIT;
            //set bch_decide_adj
            BCH_WORK_FI_FCB_DONE:
                if (fcb_fail)
                    next_bch_state = BCH_WORK_ENA_TX;
                else
                    next_bch_state = BCH_WORK_FI_SEND_ADJ_START;
            // 1. set bch_adj_flag.
            // 2. set slot_status_addr_bch and status in the blk_mem accordingly
            BCH_WORK_FI_SEND_ADJ_START: next_bch_state = BCH_WORK_FI_SEND_ADJ_WAIT;
            BCH_WORK_FI_SEND_ADJ_WAIT:
                if (send_adj_done)
                    next_bch_state = BCH_WORK_ENA_TX;
                else 
                    next_bch_state = BCH_WORK_FI_SEND_ADJ_WAIT;                    
            //enable bch_accessible_flag in the bch slot.
            BCH_WORK_ENA_TX:
                if (slot_pointer != bch_work_pointer)
                    next_bch_state = BCH_WORK_DISA_TX;
                else
                    next_bch_state = BCH_WORK_ENA_TX;
            //disable bch_accessible_flag
            BCH_WORK_DISA_TX: 
                if (bch_adj_flag)
                    next_bch_state = BCH_WORK_ADJ_WAIT;
                else
                    next_bch_state = BCH_WORK_FI_WAIT;
            BCH_WORK_ADJ_WAIT:
                if (slot_pointer == bch_work_pointer)
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                        || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_WORK_ADJ_WAIT
                        next_bch_state = BCH_WORK_ADJ_SEND_FI_START;
                    else
                        next_bch_state = BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID;
                else
                    next_bch_state = BCH_WORK_ADJ_WAIT;
            //set slot_status_addr_bch to bch_decide_adj
            BCH_WORK_ADJ_SEND_FI_START: next_bch_state = BCH_WORK_ADJ_SEND_FI_WAIT;
            BCH_WORK_ADJ_SEND_FI_WAIT:
                if (send_fi_done)
                    next_bch_state = BCH_WORK_ADJ_DECIDE_ADJ;
                else
                    next_bch_state = BCH_WORK_ADJ_SEND_FI_WAIT;
            BCH_WORK_ADJ_DECIDE_ADJ: 
                if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                    || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_WORK_ADJ_SEND_FI_START
                    next_bch_state = BCH_WORK_ADJ_SET_STATUS;
                else
                    next_bch_state = BCH_WORK_ADJ_RETREAT_1;
            // 1. clear status of current bch_work_pointer
            BCH_WORK_ADJ_SET_STATUS: next_bch_state = BCH_WORK_ADJ_SEND_BAN_START;
            // 2. reset bch_work_pointer to bch_decide_adj, set status of bch_decide_adj to FI.
            BCH_WORK_ADJ_SEND_BAN_START: next_bch_state = BCH_WORK_ADJ_SEND_BAN_WAIT;
            BCH_WORK_ADJ_SEND_BAN_WAIT:
                if (send_ban_done)
                    next_bch_state = BCH_WORK_ENA_TX;
                else
                    next_bch_state = BCH_WORK_ADJ_SEND_BAN_WAIT;
            //1.clear status of bch_decide_adj
            BCH_WORK_ADJ_RETREAT_1: next_bch_state = BCH_WORK_ADJ_RETREAT_2;
            //2. reset slot_status_addr_bch to bch_work_pointer
            BCH_WORK_ADJ_RETREAT_2: next_bch_state = BCH_WORK_FI_WAIT;
            //set slot_status_addr_bch to bch_decide_adj
            BCH_WORK_ADJ_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID;
            BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID: 
                if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) 
                    || (0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB])) // address has been set in BCH_WORK_ADJ_BCH_INVALID
                    next_bch_state = BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID;
                else
                    next_bch_state = BCH_WORK_ADJ_FREE_1_BCH_INVALID; 
            // 1. set bch_work_pointer to bch_decide_adj
            // 2. set set old bch status to free; set new bch status)
            // * Here we just forgive the empty Counts because we just empty it befor the old bch.
            BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID;
            // 3. set new bch status
            BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID;
            // 4. reset slot_status_addr_bch to new bch.
            BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID: next_bch_state = BCH_WORK_FI_WAIT;
            
            // 1. set status of bch to free.
            BCH_WORK_ADJ_FREE_1_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_FREE_2_BCH_INVALID;
            // 2. set status of bch_decide_adj to free.
            BCH_WORK_ADJ_FREE_2_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_FREE_3_BCH_INVALID;
            BCH_WORK_ADJ_FREE_3_BCH_INVALID: next_bch_state = BCH_WAIT_REQ_FCB_START;
            default: next_bch_state = BCH_ERROR;
        endcase
    end

    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            fcb_start <= 0;
            slot_status_we_bch <= 0;
            slot_status_din_bch[63:0] <= 0;
            send_req_start <= 0;
            init_fi_start <= 0;
            send_fi_start <= 0;
            fcb_strict <= 0;
            bch_adj_flag <= 0;
            bch_accessible_flag <= 0;
            send_ban_start <= 0;
            send_adj_start <= 0;
        end else begin
            case (next_bch_state)
//                BCH_IDLE:    
                BCH_LIS_DECIDE_REQ: begin
                    bch_decide_req <= (slot_pointer + 1) % FRAME_SLOT_NUM;
                end
//                BCH_LIS_WAIT_NEXT_FRAME:
//                BCH_LIS_WAIT:
                BCH_LIS_FCB_START: begin
                    fcb_start <= 1;
                    fcb_strict <= 0;
                end
                BCH_LIS_FCB_WAIT: fcb_start <= 0;
                BCH_LIS_FCB_DONE: begin//set bch_decide_req, set slot_status_addr_bch 
                    bch_decide_req <= fcb_bch_candidate;
                    slot_status_addr_bch <= fcb_bch_candidate;
                end
                BCH_WAIT_REQ_WAIT: slot_status_we_bch <= 0;
                // 1. set slot status (decide_req) in the blk_mem accordingly
                // 2. Construct REQ and send it.
                BCH_WAIT_REQ_SEND_START: begin
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_DECIDE_REQ; 
                    slot_status_we_bch <= 1;   
                    send_req_start <= 1;             
                end
                BCH_WAIT_REQ_SEND_WAIT: begin
                    send_req_start <= 0; 
                    slot_status_we_bch <= 0;
                end          
//                BCH_WAIT_REQ_SEND_DONE: 
                //the decide_req slot (and bch_work_pointer) is unusable, we should reset the status of this slot, and re-run the FCB process.
                BCH_WAIT_REQ_FCB_START: begin
                    fcb_start <= 1;
                    fcb_strict <= 0;
                    slot_status_addr_bch <= bch_decide_req;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING; 
                    slot_status_we_bch <= 1;
                end
                BCH_WAIT_REQ_FCB_WAIT: begin
                    fcb_start <= 0;
                    slot_status_we_bch <= 0;
                end
                //1. set bch_decide_req, set slot_status_addr_bch.
                //2. status (decide_req) will be set in BCH_WAIT_REQ_SEND_START
                BCH_WAIT_REQ_FCB_DONE: begin
                    bch_decide_req <= fcb_bch_candidate;
                    slot_status_addr_bch <= fcb_bch_candidate;                    
                end
//                BCH_REQ_WAIT: 
                // 1. set bch_work_pointer�� set slot_status_addr_bch and status in the blk_mem accordingly
                // 2. notify FI_state_machine to initial FI pkt for the first time.
                BCH_WORK_FI_INIT_START: begin
                    bch_work_pointer <= bch_decide_req;
                    slot_status_addr_bch <= bch_decide_req;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_FI;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 2'b10;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= global_sid;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= global_priority;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1; //the count-2hop of bch should always be 1 untill collision happens.
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                    slot_status_we_bch <= 1;
                    init_fi_start <= 1;
                end
                BCH_WORK_FI_INIT_WAIT: begin
                    slot_status_we_bch <= 0;
                    init_fi_start <= 0;
                end
                //��BCH_REQ_WAIT�����Ժ���Ҫ�ٵ�һ��֡
                //set slot_status_addr_bch
                BCH_WORK_FI_WAIT: begin
                    slot_status_addr_bch <= bch_work_pointer;
                end
                BCH_WORK_FI_SEND_FI_START: begin
                    send_fi_start <= 1;
                end
                BCH_WORK_FI_SEND_FI_WAIT: send_fi_start <= 0;
                //1. set fcb_strict: we only want candidate whose value lower than thres_s1.
                //2. set status of current bch from FI to ADJ;
                BCH_WORK_FI_FCB_START: begin
                    fcb_strict <= 1;
                    fcb_start <= 1;
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_ADJ;
                    slot_status_we_bch <= 1;
                end
                BCH_WORK_FI_FCB_WAIT: begin
                    slot_status_we_bch <= 0;
                    fcb_start <= 0;
                end
                //set bch_decide_adj
                BCH_WORK_FI_FCB_DONE: begin
                    fcb_strict <= 0;
                    bch_decide_adj <= fcb_bch_candidate;
                end
                // 1. set bch_adj_flag.
                // 2. set slot_status_addr_bch and status in the blk_mem accordingly
                // 3. send adj pkt
                BCH_WORK_FI_SEND_ADJ_START: begin
                    bch_adj_flag <= 1;
                    slot_status_addr_bch <= bch_decide_adj;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_DECIDE_ADJ;
                    slot_status_we_bch <= 1;
                    send_adj_start <= 1;
                end
                BCH_WORK_FI_SEND_ADJ_WAIT: begin
                    slot_status_we_bch <= 0;
                    send_adj_start <= 0;
                end
                //enable bch_accessible_flag in the bch slot.
                BCH_WORK_ENA_TX: bch_accessible_flag <= 1;
                //disable bch_accessible_flag
                BCH_WORK_DISA_TX: bch_accessible_flag <= 0;
                BCH_WORK_ADJ_WAIT: bch_adj_flag <= 0;
                //set slot_status_addr_bch to bch_decide_adj
                BCH_WORK_ADJ_SEND_FI_START: begin
                    send_fi_start <= 1;
                    slot_status_addr_bch <= bch_decide_adj;
                end
                BCH_WORK_ADJ_SEND_FI_WAIT: send_fi_start <= 0;
//                BCH_WORK_ADJ_DECIDE_ADJ: 
                    
                // 1. clear status of current bch_work_pointer
                BCH_WORK_ADJ_SET_STATUS: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch <= 0;
                    slot_status_we_bch <= 1;                    
                end
                // 2. set status of bch_decide_adj to FI.
                // 3. send ban pkt.
                BCH_WORK_ADJ_SEND_BAN_START: begin
                    
                    slot_status_addr_bch <= bch_decide_adj;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_FI;
                    
                    send_ban_start <= 1;
                end
                // 4. reset bch_work_pointer to bch_decide_adj
                BCH_WORK_ADJ_SEND_BAN_WAIT: begin
                    slot_status_we_bch <= 0;
                    send_ban_start <= 0;
                    bch_work_pointer <= bch_decide_adj;
                end
                //1. clear status of bch_decide_adj
                BCH_WORK_ADJ_RETREAT_1: begin
                    slot_status_addr_bch <= bch_decide_adj;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                    slot_status_we_bch <= 1;
                end
                //2. reset slot_status_addr_bch to bch_work_pointer
                BCH_WORK_ADJ_RETREAT_2: begin
                    slot_status_we_bch <= 0;
                    slot_status_addr_bch <= bch_work_pointer;
                end
                //set slot_status_addr_bch to bch_decide_adj
                BCH_WORK_ADJ_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_decide_adj;
                end
//                BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID: 

                // 1. set bch_work_pointer to bch_decide_adj
                // 2. set set old bch status to free; 
                // * Here we just forgive the empty Counts because we just empty it befor the old bch.
                BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                    slot_status_we_bch <= 1;
                    bch_work_pointer <= bch_decide_adj;
                end
                // 3. set new bch status
                BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_FI;                    
                end
                BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID: slot_status_we_bch <= 0;
                // 1. set status of bch to free.
                BCH_WORK_ADJ_FREE_1_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                    slot_status_we_bch <= 1;
                end
                // 2. set status of bch_decide_adj to free.
                BCH_WORK_ADJ_FREE_2_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_decide_adj;
                    slot_status_din_bch[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;                
                end
                BCH_WORK_ADJ_FREE_3_BCH_INVALID: slot_status_we_bch <= 0;
                default: begin end
            endcase
        end
    end
        
    /////////////////////////////////////////////////////////////
    // BCH pointer assignment
    /////////////////////////////////////////////////////////////
    // Input: time slot state (to do)
    //        bch_user_pointer
    /////////////////////////////////////////////////////////////
    reg [DATA_WIDTH/2 -1:0] bch_slot_pointer;
    reg bch_user_accessible_flag;
    
    always @ (*)
    begin
        if (bch_user_pointer != 16'hffff) begin
            bch_slot_pointer = bch_user_pointer;
            bch_user_accessible_flag = 1;
        end else begin
            bch_slot_pointer = bch_work_pointer;
            bch_user_accessible_flag = 0;
        end
    end
    
    /////////////////////////////////////////////////////////////
    // Time slot enabling: enable TX in our own BCH
    /////////////////////////////////////////////////////////////    
    // Input: accessible_flag
    //        bch_pointer
    /////////////////////////////////////////////////////////////  
    always @ (*)
    begin
        if (reset_n == 0 || tdma_function_enable == 0) begin
            tdma_tx_enable = 1;
        end else begin
            if ( (bch_user_accessible_flag || bch_accessible_flag) && bch_slot_pointer == slot_pointer )
                tdma_tx_enable = 1;
            else
                tdma_tx_enable = 0;
        end
    end
    
    `define BURST_RD 0
    `define BURST_WR 1
    `define SINGLE_RD 2
    `define SINGLE_WR 3
    `define CAL_DESC_CKS 5
    
    reg [DATA_WIDTH-1:0] curr_skbdata_addr;
    reg send_pkt_mo;

    localparam ATH9K_BASE_ADDR  =    32'h60000000;
    localparam integer AR_Q1_TXDP = 32'h0804;
    localparam integer AR_Q6_TXDP = 32'h0818;
    
    `define EX 0
    `define MO 1
    `define FI 2

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
    reg [DATA_WIDTH-1 : 0] write_data_mo;
    reg [C_LENGTH_WIDTH-1 : 0] read_length_mo;
    reg [ADDR_WIDTH-1 : 0] read_addr_mo;
    
    reg [2:0] ipic_type_fi;
    reg ipic_start_fi;
    reg ipic_ack_fi;
    reg [C_LENGTH_WIDTH-1 : 0] write_length_fi;
    reg [ADDR_WIDTH-1 : 0] write_addr_fi;
    reg [DATA_WIDTH-1 : 0] write_data_fi;
    reg [C_LENGTH_WIDTH-1 : 0] read_length_fi;
    reg [ADDR_WIDTH-1 : 0] read_addr_fi;
              
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
            ipic_ack_fi <= 0;
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
                        write_data <= write_data_mo;
                        write_length <= write_length_mo;
                        read_addr <= read_addr_mo;
                        ipic_start <= 1;
                        ipic_start_state <= 1;                     
                    end else if (ipic_start_fi) begin
                        ipic_dispatch_type <= `FI;
                        ipic_type <= ipic_type_fi;
                        write_addr <= write_addr_fi;
                        write_data <= write_data_fi;
                        write_length <= write_length_fi;
                        read_addr <= read_addr_fi;
                        ipic_start <= 1;
                        ipic_start_state <= 1;                     
                    end
                end
                1: begin
                    if (ipic_ack) begin
                        case (ipic_dispatch_type)
                            `EX: ipic_ack_ex <= 1;
                            `MO: ipic_ack_mo <= 1;
                            `FI: ipic_ack_fi <= 1;
                            default: begin 
                                ipic_ack_ex <= 0;
                                ipic_ack_mo <= 0;
                                ipic_ack_fi <= 0;
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
                    ipic_ack_fi <= 0;
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
    assign sendpkt = test_sendpkt || send_pkt_mo;
    
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
                if (sendpkt_counter != current_sendpkt_counter)
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
    
    `define PING        1
    `define ACK_PING    2
    `define BCH_REQ     3
    `define BCH_FI      4
    `define BCH_ADJ     5
    `define BCH_BAN     6
    
    // lens of the 802.11 MAC header is 30 bytes. 2 bytes for padding.
    `define PAYLOAD_OFFSET 32'h20

    /////////////////////////////////////////////////////////////
    // Construct FI pkt just before our BCH begins.
    /////////////////////////////////////////////////////////////
    parameter FI_IDLE = 0,
            FI_START = 1, FI_LOOP_1_PRE = 29, FI_LOOP_1 = 2, FI_LOOP_2 = 3,
            FI_SET_PKT_CONTENT_START = 4, FI_SET_PKT_CONTENT_MID = 5, FI_SET_PKT_CONTENT_WAIT = 6,
            FI_SET_BUF_LEN_START = 7, FI_SET_BUF_LEN_MID = 8, FI_SET_BUF_LEN_WAIT = 9,
            FI_SET_FRAME_LEN_START = 10, FI_SET_FRAME_LEN_MID = 11, FI_SET_FRAME_LEN_WAIT = 12,
            FI_CAL_CKS_START = 13, FI_CAL_CKS_MID = 14, FI_CAL_CKS_WAIT = 15, FI_SET_CKS_START = 16, FI_SET_CKS_MID = 17, FI_SET_CKS_WAIT = 18,
            FI_END = 30, FI_ERROR = 31;
    (* mark_debug = "true" *) reg [4:0] fi_state;
    
    reg [12:0] fi_index;
    reg [6:0] bit_fi_index;
    reg [10:0] fi_pkt_len_byte;
    reg [FI_PER_SLOT_BITSNUM-1:0] fi_per_slot;
    reg [4:0] fi_per_slot_index;
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            fi_state <= FI_IDLE;
            init_fi_done <= 0;
            blk_mem_sendpkt_we_fi <= 0;
            blk_mem_sendpkt_en_fi <= 0;
            blk_mem_slot_status_en_fi <= 0;
            slot_status_we_fi <= 0;
            fi_index <= 0;
        end else begin
            case (fi_state)
                FI_IDLE: begin
                    init_fi_done <= 0;
                    if (init_fi_start)
                        fi_state <= FI_START;
                    else if (curr_bch_state > BCH_WORK_FI_INIT_WAIT ) begin
                        if (bch_work_pointer == 0) begin
                            if (slot_pointer == (FRAME_SLOT_NUM - 1) 
                                && (slot_pulse2_counter > (SLOT_US - 10))) 
                                fi_state <= FI_START;
                        end else begin 
                            if ((slot_pointer == (bch_work_pointer - 1)) 
                                && (slot_pulse2_counter > (SLOT_US - 10))) 
                                fi_state <= FI_START;
                        end
                    end else
                        fi_state <= FI_IDLE;
                end
                FI_START: begin
                    blk_mem_sendpkt_en_fi <= 1; //enable accessing the sendpkt block memory.
                    blk_mem_slot_status_en_fi <= 1; //enable accessing the slot status block memory.
                    blk_mem_sendpkt_addr_fi <= 0;
                    slot_status_addr_fi <= 0;
                    blk_mem_sendpkt_din_fi[4:0] <= `BCH_FI;
                    blk_mem_sendpkt_din_fi[12:5] <= global_sid;

                    fi_pkt_len_byte <= FI_PKT_LEN;//FRAME_SLOT_NUM * 20 bits / 8. 
                    fi_index <= 13;
                    bit_fi_index = 13;
                    fi_state <= FI_LOOP_1_PRE;
                end

                FI_LOOP_1_PRE: begin
                    slot_status_din_fi[STATUS_MSB : STATUS_LSB] <= blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB];
                    slot_status_din_fi[BUSY_MSB:BUSY_LSB] <= blk_mem_slot_status_dout[BUSY_MSB:BUSY_LSB];
                    slot_status_din_fi[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB] <= blk_mem_slot_status_dout[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB];
                    slot_status_din_fi[COUNT_2HOP_MSB: COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB: COUNT_2HOP_LSB];
                    slot_status_din_fi[COUNT_3HOP_MSB:COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB:COUNT_3HOP_LSB];
                    slot_status_din_fi[PSF_MSB:PSF_LSB] <= blk_mem_slot_status_dout[PSF_MSB:PSF_LSB];
                    slot_status_din_fi[LIFE_MSB:LIFE_LSB] <= blk_mem_slot_status_dout[LIFE_MSB:LIFE_LSB];
                    slot_status_din_fi[C3HOP_N] <= blk_mem_slot_status_dout[C3HOP_N];
                    blk_mem_sendpkt_we_fi <= 0;
                    fi_state <= FI_LOOP_1;
                end

                FI_LOOP_1: begin
                    fi_per_slot[FI_S_PERSLOT_BUSY_MSB:FI_S_PERSLOT_BUSY_LSB] <= blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB];
                    fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB:FI_S_PERSLOT_OCCUPIER_SID_LSB] <= blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB];
                    fi_per_slot[FI_S_PERSLOT_COUNT_MSB:FI_S_PERSLOT_COUNT_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB];
                    fi_per_slot[FI_S_PERSLOT_PSF_MSB:FI_S_PERSLOT_PSF_LSB] <= blk_mem_slot_status_dout[PSF_MSB : PSF_LSB];
                    fi_per_slot_index <= 0;
                    //Clear Count_2hop/3hop after we construct FI.
                    slot_status_we_fi <= 1;
                    if (slot_status_addr_fi == bch_work_pointer) begin
                        slot_status_din_fi[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1;
                        slot_status_din_fi[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;                    
                    end else begin
                        slot_status_din_fi[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0;
                        slot_status_din_fi[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                    end
                    slot_status_din_fi[C3HOP_N] <= 0;
                    //refresh life time.         
                    if (blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] > 1) begin
                        slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] - 1;
                    end if (blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] == 1) begin
                        slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= 0;
                        slot_status_din_fi[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                        slot_status_din_fi[BUSY_MSB : BUSY_LSB] <= 0;
                        slot_status_din_fi[STATUS_MSB : STATUS_LSB] <= STATUS_NOTHING;
                        slot_status_din_fi[PSF_MSB : PSF_LSB] <= 0;
                    end
                    fi_state <= FI_LOOP_2;  
                end
                FI_LOOP_2: begin
                    blk_mem_sendpkt_we_fi <= 1;
                    slot_status_we_fi <= 0;
                    blk_mem_sendpkt_din_fi[bit_fi_index] = fi_per_slot[fi_per_slot_index];
                    bit_fi_index = (bit_fi_index + 1) % DATA_WIDTH;
                    fi_index = fi_index + 1;
                    if (fi_index == ((fi_pkt_len_byte << 3) - 3)) // fi_pkt_len_byte includes 3 bits extra padding.
                        fi_state <= FI_SET_PKT_CONTENT_START; 
                    else begin
                        fi_per_slot_index = fi_per_slot_index + 1;
                        if (bit_fi_index == 0)
                            blk_mem_sendpkt_addr_fi <= blk_mem_sendpkt_addr_fi + 1;
                        if (fi_per_slot_index == FI_PER_SLOT_BITSNUM) begin
                            slot_status_addr_fi <= slot_status_addr_fi + 1;
                            fi_state <= FI_LOOP_1_PRE;
                        end
                    end
                end
                FI_SET_PKT_CONTENT_START: begin     
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `BURST_WR;
                    write_addr_fi <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    write_length_fi <= (FI_PKT_LEN + 4) & 14'h3FFC; // because FI_PKT_LEN is not 4 byte aligned !
                    fi_state = FI_SET_PKT_CONTENT_MID;
                end
                FI_SET_PKT_CONTENT_MID: 
                    if (ipic_ack_fi) begin
                        ipic_start_fi <= 0; 
                        fi_state <= FI_SET_PKT_CONTENT_WAIT;                       
                    end
                FI_SET_PKT_CONTENT_WAIT: 
                    if (ipic_done_wire) begin
                        fi_state <= FI_SET_BUF_LEN_START;
                    end  
                FI_SET_BUF_LEN_START: begin
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `SINGLE_WR;
                    write_addr_fi <= txfifo_dread[DATA_WIDTH-1 : 0] + 12; //refer to ar9003_txc 
                    write_data_fi <= ((`PAYLOAD_OFFSET + FI_PKT_LEN + 4) << 16) & 32'h0fff0000;
                    fi_state = FI_SET_BUF_LEN_MID;                    
                end
                FI_SET_BUF_LEN_MID: 
                    if (ipic_done_wire) begin
                        ipic_start_fi <= 0; 
                        fi_state <= FI_SET_BUF_LEN_WAIT;
                    end                 
                FI_SET_BUF_LEN_WAIT:
                    if (ipic_done_wire) begin
                        fi_state <= FI_SET_FRAME_LEN_START;
                    end 
                FI_SET_FRAME_LEN_START: begin
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `SINGLE_WR;
                    write_addr_fi <= txfifo_dread[DATA_WIDTH-1 : 0] + 44; //refer to ar9003_txc 
                    write_data_fi <= ((`PAYLOAD_OFFSET + FI_PKT_LEN + 4 + 4) & 32'h00000fff) | 32'h13f0000;
                    fi_state = FI_SET_FRAME_LEN_MID;
                end
                FI_SET_FRAME_LEN_MID: 
                    if (ipic_done_wire) begin
                        ipic_start_fi <= 0; 
                        fi_state <= FI_SET_FRAME_LEN_WAIT;
                    end           
                FI_SET_FRAME_LEN_WAIT:
                    if (ipic_done_wire) begin
                        fi_state <= FI_CAL_CKS_START;
                    end

                FI_CAL_CKS_START: begin
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `CAL_DESC_CKS;
                    read_addr_fi <= txfifo_dread[DATA_WIDTH-1 : 0];
                    fi_state <= FI_CAL_CKS_MID;
                end
                FI_CAL_CKS_MID: begin
                    if (ipic_ack_fi) begin
                        ipic_start_fi <= 0; 
                        fi_state <= FI_CAL_CKS_WAIT;
                    end
                end
                FI_CAL_CKS_WAIT: begin
                    if (ipic_done_wire) 
                        fi_state <= FI_SET_CKS_START;
                end
                FI_SET_CKS_START: begin
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `SINGLE_WR;
                    write_addr_fi <= txfifo_dread[DATA_WIDTH-1 : 0] + 40; //refer to ar9003_txc 
                    write_data_fi <= ptr_checksum;
                    fi_state = FI_SET_CKS_MID;
                end
                FI_SET_CKS_MID: 
                    if (ipic_ack_fi) begin
                        ipic_start_fi <= 0;
                        fi_state = FI_SET_CKS_WAIT;
                    end
                FI_SET_CKS_WAIT: 
                    if (ipic_done_wire) begin
                        fi_state = FI_END;
                    end
                FI_END: begin
                    init_fi_done <= 1;
                    if (bch_slot_pointer == 0 && (slot_pointer != (FRAME_SLOT_NUM - 1)))
                        fi_state <= FI_IDLE;
                    else if (bch_slot_pointer != 0 && slot_pointer != (bch_slot_pointer - 1))
                        fi_state <= FI_IDLE;
                end
                default: fi_state <= FI_ERROR;
            endcase
        end   
    end    
        
    reg [31:0] test_seq;
    reg [4:0] pkt_type_flag;
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
    parameter MO_IDLE=0, MO_WAIT_TXEN=1, MO_PROCESS_ACKPING=2,
                MO_SETPKT_START=3, MO_SETPKT_WR_SEQ = 4, MO_SETPKT_WR_SEC = 5, MO_SETPKT_WR_COUNTER2 = 6, MO_SETPKT_MID=7, MO_SETPKT_WAIT=8,
                MO_SET_REQ_START = 9, MO_SET_REQ_LOOP = 10, 
                MO_SET_REQ_PKT_CONTENT_START = 11, MO_SET_REQ_PKT_CONTENT_MID = 12, MO_SET_REQ_PKT_CONTENT_WAIT = 13,

                MO_SEND_FI = 14,
                MO_SET_ADJ_PKT_CONTENT_START = 15, MO_SET_ADJ_PKT_CONTENT_MID = 16, MO_SET_ADJ_PKT_CONTENT_WAIT = 17,

                MO_SET_BAN_PKT_CONTENT_START = 18, MO_SET_BAN_PKT_CONTENT_MID = 19, MO_SET_BAN_PKT_CONTENT_WAIT = 20,
                MO_SET_BUF_LEN_START = 21, MO_SET_BUF_LEN_MID = 22, MO_SET_BUF_LEN_WAIT = 23, 
                MO_SET_FRAME_LEN_START = 24, MO_SET_FRAME_LEN_MID = 25, MO_SET_FRAME_LEN_WAIT = 26,
                MO_CAL_CKS_START = 27, MO_CAL_CKS_MID = 28, MO_CAL_CKS_WAIT = 29, MO_SET_CKS_START = 30, MO_SET_CKS_MID = 31, MO_SET_CKS_WAIT = 32,
                MO_END=62, MO_ERROR = 63;
                
    (* mark_debug = "true" *) reg [5:0] mo_state;
    reg [10:0] mo_index;
    reg [6:0] bit_index;
    reg [9:0] pkt_len_byte;
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            mo_state <= MO_IDLE;
            test_seq <= 0;
            pkt_type_flag <= 0;
            send_pkt_mo <= 0;
            res_seq <= 0;
            res_delta_t <= 0;
            ipic_start_mo <= 0;
//            bunch_write_data <= 0;
            blk_mem_sendpkt_we_mo <= 0;
            blk_mem_sendpkt_en_mo <= 0;
            blk_mem_slot_status_en_mo <= 0;
            bit_index <= 0;
            mo_index <= 0;
            send_req_done <= 0;
            send_ban_done <= 0;
        end else begin
            case (mo_state)
                MO_IDLE: begin
                    send_req_done <= 0;
                    send_fi_done <= 0;
                    send_adj_done <= 0;
                    send_ban_done <= 0;
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
                    else if (send_req_start) begin
                        bch_control_time_ns <= 0;
                        mo_state <= MO_SET_REQ_START;
                    end else if (send_fi_start) begin
                        bch_control_time_ns <= 0;
                        mo_state <= MO_SEND_FI;
                    end else if (send_adj_start) begin
                        mo_state <= MO_SET_ADJ_PKT_CONTENT_START;
                    end else if (send_ban_start) begin
                        mo_state <= MO_SET_BAN_PKT_CONTENT_START;
                    end
                end
                MO_SET_REQ_START: begin
                    pkt_type_flag <= `BCH_REQ;

                    write_data_mo[4:0] <= `BCH_REQ;
                    write_data_mo[12:5] <= global_sid;
                    write_data_mo[14:13] <= global_priority;
                    write_data_mo[22:15] <= bch_decide_req[7:0];  
                    write_data_mo[31:23] <= 0;

                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    
                    bch_control_time_ns <= REQ_PKT_TIME_NS;
                    mo_state <= MO_SET_REQ_PKT_CONTENT_MID;
                end
                
/*
                MO_SET_REQ_START: begin
                    pkt_type_flag <= `BCH_REQ;
                    blk_mem_sendpkt_en_mo <= 1; //enable accessing the sendpkt block memory.
                    blk_mem_sendpkt_we_mo <= 1;
                    blk_mem_slot_status_en_mo <= 1; //enable accessing the slot status block memory.
                    blk_mem_sendpkt_addr_mo <= 0;
                    slot_status_addr_mo <= 0;
                    blk_mem_sendpkt_din_mo[4:0] <= `BCH_REQ;
                    blk_mem_sendpkt_din_mo[12:5] <= global_sid;
                    blk_mem_sendpkt_din_mo[14:13] <= global_priority;
                    blk_mem_sendpkt_din_mo[22:15] <= bch_decide_req[7:0];  
                    mo_index <= 23;
                    bch_control_time_ns <= REQ_PKT_TIME_NS;
                    mo_state <= MO_SET_REQ_LOOP;
                end
                MO_SET_REQ_LOOP: begin
                    bit_index = mo_index % DATA_WIDTH;
                    if (bit_index == 0)
                        blk_mem_sendpkt_addr_mo = blk_mem_sendpkt_addr_mo + 1; // set write addr
                    if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 0)
                        blk_mem_sendpkt_din_mo[bit_index] = 0;
                    else
                        blk_mem_sendpkt_din_mo[bit_index] = 1;
                    mo_index = mo_index + 1;
                    slot_status_addr_mo = slot_status_addr_mo + 1; // next slot.
                    if (mo_index < (FRAME_SLOT_NUM + 23))
                        mo_state <= MO_SET_REQ_LOOP;
                    else begin
                        blk_mem_sendpkt_we_mo <= 0; 
                        mo_state <= MO_SET_REQ_PKT_CONTENT_START;
                    end
                end
                MO_SET_REQ_PKT_CONTENT_START: begin
                    blk_mem_sendpkt_en_mo <= 0;
                    blk_mem_slot_status_en_mo <= 0;      
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `BURST_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    write_length_mo <= (REQ_PKT_LEN + 4) & 14'h3FFC; // because FI_PKT_LEN is not 4 byte aligned !

                    mo_state = MO_SET_REQ_PKT_CONTENT_MID;
                end
*/
                MO_SET_REQ_PKT_CONTENT_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_SET_REQ_PKT_CONTENT_WAIT;                       
                    end
                MO_SET_REQ_PKT_CONTENT_WAIT: 
                    if (ipic_done_wire) begin
                        pkt_len_byte <= REQ_PKT_LEN;
                        mo_state <= MO_SET_BUF_LEN_START;
                    end                        

                
                //Content of FI has been constructed by FI_STATE_MACHINE.
                MO_SEND_FI: begin
                    send_pkt_mo <= 1;
                    send_fi_done <= 1;
                    bch_control_time_ns <= FI_PKT_TIME_NS;
                    mo_state <= MO_END;
                end

                MO_SET_ADJ_PKT_CONTENT_START: begin
                    pkt_type_flag <= `BCH_ADJ;

                    write_data_mo[4:0] <= `BCH_ADJ;
                    write_data_mo[12:5] <= global_sid;
                    write_data_mo[14:13] <= global_priority;
                    write_data_mo[22:15] <= bch_decide_adj[7:0];
                    write_data_mo[31:23] <= 0;
                    bch_control_time_ns <= bch_control_time_ns + ADJ_PKT_TIME_NS;  
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    mo_state = MO_SET_ADJ_PKT_CONTENT_MID;
                end
                MO_SET_ADJ_PKT_CONTENT_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_SET_ADJ_PKT_CONTENT_WAIT;                       
                    end
                MO_SET_ADJ_PKT_CONTENT_WAIT: 
                    if (ipic_done_wire) begin
                        pkt_len_byte <= ADJ_PKT_LEN;
                        mo_state <= MO_SET_BUF_LEN_START;
                    end                        

                MO_SET_BAN_PKT_CONTENT_START: begin
                    pkt_type_flag <= `BCH_BAN;

                    write_data_mo[4:0] <= `BCH_BAN;
                    write_data_mo[12:5] <= global_sid;
                    write_data_mo[14:13] <= global_priority;
                    write_data_mo[22:15] <= bch_work_pointer[7:0];
                    write_data_mo[31:23] <= 0;
                    bch_control_time_ns <= bch_control_time_ns + BAN_PKT_TIME_NS;  
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    mo_state = MO_SET_BAN_PKT_CONTENT_MID;
                end
                MO_SET_BAN_PKT_CONTENT_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_SET_BAN_PKT_CONTENT_WAIT;                       
                    end
                MO_SET_BAN_PKT_CONTENT_WAIT: 
                    if (ipic_done_wire) begin
                        pkt_len_byte <= BAN_PKT_LEN;
                        mo_state <= MO_SET_BUF_LEN_START;
                    end
                    
                    
                MO_SET_BUF_LEN_START: begin
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 12; //refer to ar9003_txc 
                    write_data_mo <= ((`PAYLOAD_OFFSET + pkt_len_byte + 4) << 16) & 32'h0fff0000;
                    mo_state = MO_SET_BUF_LEN_MID;   
                end
                MO_SET_BUF_LEN_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_SET_BUF_LEN_WAIT;
                    end                 
                MO_SET_BUF_LEN_WAIT:
                    if (ipic_done_wire) begin
                        mo_state <= MO_SET_FRAME_LEN_START;
                    end 
                MO_SET_FRAME_LEN_START: begin
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 44; //refer to ar9003_txc 
                    write_data_mo <= ((`PAYLOAD_OFFSET + pkt_len_byte + 4 + 4) & 32'h00000fff) | 32'h13f0000;
                    mo_state = MO_SET_FRAME_LEN_MID;
                end
                MO_SET_FRAME_LEN_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_SET_FRAME_LEN_WAIT;
                    end           
                MO_SET_FRAME_LEN_WAIT:
                    if (ipic_done_wire) begin
                        mo_state <= MO_CAL_CKS_START;
                    end
                MO_CAL_CKS_START: begin
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `CAL_DESC_CKS;
                    read_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0];
                    mo_state <= MO_CAL_CKS_MID;
                end
                MO_CAL_CKS_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0; 
                        mo_state <= MO_CAL_CKS_WAIT;
                    end
                
                MO_CAL_CKS_WAIT: 
                    if (ipic_done_wire) 
                        mo_state <= MO_SET_CKS_START;
                
                MO_SET_CKS_START: begin
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `SINGLE_WR;
                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 40; //refer to ar9003_txc 
                    write_data_mo <= ptr_checksum;
                    mo_state = MO_SET_CKS_MID;
                end
                MO_SET_CKS_MID: 
                    if (ipic_ack_mo) begin
                        ipic_start_mo <= 0;
                        mo_state = MO_SET_CKS_WAIT;
                    end
                MO_SET_CKS_WAIT: 
                    if (ipic_done_wire) begin
                        send_pkt_mo <= 1;
                        send_req_done <= 1;
                        send_fi_done <= 1;
                        send_adj_done <= 1;
                        send_ban_done <= 1;
                        mo_state = MO_END;
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
                        send_pkt_mo <= 0;
                    end
                end
                MO_SETPKT_START: begin //open_loop &&
                    // flag(32bit), test_seq (32bit), utc_sec(32bit), gps_counter2(32bit)
                    blk_mem_sendpkt_en_mo <= 1;
                    blk_mem_sendpkt_we_mo <= 1;
                    blk_mem_sendpkt_addr_mo <= 0;
                    blk_mem_sendpkt_din_mo <= pkt_type_flag[4:0];
//                    bunch_write_data[127:0] <= {pkt_counter2[31:0], pkt_sec[31:0],test_seq[31:0], 27'b0, pkt_type_flag[4:0] };// 32'h66666666, 32'h55555555, 32'h44444444
                    mo_state <= MO_SETPKT_WR_SEQ;
                end
                MO_SETPKT_WR_SEQ: begin
                    blk_mem_sendpkt_addr_mo <= 1;
                    blk_mem_sendpkt_din_mo <= test_seq[31:0];
                    mo_state <= MO_SETPKT_WR_SEC;
                end
                MO_SETPKT_WR_SEC: begin
                    blk_mem_sendpkt_addr_mo <= 2;
                    blk_mem_sendpkt_din_mo <= pkt_sec[31:0];
                    mo_state <= MO_SETPKT_WR_COUNTER2;
                end  
                MO_SETPKT_WR_COUNTER2: begin
                    blk_mem_sendpkt_addr_mo <= 3;
                    blk_mem_sendpkt_din_mo <= pkt_counter2[31:0];
                    
                    ipic_start_mo <= 1;
                    ipic_type_mo <= `BURST_WR;
                    write_addr_mo <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    write_length_mo <= 16;
                    mo_state <= MO_SETPKT_MID;
                end                               
                MO_SETPKT_MID: begin
                    blk_mem_sendpkt_en_mo <= 0;
                    blk_mem_sendpkt_we_mo <= 0;
                    if (ipic_ack_mo) begin
                        mo_state <= MO_SETPKT_WAIT;
                        ipic_start_mo <= 0; 
                    end
                end
                MO_SETPKT_WAIT:
                    if (ipic_done_wire) begin
                        mo_state <= MO_END;
                        send_pkt_mo <= 1;
                    end
                MO_END: begin
                    send_pkt_mo <= 0;
                    mo_state <= MO_IDLE;
                end
            endcase
        end
    end
    

endmodule