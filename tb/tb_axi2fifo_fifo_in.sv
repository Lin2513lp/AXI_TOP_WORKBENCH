`timescale 1ns/1ps
`default_nettype none

// One AXI packet through axi2fifo -> fifo_in. Hold the FIFO reader to
// demonstrate PRE_FULL backpressure, then print every consumed FIFO beat.
module tb_axi2fifo_fifo_in;
  localparam int BEATS = 9;
  localparam int DEPTH = 4;  // PRE_FULL rises after three queued beats.

  logic sys_ckg = 1'b0;
  always #5 sys_ckg = ~sys_ckg;

  logic tpu_rst_n = 1'b0;
  logic cpu_tpu_en_sync = 1'b0;
  logic cpu_tpu_start_sync = 1'b0;
  logic rd_tready;
  logic rd_tvalid = 1'b0;
  logic [511:0] rd_tdata = '0;
  logic rd_tlast = 1'b0;
  logic fifo_in_we;
  logic fifo_in_pre_full;
  logic [511:0] fifo_in_wdata;
  logic rd_dat_last;
  logic fifo_in_re = 1'b0;
  logic fifo_empty;
  logic [511:0] fifo_in_rdata;
  logic fifo_in_rd_dat_last;
  int sent = 0;
  int received = 0;
  bit pre_full_seen = 1'b0;
  bit valid_before_ready_seen = 1'b0;

  axi2fifo u_axi2fifo (
    .sys_ckg, .tpu_rst_n, .cpu_tpu_en_sync, .cpu_tpu_start_sync,
    .rd_tready, .rd_tvalid, .rd_tdata,
    .rd_tkeep('1), .rd_tstrb('1), .rd_tlast,
    .rd_tid(1'b0), .rd_tdest(1'b0), .rd_tuser(1'b0),
    .fifo_in_we, .fifo_in_pre_full, .fifo_in_wdata, .rd_dat_last
  );

  fifo_in #(.DEPTH(DEPTH)) u_fifo_in (
    .sys_ckg, .tpu_rst_n, .fifo_in_we, .fifo_in_pre_full,
    .fifo_in_wdata, .rd_dat_last, .fifo_in_re, .fifo_empty,
    .fifo_in_rdata, .fifo_in_rd_dat_last
  );

  // FWFT data belongs to the head being consumed at this rising edge.
  always @(posedge sys_ckg) begin
    if (tpu_rst_n) begin
      if (fifo_in_we !== (rd_tvalid && rd_tready))
        $fatal(1, "FIFO write must equal the AXI handshake");
      if (rd_dat_last !== (fifo_in_we && rd_tlast))
        $fatal(1, "LAST must accompany the accepted data beat");

      if (rd_tvalid && !rd_tready && !cpu_tpu_start_sync && sent == 0)
        valid_before_ready_seen = 1'b1;
      if (rd_tvalid && fifo_in_pre_full) begin
        if (rd_tready || fifo_in_we)
          $fatal(1, "AXI input transferred during PRE_FULL");
        if (!pre_full_seen)
          $display("PRE_FULL backpressure: DATA held at %0t", $time);
        pre_full_seen = 1'b1;
      end

      if (rd_tvalid && rd_tready)
        sent++;

      if (fifo_in_re && !fifo_empty) begin
        if (received >= BEATS ||
            fifo_in_rdata !== {16{32'hA500_0000 + 32'(received)}} ||
            fifo_in_rd_dat_last !== (received == BEATS-1))
          $fatal(1, "FIFO output mismatch at beat %0d", received);
        $display("FIFO_IN beat=%0d data=%h last=%b time=%0t",
                 received, fifo_in_rdata, fifo_in_rd_dat_last, $time);
        received++;
      end
    end
  end

  initial begin
    repeat (3) @(negedge sys_ckg);
    tpu_rst_n = 1'b1;
    cpu_tpu_en_sync = 1'b1;
    rd_tdata = {16{32'hA500_0000}};
    rd_tvalid = 1'b1;  // VALID and the first DATA precede READY.

    @(posedge sys_ckg);
    if (rd_tready !== 1'b0)
      $fatal(1, "READY rose before START");
    @(negedge sys_ckg);
    cpu_tpu_start_sync = 1'b1;
    @(negedge sys_ckg);
    cpu_tpu_start_sync = 1'b0;

    fork
      begin
        for (int beat = 0; beat < BEATS; beat++) begin
          if (beat != 0) begin
            @(negedge sys_ckg);
            rd_tdata = {16{32'hA500_0000 + 32'(beat)}};
            rd_tlast = (beat == BEATS-1);
          end
          @(posedge sys_ckg);
          while (!rd_tready)
            @(posedge sys_ckg);  // Keep VALID, DATA and LAST unchanged.
        end
        @(negedge sys_ckg);
        rd_tvalid = 1'b0;
        rd_tlast = 1'b0;
      end
      begin
        // First fill three entries; releasing RE later clears PRE_FULL.
        repeat (12) @(negedge sys_ckg);
        fifo_in_re = 1'b1;
      end
    join

    wait (received == BEATS);
    @(negedge sys_ckg);
    if (sent != BEATS || !fifo_empty || !pre_full_seen ||
        !valid_before_ready_seen)
      $fatal(1, "M path count, drain or required timing scenario missing");
    $display("AXI2FIFO_FIFO_IN PASS: %0d beats, VALID before READY, PRE_FULL stall", BEATS);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "AXI2FIFO/FIFO_IN timeout");
  end
endmodule

`default_nettype wire
