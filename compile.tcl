# This script was generated automatically by bender.
set ROOT "/scratch/socmipo2/swueest/axi_vga"

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/clk_rst_gen.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/sim_timeout.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/stream_watchdog.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/signal_highlighter.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_stream_mst.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_synch_holdable_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_verif_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_synch_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/src/rand_stream_slv.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/common_verification-2522126e8ab31cea/test/tb_clk_rst_gen.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/rtl/tc_sram.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/rtl/tc_sram_impl.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/rtl/tc_clk.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/cluster_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/generic_memory.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/generic_rom.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/pad_functional.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/pulp_buffer.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/pulp_pwr_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/tc_pwr.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/test/tb_tc_sram.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/pulp_clock_gating_async.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/cluster_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-fb9f84c516307ee3/src/deprecated/pulp_clk_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/binary_to_gray.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cb_filter_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cc_onehot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_reset_ctrlr_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/clk_int_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/credit_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/delta_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/ecc_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/edge_propagator_tx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/exp_backoff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/fifo_v3.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/gray_to_binary.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/heaviside.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/isochronous_4phase_handshake.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/isochronous_spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/lfsr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/lfsr_16bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/lfsr_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/lossy_valid_to_stream.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/mv_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/onehot_to_bin.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/plru_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/passthrough_stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/popcount.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/ring_buffer.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/rr_arb_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/rstgen_bypass.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/serial_deglitch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/shift_reg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/shift_reg_gated.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/spill_register_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_demux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_fork.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_intf.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_join_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_mux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_throttle.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/sub_per_hash.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/unread.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/read.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/addr_decode_dync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/boxcar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_4phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/clk_int_div_static.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/trip_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/addr_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/addr_decode_napot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/multiaddr_decode.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cb_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_fifo_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/clk_mux_glitch_free.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/ecc_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/ecc_encode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/edge_detect.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/lzc.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/max_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/rstgen.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_delay.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_fork_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_join.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_reset_ctrlr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_fifo_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/fall_through_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_arbiter_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_fifo_optimal_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_xbar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_fifo_gray_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/cdc_2phase_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/mem_to_banks_detailed.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/stream_omega_net.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/mem_to_banks.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/sram.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/addr_decode_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/cb_filter_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/cdc_2phase_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/cdc_2phase_clearable_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/cdc_fifo_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/cdc_fifo_clearable_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/fifo_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/graycode_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/id_queue_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/passthrough_stream_fifo_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/popcount_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/rr_arb_tree_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/stream_test.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/stream_register_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/stream_to_mem_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/sub_per_hash_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/isochronous_crossing_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/stream_omega_net_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/stream_xbar_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/clk_int_div_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/clk_int_div_static_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/clk_mux_glitch_free_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/test/lossy_valid_to_stream_tb.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/clock_divider_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/clk_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/find_first_one.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/generic_LFSR_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/generic_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/prioarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/pulp_sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/pulp_sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/rrarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/clock_divider.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/fifo_v2.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/deprecated/fifo_v1.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/edge_propagator_ack.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/edge_propagator.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/src/edge_propagator_rx.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_pkg.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_intf.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_regs.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_cdc.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_demux.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/src/apb_test.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/test/tb_apb_regs.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/test/tb_apb_cdc.sv" \
    "$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/test/tb_apb_demux.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_pkg.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_demux_id_counters.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_intf.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_atop_filter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_burst_splitter_gran.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_burst_unwrap.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_bus_compare.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_cdc_dst.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_cdc_src.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_cut.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_delayer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_demux_simple.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_dw_downsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_dw_upsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_fifo.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_fifo_delay_dyn.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_id_remap.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_id_prepend.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_inval_filter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_isolate.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_dw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_from_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_mailbox.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_regs.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_to_axi.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_modify_address.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_rw_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_rw_split.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_serializer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_slave_compare.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_throttle.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_detailed_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_burst_splitter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_cdc.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_dw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_from_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_id_serialize.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_multicut.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_axi_lite.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_zero_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_interleaved_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_iw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_lite_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_xbar_unmuxed.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_mem_banked.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_mem_interleaved.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_to_mem_split.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_xp.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_chan_compare.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_dumper.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_sim_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/src/axi_test.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_dw_pkg.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_xbar_pkg.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_addr_test.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_atop_filter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_bus_compare.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_cdc.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_delayer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_dw_downsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_dw_upsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_fifo.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_isolate.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_dw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_mailbox.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_regs.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_iw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_to_axi.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_lite_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_modify_address.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_serializer.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_sim_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_slave_compare.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_to_axi_lite.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_to_mem_banked.sv" \
    "$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/test/tb_axi_xbar.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/include" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/src/axi_vga_reg_pkg.sv" \
    "$ROOT/src/axi_vga_reg_offsets_pkg.sv" \
    "$ROOT/src/axi_vga_reg_top.sv" \
    "$ROOT/src/axi_vga_timing_fsm.sv" \
    "$ROOT/src/axi_vga_fetcher.sv" \
    "$ROOT/src/axi_vga.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TEST" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-38d8e0ca13cecee5/include" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-96ccc672928ebbdd/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-9c550fbfdaba7491/include" \
    "$ROOT/test/tb_axi_vga.sv" \
}]} {return 1}

