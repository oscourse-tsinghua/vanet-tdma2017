`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/04 15:08:15
// Design Name: 
// Module Name: ipic_lite_state_machine
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


module ipic_lite_state_machine#(
        parameter integer C_M_AXI_ADDR_WIDTH = 32,
        parameter integer C_NATIVE_DATA_WIDTH = 32,
        parameter integer C_LENGTH_WIDTH = 14
)
(
        //clk
        input wire clk,
        input wire reset_n,
        
        //  IP Master Request/Qualifers
        output     reg                     ip2bus_mstrd_req,
        output  reg                     ip2bus_mstwr_req,
        output     reg     [C_M_AXI_ADDR_WIDTH-1 : 0]                ip2bus_mst_addr,
        output     reg     [(C_NATIVE_DATA_WIDTH/8)-1 : 0]     ip2bus_mst_be,
        output  reg                     ip2bus_mst_lock,
        output     reg                     ip2bus_mst_reset,
        //  IP Request Status Reply  
        input     wire                     bus2ip_mst_cmdack,
        input   wire                     bus2ip_mst_cmplt,
        input   wire                     bus2ip_mst_error,
        input   wire                     bus2ip_mst_rearbitrate,
        input   wire                     bus2ip_mst_cmd_timeout,
        //  IPIC Read data
        input     wire     [C_NATIVE_DATA_WIDTH-1 : 0]        bus2ip_mstrd_d,
        input     wire                     bus2ip_mstrd_src_rdy_n,
        //  IPIC Write data
        output     reg     [C_NATIVE_DATA_WIDTH-1 : 0]        ip2bus_mstwr_d,
        input     wire                     bus2ip_mstwr_dst_rdy_n,     
        //USER LOGIC
        input wire [2:0]ipic_type ,
        input wire ipic_start,
        output reg ipic_done,
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr,
        output reg [C_NATIVE_DATA_WIDTH-1 : 0] single_read_data,
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] write_addr,
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] write_data      
    );
    
    //-----------------------------------------------------------------------------------------
    //--IPIC transaction state machine:
    ////0: burst read transaction (Unspoorted in Lite IPIC)
    ////1: burst write transaction (Unspoorted in Lite IPIC)
    ////2: single read transaction
    ////3: single write transaction
    //-----------------------------------------------------------------------------------------
    `define SINGLE_RD 2
    `define SINGLE_WR 3
    
    reg [5:0] curr_ipic_state;
    reg [5:0] next_ipic_state;
    
    localparam IPIC_IDLE=0, IPIC_DISPATCH=1, 
         IPIC_SINGLE_RD_WAIT=2, IPIC_SINGLE_RD_RCV_WAIT=8, IPIC_SINGLE_RD_END=10,
         IPIC_SINGLE_WR_WAIT=12, IPIC_SINGLE_WR_WR_WAIT = 13, IPIC_SINGLE_WR_END=15,
         IPIC_ERROR=37;    
         
    //First Stage of IPIC
    always @ (posedge clk)
    begin
         if ( reset_n == 0 )  
             curr_ipic_state <= IPIC_IDLE;
         else
             curr_ipic_state <= next_ipic_state; 
    end
     
    //Second Stage of IPIC
    always @ (curr_ipic_state)
    begin
        case(curr_ipic_state)
            IPIC_IDLE: begin
                if (ipic_start)
                    next_ipic_state <= IPIC_DISPATCH;
                else
                    next_ipic_state <= IPIC_IDLE;                 
            end
            IPIC_DISPATCH: begin
                case(ipic_type)               
                    `SINGLE_RD: next_ipic_state <= IPIC_SINGLE_RD_WAIT;
                    `SINGLE_WR: next_ipic_state <= IPIC_SINGLE_WR_WAIT;
                    default: next_ipic_state <= IPIC_ERROR;
                endcase
            end          
            
            //--------------------------------------------------------
            // Single Read
            //--------------------------------------------------------
            IPIC_SINGLE_RD_WAIT: begin
                if ( bus2ip_mst_cmdack ) 
                    next_ipic_state <= IPIC_SINGLE_RD_RCV_WAIT;     
                else
                    next_ipic_state <= IPIC_SINGLE_RD_WAIT;
            end
            IPIC_SINGLE_RD_RCV_WAIT: begin
                if ( bus2ip_mst_cmplt )
                    next_ipic_state <= IPIC_SINGLE_RD_END;   
                else
                    next_ipic_state <= IPIC_SINGLE_RD_RCV_WAIT;
            end
            IPIC_SINGLE_RD_END: next_ipic_state <= IPIC_IDLE; 
             //--------------------------------------------------------
             // Single Write
             //--------------------------------------------------------
            IPIC_SINGLE_WR_WAIT: begin
                if (bus2ip_mst_cmdack)
                    next_ipic_state <= IPIC_SINGLE_WR_WR_WAIT; 
                else
                    next_ipic_state <= IPIC_SINGLE_WR_WAIT;
            end
            IPIC_SINGLE_WR_WR_WAIT: begin
                if (bus2ip_mst_cmplt)
                    next_ipic_state <= IPIC_SINGLE_WR_END;
                else
                    next_ipic_state <= IPIC_SINGLE_WR_WR_WAIT;
            end
            IPIC_SINGLE_WR_END: next_ipic_state <= IPIC_IDLE;         
            default: next_ipic_state <= IPIC_ERROR;
    
         endcase
     end

    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin
            ip2bus_mstrd_req <= 0; 
            ip2bus_mst_lock <= 0;
            ip2bus_mst_reset <= 0;
            ip2bus_mstwr_req <= 0; 

            ip2bus_mst_be <= 4'b1111;

            single_read_data <= 0;
            ipic_done <= 0;       
        end else begin
            case(next_ipic_state) 
                IPIC_IDLE: ipic_done <= 0; 




                //--------------------------------------------------------
                // Single Read
                //--------------------------------------------------------
                IPIC_SINGLE_RD_WAIT: begin
                    ip2bus_mstrd_req <= 1;
                    ip2bus_mstwr_req <= 0;
                    ip2bus_mst_addr <= read_addr;
                    ip2bus_mst_be <= 4'b1111;
                end
                IPIC_SINGLE_RD_RCV_WAIT: ip2bus_mstrd_req <= 0; 

                IPIC_SINGLE_RD_END: begin
                    single_read_data <= bus2ip_mstrd_d;
                    ipic_done <= 1;
                end

                //--------------------------------------------------------
                // Single Write
                //--------------------------------------------------------
                IPIC_SINGLE_WR_WAIT: begin
                    // assumed the data width is 32.
                    // actually the axi_master_lite ip only 
                    // supports 32bit data width. (PG161)
                    ip2bus_mst_be <= 4'b1111; 
                    // init a write request, load addr and data 
                    ip2bus_mstwr_req <= 1; 
                    ip2bus_mstrd_req <= 0; 
                    ip2bus_mst_addr <= write_addr;
                    ip2bus_mstwr_d <= write_data;
                end
                IPIC_SINGLE_WR_WR_WAIT: ip2bus_mstwr_req <= 0; 
                IPIC_SINGLE_WR_END: ipic_done <= 1;     
                         
                default: begin end                                                     
            endcase
        end //end if      
    end         
         
         
endmodule
