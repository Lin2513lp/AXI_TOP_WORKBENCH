`default_nettype none

module axi2fifo_sva (
  input logic sys_ckg,
  input logic tpu_rst_n,
  input logic rd_tready,
  input logic rd_tvalid,
  input logic rd_tlast,
  input logic fifo_in_pre_full,
  input logic fifo_in_we,
  input logic rd_dat_last
);

  default clocking cb @(posedge sys_ckg); endclocking
  default disable iff (!tpu_rst_n);

  ap_pre_full_blocks_write:
    assert property (fifo_in_pre_full |-> (!rd_tready && !fifo_in_we));

  ap_write_is_handshake:
    assert property (fifo_in_we |-> (rd_tvalid && rd_tready));

  ap_last_is_accepted_last:
    assert property (rd_dat_last |-> (fifo_in_we && rd_tlast));

endmodule

module fifo2axi_sva #(
  parameter int unsigned DATA_WIDTH = 512,
  parameter int unsigned KEEP_WIDTH = DATA_WIDTH / 8
) (
  input logic                  sys_ckg,
  input logic                  tpu_rst_n,
  input logic                  cpu_tpu_en_sync,
  input logic                  wr_tready,
  input logic                  wr_tvalid,
  input logic [DATA_WIDTH-1:0] wr_tdata,
  input logic [KEEP_WIDTH-1:0] wr_tkeep,
  input logic [KEEP_WIDTH-1:0] wr_tstrb,
  input logic                  wr_tlast,
  input logic                  wr_tid,
  input logic                  wr_tdest,
  input logic                  wr_tuser,
  input logic                  fifo_out_re,
  input logic                  fifo_out_empty
);

  default clocking cb @(posedge sys_ckg); endclocking
  default disable iff (!tpu_rst_n);

  ap_pop_is_handshake:
    assert property (fifo_out_re == (wr_tvalid && wr_tready));

  ap_no_empty_pop:
    assert property (fifo_out_empty |-> !fifo_out_re);

  ap_last_requires_valid:
    assert property (wr_tlast |-> wr_tvalid);

  ap_stall_holds_payload:
    assert property (
      wr_tvalid && !wr_tready
      |=> wr_tvalid &&
          $stable({wr_tdata, wr_tkeep, wr_tstrb, wr_tlast,
                   wr_tid, wr_tdest, wr_tuser})
    );

  ap_enable_drop_does_not_withdraw_valid:
    assert property (
      wr_tvalid && !wr_tready && $fell(cpu_tpu_en_sync)
      |=> wr_tvalid
    );

endmodule

`default_nettype wire
