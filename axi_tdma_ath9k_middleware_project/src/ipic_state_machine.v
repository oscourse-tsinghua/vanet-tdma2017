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
        parameter integer ADDR_WIDTH = 32,
        parameter integer DATA_WIDTH = 32,
        parameter integer C_LENGTH_WIDTH = 12,
        parameter integer C_PKT_LEN = 256
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
        output reg [ADDR_WIDTH-1 : 0] ip2bus_mst_addr,
        output reg [C_LENGTH_WIDTH-1 : 0] ip2bus_mst_length,
        output reg [(DATA_WIDTH/8)-1 : 0] ip2bus_mst_be,
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
        input wire  [DATA_WIDTH-1 : 0] bus2ip_mstrd_d,
        input wire  [(DATA_WIDTH/8)-1 : 0] bus2ip_mstrd_rem,
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
        output reg [DATA_WIDTH-1 : 0] ip2bus_mstwr_d,
        output reg [(DATA_WIDTH/8)-1 : 0] ip2bus_mstwr_rem,
        output reg ip2bus_mstwr_sof_n,
        output reg ip2bus_mstwr_eof_n,
        output reg ip2bus_mstwr_src_rdy_n,
        output reg ip2bus_mstwr_src_dsc_n,
        //OUT
        input wire  bus2ip_mstwr_dst_rdy_n,
        input wire  bus2ip_mstwr_dst_dsc_n,
        
        //USER LOGIC
        input wire [2:0]ipic_type_dp,
        input wire ipic_start_dp,
        output reg ipic_ack_dp,
        output reg ipic_done_dp,
        input wire [ADDR_WIDTH-1 : 0] read_addr_dp,
        input wire [C_LENGTH_WIDTH-1 : 0] read_length_dp,
        input wire [ADDR_WIDTH-1 : 0] write_addr_dp,
        input wire [DATA_WIDTH-1 : 0] write_data_dp,
        input wire [C_LENGTH_WIDTH-1 : 0] write_length_dp,
        
        input wire [2:0]ipic_type_tc,
        input wire ipic_start_tc,
        output reg ipic_ack_tc,
        output reg ipic_done_tc,
        input wire [ADDR_WIDTH-1 : 0] read_addr_tc,
        output reg [15:0] ptr_checksum,
        input wire [ADDR_WIDTH-1 : 0] write_addr_tc,
        input wire [DATA_WIDTH-1 : 0] write_data_tc,
        input wire [C_LENGTH_WIDTH-1 : 0] write_length_tc,
        
        output reg [DATA_WIDTH-1 : 0] single_read_data,
//        output reg [2047 :0] bunch_read_data,
//        input wire [1023 : 0] bunch_write_data, //128 bytes data
        
        output reg [8:0] blk_mem_rcvpkt_addra, //32 bit * 512 
        output reg [31:0] blk_mem_rcvpkt_dina,
        output reg blk_mem_rcvpkt_wea,
        
        output reg [8:0] blk_mem_sendpkt_addrb,
        input wire [31:0] blk_mem_sendpkt_doutb,
        
        (* mark_debug = "true" *) output wire [16 : 0] debug_len2,
        output wire [12:0] debug_idx_rd,
        output wire [12:0] debug_idx_wr,
        output reg [5:0] curr_ipic_state
