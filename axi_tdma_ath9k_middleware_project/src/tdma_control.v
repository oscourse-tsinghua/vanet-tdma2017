module tdma_control # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
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
    input wire ipic_done_lite_wire,
    output reg [ADDR_WIDTH-1 : 0] read_addr_lite, 
    input wire [DATA_WIDTH-1 : 0] single_read_data_lite,
    output reg [ADDR_WIDTH-1 : 0] write_addr_lite,  
    output reg [DATA_WIDTH-1 : 0] write_data_lite,
    
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
    input wire gps_timepulse_2
);
    localparam ATH9K_BASE_ADDR  =    32'h60000000;
    localparam integer AR_Q1_TXDP = 32'h0804;
    localparam integer AR_Q6_TXDP = 32'h0818;
    
    reg [2:0] sendpkt_counter;
    reg [2:0] current_sendpkt_counter;
    
    always @ (posedge test_sendpkt or negedge reset_n)
    begin
        if ( reset_n == 0 )
            sendpkt_counter <= 0;
        else sendpkt_counter <= sendpkt_counter + 1'b1;
    end

    `define SINGLE_RD 2
    `define SINGLE_WR 3
    
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
            0: begin
                if (test_sendpkt) 
                    pktsend_status<= 1;
            end
            1: begin
                if (sendpkt_counter != current_sendpkt_counter)
                    pktsend_status<= 2;
                else
                    pktsend_status<= 0;
            end
            2: begin
                current_sendpkt_counter <= sendpkt_counter;
                if (txfifo_valid && desc_irq_state == 0) begin
                    txfifo_rd_en <= 1;
                    write_addr_lite[ADDR_WIDTH-1 : 0] <= ATH9K_BASE_ADDR + AR_Q6_TXDP;
                    write_data_lite[ADDR_WIDTH-1 : 0] <= txfifo_dread[DATA_WIDTH-1 : 0];
                    txfifo_wr_data[ADDR_WIDTH-1 : 0] <= txfifo_dread[ADDR_WIDTH-1 : 0];
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
    // GPS TimePulse Logic
    /////////////////////////////////////////////////////////////
    // 1. TimePulse_1 pulses per 1 UTC-Sec. This is for the UTC time,
    // UTC time can be readed from a specific register after a pulse.
    // 2. We count TimePulse_2 to maintain an accurate and sync time.
    // The 32bit-counter clears every 1 UTC-sec.
    /////////////////////////////////////////////////////////////
    reg [31:0] pulse1_counter;
    reg [31:0] curr_pulse1_counter;
    reg [31:0] pulse2_counter;
    
    always @ (posedge gps_timepulse_1 or negedge reset_n)
    begin
        if ( reset_n == 0 )
            pulse1_counter <= 0;
        else pulse1_counter <= pulse1_counter + 1'b1;
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
endmodule