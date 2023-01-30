#!/bin/bash
# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

set -e

[ ! -z "$VSIM" ] || VSIM=vsim

$VSIM -64 -c -do 'exit -code [source start.tcl; run -a]'
