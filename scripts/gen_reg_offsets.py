#!/usr/bin/env python3

import argparse
import re
from pathlib import Path

from systemrdl import RDLCompiler
from systemrdl.node import RegNode


def sv_const_name(prefix: str, reg_name: str) -> str:
    name = re.sub(r"[^a-zA-Z0-9]+", "_", reg_name)
    name = name.upper()
    return f"{prefix}_{name}_OFFSET"


def collect_registers(node, root_addr):
    regs = []

    for child in node.children(unroll=True):
        if isinstance(child, RegNode):
            offset = child.absolute_address - root_addr
            regs.append((child.inst_name, offset))
        else:
            if hasattr(child, "children"):
                regs.extend(collect_registers(child, root_addr))

    return regs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rdl_file")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("--package-name", default="axi_vga_reg_offsets_pkg")
    parser.add_argument("--prefix", default="AXI_VGA")
    args = parser.parse_args()

    rdlc = RDLCompiler()
    rdlc.compile_file(args.rdl_file)
    root = rdlc.elaborate()

    top = root.children(unroll=True)[0]
    root_addr = top.absolute_address
    regs = collect_registers(top, root_addr)

    out = []
    out.append("// Generated from SystemRDL. Do not edit manually.")
    out.append("")
    out.append(f"package {args.package_name};")
    out.append("")

    for reg_name, offset in regs:
        const_name = sv_const_name(args.prefix, reg_name)
        out.append(f"    localparam logic [31:0] {const_name:<45} = 32'h{offset:08X};")

    out.append("")
    out.append("endpackage")
    out.append("")

    Path(args.output).write_text("\n".join(out))


if __name__ == "__main__":
    main()