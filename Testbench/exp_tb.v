`timescale 1ns/1ps

module exp_tb;

  parameter DW = 32;
  parameter FRACTION = 16;
  parameter NUM_INST = 10;

  reg                          clk;
  reg                          rst_n;
  reg                          valid_in;
  reg signed [NUM_INST*DW-1:0] x_in;
  
  wire                         valid_out;
  wire signed [NUM_INST*DW-1:0] y_out;
  
  reg signed [DW-1:0]          current_y;

  // -----------------------------
  // DUT Instantiation
  // -----------------------------
  exp_top #(
    .DW(DW)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .x_in(x_in),
    .valid_out(valid_out),
    .y_out(y_out)
  );

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
      to_real = val / 65536.0; // 65536 = 2^16 for Q16.16 format
    end
  endfunction

  // -----------------------------
  // Clock Generation (100MHz)
  // -----------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk; 
  end

  // -----------------------------
  // TASK: Single-Shot Injection & Print
  // -----------------------------
  task run_exp_test;
    input [8*30:1] test_name; // 30 character string buffer
    input real r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
    
    integer i;
    real test_arr [0:9]; // Local array for printing
    begin
      $display("---- %0s ----", test_name);
      
      // Store inputs in local array for the display loop
      test_arr[0] = r0; test_arr[1] = r1; test_arr[2] = r2; test_arr[3] = r3;
      test_arr[4] = r4; test_arr[5] = r5; test_arr[6] = r6; test_arr[7] = r7;
      test_arr[8] = r8; test_arr[9] = r9;
      
      // 1. Inject data on the NEGATIVE edge
      @(negedge clk);
      valid_in = 1;
      
      // Pack the 10 unrolled reals into the vector
      x_in = {
        to_fixed(r9), to_fixed(r8), to_fixed(r7), to_fixed(r6),
        to_fixed(r5), to_fixed(r4), to_fixed(r3), to_fixed(r2),
        to_fixed(r1), to_fixed(r0)
      };

      // 2. Hold for 1 cycle, then clear inputs
      @(negedge clk);
      valid_in = 0;
      x_in = 0;

      // 3. Wait for the valid_out flag
      wait(valid_out == 1'b1);
      
      // 4. Print results
      for (i = 0; i < NUM_INST; i = i + 1) begin
        current_y = y_out[i*DW +: DW];
        $display("idx[%0d] | x = %8.4f | exp(x) = %8.4f", 
                 i, test_arr[i], to_real(current_y));
      end
      $display("--------------------\n");
      
      // Wait a few cycles before the next test
      repeat(3) @(posedge clk);
    end
  endtask

  // -----------------------------
  // Main Test Sequence
  // -----------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    x_in = 0;
    
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    run_exp_test("Test 1: Mixed inputs", 
                 -4.41, -9.74, -30.73, -40.80, 1.91, -29.23, 21.73, -9.95, -18.57, -22.88);
                 
    run_exp_test("Test 2: Softmax range", 
                 0.0, -1.0, -2.0, -5.0, -10.0, -15.0, -20.0, -0.5, -3.0, -8.0);
                 
    run_exp_test("Test 3: Edge cases", 
                 0.0, 0.1, 5.0, 10.0, -10.0, -10.5, -50.0, -0.01, -0.5, -9.9);
                 
    run_exp_test("SPEC TEST CASE", 
                 -4.4137, -9.7494, -30.7384, -40.8083, 1.9162, -29.2329, 21.7290, -9.9515, -18.5767, -22.8818);

    $display("Simulation Complete.");
    $finish;
  end

endmodule