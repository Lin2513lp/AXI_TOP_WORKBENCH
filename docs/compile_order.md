# Compile order

Synthesizable RTL:

1. `rtl/axi2fifo.sv`
2. `rtl/fifo2axi.sv`
3. `rtl/axi_top.sv`

The same order is recorded in the repository-root `filelist.f`.

Verification-only sources:

1. Synthesizable RTL above
2. `sva/axi_stream_fifo_sva.sv` for property lint/formal integration
3. `tb/tb_axi_top_smoke.sv` for the Icarus smoke simulation
