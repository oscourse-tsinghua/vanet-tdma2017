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
-- Filename:        axi_master_lite.vhd
--
-- Description:     
--                  
-- This VHDL file is the top level design file for the (Lite) AXI Master
-- design that only supports single data beat transfers. This succeeds
-- the plbv46_master_single design.                 
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
-- Revision:        $Revision: 1.1.4.1 $
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
--     DET     12/17/2010     Initial
-- ~~~~~~
--    -- Per CR587285
--     - Add _lite to AXI4 port names per DDS.
-- ^^^^^^
--
--     DET     3/9/2011     V2_00-a for EDK 13.2
-- ~~~~~~
--    -- Per CR596400
--     - Rolled core version to v3_0
--     - Fixed IPIC port bit ordering from "x to Y" to "y downto x"
-- ^^^^^^
-- ~~~~~~
--  SK       12/16/12      -- v2.0
--  1. up reved to major version for 2013.1 Vivado release. No logic updates.
--  2. Updated the version of AXI MASTER IPIF to v3.0 in X.Y format
--  3. updated the proc common version to proc_common_v4_0
--  4. No Logic Updates
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


library axi_master_lite_v3_0;
Use axi_master_lite_v3_0.axi_master_lite_reset;
Use axi_master_lite_v3_0.axi_master_lite_cntlr;



-------------------------------------------------------------------------------

