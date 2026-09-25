`default_nettype none

// Wiring-only integration wrapper for the independent AXI-Stream directions.
module axi_top #(
  parameter int unsigned DATA_WIDTH  = 512,
  parameter int unsigned KEEP_WIDTH  = DATA_WIDTH / 8,
  parameter int unsigned COUNT_WIDTH = 32
) (
  input  logic                   sys_ckg,
  input  logic                   tpu_rst_n,

  output logic                   rd_tready,
  input  logic                   rd_tvalid,
  input  logic [DATA_WIDTH-1:0]  rd_tdata,
  input  logic [KEEP_WIDTH-1:0]  rd_tkeep,
  input  logic [KEEP_WIDTH-1:0]  rd_tstrb,
  input  logic                   rd_tlast,
  input  logic                   rd_tid,
  input  logic                   rd_tdest,
  input  logic                   rd_tuser,

  input  logic                   wr_tready,
  output logic                   wr_tvalid,
  output logic [DATA_WIDTH-1:0]  wr_tdata,
  output logic [KEEP_WIDTH-1:0]  wr_tkeep,
  output logic [KEEP_WIDTH-1:0]  wr_tstrb,
  output logic                   wr_tlast,
  output logic                   wr_tid,
  output logic                   wr_tdest,
  output logic                   wr_tuser,

  input  logic [1:0]             cpu_cpt_mode,
  output logic [COUNT_WIDTH-1:0] rpt_cpt_cyc,
  input  logic                   cpu_tpu_en_sync,
  input  logic                   cpu_tpu_start_sync,

  output logic                   fifo_in_we,
  input  logic                   fifo_in_pre_full,
  output logic [DATA_WIDTH-1:0]  fifo_in_wdata,
  output logic                   rd_dat_last,

  output logic                   fifo_out_re,
  input  logic                   fifo_out_empty,
  input  logic [DATA_WIDTH-1:0]  fifo_out_rdata,
  input  logic                   data_out_last
);

  axi2fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .KEEP_WIDTH (KEEP_WIDTH)
  ) u_axi2fifo (
    .sys_ckg            (sys_ckg),
    .tpu_rst_n          (tpu_rst_n),
    .cpu_tpu_en_sync    (cpu_tpu_en_sync),
    .cpu_tpu_start_sync (cpu_tpu_start_sync),
    .rd_tready          (rd_tready),
    .rd_tvalid          (rd_tvalid),
    .rd_tdata           (rd_tdata),
    .rd_tkeep           (rd_tkeep),
    .rd_tstrb           (rd_tstrb),
    .rd_tlast           (rd_tlast),
    .rd_tid             (rd_tid),
    .rd_tdest           (rd_tdest),
    .rd_tuser           (rd_tuser),
    .fifo_in_we         (fifo_in_we),
    .fifo_in_pre_full   (fifo_in_pre_full),
    .fifo_in_wdata      (fifo_in_wdata),
    .rd_dat_last        (rd_dat_last)
  );

  fifo2axi #(
    .DATA_WIDTH  (DATA_WIDTH),
    .KEEP_WIDTH  (KEEP_WIDTH),
    .COUNT_WIDTH (COUNT_WIDTH)
  ) u_fifo2axi (
    .sys_ckg            (sys_ckg),
    .tpu_rst_n          (tpu_rst_n),
    .cpu_tpu_en_sync    (cpu_tpu_en_sync),
    .cpu_tpu_start_sync (cpu_tpu_start_sync),
    .cpu_cpt_mode       (cpu_cpt_mode),
    .rpt_cpt_cyc        (rpt_cpt_cyc),
    .wr_tready          (wr_tready),
    .wr_tvalid          (wr_tvalid),
    .wr_tdata           (wr_tdata),
    .wr_tkeep           (wr_tkeep),
    .wr_tstrb           (wr_tstrb),
    .wr_tlast           (wr_tlast),
    .wr_tid             (wr_tid),
    .wr_tdest           (wr_tdest),
    .wr_tuser           (wr_tuser),
    .fifo_out_re        (fifo_out_re),
    .fifo_out_empty     (fifo_out_empty),
    .fifo_out_rdata     (fifo_out_rdata),
    .data_out_last      (data_out_last)
  );

endmodule

`default_nettype wire