//        output reg rd_burst_error,
//        output reg rd_single_error       
    );
    
    reg [2:0]ipic_type;
    reg ipic_start;
    reg ipic_done;
    reg [ADDR_WIDTH-1 : 0] read_addr;
    reg [DATA_WIDTH-1 : 0] read_length;
    reg [ADDR_WIDTH-1 : 0] write_addr;
    reg [DATA_WIDTH-1 : 0] write_data;
    reg [DATA_WIDTH-1 : 0] write_length;

    reg [2:0] dispatch_state;    
    reg [2:0] dispatch_type;
    
    `define NONE    0
    `define TC  1
    `define DP  2 
    
    always @ (posedge clk)
    begin
        if (reset_n == 0) begin
            ipic_done_dp <= 0;
            ipic_done_tc <= 0;
            dispatch_state <= 0;
            dispatch_type <= `NONE;
            ipic_ack_dp <= 0;
            ipic_ack_tc <= 0;
        end else begin
            case(dispatch_state)
                0:begin
                    if (ipic_start_tc) begin
                        write_addr <= write_addr_tc;
                        write_data <= write_data_tc;
                        write_length <= write_length_tc;
                        read_addr <= read_addr_tc;
                        ipic_start <= 1;
                        ipic_ack_tc <= 1;
                        ipic_type <= ipic_type_tc;
                        dispatch_state <= 1;
                        dispatch_type <= `TC;
                    end else if (ipic_start_dp) begin 
                        read_addr <= read_addr_dp;
                        read_length <= read_length_dp;
                        write_addr <= write_addr_dp;
                        write_data <= write_data_dp;
                        write_length <= write_length_dp;
                        ipic_start <= 1;
                        ipic_ack_dp <= 1;
                        ipic_type <= ipic_type_dp;    
                        dispatch_state <= 1;
                        dispatch_type <= `DP;                   
                    end
                end
                1: begin
                    ipic_start <= 0;
                    ipic_ack_dp <= 0;
                    ipic_ack_tc <= 0;
                    if (ipic_done) begin
                        dispatch_state <= 2;
                        if (dispatch_type == `TC)
                            ipic_done_tc <= 1;
                        else if (dispatch_type == `DP)
                            ipic_done_dp <= 1;
                    end
                end
                2: begin
                    dispatch_state <= 0;
                    ipic_done_dp <= 0;
                    ipic_done_tc <= 0;
                end
                default: begin end
            endcase
        end        
    end        
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
    `define CAL_DESC_CKS 5
    
    reg [12:0] wr_beat_idx;
    reg [12:0] read_beat_idx;
    reg [12:0] read_beat_lenghth;
    reg [12 : 0] write_beat_length;
        
    reg [31:0] desc_checksum;
    
//    reg [5:0] curr_ipic_state;
    reg [5:0] next_ipic_state;

    
    localparam IPIC_IDLE=0, IPIC_DISPATCH=1, 
         IPIC_BURST_RD_WAIT=2, IPIC_BURST_RD_RCV=3, IPIC_BURST_RD_RCV_END=5,IPIC_BURST_RD_END=6, 
         IPIC_SINGLE_RD_WAIT=7, IPIC_SINGLE_RD_RCV=8, IPIC_SINGLE_RD_RCV_1=9, IPIC_SINGLE_RD_END=10, IPIC_SINGLE_RD_END_2 = 11,
         IPIC_SINGLE_WR_WAIT=12, IPIC_SINGLE_WR_WR=13, IPIC_SINGLE_WR_WR_1=14, IPIC_SINGLE_WR_END=15,
         IPIC_BURST_WR_START = 16, IPIC_BURST_WR_WAIT = 17, IPIC_BURST_WR = 18,  IPIC_BURST_WR_LAST = 19, IPIC_BURST_WR_END = 20, IPIC_BURST_WR_END_2 = 21,
IPIC_BURST_WR_DEBUG = 22,
          IPIC_SETZERO_WAIT= 32, IPIC_SETZERO_START=33,  IPIC_SETZERO_LAST=34,  IPIC_SERZERO_END=35,  IPIC_SERZERO_END_2=36,
          IPIC_CAL_CKS_WAIT = 23,  IPIC_CAL_CKS_RD_RCV=24, IPIC_CAL_CKS_RD_RCV_END=25,IPIC_CAL_CKS_RD_END=26, 
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
                        next_ipic_state <= IPIC_BURST_RD_WAIT;
                    end    
                    `BURST_WR: begin
                        next_ipic_state <= IPIC_BURST_WR_DEBUG;
                    end     
                    `SET_ZERO: begin
                        next_ipic_state <= IPIC_SETZERO_WAIT;
                    end                                
                    `SINGLE_RD: begin
                        next_ipic_state <= IPIC_SINGLE_RD_WAIT;
                    end
                    `SINGLE_WR: begin
                        next_ipic_state <= IPIC_SINGLE_WR_WAIT;
                    end
                    `CAL_DESC_CKS: begin
                         next_ipic_state <= IPIC_CAL_CKS_WAIT;
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
            // Calculate checksum of the desc.
            //-------------------------------------------------------- 
            IPIC_CAL_CKS_WAIT: begin
                if ( bus2ip_mst_cmdack ) 
                    next_ipic_state <= IPIC_CAL_CKS_RD_RCV;
                else
                    next_ipic_state <= IPIC_CAL_CKS_WAIT;
            end
            IPIC_CAL_CKS_RD_RCV: begin
                if (read_beat_idx < read_beat_lenghth)
                    next_ipic_state <= IPIC_CAL_CKS_RD_RCV;
                else
                    next_ipic_state <= IPIC_CAL_CKS_RD_RCV_END;
            end
            IPIC_CAL_CKS_RD_RCV_END: begin
                if( bus2ip_mst_cmplt )
                    next_ipic_state <= IPIC_CAL_CKS_RD_END;    
                else
                    next_ipic_state <= IPIC_CAL_CKS_RD_RCV_END;                
            end
            IPIC_CAL_CKS_RD_END: begin  
                next_ipic_state <= IPIC_IDLE;  
            end  
            
            //--------------------------------------------------------
            // Single Read
            //--------------------------------------------------------
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
            // Burst Write
            //--------------------------------------------------------   
            IPIC_BURST_WR_DEBUG: 
