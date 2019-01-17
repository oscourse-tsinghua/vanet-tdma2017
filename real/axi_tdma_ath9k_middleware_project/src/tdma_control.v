(* DONT_TOUCH = "yes" *)
module tdma_control # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer C_LENGTH_WIDTH = 14,
    parameter integer FRAME_SLOT_NUM_DEFAULT = 64,
    parameter integer SLOT_US = 1000,
    parameter integer TX_GUARD_NS = 70000, // 70 us
    parameter integer TIME_PER_BYTE_12M_NS = 700, // 700 ns per byte under 12 Mbps
    parameter integer OCCUPIER_LIFE_FRAME = 3
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
    input wire tdma_function_enable,   
    input wire [DATA_WIDTH/2 -1:0] bch_user_pointer,
    output reg [9:0] slot_pulse2_counter,
    output reg tdma_tx_enable,
    output reg [31:0] bch_control_time_ns,
    output reg [9:0] curr_frame_len,
    input wire [7:0] default_frame_len_user,
    input wire frame_adj_ena,
    input wire slot_adj_ena,
    input wire [8:0] adj_frame_lower_bound,
    input wire [8:0] adj_frame_upper_bound,
    input wire [8:0] input_random,
    input wire frame_len_exp_dp,
    input wire randon_bch_if_single,
    
    output reg [31:0] frame_count,
    output reg [31:0] fi_send_count,
    output reg [15:0] no_avail_count,
    output reg [15:0] request_fail_count,
    output reg [15:0] collision_count,
    
    output reg [DATA_WIDTH/2 -1:0] bch_slot_pointer
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
//    localparam STATUS_NOTHING = 0, STATUS_DECIDE_REQ = 1, STATUS_REQ = 2, STATUS_FI = 3, STATUS_DECIDE_ADJ = 4, STATUS_ADJ = 5;
    localparam BUSY_LSB = 5, BUSY_MSB = 6;
    localparam OCCUPIER_SID_LSB = 7, OCCUPIER_SID_MSB = 14;
    localparam COUNT_2HOP_LSB = 15, COUNT_2HOP_MSB = 22;
    localparam COUNT_3HOP_LSB = 23, COUNT_3HOP_MSB = 31;
    localparam PSF_LSB = 32, PSF_MSB = 33;
    localparam LIFE_LSB = 34, LIFE_MSB = 43;
    localparam C3HOP_N = 44;
    localparam LOCKER = 45;
    localparam EXISTED = 46;
    
    localparam FI_PER_SLOT_BITSNUM = 14;
    
