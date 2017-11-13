-------------------------------------------------------------------
-- (c) Copyright 1984 - 2012 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-------------------------------------------------------------------
-- Filename:        axi_master_lite_cntlr.vhd
--
-- Description:     
--                  
-- This VHDL file is the design implementation for the Read/Write Controller
-- that is part of the AXI Master Lite core.                 
--                  
--                  
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--
--               axi_master_lite.vhd (v3_0)
--                   |
--                   |- axi_master_lite_cntlr.vhd
--                   |      |- axi_master_lite_pulse_gen.vhd
--                   |
--                   |- axi_master_lite_reset.vhd
--
-------------------------------------------------------------------------------
-- Author:          DET
-- Revision:        $Revision: 1.0 $
-- Date:            $12/01/2010$
--
-- History:
--   DET   12/01/2010       Initial Version
--
--     DET     12/14/2010     Initial
-- ~~~~~~
--    -- Per CR587090
--     - Removed the input port m_axi_rlast. It is not part of the AXI4-Lite
--       signal set. 
-- ^^^^^^
--
--     DET     12/15/2010     Initial
-- ~~~~~~
--    -- Per CR587194
--     - Fixed the Bus2IP_Error assertion logic.
-- ^^^^^^
-- ~~~~~~
--  SK       12/16/12      -- v2.0
--  1. up reved to major version for 2013.1 Vivado release. No logic updates.
--  2. Updated the version of AXI MASTER IPIF to v3.0 in X.Y format
--  3. updated the proc common version to proc_common_v4_0
--  4. No Logic Updates
-- ^^^^^^
--
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library proc_common_v4_0;
Use proc_common_v4_0.proc_common_pkg.all; 
Use proc_common_v4_0.family_support.all;              




-------------------------------------------------------------------------------

