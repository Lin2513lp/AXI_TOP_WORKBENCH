# Questa FIFO verification results

Tool: `D:\questasim\win64\vlog.exe` / `vsim.exe`, QuestaSim-64 2021.1.
Latest M integration run date: 2026-09-25 (local tool timestamps).

All four latest listed runs completed with compile **Errors: 0, Warnings: 0**
and simulator **Errors: 0, Warnings: 0**, with the required PASS marker.

| Test top | Coverage | Result |
|---|---|---|
| `tb_fifo_in` | DEPTH 1/3/8/512, default512/custom17-bit widths, PRE_FULL boundaries/custom threshold, empty/full protection, simultaneous RW, stalls, LAST order, wraps, reset, 1000 random cycles per case | FIFO_IN PASS |
| `tb_fifo_out` | DEPTH 1/3/8/512, default16x32/custom3x7 lanes, independent packing reference, empty/full protection, simultaneous RW, stalls, LAST order, wraps, reset, 1500 random cycles per case | FIFO_OUT PASS |
| `tb_axi2fifo_fifo_in` | 9 input beats, VALID before READY, PRE_FULL stall, full-width FIFO readout, one final LAST | AXI2FIFO_FIFO_IN PASS |
| `tb_fifo_out_fifo2axi` | 49 output results, 5 LASTs, 00/01 USER0 and 10/11 USER1, stalls, per-handshake counts, enable drop while final beat is stalled | FIFO_OUT_FIFO2AXI PASS |

## Evidence logs

- FIFO_IN [compile](E:/CodexWork/AXI_TOP/sim/questa/fifo_in/20260920_155042_99cc3bbf/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/fifo_in/20260920_155042_99cc3bbf/simulate.log).
- FIFO_OUT [compile](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260920_155042_0e4049e1/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260920_155042_0e4049e1/simulate.log).
- AXI_M_TOP depth-8 [compile](E:/CodexWork/AXI_TOP/sim/questa/AXI_M_TOP/20260925_162440_39c7775f/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/AXI_M_TOP/20260925_162440_39c7775f/simulate.log).
- AXI_S_TOP depth-8 [compile](E:/CodexWork/AXI_TOP/sim/questa/AXI_S_TOP/20260920_155042_870457b0/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/AXI_S_TOP/20260920_155042_870457b0/simulate.log).
- RX integration [compile](E:/CodexWork/AXI_TOP/sim/questa/fifo_in/20260925_162440_35e642bf/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/fifo_in/20260925_162440_35e642bf/simulate.log).
- TX integration [compile](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260918_000646_c2c35b90/compile.log), [simulation](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260918_000646_c2c35b90/simulate.log).

## Additional lint

Each FIFO independently passed Verilator 5.050 with `--lint-only -Wall` and its
own top module, without warning suppression.

## Boundary of verification

These are self-checking simulations, not exhaustive formal verification or PPA
sign-off. No complete SA_TOP implementation, clock timing target, memory macro
or maximum unthrottled result burst was supplied. Storage depth defaults to 8
beats and remains configurable. The producer-side FIFO_OUT full policy and
the FIFO_IN read-side LAST naming are documented in
[fifo_interfaces.md](E:/CodexWork/AXI_TOP/docs/fifo_interfaces.md).

An initial FIFO_IN compile failed on implicit input net kinds under
`default_nettype none`; explicitly declaring input var logic resolved it. Those
initial failure logs are retained, not represented as successful results. Only
bridge integration runs use Questa's `-svinputport=var` compatibility option;
the standalone FIFO compilations use normal strict options.