//                if (blk_mem_sendpkt_doutb != bunch_write_data[31:0]) //For debug
//                    next_ipic_state <= IPIC_ERROR;
//                else
                    next_ipic_state <= IPIC_BURST_WR_START;
            IPIC_BURST_WR_START: next_ipic_state <= IPIC_BURST_WR_WAIT;
            IPIC_BURST_WR_WAIT:
                if ( bus2ip_mst_cmdack )
                    next_ipic_state <= IPIC_BURST_WR;
                else
                    next_ipic_state <= IPIC_BURST_WR_WAIT;
            IPIC_BURST_WR:
                if (wr_beat_idx == write_beat_length)
                    next_ipic_state <= IPIC_BURST_WR_END;
                else
                    next_ipic_state <= IPIC_BURST_WR;
//            IPIC_BURST_WR_LAST: 
//                if (!bus2ip_mstwr_dst_rdy_n) 
//                    next_ipic_state <= IPIC_BURST_WR_END;
//                else
//                    next_ipic_state <= IPIC_BURST_WR_LAST;
            IPIC_BURST_WR_END: 
                if( bus2ip_mst_cmplt )
                    next_ipic_state <= IPIC_BURST_WR_END_2;    
                else
                    next_ipic_state <= IPIC_BURST_WR_END;  
            IPIC_BURST_WR_END_2: next_ipic_state <= IPIC_IDLE;
            
            //--------------------------------------------------------
            // Burst Write ZERO
            //--------------------------------------------------------             
            IPIC_SETZERO_WAIT: begin 
                if ( bus2ip_mst_cmdack )
                    next_ipic_state <= IPIC_SETZERO_START;
                else
                    next_ipic_state <= IPIC_SETZERO_WAIT;                   
            end
            IPIC_SETZERO_START: begin
                if (wr_beat_idx == (write_beat_length - 2 ))//ʣ���һ��beat
                    next_ipic_state <= IPIC_SETZERO_LAST;
                else
                    next_ipic_state <= IPIC_SETZERO_START;                
            end
            IPIC_SETZERO_LAST: begin
                if (!bus2ip_mstwr_dst_rdy_n)
                    next_ipic_state <= IPIC_SERZERO_END;
                else
                    next_ipic_state <= IPIC_SETZERO_LAST;                 
            end            
            IPIC_SERZERO_END: begin
                if (bus2ip_mst_cmplt) 
                    next_ipic_state <= IPIC_SERZERO_END_2;
                else
                    next_ipic_state <= IPIC_SERZERO_END;                 
            end
            IPIC_SERZERO_END_2: begin
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
            write_beat_length <= 0;
            single_read_data <= 0;
            ipic_done <= 0;
            blk_mem_rcvpkt_wea <= 0; 
            blk_mem_sendpkt_addrb <= 0;
            desc_checksum <= 0;
        end else begin
            case(next_ipic_state) //当三段式状�?�机的输出基于nextstate描述时，无法用同�????????个输入信号即触发当前状�?�跳转，又控制当前状态输出正确�?�辑
                IPIC_IDLE: begin
                    ipic_done <= 0; //注意！在前序的END状�?�中必须�???????? ipic_done �????????1
                    blk_mem_sendpkt_addrb <= 0;
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
                        blk_mem_rcvpkt_wea <= 1;
                        blk_mem_rcvpkt_dina <= bus2ip_mstrd_d[31:0];