entity axi_master_lite is
  generic (
     
 
    -- AXI4-Lite Parameters 
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
    m_axi_lite_aclk            : in  std_logic                           ;-- AXI4
    
    -----------------------------------------------------------------------
    -- Reset Input (active low) 
    -----------------------------------------------------------------------
    m_axi_lite_aresetn         : in  std_logic                           ;-- AXI4

    
    
    -----------------------------------------------------------------------
    -- Master Detected Error output 
    -----------------------------------------------------------------------
    md_error                   : out std_logic                           ;-- Discrete Out
    
    
     
     
    ----------------------------------------------------------------------------
    -- AXI4 Read Channels
    ----------------------------------------------------------------------------
    --  AXI4 Read Address Channel                                          -- AXI4
    m_axi_lite_arready         : in  std_logic                           ; -- AXI4
    m_axi_lite_arvalid         : out std_logic                           ; -- AXI4
    m_axi_lite_araddr          : out std_logic_vector                      -- AXI4
                                     (C_M_AXI_LITE_ADDR_WIDTH-1 downto 0); -- AXI4
    m_axi_lite_arprot          : out std_logic_vector(2 downto 0)        ; -- AXI4
                                                                           -- AXI4
    --  AXI4 Read Data Channel                                             -- AXI4
    m_axi_lite_rready          : out std_logic                           ; -- AXI4
    m_axi_lite_rvalid          : in  std_logic                           ; -- AXI4
    m_axi_lite_rdata           : in  std_logic_vector                      -- AXI4
                                    (C_M_AXI_LITE_DATA_WIDTH-1 downto 0) ; -- AXI4
    m_axi_lite_rresp           : in  std_logic_vector(1 downto 0)        ; -- AXI4
                         


    -----------------------------------------------------------------------------
    -- AXI4 Write Channels
    -----------------------------------------------------------------------------
    -- AXI4 Write Address Channel
    m_axi_lite_awready         : in  std_logic                           ;    -- AXI4
    m_axi_lite_awvalid         : out std_logic                           ;    -- AXI4
    m_axi_lite_awaddr          : out std_logic_vector                         -- AXI4
                                     (C_M_AXI_LITE_ADDR_WIDTH-1 downto 0);    -- AXI4
    m_axi_lite_awprot          : out std_logic_vector(2 downto 0)        ;    -- AXI4
                                                                              -- AXI4
    -- AXI4 Write Data Channel                                                -- AXI4
    m_axi_lite_wready          : in  std_logic                           ;    -- AXI4
    m_axi_lite_wvalid          : out std_logic                           ;    -- AXI4
    m_axi_lite_wdata           : out std_logic_vector                         -- AXI4
                                     (C_M_AXI_LITE_DATA_WIDTH-1 downto 0);    -- AXI4
    m_axi_lite_wstrb           : out std_logic_vector                         -- AXI4
                                     ((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0);-- AXI4
                                                                              -- AXI4
    -- AXI4 Write Response Channel                                            -- AXI4
    m_axi_lite_bready          : out std_logic                           ;    -- AXI4
    m_axi_lite_bvalid          : in  std_logic                           ;    -- AXI4
    m_axi_lite_bresp           : in  std_logic_vector(1 downto 0)        ;    -- AXI4




    -----------------------------------------------------------------------------
    -- IP Master Request/Qualifers
    -----------------------------------------------------------------------------
    ip2bus_mstrd_req           : In  std_logic;                                           -- IPIC
    ip2bus_mstwr_req           : In  std_logic;                                           -- IPIC
    ip2bus_mst_addr            : in  std_logic_vector(C_M_AXI_LITE_ADDR_WIDTH-1 downto 0);    -- IPIC
    ip2bus_mst_be              : in  std_logic_vector((C_M_AXI_LITE_DATA_WIDTH/8)-1 downto 0);-- IPIC     
    ip2bus_mst_lock            : In  std_logic;                                           -- IPIC
    ip2bus_mst_reset           : In  std_logic;                                           -- IPIC
                                                                                          -- IPIC
    -----------------------------------------------------------------------------
    -- IP Request Status Reply                                                            
    -----------------------------------------------------------------------------
    bus2ip_mst_cmdack          : Out std_logic;                                           -- IPIC
    bus2ip_mst_cmplt           : Out std_logic;                                           -- IPIC
    bus2ip_mst_error           : Out std_logic;                                           -- IPIC
    bus2ip_mst_rearbitrate     : Out std_logic;                                           -- IPIC
    bus2ip_mst_cmd_timeout     : out std_logic;                                           -- IPIC
                                                                                          -- IPIC
                                                                                          -- IPIC
    -----------------------------------------------------------------------------
    -- IPIC Read data                                                                     
    -----------------------------------------------------------------------------
    bus2ip_mstrd_d             : out std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0);-- IPIC
    bus2ip_mstrd_src_rdy_n     : Out std_logic;                                           -- IPIC
                                                                                          -- IPIC
    -----------------------------------------------------------------------------
    -- IPIC Write data                                                                    
    -----------------------------------------------------------------------------
    ip2bus_mstwr_d             : In  std_logic_vector(C_M_AXI_LITE_DATA_WIDTH-1 downto 0);-- IPIC
    bus2ip_mstwr_dst_rdy_n     : Out  std_logic                                           -- IPIC
                                               
    );

end entity axi_master_lite;


architecture implementation of axi_master_lite is

attribute DowngradeIPIdentifiedWarnings: string;

attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

  
  -- Signals
  signal sig_master_reset        : std_logic := '0';
  
  
  
   
                      

