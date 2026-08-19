# Copyright 2018-2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Import this GNU Make fragment in your project's makefile to regenerate and
# reconfigure these IPs. You can modify the original RTL, configuration, and
# templates from your project without entering this dependency repo by adding
# build targets for them. To build the IPs, `make axi_vga`.

# You may need to adapt these environment variables to your configuration.
BENDER 	?= bender
PYTHON3	?= /usr/bin/env python3
PEAKRDL ?= peakrdl

AXI_VGA_ROOT ?= $(shell $(BENDER) path axi_vga)

$(AXI_VGA_ROOT)/sw/include:
	mkdir -p $@

$(AXI_VGA_ROOT)/src:
	mkdir -p $@

$(AXI_VGA_ROOT)/src/axi_vga_reg_top.sv $(AXI_VGA_ROOT)/src/axi_vga_reg_pkg.sv: $(AXI_VGA_ROOT)/data/axi_vga.rdl | $(AXI_VGA_ROOT)/src
	$(PEAKRDL) regblock $< -o $(AXI_VGA_ROOT)/src --module-name axi_vga_reg_top --package-name axi_vga_reg_pkg --cpuif apb4-flat

$(AXI_VGA_ROOT)/src/axi_vga_reg_offsets_pkg.sv: $(AXI_VGA_ROOT)/data/axi_vga.rdl $(AXI_VGA_ROOT)/scripts/gen_reg_offsets.py | $(AXI_VGA_ROOT)/src
	$(PYTHON3) $(AXI_VGA_ROOT)/scripts/gen_reg_offsets.py $< -o $@ --package-name axi_vga_reg_offsets_pkg --prefix AXI_VGA

$(AXI_VGA_ROOT)/sw/include/axi_vga_regs.h: $(AXI_VGA_ROOT)/data/axi_vga.rdl | $(AXI_VGA_ROOT)/sw/include
	$(PEAKRDL) c-header $< -o $@

_axi_vga: $(AXI_VGA_ROOT)/src/axi_vga_reg_top.sv
_axi_vga: $(AXI_VGA_ROOT)/src/axi_vga_reg_pkg.sv
_axi_vga: $(AXI_VGA_ROOT)/src/axi_vga_reg_offsets_pkg.sv
_axi_vga: $(AXI_VGA_ROOT)/sw/include/axi_vga_regs.h

axi_vga:
	@echo "[PULP] Generate AXI_VGA"
	@$(MAKE) -B _axi_vga
