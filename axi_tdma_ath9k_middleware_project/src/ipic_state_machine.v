`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/08/03 09:10:40
// Design Name: 
// Module Name: ipic_state_machine
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
module ipic_state_machine#(
        parameter integer C_M_AXI_ADDR_WIDTH = 32,
        parameter integer C_NATIVE_DATA_WIDTH = 32,
        parameter integer C_LENGTH_WIDTH = 14,
        parameter  integer SEL_STEP_BEATS         = 8,
        parameter integer C_PKT_LEN = 2048
)

(
        //clk
        input wire clk,
        input wire reset_n,
        //-----------------------------------------------------------------------------------------
        //-- IPIC Request/Qualifiers (ALL INPUT)
        //-----------------------------------------------------------------------------------------
        output reg ip2bus_mstrd_req,
        output reg ip2bus_mstwr_req,
        output reg [C_M_AXI_ADDR_WIDTH-1 : 0] ip2bus_mst_addr,
        output reg [C_LENGTH_WIDTH-1 : 0] ip2bus_mst_length,
        output reg [(C_NATIVE_DATA_WIDTH/8)-1 : 0] ip2bus_mst_be,
        output reg ip2bus_mst_type,
        output reg ip2bus_mst_lock,
        output reg ip2bus_mst_reset,
        
        //-----------------------------------------------------------------------------------------
        //-- IPIC Request Status Reply (ALL OUT)
        //-----------------------------------------------------------------------------------------
        input wire bus2ip_mst_cmdack,
        input wire bus2ip_mst_cmplt,
        input wire bus2ip_mst_error,
        input wire  bus2ip_mst_rearbitrate,
        input wire  bus2ip_mst_cmd_timeout,
        
        //-----------------------------------------------------------------------------------------
        //-- IPIC Read LocalLink Channel
        //-----------------------------------------------------------------------------------------
        //OUT 
        input wire  [C_NATIVE_DATA_WIDTH-1 : 0] bus2ip_mstrd_d,
        input wire  [(C_NATIVE_DATA_WIDTH/8)-1 : 0] bus2ip_mstrd_rem,
        input wire  bus2ip_mstrd_sof_n,
        input wire  bus2ip_mstrd_eof_n,
        input wire  bus2ip_mstrd_src_rdy_n,
        input wire  bus2ip_mstrd_src_dsc_n,
        //IN
        output reg ip2bus_mstrd_dst_rdy_n,
        output reg ip2bus_mstrd_dst_dsc_n,
        
        
        //-----------------------------------------------------------------------------------------
        //-- IPIC Write LocalLink Channel
        //-----------------------------------------------------------------------------------------
        //IN
        output reg [C_NATIVE_DATA_WIDTH-1 : 0] ip2bus_mstwr_d,
        output reg [(C_NATIVE_DATA_WIDTH/8)-1 : 0] ip2bus_mstwr_rem,
        output reg ip2bus_mstwr_sof_n,
        output reg ip2bus_mstwr_eof_n,
        output reg ip2bus_mstwr_src_rdy_n,
        output reg ip2bus_mstwr_src_dsc_n,
        //OUT
        input wire  bus2ip_mstwr_dst_rdy_n,
        input wire  bus2ip_mstwr_dst_dsc_n,
        
        //USER LOGIC
        input wire [2:0]ipic_type,
        input wire ipic_start,
        output reg ipic_done,
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] read_addr,
        input wire [C_LENGTH_WIDTH-1 : 0] read_length,
        output reg [C_NATIVE_DATA_WIDTH-1 : 0] single_read_data,
        output reg [C_PKT_LEN-1:0] bunch_read_data, 
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] write_addr,
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] write_data,
        input wire [C_LENGTH_WIDTH-1 : 0] write_beat_length,
        //input wire [C_LENGTH_WIDTH-1 : 0] write_length,
        
        output wire [23 : 0] debug_len2,
        output wire [31:0] single_read_debug,
        output reg [5:0] curr_ipic_state
//        output reg rd_burst_error,
//        output reg rd_single_error       
    );
    
    assign single_read_debug = single_read_data;
    reg read_beat_lenghth;
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

    
//    reg [31:0] sel_buf_rd[0:7];
//    reg [31:0] sel_buf_wr[0:7];
    
    reg [13:0] wr_beat_idx;
    reg [12:0] read_beat_idx;
        
//    reg [5:0] curr_ipic_state;
    reg [5:0] next_ipic_state;

    
    parameter IPIC_IDLE=0, IPIC_DISPATCH=1, 
         IPIC_BURST_RD_WAIT=2, IPIC_BURST_RD_RCV=3, IPIC_BURST_RD_RCV_END=5,IPIC_BURST_RD_END=6, 
         IPIC_SINGLE_RD_WAIT=7, IPIC_SINGLE_RD_RCV=8, IPIC_SINGLE_RD_RCV_1=9, IPIC_SINGLE_RD_END=10, IPIC_SINGLE_RD_END_2 = 11,
         IPIC_SINGLE_WR_WAIT=12, IPIC_SINGLE_WR_WR=13, IPIC_SINGLE_WR_WR_1=14, IPIC_SINGLE_WR_END=15,
         IPIC_BURST_RD_SEL_WAIT=16, IPIC_BURST_RD_SEL_RCV=17, IPIC_BURST_RD_SEL_RCV_1=18,IPIC_BURST_RD_SEL_RCV_2=19,IPIC_BURST_RD_SEL_END=20,
         IPIC_BURST_WR_SEL_WAIT= 21, IPIC_BURST_WR_SEL_START= 22, IPIC_BURST_WR_SEL_START_1=23, IPIC_BURST_WR_SEL_START_2=24, IPIC_BURST_WR_SEL_START_3=25,
         IPIC_BURST_WR_SEL_START_4=26, IPIC_BURST_WR_SEL_START_5=27, IPIC_BURST_WR_SEL_START_6=28,IPIC_BURST_WR_SEL_START_7=29,
         /*IPIC_BURST_WR_SEL_WR= 21,  IPIC_BURST_WR_SEL_WR_1= 22, IPIC_BURST_WR_SEL_WR_2= 23, IPIC_BURST_WR_SEL_WR_3= 24, */
          IPIC_BURST_WR_SEL_WR_END= 30, IPIC_BURST_WR_SEL_END= 31,
          IPIC_SETZERO_WAIT= 32, IPIC_SETZERO_START=33,  IPIC_SETZERO_LAST=34,  IPIC_SERZERO_END=35,  IPIC_SERZERO_END_2=36,
          IPIC_ERROR=37;

    
    //First Stage of IPIC
    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin 
            curr_ipic_state <= IPIC_IDLE;
        end else
            curr_ipic_state <= next_ipic_state; 
    end
    
    //Second Stage of IPIC
    always @ (curr_ipic_state)//ipic_start or bus2ip_mst_cmdack or bus2ip_mst_cmplt or /*bus2ip_mstrd_src_rdy_n or bus2ip_mstwr_dst_rdy_n  or*/ curr_ipic_state)
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
                    `BURST_RD: begin
                        next_ipic_state <= IPIC_BURST_RD_WAIT;//IPIC_BURST_RD_PRE;
                    end                    
                    `SINGLE_RD: begin
                        next_ipic_state <= IPIC_SINGLE_RD_WAIT;
                    end
                    `SINGLE_WR: begin
                        next_ipic_state <= IPIC_SINGLE_WR_WAIT;
                    end
                    default: begin
                        next_ipic_state <= IPIC_ERROR;
                    end 
                endcase
            end //end IPIC_IDLE
   
            //--------------------------------------------------------
            // Burst Read
            //--------------------------------------------------------                
            IPIC_BURST_RD_WAIT: begin
                if ( bus2ip_mst_cmdack ) 
                    next_ipic_state <= IPIC_BURST_RD_RCV;
                else
                    next_ipic_state <= IPIC_BURST_RD_WAIT;
            end
            IPIC_BURST_RD_RCV: begin
                if (read_beat_idx < read_beat_lenghth)
                    next_ipic_state <= IPIC_BURST_RD_RCV;
                else
                    next_ipic_state <= IPIC_BURST_RD_RCV_END;
            end
            IPIC_BURST_RD_RCV_END: begin
                if( bus2ip_mst_cmplt )
                    next_ipic_state <= IPIC_BURST_RD_END;    
                else
                    next_ipic_state <= IPIC_BURST_RD_RCV_END;                
            end
            IPIC_BURST_RD_END: begin  
                next_ipic_state <= IPIC_IDLE;  
            end                        

            
            //--------------------------------------------------------
            // Single Read
            //--------------------------------------------------------
