`timescale 1ns/1ps

module multiplier_tb;

  parameter DW = 32;
  parameter FRACTION = 16;
  parameter NUM_INST = 10;

  reg                          clk;
  reg                          rst_n;
  reg                          valid_in;
  reg signed [10*DW-1:0]       exp_in;
  reg signed [DW-1:0]          inv_out;
  
  wire                         valid_out;
  wire signed [10*DW-1:0]      p_out;
  
  reg signed [DW-1:0]          current_p;

  // -----------------------------
  // DUT Instantiation
  // -----------------------------
  multiplier #(
    .DW(DW),
    .FRAC(FRACTION)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .exp_in(exp_in),
    .inv_out(inv_out),
    .valid_out(valid_out),
    .p_out(p_out)
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
      to_real = val / 65536.0; // 65536.0 = 2^16 for Q16.16 format
    end
  endfunction

  // -----------------------------
  // Clock Generation (100MHz)
  // -----------------------------
  initial clk = 0;
  always #5 clk = ~clk; 

  // -----------------------------
  // Realistic Test Data
  // -----------------------------
  real test_exps [0:9];
  real test_inv_sum;
  
  integer i; // Loop variable

  // -----------------------------
  // Main Stimulus Sequence
  // -----------------------------
  initial begin
    // Initialize test array (Verilog-2001 compatible)
    test_exps[0] = 0.10;
    test_exps[1] = 0.05;
    test_exps[2] = 0.00;
    test_exps[3] = 1.00;
    test_exps[4] = 0.00;
    test_exps[5] = 0.20;
    test_exps[6] = 0.00;
    test_exps[7] = 0.00;
    test_exps[8] = 0.05;
    test_exps[9] = 0.04;
    
    test_inv_sum = 0.6944; // 1 / 1.44

    rst_n = 0;
    valid_in = 0;
    exp_in = 0;
    inv_out = 0;
    
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    $display("==================================================");
    $display("  INJECTING SOFTMAX DATA SNAPSHOT");
    $display("==================================================");

    // Inject data on the NEGATIVE edge for clean setup times
    @(negedge clk);
    valid_in = 1;
    inv_out = to_fixed(test_inv_sum);
    
    // Manually pack the test array into the flat vector
    for (i = 0; i < NUM_INST; i = i + 1) begin
        exp_in[i*DW +: DW] = to_fixed(test_exps[i]);
    end
    
    $display("Time %0t: INJECTED Denominator (1/sum) = %7.4f", $time, test_inv_sum);
    $display("Time %0t: INJECTED Numerators  (exp)   = 0.10, 0.05, 0.00, 1.00...", $time);

    // Hold for 1 cycle, then clear
    @(negedge clk);
    valid_in = 0;
    exp_in = 0;
    inv_out = 0;

    // Wait for the pipeline to finish
    wait(valid_out == 1'b1);
    
    $display("\n==================================================");
    $display("  MULTIPLIER RESULTS (Probabilities)");
    $display("==================================================");
    
    // Unpack and print the results
    for (i = 0; i < NUM_INST; i = i + 1) begin
      current_p = p_out[i*DW +: DW];
      $display("Class [%0d] Probability: %7.4f", i, to_real(current_p));
    end

    // Wait a few cycles to clear waveforms, then end
    repeat(3) @(posedge clk);
    $display("\nSimulation Complete.");
    $finish;
  end

endmodule