//    localparam FI_PKT_LEN = ((FRAME_SLOT_NUM >> 1) * 5 + 2); // FRAME_SLOT_NUM * 20 bits / 8 + 2
//    localparam FI_PKT_TIME_NS = TIME_PER_BYTE_12M_NS * (FI_PKT_LEN + 4) + TX_GUARD_NS; //4 bytes FCS.
    
    /*************************
    * FI Packet:
    * frame_len: 0~3
    * sender_sid: 4~11
    * status per slot: 12~
    *   busy1/2:        0~1
    *   slot-occupier:  2~9   
    *   count:          10~11
    *   psf:            12~13
    **************************/
    localparam PKT_FRAMELEN_MSB = 3, PKT_FRAMELEN_LSB = 0;
    localparam FI_SENDER_SID_MSB = 11, FI_SENDER_SID_LSB = 4;
    localparam FI_S_PERSLOT_BUSY_MSB = 1, FI_S_PERSLOT_BUSY_LSB = 0;
    localparam FI_S_PERSLOT_OCCUPIER_SID_MSB = 9, FI_S_PERSLOT_OCCUPIER_SID_LSB = 2;
    localparam FI_S_PERSLOT_COUNT_MSB = 11, FI_S_PERSLOT_COUNT_LSB = 10;
    localparam FI_S_PERSLOT_PSF_MSB = 13, FI_S_PERSLOT_PSF_LSB = 12;

    reg is_single_flag;
    /////////////////////////////////////////////////////////////
    // GPS TimePulse Logic
    /////////////////////////////////////////////////////////////
    // 1. TimePulse_1 pulses per 1 UTC-Sec. This is for the UTC time,
    // UTC time can be readed from a specific register after a pulse.
    // 2. We count TimePulse_2 to maintain an accurate and sync time.
    // The 32bit-counter clears every 1 UTC-sec.
    // 3. slot_counter_1sec counts every slot in a UTC-sec, 
    // clears every 1 UTC-sec.
    /////////////////////////////////////////////////////////////
    `define MAX_COUNTER2 32'hf423f
    
    reg [31:0] pulse1_counter;
    reg [31:0] pulse2_counter;
    (* mark_debug = "true" *) reg [10:0] slot_counter_1sec;
    reg [31:0] curr_pulse1_counter;
    reg [31:0] curr_utc_sec;
    assign gps_pulse1_counter[31:0] = pulse1_counter[31:0];
    assign gps_pulse2_counter[31:0] = pulse2_counter[31:0];
    
    reg [4:0] curr_frame_len_log2;
    
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
            slot_counter_1sec <= 0;
        end else begin
            if (pulse1_counter[31:0] != curr_pulse1_counter2[31:0]) begin
                curr_pulse1_counter2[31:0] <= pulse1_counter[31:0];
                slot_pointer <= 0;
                slot_pulse2_counter <= 0;
                slot_counter_1sec <= 0;
            end else begin
                if (slot_pulse2_counter == (SLOT_US - 1)) begin // 1ms
                    slot_pulse2_counter <= 0;
                    slot_counter_1sec = slot_counter_1sec + 1;
                    slot_pointer = slot_counter_1sec & ((1 << curr_frame_len_log2) - 1);
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
    
    wire [15:0] fifo_fcb_dread_half;
    reg fifo_fcb_wr_en_half;
    reg fifo_fcb_rd_en_half;
    wire fifo_fcb_wr_ack_half;
    wire fifo_fcb_full_half;
    wire fifo_fcb_empty_half;
    wire fifo_fcb_valid_half;
    wire [7:0] fifo_fcb_data_count_half;
    fifo_16bits_128dept fifo_fcb_candidates_half_inst (
        .clk(clk),
        .srst(fifo_fcb_srst),
        .din(fifo_fcb_dwrite),              
        .wr_en(fifo_fcb_wr_en_half),            
        .rd_en(fifo_fcb_rd_en_half),            
        .dout(fifo_fcb_dread_half),              
        .full(fifo_fcb_full_half),            
        .wr_ack(fifo_fcb_wr_ack_half),         
        .empty(fifo_fcb_empty_half),           
        .valid(fifo_fcb_valid_half),
        .data_count(fifo_fcb_data_count_half)
    );

    reg blk_mem_sendpkt_en_mo;
//    reg blk_mem_sendpkt_en_fi;
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

    reg [15:0] fcb_bch_candidate;
    reg [8:0] fcb_ran_idx;

    (* mark_debug = "true" *) reg frmae_len_need_slotadj;
    (* mark_debug = "true" *) reg frmae_len_need_expand;
    (* mark_debug = "true" *) reg frmae_len_need_halve;
    (* mark_debug = "true" *) reg slot_need_adj;
    (* mark_debug = "true" *) reg adj_slot_win;
    (* mark_debug = "true" *) reg frame_half_empty;
    
    reg blk_mem_slot_status_en_mo;
    reg blk_mem_slot_status_en_fi;
    reg [6:0] slot_status_addr_mo;
    reg [6:0] slot_status_addr_fi;
    reg [6:0] slot_status_addr_bch;
    reg [63:0] slot_status_din_fi;
    reg [63:0] slot_status_din_bch;
    reg [63:0] slot_status_din_fcb;
    (* mark_debug = "true" *) reg slot_status_we_fi;
    (* mark_debug = "true" *) reg slot_status_we_bch;
    reg slot_status_we_fcb;
    
    /////////////////////////////////////////////////////////////
    // Logic for accessing blk_mem_slot_status
    /////////////////////////////////////////////////////////////
    always @ ( * ) //Only one of the enabling signals will be set at same time.
    begin
        if (fcb_inprogress) begin
            blk_mem_slot_status_addr = slot_status_addr_fcb;
            blk_mem_slot_status_din = slot_status_din_fcb; 
            blk_mem_slot_status_we = slot_status_we_fcb;
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

    // T 0.4 E 0.6
    reg [8:0] free_ths_count;
    reg [8:0] free_ehs_count;
    reg [8:0] thres_cut_free_ths;
    reg [8:0] thres_cut_free_ehs;
    reg [8:0] thres_exp_free_ths;
    reg [8:0] thres_exp_free_ehs;
    reg [8:0] thres_slot_adj;
    
    always @ (*)
    begin
        case (curr_frame_len)
            4: begin
                curr_frame_len_log2 = 2;
                thres_cut_free_ths = 2;
                thres_cut_free_ehs = 2;
                thres_exp_free_ths = 0;
                thres_exp_free_ehs = 0;
                thres_slot_adj = 1;
            end
            8: begin
                curr_frame_len_log2 = 3;
                thres_cut_free_ths = 4; 
                thres_cut_free_ehs = 5; 
                thres_exp_free_ths = 1;
                thres_exp_free_ehs = 2;
                thres_slot_adj = 1;
            end
            16: begin
                curr_frame_len_log2 = 4;
                thres_cut_free_ths = 12; //40% full
                thres_cut_free_ehs = 10;
                thres_exp_free_ths = 2;
                thres_exp_free_ehs = 3;
                thres_slot_adj = 2;
            end
            32: begin
                curr_frame_len_log2 = 5;
                thres_cut_free_ths = 19;
                thres_cut_free_ehs = 12;
                thres_exp_free_ths = 3;
                thres_exp_free_ehs = 4;
                thres_slot_adj = 3;
            end
            64: begin
                curr_frame_len_log2 = 6;
                thres_cut_free_ths = 38;
                thres_cut_free_ehs = 25;
                thres_exp_free_ths = 4;
                thres_exp_free_ehs = 5;
                thres_slot_adj = 4;
            end
            128: begin
                curr_frame_len_log2 = 7;
                thres_cut_free_ths = 76;
                thres_cut_free_ehs = 51;
                thres_exp_free_ths = 12;
                thres_exp_free_ehs = 13;
                thres_slot_adj = 5;
            end
                        
            default: begin
                curr_frame_len_log2 = 0;
                thres_cut_free_ths = 0;
                thres_cut_free_ehs = 0;
                thres_exp_free_ths = 0;
                thres_exp_free_ehs = 0;
                thres_slot_adj = 0;
            end
        endcase
    end
    
    reg frame_len_exp_bch;
    reg frame_len_cut_bch;
    /////////////////////////////////////////////////////////////
    // FRAME_LEN adjustment logic
    /////////////////////////////////////////////////////////////
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            curr_frame_len <= FRAME_SLOT_NUM_DEFAULT;
        end else begin
            if (tdma_function_enable && frame_adj_ena) begin
                if (frame_len_exp_bch || frame_len_exp_dp)
                    curr_frame_len <= (curr_frame_len << 1);
                else if (frame_len_cut_bch)
                    curr_frame_len <= (curr_frame_len >> 1);
            end else begin
                if (default_frame_len_user != 0 )
                    curr_frame_len <= default_frame_len_user;
            end
        end
    end
    
    /////////////////////////////////////////////////////////////
    // BCH accessing state machine
    /////////////////////////////////////////////////////////////
    parameter BCH_IDLE = 0,
            BCH_LIS_DECIDE_REQ = 1, BCH_LIS_WAIT_NEXT_SLOT = 2, BCH_LIS_WAIT_NEXT_SLOT_2 = 3, BCH_LIS_WAIT_NEXT_FRAME = 4, 
            BCH_LIS_FCB = 5, 
            BCH_WAIT_REQ_FI_INIT_START = 6, BCH_WAIT_REQ_FI_INIT_WAIT = 7,
            BCH_WAIT_REQ_WAIT = 8, BCH_WAIT_REQ_FI_SEND_START = 9, BCH_WAIT_REQ_FI_SEND_WAIT = 10, BCH_WAIT_REQ_FI_SEND_DONE = 11,
            BCH_REQ_FAIL_COUNT = 39, BCH_COL_COUNT = 40,
            BCH_WAIT_REQ_FCB_PRE = 12, BCH_WAIT_REQ_FCB_PRE_WAIT = 33, BCH_WAIT_REQ_FCB_START = 13, BCH_WAIT_REQ_FCB_DONE = 14, BCH_WAIT_REQ_FCB_SET_STATUS = 15,
            BCH_REQ_WAIT = 16, BCH_WORK_FI_WAIT = 17, BCH_WORK_FI_ADJ_FRAMELEN = 18, 
            BCH_IF_SINGLE = 34, BCH_IF_SINGLE_SET_1 = 35, BCH_IF_SINGLE_SET_2 = 36, BCH_IF_SINGLE_RESET = 38,
            BCH_WORK_FI_SEND_FI_START = 20,  BCH_WORK_FI_SEND_FI_WAIT = 21,
            BCH_WORK_FI_FCB = 22, BCH_WORK_ENA_TX = 23, BCH_WORK_DISA_TX = 24, 
            BCH_WORK_ADJ_WAIT = 25, BCH_WORK_ADJ_SEND_FI_START = 26, BCH_WORK_ADJ_SEND_FI_WAIT = 27,            
            BCH_WORK_ADJ_SET_STATUS = 28,            
            BCH_WORK_ADJ_BCH_INVALID = 29, BCH_WORK_ADJ_BCH_INVALID_WAIT = 37, BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID = 30, 
            BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID = 31, BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID = 32,// BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID = 33, 
            BCH_FCB_FAIL_COUNT = 61, BCH_END = 62, BCH_ERROR = 63;
    
    (* mark_debug = "true" *) reg [5:0] curr_bch_state;
    reg [5:0] next_bch_state;

    reg init_fi_start;
    reg init_fi_done;
    reg send_fi_start;
    reg send_fi_done;
    
    reg bch_adj_flag;
    reg [2:0] bch_single_lock;

//    (* mark_debug = "true" *) reg [DATA_WIDTH/2 -1:0] bch_decide_req;
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
            //set fi_init.
            BCH_LIS_DECIDE_REQ: next_bch_state = BCH_LIS_WAIT_NEXT_SLOT;
            
            BCH_LIS_WAIT_NEXT_SLOT:
                if (bch_work_pointer != (((slot_pointer + 1) == curr_frame_len) ? 0 : (slot_pointer + 1)))
//                if (bch_decide_req != (slot_pointer + 1) % FRAME_SLOT_NUM) //we need to wait for the next slot (as BCH_LIS_DECIDE_REQ has set bch_decide_req to its current slot_pointer + 1).
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT_2;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT;
            BCH_LIS_WAIT_NEXT_SLOT_2:
                if (bch_work_pointer != slot_pointer)  // wait another slot.
                    next_bch_state = BCH_LIS_WAIT_NEXT_FRAME;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_SLOT_2;
            BCH_LIS_WAIT_NEXT_FRAME:
                if (bch_work_pointer == slot_pointer) //Wait one frmae.
                    next_bch_state = BCH_LIS_FCB;
                else
                    next_bch_state = BCH_LIS_WAIT_NEXT_FRAME;
            BCH_LIS_FCB: //set bch_work_pointer, set slot_status_addr_bch and status (decide_req) in the blk_mem accordingly
                if (fcb_fail)
                    next_bch_state = BCH_FCB_FAIL_COUNT;
                else
                    next_bch_state = BCH_WAIT_REQ_FI_INIT_START;
                    
            // 1. set bch_work_pointer�� set slot_status_addr_bch and status in the blk_mem accordingly
            // 2. notify FI_state_machine to initial FI pkt for the first time.
            BCH_WAIT_REQ_FI_INIT_START: next_bch_state = BCH_WAIT_REQ_FI_INIT_WAIT;
            BCH_WAIT_REQ_FI_INIT_WAIT: 
                if (init_fi_done)
                    next_bch_state = BCH_WAIT_REQ_WAIT;
                else
                    next_bch_state = BCH_WAIT_REQ_FI_INIT_WAIT;
            BCH_WAIT_REQ_WAIT: //set slot status (bch_work_pointer) in the blk_mem accordingly
                if (slot_pointer == bch_work_pointer) begin//wait until bch_work_pointer slot.
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] 
                            && blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10)
                        || 0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) // address has been set in BCH_LIS_FCB_DONE
                        next_bch_state = BCH_WAIT_REQ_FI_SEND_START;
                    else
                        next_bch_state = BCH_REQ_FAIL_COUNT;
                end else
                    next_bch_state = BCH_WAIT_REQ_WAIT;
            BCH_WAIT_REQ_FI_SEND_START: next_bch_state = BCH_WAIT_REQ_FI_SEND_WAIT; //Construct REQ and send it.
            BCH_WAIT_REQ_FI_SEND_WAIT:
                if (send_fi_done)
                    next_bch_state = BCH_WAIT_REQ_FI_SEND_DONE;
                else
                    next_bch_state = BCH_WAIT_REQ_FI_SEND_WAIT;            
            BCH_WAIT_REQ_FI_SEND_DONE: 
                if (slot_pointer != bch_work_pointer) //wait for the next slot.
                    next_bch_state = BCH_REQ_WAIT;
                else
                    next_bch_state = BCH_WAIT_REQ_FI_SEND_DONE;
            BCH_REQ_FAIL_COUNT: next_bch_state = BCH_WAIT_REQ_FCB_PRE;
            BCH_COL_COUNT: next_bch_state = BCH_WAIT_REQ_FCB_PRE;
            //the decide_req slot (and bch_work_pointer) is unusable, we should reset the status of this slot, and re-run the FCB process.
            BCH_WAIT_REQ_FCB_PRE: next_bch_state = BCH_WAIT_REQ_FCB_PRE_WAIT;
            BCH_WAIT_REQ_FCB_PRE_WAIT: next_bch_state = BCH_WAIT_REQ_FCB_START;
            BCH_WAIT_REQ_FCB_START: next_bch_state = BCH_WAIT_REQ_FCB_DONE; 
            //1. set bch_work_pointer, set slot_status_addr_bch.
            //2. status (decide_req) will be set in BCH_WAIT_REQ_SEND_START                    
            BCH_WAIT_REQ_FCB_DONE: 
                if (fcb_fail)
                    next_bch_state = BCH_FCB_FAIL_COUNT;
                else
                    next_bch_state = BCH_WAIT_REQ_WAIT;
            BCH_REQ_WAIT:
                if (slot_pointer == bch_work_pointer)
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] 
                            && blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10)
                        || 0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) // address has been set in BCH_REQ_WAIT
                        next_bch_state = BCH_WORK_FI_WAIT;
                    else
                        next_bch_state = BCH_REQ_FAIL_COUNT;  
                else
                    next_bch_state = BCH_REQ_WAIT;

            //��BCH_REQ_WAIT�����Ժ���Ҫ�ٵ�һ��֡
            //set slot_status_addr_bch
            BCH_WORK_FI_WAIT: 
                if (slot_pointer == bch_work_pointer)
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] 
                            && blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10)
                        || 0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) // address has been set in BCH_WORK_FI_INIT_START and BCH_WORK_FI_WAIT
                    begin
                        if (!fcb_fail && (slot_need_adj == 1 || frmae_len_need_slotadj == 1))
                            next_bch_state = BCH_WORK_FI_FCB;
                        else                      
                            next_bch_state = BCH_WORK_FI_ADJ_FRAMELEN;
                    end else
                        next_bch_state = BCH_COL_COUNT;
                else
                    next_bch_state = BCH_WORK_FI_WAIT;
            BCH_WORK_FI_FCB: next_bch_state = BCH_IF_SINGLE;
            BCH_WORK_FI_ADJ_FRAMELEN: next_bch_state = BCH_IF_SINGLE;
            BCH_IF_SINGLE:
                if (randon_bch_if_single && is_single_flag)
                    if (bch_single_lock == 0)
                        next_bch_state = BCH_IF_SINGLE_SET_1;
                    else
                        next_bch_state = BCH_WORK_FI_SEND_FI_START;
                else
                    next_bch_state = BCH_IF_SINGLE_RESET;
                
            BCH_IF_SINGLE_SET_1: next_bch_state = BCH_IF_SINGLE_SET_2;
            BCH_IF_SINGLE_SET_2: next_bch_state = BCH_WORK_FI_SEND_FI_START;
            BCH_IF_SINGLE_RESET: next_bch_state = BCH_WORK_FI_SEND_FI_START;
            BCH_WORK_FI_SEND_FI_START: next_bch_state = BCH_WORK_FI_SEND_FI_WAIT;
            BCH_WORK_FI_SEND_FI_WAIT:
                if (send_fi_done)
                    next_bch_state = BCH_WORK_ENA_TX;
                else
                    next_bch_state = BCH_WORK_FI_SEND_FI_WAIT;
                  
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
                    if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] 
                            && blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10)
                        || 0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) // address has been set in BCH_WORK_ADJ_WAIT
                        next_bch_state = BCH_WORK_ADJ_SET_STATUS;
                    else
                        next_bch_state = BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID;
                else
                    next_bch_state = BCH_WORK_ADJ_WAIT;
            BCH_WORK_ADJ_SET_STATUS: next_bch_state = BCH_WORK_ADJ_SEND_FI_START;
            BCH_WORK_ADJ_SEND_FI_START: next_bch_state = BCH_WORK_ADJ_SEND_FI_WAIT;
            BCH_WORK_ADJ_SEND_FI_WAIT:
                if (send_fi_done)
                    next_bch_state = BCH_WORK_ENA_TX;
                else
                    next_bch_state = BCH_WORK_ADJ_SEND_FI_WAIT;
                    
                   
            //set slot_status_addr_bch to bch_decide_adj
            BCH_WORK_ADJ_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_BCH_INVALID_WAIT;
            BCH_WORK_ADJ_BCH_INVALID_WAIT: next_bch_state = BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID;
            BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID: 
                if ((global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] 
                        && blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10)
                    || 0 == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB]) // address has been set in BCH_WORK_ADJ_BCH_INVALID
                    next_bch_state = BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID;
                else
                    next_bch_state = BCH_COL_COUNT; 
            // 1. set bch_work_pointer to bch_decide_adj
            // 2. set set old bch status to free; set new bch status)
            // * Here we just forgive the empty Counts because we just empty it befor the old bch.
            BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID: next_bch_state = BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID;
            // 3. set new bch status
            BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID: next_bch_state = BCH_WORK_FI_WAIT;
            // 4. reset slot_status_addr_bch to new bch.
//            BCH_WORK_ADJ_SET_BCH_3_BCH_INVALID: next_bch_state = BCH_WORK_FI_WAIT;
            
            BCH_FCB_FAIL_COUNT: next_bch_state = BCH_IDLE;
            default: next_bch_state = BCH_ERROR;
        endcase
    end

    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            slot_status_we_bch <= 0;
            slot_status_din_bch[63:0] <= 0;
            init_fi_start <= 0;
            send_fi_start <= 0;
            bch_adj_flag <= 0;
            bch_accessible_flag <= 0;
            bch_single_lock <= 5;                   
            no_avail_count <= 0;
            request_fail_count <= 0;
            collision_count <= 0;
        end else begin
            case (next_bch_state)
//                BCH_IDLE:
                BCH_LIS_DECIDE_REQ: begin
                    init_fi_start <= 1;
                    bch_work_pointer <= (((slot_pointer + 1) == curr_frame_len) ? 0 : (slot_pointer + 1));
                end
                BCH_LIS_WAIT_NEXT_SLOT:
                    init_fi_start <= 0;
//                BCH_LIS_WAIT:
                BCH_LIS_FCB: begin//set bch_work_pointer, set slot_status_addr_bch 
                    bch_work_pointer <= fcb_bch_candidate;
                end
                BCH_WAIT_REQ_FI_INIT_START: begin
                    slot_status_we_bch <= 1;
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 2'b10;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= global_sid;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= global_priority;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1; //the count-2hop of bch should always be 1 untill collision happens.
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                    slot_status_din_bch[C3HOP_N] <= 0;
                    slot_status_din_bch[LOCKER] <= 0;
                    init_fi_start <= 1;
                end
                BCH_WAIT_REQ_FI_INIT_WAIT: begin
                    init_fi_start <= 0;
                    slot_status_we_bch <= 0;
                end      
//                BCH_WAIT_REQ_WAIT: slot_status_we_bch <= 0;
                // 1. set slot status (decide_req) in the blk_mem accordingly
                // 2. Construct REQ and send it.
                BCH_WAIT_REQ_FI_SEND_START: begin
                    send_fi_start <= 1;
                end
                BCH_WAIT_REQ_FI_SEND_WAIT: send_fi_start <= 0;    
//                BCH_WAIT_REQ_FI_SEND_DONE: 
                BCH_REQ_FAIL_COUNT: request_fail_count <= request_fail_count + 1;
                BCH_COL_COUNT: collision_count <= collision_count + 1;
                //the decide_req slot (and bch_work_pointer) is unusable, we should reset the status of this slot, and re-run the FCB process.
                BCH_WAIT_REQ_FCB_PRE: slot_status_addr_bch <= bch_work_pointer;
                //BCH_WAIT_REQ_FCB_PRE_WAIT: 
                BCH_WAIT_REQ_FCB_START: begin
                    if ( global_sid == blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] ) begin
                        slot_status_we_bch <= 1;
                        slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 0;
                        slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                        slot_status_din_bch[PSF_MSB : PSF_LSB] <= 0;
                        slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0; 
                        slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                        slot_status_din_bch[C3HOP_N] <= 0;
                        slot_status_din_bch[LOCKER] <= 1;
                    end
                end
                //1. set bch_work_pointer, set slot_status_addr_bch.
                //2. status (decide_req) will be set in BCH_WAIT_REQ_SEND_START
                BCH_WAIT_REQ_FCB_DONE: begin
                    
                    if (!fcb_fail) begin
                        bch_work_pointer <= fcb_bch_candidate;
                        slot_status_addr_bch <= fcb_bch_candidate;         
                        slot_status_we_bch <= 1;
                        slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 2'b10;
                        slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= global_sid;
                        slot_status_din_bch[PSF_MSB : PSF_LSB] <= global_priority;
                        slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1; //the count-2hop of bch should always be 1 untill collision happens.
                        slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                        slot_status_din_bch[C3HOP_N] <= 0;
                        slot_status_din_bch[LOCKER] <= 0;
                    end else 
                        slot_status_we_bch <= 0;
                end
                BCH_REQ_WAIT: slot_status_we_bch <= 0;

                //��BCH_REQ_WAIT�����Ժ���Ҫ�ٵ�һ��֡
                //set slot_status_addr_bch
                BCH_WORK_FI_WAIT: begin
                    slot_status_addr_bch <= bch_work_pointer;
                end
                BCH_WORK_FI_FCB: begin
                    bch_decide_adj <= fcb_bch_candidate;
                    slot_status_addr_bch <= fcb_bch_candidate;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 2'b10;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= global_sid;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= global_priority;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1; 
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                    slot_status_din_bch[LOCKER] <= 0;
                    slot_status_din_bch[C3HOP_N] <= 0;
                    slot_status_we_bch <= 1;
                    bch_adj_flag <= 1;
                end
                BCH_WORK_FI_ADJ_FRAMELEN: begin
//                    if (frmae_len_need_halve) begin
//                        bch_work_pointer <= (bch_work_pointer < (curr_frame_len >> 1)) ? bch_work_pointer : (bch_work_pointer - (curr_frame_len >> 1));
//                    end else if (frmae_len_need_expand) begin
                    
//                    end
                        
                end
                BCH_IF_SINGLE: bch_single_lock <= bch_single_lock - 1;
                BCH_IF_SINGLE_SET_1: begin
                    slot_status_we_bch <= 1;
                    
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 0;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= 0;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0; 
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                    slot_status_din_bch[C3HOP_N] <= 0;
                    slot_status_din_bch[LOCKER] <= 1;

                    bch_single_lock <= 5;
                end
                BCH_IF_SINGLE_SET_2: begin
                    bch_work_pointer <= fcb_bch_candidate;
                    
                    slot_status_addr_bch <= fcb_bch_candidate;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 2'b10;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= global_sid;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= global_priority;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1; 
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;
                    slot_status_din_bch[LOCKER] <= 0;
                    slot_status_din_bch[C3HOP_N] <= 0;
                    
                end
                BCH_IF_SINGLE_RESET: bch_single_lock <= 5;
                BCH_WORK_FI_SEND_FI_START: begin
                    slot_status_we_bch <= 0;
                    send_fi_start <= 1;
                end
                BCH_WORK_FI_SEND_FI_WAIT: send_fi_start <= 0;                
                //enable bch_accessible_flag in the bch slot.
                BCH_WORK_ENA_TX: bch_accessible_flag <= 1;

                //disable bch_accessible_flag
                BCH_WORK_DISA_TX: bch_accessible_flag <= 0;
                BCH_WORK_ADJ_WAIT: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    bch_adj_flag <= 0;
                end
                BCH_WORK_ADJ_SET_STATUS: begin
                    if (adj_slot_win) begin
                        bch_work_pointer <= bch_decide_adj;
                        
                        slot_status_addr_bch <= bch_work_pointer;
                        slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 0;
                        slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                        slot_status_din_bch[PSF_MSB : PSF_LSB] <= 0;
                        slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0; 
                        slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                        slot_status_din_bch[C3HOP_N] <= 0;
                        slot_status_din_bch[LOCKER] <= 1;
                        
                        slot_status_we_bch <= 1;
                    end else begin
                        bch_work_pointer <= bch_work_pointer;
                        
                        slot_status_addr_bch <= bch_decide_adj;
                        slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 0;
                        slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                        slot_status_din_bch[PSF_MSB : PSF_LSB] <= 0;
                        slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0; 
                        slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                        slot_status_din_bch[C3HOP_N] <= 0;
                        slot_status_din_bch[LOCKER] <= 1;
                        
                        slot_status_we_bch <= 1;
                    end
                end
                BCH_WORK_ADJ_SEND_FI_START: begin
                    slot_status_we_bch <= 0;
                    
                    send_fi_start <= 1;
                end
                BCH_WORK_ADJ_SEND_FI_WAIT: send_fi_start <= 0;

                //set slot_status_addr_bch to bch_decide_adj
                BCH_WORK_ADJ_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_decide_adj;
                end
                //BCH_WORK_ADJ_BCH_INVALID_WAIT
//                BCH_WORK_ADJ_DECIDE_ADJ_BCH_INVALID: 

                // 1. set bch_work_pointer to bch_decide_adj
                // 2. set set old bch status to free; 
                // * Here we just forgive the empty Counts because we just empty it befor the old bch.
                BCH_WORK_ADJ_SET_BCH_1_BCH_INVALID: begin
                    slot_status_addr_bch <= bch_work_pointer;
                    slot_status_we_bch <= 1;
                    slot_status_din_bch[BUSY_MSB : BUSY_LSB] <= 0;
                    slot_status_din_bch[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                    slot_status_din_bch[PSF_MSB : PSF_LSB] <= 0;
                    slot_status_din_bch[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0; 
                    slot_status_din_bch[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                    slot_status_din_bch[C3HOP_N] <= 0;
                    slot_status_din_bch[LOCKER] <= 1;
                    
                    bch_work_pointer <= bch_decide_adj;
                end
                BCH_WORK_ADJ_SET_BCH_2_BCH_INVALID: slot_status_we_bch <= 0;
                
                BCH_FCB_FAIL_COUNT: no_avail_count <= no_avail_count + 1;
                default: begin end
            endcase
        end
    end


    /////////////////////////////////////////////////////////////
    // State machine for finding a candidate BCH (fcb)
    /////////////////////////////////////////////////////////////
    parameter FCB_IDLE = 0, FCB_START = 1, FCB_RD_LOOP = 2, FCB_CLR_C3H = 8, FCB_CLR_SETADDR = 9, FCB_CLR_SETADDR_WAIT = 11, FCB_RD_LOOP_2 = 3, 
                FCB_SEL_RAN_START = 4, FCB_SEL_RAN_WAIT_1 = 5, FCB_SEL_RAN_WAIT_2 = 6,
                FCB_DONE = 7, FCB_DONE2 = 10;
    
    (* mark_debug = "true" *) reg [3:0] fcb_state;
    reg [7:0] fifo_fcb_data_count_s1_tmp;
    
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
            fifo_fcb_rd_en_s2 <= 0;
            fifo_fcb_wr_en_half <= 0;
            fifo_fcb_rd_en_half <= 0;
            fcb_bch_candidate <= 16'hffff;
            divider_enable <= 0;
            fifo_fcb_srst <= 0;
            fcb_ran_idx <= 0;
            fifo_fcb_dwrite <= 0;
            slot_status_we_fcb <= 0;
        end else begin
            case (fcb_state)
                FCB_IDLE: begin
                    fcb_done <= 0;
                    if (fcb_start) begin
                        fcb_inprogress <= 1;                        
                        slot_status_we_fcb <= 0;
                        slot_status_addr_fcb <= 0;
                        fcb_fail <= 0;
                        fcb_bch_candidate <= 16'hffff;
                        fcb_state <= FCB_START;
                    end
                end
                FCB_START: fcb_state <= FCB_RD_LOOP;
                FCB_RD_LOOP: // pick up slots those count_3hop is less than the threshold. 
                    if (slot_status_addr_fcb == curr_frame_len) begin
                        fifo_fcb_wr_en_s1 <= 0;
                        fifo_fcb_wr_en_s2 <= 0;
                        fifo_fcb_wr_en_half <= 0;
                        fcb_ran_idx = input_random;
                        fifo_fcb_data_count_s1_tmp <= fifo_fcb_data_count_s1;
                        fcb_state <= FCB_SEL_RAN_START;
                    end else begin
                        fcb_state <= FCB_CLR_C3H;
                        if ( slot_adj_ena ) begin
                            if ((blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 0
                                    || ( !fcb_strict && (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] == global_sid)))
                                && blk_mem_slot_status_dout[LOCKER] == 0 )
                            begin
                                fifo_fcb_dwrite <= slot_status_addr_fcb; // three fifos share one write bus. 
                                fifo_fcb_wr_en_s2 <= 1;
                                if (blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] == 0) begin
                                    fifo_fcb_wr_en_s1 <= 1;
                                    if ( frame_adj_ena && frame_half_empty && slot_status_addr_fcb < (curr_frame_len >> 1))
                                        fifo_fcb_wr_en_half <= 1;
                                    else
                                        fifo_fcb_wr_en_half <= 0;
                                end else begin
                                    fifo_fcb_wr_en_s1 <= 0;
                                    fifo_fcb_wr_en_half <= 0;
                                end
                                

                            end else begin
                                fifo_fcb_wr_en_s1 <= 0;
                                fifo_fcb_wr_en_s2 <= 0;
                                fifo_fcb_wr_en_half <= 0;
                            end
                        end else begin
                            if ((blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 0
                                    || ( !fcb_strict && (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] == global_sid)))
                                && blk_mem_slot_status_dout[LOCKER] == 0 )
                            begin
                                fifo_fcb_dwrite <= slot_status_addr_fcb;  
                                fifo_fcb_wr_en_s1 <= 1;
                            end else
                                fifo_fcb_wr_en_s1 <= 0;
                        end
                    end
                FCB_CLR_C3H: begin
                    fcb_state <= FCB_CLR_SETADDR;
                    fifo_fcb_wr_en_s1 <= 0;
                    fifo_fcb_wr_en_s2 <= 0;
                    fifo_fcb_wr_en_half <= 0;
                    //Clear Count_2hop/3hop after we construct FI.
                    if (curr_bch_state > BCH_WAIT_REQ_FI_INIT_WAIT) begin
                        slot_status_we_fcb <= 1;
                        slot_status_din_fcb[COUNT_2HOP_LSB-1:0] <= blk_mem_slot_status_dout[COUNT_2HOP_LSB-1:0];
                        slot_status_din_fcb[63:COUNT_2HOP_MSB+1] <= blk_mem_slot_status_dout[63:COUNT_2HOP_MSB+1];
                        if (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] == global_sid) begin
                            slot_status_din_fcb[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 1;
                            slot_status_din_fcb[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 1;                    
                        end else begin
                            slot_status_din_fcb[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0;
                            slot_status_din_fcb[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                        end
                    end
                end
                FCB_CLR_SETADDR: begin
                    fcb_state <= FCB_CLR_SETADDR_WAIT;
                    slot_status_we_fcb <= 0;
                    slot_status_addr_fcb <= slot_status_addr_fcb + 1;
                end
                FCB_CLR_SETADDR_WAIT: fcb_state <= FCB_RD_LOOP;
                FCB_SEL_RAN_START: begin// randomly select a slot from the candidata fifo. 
                    if (frame_adj_ena && !fifo_fcb_empty_half) begin
                        if (fcb_ran_idx < fifo_fcb_data_count_half) begin
                            fcb_ran_idx <= fcb_ran_idx + 1;
                            fcb_state <= FCB_SEL_RAN_WAIT_2;
                        end else begin //calculate modulo
                            dividend <= fcb_ran_idx;
                            divisor <= fifo_fcb_data_count_half;
                            divider_enable <= 1;
                            fcb_state <= FCB_SEL_RAN_WAIT_1;
                        end
                    end else if (slot_adj_ena) begin
                        if (fifo_fcb_data_count_s1_tmp >= thres_slot_adj) begin
                            if (fcb_ran_idx < fifo_fcb_data_count_s1) begin
                                fcb_ran_idx <= fcb_ran_idx + 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_2;
                            end else begin //calculate modulo
                                dividend <= fcb_ran_idx;
                                divisor <= fifo_fcb_data_count_s1;
                                divider_enable <= 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_1;
                            end                            
                        end else if (fifo_fcb_data_count_s2 != 0) begin
                            if (fcb_ran_idx < fifo_fcb_data_count_s2) begin
                                fcb_ran_idx <= fcb_ran_idx + 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_2;
                            end else begin //calculate modulo
                                dividend <= fcb_ran_idx;
                                divisor <= fifo_fcb_data_count_s2;
                                divider_enable <= 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_1;
                            end  
                        end else begin
                           fcb_fail <= 1; // we cannot find a bch candidate.
                           fcb_state <= FCB_DONE; 
                       end
                    end else begin
                        if (fifo_fcb_data_count_s1 != 0) begin
                            if (fcb_ran_idx < fifo_fcb_data_count_s1) begin
                                fcb_ran_idx <= fcb_ran_idx + 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_2;
                            end else begin //calculate modulo
                                dividend <= fcb_ran_idx;
                                divisor <= fifo_fcb_data_count_s1;
                                divider_enable <= 1;
                                fcb_state <= FCB_SEL_RAN_WAIT_1;
                            end
                        end else begin
                           fcb_fail <= 1; // we cannot find a bch candidate.
                           fcb_state <= FCB_DONE; 
                       end
                    end
                end
                FCB_SEL_RAN_WAIT_1: begin
                    divider_enable <= 0;
                    if (divider_done) begin
                        fcb_ran_idx <= divider_remainder;
                        fcb_state <= FCB_SEL_RAN_START;
                    end
                end
                FCB_SEL_RAN_WAIT_2: begin
                    if (frame_adj_ena && !fifo_fcb_empty_half) begin
                        if (fcb_ran_idx == 0) begin
                            fifo_fcb_rd_en_half <= 1;
                            fcb_bch_candidate <= fifo_fcb_dread_half;
                            fifo_fcb_srst <= 1; // reset fifos.
                            fcb_state <= FCB_DONE;  
                        end else begin
                            fifo_fcb_rd_en_half <= 1;
                            fcb_bch_candidate <= fifo_fcb_dread_half;
                            fcb_ran_idx = fcb_ran_idx - 1;
                        end
                    end else if (slot_adj_ena) begin
                        if (fifo_fcb_data_count_s1 >= thres_slot_adj) begin
                            if (fcb_ran_idx == 0) begin
                                fifo_fcb_rd_en_s1 <= 1;
                                fcb_bch_candidate <= fifo_fcb_dread_s1;
                                fifo_fcb_srst <= 1; // reset fifos.
                                fcb_state <= FCB_DONE;  
                            end else begin
                                fifo_fcb_rd_en_s1 <= 1;
                                fcb_bch_candidate <= fifo_fcb_dread_s1;
                                fcb_ran_idx = fcb_ran_idx - 1;
                            end
                        end else if (fifo_fcb_data_count_s2 != 0) begin
                            if (fcb_ran_idx == 0) begin
                                fifo_fcb_rd_en_s2 <= 1;
                                fcb_bch_candidate <= fifo_fcb_dread_s2;
                                fifo_fcb_srst <= 1; // reset fifos.
                                fcb_state <= FCB_DONE;  
                            end else begin
                                fifo_fcb_rd_en_s1 <= 1;
                                fcb_bch_candidate <= fifo_fcb_dread_s2;
                                fcb_ran_idx = fcb_ran_idx - 1;
                            end   
                        end
                    end else begin
                        if (fifo_fcb_valid_s1 && fcb_ran_idx) begin
                            fifo_fcb_rd_en_s1 <= 1;
                            fcb_bch_candidate <= fifo_fcb_dread_s1;
                            fcb_ran_idx = fcb_ran_idx - 1;
                        end else begin
                            fifo_fcb_rd_en_s1 <= 0;
                            fifo_fcb_srst <= 1; // reset fifos.
                            fcb_state <= FCB_DONE;                        
                        end   
                    end                
                end
                FCB_DONE: begin
                    
                    slot_status_addr_fcb <= 0;
                    
                    fifo_fcb_rd_en_s1 <= 0;
                    fifo_fcb_rd_en_s2 <= 0;
                    fifo_fcb_rd_en_half <= 0;
                    fifo_fcb_srst <= 0;
                    fcb_state <= FCB_DONE2;
                end
                FCB_DONE2:begin
                    fcb_done <= 1;
                    fcb_inprogress <= 0;
                    fcb_state <= FCB_IDLE;
                end
            endcase
        end
    end
    
    /////////////////////////////////////////////////////////////
    // BCH pointer assignment
    /////////////////////////////////////////////////////////////
    // Input: time slot state (to do)
    //        bch_user_pointer
    /////////////////////////////////////////////////////////////
    //reg [DATA_WIDTH/2 -1:0] bch_slot_pointer;
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

    reg [10:0] fi_pkt_len_byte;
    reg [31:0] fi_pkt_time_ns;

    always @ (posedge clk)
    begin
        fi_pkt_len_byte <= (curr_frame_len >> 2) * 7 + 2;//// FRAME_SLOT_NUM * 14 bits / 8 + 2
        fi_pkt_time_ns <= TIME_PER_BYTE_12M_NS * (fi_pkt_len_byte + 4) + TX_GUARD_NS;
    end
    
    // lens of the 802.11 MAC header is 30 bytes. 2 bytes for padding.
    `define PAYLOAD_OFFSET 32'h20

    /////////////////////////////////////////////////////////////
    // Construct FI pkt just before our BCH begins.
    /////////////////////////////////////////////////////////////
    parameter FI_IDLE = 0, FI_START_RST_BUF = 28, FI_START_RST_BUF_LOOP = 29, FI_START_PRE = 30,
            FI_START = 1, FI_LOOP_1_PRE = 2, FI_LOOP_1 = 3, FI_LOOP_1_UNLOCK = 4, FI_LOOP_1_REFRESH = 5, FI_LOOP_2 = 6, FI_LOOP_2_WR = 7,
            FI_ADJ_IS_NEEDED_PRE = 31, FI_ADJ_IS_NEEDED = 8, FI_ADJ_FRAME_LEN = 9, FI_ADJ_WINNER_PRE = 32, FI_ADJ_WINNER = 10, 
            FI_SET_PKT_CONTENT_START = 11, FI_SET_PKT_CONTENT_MID = 12, FI_SET_PKT_CONTENT_WAIT = 13,
            FI_SET_BUF_LEN_START = 14, FI_SET_BUF_LEN_MID = 15, FI_SET_BUF_LEN_WAIT = 16,
            FI_SET_FRAME_LEN_START = 17, FI_SET_FRAME_LEN_MID = 18, FI_SET_FRAME_LEN_WAIT = 19,
            FI_CAL_CKS_START = 20, FI_CAL_CKS_MID = 21, FI_CAL_CKS_WAIT = 22, FI_SET_CKS_START = 23, FI_SET_CKS_MID = 24, FI_SET_CKS_WAIT = 25,
            FI_START_FCB = 26, FI_WAIT_FCB = 27,
            FI_END = 62, FI_ERROR = 63;
    (* mark_debug = "true" *) reg [5:0] fi_state;
    
    reg fi_initialed;
    reg [12:0] fi_index;
    reg [6:0] bit_fi_index;
    reg [FI_PER_SLOT_BITSNUM-1:0] fi_per_slot;
    reg [4:0] fi_per_slot_index;
    reg frame_cut_flag;
    reg [7:0] bch_c3h;
    reg [31:0] sendpkt_tmp_buf;
    reg [5:0] rst_beat_idx;
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            fi_state <= FI_IDLE;
            init_fi_done <= 0;
            blk_mem_sendpkt_we_fi <= 0;