//            IPIC_SINGLE_RD_PRE: begin
//                next_ipic_state <= IPIC_SINGLE_RD_WAIT;
//            end
            IPIC_SINGLE_RD_WAIT: begin
                if ( bus2ip_mst_cmdack ) 
                    next_ipic_state <= IPIC_SINGLE_RD_RCV;     
                else
                    next_ipic_state <= IPIC_SINGLE_RD_WAIT;
            end
            IPIC_SINGLE_RD_RCV: begin
                if (!bus2ip_mstrd_src_rdy_n )
                    next_ipic_state <= IPIC_SINGLE_RD_RCV_1;   
                else
                    next_ipic_state <= IPIC_SINGLE_RD_RCV;
            end
            IPIC_SINGLE_RD_RCV_1: begin
                next_ipic_state <= IPIC_SINGLE_RD_END;
            end
            IPIC_SINGLE_RD_END:begin
                if (bus2ip_mst_cmplt)
                    next_ipic_state <= IPIC_SINGLE_RD_END_2;
                else
                    next_ipic_state <= IPIC_SINGLE_RD_END;   
            end
            IPIC_SINGLE_RD_END_2: begin
                next_ipic_state <= IPIC_IDLE;
            end

            //--------------------------------------------------------
            // Single Write
            //--------------------------------------------------------
