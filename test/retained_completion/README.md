# Retained read completions

A read completion is an accepted `RVALID && RREADY && RLAST` beat. Keep that
completion until the request state consumes it. The first request token is
independent of read completions. If a saved completion and a new completion
coincide in the idle state, consume one and retain the other.

The previous implementation sampled `RLAST` without its handshake and used an
edge-like condition only in `R_IDLE`. An accepted LAST in `REQ`, consecutive
accepted LAST beats, or the first startup transition can lose a request token.

## Fixed inputs

Official base: `4d3e70d4f47bb74edc1ab68d99ffc02382e0fb9e`.
The repository has no checked-in dependency lock. This test fixes the minimum
versions declared by its Bender manifest. No dependency is upgraded.

| Package | Version | Commit |
|---|---|---|
| axi | 0.39.2 | ac5deb3ff086aa34b168f392c051e92603d6c0e2 |
| common_cells | 1.33.0 | 13f28aa0021fc22c0d01a12d618fda58d2c93239 |
| register_interface | 0.4.2 | d7693be4aef1fc7e7eb2b00b41c42e87d959866c |

Use VCS W-2024.09-SP1, Python 3 with PyYAML, and Bash. Obtain each upstream
package at the exact commit above. Run these commands from this checkout.
Set the three dependency paths to absolute paths.

```sh
export AXI_DIR=/absolute/deps/axi
export COMMON_CELLS_DIR=/absolute/deps/common_cells
export REGISTER_INTERFACE_DIR=/absolute/deps/register_interface
mkdir -p /tmp/vga-completion

git show 4d3e70d4f47bb74edc1ab68d99ffc02382e0fb9e:src/axi_vga_fetcher.sv > /tmp/vga-completion/original_fetcher.sv
FETCHER_SOURCE=/tmp/vga-completion/original_fetcher.sv RUN_DIR=/tmp/vga-completion/original bash test/retained_completion/run.sh
RUN_DIR=/tmp/vga-completion/candidate bash test/retained_completion/run.sh

for variant in original candidate; do
  for profile in timing flow restart; do
    python3 test/retained_completion/review_vga.py --kind unit --profile "$profile" \
      --run "/tmp/vga-completion/$variant/$profile" \
      --output "/tmp/vga-completion/$variant/$profile/audit.json"
  done
done
```

The original timing command is expected to fail. Each run has its own output,
objects, input SHA list and log. The HDL limit is 2 ms and the wall limit is
600 seconds. A success marker alone is insufficient. Check the independent
reader result, normal finish, return code and absence of assertion failures.
The public reader accepts only the unit tests. It requires no SoC or ELF helper.

## Pixel and transaction results

Both versions use the same test source, configuration and endpoint data formula.
The test instantiates the complete real `axi_vga`, including its register block,
fetcher, burst splitter, stream FIFO, credit control and timing state machine.
The endpoint generates data from accepted public addresses and the case epoch.
The reader calculates all pixel values, sync periods, public transactions,
credits, register accesses, drain/reset boundaries and completion independently.
It does not use the DUT's pixel value or internal address as expected data.

| Profile | Cases | Checked display pixels | Original | Candidate |
|---|---:|---:|---|---|
| timing | 2 | 512 | 256 pixel errors | 0 errors |
| flow | 3 | 768 plus 256 black pixels | Pass | Pass |
| restart | 3 | 768 | Pass | Pass |

The candidate performs 144036 / 288171 / 324226 in-test checks for those profiles.
All three independent readers pass. The original timing run reaches its explicit
failure at normal finalization. It does not time out. The cases include LEN0,
LEN7 and LEN15, a 4 KiB split, high address bits, AR stalls, full credits,
controlled starvation, disable/drain, delayed responses and reset with requests
in flight. Recovery after deliberate underflow uses a common reset. This test
does not claim seamless underflow recovery or every legal parameter setting.

## Direct handshake boundaries

