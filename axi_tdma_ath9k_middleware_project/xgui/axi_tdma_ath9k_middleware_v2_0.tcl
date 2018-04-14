# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "FRAME_SLOT_NUM"
  ipgui::add_param $IPINST -name "SLOT_US"
  ipgui::add_param $IPINST -name "TX_GUARD_US"
  ipgui::add_param $IPINST -name "OCCUPIER_LIFE_FRAME"
  ipgui::add_param $IPINST -name "BCH_CANDIDATE_C3HOP_THRES_S1"
  ipgui::add_param $IPINST -name "BCH_CANDIDATE_C3HOP_THRES_S2"

}

proc update_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to update ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to validate ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 { PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 } {
	# Procedure called to update BCH_CANDIDATE_C3HOP_THRES_S1 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 { PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 } {
	# Procedure called to validate BCH_CANDIDATE_C3HOP_THRES_S1
	return true
}

proc update_PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 { PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 } {
	# Procedure called to update BCH_CANDIDATE_C3HOP_THRES_S2 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 { PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 } {
	# Procedure called to validate BCH_CANDIDATE_C3HOP_THRES_S2
	return true
}

proc update_PARAM_VALUE.C_ADDR_PIPE_DEPTH { PARAM_VALUE.C_ADDR_PIPE_DEPTH } {
	# Procedure called to update C_ADDR_PIPE_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_ADDR_PIPE_DEPTH { PARAM_VALUE.C_ADDR_PIPE_DEPTH } {
	# Procedure called to validate C_ADDR_PIPE_DEPTH
	return true
}

proc update_PARAM_VALUE.C_LENGTH_WIDTH { PARAM_VALUE.C_LENGTH_WIDTH } {
	# Procedure called to update C_LENGTH_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_LENGTH_WIDTH { PARAM_VALUE.C_LENGTH_WIDTH } {
	# Procedure called to validate C_LENGTH_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH } {
	# Procedure called to update C_M00_AXI_ARUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH { PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH } {
	# Procedure called to validate C_M00_AXI_ARUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH } {
	# Procedure called to update C_M00_AXI_AWUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH { PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH } {
	# Procedure called to validate C_M00_AXI_AWUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_BURST_LEN { PARAM_VALUE.C_M00_AXI_BURST_LEN } {
	# Procedure called to update C_M00_AXI_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_BURST_LEN { PARAM_VALUE.C_M00_AXI_BURST_LEN } {
	# Procedure called to validate C_M00_AXI_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_BUSER_WIDTH { PARAM_VALUE.C_M00_AXI_BUSER_WIDTH } {
	# Procedure called to update C_M00_AXI_BUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_BUSER_WIDTH { PARAM_VALUE.C_M00_AXI_BUSER_WIDTH } {
	# Procedure called to validate C_M00_AXI_BUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_ID_WIDTH { PARAM_VALUE.C_M00_AXI_ID_WIDTH } {
	# Procedure called to update C_M00_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_ID_WIDTH { PARAM_VALUE.C_M00_AXI_ID_WIDTH } {
	# Procedure called to validate C_M00_AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_RUSER_WIDTH { PARAM_VALUE.C_M00_AXI_RUSER_WIDTH } {
	# Procedure called to update C_M00_AXI_RUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_RUSER_WIDTH { PARAM_VALUE.C_M00_AXI_RUSER_WIDTH } {
	# Procedure called to validate C_M00_AXI_RUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to update C_M00_AXI_TARGET_SLAVE_BASE_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to validate C_M00_AXI_TARGET_SLAVE_BASE_ADDR
	return true
}

