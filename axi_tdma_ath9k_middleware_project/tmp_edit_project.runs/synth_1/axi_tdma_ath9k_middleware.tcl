# 
# Synthesis run script generated by Vivado
# 

set_msg_config -id {HDL 9-1061} -limit 100000
set_msg_config -id {HDL 9-1654} -limit 100000
set_msg_config -id {HDL-1065} -limit 10000
create_project -in_memory -part xc7z015clg485-1

set_param project.singleFileAddWarning.threshold 0
set_param project.compositeFile.enableAutoGeneration 0
set_param synth.vivado.isSynthRun true
set_msg_config -source 4 -id {IP_Flow 19-2162} -severity warning -new_severity info
set_property webtalk.parent_dir e:/work/fpga/tdma-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/tmp_edit_project.cache/wt [current_project]
set_property parent.project_path e:/work/fpga/tdma-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/tmp_edit_project.xpr [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property target_language Verilog [current_project]
set_property board_part em.avnet.com:picozed_7015_fmc2:part0:1.1 [current_project]
set_property ip_repo_paths {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_txdesc_middleware_v1_0_project/axi_txdesc_middleware_v1_0_project.srcs/sources_1
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/ip_repo/axi_txdesc_middleware_1.0
  e:/work/FPGA/zedboard/Vivado/ip_repo/simple_adder_1.0
} [current_project]
read_ip -quiet e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/cmd_fifo/cmd_fifo.xci
set_property used_in_implementation false [get_files -all e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/cmd_fifo/cmd_fifo/cmd_fifo.xdc]
set_property is_locked true [get_files e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/cmd_fifo/cmd_fifo.xci]

read_verilog -library xil_defaultlib {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/ipic_state_machine.v
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/desc_processor.v
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_S00.v
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_tdma_ath9k_middleware.v
}
read_vhdl -library lib_pkg_v1_0_2 e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/lib_pkg_v1_0_2/lib_pkg.vhd
read_vhdl -library lib_srl_fifo_v1_0_2 {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/lib_srl_fifo_v1_0_2/dynshreg_f.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/lib_srl_fifo_v1_0_2/cntr_incr_decr_addn_f.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/lib_srl_fifo_v1_0_2/srl_fifo_rbu_f.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/lib_srl_fifo_v1_0_2/srl_fifo_f.vhd
}
read_vhdl -library axi_master_burst_v2_0_7 {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_wr_demux.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_strb_gen.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_rdmux.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_fifo.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_wr_status_cntl.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_wrdata_cntl.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_stbs_set.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_skid_buf.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_skid2mm_buf.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_rd_status_cntl.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_rddata_cntl.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_pcc.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_first_stb_offset.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_addr_cntl.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_wr_llink.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_reset.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_rd_wr_cntlr.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_rd_llink.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst_cmd_status.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_burst_v2_0_7/axi_master_burst.vhd
}
read_vhdl -library proc_common_v4_0 {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/proc_common_v4_0/proc_common_pkg.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/proc_common_v4_0/family_support.vhd
}
read_vhdl -library axi_master_lite_v3_0 {
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_lite_v3_0/axi_master_lite_reset.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_lite_v3_0/axi_master_lite_cntlr.vhd
  e:/work/FPGA/TDMA-picozed/vanet-tdma2017/axi_tdma_ath9k_middleware_project/src/axi_master_lite_v3_0/axi_master_lite.vhd
}
foreach dcp [get_files -quiet -all *.dcp] {
  set_property used_in_implementation false $dcp
}
read_xdc dont_touch.xdc
set_property used_in_implementation false [get_files dont_touch.xdc]

synth_design -top axi_tdma_ath9k_middleware -part xc7z015clg485-1


write_checkpoint -force -noxdef axi_tdma_ath9k_middleware.dcp

catch { report_utilization -file axi_tdma_ath9k_middleware_utilization_synth.rpt -pb axi_tdma_ath9k_middleware_utilization_synth.pb }
