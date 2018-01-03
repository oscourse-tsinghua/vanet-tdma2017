
module txfifo_wr_machine # 
(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)
(
    input wire clk,
    input wire reset_n,

    //FIFO Logic
    input wire  txfifo_full,
    output reg  txfifo_wr_en,
    output reg [DATA_WIDTH-1 : 0] txfifo_dwrite,
    input wire  txfifo_wr_ack,
    input wire  txfifo_overflow,
    
    //User Logic
    input wire linux_wr_start,
    input wire [DATA_WIDTH-1:0] linux_wr_data,
    input wire tc_wr_start,
    input wire [DATA_WIDTH-1:0] tc_wr_data,
    output reg wr_done
);
    
    
    reg txfifo_write_cpl_pulse;
    reg txfifo_write_enable;
    reg [DATA_WIDTH-1:0] txfifo_data;
    reg [1:0] dispatch_state;
    
    always @( posedge clk )
    begin
        if ( reset_n == 0 ) begin
            dispatch_state <= 0;
            txfifo_write_enable <= 0;
            txfifo_data <= 0;
            wr_done <= 0;
        end 
        else begin
            if ( dispatch_state == 0 ) begin
                if (tc_wr_start) begin
                    txfifo_data <= tc_wr_data;
                    txfifo_write_enable <= 1;
                    dispatch_state <= 1;
                end
                else if (linux_wr_start) begin
                    txfifo_data <= linux_wr_data;
                    txfifo_write_enable <= 1;
                    dispatch_state <= 1;
                end
            end else if ( dispatch_state == 1 ) begin    
                txfifo_write_enable <= 0;       
                if (txfifo_write_cpl_pulse) begin
                    wr_done <= 1;
                    dispatch_state <= 2;
                end
            end else if ( dispatch_state == 2 ) begin  
                wr_done <= 0;
                dispatch_state <= 0;
            end    
        end
    end
    
    reg [2:0] txfifo_write_status;
    /**
     * tx FIFO
     **/
    always @( posedge clk )
    begin
        if ( reset_n == 0 ) begin
           txfifo_write_status <= 0;
           txfifo_write_cpl_pulse <= 0;
        end
        else begin 
            if ( txfifo_write_enable  && txfifo_write_status == 0 && !txfifo_full ) begin
                txfifo_dwrite[DATA_WIDTH-1 : 0] <= txfifo_data[DATA_WIDTH-1 : 0];
                txfifo_write_status <= 1;
                txfifo_wr_en <= 1;
            end
            else if ( txfifo_write_status == 1) begin
                txfifo_wr_en <= 0;  
                txfifo_write_status <= 2;
                txfifo_write_cpl_pulse <= 1;
            end
            else if ( txfifo_write_status == 2 ) begin
                txfifo_write_status <= 0;
                txfifo_write_cpl_pulse <= 0;
            end
        end
    end
    
endmodule