# CDC/RDC summary

- Clock domains: one (`sys_ckg`)
- CDC crossings in this block: none
- `cpu_tpu_en_sync` and `cpu_tpu_start_sync` are contractually synchronized
  before entering AXI_TOP.
- FIFO_IN and FIFO_OUT interfaces are assumed synchronous to `sys_ckg`.
- Reset: active-low `tpu_rst_n`, asynchronously asserted by the RTL flops. Its
  deassertion must be synchronized upstream to `sys_ckg`.
- Unwaived CDC violations: 0 under these interface assumptions
- Unwaived RDC violations: 0 under the synchronized-reset-release assumption

If either FIFO is placed in another clock domain, this result is no longer
valid; an asynchronous FIFO or explicit CDC wrapper is then required.
