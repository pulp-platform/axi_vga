# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Nicole Narr <narrn@student.ethz.ch>
# Christopher Reinwardt <creinwar@student.ethz.ch>

all:

clean:
	rm -rf .bender
	rm -f bender Bender.lock

bender:
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init | bash -s -- 0.25.3
	touch bender

# Generate VGA RTL

BENDER = ./bender
AXI_VGA_ROOT = .
axi_vga.mk: bender # Bender is needed by make fragment
include axi_vga.mk

all: axi_vga

# Checks

CHECK_CLEAN = git status && test -z "$$(git status --porcelain)"

check_generated:
	$(MAKE) -B axi_vga
	$(CHECK_CLEAN)

check: check_generated

# Simulation using QuestaSim

clean: clean_vsim

clean_vsim:
	rm -rf test/work
	rm -f transcript *.wlf wlf*
	rm -f test/compile.tcl

vsim: clean_vsim bender
	cd vsim && ./compile.sh
	cd vsim && ./run.sh
