`timescale 1ns/1ps

module softmax_tb;

  parameter DW = 32;
  parameter NUM_INST = 10;
  parameter FRACTION = 16;

  reg                          clk;
  reg                          rst_n;
  reg                          valid_in;
  reg signed [10*DW-1:0]       data_in;
  
  wire                         valid_out;
  wire [3:0]                   pred_class;
  wire                         ready;

  // Counters for the self-checking mechanism
  integer tests_run;
  integer tests_passed;

  // ---------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------
  softmax_top #(
    .DW(DW),
    .NUM_INST(NUM_INST)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .data_in(data_in),
    .valid_out(valid_out),
    .pred_class(pred_class),
    .ready(ready)
  );

  // ---------------------------------------------------------
  // Clock Generation (100MHz)
  // ---------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk; 

  // ---------------------------------------------------------
  // Fixed-Point Converter
  // ---------------------------------------------------------
  function [31:0] to_fixed;
    input real val;
    begin
      to_fixed = $rtoi(val * (1 << FRACTION));
    end
  endfunction

  // ---------------------------------------------------------
  // AUTOMATED TASK: Inject, Wait, and Verify
  // ---------------------------------------------------------
  task run_stress_test;
    input [8*50:1] test_name; // String buffer
    input real d0, d1, d2, d3, d4, d5, d6, d7, d8, d9;
    input [3:0] expected_class;
    
    time start_time, end_time;
    begin
      tests_run = tests_run + 1;
      
      // 1. Wait until FSM is ready
      wait(ready == 1'b1);
      
      // 2. Inject on negative edge to prevent setup/hold violations in sim
      @(negedge clk);
      start_time = $time;
      valid_in = 1;
      
      // Pack the inputs
      data_in = {
        to_fixed(d9), to_fixed(d8), to_fixed(d7), to_fixed(d6), to_fixed(d5),
        to_fixed(d4), to_fixed(d3), to_fixed(d2), to_fixed(d1), to_fixed(d0)
      };

      // 3. Clear inputs after exactly 1 cycle to prove FSM internal buffering
      @(negedge clk);
      valid_in = 0;
      data_in = { (10*DW) {1'bx} }; 

      // 4. Wait for hardware calculation to finish
      wait(valid_out == 1'b1);
      end_time = $time;
      
      // 5. Verification Logging
      $display("---------------------------------------------------------");
      $display("TEST %0d: %0s", tests_run, test_name);
      $display("Latency : %0d cycles", (end_time - start_time)/10);
      
      if (pred_class === expected_class) begin
        $display("RESULT  : PASS (Got Class %0d)", pred_class);
        tests_passed = tests_passed + 1;
      end else begin
        $display("RESULT  : FAIL !!! (Expected %0d, Got %0d)", expected_class, pred_class);
      end
      
      // Cool down cycles between tests
      repeat(5) @(posedge clk);
    end
  endtask

  // ---------------------------------------------------------
  // Main Verification Sequence
  // ---------------------------------------------------------
  initial begin
    // Initialize Variables
    rst_n = 0;
    valid_in = 0;
    data_in = 0;
    tests_run = 0;
    tests_passed = 0;
    
    $display("\n=========================================================");
    $display("  STARTING INTENSE SOFTMAX VERIFICATION SUITE (20 TESTS)");
    $display("=========================================================");

    // Hard Reset System
    repeat(5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // =========================================================
    // PART 1: SYSTEM STRESS & BOUNDARY TESTS (1-10)
    // =========================================================
    
    // Test 1: Original Z2 Vector from Project Specifications
    run_stress_test("Normal Z2 Vector (Spec)", 
                    -22.88, -18.57, -9.95, 21.73, -29.23, 1.91, -40.80, -30.73, -9.74, -4.41, 
                    4'd3);

    // Test 2: Absolute Zeros (Tests divider stability)
    run_stress_test("Flatline (All Zeros)", 
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    4'd0);

    // Test 3: Large Uniform Positives (Tests subtractor saturation)
    run_stress_test("Flatline (Large Uniform +50)", 
                    50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 
                    4'd0);

    // Test 4: Extreme Negatives (Tests two's complement boundaries)
    run_stress_test("Extreme Negatives (Increasing)", 
                    -100.0, -90.0, -80.0, -70.0, -60.0, -50.0, -40.0, -30.0, -20.0, -10.0, 
                    4'd9);

    // Test 5: Exact Tie across Data Path
    run_stress_test("Exact Max Value Tie (Idx 4 vs 8)", 
                    1.0, 2.0, 3.0, 4.0, 15.5, 5.0, 6.0, 7.0, 15.5, 8.0, 
                    4'd4);

    // Test 6: Index 0 Maximum
    run_stress_test("Index 0 Dominant", 
                    10.0, -1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, -9.0, 
                    4'd0);

    // Test 7: Index 9 Maximum
    run_stress_test("Index 9 Dominant", 
                    -9.0, -8.0, -7.0, -6.0, -5.0, -4.0, -3.0, -2.0, -1.0, 10.0, 
                    4'd9);

    // Test 8: Alternating High/Low Spikes
    run_stress_test("Alternating Spikes", 
                    -20.0, 20.0, -20.0, 20.0, -20.0, 20.0, -20.0, 25.0, -20.0, 20.0, 
                    4'd7);

    // Test 9: One Massive Outlier
    run_stress_test("The Massive Outlier", 
                    -50.0, -50.0, -50.0, -50.0, 80.0, -50.0, -50.0, -50.0, -50.0, -50.0, 
                    4'd4);

    // Test 10: Deep Negative Tie Breaker
    run_stress_test("Deep Negative Tie (Idx 2 vs 5)", 
                    -50.0, -50.0, -10.0, -50.0, -50.0, -10.0, -50.0, -50.0, -50.0, -50.0, 
                    4'd2);

    // =========================================================
    // PART 2: REALISTIC MNIST NEURAL NET DATA (11-20)
    // =========================================================

    // Test 11: High Confidence '0'
    run_stress_test("MNIST: Clear '0'", 
                    12.5, -2.1, -1.0, 0.5, -3.4, 1.2, -5.0, 0.0, -1.1, -2.2, 
                    4'd0);

    // Test 12: High Confidence '1'
    run_stress_test("MNIST: Clear '1'", 
                    -4.0, 15.2, 1.1, -2.0, -3.0, 0.0, 1.5, 2.2, -1.0, 0.5, 
                    4'd1);

    // Test 13: Standard '2'
    run_stress_test("MNIST: Clear '2'", 
                    0.1, 0.2, 9.8, 1.0, -1.5, -2.5, 0.0, 0.5, 1.1, -3.0, 
                    4'd2);

    // Test 14: Confused '3' vs '5' (3 barely wins)
    run_stress_test("MNIST: Confused '3' vs '5' (3 wins)", 
                    -1.0, 0.0, 1.2, 8.4, -2.0, 7.9, -3.0, 0.5, 1.0, -1.5, 
                    4'd3);

    // Test 15: Confused '4' vs '9' (9 wins)
    run_stress_test("MNIST: Confused '4' vs '9' (9 wins)", 
                    0.0, -1.0, -2.0, 0.5, 8.1, 1.0, -1.5, 2.0, 1.5, 8.6, 
                    4'd9);

    // Test 16: Blurry Low Confidence '6'
    run_stress_test("MNIST: Low Confidence '6'", 
                    1.1, 0.5, 1.2, 0.8, 1.0, 0.9, 3.5, 0.2, 1.5, 0.1, 
                    4'd6);

    // Test 17: Deep Negative Weights '7'
    run_stress_test("MNIST: Very High Confidence '7'", 
                    -10.5, -15.2, -8.0, -9.1, -12.0, -11.1, -20.0, 25.4, -14.2, -9.9, 
                    4'd7);

    // Test 18: Confused '8' vs '0' (Loops in handwriting)
    run_stress_test("MNIST: Confused '8' vs '0' (8 wins)", 
                    6.5, -1.0, 0.5, -2.0, 1.0, -1.5, 2.0, -0.5, 7.2, 1.1, 
                    4'd8);

    // Test 19: Standard '9'
    run_stress_test("MNIST: Clear '9'", 
                    -2.0, -3.0, -4.0, 1.0, 5.0, -1.0, -2.0, 6.0, 1.0, 14.5, 
                    4'd9);

    // Test 20: Dead Tie '1' and '7'
    run_stress_test("MNIST: Dead Tie '1' vs '7' (Hardware picks 1)", 
                    -1.0, 8.5, 0.0, 1.0, -2.0, -3.0, 0.5, 8.5, -1.0, 0.0, 
                    4'd1);

    // =========================================================
    // FINAL REPORT
    // =========================================================
    $display("=========================================================");
    $display("  VERIFICATION COMPLETE");
    $display("  Total Tests Run    : %0d", tests_run);
    $display("  Total Tests Passed : %0d", tests_passed);
    
    if (tests_run == tests_passed) begin
      $display("\n  >>> HARDWARE SIGN-OFF APPROVED: 100%% PASS <<<");
    end else begin
      $display("\n  >>> HARDWARE SIGN-OFF REJECTED: ERRORS DETECTED <<<");
    end
    $display("=========================================================");
    
    $finish;
  end

endmodule