//            blk_mem_sendpkt_en_fi <= 0;
            blk_mem_slot_status_en_fi <= 0;
            slot_status_we_fi <= 0;
            fi_index <= 0;
            frmae_len_need_slotadj <= 0;
            frmae_len_need_expand <= 0;
            frmae_len_need_halve <= 0;
            slot_need_adj <= 0;
            adj_slot_win <= 0;
            frame_half_empty <= 0;
            free_ths_count <= 0;
            free_ehs_count <= 0;
            fi_initialed <= 0;
            fcb_strict <= 0;
            frame_cut_flag <= 1;
            frame_len_exp_bch <= 0;
            frame_len_cut_bch <= 0;
            rst_beat_idx <= 0;
            is_single_flag <= 0;
            frame_count <= 0;
        end else begin
            case (fi_state)
                FI_IDLE: begin
                    init_fi_done <= 0;
                    frame_cut_flag <= 1;
                    free_ths_count <= 0;
                    free_ehs_count <= 0;
                    
                    if (init_fi_start) begin
                        fi_initialed <= 1;
                        fi_state <= FI_START_PRE;
                    end else if ( fi_initialed ) begin
                        if (bch_work_pointer == 0) begin
                            if (slot_pointer == (curr_frame_len - 1) 
                                    && (slot_pulse2_counter > (SLOT_US - 30))) begin
                                frame_count <= frame_count + 1;
                                fi_state <= FI_START_RST_BUF;
                            end
                        end else begin 
                            if ((slot_pointer == (bch_work_pointer - 1)) 
                                    && (slot_pulse2_counter > (SLOT_US - 30))) begin
                                frame_count <= frame_count + 1;
                                fi_state <= FI_START_RST_BUF;
                            end
                        end
                    end else
                        fi_state <= FI_IDLE;
                end
                FI_START_RST_BUF: begin
                    blk_mem_slot_status_en_fi <= 1; //enable accessing the slot status block memory.
                    rst_beat_idx <= 1;
                    blk_mem_sendpkt_addr_fi <= 0;
                    blk_mem_sendpkt_we_fi <= 1;
                    blk_mem_sendpkt_din_fi[31:0] <= 0;
                    fi_state <= FI_START_RST_BUF_LOOP;
                end
                FI_START_RST_BUF_LOOP: begin
                    blk_mem_sendpkt_addr_fi <= rst_beat_idx;
                    blk_mem_sendpkt_din_fi[31:0] <= 0;
                    rst_beat_idx <= rst_beat_idx + 1;
                    if (rst_beat_idx == 57)
                        fi_state <= FI_START_PRE;  
                end
                FI_START_PRE: begin
                    blk_mem_sendpkt_we_fi <= 0;
                    fi_state <= FI_START;
                    blk_mem_slot_status_en_fi <= 1; //enable accessing the slot status block memory.
                    slot_status_addr_fi <= 0; 
                end
                FI_START: begin
