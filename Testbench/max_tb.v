`timescale 1ns/1ps

module max_tb;

  parameter DW = 32;
  parameter FRACTION = 16;

  reg clk;
  reg rst_n;
  reg valid_in;
  reg signed [10*DW-1:0] z2_in;

  wire valid_out;
  wire signed [DW-1:0] max_out;

  // DUT
  max_function #(
    .DW(DW),
    .N(10)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .z2_in(z2_in),
    .valid_out(valid_out),
    .max_out(max_out)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // -----------------------------
  // Fixed-point helpers
  // -----------------------------
  function [31:0] to_fixed;
    input real val;
    begin
      to_fixed = $rtoi(val * (1 << FRACTION));
    end
  endfunction

  function real to_real;
    input signed [31:0] val;
    begin
      // 65536.0 = 1 << 16 for Q16.16 format
      to_real = val / 65536.0; 
    end
  endfunction

  // -----------------------------
  // Pack function
  // -----------------------------
  function signed [10*32-1:0] pack;
    input real r9, r8, r7, r6, r5, r4, r3, r2, r1, r0;
    begin
      pack = {to_fixed(r9), to_fixed(r8), to_fixed(r7), to_fixed(r6),
              to_fixed(r5), to_fixed(r4), to_fixed(r3), to_fixed(r2),
              to_fixed(r1), to_fixed(r0)};
    end
  endfunction

  // -----------------------------
  // Expected queue (Verilog-2001 FIFO)
  // -----------------------------
  real expected_mem [0:31];
  integer push_idx;
  integer pop_idx;

  function real find_max;
    input real r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
    real m;
    begin
      m = r0;
      if (r1 > m) m = r1;
      if (r2 > m) m = r2;
      if (r3 > m) m = r3;
      if (r4 > m) m = r4;
      if (r5 > m) m = r5;
      if (r6 > m) m = r6;
      if (r7 > m) m = r7;
      if (r8 > m) m = r8;
      if (r9 > m) m = r9;
      find_max = m;
    end
  endfunction

  // -----------------------------
  // Monitor
  // -----------------------------
  integer cycle;

  always @(posedge clk) begin
    cycle = cycle + 1;

    $display("Cycle=%0d | vin=%0b | vout=%0b | max=%f",
              cycle, valid_in, valid_out, to_real(max_out));

    if (valid_out) begin
      $display(">>> Expected = %f | HW = %f",
                expected_mem[pop_idx], to_real(max_out));
      $display("----------------------------------");
      pop_idx = pop_idx + 1;
    end
  end

  // -----------------------------
  // Stimulus Task
  // -----------------------------
  task send_data;
    input real r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
    begin
      z2_in = pack(r9, r8, r7, r6, r5, r4, r3, r2, r1, r0);
      expected_mem[push_idx] = find_max(r0, r1, r2, r3, r4, r5, r6, r7, r8, r9);
      push_idx = push_idx + 1;
      @(posedge clk);
    end
  endtask

  // -----------------------------
  // Stimulus
  // -----------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    z2_in = 0;
    cycle = 0;
    
    // Initialize pointers
    push_idx = 0;
    pop_idx = 0;

    // Reset
    repeat(3) @(posedge clk);
    rst_n = 1;

    // -----------------------------
    // STREAMING INPUT (NO GAPS)
    // -----------------------------
    @(posedge clk);
    valid_in = 1;

    // cycle 1
    send_data(-22.88, -18.57, -9.95, 21.73, -29.23, 1.91, -40.80, -30.73, -9.74, -4.41);

    // cycle 2
    send_data(1.0, 5.0, 3.0, 7.0, 2.0, 0.0, -1.0, 6.0, 4.0, 8.0);

    // cycle 3
    send_data(-10.0, -5.0, -3.0, -20.0, -7.0, -1.0, -2.0, -9.0, -4.0, -6.0);

    // cycle 4
    send_data(0.5, 2.2, 1.1, 3.3, 0.9, 4.4, 2.8, 1.7, 3.9, 2.6);

    // stop input
    valid_in = 0;

    // Flush pipeline
    repeat(15) @(posedge clk);

    $finish;
  end

endmodule