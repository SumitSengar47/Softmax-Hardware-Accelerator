`timescale 1ns/1ps

module reciprocal_tb;

  parameter DW = 32;
  parameter FRACTION = 16;

  reg                  clk;
  reg                  rst_n;
  reg                  valid_in;
  reg signed [DW-1:0]  sum_in;
  wire                 valid_out;
  wire signed [DW-1:0] inv_out;

  reciprocal #(
    .DW(DW),
    .FRAC(FRACTION)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .sum_in(sum_in),
    .valid_out(valid_out),
    .inv_out(inv_out)
  );

  // -----------------------------
  // Clock Generation (100MHz)
  // -----------------------------
  initial clk = 0;
  always #5 clk = ~clk; // 10ns clock period

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
      to_real = val / 65536.0; // 65536.0 = 2^16 for Q16.16 format
    end
  endfunction

  // =========================================================
  // TASK: Inject one value and wait for the result
  // =========================================================
  task test_single_value;
    input real val;
    time start_time;
    time end_time;
    begin
      // 1. Inject data on the NEGATIVE edge to prevent simulator race conditions
      @(negedge clk);
      start_time = $time;
      valid_in = 1;
      sum_in = to_fixed(val);
      $display("\n[Time %0t] INJECTING: sum = %7.4f", start_time, val);

      // 2. Hold for exactly 1 clock cycle, then clear inputs
      @(negedge clk);
      valid_in = 0;
      sum_in = 0;

      // 3. Wait until the DUT says the output is ready
      wait(valid_out == 1'b1);
      end_time = $time;
      
      // 4. Print the result and the latency
      $display("[Time %0t] RECEIVED : 1/sum = %7.4f", end_time, to_real(inv_out));
      $display("--> Latency: %0t ns (%0d clock cycles)", 
               (end_time - start_time), 
               (end_time - start_time)/10);
               
      // Wait a couple of empty cycles before the next test to keep waveforms clean
      repeat(3) @(posedge clk);
    end
  endtask

  // =========================================================
  // Main Stimulus Sequence
  // =========================================================
  initial begin
    rst_n = 0;
    sum_in = 0;
    valid_in = 0;
    
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    $display("==================================================");
    $display("  SINGLE-SHOT LATENCY TESTING");
    $display("==================================================");

    // Test a few specific values one at a time
    test_single_value(1.00);
    test_single_value(3.14);
    test_single_value(10.00);

    $display("\n==================================================");
    $display("  SIMULATION COMPLETE");
    $display("==================================================");
    $finish;
  end

endmodule