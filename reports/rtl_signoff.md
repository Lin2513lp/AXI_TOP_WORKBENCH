# RTL readiness record

- Run ID: `rtl-design_20260915_183000`
- Design: `axi_top`
- Status: RTL implemented and lint/smoke clean; synthesis timing sign-off not run

## Completed

- [x] Wiring-only top and both planned leaf modules implemented
- [x] Explicit three-process FSM in `axi2fifo`
- [x] Explicit three-process FSM in `fifo2axi`
- [x] All top-level ports connected
- [x] AXI backpressure payload stability covered by RTL and SVA
- [x] Enable-drop-during-stall corner covered by SVA and smoke simulation
- [x] FIFO empty/pre-full guards covered by SVA
- [x] Verilator lint: 0 errors, 0 warnings
- [x] Icarus smoke: PASS
- [x] Single-clock CDC/RDC review completed under documented assumptions
- [x] Compile order and file list documented

## Open before physical/synthesis sign-off

- [ ] Supply `constraints.clock.clk_mhz` and target library/corner.
- [ ] Run synthesis/timing and check area, WNS, fanout and unmapped cells.
- [ ] Confirm that FIFO_OUT is FWFT/show-ahead and that `data_out_last` is
      aligned to the current FIFO head.
- [ ] Confirm that `tpu_rst_n` deassertion is synchronized to `sys_ckg` upstream.

## Clock-gating metric

Internal ICG coverage is N/A for this leaf block. `sys_ckg` is already gated
upstream, and no library-approved ICG cell was provided; no behavioral clock
gate was inserted.