//            IPIC_SINGLE_WR_PRE: begin
//                next_ipic_state <= IPIC_SINGLE_WR_WAIT;                 
//            end
            IPIC_SINGLE_WR_WAIT: begin
                if ( bus2ip_mst_cmdack ) 
                    next_ipic_state <= IPIC_SINGLE_WR_WR;
                else 
                    next_ipic_state <= IPIC_SINGLE_WR_WAIT;
            end
            IPIC_SINGLE_WR_WR: begin
                if (!bus2ip_mstwr_dst_rdy_n)
                    next_ipic_state <= IPIC_SINGLE_WR_WR_1;
                else
                    next_ipic_state <= IPIC_SINGLE_WR_WR;
            end
            IPIC_SINGLE_WR_WR_1: begin
                if (bus2ip_mst_cmplt)
                    next_ipic_state <= IPIC_SINGLE_WR_END; 
                else
                    next_ipic_state <= IPIC_SINGLE_WR_WR_1;
                end
            IPIC_SINGLE_WR_END: begin
                next_ipic_state <= IPIC_IDLE;
            end
                        
            default: begin 
                next_ipic_state <= IPIC_ERROR;
            end          

        endcase
    end

        
    always @ (posedge clk)
    begin
        if ( reset_n == 0 ) begin

