# Lint summary

- Run ID: `rtl-design_20260915_183000`
- Top: `axi_top`
- Tool: Verilator
- Command: `verilator --lint-only -Wall --top-module axi_top -f filelist.f`
- Result: 0 errors, 0 warnings
- SVA syntax command: `verilator --lint-only -Wall -Wno-MULTITOP --assert sva/axi_stream_fifo_sva.sv`
- SVA syntax result: 0 errors, 0 warnings
- Icarus compile and smoke simulation: PASS (including enable deassertion during
  TX backpressure without withdrawing VALID/payload)

Icarus emitted only simulator capability notices for `unique case` and an
`always_comb` sensitivity over `cpu_cpt_mode`; these are not RTL diagnostics.
Verilator's full warning set was clean.
