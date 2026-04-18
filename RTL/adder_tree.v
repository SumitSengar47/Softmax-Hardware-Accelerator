module adder_tree #(
    parameter DW = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,   // Standardized Input
    input  wire signed [10*DW-1:0] exp_in,
    output reg                    valid_out,  // Standardized Output
    output reg  signed [DW-1:0]   sum_out
);

  // -----------------------------
  // Manual Unpack Flat Vector
  // -----------------------------
  wire signed [DW-1:0] in0, in1, in2, in3, in4, in5, in6, in7, in8, in9;

  assign in0 = exp_in[0*DW +: DW];
  assign in1 = exp_in[1*DW +: DW];
  assign in2 = exp_in[2*DW +: DW];
  assign in3 = exp_in[3*DW +: DW];
  assign in4 = exp_in[4*DW +: DW];
  assign in5 = exp_in[5*DW +: DW];
  assign in6 = exp_in[6*DW +: DW];
  assign in7 = exp_in[7*DW +: DW];
  assign in8 = exp_in[8*DW +: DW];
  assign in9 = exp_in[9*DW +: DW];

  // Pipeline registers for data
  reg signed [DW-1:0] stg1_0, stg1_1, stg1_2, stg1_3, stg1_4;
  reg signed [DW-1:0] stg2_0, stg2_1, stg2_2;
  reg signed [DW-1:0] stg3_0, stg3_1;
  
  // Pipeline registers for valid signal
  reg v_stg1;
  reg v_stg2;
  reg v_stg3;

  // -----------------------------
  // Stage 1: 5 Adders
  // -----------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stg1_0 <= 0;
      stg1_1 <= 0;
      stg1_2 <= 0;
      stg1_3 <= 0;
      stg1_4 <= 0;
      v_stg1 <= 1'b0;
    end else begin
      stg1_0 <= in0 + in1;
      stg1_1 <= in2 + in3;
      stg1_2 <= in4 + in5;
      stg1_3 <= in6 + in7;
      stg1_4 <= in8 + in9;
      v_stg1 <= valid_in; // Pass valid forward
    end
  end

  // -----------------------------
  // Stage 2: 2 Adders, 1 Passthrough
  // -----------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stg2_0 <= 0;
      stg2_1 <= 0;
      stg2_2 <= 0;
      v_stg2 <= 1'b0;
    end else begin
      stg2_0 <= stg1_0 + stg1_1;
      stg2_1 <= stg1_2 + stg1_3;
      stg2_2 <= stg1_4; 
      v_stg2 <= v_stg1; // Pass valid forward
    end
  end

  // -----------------------------
  // Stage 3 & 4: Final Sums
  // -----------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stg3_0    <= 0;
      stg3_1    <= 0;
      sum_out   <= 0;
      v_stg3    <= 1'b0;
      valid_out <= 1'b0;
    end else begin
      // Stage 3
      stg3_0 <= stg2_0 + stg2_1;
      stg3_1 <= stg2_2;
      v_stg3 <= v_stg2; // Pass valid forward
      
      // Stage 4 (Final Output)
      sum_out   <= stg3_0 + stg3_1;
      valid_out <= v_stg3; // Final valid output
    end
  end

endmodule