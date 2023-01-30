# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Nicole Narr <narrn@student.ethz.ch>
# Christopher Reinwardt <creinwar@student.ethz.ch>

vsim tb_axi_vga -t 1ps -voptargs=+acc

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/clk_i
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_req_o.ar
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_req_o.ar_valid
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_req_o.r_ready
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_resp_i.ar_ready
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_resp_i.r_valid
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/axi_resp_i.r
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/enable_i
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/req_state_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/accept_state_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/red_o
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/green_o
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/blue_o
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/old_beat_data_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/new_beat_data_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/valid_o
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/ready_i
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_timing_fsm/hstate_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_timing_fsm/vstate_q
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/offset_q
add wave -position end  sim:/tb_axi_vga/vga_axi_resp.r.last
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/frame_size_i
add wave -position end  sim:/tb_axi_vga/i_axi_vga/blue_o
add wave -position end  sim:/tb_axi_vga/i_axi_vga/i_axi_vga_fetcher/offset_q
