# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Nicole Narr <narrn@student.ethz.ch>
# Christopher Reinwardt <creinwar@student.ethz.ch>

BENDER 		?= bender
PYTHON		?= python3

REGGEN		 = $(PYTHON) $(shell bender path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
REG_INCDIR   = sw/include


.PHONY: vsim

all: vga_regs vsim

clean:
	rm -f $(REG_INCDIR)/axi_vga_regs.h\
		  src/axi_vga_register_file_reg*.sv\
		  vsim/compile.tcl

vga_regs:
	$(REGGEN) -r src/axi_vga_reg.hjson --outdir src/
	$(REGGEN) --cdefines --outfile $(REG_INCDIR)/axi_vga_regs.h src/axi_vga_reg.hjson


vsim:
	$(BENDER) script -t rtl -t sim -t test vsim > vsim/compile.tcl
