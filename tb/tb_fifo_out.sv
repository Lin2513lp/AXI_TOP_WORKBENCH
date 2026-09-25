`timescale 1ns/1ps
`default_nettype none

module fifo_out_test_case #(
  parameter int unsigned LANE_COUNT = 16,
  parameter int unsigned LANE_WIDTH = 32,
  parameter int unsigned DEPTH = 8
) (
  output logic done
);
  localparam int unsigned DATA_WIDTH = LANE_COUNT * LANE_WIDTH;
  logic sys_ckg;
  logic tpu_rst_n;
  logic [LANE_COUNT-1:0][LANE_WIDTH-1:0] data_out;
  logic dat_out_vld;
  logic dat_out_last;
  logic fifo_out_re;
  logic fifo_out_empty;
  logic [DATA_WIDTH-1:0] fifo_out_rdata;
  logic data_out_last;
  logic [DATA_WIDTH:0] expected [0:DEPTH-1];
  integer occupancy;
  integer sequence_id;
  integer push_count;
  integer pop_count;

  fifo_out #(
    .LANE_COUNT(LANE_COUNT), .LANE_WIDTH(LANE_WIDTH), .DEPTH(DEPTH)
  ) dut (.*);

  always #5 sys_ckg = ~sys_ckg;

  // Each lane has its own pattern; vary all bits across the complete beat.
  function automatic logic [LANE_WIDTH-1:0] lane_pattern(
    input integer tag, input integer lane
  );
    for (integer bit_index = 0; bit_index < LANE_WIDTH; bit_index++) begin
      lane_pattern[bit_index] = (((tag * 37 + lane * 53 + bit_index * 13)
                                >> (bit_index % 11)) & 1) != 0;
    end
  endfunction

  // Build the reference bus by explicit bit positions, independently of the
  // DUT's packed-vector concatenation, to check lane order as well as storage.
  function automatic logic [DATA_WIDTH-1:0] packed_reference;
    for (integer lane = 0; lane < LANE_COUNT; lane++) begin
      for (integer bit_index = 0; bit_index < LANE_WIDTH; bit_index++) begin
        packed_reference[lane*LANE_WIDTH + bit_index] = data_out[lane][bit_index];
      end
    end
  endfunction

  task automatic check_head;
    if (fifo_out_empty !== (occupancy == 0)) begin
      $fatal(1, "FIFO_OUT depth=%0d EMPTY mismatch occupancy=%0d", DEPTH, occupancy);
    end
    if (occupancy == 0) begin
      if (fifo_out_rdata !== '0 || data_out_last !== 1'b0) begin
        $fatal(1, "FIFO_OUT depth=%0d empty outputs not zero", DEPTH);
      end
    end else begin
      if ({data_out_last, fifo_out_rdata} !== expected[0]) begin
        $fatal(1, "FIFO_OUT depth=%0d DATA/LAST packing, order or stall mismatch", DEPTH);
      end
    end
  endtask

  task automatic reset_fifo;
    @(negedge sys_ckg);
    // Assert away from a rising edge to exercise asynchronous reset.
    #2;
    tpu_rst_n = 1'b0;
    dat_out_vld = 1'b1;
    fifo_out_re = 1'b1;
    dat_out_last = 1'b1;
    data_out = '1;
    occupancy = 0;
    #1;
    check_head();
    repeat (2) begin
      @(posedge sys_ckg);
      #1;
      check_head();
    end
    @(negedge sys_ckg);
    dat_out_vld = 1'b0;
    fifo_out_re = 1'b0;
    tpu_rst_n = 1'b1;
    #1;
    check_head();
  endtask

  task automatic step(input logic write_request, input logic read_request,
                      input logic last_value);
    logic expected_pop;
    logic expected_push;
    logic [DATA_WIDTH:0] incoming;
    @(negedge sys_ckg);
    dat_out_vld = write_request;
    fifo_out_re = read_request;
    for (integer lane = 0; lane < LANE_COUNT; lane++) begin
      data_out[lane] = lane_pattern(sequence_id, lane);
    end
    dat_out_last = last_value;
    sequence_id = sequence_id + 1;
    incoming = {dat_out_last, packed_reference()};
    #1;
    // Invalid writes and changing producer LAST must never disturb the head.
    check_head();
    expected_pop = read_request && occupancy != 0;
    expected_push = write_request && (occupancy < DEPTH || expected_pop);

    @(posedge sys_ckg);
    if (expected_pop) begin
      for (integer index = 0; index < occupancy - 1; index++) begin
        expected[index] = expected[index + 1];
      end
      occupancy = occupancy - 1;
      pop_count = pop_count + 1;
    end
    if (expected_push) begin
      expected[occupancy] = incoming;
      occupancy = occupancy + 1;
      push_count = push_count + 1;
    end
    #1;
    check_head();
  endtask

  initial begin
    sys_ckg = 1'b0;
    done = 1'b0;
    tpu_rst_n = 1'b0;
    data_out = '0;
    dat_out_vld = 1'b0;
    dat_out_last = 1'b0;
    fifo_out_re = 1'b0;
    occupancy = 0;
    sequence_id = 1;
    push_count = 0;
    pop_count = 0;
    reset_fifo();

    // Underflow protection, no empty bypass, and LAST held over long stalls.
    repeat (3) step(1'b0, 1'b1, 1'b0);
    step(1'b1, 1'b1, 1'b1);
    repeat (5) step(1'b0, 1'b0, 1'b0);
    step(1'b0, 1'b1, 1'b0);

    for (integer index = 0; index < DEPTH; index++) begin
      step(1'b1, 1'b0, (index % 3) == 0);
    end
    // The port no longer exposes FULL, but the internal guard must still reject
    // accidental overflow without overwriting unread DATA/LAST.
    repeat (4) step(1'b1, 1'b0, 1'b1);
    // Full replacements exercise old-head consumption and pointer wrap.
    repeat (DEPTH * 4 + 3) step(1'b1, 1'b1, (sequence_id % 5) == 0);
    repeat (DEPTH) step(1'b0, 1'b1, 1'b0);
    step(1'b0, 1'b1, 1'b0);

    // Sequential input fills every lane with distinct values.
    repeat (DEPTH * 3 + 5) begin
      step(1'b1, 1'b0, 1'b0);
      step(1'b0, 1'b0, 1'b1);
      step(1'b0, 1'b1, 1'b0);
    end
    // Many wraps and holes in valid/read requests, including deliberate
    // overflow attempts that exercise only the FIFO's internal protection.
    repeat (1500) begin
      step($urandom_range(0, 1) != 0, $urandom_range(0, 1) != 0,
           $urandom_range(0, 4) == 0);
    end
    while (occupancy != 0) step(1'b0, 1'b1, 1'b0);

    repeat (DEPTH) step(1'b1, 1'b0, 1'b1);
    reset_fifo();
    step(1'b0, 1'b1, 1'b0);
    step(1'b1, 1'b0, 1'b0);
    repeat (3) step(1'b0, 1'b0, 1'b1);
    step(1'b0, 1'b1, 1'b0);
    @(negedge sys_ckg);
    dat_out_vld = 1'b0;
    fifo_out_re = 1'b0;
    $display("FIFO_OUT case PASS: lanes=%0d width=%0d depth=%0d pushes=%0d pops=%0d",
             LANE_COUNT, LANE_WIDTH, DEPTH, push_count, pop_count);
    done = 1'b1;
  end
endmodule

module tb_fifo_out;
  logic [4:0] done;
  fifo_out_test_case #(.DEPTH(1)) case_depth1 (.done(done[0]));
  fifo_out_test_case #(.DEPTH(3)) case_depth3 (.done(done[1]));
  fifo_out_test_case #(.DEPTH(8)) case_depth8 (.done(done[2]));
  fifo_out_test_case #(.LANE_COUNT(3), .LANE_WIDTH(7), .DEPTH(3))
    case_custom (.done(done[3]));
  fifo_out_test_case #(.DEPTH(512)) case_depth512 (.done(done[4]));

  initial begin
    wait (&done);
    $display("FIFO_OUT PASS: all parameter cases and DATA/LAST scoreboard checks");
    $finish;
  end
  initial begin
    #500000;
    $fatal(1, "FIFO_OUT TIMEOUT");
  end
endmodule

`default_nettype wire