entity axi_master_lite_cntlr is
  generic (
     
 
 -- AXI4 Parameters 
     
    C_M_AXI_LITE_ADDR_WIDTH : INTEGER range 32 to 32 := 32;  
      --  width of AXI4 Address Bus (in bits)
             
    C_M_AXI_LITE_DATA_WIDTH : INTEGER range 32 to 32 := 32;  
      --  Width of the AXI4 Data Bus (in bits)
             
 -- FPGA Family Parameter      
     
    C_FAMILY               : String := "virtex7"
      -- Select the target architecture type
      -- see the family.vhd package in the proc_common
      -- library
    );
  port (
    
    -----------------------------------------------------------------------
    -- Clock Input
    -----------------------------------------------------------------------
    axi_aclk                    : in  std_logic                           ;-- AXI4
    
    -----------------------------------------------------------------------
    -- Reset Input (active high) 
    -----------------------------------------------------------------------
    axi_reset                   : in  std_logic                           ;-- AXI4

    
    
    -----------------------------------------------------------------------
    -- Master Detected Error output 
    -----------------------------------------------------------------------
    md_error                    : out std_logic                           ;-- Discrete Out
    
    
     
     
    ----------------------------------------------------------------------------
    -- AXI4 Read Channels
    ----------------------------------------------------------------------------
    --  AXI4 Read Address Channel                                           -- AXI4
    m_axi_arready               : in  std_logic                           ; -- AXI4
    m_axi_arvalid               : out std_logic                           ; -- AXI4
    m_axi_araddr                : out std_logic_vector                      -- AXI4
                                      (C_M_AXI_LITE_ADDR_WIDTH-1 downto 0); -- AXI4
    m_axi_arprot                : out std_logic_vector(2 downto 0)        ; -- AXI4
                                                                            -- AXI4
    --  AXI4 Read Data Channel                                              -- AXI4
    m_axi_rready                : out std_logic                           ; -- AXI4
    m_axi_rvalid                : in  std_logic                           ; -- AXI4
    m_axi_rdata                 : in  std_logic_vector                      -- AXI4
                                      (C_M_AXI_LITE_DATA_WIDTH-1 downto 0); -- AXI4
    m_axi_rresp                 : in  std_logic_vector(1 downto 0)        ; -- AXI4
                               


    -----------------------------------------------------------------------------
    -- AXI4 Write Channels
    -----------------------------------------------------------------------------
    -- AXI4 Write Address Channel
    m_axi_awready               : in  std_logic                         ;      -- AXI4
    m_axi_awvalid               : out std_logic                         ;      -- AXI4
    m_axi_awaddr                : out std_logic_vector                         -- AXI4
                                      (C_M_AXI_LITE_ADDR_WIDTH-1 downto 0);    -- AXI4
    m_axi_awprot                : out std_logic_vector(2 downto 0)      ;      -- AXI4
                                                                               -- AXI4
    -- AXI4 Write Data Channel                                                 -- AXI4
    m_axi_wready                : in  std_logic                         ;      -- AXI4
    m_axi_wvalid                : out std_logic                         ;      -- AXI4
    m_axi_wdata                 : out std_logic_vector                         -- AXI4
                                      (C_M_AXI_LITE_DATA_WIDTH-1 downto 0);    -- AXI4
    m_axi_wstrb                 : out std_logic_vector                         -- AXI4
                                      ((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0);-- AXI4
                                                                               -- AXI4
    -- AXI4 Write Response Channel                                             -- AXI4
    m_axi_bready                : out std_logic                         ;      -- AXI4
    m_axi_bvalid                : in  std_logic                         ;      -- AXI4
    m_axi_bresp                 : in  std_logic_vector(1 downto 0)      ;      -- AXI4




    -----------------------------------------------------------------------------
    -- IP Master Request/Qualifers
    -----------------------------------------------------------------------------
    ip2bus_mstrd_req           : In  std_logic;                                               -- IPIC
    ip2bus_mstwr_req           : In  std_logic;                                               -- IPIC
    ip2bus_mst_addr            : in  std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0);    -- IPIC
    ip2bus_mst_be              : in  std_logic_vector((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0);-- IPIC     
    ip2bus_mst_lock            : In  std_logic;                                               -- IPIC
                                                                                              -- IPIC
    -----------------------------------------------------------------------------
    -- IP Request Status Reply                                                            
    -----------------------------------------------------------------------------
    bus2ip_mst_cmdack          : Out std_logic;                                               -- IPIC
    bus2ip_mst_cmplt           : Out std_logic;                                               -- IPIC
    bus2ip_mst_error           : Out std_logic;                                               -- IPIC
    bus2ip_mst_rearbitrate     : Out std_logic;                                               -- IPIC
    bus2ip_mst_cmd_timeout     : out std_logic;                                               -- IPIC
                                                                                              -- IPIC
                                                                                              -- IPIC
    -----------------------------------------------------------------------------
    -- IPIC Read data                                                                     
    -----------------------------------------------------------------------------
    bus2ip_mstrd_d             : out std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0);    -- IPIC
    bus2ip_mstrd_src_rdy_n     : Out std_logic;                                               -- IPIC
                                                                                              -- IPIC
    -----------------------------------------------------------------------------
    -- IPIC Write data                                                                    
    -----------------------------------------------------------------------------
    ip2bus_mstwr_d             : In  std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0);    -- IPIC
    bus2ip_mstwr_dst_rdy_n     : Out std_logic                                                -- IPIC
    );

end entity axi_master_lite_cntlr;


architecture implementation of axi_master_lite_cntlr is

attribute DowngradeIPIdentifiedWarnings: string;

attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";
  
  
  
  -- Signal declarations ---------------------------------------
  
  --  AXI4 Read Address Channel                               
  signal sig_m_axi_arready       : std_logic := '0';
  signal sig_m_axi_arvalid       : std_logic := '0';
  signal sig_m_axi_araddr        : std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal sig_m_axi_arprot        : std_logic_vector(2 downto 0) := (others => '0') ;
                                                                 
  --  AXI4 Read Data Channel                          
  signal sig_m_axi_rready        : std_logic := '0';
  signal sig_m_axi_rvalid        : std_logic := '0';
  signal sig_m_axi_rdata         : std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0');
  signal sig_m_axi_rresp         : std_logic_vector(1 downto 0) := (others => '0');
 
    --  Write Address Channel                                
  signal sig_m_axi_awready       : std_logic := '0';      
  signal sig_m_axi_awvalid       : std_logic := '0';      
  signal sig_m_axi_awaddr        : std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0'); 
  signal sig_m_axi_awprot        : std_logic_vector(2 downto 0) := (others => '0');      
    
    --  Write Data Channel                                         
  signal sig_m_axi_wready        : std_logic := '0';      
  signal sig_m_axi_wvalid        : std_logic := '0';      
  signal sig_m_axi_wdata         : std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0');    
  signal sig_m_axi_wstrb         : std_logic_vector((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0) := (others => '0');
    
    --  Write Response Channel                                     
  signal sig_m_axi_bready        : std_logic := '0';      
  signal sig_m_axi_bvalid        : std_logic := '0';      
  signal sig_m_axi_bresp         : std_logic_vector(1 downto 0) := (others => '0');      

 
 
  -- IP Master Request Qualifers
  signal sig_ip2bus_rd_req       : std_logic := '0';                                           
  signal sig_ip2bus_wr_req       : std_logic := '0';                                           
  signal sig_ip2bus_addr         : std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0');    
  signal sig_ip2bus_addr_reg     : std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0');    
  signal sig_ip2bus_be           : std_logic_vector((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0) := (others => '0');     
  signal sig_ip2bus_lock         : std_logic := '0';                                           
 
  
  --  IPIC Status Reply                               
  signal sig_bus2ip_cmdack       : std_logic := '0';
  signal sig_bus2ip_rearbitrate  : std_logic := '0';
  signal sig_bus2ip_cmd_timeout  : std_logic := '0';
  signal sig_bus2ip_cmplt        : std_logic := '0';
  signal sig_bus2ip_error        : std_logic := '0';
            
  --  IPIC Data Interface                               
  signal sig_bus2ip_mstrd_d      : std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0');  
  signal sig_bus2ip_rd_src_rdy   : std_logic := '0';
  signal sig_ip2bus_mstwr_d      : std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0'); 
  signal sig_bus2ip_wr_dst_rdy   : std_logic := '0';
  
  --  AXI Error Response                               
  signal sig_read_resp_error     : std_logic := '0';
  signal sig_read_error          : std_logic := '0';
  signal sig_write_resp_error    : std_logic := '0';
  signal sig_write_error         : std_logic := '0';
  
  --  Transfer completion                               
  signal sig_rd_addrqual_taken   : std_logic := '0';
  signal sig_wr_addrqual_taken   : std_logic := '0';
  signal sig_rd_data_taken       : std_logic := '0';
  signal sig_wr_data_taken       : std_logic := '0';
  signal sig_wr_resp_taken       : std_logic := '0';
 
  --  Transfer Startup                               
  signal sig_rd_start            : std_logic := '0';
  signal sig_wr_start            : std_logic := '0';
  signal sig_ld_addr             : std_logic := '0';
 
  --  Read Transfer sequence                               
  signal sig_rd_req_reg          : std_logic := '0';
  signal sig_rd_in_prog          : std_logic := '0';
  signal sig_rd_addr_cmplt       : std_logic := '0';
  signal sig_rd_data_cmplt       : std_logic := '0';
  signal sig_rd_cmplt            : std_logic := '0';
  
  --  Write Transfer sequence                               
  signal sig_wr_req_reg          : std_logic := '0';
  signal sig_wr_in_prog          : std_logic := '0';
  signal sig_wr_addr_cmplt       : std_logic := '0';
  signal sig_wr_data_cmplt       : std_logic := '0';
  signal sig_wr_resp_cmplt       : std_logic := '0';
  signal sig_wr_cmplt            : std_logic := '0';
  
  --  Command Completion                               
  signal sig_bus2ip_cmplt_local  : std_logic := '0';
  
  -- Detected error
  signal sig_md_error            : std_logic := '0';
  
  
  
  
  
  ----------------------------------------------------------------
  -- Register duplication attribute assignments to control fanout
  -- on register clear signals
  ----------------------------------------------------------------

  Attribute KEEP : string; -- declaration
  Attribute EQUIVALENT_REGISTER_REMOVAL : string; -- declaration
  
  Attribute KEEP of sig_bus2ip_cmplt_local    : signal is "TRUE";
  Attribute KEEP of sig_bus2ip_cmplt          : signal is "TRUE";
  
  Attribute EQUIVALENT_REGISTER_REMOVAL of sig_bus2ip_cmplt_local : signal is "no";
  Attribute EQUIVALENT_REGISTER_REMOVAL of sig_bus2ip_cmplt       : signal is "no";



  

begin --(architecture implementation)

   
  -----------------------------------------------------------------------------
  -- Port Assignments
  -----------------------------------------------------------------------------
  
  -- Read Address Channel port assignments
  sig_m_axi_arready  <= m_axi_arready     ;
  m_axi_arvalid      <= sig_m_axi_arvalid ;
  m_axi_araddr       <= sig_m_axi_araddr  ;
  m_axi_arprot       <= sig_m_axi_arprot  ;
  
  
  -- Read Data Channel port assignments
  m_axi_rready       <= sig_m_axi_rready  ;
  sig_m_axi_rvalid   <= m_axi_rvalid      ;
  sig_m_axi_rdata    <= m_axi_rdata       ;
  sig_m_axi_rresp    <= m_axi_rresp       ;
  
   
  -- Write Address Channel port assignments
  sig_m_axi_awready  <= m_axi_awready     ; 
  m_axi_awvalid      <= sig_m_axi_awvalid ;
  m_axi_awaddr       <= sig_m_axi_awaddr  ;
  m_axi_awprot       <= sig_m_axi_awprot  ;
   
   
  -- AXI4 Write Data Channel port assignments
  sig_m_axi_wready   <= m_axi_wready      ;
  m_axi_wvalid       <= sig_m_axi_wvalid  ;
  m_axi_wdata        <= sig_m_axi_wdata   ;
  m_axi_wstrb        <= sig_m_axi_wstrb   ;
  
   
  -- AXI4 Write Response Channel port assignments
  m_axi_bready       <= sig_m_axi_bready  ;
  sig_m_axi_bvalid   <= m_axi_bvalid      ;
  sig_m_axi_bresp    <= m_axi_bresp       ;
   
  
  
     
  -- IPIC Command Qualifiers
  sig_ip2bus_rd_req      <=  ip2bus_mstrd_req      ; -- Input
  sig_ip2bus_wr_req      <=  ip2bus_mstwr_req      ; -- Input
  sig_ip2bus_addr        <=  ip2bus_mst_addr       ; -- Input
  sig_ip2bus_be          <=  ip2bus_mst_be         ; -- Input
  sig_ip2bus_lock        <=  ip2bus_mst_lock       ; -- Input
   
  -- IPIC Status reply 
  bus2ip_mst_cmdack      <= sig_bus2ip_cmdack      ; -- output
  bus2ip_mst_rearbitrate <= sig_bus2ip_rearbitrate ; -- output
  bus2ip_mst_cmd_timeout <= sig_bus2ip_cmd_timeout ; -- output
  bus2ip_mst_cmplt       <= sig_bus2ip_cmplt       ; -- output
  bus2ip_mst_error       <= sig_bus2ip_error       ; -- output
    
  
  
  -- IPIC Read Data IF 
  bus2ip_mstrd_d         <= sig_bus2ip_mstrd_d        ; -- output
  bus2ip_mstrd_src_rdy_n <= not(sig_bus2ip_rd_src_rdy); -- output
  
  
  -- IPIC write Data IF 
  sig_ip2bus_mstwr_d     <= ip2bus_mstwr_d            ; -- input 
  bus2ip_mstwr_dst_rdy_n <= not(sig_bus2ip_wr_dst_rdy); -- output 
  
  
  
  -- MD Error output
  md_error               <= sig_md_error              ; -- output
  
  
  -- IPIC Error status output
  sig_bus2ip_error       <= sig_read_error or -- Assert on either a read
                            sig_write_error ; -- or write error detection          
  
  
    
    
  
  -----------------------------------------------------------------------------
  -- Combinitorial logic
  -----------------------------------------------------------------------------
  
   
   
  -- Drive the IPIC Rearbitrate and Timeout to zeros
  sig_bus2ip_rearbitrate <= '0'                    ; -- not available in AXI4
  sig_bus2ip_cmd_timeout <= '0'                    ; -- not available in AXI4

  
  -- Drive the axi protection qualifiers to zeros
  sig_m_axi_awprot       <= (others => '0')        ; -- always driven to zeros
  sig_m_axi_arprot       <= (others => '0')        ; -- always driven to zeros
  
  
  -- Share the address register for both read and write xfers
  sig_m_axi_araddr       <= sig_ip2bus_addr_reg    ;
  sig_m_axi_awaddr       <= sig_ip2bus_addr_reg    ;
  
  
  
  
  -- Detect when the read address has been accepted on the axi bus
  sig_rd_addrqual_taken  <= sig_m_axi_arvalid and
                            sig_m_axi_arready      ;
  
  -- Detect when the write address has been accepted axi bus
  sig_wr_addrqual_taken  <= sig_m_axi_awvalid and
                            sig_m_axi_awready      ;
  
  -- Detect when the read data has been accepted axi bus
  sig_rd_data_taken      <= sig_m_axi_rvalid and
                            sig_m_axi_rready       ;
  
  -- Detect when the write data has been accepted axi bus
  sig_wr_data_taken      <= sig_m_axi_wvalid and
                            sig_m_axi_wready       ;
  
  -- Detect when the write response has been accepted axi bus
  sig_wr_resp_taken      <= sig_m_axi_bvalid and    
                            sig_m_axi_bready       ; 
                            
                            
 
  -- Detirmine if a read response error is being flagged
  sig_read_resp_error  <= '1'
    when (sig_m_axi_rresp(0) = '1' or
          sig_m_axi_rresp(1) = '1')
    else '0';
 
 
  
  -- Detirmine if a write response error is being flagged
  sig_write_resp_error  <= '1'
    when (sig_m_axi_bresp(0) = '1' or
          sig_m_axi_bresp(1) = '1')
    else '0';
 
  
  
  -- Detirmine if a read transfer sequence has completed
  -- or is about to complete
  sig_rd_cmplt <= sig_rd_in_prog          and
                  (sig_rd_addr_cmplt or
                   sig_rd_addrqual_taken) and
                  (sig_rd_data_cmplt or
                   sig_rd_data_taken);
  
  
  
  -- Detirmine if a write transfer sequence has completed
  -- or is about to complete
  sig_wr_cmplt <= sig_wr_in_prog          and
                  (sig_wr_addr_cmplt or
                   sig_wr_addrqual_taken) and
                  (sig_wr_data_cmplt or
                   sig_wr_data_taken)     and
                  (sig_wr_resp_cmplt or
                   sig_wr_resp_taken);
  
 
  -- Generate the Command Address sample and hold signal
  sig_ld_addr            <= sig_rd_start or 
                            sig_wr_start;
 
 
 
  -- Detect rising edge of new read command
  sig_rd_start <=  sig_ip2bus_rd_req and
                   not(sig_rd_req_reg);
 
 
  -- Detect rising edge of new write command
  sig_wr_start <=  sig_ip2bus_wr_req and
                   not(sig_wr_req_reg);
 
 
 
 
 
 
    
                                              
  -----------------------------------------------------------------------------
  -- Command Start detection
  -----------------------------------------------------------------------------
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RDREQ_REG
  --
  -- Process Description:
  --   Registers the IPIC read request input.
  --
  -------------------------------------------------------------
  IMP_RDREQ_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset  = '1') then
  
           sig_rd_req_reg  <= '0' ;

         else
  
           sig_rd_req_reg  <= sig_ip2bus_rd_req ;
  
         end if; 
      end if;       
    end process IMP_RDREQ_REG; 
  
  
  
  
  
  
   
   
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WRREQ_REG
  --
  -- Process Description:
  --   Registers the IPIC write request input.
  --
  -------------------------------------------------------------
  IMP_WRREQ_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset  = '1') then
  
           sig_wr_req_reg  <= '0' ;

         else
  
           sig_wr_req_reg  <= sig_ip2bus_wr_req ;
  
         end if; 
      end if;       
    end process IMP_WRREQ_REG; 
  
  
  
  
  
   
   
   
   
  
    
    
  -----------------------------------------------------------------------------
  -- shared Address Register
  -----------------------------------------------------------------------------
  
   
   
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_ADDR_REG
  --
  -- Process Description:
  --   Registers the IPIC addres input whenever a new command
  -- has been detected.
  --
  -------------------------------------------------------------
  IMP_ADDR_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_ip2bus_addr_reg  <= (others => '0') ;

         elsif (sig_ld_addr = '1') then
  
           sig_ip2bus_addr_reg  <= sig_ip2bus_addr ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_ADDR_REG; 
  
  
  
  
  
  
   
   
   
   
   
   
  
  
  -----------------------------------------------------------------------------
  -- Generate Write Transfer Registers and Control
  -----------------------------------------------------------------------------
  
 
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WRITE_IN_PROG_FLOP
  --
  -- Process Description:
  --   Implements the read in progress flop.
  --
  -------------------------------------------------------------
  IMP_WRITE_IN_PROG_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_wr_in_prog  <= '0' ;

         elsif (sig_wr_start = '1') then
  
           sig_wr_in_prog  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WRITE_IN_PROG_FLOP; 
  
  
  
  
 
  
 
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_AWVALID_FLOP
  --
  -- Process Description:
  --   Implements the write awvalid flop.
  --
  -------------------------------------------------------------
  IMP_AWVALID_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset             = '1' or
             sig_wr_addrqual_taken = '1') then
  
           sig_m_axi_awvalid  <= '0' ;

         elsif (sig_wr_start = '1') then
  
           sig_m_axi_awvalid  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_AWVALID_FLOP; 
  
  
  
  
 
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WVALID_FLOP
  --
  -- Process Description:
  --   Implements the write wvalid flop.
  --
  -------------------------------------------------------------
  IMP_WVALID_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset         = '1' or
             sig_wr_data_taken = '1') then
  
           sig_m_axi_wvalid  <= '0' ;

         elsif (sig_wr_start = '1') then
  
           sig_m_axi_wvalid  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WVALID_FLOP; 
  
  
  
  
 
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WDATA_REG
  --
  -- Process Description:
  --   Implements the write data register.
  --
  -------------------------------------------------------------
  IMP_WDATA_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset  = '1') then
  
           sig_m_axi_wdata  <= (others => '0') ;
           sig_m_axi_wstrb  <= (others => '0') ;

         elsif (sig_wr_start = '1') then
  
           sig_m_axi_wdata  <= sig_ip2bus_mstwr_d ;
           sig_m_axi_wstrb  <= sig_ip2bus_be      ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WDATA_REG; 
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_ERR_REG
  --
  -- Process Description:
  --   Implements the read response error flag.
  --
  -------------------------------------------------------------
  IMP_WR_ERR_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_write_error  <= '0' ;

         elsif (sig_wr_resp_taken = '1') then
  
           sig_write_error  <= sig_write_resp_error ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_ERR_REG; 
  
  
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_DST_RDY_FLAG
  --
  -- Process Description:
  --   Implements the IPIC write destination ready flag.
  --
  -------------------------------------------------------------
  IMP_WR_DST_RDY_FLAG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset             = '1' or
             sig_bus2ip_wr_dst_rdy = '1') then
  
           sig_bus2ip_wr_dst_rdy  <= '0' ;

         --elsif (sig_wr_data_taken = '1') then
         elsif (sig_wr_cmplt = '1') then
  
           sig_bus2ip_wr_dst_rdy  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_DST_RDY_FLAG; 
  
  
 
 
 
 
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_BREADY_FLOP
  --
  -- Process Description:
  --   Implements the write response channel bready flop.
  --
  -------------------------------------------------------------
  IMP_WR_BREADY_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset         = '1' or
             sig_wr_resp_taken = '1') then
  
           sig_m_axi_bready  <= '0' ;

         elsif (sig_wr_start = '1') then
  
           sig_m_axi_bready  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_BREADY_FLOP; 
  
  
  
  
 
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_ADDR_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the write address complete flag.
  --
  -------------------------------------------------------------
  IMP_WR_ADDR_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_wr_addr_cmplt  <= '0' ;

         elsif (sig_wr_addrqual_taken = '1') then
  
           sig_wr_addr_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_ADDR_CMPLT_FLOP; 
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_DATA_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the write data complete flag.
  --
  -------------------------------------------------------------
  IMP_WR_DATA_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_wr_data_cmplt  <= '0' ;

         elsif (sig_wr_data_taken = '1') then
  
           sig_wr_data_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_DATA_CMPLT_FLOP; 
  
  
 
 
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_WR_RESP_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the write data complete flag.
  --
  -------------------------------------------------------------
  IMP_WR_RESP_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_wr_resp_cmplt  <= '0' ;

         elsif (sig_wr_resp_taken = '1') then
  
           sig_wr_resp_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_WR_RESP_CMPLT_FLOP; 
  
  
 
 
 
 
 
 
 
 
 
 
 
  
  
  
  
 
 
 
 
 
 
 
 
 
  
  
  -----------------------------------------------------------------------------
  -- Generate Read Transfer Registers and Control
  -----------------------------------------------------------------------------
  
  
 
 
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_READ_IN_PROG_FLOP
  --
  -- Process Description:
  --   Implements the read in progress flop.
  --
  -------------------------------------------------------------
  IMP_READ_IN_PROG_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_rd_in_prog  <= '0' ;

         elsif (sig_rd_start = '1') then
  
           sig_rd_in_prog  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_READ_IN_PROG_FLOP; 
  
  
  
  
 
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RVALID_FLOP
  --
  -- Process Description:
  --   Implements the write awvalid flop.
  --
  -------------------------------------------------------------
  IMP_RVALID_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset             = '1' or
             sig_rd_addrqual_taken = '1') then
  
           sig_m_axi_arvalid  <= '0' ;

         elsif (sig_rd_start = '1') then
  
           sig_m_axi_arvalid  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RVALID_FLOP; 
  
  
  
  
 
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RREADY_FLOP
  --
  -- Process Description:
  --   Implements the read rready flop.
  --
  -------------------------------------------------------------
  IMP_RREADY_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset         = '1' or
             sig_rd_data_taken = '1') then
  
           sig_m_axi_rready  <= '0' ;

         elsif (sig_rd_start = '1') then
  
           sig_m_axi_rready  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RREADY_FLOP; 
  
  
  
  
 
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RDATA_REG
  --
  -- Process Description:
  --   Implements the read data register.
  --
  -------------------------------------------------------------
  IMP_RDATA_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset  = '1') then
  
           sig_bus2ip_mstrd_d  <= (others => '0') ;

         elsif (sig_rd_data_taken = '1') then
  
           sig_bus2ip_mstrd_d  <= sig_m_axi_rdata ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RDATA_REG; 
  
  
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RD_SRC_RDY_FLAG
  --
  -- Process Description:
  --   Implements the IPIC read source ready flag.
  --
  -------------------------------------------------------------
  IMP_RD_SRC_RDY_FLAG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset             = '1' or
             sig_bus2ip_rd_src_rdy = '1') then
  
           sig_bus2ip_rd_src_rdy  <= '0' ;

         elsif (sig_rd_data_taken = '1') then
  
           sig_bus2ip_rd_src_rdy  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RD_SRC_RDY_FLAG; 
  
  
  
  
  
  
                    
                    
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_READ_ERR_REG
  --
  -- Process Description:
  --   Implements the read response error flag.
  --
  -------------------------------------------------------------
  IMP_READ_ERR_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_read_error  <= '0' ;

         elsif (sig_rd_data_taken = '1') then
  
           sig_read_error  <= sig_read_resp_error ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_READ_ERR_REG; 
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RD_ADDR_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the read address complete flag.
  --
  -------------------------------------------------------------
  IMP_RD_ADDR_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_rd_addr_cmplt  <= '0' ;

         elsif (sig_rd_addrqual_taken = '1') then
  
           sig_rd_addr_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RD_ADDR_CMPLT_FLOP; 
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RD_DATA_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the read data complete flag.
  --
  -------------------------------------------------------------
  IMP_RD_DATA_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_rd_data_cmplt  <= '0' ;

         elsif (sig_rd_data_taken = '1') then
  
           sig_rd_data_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_RD_DATA_CMPLT_FLOP; 
  
  
 
 
 
 
 
 
 
 
 
 
 
 
 
  
  -----------------------------------------------------------------------------
  -- IPIC Command Status Generation logic
  -----------------------------------------------------------------------------
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_CMDACK_FLOP
  --
  -- Process Description:
  --   Implements the IPIC Command Acknowledge status flag.
  --
  -------------------------------------------------------------
  IMP_CMDACK_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset         = '1' or
             sig_bus2ip_cmdack = '1') then
  
           sig_bus2ip_cmdack  <= '0' ;

         elsif (sig_rd_addrqual_taken = '1' or
                sig_wr_addrqual_taken = '1') then
  
           sig_bus2ip_cmdack  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_CMDACK_FLOP; 
  
  
  
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_CMD_CMPLT_LOCAL_FLOP
  --
  -- Process Description:
  --   Implements the IPIC Command Acknowledge status flag.
  --
  -------------------------------------------------------------
  IMP_CMD_CMPLT_LOCAL_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_bus2ip_cmplt_local  <= '0' ;

         elsif (sig_rd_cmplt = '1' or
                sig_wr_cmplt = '1') then
  
           sig_bus2ip_cmplt_local  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_CMD_CMPLT_LOCAL_FLOP; 
  
  
  
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_CMD_CMPLT_FLOP
  --
  -- Process Description:
  --   Implements the IPIC Command Acknowledge status flag.
  --
  -------------------------------------------------------------
  IMP_CMD_CMPLT_FLOP : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (axi_reset              = '1' or
             sig_bus2ip_cmplt_local = '1') then
  
           sig_bus2ip_cmplt  <= '0' ;

         elsif (sig_rd_cmplt = '1' or
                sig_wr_cmplt = '1') then
  
           sig_bus2ip_cmplt  <= '1' ;
  
         else
  
           null;  -- Hold Current State
  
         end if; 
      end if;       
    end process IMP_CMD_CMPLT_FLOP; 
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  -----------------------------------------------------------------------------
  -- Master Detected error logic
  -----------------------------------------------------------------------------
  
 
 
  
  
  
   
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: S_H_ERRORS
  --
  -- Process Description:
  --  This process implements the sample and hold logic for 
  -- any detected errors. If an error is detected, then the 
  -- md_error output signal is driven high until the Master 
  -- is reset.
  --
  -------------------------------------------------------------
  S_H_ERRORS : process (axi_aclk)
     begin
       if (axi_aclk'event and axi_aclk = '1') then
          if (axi_reset = '1') then
            
            sig_md_error <= '0';
          
          elsif (sig_read_error   = '1' or
                 sig_write_error  = '1') then
            
            sig_md_error <= '1';
          
          else
            null;  -- hold last state
          end if;        
       else
         null;
       end if;
     end process S_H_ERRORS; 

 
 

   
                 
   
  
      
 


end implementation;
