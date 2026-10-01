# AXI_TOP VCS / Verdi

Host: E:/DigitalICShare/tpu/tpu/AXI_TOP
Guest: /mnt/hgfs/share/tpu/tpu/AXI_TOP (or /hgfs/share/tpu/tpu/AXI_TOP).

Each child directory is independent and contains rtl/, tb/, Makefile and filelist.f.
AXI_M_TOP: axi2fifo -> fifo_in, 512-bit input beats.
AXI_S_TOP: fifo_out -> fifo2axi, 16 lanes x 32-bit input, 512-bit AXI output.
The M basic TB transmits 10 beats with LAST on the final beat and pauses FIFO
reads to show PRE_FULL backpressure. The S basic TB transmits 8 beats.

Run from a guest terminal with the existing Synopsys environment loaded:

```bash
cd /mnt/hgfs/share/tpu/tpu/AXI_TOP/AXI_M_TOP
make all
make verdi

cd /mnt/hgfs/share/tpu/tpu/AXI_TOP/AXI_S_TOP
make all
make verdi
```

Parent directory: make all runs both; make verdi MODULE=AXI_S_TOP opens S.
FSDB instrumentation uses +define+FSDB_TRACE, Verdi PLI, dumpvars and dumpMDA.
Builds/debug databases live in $HOME/axi_top_runs/<module> to avoid hgfs symlink failures.
Logs and FSDB are copied back into each shared results/ directory after simulation.
make verdi runs in the foreground; close Verdi to return to the terminal.
Before compilation or Verdi, make checks snpslmd with lmstat. For the default
local server it starts the existing lmgrd with the existing license file if
absent, or requests reread if the current user's lmgrd exists. No license file
or shell startup configuration is modified. Recovery is bounded and serialized
between M/S runs. Failure details are saved in results/license.log.
Use make LICENSE_SERVER=port@host to override the default local server;
remote servers are checked but never started or modified by this script.

These sources are a snapshot of E:/CodexWork/AXI_TOP, not live links.
Existing bridge input declarations and FSM behavior are preserved.
The S input type is packed [15:0][31:0], lane 0 at bits [31:0].
FIFO depths are configurable and default to 8. FIFO_IN's default early-full
threshold consequently evaluates to 7.

Validation status: package prepared; guest execution requires an authenticated
connection or running the commands in the VM terminal. Prior Questa PASS is
not a substitute for a VCS/FSDB run.
