# Standalone TPU FIFO interfaces

The two FIFO modules are independent. They do not instantiate either AXI bridge
or `axi_top`. The pre-existing AXI bridges and integration top are unchanged.
Both FIFOs use `sys_ckg` and asynchronous active-low `tpu_rst_n`. Reset release
must be synchronized upstream. Neither FIFO supports a clock-domain crossing.

## Defaults and read timing

- `fifo_in`: `DATA_WIDTH=512`, `DEPTH=8`, `PRE_FULL_THRESHOLD=7`.
- `fifo_out`: `LANE_COUNT=16`, `LANE_WIDTH=32`, `DEPTH=8`.
- DEPTH is an overridable storage capacity in data beats. It is not
  the maximum output count in `rpt_cpt_cyc`.
- Both FIFOs are FWFT: when EMPTY is low, read DATA and LAST already describe the
  current queue head. RE consumes that head at the next rising clock edge.
- DATA and LAST share a memory entry (513 bits at default widths), so LAST moves
  through the queue with its data rather than following a producer-side pulse.
- EMPTY outputs are zero. Memory itself is not reset; reset pointers/count hide
  all old entries until new accepted writes occur.
- Reads while empty are ignored. Simultaneous empty read/write stores one entry;
  it does not bypass the queue. A read and write while full replace the consumed
  head, retaining full occupancy. An overflowing write without a valid read is
  rejected and is not buffered for later retry.
- DEPTH=1 and non-power-of-two depths are supported with explicit pointer wrap.

## FIFO_IN

Source: [fifo_in.sv](E:/CodexWork/AXI_TOP/rtl/fifo_in.sv:5).

| Port | Direction | Meaning |
|---|---|---|
| `fifo_in_we` | input | Write request from `axi2fifo` |
| `fifo_in_wdata` | input, 512-bit default | Input beat |
| `rd_dat_last` | input | LAST belonging to the write beat |
| `fifo_in_pre_full` | output | Occupancy >= PRE_FULL_THRESHOLD |
| `fifo_in_re` | input | Consumer requests head consumption |
| `fifo_empty` | output | Queue contains no entry, matching the diagram name |
| `fifo_in_rdata` | output, 512-bit default | Current FWFT head data |
| `fifo_in_rd_dat_last` | output | Current FWFT head LAST |

The diagram labels both write-side and read-side LAST `rd_dat_last`. A module
cannot have two different ports with the same name; the read-side port is
qualified as `fifo_in_rd_dat_last`. It is a head property, not a delayed pulse.
A consumer wishing to count accepted last entries uses
`fifo_in_re && !fifo_empty && fifo_in_rd_dat_last` at the rising edge.

PRE_FULL is an early warning, not the actual full limit. The FIFO can still
accept writes above that threshold until actual capacity is exhausted; the
existing `axi2fifo` honors PRE_FULL and stops before that boundary.

## FIFO_OUT

Source: [fifo_out.sv](E:/CodexWork/AXI_TOP/rtl/fifo_out.sv:6).

| Port | Direction | Meaning |
|---|---|---|
| `data_out` | input, packed 16 x 32-bit default | Parallel SA_TOP results |
| `dat_out_vld` | input | Results are valid for a write |
| `dat_out_last` | input | LAST belonging to those results |
| `fifo_out_re` | input | Consumer requests head consumption |
| `fifo_out_empty` | output | Queue contains no entry |
| `fifo_out_rdata` | output, 512-bit default | Current FWFT head data |
| `data_out_last` | output | Current FWFT head LAST for `fifo2axi` |

`data_out` is declared as a packed `[15:0][31:0]` array by default. Lane i maps to
`fifo_out_rdata[i*32 +: 32]`: lane 0 occupies bits 31:0 and lane 15 bits 511:480.
Only packing is performed; there is no numeric conversion, precision decoding
or serialization into 16 separate beats. An unpacked SA_TOP array needs an
explicit lane-to-lane adapter when integrating that future module.

The project does not expose a FULL signal on `fifo_out`. System scheduling must
guarantee that the number of unconsumed results never exceeds `DEPTH`. The FIFO
retains an internal full guard so an accidental extra write cannot overwrite an
unread entry, but there is no retry/acceptance handshake back to the producer.
If SA_TOP cannot be paused, `DEPTH` must cover the maximum accumulation during
downstream stalls or separate upstream buffering/control must be provided.

## QuestaSim verification

From `E:\CodexWork\AXI_TOP`, run each independent test:

```powershell
.\sim\run_questa_fifo.ps1 -Module fifo_in
.\sim\run_questa_fifo.ps1 -Module fifo_out
```

The two separate bridge integration tests are optional:

```powershell
.\sim\run_questa_fifo.ps1 -Module fifo_in -Integration
.\sim\run_questa_fifo.ps1 -Module fifo_out -Integration
```

No test instantiates both AXI bridges under one top. The runner uses a new local
work library, modelsim.ini and ASCII TEMP/TMP directory per run, preserving
existing work libraries and global simulator configuration. It checks executable
exit status, rejects simulator error/fatal logs and requires the test's PASS
marker. Logs are retained under `sim/questa/<module>/<run-tag>/`.

New FIFO input ports are explicitly `input var logic`, passing Questa 2021.1's
strict declaration checks with `default_nettype none`. For integration tests
only, the runner uses the vendor `-svinputport=var` interpretation for existing
bridges with unqualified `input logic`; their source is not modified. Standalone
FIFO syntax/function tests do not use that compatibility option or message
suppression.
