#!/usr/bin/env bash
# Copyright 2026 CheshireAra contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
: "${AXI_DIR:?Set AXI_DIR to ac5deb3ff086aa34b168f392c051e92603d6c0e2}"
: "${COMMON_CELLS_DIR:?Set COMMON_CELLS_DIR to 13f28aa0021fc22c0d01a12d618fda58d2c93239}"
: "${REGISTER_INTERFACE_DIR:?Set REGISTER_INTERFACE_DIR to d7693be4aef1fc7e7eb2b00b41c42e87d959866c}"
: "${RUN_DIR:?Set a new absolute RUN_DIR}"
export AXI_DIR COMMON_CELLS_DIR REGISTER_INTERFACE_DIR RUN_DIR
export VGA_TEST_ROOT="$root"
export FETCHER_SOURCE="${FETCHER_SOURCE:-$root/src/axi_vga_fetcher.sv}"
mkdir "$RUN_DIR" || exit 1
python3 - <<'PY'
from pathlib import Path
import os,yaml,json,hashlib
out=Path(os.environ['RUN_DIR']);root=Path(os.environ['VGA_TEST_ROOT'])
cc=Path(os.environ['COMMON_CELLS_DIR']);axi=Path(os.environ['AXI_DIR']);reg=Path(os.environ['REGISTER_INTERFACE_DIR'])
def sources(package):
 def visit(items):
  for item in items:
   if isinstance(item,str):yield package/item
   elif 'test' not in str(item.get('target','')) and item.get('target')!='simulation':yield from visit(item['files'])
 return list(visit(yaml.safe_load((package/'Bender.yml').read_text())['sources']))
files=sources(cc)+sources(axi)+[reg/'vendor/lowrisc_opentitan/src'/n for n in ['prim_subreg_arb.sv','prim_subreg.sv','prim_subreg_ext.sv']]
files += [root/'src'/n for n in ['axi_vga_reg_pkg.sv','axi_vga_reg_top.sv','axi_vga_timing_fsm.sv']]
files += [Path(os.environ['FETCHER_SOURCE']),root/'src/axi_vga.sv',root/'test/retained_completion/tb_axi_vga_completion.sv']
files=list(dict.fromkeys(files));includes=[cc/'include',axi/'include',reg/'include']
(out/'sources.f').write_text(''.join('+incdir+'+str(p)+'\n' for p in includes)+''.join(str(p)+'\n' for p in files))
frozen=files+[p for d in includes for p in d.rglob('*.svh')]
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in frozen},indent=2)+'\n')
(out/'limit.ucli').write_text('run 2 ms\nquit\n')
PY
cd "$RUN_DIR"
timeout 600 vcs -full64 -sverilog -assert svaext -timescale=1ns/1ps +vcs+lic+wait -top tb_axi_vga_completion -o simv -Mdir=objects -f sources.f >compile.log 2>&1
rc=$?; echo "$rc" >compile.rc
if [[ $rc != 0 ]]; then exit "$rc"; fi
status=0
for profile in timing flow restart; do
 mkdir "$profile"
 (cd "$profile"; timeout 600 ../simv -ucli -do ../limit.ucli "+VGA_TEST_UNIT_PROFILE=$profile" >stdout.log 2>&1; echo "$?" >process.rc)
 if ! grep -qx "VGA_TEST_UNIT_PASS profile=$profile" "$profile/stdout.log"; then status=1; fi
done
exit "$status"
