`timescale 1ns/1ps

module subtract_tb;

  parameter DW = 32;
  parameter FRACTION = 16;

  reg clk;
  reg rst_n;
  reg valid_in;

  reg signed [10*DW-1:0] z2_in;
  reg signed [DW-1:0]    max_in;

  wire valid_out;
  wire signed [10*DW-1:0] z_norm_out;

  // DUT
  subtract #(
    .DW(DW),
    .N(10)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .z2_in(z2_in),
    .max_in(max_in),
    .valid_out(valid_out),
    .z_norm_out(z_norm_out)
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
  // Pack helper
  // -----------------------------
  function signed [10*DW-1:0] pack;
    input real r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
    begin
      pack = {
        to_fixed(r9), to_fixed(r8), to_fixed(r7), to_fixed(r6),
        to_fixed(r5), to_fixed(r4), to_fixed(r3), to_fixed(r2),
        to_fixed(r1), to_fixed(r0)
      };
    end
  endfunction

  // -----------------------------
  // Output display
  // -----------------------------
  task display_output;
    integer i;
    reg signed [31:0] temp;
    begin
      for (i = 0; i < 10; i = i + 1) begin
        temp = z_norm_out[i*DW +: DW];
        $write("%f ", to_real(temp));
        if (i == 4) $write("\n");
      end
      $write("\n");
    end
  endtask

  // -----------------------------
  // Task: send one input safely
  // -----------------------------
  task send_input;
    input real r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;
    input real max_val;
    begin
      @(posedge clk);

      z2_in   = pack(r0, r1, r2, r3, r4, r5, r6, r7, r8, r9);
      max_in  = to_fixed(max_val);
      valid_in = 1;

      @(posedge clk);
      valid_in = 0;

      // wait for output
      wait(valid_out);

      $display("---- OUTPUT ----");
      display_output();
      $display("----------------");
    end
  endtask

  // -----------------------------
  // Stimulus
  // -----------------------------
  initial begin
    rst_n = 0;
    valid_in = 0;
    z2_in = 0;
    max_in = 0;

    // Reset
    repeat(3) @(posedge clk);
    rst_n = 1;

    // Send inputs sequentially
    // Test 1 (Z2 vector from specs)
    send_input(-22.88, -18.57, -9.95, 21.73, -29.23, 1.91, -40.80, -30.73, -9.74, -4.41, 21.73);
    
    // Test 2
    send_input(1.0, 5.0, 3.0, 7.0, 2.0, 0.0, -1.0, 6.0, 4.0, 8.0, 8.0);
    
    // Test 3
    send_input(-10.0, -5.0, -3.0, -20.0, -7.0, -1.0, -2.0, -9.0, -4.0, -6.0, -1.0);

    #20;
    $finish;
  end

endmodule