`timescale 1ns/1ps
`default_nettype none

module tb_axi_top_smoke;

  localparam int unsigned DATA_WIDTH = 512;
  localparam int unsigned KEEP_WIDTH = 64;

  logic                  sys_ckg;
  logic                  tpu_rst_n;
  logic                  rd_tready;
  logic                  rd_tvalid;
  logic [DATA_WIDTH-1:0] rd_tdata;
  logic [KEEP_WIDTH-1:0] rd_tkeep;
  logic [KEEP_WIDTH-1:0] rd_tstrb;
  logic                  rd_tlast;
  logic                  rd_tid;
  logic                  rd_tdest;
  logic                  rd_tuser;
  logic                  wr_tready;
  logic                  wr_tvalid;
  logic [DATA_WIDTH-1:0] wr_tdata;
  logic [KEEP_WIDTH-1:0] wr_tkeep;
  logic [KEEP_WIDTH-1:0] wr_tstrb;
  logic                  wr_tlast;
  logic                  wr_tid;
  logic                  wr_tdest;
  logic                  wr_tuser;
  logic [1:0]            cpu_cpt_mode;
  logic [31:0]           rpt_cpt_cyc;
  logic                  cpu_tpu_en_sync;
  logic                  cpu_tpu_start_sync;
  logic                  fifo_in_we;
  logic                  fifo_in_pre_full;
  logic [DATA_WIDTH-1:0] fifo_in_wdata;
  logic                  rd_dat_last;
  logic                  fifo_out_re;
  logic                  fifo_out_empty;
  logic [DATA_WIDTH-1:0] fifo_out_rdata;
  logic                  data_out_last;

  logic                  fifo_out_loaded;
  logic                  last_mask;
  integer                fifo_out_index;
  integer                fifo_in_count;
  integer                fifo_in_last_count;
  integer                fifo_out_pop_count;
  integer                errors;

  logic [DATA_WIDTH-1:0] result_data [0:2];

  axi_top dut (
    .sys_ckg,
    .tpu_rst_n,
    .rd_tready,
    .rd_tvalid,
    .rd_tdata,
    .rd_tkeep,
    .rd_tstrb,
    .rd_tlast,
    .rd_tid,
    .rd_tdest,
    .rd_tuser,
    .wr_tready,
    .wr_tvalid,
    .wr_tdata,
    .wr_tkeep,
    .wr_tstrb,
    .wr_tlast,
    .wr_tid,
    .wr_tdest,
    .wr_tuser,
    .cpu_cpt_mode,
    .rpt_cpt_cyc,
    .cpu_tpu_en_sync,
    .cpu_tpu_start_sync,
    .fifo_in_we,
    .fifo_in_pre_full,
    .fifo_in_wdata,
    .rd_dat_last,
    .fifo_out_re,
    .fifo_out_empty,
    .fifo_out_rdata,
    .data_out_last
  );

  always #5 sys_ckg = ~sys_ckg;

  always_comb begin
    fifo_out_empty = !fifo_out_loaded || (fifo_out_index >= 3);
    fifo_out_rdata = '0;
    data_out_last  = 1'b0;
    if (!fifo_out_empty) begin
      fifo_out_rdata = result_data[fifo_out_index];
      data_out_last  = (fifo_out_index == 2) && last_mask;
    end
  end

  always @(posedge sys_ckg) begin
    if (fifo_in_we) begin
      fifo_in_count = fifo_in_count + 1;
      if (fifo_in_wdata !== rd_tdata) begin
        $error("FIFO_IN data mismatch");
        errors = errors + 1;
      end
    end

    if (rd_dat_last) begin
      fifo_in_last_count = fifo_in_last_count + 1;
    end

    if (fifo_out_re) begin
      fifo_out_index     = fifo_out_index + 1;
      fifo_out_pop_count = fifo_out_pop_count + 1;
    end
  end

  task automatic send_rd_beat(
    input logic [DATA_WIDTH-1:0] value,
    input logic                  is_last
  );
    begin
      @(negedge sys_ckg);
      rd_tdata  = value;
      rd_tlast  = is_last;
      rd_tvalid = 1'b1;

      do begin
        @(posedge sys_ckg);
      end while (!rd_tready);

      @(negedge sys_ckg);
      rd_tvalid = 1'b0;
      rd_tlast  = 1'b0;
    end
  endtask

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $error("%s", message);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    sys_ckg              = 1'b0;
    tpu_rst_n            = 1'b0;
    rd_tvalid            = 1'b0;
    rd_tdata             = '0;
    rd_tkeep             = '1;
    rd_tstrb             = '1;
    rd_tlast             = 1'b0;
    rd_tid               = 1'b0;
    rd_tdest             = 1'b0;
    rd_tuser             = 1'b0;
    wr_tready            = 1'b0;
    cpu_cpt_mode         = 2'b10;
    cpu_tpu_en_sync      = 1'b0;
    cpu_tpu_start_sync   = 1'b0;
    fifo_in_pre_full     = 1'b0;
    fifo_out_loaded      = 1'b0;
    last_mask            = 1'b1;
    fifo_out_index       = 0;
    fifo_in_count        = 0;
    fifo_in_last_count   = 0;
    fifo_out_pop_count   = 0;
    errors               = 0;
    result_data[0]       = 512'hA0;
    result_data[1]       = 512'hB1;
    result_data[2]       = 512'hC2;

    repeat (3) @(posedge sys_ckg);
    @(negedge sys_ckg);
    tpu_rst_n       = 1'b1;
    cpu_tpu_en_sync = 1'b1;

    // Start RX. VALID may precede READY; the first beat must wait for ACTIVE.
    fork
      begin
        @(negedge sys_ckg);
        cpu_tpu_start_sync = 1'b1;
        @(negedge sys_ckg);
        cpu_tpu_start_sync = 1'b0;
      end
      send_rd_beat(512'h11, 1'b0);
    join

    // PRE_FULL must remove READY without dropping the held AXI beat.
    @(negedge sys_ckg);
    fifo_in_pre_full = 1'b1;
    rd_tdata         = 512'h22;
    rd_tvalid        = 1'b1;
    repeat (2) begin
      @(posedge sys_ckg);
      #1;
      check(!rd_tready && !fifo_in_we, "PRE_FULL did not block RX");
    end
    @(negedge sys_ckg);
    fifo_in_pre_full = 1'b0;
    do @(posedge sys_ckg); while (!rd_tready);
    @(negedge sys_ckg);
    rd_tvalid = 1'b0;

    send_rd_beat(512'h33, 1'b1);
    repeat (2) @(posedge sys_ckg);
    #1;
    check(fifo_in_count == 3, "RX did not write exactly three beats");
    check(fifo_in_last_count == 1, "RX last pulse count mismatch");
    check(!rd_tready, "RX remained ready after accepted TLAST");
    check(rpt_cpt_cyc == 0, "RX handshakes changed output counter");

    // Load a three-entry FWFT result stream. The first entry is snapshotted,
    // then PASS mode sustains one beat per cycle when READY remains high.
    @(negedge sys_ckg);
    fifo_out_loaded = 1'b1;
    wr_tready       = 1'b1;
    wait (fifo_out_pop_count == 1);

    // Stall the second entry and verify its payload is held.
    @(negedge sys_ckg);
    wr_tready       = 1'b0;
    cpu_tpu_en_sync = 1'b0;
    @(posedge sys_ckg);
    #1;
    check(wr_tvalid && (wr_tdata == result_data[1]),
          "Enable drop withdrew a stalled TX beat");
    repeat (2) begin
      @(posedge sys_ckg);
      #1;
      check(wr_tvalid && (wr_tdata == result_data[1]),
            "TX payload changed under backpressure");
      check(!fifo_out_re, "FIFO_OUT popped under backpressure");
    end
    @(negedge sys_ckg);
    wr_tready = 1'b1;
    wait (fifo_out_pop_count == 2);

    // Stall the final beat. Drop the source last pulse after capture to prove
    // that AXI TLAST remains part of the held payload.
    @(negedge sys_ckg);
    wr_tready       = 1'b0;
    cpu_tpu_en_sync = 1'b1;
    @(posedge sys_ckg);
    #1;
    check(wr_tvalid && wr_tlast && (wr_tdata == result_data[2]),
          "Final TX beat/TLAST not presented");
    @(negedge sys_ckg);
    last_mask = 1'b0;
    repeat (2) begin
      @(posedge sys_ckg);
      #1;
      check(wr_tvalid && wr_tlast && (wr_tdata == result_data[2]),
            "TLAST/payload was not held under backpressure");
    end
    @(negedge sys_ckg);
    wr_tready = 1'b1;
    wait (fifo_out_pop_count == 3);
    @(posedge sys_ckg);
    #1;
    check(rpt_cpt_cyc == 3, "Output handshake counter mismatch");
    check(wr_tkeep == {KEEP_WIDTH{1'b1}}, "TKEEP is not all ones");
    check(wr_tstrb == {KEEP_WIDTH{1'b1}}, "TSTRB is not all ones");
    check((wr_tid == 1'b0) && (wr_tdest == 1'b0),
          "TID/TDEST are not tied low");

    if (errors == 0) begin
      $display("SMOKE PASS: AXI_TOP RX/TX handshakes, stalls, TLAST and count");
      $finish;
    end else begin
      $fatal(1, "SMOKE FAIL: %0d errors", errors);
    end
  end

  initial begin
    #5000;
    $fatal(1, "SMOKE TIMEOUT");
  end

endmodule

`default_nettype wire
