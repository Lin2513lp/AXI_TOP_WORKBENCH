`timescale 1ns/1ps
`default_nettype none

// Transmit-path integration only; no RX bridge or AXI_TOP is instantiated.
module tb_fifo_out_fifo2axi;
  localparam int DATA_WIDTH = 512;
  localparam int DEPTH = 8;
  logic sys_ckg = 1'b0;
  logic tpu_rst_n = 1'b0;
  logic cpu_tpu_en_sync = 1'b0;
  logic cpu_tpu_start_sync = 1'b0;
  logic [1:0] cpu_cpt_mode = 2'b00;
  logic [31:0] rpt_cpt_cyc;
  logic [15:0][31:0] data_out = '0;
  logic dat_out_vld = 1'b0;
  logic dat_out_last = 1'b0;
  logic fifo_out_re;
  logic fifo_out_empty;
  logic [DATA_WIDTH-1:0] fifo_out_rdata;
  logic data_out_last;
  logic wr_tready = 1'b0;
  logic wr_tvalid;
  logic [DATA_WIDTH-1:0] wr_tdata;
  logic [63:0] wr_tkeep;
  logic [63:0] wr_tstrb;
  logic wr_tlast;
  logic wr_tid;
  logic wr_tdest;
  logic wr_tuser;
  logic ready_pattern_enable = 1'b0;
  logic stalled = 1'b0;
  logic [DATA_WIDTH+1:0] stalled_payload;
  logic [DATA_WIDTH+1:0] expected[$];
  logic [DATA_WIDTH+1:0] expected_head;
  integer cycles = 0;
  integer writes = 0;
  integer reads = 0;
  integer lasts = 0;
  integer stalls = 0;

  always #5 sys_ckg = ~sys_ckg;
  always @(negedge sys_ckg) begin
    if (ready_pattern_enable)
      wr_tready = ((cycles % 5) != 1) && ((cycles % 5) != 2);
  end

  fifo_out #(.DEPTH(DEPTH)) u_fifo_out (
    .sys_ckg, .tpu_rst_n, .data_out, .dat_out_vld, .dat_out_last,
    .fifo_out_re, .fifo_out_empty, .fifo_out_rdata, .data_out_last
  );
  fifo2axi u_fifo2axi (
    .sys_ckg, .tpu_rst_n, .cpu_tpu_en_sync, .cpu_tpu_start_sync,
    .cpu_cpt_mode, .rpt_cpt_cyc, .wr_tready, .wr_tvalid, .wr_tdata,
    .wr_tkeep, .wr_tstrb, .wr_tlast, .wr_tid, .wr_tdest, .wr_tuser,
    .fifo_out_re, .fifo_out_empty, .fifo_out_rdata, .data_out_last
  );

  function automatic logic [DATA_WIDTH-1:0] pack_reference;
    logic [DATA_WIDTH-1:0] packed_data;
    for (integer lane = 0; lane < 16; lane++)
      packed_data[lane*32 +: 32] = data_out[lane];
    return packed_data;
  endfunction

  always @(posedge sys_ckg) begin
    if (!tpu_rst_n) begin
      expected.delete();
      stalled = 1'b0;
      cycles = 0;
      writes = 0;
      reads = 0;
      lasts = 0;
      stalls = 0;
    end else begin
      if (fifo_out_re !== (wr_tvalid && wr_tready))
        $fatal(1, "FIFO pop differs from TX handshake");
      if (fifo_out_empty && fifo_out_re)
        $fatal(1, "TX popped an empty FIFO");
      if (stalled && (!wr_tvalid ||
          {wr_tuser, wr_tlast, wr_tdata} !== stalled_payload))
        $fatal(1, "TX withdrew VALID or changed stalled DATA/LAST/USER");
      if (wr_tvalid) begin
        if (wr_tkeep !== '1 || wr_tstrb !== '1 || wr_tid !== 1'b0 || wr_tdest !== 1'b0)
          $fatal(1, "TX KEEP/STRB/ID/DEST mismatch");
      end
      stalled = wr_tvalid && !wr_tready;
      stalled_payload = {wr_tuser, wr_tlast, wr_tdata};
      if (stalled) stalls++;
      if (wr_tvalid && wr_tready) begin
        if (expected.size() == 0)
          $fatal(1, "TX sent an unexpected result");
        expected_head = expected.pop_front();
        if ({wr_tuser, wr_tlast, wr_tdata} !== expected_head)
          $fatal(1, "TX lane packing, LAST or USER mismatch at result %0d", reads);
        reads++;
        if (wr_tlast) lasts++;
      end
      if (dat_out_vld) begin
        if (expected.size() >= DEPTH)
          $fatal(1, "Integration stimulus exceeded FIFO depth without a FULL interface");
        expected.push_back({cpu_cpt_mode[1], dat_out_last, pack_reference()});
        writes++;
      end
      cycles++;
    end
  end

  task automatic clear_count;
    @(negedge sys_ckg);
    cpu_tpu_start_sync = 1'b1;
    @(negedge sys_ckg);
    cpu_tpu_start_sync = 1'b0;
    if (rpt_cpt_cyc != 0) $fatal(1, "TX start did not clear output count");
  endtask

  task automatic send_result(input integer tag, input logic last);
    @(negedge sys_ckg);
    dat_out_vld = 1'b0;
    for (integer lane = 0; lane < 16; lane++)
      data_out[lane] = 32'h8000_0000 + 32'(tag * 16 + lane);
    dat_out_last = last;
    dat_out_vld = 1'b1;
    @(posedge sys_ckg);
  endtask

  task automatic stop_producer;
    @(negedge sys_ckg);
    dat_out_vld = 1'b0;
    dat_out_last = 1'b0;
  endtask

  initial begin
    repeat (3) @(negedge sys_ckg);
    tpu_rst_n = 1'b1;
    cpu_tpu_en_sync = 1'b1;
    for (integer mode = 0; mode < 4; mode++) begin
      ready_pattern_enable = 1'b0;
      wr_tready = 1'b0;
      cpu_cpt_mode = 2'(mode);
      clear_count();
      fork
        begin
          for (integer index = 0; index < 12; index++)
            send_result(mode * 100 + index, index == 11);
          stop_producer();
        end
        begin
          // Start draining before eight unconsumed results accumulate. The
          // system schedule, rather than a FULL port, guarantees capacity.
          repeat (4) @(negedge sys_ckg);
          ready_pattern_enable = 1'b1;
        end
      join
      wait (reads == (mode + 1) * 12);
      @(negedge sys_ckg);
      if (rpt_cpt_cyc != 12 || !fifo_out_empty || expected.size() != 0)
        $fatal(1, "TX MODE=%0d count/drain mismatch", mode);
      $display("FIFO_OUT_FIFO2AXI mode PASS: mode=%02b user=%0d count=12", cpu_cpt_mode, cpu_cpt_mode[1]);
    end

    // A stalled final beat must survive EN dropping, then transfer exactly once.
    ready_pattern_enable = 1'b0;
    wr_tready = 1'b0;
    clear_count();
    send_result(999, 1'b1);
    stop_producer();
    wait (wr_tvalid);
    @(negedge sys_ckg);
    cpu_tpu_en_sync = 1'b0;
    repeat (4) @(negedge sys_ckg);
    if (!wr_tvalid || !wr_tlast || !wr_tuser)
      $fatal(1, "Enable drop lost held final result");
    wr_tready = 1'b1;
    wait (reads == 49);
    @(negedge sys_ckg);
    if (writes != 49 || lasts != 5 || rpt_cpt_cyc != 1 ||
        !fifo_out_empty || wr_tvalid || expected.size() != 0 || stalls == 0)
      $fatal(1, "TX final counts, stop behavior or scoreboard mismatch");
    $display("FIFO_OUT_FIFO2AXI PASS: 49 results, 4 MODEs, stalls, LAST, count and enable drop");
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "FIFO_OUT/FIFO2AXI integration timeout");
  end
endmodule

`default_nettype wire