//                    blk_mem_sendpkt_en_fi <= 1; //enable accessing the sendpkt block memory.
                    is_single_flag <= 1;
                    blk_mem_sendpkt_addr_fi <= 0;
                    
                    blk_mem_sendpkt_din_fi[PKT_FRAMELEN_MSB:PKT_FRAMELEN_LSB] <= curr_frame_len_log2;
                    blk_mem_sendpkt_din_fi[FI_SENDER_SID_MSB:FI_SENDER_SID_LSB] <= global_sid;

                    fi_index <= FI_SENDER_SID_MSB + 1;
                    bit_fi_index = FI_SENDER_SID_MSB + 1;
                    fi_state <= FI_LOOP_1_PRE;
                    
                end

                FI_LOOP_1_PRE: begin
                    if (slot_status_addr_fi == curr_frame_len) begin
                        slot_status_addr_fi <= bch_work_pointer; //for the slot adj determination.
                        blk_mem_sendpkt_we_fi <= 1; //write last beat of sendpkt.
                        if (slot_adj_ena)
                            fi_state <= FI_ADJ_IS_NEEDED_PRE;
                        else
                            fi_state <= FI_SET_PKT_CONTENT_START;
                    end else begin
                        fi_state <= FI_LOOP_1;
                    end
                end
                FI_ADJ_IS_NEEDED_PRE: begin
                    blk_mem_sendpkt_we_fi <= 0;
                    fi_state <= FI_ADJ_IS_NEEDED;
                end
                FI_ADJ_IS_NEEDED: begin
                    if (/*free_ths_count >= thres_cut_free_ths &&*/ free_ehs_count >= thres_cut_free_ehs 
                        && curr_frame_len > adj_frame_lower_bound) 
                        frame_half_empty <= 1;
                    else
                        frame_half_empty <= 0;
                    
                    if (curr_bch_state > BCH_WAIT_REQ_FI_INIT_WAIT) begin
                        //determine if slot_adj is needed
                        if (blk_mem_slot_status_dout[COUNT_3HOP_MSB:COUNT_3HOP_LSB] >= bch_candidate_c3hop_thres_s1
                                && free_ehs_count >= thres_slot_adj ) begin
                            slot_need_adj <= 1;
                            fcb_strict <= 1;
                        end else if (frame_adj_ena) begin
                            slot_need_adj <= 0;
                            //determine if frame_len adj is needed.
                            if (/*free_ths_count >= thres_cut_free_ths &&*/ free_ehs_count >= thres_cut_free_ehs 
                                && curr_frame_len > adj_frame_lower_bound
                                && bch_work_pointer >= (curr_frame_len >> 1)) begin
                                frmae_len_need_slotadj <= 1;
                                frmae_len_need_expand <= 0;
                                fcb_strict <= 1;
                            end else if (/*free_ths_count <= thres_exp_free_ths*/ free_ehs_count <= thres_exp_free_ehs && curr_frame_len < adj_frame_upper_bound) begin
                                frmae_len_need_slotadj <= 0;
                                frmae_len_need_expand <= 1;
                                frame_len_exp_bch <= 1;
                                fcb_strict <= 0;
                            end else begin
                                frmae_len_need_slotadj <= 0;
                                frmae_len_need_expand <= 0;
                                fcb_strict <= 0;                    
                            end
                        end
                        //determine if frame_len_halve is needed.
                        if (frame_adj_ena && frame_cut_flag && /*free_ths_count >= thres_cut_free_ths &&*/ free_ehs_count >= thres_cut_free_ehs 
                                                    && curr_frame_len > adj_frame_lower_bound) begin
                            frmae_len_need_halve <= 1;
                            frame_len_cut_bch <= 1;
                        end else
                            frmae_len_need_halve <= 0;
                        //choose ADJ winner from bch_work_pointer / bch_decide_adj
                        //In FI_LOOP_1_PRE, we have set slot_status_addr_fi <= bch_work_pointer, so this state we have set bch_decide_adj.
                        bch_c3h <= blk_mem_slot_status_dout[COUNT_3HOP_MSB:COUNT_3HOP_LSB];
                        slot_status_addr_fi <= bch_decide_adj;
                        
                        fi_state <= FI_ADJ_WINNER_PRE;
                    end else begin
                        fi_state <= FI_SET_PKT_CONTENT_START;
                    end
                end
                FI_ADJ_WINNER_PRE: begin
                    fi_state <= FI_ADJ_WINNER;
                    frame_len_exp_bch <= 0;
                    frame_len_cut_bch <= 0;
                end
                FI_ADJ_WINNER: begin
                    if (bch_c3h >= blk_mem_slot_status_dout[COUNT_3HOP_MSB:COUNT_3HOP_LSB] 
                        && blk_mem_slot_status_dout[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB] == global_sid
                        && blk_mem_slot_status_dout[BUSY_MSB:BUSY_LSB] == 2'b10)
                        adj_slot_win <= 1;
                    else
                        adj_slot_win <= 0;
                    if (frmae_len_need_expand || frmae_len_need_halve)
                        fi_state <= FI_ADJ_FRAME_LEN;
                    else
                        fi_state <= FI_SET_PKT_CONTENT_START;
                end
                FI_ADJ_FRAME_LEN: begin
                    blk_mem_sendpkt_addr_fi <= 0;
                    blk_mem_sendpkt_we_fi <= 1;
                    blk_mem_sendpkt_din_fi[PKT_FRAMELEN_MSB:PKT_FRAMELEN_LSB] <= curr_frame_len_log2;
                    blk_mem_sendpkt_din_fi[31: (PKT_FRAMELEN_MSB+1)] <= sendpkt_tmp_buf[31: (PKT_FRAMELEN_MSB+1)];
                    fi_state <= FI_SET_PKT_CONTENT_START;
                end
                FI_LOOP_1: begin
                    fi_state <= FI_LOOP_1_UNLOCK;
                    
                    fi_per_slot[FI_S_PERSLOT_BUSY_MSB:FI_S_PERSLOT_BUSY_LSB] <= blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB];
                    fi_per_slot[FI_S_PERSLOT_OCCUPIER_SID_MSB:FI_S_PERSLOT_OCCUPIER_SID_LSB] <= blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB];
                    fi_per_slot[FI_S_PERSLOT_COUNT_MSB:FI_S_PERSLOT_COUNT_LSB] <= 
                                (blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB] > 2'b11) ? 2'b11 : blk_mem_slot_status_dout[COUNT_2HOP_MSB : COUNT_2HOP_LSB];
                    fi_per_slot[FI_S_PERSLOT_PSF_MSB:FI_S_PERSLOT_PSF_LSB] <= blk_mem_slot_status_dout[PSF_MSB : PSF_LSB];
                    fi_per_slot_index <= 0;
                    // THS/EHS free count.
                    if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 0) begin
                        free_ths_count <= free_ths_count + 1;
                        if (blk_mem_slot_status_dout[COUNT_3HOP_MSB : COUNT_3HOP_LSB] == 0)
                            free_ehs_count <= free_ehs_count + 1;
                    end else if ( slot_status_addr_fi >= (curr_frame_len >> 1) ) 
                        frame_cut_flag <= 0;
                    
                    //is Single
                    if (blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] != 0
                            && blk_mem_slot_status_dout[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] != global_sid) begin
                        is_single_flag <= 0;
                    end
                    
                    slot_status_din_fi[63:0] <= blk_mem_slot_status_dout[63:0];
