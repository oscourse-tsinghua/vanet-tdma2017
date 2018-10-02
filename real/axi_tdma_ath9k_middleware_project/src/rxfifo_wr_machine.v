
module rxfifo_wr_machine # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)
(
    input wire clk,
    input wire reset_n,

    //FIFO Logic
    input wire  rxfifo_full,
    output reg  rxfifo_wr_en,
    output reg [DATA_WIDTH-1 : 0] rxfifo_dwrite,
    input wire  rxfifo_wr_ack,
    input wire  rxfifo_overflow,
    
    //User Logic
    input wire linux_wr_start,
    input wire [DATA_WIDTH-1:0] linux_wr_data,
    input wire desc_wr_start,
    input wire [DATA_WIDTH-1:0] desc_wr_data,
    output reg wr_done
);
    
    
    reg rxfifo_write_cpl_pulse;
    reg rxfifo_write_enable;
    reg [DATA_WIDTH-1:0] rxfifo_data;
    reg [1:0] dispatch_state;
    
    always @( posedge clk )
    begin
        if ( reset_n == 0 ) begin
            dispatch_state <= 0;
            rxfifo_write_enable <= 0;
            rxfifo_data <= 0;
            wr_done <= 0;
        end 
        else begin
            if ( dispatch_state == 0 ) begin
                if (desc_wr_start) begin
                    rxfifo_data <= desc_wr_data;
                    rxfifo_write_enable <= 1;
                    dispatch_state <= 1;
                end
                else if (linux_wr_start) begin
                    rxfifo_data <= linux_wr_data;
                    rxfifo_write_enable <= 1;
                    dispatch_state <= 1;
                end
            end else if ( dispatch_state == 1 ) begin    
                rxfifo_write_enable <= 0;       
                if (rxfifo_write_cpl_pulse) begin
                    wr_done <= 1;
                    dispatch_state <= 2;
                end
            end else if ( dispatch_state == 2 ) begin  
                wr_done <= 0;
                dispatch_state <= 0;
            end    
        end
    end
    
    reg [2:0] rxfifo_write_status;
    /**
     * Rx FIFO
     **/
    always @( posedge clk )
    begin
        if ( reset_n == 0 ) begin
           rxfifo_write_status <= 0;
           rxfifo_write_cpl_pulse <= 0;
        end
        else begin 
            if ( rxfifo_write_enable  && rxfifo_write_status == 0 && !rxfifo_full ) begin
                rxfifo_dwrite[DATA_WIDTH-1 : 0] <= rxfifo_data[DATA_WIDTH-1 : 0];
                rxfifo_write_status <= 1;
                rxfifo_wr_en <= 1;
            end
            else if ( rxfifo_write_status == 1) begin
                rxfifo_wr_en <= 0;  
                rxfifo_write_status <= 2;
                rxfifo_write_cpl_pulse <= 1;
            end
            else if ( rxfifo_write_status == 2 ) begin
                rxfifo_write_status <= 0;
                rxfifo_write_cpl_pulse <= 0;
            end
        end
    end
    
endmodule