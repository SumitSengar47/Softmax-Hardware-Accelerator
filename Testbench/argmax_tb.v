`timescale 1ns/1ps

module argmax_tb;

  parameter DW = 32;
  parameter FRACTION = 16;

  reg                          clk;
  reg                          rst_n;
  reg                          valid_in;
  reg signed [10*DW-1:0]       prob_in;
  
  wire                         valid_out;
  wire [3:0]                   pred_class;

  // -----------------------------
  // DUT Instantiation
  // -----------------------------
  argmax #(
    .DW(DW)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .prob_in(prob_in),
    .valid_out(valid_out),
    .pred_class(pred_class)
  );

  // -----------------------------
  // Fixed-point helper
  // -----------------------------
  function [31:0] to_fixed;
    input real val;
    begin
      to_fixed = $rtoi(val * (1 << FRACTION));
    end
  endfunction

  // -----------------------------
  // Clock Generation (100MHz)
  // -----------------------------
  initial clk = 0;
  always #5 clk = ~clk; 

  // -----------------------------
  // TASK: Inject flat data and track latency
  // -----------------------------
  task run_argmax_test;
    input real p0, p1, p2, p3, p4, p5, p6, p7, p8, p9;
    input [8*50:1] test_name; // Fixed width string buffer (up to 50 chars)
    
    time start_time, end_time;
    begin
      $display("\n==================================================");
      $display("  TEST: %0s", test_name);
      $display("==================================================");
      
      // 1. Inject data on the NEGATIVE edge
      @(negedge clk);
      start_time = $time;
      valid_in = 1;
      
      // Pack the vector manually (MSB to LSB: p9 down to p0)
      prob_in = {
        to_fixed(p9), to_fixed(p8), to_fixed(p7), to_fixed(p6), to_fixed(p5),
        to_fixed(p4), to_fixed(p3), to_fixed(p2), to_fixed(p1), to_fixed(p0)
      };
      
      // 2. Hold for exactly 1 clock cycle, then clear
      @(negedge clk);
      valid_in = 0;
      prob_in = 0;

      // 3. Wait for the FSM to reach the DONE state
      wait(valid_out == 1'b1);
      end_time = $time;
      
      // 4. Print results
      $display("[Time %0t] Result: Predicted Class = %0d", end_time, pred_class);
      $display("--> FSM Latency: %0d clock cycles", (end_time - start_time)/10);
      
      // Wait for FSM to safely return to IDLE before the next test
      repeat(3) @(posedge clk);
    end
  endtask

  // -----------------------------
  // Main Stimulus Sequence
  // -----------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    prob_in = 0;
    
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // Test 1: Data from your Multiplier Snapshot
    run_argmax_test(
      0.0694, 0.0347, 0.0000, 0.6944, 0.0000, 
      0.1389, 0.0000, 0.0000, 0.0347, 0.0278,
      "Snapshot Data (Expected Class: 3)"
    );

    // Test 2: Maximum at the very end
    run_argmax_test(
      0.0100, 0.0200, 0.0300, 0.0400, 0.0500, 
      0.0600, 0.0700, 0.0800, 0.0900, 0.9500,
      "Max at Index 9 (Expected Class: 9)"
    );

    // Test 3: Maximum at the very beginning
    run_argmax_test(
      0.9900, 0.0100, 0.0100, 0.0100, 0.0100, 
      0.0100, 0.0100, 0.0100, 0.0100, 0.0100,
      "Max at Index 0 (Expected Class: 0)"
    );

    $display("\n==================================================");
    $display("  SIMULATION COMPLETE");
    $display("==================================================");
    $finish;
  end

endmodule