//                        slot_status_din_fi[STATUS_MSB : STATUS_LSB] <= blk_mem_slot_status_dout[STATUS_MSB : STATUS_LSB];
//                        slot_status_din_fi[BUSY_MSB:BUSY_LSB] <= blk_mem_slot_status_dout[BUSY_MSB:BUSY_LSB];
//                        slot_status_din_fi[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB] <= blk_mem_slot_status_dout[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB];
//                        slot_status_din_fi[COUNT_2HOP_MSB: COUNT_2HOP_LSB] <= blk_mem_slot_status_dout[COUNT_2HOP_MSB: COUNT_2HOP_LSB];
//                        slot_status_din_fi[COUNT_3HOP_MSB:COUNT_3HOP_LSB] <= blk_mem_slot_status_dout[COUNT_3HOP_MSB:COUNT_3HOP_LSB];
//                        slot_status_din_fi[PSF_MSB:PSF_LSB] <= blk_mem_slot_status_dout[PSF_MSB:PSF_LSB];
//                        slot_status_din_fi[LIFE_MSB:LIFE_LSB] <= blk_mem_slot_status_dout[LIFE_MSB:LIFE_LSB];
//                        slot_status_din_fi[C3HOP_N] <= blk_mem_slot_status_dout[C3HOP_N];

                end
                FI_LOOP_1_UNLOCK: begin
                    fi_state <= FI_LOOP_1_REFRESH;
                    
                    slot_status_din_fi[C3HOP_N] <= 0;
                    slot_status_din_fi[EXISTED] <= 0;
                    if (slot_status_din_fi[LOCKER])
                        slot_status_din_fi[LOCKER] <= 0; //unlock this slot.
                    end
                FI_LOOP_1_REFRESH: begin
                    fi_state <= FI_LOOP_2; 
                    
                    slot_status_we_fi <= 1;