The additional test directly instantiates the real fetcher. It does not force
or assign internal state. Compile it for each exact fetcher source:

```sh
mkdir /tmp/vga-completion/edges-candidate
cd /tmp/vga-completion/edges-candidate
# Set VGA_CHECKOUT to the absolute path of this checkout.
vcs -full64 -sverilog -assert svaext -timescale=1ns/1ps \
  +incdir+"$AXI_DIR/include" "$AXI_DIR/src/axi_pkg.sv" \
  "$VGA_CHECKOUT/src/axi_vga_fetcher.sv" \
  "$VGA_CHECKOUT/test/retained_completion/tb_completion_edges.sv" \
  -top tb_completion_edges -o simv -Mdir=objects >compile.log 2>&1
timeout 600 ./simv >stdout.log 2>&1
```

Repeat in a separate directory with the original source. The identical four
cases perform 166 checks: original 13 errors, candidate zero. They check eight
clocks with `RVALID=1, RREADY=0, RLAST=1`, unrelated LAST transitions while VALID
is zero, acceptance while AR is held in REQ, saved plus new completion in the
idle state, and a completion on the startup-token edge. Every accepted response
has a previously accepted request. Candidate pending single-beat requests stay
between zero and two. Reset explicitly cancels the final pending requests.

The one-bit saved completion follows the request protocol. During a clean
enabled epoch, let O count outstanding logical bursts, Q denote a request token
in REQ, P denote the saved completion, and S denote the startup token.
The initial budget is `O + Q + P + S = 2`. An AR transfers Q to O. An accepted
LAST transfers O to P or Q. The idle state transfers P or S to Q. A saved token
in REQ therefore cannot receive a second completion from an older burst.
The real integration also has a registered response FIFO. Stop/drain or reset
separates epochs. This is not a claim about arbitrary unmatched response inputs.

## Module implementation checks

Use DC W-2024.09-SP1 and the typed `v01_vga_fetcher_impl.sv` wrapper. Set a new
absolute output directory for each source. The wrapper exposes all public
fetcher inputs and outputs and fixes RGB565, address48 and data64.

```sh
mkdir /tmp/vga-completion/dc-candidate
printf '%s\n' "$COMMON_CELLS_DIR/src/cf_math_pkg.sv" "$AXI_DIR/src/axi_pkg.sv" \
  "$PWD/src/axi_vga_fetcher.sv" "$PWD/test/retained_completion/v01_vga_fetcher_impl.sv" \
  > /tmp/vga-completion/dc-candidate/sources.list
printf '%s\n' "$COMMON_CELLS_DIR/include" "$AXI_DIR/include" "$REGISTER_INTERFACE_DIR/include" \
  > /tmp/vga-completion/dc-candidate/includes.list
OUT=/tmp/vga-completion/dc-candidate INPUTS="$PWD" VARIANT=candidate MODULE=vga \
  TOP=v01_vga_fetcher_impl timeout 1800 dc_shell \
  -f test/retained_completion/check_structure.tcl > /tmp/vga-completion/dc-candidate/dc.log 2>&1
```

Repeat with the original source. Both designs have 296 flip-flops and zero
latches, loops, multiple drivers, unexplained cells or final blackboxes.
Generic `compile -no_map` reports 4868/4878 hierarchical cells before/after.
This is a structure check, not technology timing or area signoff.
VCS `+lint=all` on both typed module instances reports identical categories:
SV-PIU1, ULCO7, WMIA-L14, CAWM-L2 and SVA-UA1. These existing width/assertion
messages are preserved. No new lint category or count is introduced.

The existing license checker also checks the new test files. Its allowed-author
list includes their actual author group. No test path is excluded. Production
copyright and SHL-0.51 licensing remain unchanged. New tests retain their stated
Apache-2.0 license and the original public-test provenance header.

AI assistance: OpenAI Codex assisted implementation, test preparation and
validation. A separate AI technical review is recorded with the contribution.
This does not claim a human review.
