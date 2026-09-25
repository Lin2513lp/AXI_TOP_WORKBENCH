`timescale 1ns/1ps
`default_nettype none

// Basic end-to-end example: eight packed TPU results become eight AXI beats.
module tb_AXI_S_TOP;
  localparam int BEATS = 8;
  logic sys_ckg = 0;
  always #5 sys_ckg = ~sys_ckg;
  logic tpu_rst_n = 0;
  logic cpu_tpu_en_sync = 0;
  logic cpu_tpu_start_sync = 0;
  logic [1:0] cpu_cpt_mode = 2'b10;
  logic [31:0] rpt_cpt_cyc;
  logic [15:0][31:0] data_out = '0;
  logic dat_out_vld = 0, dat_out_last = 0;
  // The receiver is ready before the producer asserts VALID and stays ready.
  logic wr_tready = 1;
  logic wr_tvalid;
  logic [511:0] wr_tdata;
  logic [63:0] wr_tkeep, wr_tstrb;
  logic wr_tlast, wr_tid, wr_tdest, wr_tuser;
  int sent = 0, received = 0, last_count = 0;

  AXI_S_TOP dut (.*);

  function automatic logic [511:0] expected_data(input int beat);
    for (int lane = 0; lane < 16; lane++)
      expected_data[lane*32 +: 32] = 32'h8000_0000 + 32'(beat*16 + lane);
  endfunction

  always @(posedge sys_ckg) begin
    if (tpu_rst_n) begin
      if (dat_out_vld) begin
        sent++;
      end
      if (wr_tvalid && wr_tready) begin
        if (received >= BEATS) $fatal(1, "AXI_S_TOP: extra output");
        if (wr_tdata !== expected_data(received))
          $fatal(1, "AXI_S_TOP: DATA mismatch at beat %0d", received);
        if (wr_tlast !== (received == BEATS-1))
          $fatal(1, "AXI_S_TOP: LAST mismatch at beat %0d", received);
        if (wr_tkeep !== 64'hffffffffffffffff || wr_tstrb !== 64'hffffffffffffffff ||
            wr_tid !== 1'b0 || wr_tdest !== 1'b0 || wr_tuser !== 1'b1)
          $fatal(1, "AXI_S_TOP: sideband mismatch");
        $display("S transfer beat=%0d low32=%h last=%b user=%b time=%0t",
                 received, wr_tdata[31:0], wr_tlast, wr_tuser, $time);
        if (wr_tlast) last_count++;
        received++;
      end
    end
  end

  initial begin
    repeat (3) @(negedge sys_ckg);
    tpu_rst_n = 1;
    cpu_tpu_en_sync = 1;
    cpu_tpu_start_sync = 1;
    @(negedge sys_ckg);
    cpu_tpu_start_sync = 0;
    for (int beat = 0; beat < BEATS; beat++) begin
      @(negedge sys_ckg);
      dat_out_vld = 0;
      for (int lane = 0; lane < 16; lane++)
        data_out[lane] = 32'h8000_0000 + 32'(beat*16 + lane);
      dat_out_last = (beat == BEATS-1);
      dat_out_vld = 1;
      @(posedge sys_ckg);
    end
    @(negedge sys_ckg);
    dat_out_vld = 0;
    dat_out_last = 0;
    wait (received == BEATS);
    repeat (3) @(negedge sys_ckg);
    if (sent != BEATS || last_count != 1 || rpt_cpt_cyc !== 32'd8 || wr_tvalid)
      $fatal(1, "AXI_S_TOP: final count/drain mismatch");
    $display("AXI_S_TOP PASS: sent=%0d received=%0d last=%0d rpt_cpt_cyc=%0d width=512", sent, received, last_count, rpt_cpt_cyc);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "AXI_S_TOP: timeout");
  end
endmodule

`default_nettype wire