//                    if (curr_bch_state > BCH_WAIT_REQ_FI_INIT_WAIT) begin
                    //refresh life time.
                    if (blk_mem_slot_status_dout[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB] != global_sid 
                            && blk_mem_slot_status_dout[OCCUPIER_SID_MSB:OCCUPIER_SID_LSB] != 0)
                    begin
                        if (blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] > 1) begin
                            slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] - 1;
                        end else if (blk_mem_slot_status_dout[LIFE_MSB: LIFE_LSB] == 1) begin
                            if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b01) begin
                                slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= 0;
                                slot_status_din_fi[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                                slot_status_din_fi[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0;
                                slot_status_din_fi[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                                slot_status_din_fi[BUSY_MSB : BUSY_LSB] <= 0;
                                slot_status_din_fi[PSF_MSB : PSF_LSB] <= 0;
                                slot_status_din_fi[LOCKER] <= 0; 
                                slot_status_din_fi[C3HOP_N] <= 0; 
                            end else if (blk_mem_slot_status_dout[BUSY_MSB : BUSY_LSB] == 2'b10 && blk_mem_slot_status_dout[EXISTED] == 1) begin
                                slot_status_din_fi[BUSY_MSB : BUSY_LSB] <= 2'b01;
                                slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= OCCUPIER_LIFE_FRAME - 1;
                                slot_status_din_fi[LOCKER] <= 0; 
                            end else begin
                                slot_status_din_fi[LIFE_MSB: LIFE_LSB] <= 0;
                                slot_status_din_fi[OCCUPIER_SID_MSB : OCCUPIER_SID_LSB] <= 0;
                                slot_status_din_fi[COUNT_2HOP_MSB : COUNT_2HOP_LSB] <= 0;
                                slot_status_din_fi[COUNT_3HOP_MSB : COUNT_3HOP_LSB] <= 0;
                                slot_status_din_fi[BUSY_MSB : BUSY_LSB] <= 0;
                                slot_status_din_fi[PSF_MSB : PSF_LSB] <= 0;
                                slot_status_din_fi[LOCKER] <= 1; 
                                slot_status_din_fi[C3HOP_N] <= 0; 
                            end
                        end
                    end
//                    end
                    
                end
                FI_LOOP_2: begin
                    
                    slot_status_we_fi <= 0;
                    blk_mem_sendpkt_din_fi[bit_fi_index] = fi_per_slot[fi_per_slot_index];
                    bit_fi_index = (bit_fi_index + 1) % DATA_WIDTH;
                    fi_index = fi_index + 1;
                    fi_per_slot_index = fi_per_slot_index + 1;
                    if (bit_fi_index == 0) begin
                        if (blk_mem_sendpkt_addr_fi == 0)
                            sendpkt_tmp_buf[31:0] <= blk_mem_sendpkt_din_fi[31:0];
                            
                        blk_mem_sendpkt_we_fi <= 1;
                        fi_state <= FI_LOOP_2_WR;
                    end else if (fi_per_slot_index == FI_PER_SLOT_BITSNUM) begin
                        slot_status_addr_fi <= slot_status_addr_fi + 1;
                        fi_state <= FI_LOOP_1_PRE;
                    end
                end
                FI_LOOP_2_WR: begin
                    blk_mem_sendpkt_we_fi <= 0;
                    blk_mem_sendpkt_addr_fi <= blk_mem_sendpkt_addr_fi + 1;
                    blk_mem_sendpkt_din_fi[DATA_WIDTH-1:0] <= 0;
                    
                    if (fi_per_slot_index == FI_PER_SLOT_BITSNUM) begin
                        slot_status_addr_fi <= slot_status_addr_fi + 1;
                        fi_state <= FI_LOOP_1_PRE;
                    end else
                        fi_state <= FI_LOOP_2;
                end
                FI_SET_PKT_CONTENT_START: begin 
                    blk_mem_sendpkt_we_fi <= 0;    
                    ipic_start_fi <= 1;
                    ipic_type_fi <= `BURST_WR;
                    write_addr_fi <= curr_skbdata_addr + `PAYLOAD_OFFSET;
                    write_length_fi <= (fi_pkt_len_byte + 4) & 14'h3FFC; // because FI_PKT_LEN is not 4 byte aligned !
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
                    write_data_fi <= ((`PAYLOAD_OFFSET + fi_pkt_len_byte + 4) << 16) & 32'h0fff0000;
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
                    write_data_fi <= ((`PAYLOAD_OFFSET + fi_pkt_len_byte + 4 + 4) & 32'h00000fff) | 32'h13f0000;
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
                        fi_state = FI_START_FCB;
                    end
                FI_START_FCB: begin
                    fi_state <= FI_WAIT_FCB;              
                    fcb_start <= 1;
                end
                FI_WAIT_FCB: begin
                    fcb_start <= 0;
                    if (fcb_done)
                        fi_state <= FI_END;
                end                    
                FI_END: begin
                    init_fi_done <= 1;
                    blk_mem_slot_status_en_fi <= 0; 
                    if (bch_slot_pointer == 0 && (slot_pointer != (curr_frame_len - 1)))
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
                MO_SEND_FI = 14,
                MO_SET_BUF_LEN_START = 21, MO_SET_BUF_LEN_MID = 22, MO_SET_BUF_LEN_WAIT = 23, 
                /*MO_SET_FRAME_LEN_START = 24, MO_SET_FRAME_LEN_MID = 25, MO_SET_FRAME_LEN_WAIT = 26,
                MO_CAL_CKS_START = 27, MO_CAL_CKS_MID = 28, MO_CAL_CKS_WAIT = 29, MO_SET_CKS_START = 30, MO_SET_CKS_MID = 31, MO_SET_CKS_WAIT = 32,*/
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
            fi_send_count <= 0;
        end else begin
            case (mo_state)
                MO_IDLE: begin
                    send_fi_done <= 0;
                    if (start_ping) begin
                        mo_state <= MO_WAIT_TXEN;
                    end else if (recv_ping) begin
                        test_seq <= recv_seq;
                        pkt_type_flag <= `ACK_PING;
                        pkt_sec <= recv_sec;
                        pkt_counter2 <= recv_counter2;
                        mo_state <= MO_SETPKT_START;
                    end else if ( recv_ack_ping) begin
                        mo_state <= MO_PROCESS_ACKPING;
                    end else if (send_fi_start) begin
                        bch_control_time_ns <= 0;
                        mo_state <= MO_SEND_FI;
                    end
                end

                //Content of FI has been constructed by FI_STATE_MACHINE.
                MO_SEND_FI: begin
                    send_pkt_mo <= 1;
                    fi_send_count <= fi_send_count + 1;
                    send_fi_done <= 1;
                    bch_control_time_ns <= fi_pkt_time_ns;
                    mo_state <= MO_END;
                end                 
                    
//                MO_SET_BUF_LEN_START: begin
//                    ipic_start_mo <= 1;
//                    ipic_type_mo <= `SINGLE_WR;
//                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 12; //refer to ar9003_txc 
//                    write_data_mo <= ((`PAYLOAD_OFFSET + pkt_len_byte + 4) << 16) & 32'h0fff0000;
//                    mo_state = MO_SET_BUF_LEN_MID;   
//                end
//                MO_SET_BUF_LEN_MID: 
//                    if (ipic_ack_mo) begin
//                        ipic_start_mo <= 0; 
//                        mo_state <= MO_SET_BUF_LEN_WAIT;
//                    end                 
//                MO_SET_BUF_LEN_WAIT:
//                    if (ipic_done_wire) begin
//                        mo_state <= MO_SET_FRAME_LEN_START;
//                    end 
//                MO_SET_FRAME_LEN_START: begin
//                    ipic_start_mo <= 1;
//                    ipic_type_mo <= `SINGLE_WR;
//                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 44; //refer to ar9003_txc 
//                    write_data_mo <= ((`PAYLOAD_OFFSET + pkt_len_byte + 4 + 4) & 32'h00000fff) | 32'h13f0000;
//                    mo_state = MO_SET_FRAME_LEN_MID;
//                end
//                MO_SET_FRAME_LEN_MID: 
//                    if (ipic_ack_mo) begin
//                        ipic_start_mo <= 0; 
//                        mo_state <= MO_SET_FRAME_LEN_WAIT;
//                    end           
//                MO_SET_FRAME_LEN_WAIT:
//                    if (ipic_done_wire) begin
//                        mo_state <= MO_CAL_CKS_START;
//                    end
//                MO_CAL_CKS_START: begin
//                    ipic_start_mo <= 1;
//                    ipic_type_mo <= `CAL_DESC_CKS;
//                    read_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0];
//                    mo_state <= MO_CAL_CKS_MID;
//                end
//                MO_CAL_CKS_MID: 
//                    if (ipic_ack_mo) begin
//                        ipic_start_mo <= 0; 
//                        mo_state <= MO_CAL_CKS_WAIT;
//                    end
                
//                MO_CAL_CKS_WAIT: 
//                    if (ipic_done_wire) 
//                        mo_state <= MO_SET_CKS_START;
                
//                MO_SET_CKS_START: begin
//                    ipic_start_mo <= 1;
//                    ipic_type_mo <= `SINGLE_WR;
//                    write_addr_mo <= txfifo_dread[DATA_WIDTH-1 : 0] + 40; //refer to ar9003_txc 
//                    write_data_mo <= ptr_checksum;
//                    mo_state = MO_SET_CKS_MID;
//                end
//                MO_SET_CKS_MID: 
//                    if (ipic_ack_mo) begin
//                        ipic_start_mo <= 0;
//                        mo_state = MO_SET_CKS_WAIT;
//                    end
//                MO_SET_CKS_WAIT: 
//                    if (ipic_done_wire) begin
//                        send_pkt_mo <= 1;
//                        send_fi_done <= 1;
//                        mo_state = MO_END;
//                    end                      
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