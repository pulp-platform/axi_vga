#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="src"
TMP_DIR="/tmp/axi_vga_peakrdl_apb"

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

python -m peakrdl regblock data/axi_vga.rdl \
  -o "${TMP_DIR}" \
  --cpuif apb4-flat \
  --module-name axi_vga_reg_top \
  --package-name axi_vga_reg_pkg

cp "${TMP_DIR}/axi_vga_reg_top.sv" "${OUT_DIR}/axi_vga_reg_top.sv"
cp "${TMP_DIR}/axi_vga_reg_pkg.sv" "${OUT_DIR}/axi_vga_reg_pkg.sv"

python scripts/gen_reg_offsets.py data/axi_vga.rdl \
    -o src/axi_vga_reg_offsets_pkg.sv \
    --package-name axi_vga_reg_offsets_pkg \
    --prefix AXI_VGA

python -m peakrdl c-header data/axi_vga.rdl \
    -o sw/include/axi_vga_regs.h
    
grep -q "module axi_vga_reg_top" "${OUT_DIR}/axi_vga_reg_top.sv"
grep -q "s_apb_psel" "${OUT_DIR}/axi_vga_reg_top.sv"
grep -q "package axi_vga_reg_pkg" "${OUT_DIR}/axi_vga_reg_pkg.sv"

echo "Generated APB PeakRDL register block into ${OUT_DIR}"