//            rd_burst_error <= 0;
//            rd_single_error <= 0;
            //read_burst_done <= 0;
            //ip2bus_mst_addr <= 0;
            ip2bus_mstrd_req <= 0; 
    
            ip2bus_mst_lock <= 0;
            ip2bus_mst_reset <= 0;
            ip2bus_mstwr_req <= 0; 
            //ip2bus_mst_type <= 0;
            ip2bus_mstwr_sof_n <= 1;
            ip2bus_mstwr_eof_n <= 1;
            ip2bus_mstwr_src_rdy_n <= 1;
            ip2bus_mstwr_src_dsc_n <= 1;
            ip2bus_mstrd_dst_rdy_n <= 1;
            ip2bus_mstrd_dst_dsc_n <= 1;
            ip2bus_mst_be <= 4'b1111;
           
            read_beat_idx <= 0;  
            read_beat_lenghth <= 0;
            wr_beat_idx <= 0;
            single_read_data <= 0;
            ipic_done <= 0;       
        end else begin
            case(next_ipic_state) //当三段式状�?�机的输出基于nextstate描述时，无法用同�?????个输入信号即触发当前状�?�跳转，又控制当前状态输出正确�?�辑
                IPIC_IDLE: begin
                    ipic_done <= 0; //注意！在前序的END状�?�中必须�????? ipic_done �?????1

                end //end IPIC_IDLE
                
                IPIC_DISPATCH: begin
                    
                end
             
                //--------------------------------------------------------
                // Burst Read 
                //--------------------------------------------------------                                      
                IPIC_BURST_RD_WAIT: begin
                    ip2bus_mstrd_req <= 1;
                    ip2bus_mst_type <= 1;
                    ip2bus_mst_addr <= read_addr;
                    ip2bus_mst_be <= 4'b1111;// assume the data width is 32.
                    ip2bus_mst_length <= read_length;
                    read_beat_lenghth <= (read_length >> 2);
                    read_beat_idx <= 0;
                    ip2bus_mstrd_dst_rdy_n <= 0;  
                end
                IPIC_BURST_RD_RCV: begin
                    ip2bus_mstrd_req <= 0;
                    ip2bus_mst_type <= 0;  
                    if( !bus2ip_mstrd_src_rdy_n ) begin
                        //д�����ݣ�
                        bunch_read_data[read_beat_idx +: 32] <= bus2ip_mstrd_d;
                        read_beat_idx = read_beat_idx + 1;               
                    end                  
                end
                IPIC_BURST_RD_END: begin
                    ipic_done <= 1;
                    ip2bus_mstrd_dst_rdy_n <= 1; 
                end            
 
                //--------------------------------------------------------
                // Single Read
                //--------------------------------------------------------
                IPIC_SINGLE_RD_WAIT: begin
                    ip2bus_mstrd_req <= 1;
                    ip2bus_mst_type <= 0;
                    ip2bus_mst_addr <= read_addr;
                    ip2bus_mst_be <= 4'b1111;// assumed the data width is 32.     
                    ip2bus_mstrd_dst_rdy_n <= 0;   
                end
                IPIC_SINGLE_RD_RCV: begin
                    ip2bus_mstrd_req <= 0;                   
                end
                IPIC_SINGLE_RD_RCV_1: begin
                    single_read_data <= bus2ip_mstrd_d;
                    ip2bus_mstrd_dst_rdy_n <= 1;                     
                end
                IPIC_SINGLE_RD_END: begin
 
                end
                IPIC_SINGLE_RD_END_2: begin
                    ipic_done <= 1;
                end
                //--------------------------------------------------------
                // Single Write
                //--------------------------------------------------------

                IPIC_SINGLE_WR_WAIT: begin
                    ip2bus_mstwr_d <= write_data;
                    ip2bus_mstwr_req <= 1;
                    ip2bus_mst_type <= 0;
                    ip2bus_mst_addr <= write_addr;
                    ip2bus_mst_be <= 4'b1111;
                    
                    ip2bus_mstwr_rem = 0;
                    ip2bus_mstwr_sof_n <= 0;
                    ip2bus_mstwr_eof_n <= 0;
                    ip2bus_mstwr_src_rdy_n <= 0;                                                                             
                end
                IPIC_SINGLE_WR_WR: begin
                    ip2bus_mstwr_req <= 0;
                
                end
                IPIC_SINGLE_WR_WR_1: begin
                    ip2bus_mstwr_sof_n <= 1;
                    ip2bus_mstwr_eof_n <= 1;
                    ip2bus_mstwr_src_rdy_n <= 1;                     
                end
                IPIC_SINGLE_WR_END: begin
                    ipic_done <= 1;                                                  
                end
                                             
                default: begin
                
                end                                                          
            endcase
        end //end if      
    end

    assign debug_len2[6] = ip2bus_mstrd_req;
    assign debug_len2[7] = ip2bus_mstwr_req;
    assign debug_len2[8] = ip2bus_mst_type;
    assign debug_len2[9] = bus2ip_mst_cmdack;
    assign debug_len2[10] = bus2ip_mst_cmplt;
    assign debug_len2[11] = bus2ip_mst_error;
    assign debug_len2[12] = bus2ip_mstrd_sof_n;
    assign debug_len2[13] = bus2ip_mstrd_eof_n;
    assign debug_len2[14] = bus2ip_mstrd_src_rdy_n;
    assign debug_len2[15] = bus2ip_mstrd_src_dsc_n;
    assign debug_len2[16] = ip2bus_mstrd_dst_rdy_n;
    assign debug_len2[17] = ip2bus_mstrd_dst_dsc_n;
    assign debug_len2[18] = ip2bus_mstwr_sof_n;
    assign debug_len2[19] = ip2bus_mstwr_eof_n;
    assign debug_len2[20] = ip2bus_mstwr_src_rdy_n;
    assign debug_len2[21] = bus2ip_mstwr_dst_rdy_n;
    assign debug_len2[22] = bus2ip_mstwr_dst_dsc_n;   
          
    
endmodule