//                        bunch_read_data[(read_beat_idx << 5) +: 32] = bus2ip_mstrd_d[31:0];
                        blk_mem_rcvpkt_addra[8:0] = read_beat_idx[8:0];
                        read_beat_idx = read_beat_idx + 1;               
                    end                  
                end
                IPIC_BURST_RD_RCV_END: blk_mem_rcvpkt_wea <= 0;
                IPIC_BURST_RD_END: begin
                    ipic_done <= 1;
                    ip2bus_mstrd_dst_rdy_n <= 1; 
                end
                
                //--------------------------------------------------------
                // Calculate checksum of the desc.
                //-------------------------------------------------------- 
                IPIC_CAL_CKS_WAIT: begin
                    ip2bus_mstrd_req <= 1;
                    ip2bus_mst_type <= 1;
                    ip2bus_mst_addr <= read_addr;
                    ip2bus_mst_be <= 4'b1111;// assume the data width is 32.
                    ip2bus_mst_length <= 40; 
                    read_beat_lenghth <= 10;
                    read_beat_idx <= 0;
                    ip2bus_mstrd_dst_rdy_n <= 0;
                    desc_checksum <= 0;
                end
                IPIC_CAL_CKS_RD_RCV: begin
                    ip2bus_mstrd_req <= 0;
                    ip2bus_mst_type <= 0;  
                    if( !bus2ip_mstrd_src_rdy_n ) begin
                        desc_checksum = desc_checksum + bus2ip_mstrd_d[31:0];
                        read_beat_idx = read_beat_idx + 1;               
                    end                  
                end
                IPIC_CAL_CKS_RD_RCV_END: ptr_checksum <= (((desc_checksum & 16'hffff) + (desc_checksum >> 16)) & 16'hffff);
                IPIC_CAL_CKS_RD_END: begin
                    ipic_done <= 1;
                    ip2bus_mstrd_dst_rdy_n <= 1; 
                end                
                
                //--------------------------------------------------------
                // Burst Write
                //--------------------------------------------------------   
                IPIC_BURST_WR_START: begin
                    ip2bus_mstwr_req <= 1;
                    ip2bus_mst_type <= 1;
                    ip2bus_mst_addr <= write_addr;
                    ip2bus_mst_length <= write_length;
                    write_beat_length <= (write_length >> 2);
                    ip2bus_mst_be <= 4'b1111;
                    
                    ip2bus_mstwr_rem = 0;
                    ip2bus_mstwr_sof_n <= 0;
                    ip2bus_mstwr_eof_n <= 1;
                    ip2bus_mstwr_src_rdy_n <= 0; 
                    
//                    ip2bus_mstwr_d[31:0] <= bunch_write_data[31:0];
                    ip2bus_mstwr_d[31:0] <= blk_mem_sendpkt_doutb;
                    wr_beat_idx <= 1;
                    blk_mem_sendpkt_addrb <= 1;                    
                end
                IPIC_BURST_WR_WAIT: begin           
                end
                IPIC_BURST_WR: begin
                    ip2bus_mstwr_req <= 0;
                    ip2bus_mst_type <= 0;  
                    if( !bus2ip_mstwr_dst_rdy_n ) begin
                        ip2bus_mstwr_sof_n <= 1;
//                        ip2bus_mstwr_d[31:0] = bunch_write_data[(wr_beat_idx << 5) +: 32];
                        ip2bus_mstwr_d[31:0] <= blk_mem_sendpkt_doutb;
                        wr_beat_idx = wr_beat_idx + 1;
                        blk_mem_sendpkt_addrb = wr_beat_idx;
                        if (wr_beat_idx == write_beat_length)
                            ip2bus_mstwr_eof_n <= 0;
                    end 
                end

//                IPIC_BURST_WR_LAST: begin
//                    ip2bus_mstwr_eof_n <= 0; 
//                    ip2bus_mstwr_d[31:0] <= bunch_write_data[(wr_beat_idx << 5) +: 32];
//                end
                IPIC_BURST_WR_END: begin
                    ip2bus_mstwr_eof_n <= 1;
                    ip2bus_mstwr_src_rdy_n <= 1; 
                    blk_mem_sendpkt_addrb <= 0;
                end
                IPIC_BURST_WR_END_2: ipic_done <= 1;
            
                //--------------------------------------------------------
                // Burst Write ZERO
                //--------------------------------------------------------             
                IPIC_SETZERO_WAIT: begin
                    ip2bus_mstwr_d <= 32'h0;
                    ip2bus_mstwr_req <= 1;
                    ip2bus_mst_type <= 1;
                    ip2bus_mst_addr <= write_addr;
                    ip2bus_mst_length <= write_length;
                    write_beat_length <= (write_length >> 2);
                    ip2bus_mst_be <= 4'b1111;
                    
                    ip2bus_mstwr_rem = 0;
                    ip2bus_mstwr_sof_n <= 0;
                    ip2bus_mstwr_eof_n <= 1;
                    ip2bus_mstwr_src_rdy_n <= 0;   
                    wr_beat_idx <= 0;                  
                end
                IPIC_SETZERO_START: begin
                    ip2bus_mstwr_req <= 0;
                    ip2bus_mst_type <= 0;   
                                   
                    if (!bus2ip_mstwr_dst_rdy_n) begin //????��bus2ip_mstwr_dst_rdy_nָʾ��һ�����ݵ����?????
                        ip2bus_mstwr_sof_n <= 1;
                        wr_beat_idx <= wr_beat_idx + 1;
                    end
                end
                IPIC_SETZERO_LAST: begin
                    ip2bus_mstwr_eof_n <= 0; 
                    if (!bus2ip_mstwr_dst_rdy_n) begin
                        wr_beat_idx <= wr_beat_idx + 1;
                         
                    end
                        
                end            
                IPIC_SERZERO_END: begin
                    ip2bus_mstwr_eof_n <= 1;
                    ip2bus_mstwr_src_rdy_n <= 1;                 
                end
                IPIC_SERZERO_END_2: begin
                    ipic_done <= 1;
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

    assign debug_len2[0] = ip2bus_mstrd_req;
    assign debug_len2[1] = ip2bus_mstwr_req;
    assign debug_len2[2] = ip2bus_mst_type;
    assign debug_len2[3] = bus2ip_mst_cmdack;
    assign debug_len2[4] = bus2ip_mst_cmplt;
    assign debug_len2[5] = bus2ip_mst_error;
    assign debug_len2[6] = bus2ip_mstrd_sof_n;
    assign debug_len2[7] = bus2ip_mstrd_eof_n;
    assign debug_len2[8] = bus2ip_mstrd_src_rdy_n;
    assign debug_len2[9] = bus2ip_mstrd_src_dsc_n;
    assign debug_len2[10] = ip2bus_mstrd_dst_rdy_n;
    assign debug_len2[11] = ip2bus_mstrd_dst_dsc_n;
    assign debug_len2[12] = ip2bus_mstwr_sof_n;
    assign debug_len2[13] = ip2bus_mstwr_eof_n;
    assign debug_len2[14] = ip2bus_mstwr_src_rdy_n;
    assign debug_len2[15] = bus2ip_mstwr_dst_rdy_n;
    assign debug_len2[16] = bus2ip_mstwr_dst_dsc_n;   

    assign debug_idx_rd[12:0] = read_beat_idx[12:0];
    assign debug_idx_wr[12:0] = wr_beat_idx[12:0];
    
endmodule