proc update_PARAM_VALUE.C_M00_AXI_WUSER_WIDTH { PARAM_VALUE.C_M00_AXI_WUSER_WIDTH } {
	# Procedure called to update C_M00_AXI_WUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M00_AXI_WUSER_WIDTH { PARAM_VALUE.C_M00_AXI_WUSER_WIDTH } {
	# Procedure called to validate C_M00_AXI_WUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_PKT_LEN { PARAM_VALUE.C_PKT_LEN } {
	# Procedure called to update C_PKT_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_PKT_LEN { PARAM_VALUE.C_PKT_LEN } {
	# Procedure called to validate C_PKT_LEN
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S00_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S00_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to update C_S00_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S00_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.FRAME_SLOT_NUM { PARAM_VALUE.FRAME_SLOT_NUM } {
	# Procedure called to update FRAME_SLOT_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FRAME_SLOT_NUM { PARAM_VALUE.FRAME_SLOT_NUM } {
	# Procedure called to validate FRAME_SLOT_NUM
	return true
}

proc update_PARAM_VALUE.OCCUPIER_LIFE_FRAME { PARAM_VALUE.OCCUPIER_LIFE_FRAME } {
	# Procedure called to update OCCUPIER_LIFE_FRAME when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.OCCUPIER_LIFE_FRAME { PARAM_VALUE.OCCUPIER_LIFE_FRAME } {
	# Procedure called to validate OCCUPIER_LIFE_FRAME
	return true
}

proc update_PARAM_VALUE.SLOT_US { PARAM_VALUE.SLOT_US } {
	# Procedure called to update SLOT_US when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SLOT_US { PARAM_VALUE.SLOT_US } {
	# Procedure called to validate SLOT_US
	return true
}

proc update_PARAM_VALUE.TX_GUARD_US { PARAM_VALUE.TX_GUARD_US } {
	# Procedure called to update TX_GUARD_US when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_GUARD_US { PARAM_VALUE.TX_GUARD_US } {
	# Procedure called to validate TX_GUARD_US
	return true
}


proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ADDR_WIDTH { MODELPARAM_VALUE.ADDR_WIDTH PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_WIDTH}] ${MODELPARAM_VALUE.ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR { MODELPARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR}] ${MODELPARAM_VALUE.C_M00_AXI_TARGET_SLAVE_BASE_ADDR}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_BURST_LEN { MODELPARAM_VALUE.C_M00_AXI_BURST_LEN PARAM_VALUE.C_M00_AXI_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_BURST_LEN}] ${MODELPARAM_VALUE.C_M00_AXI_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_ID_WIDTH { MODELPARAM_VALUE.C_M00_AXI_ID_WIDTH PARAM_VALUE.C_M00_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_AWUSER_WIDTH { MODELPARAM_VALUE.C_M00_AXI_AWUSER_WIDTH PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_AWUSER_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_AWUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_ARUSER_WIDTH { MODELPARAM_VALUE.C_M00_AXI_ARUSER_WIDTH PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_ARUSER_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_ARUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_WUSER_WIDTH { MODELPARAM_VALUE.C_M00_AXI_WUSER_WIDTH PARAM_VALUE.C_M00_AXI_WUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_WUSER_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_WUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_RUSER_WIDTH { MODELPARAM_VALUE.C_M00_AXI_RUSER_WIDTH PARAM_VALUE.C_M00_AXI_RUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_RUSER_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_RUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M00_AXI_BUSER_WIDTH { MODELPARAM_VALUE.C_M00_AXI_BUSER_WIDTH PARAM_VALUE.C_M00_AXI_BUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M00_AXI_BUSER_WIDTH}] ${MODELPARAM_VALUE.C_M00_AXI_BUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_ADDR_PIPE_DEPTH { MODELPARAM_VALUE.C_ADDR_PIPE_DEPTH PARAM_VALUE.C_ADDR_PIPE_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_ADDR_PIPE_DEPTH}] ${MODELPARAM_VALUE.C_ADDR_PIPE_DEPTH}
}

proc update_MODELPARAM_VALUE.C_LENGTH_WIDTH { MODELPARAM_VALUE.C_LENGTH_WIDTH PARAM_VALUE.C_LENGTH_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_LENGTH_WIDTH}] ${MODELPARAM_VALUE.C_LENGTH_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_PKT_LEN { MODELPARAM_VALUE.C_PKT_LEN PARAM_VALUE.C_PKT_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_PKT_LEN}] ${MODELPARAM_VALUE.C_PKT_LEN}
}

proc update_MODELPARAM_VALUE.FRAME_SLOT_NUM { MODELPARAM_VALUE.FRAME_SLOT_NUM PARAM_VALUE.FRAME_SLOT_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FRAME_SLOT_NUM}] ${MODELPARAM_VALUE.FRAME_SLOT_NUM}
}

proc update_MODELPARAM_VALUE.SLOT_US { MODELPARAM_VALUE.SLOT_US PARAM_VALUE.SLOT_US } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SLOT_US}] ${MODELPARAM_VALUE.SLOT_US}
}

proc update_MODELPARAM_VALUE.TX_GUARD_US { MODELPARAM_VALUE.TX_GUARD_US PARAM_VALUE.TX_GUARD_US } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_GUARD_US}] ${MODELPARAM_VALUE.TX_GUARD_US}
}

proc update_MODELPARAM_VALUE.OCCUPIER_LIFE_FRAME { MODELPARAM_VALUE.OCCUPIER_LIFE_FRAME PARAM_VALUE.OCCUPIER_LIFE_FRAME } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.OCCUPIER_LIFE_FRAME}] ${MODELPARAM_VALUE.OCCUPIER_LIFE_FRAME}
}

proc update_MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 { MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1}] ${MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S1}
}

proc update_MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 { MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2}] ${MODELPARAM_VALUE.BCH_CANDIDATE_C3HOP_THRES_S2}
}

