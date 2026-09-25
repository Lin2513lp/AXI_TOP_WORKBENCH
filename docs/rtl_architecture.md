# AXI_TOP RTL architecture

## Hierarchy

```text
axi_top
|- axi2fifo u_axi2fifo       // rd_* AXI-Stream input -> FIFO_IN
`- fifo2axi u_fifo2axi       // FIFO_OUT -> wr_* AXI-Stream output
```

`axi_top` is wiring-only. Both leaf blocks are in the `sys_ckg` clock domain and
use the active-low `tpu_rst_n` reset. The design contains no CDC crossing.

## Module contracts

### `axi2fifo`

- Starts an input transaction after `cpu_tpu_en_sync && cpu_tpu_start_sync`.
- Accepts a beat only on `rd_tvalid && rd_tready`.
- Deasserts `rd_tready` while `fifo_in_pre_full` is asserted.
- Pulses `fifo_in_we` for every accepted beat and `rd_dat_last` for an accepted
  beat carrying `rd_tlast`.
- Returns to idle after the accepted last beat.

### `fifo2axi`

- Starts presenting output whenever the enabled FIFO_OUT is non-empty; start is
  not a TX trigger.
- Uses a transparent/pass state for full-rate FWFT streaming and a holding state
  to preserve the AXI payload when the downstream applies backpressure.
- Once a beat is advertised, a later `cpu_tpu_en_sync` drop cannot withdraw it;
  the beat remains valid through the stall, transfers once, then TX idles.
- Pops FIFO_OUT only on `wr_tvalid && wr_tready`.
- Forms `wr_tlast` from the FIFO-side `data_out_last`, but treats it as AXI
  payload: it is asserted only with `wr_tvalid` and is held through a stall.
- Clears `rpt_cpt_cyc` on `cpu_tpu_start_sync`; increments it once per successful
  output handshake.

## FIFO_OUT timing contract

This first implementation assumes a show-ahead/FWFT FIFO:

- When `fifo_out_empty == 0`, `fifo_out_rdata` and the aligned
  `data_out_last` describe the current head entry before `fifo_out_re`.
- The FIFO keeps its current head stable until `fifo_out_re` is sampled high.
- A high `fifo_out_re` consumes exactly one current head entry.
- If `data_out_last` is generated only when a result is enqueued rather than
  when that result is at the FIFO head, it must instead be stored alongside the
  512-bit data or in an equivalent sideband FIFO.

## Interface widths

| Interface | Width |
|---|---:|
| `rd_tdata`, `wr_tdata`, FIFO data | 512 |
| `rd_tkeep`, `rd_tstrb`, `wr_tkeep`, `wr_tstrb` | 64 |
| `rd_tid`, `rd_tdest`, `rd_tuser` | 1 each |
| `wr_tid`, `wr_tdest`, `wr_tuser` | 1 each |
| `cpu_cpt_mode` | 2 |
| `rpt_cpt_cyc` | 32 |

## Power and clocking note

`sys_ckg` is already an upstream-gated clock. No behavioral clock gate or
technology ICG is inserted in this block because no library-approved ICG cell
has been provided. The domain is treated as externally gated for this RTL-only
run.

## Verification boundary

No target clock frequency was supplied, so timing synthesis is outside this
run. Compile/lint and cycle-level protocol smoke testing are required before
handoff.
