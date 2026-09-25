`timescale 1ns/1ps
`default_nettype none

// One AXI packet through AXI_M_TOP; print each beat read from FIFO_IN.
module tb_AXI_M_TOP;
  localparam int BEATS = 10;

  logic sys_ckg = 1'b0;
  always #5 sys_ckg = ~sys_ckg;

  logic tpu_rst_n = 1'b0;
  logic cpu_tpu_en_sync = 1'b0;
  logic cpu_tpu_start_sync = 1'b0;
  logic rd_tready;
  logic rd_tvalid = 1'b0;
  logic [511:0] rd_tdata = '0;
  logic [63:0] rd_tkeep = '1;
  logic [63:0] rd_tstrb = '1;
  logic rd_tlast = 1'b0;
  logic rd_tid = 1'b0;
  logic rd_tdest = 1'b0;
  logic rd_tuser = 1'b0;
  logic fifo_in_re = 1'b0;
  logic fifo_empty;
  logic [511:0] fifo_in_rdata;
  logic fifo_in_rd_dat_last;
  int sent = 0;
  int received = 0;
  bit pre_full_seen = 1'b0;
  bit valid_before_ready_seen = 1'b0;

  AXI_M_TOP dut (.*);

  // Observe the FWFT head before this edge removes it from FIFO_IN.
  always @(posedge sys_ckg) begin
    if (tpu_rst_n) begin
      if (rd_tvalid && !rd_tready && !cpu_tpu_start_sync && sent == 0)
        valid_before_ready_seen = 1'b1;
      if (rd_tvalid && dut.fifo_in_pre_full) begin
        if (rd_tready)
          $fatal(1, "AXI READY stayed high during FIFO PRE_FULL");
        if (!pre_full_seen)
          $display("M PRE_FULL backpressure: DATA held at %0t", $time);
        pre_full_seen = 1'b1;
      end
      if (rd_tvalid && rd_tready)
        sent++;

      if (fifo_in_re && !fifo_empty) begin
        if (received >= BEATS ||
            fifo_in_rdata !== {16{32'hA500_0000 + 32'(received)}} ||
            fifo_in_rd_dat_last !== (received == BEATS-1))
          $fatal(1, "M FIFO output mismatch at beat %0d", received);
        $display("M FIFO_IN beat=%0d data=%h last=%b time=%0t",
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
    rd_tvalid = 1'b1;  // Present first DATA and VALID while READY is low.

    @(posedge sys_ckg);
    if (rd_tready !== 1'b0)
      $fatal(1, "M READY rose before START");
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
            @(posedge sys_ckg);  // Keep VALID, DATA and LAST stable.
        end
        @(negedge sys_ckg);
        rd_tvalid = 1'b0;
        rd_tlast = 1'b0;
      end
      begin
        // FIFO depth is eight. Seven queued beats assert PRE_FULL; RE then
        // frees space so the blocked AXI beat can complete its handshake.
        repeat (18) @(negedge sys_ckg);
        fifo_in_re = 1'b1;
      end
    join

    wait (received == BEATS);
    @(negedge sys_ckg);
    if (sent != BEATS || !fifo_empty || !pre_full_seen ||
        !valid_before_ready_seen)
      $fatal(1, "M path count, drain or required timing scenario missing");
    $display("AXI_M_TOP PASS: %0d beats, VALID before READY, PRE_FULL stall", BEATS);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "AXI_M_TOP timeout");
  end
endmodule

`default_nettype wire
