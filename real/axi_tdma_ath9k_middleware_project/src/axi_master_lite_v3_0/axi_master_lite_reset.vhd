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
-------------------------------------------------------------------------------
-- Filename:        axi_master_lite_reset.vhd
--
-- Description:     
--                  
-- This VHDL file implements the reset module for the AXI Master lite.                 
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
--
-- ~~~~~~
--  SK       12/16/12      -- v2.0
--  1. up reved to major version for 2013.1 Vivado release. No logic updates.
--  2. Updated the version of AXI MASTER IPIF to v3.0 in X.Y format
--  3. updated the proc common version to proc_common_v4_0
--  4. No Logic Updates
-- ^^^^^^
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;




-------------------------------------------------------------------------------

entity axi_master_lite_reset is
  port (
    
    -----------------------------------------------------------------------
    -- Clock Input
    -----------------------------------------------------------------------
    axi_aclk          : in  std_logic ;
    
    -----------------------------------------------------------------------
    -- Reset Input (active low) 
    -----------------------------------------------------------------------
    axi_aresetn       : in  std_logic ;

    
    
    -----------------------------------------------------------------------
    -- IPIC Reset Input 
    -----------------------------------------------------------------------
    ip2bus_mst_reset  : In  std_logic ; 
     
    
    
    -----------------------------------------------------------------------
    -- Combined Reset Output 
    -----------------------------------------------------------------------
    rst2ip_reset_out  : out  std_logic  
    
    );

end entity axi_master_lite_reset;


architecture implementation of axi_master_lite_reset is

attribute DowngradeIPIdentifiedWarnings: string;

attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

  
  -- Signals
  signal sig_axi_reset           : std_logic := '0';
  signal sig_ipic_reset          : std_logic := '0';
  signal sig_combined_reset      : std_logic := '0';
  
   
                      

begin --(architecture implementation)

  
  -- Assign the output port
  rst2ip_reset_out <=  sig_combined_reset;
  
  
   
  -- Generate an active high combined reset from the 
  -- axi reset input and the IPIC reset input
  sig_axi_reset          <= not(axi_aresetn);
  sig_ipic_reset         <= ip2bus_mst_reset;
    
  
  
  -------------------------------------------------------------
  -- Synchronous Process with Sync Reset
  --
  -- Label: IMP_RST_REG
  --
  -- Process Description:
  --   Implements the register for the combined reset output.
  --
  -------------------------------------------------------------
  IMP_RST_REG : process (axi_aclk)
    begin
      if (axi_aclk'event and axi_aclk = '1') then
         if (sig_axi_reset = '1') then
  
           sig_combined_reset <= '1';
  
         else
  
           sig_combined_reset <= sig_axi_reset or sig_ipic_reset;     
  
         end if; 
      end if;       
    end process IMP_RST_REG; 
  

end implementation;