begin --(architecture implementation)

   
       
  ------------------------------------------------------------
  -- Instance: I_RESET_MODULE 
  --
  -- Description:
  --   Instance for the Reset Module  
  --
  ------------------------------------------------------------
  I_RESET_MODULE : entity axi_master_lite_v3_0.axi_master_lite_reset
  port map (
    
    -- Clock Input
    axi_aclk          => m_axi_lite_aclk    , 
    
    -- Reset Input (active low) 
    axi_aresetn       => m_axi_lite_aresetn , 
    
    -- IPIC Reset Input 
    ip2bus_mst_reset  => ip2bus_mst_reset   ,  
    
    -- Combined Reset Output 
    rst2ip_reset_out  => sig_master_reset     
    
    );
  

          
          
          
       
  ------------------------------------------------------------
  -- Instance: I_RD_WR_CNTLR 
  --
  -- Description:
  --   Instance for the Read/Write Controller Module  
  --
  ------------------------------------------------------------
  I_RD_WR_CNTLR : entity axi_master_lite_v3_0.axi_master_lite_cntlr
  generic map (
   
    C_M_AXI_LITE_ADDR_WIDTH => C_M_AXI_LITE_ADDR_WIDTH,   
    C_M_AXI_LITE_DATA_WIDTH => C_M_AXI_LITE_DATA_WIDTH,  
    C_FAMILY                => C_FAMILY
    
    )
  port map (

    -----------------------------------
    -- Clock Input
    -----------------------------------
    axi_aclk        => m_axi_lite_aclk ,            
    
    -----------------------------------
    -- Reset Input (active high) 
    -----------------------------------
    axi_reset      =>  sig_master_reset,             

    
    
    -----------------------------------
    -- Master Detected Error output 
    -----------------------------------
    md_error       =>  md_error        ,             
    
    
     
     
    -----------------------------------
    -- AXI4 Read Channels
    -----------------------------------
    --  AXI4 Read Address Channel      
    m_axi_arready  => m_axi_lite_arready ,
    m_axi_arvalid  => m_axi_lite_arvalid ,
    m_axi_araddr   => m_axi_lite_araddr  ,
    m_axi_arprot   => m_axi_lite_arprot  ,
                                      
    --  AXI4 Read Data Channel         
    m_axi_rready   => m_axi_lite_rready  , 
    m_axi_rvalid   => m_axi_lite_rvalid  , 
    m_axi_rdata    => m_axi_lite_rdata   , 
    m_axi_rresp    => m_axi_lite_rresp   , 
                               


    -----------------------------------
    -- AXI4 Write Channels
    -----------------------------------
    -- AXI4 Write Address Channel
    m_axi_awready  => m_axi_lite_awready ,      
    m_axi_awvalid  => m_axi_lite_awvalid ,      
    m_axi_awaddr   => m_axi_lite_awaddr  ,      
    m_axi_awprot   => m_axi_lite_awprot  ,      
                                                                              
    -- AXI4 Write Data Channel                                                
    m_axi_wready   => m_axi_lite_wready  ,      
    m_axi_wvalid   => m_axi_lite_wvalid  ,      
    m_axi_wdata    => m_axi_lite_wdata   ,      
    m_axi_wstrb    => m_axi_lite_wstrb   ,      
                                                                              
    -- AXI4 Write Response Channel                                            
    m_axi_bready   => m_axi_lite_bready  ,      
    m_axi_bvalid   => m_axi_lite_bvalid  ,      
    m_axi_bresp    => m_axi_lite_bresp   ,      




    -----------------------------------
    -- IP Master Request/Qualifers
    -----------------------------------
    ip2bus_mstrd_req        => ip2bus_mstrd_req   ,         
    ip2bus_mstwr_req        => ip2bus_mstwr_req   ,         
    ip2bus_mst_addr         => ip2bus_mst_addr    ,         
    ip2bus_mst_be           => ip2bus_mst_be      ,              
    ip2bus_mst_lock         => ip2bus_mst_lock    ,         
                                    
    -----------------------------------
    -- IP Request Status Reply                  
    -----------------------------------
    bus2ip_mst_cmdack       => bus2ip_mst_cmdack       ,    
    bus2ip_mst_cmplt        => bus2ip_mst_cmplt        ,    
    bus2ip_mst_error        => bus2ip_mst_error        ,    
    bus2ip_mst_rearbitrate  => bus2ip_mst_rearbitrate  ,    
    bus2ip_mst_cmd_timeout  => bus2ip_mst_cmd_timeout  ,    
                               
                               
    -----------------------------------
    -- IPIC Read data                           
    -----------------------------------
    bus2ip_mstrd_d          => bus2ip_mstrd_d          ,    
    bus2ip_mstrd_src_rdy_n  => bus2ip_mstrd_src_rdy_n  ,    
                               
    ----------------------------------
    -- IPIC Write data                         
    ----------------------------------
    ip2bus_mstwr_d          => ip2bus_mstwr_d          ,    
    bus2ip_mstwr_dst_rdy_n  => bus2ip_mstwr_dst_rdy_n      
    
    );

        
        
          
          
          
end implementation;
