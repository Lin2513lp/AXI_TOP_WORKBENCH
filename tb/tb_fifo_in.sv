`timescale 1ns/1ps
`default_nettype none

module fifo_in_test_case #(
  parameter int unsigned DATA_WIDTH = 512,
  parameter int unsigned DEPTH = 8,
  parameter int unsigned PRE_FULL_THRESHOLD = (DEPTH > 1) ? DEPTH - 1 : 1
) (
  output logic done
);
  logic sys_ckg = 1'b0;
  logic tpu_rst_n;
  logic fifo_in_we;
  logic [DATA_WIDTH-1:0] fifo_in_wdata;
  logic rd_dat_last;
  logic fifo_in_pre_full;
  logic fifo_in_re;
  logic fifo_empty;
  logic [DATA_WIDTH-1:0] fifo_in_rdata;
  logic fifo_in_rd_dat_last;

  logic [DATA_WIDTH:0] expected [0:DEPTH-1];
  integer occupancy;
  integer sequence_id;
  integer push_count;
  integer pop_count;

  fifo_in #(
    .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH),
    .PRE_FULL_THRESHOLD(PRE_FULL_THRESHOLD)
  ) dut (.*);

  always #5 sys_ckg = ~sys_ckg;

  // Exercise every data bit, including the upper bits of each 512-bit beat.
  function automatic logic [DATA_WIDTH-1:0] pattern(input integer tag);
    for (integer bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
      pattern[bit_index] = (((tag * 37 + bit_index * 13 + bit_index / 7)
                            >> (bit_index % 17)) & 1) != 0;
    end
  endfunction

  task automatic check_head;
    if (fifo_empty !== (occupancy == 0)) begin
      $fatal(1, "FIFO_IN depth=%0d EMPTY mismatch occupancy=%0d", DEPTH, occupancy);
    end
    if (fifo_in_pre_full !== (occupancy >= PRE_FULL_THRESHOLD)) begin
      $fatal(1, "FIFO_IN depth=%0d PRE_FULL mismatch occupancy=%0d", DEPTH, occupancy);
    end
    if (occupancy == 0) begin
      if (fifo_in_rdata !== '0 || fifo_in_rd_dat_last !== 1'b0) begin
        $fatal(1, "FIFO_IN depth=%0d empty outputs not zero", DEPTH);
      end
    end else begin
      if ({fifo_in_rd_dat_last, fifo_in_rdata} !== expected[0]) begin
        $fatal(1, "FIFO_IN depth=%0d DATA/LAST order or stall mismatch", DEPTH);
      end
    end
  endtask

  task automatic reset_fifo;
    @(negedge sys_ckg);
    tpu_rst_n = 1'b0;
    fifo_in_we = 1'b0;
    fifo_in_re = 1'b0;
    occupancy = 0;
    #1;
    check_head();
    repeat (2) @(posedge sys_ckg);
    @(negedge sys_ckg);
    tpu_rst_n = 1'b1;
    #1;
    check_head();
  endtask

  task automatic step(input logic write_request, input logic read_request,
                      input logic last_value);
    logic expected_pop;
    logic expected_push;
    @(negedge sys_ckg);
    fifo_in_we = write_request;
    fifo_in_re = read_request;
    fifo_in_wdata = pattern(sequence_id);
    rd_dat_last = last_value;
    sequence_id = sequence_id + 1;
    #1;
    check_head();
    expected_pop = read_request && occupancy != 0;
    expected_push = write_request && (occupancy < DEPTH || expected_pop);

    @(posedge sys_ckg);
    // Scoreboard consumes the old head before appending a simultaneous write.
    if (expected_pop) begin
      for (integer index = 0; index < occupancy - 1; index++) begin
        expected[index] = expected[index + 1];
      end
      occupancy = occupancy - 1;
      pop_count = pop_count + 1;
    end
    if (expected_push) begin
      expected[occupancy] = {rd_dat_last, fifo_in_wdata};
      occupancy = occupancy + 1;
      push_count = push_count + 1;
    end
    #1;
    check_head();
  endtask

  initial begin
    done = 1'b0;
    tpu_rst_n = 1'b0;
    fifo_in_we = 1'b0;
    fifo_in_re = 1'b0;
    fifo_in_wdata = '0;
    rd_dat_last = 1'b0;
    occupancy = 0;
    sequence_id = 1;
    push_count = 0;
    pop_count = 0;
    reset_fifo();

    // Empty reads are rejected; simultaneous empty read/write enqueues one.
    repeat (3) step(1'b0, 1'b1, 1'b0);
    step(1'b1, 1'b1, 1'b1);
    repeat (4) step(1'b0, 1'b0, 1'b0);
    step(1'b0, 1'b1, 1'b0);

    // Fill past PRE_FULL to actual full, then reject overflow writes.
    for (integer index = 0; index < DEPTH; index++) begin
      step(1'b1, 1'b0, (index % 3) == 0);
    end
    repeat (3) step(1'b1, 1'b0, 1'b1);
    // Full replacement must accept both operations without changing occupancy.
    repeat (DEPTH * 4 + 3) step(1'b1, 1'b1, (sequence_id % 5) == 0);
    repeat (DEPTH) step(1'b0, 1'b1, 1'b0);
    step(1'b0, 1'b1, 1'b0);

    // Many wraps, intermittent stalls, overflow/underflow and varying LAST.
    repeat (1000) begin
      step($urandom_range(0, 1) != 0, $urandom_range(0, 1) != 0,
           $urandom_range(0, 4) == 0);
    end
    while (occupancy != 0) step(1'b0, 1'b1, 1'b0);

    // Reset discards outstanding data and its LAST; old memory must stay hidden.
    repeat (DEPTH) step(1'b1, 1'b0, 1'b1);
    reset_fifo();
    step(1'b0, 1'b1, 1'b0);
    step(1'b1, 1'b0, 1'b0);
    repeat (3) step(1'b0, 1'b0, 1'b1);
    step(1'b0, 1'b1, 1'b0);
    @(negedge sys_ckg);
    fifo_in_we = 1'b0;
    fifo_in_re = 1'b0;
    $display("FIFO_IN case PASS: width=%0d depth=%0d threshold=%0d pushes=%0d pops=%0d",
             DATA_WIDTH, DEPTH, PRE_FULL_THRESHOLD, push_count, pop_count);
    done = 1'b1;
  end
endmodule

module tb_fifo_in;
  logic [4:0] done;
  fifo_in_test_case #(.DEPTH(1)) case_depth1 (.done(done[0]));
  fifo_in_test_case #(.DEPTH(3)) case_depth3 (.done(done[1]));
  fifo_in_test_case #(.DEPTH(8)) case_depth8 (.done(done[2]));
  fifo_in_test_case #(.DATA_WIDTH(17), .DEPTH(3), .PRE_FULL_THRESHOLD(3))
    case_custom (.done(done[3]));
  fifo_in_test_case #(.DEPTH(512)) case_depth512 (.done(done[4]));

  initial begin
    wait (&done);
    $display("FIFO_IN PASS: all parameter cases and DATA/LAST scoreboard checks");
    $finish;
  end
  initial begin
    #500000;
    $fatal(1, "FIFO_IN TIMEOUT");
  end
endmodule

`default_nettype wire
