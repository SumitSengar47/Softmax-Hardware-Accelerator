`timescale 1ns/1ps

module adder_tree_tb;

  parameter DW = 32;
  parameter NUM_INST = 10;

  reg                          clk;
  reg                          rst_n;
  reg                          valid_in;
  reg signed [10*DW-1:0]       exp_in;
  
  wire                         valid_out;
  wire signed [DW-1:0]         sum_out;

  // -----------------------------
  // DUT Instantiation
  // -----------------------------
  adder_tree #(
    .DW(DW)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .exp_in(exp_in),
    .valid_out(valid_out),
    .sum_out(sum_out)
  );

  // -----------------------------
  // Clock Generation (100MHz)
  // -----------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk; 
  end

  // -----------------------------
  // TASK: Single-Shot Injection & Latency Check
  // -----------------------------
  task run_adder_test;
    input [8*30:1] test_name; // 30 character string buffer
    input integer d0, d1, d2, d3, d4, d5, d6, d7, d8, d9;
    
    time start_time, end_time;
    begin
      $display("\n==================================================");
      $display("  TEST: %0s", test_name);
      $display("==================================================");
      
      // 1. Inject data on the NEGATIVE edge for clean setup times
      @(negedge clk);
      start_time = $time;
      valid_in = 1;
      
      // Pack the vector
      exp_in[0*DW +: DW] = d0;
      exp_in[1*DW +: DW] = d1;
      exp_in[2*DW +: DW] = d2;
      exp_in[3*DW +: DW] = d3;
      exp_in[4*DW +: DW] = d4;
      exp_in[5*DW +: DW] = d5;
      exp_in[6*DW +: DW] = d6;
      exp_in[7*DW +: DW] = d7;
      exp_in[8*DW +: DW] = d8;
      exp_in[9*DW +: DW] = d9;
      
      // 2. Hold for exactly 1 clock cycle, then clear
      @(negedge clk);
      valid_in = 0;
      exp_in = 0;

      // 3. Wait for the pipeline valid_out to assert
      wait(valid_out == 1'b1);
      end_time = $time;
      
      // 4. Print results
      $display("[Time %0t] Result: SUM = %0d", end_time, sum_out);
      $display("--> Pipeline Latency: %0d clock cycles", (end_time - start_time)/10);
      
      // Wait a few cycles to clear waveforms before the next test
      repeat(3) @(posedge clk);
    end
  endtask

  // -----------------------------
  // Main Stimulus Sequence
  // -----------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    exp_in = 0;
    
    // Hold reset for a few cycles
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // Run the tests (passing the 10 values individually)
    
    // Test 1: Sum should be 65536
    run_adder_test("One Dominant Class",  
                   0, 0, 0, 65536, 0, 0, 0, 0, 0, 0);
                   
    // Test 2: Sum should be 550
    run_adder_test("Linear Increase",     
                   10, 20, 30, 40, 50, 60, 70, 80, 90, 100);
                   
    // Test 3: Sum should be 196608
    run_adder_test("Three Equal Classes", 
                   65536, 65536, 65536, 0, 0, 0, 0, 0, 0, 0);

    $display("\n==================================================");
    $display("  SIMULATION COMPLETE");
    $display("==================================================");
    $finish;
  end

endmodule