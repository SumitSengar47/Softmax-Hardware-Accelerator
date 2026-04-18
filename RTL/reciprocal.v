module reciprocal #(
    parameter DW = 32,
    parameter FRAC = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,  // Added!
    input  wire signed [DW-1:0]   sum_in,
    output wire                   valid_out, // Added!
    output wire signed [DW-1:0]   inv_out
);

  localparam signed [DW-1:0] CONST_TWO = 32'sd131072; 
  localparam signed [DW-1:0] CONST_M   = 32'sd184956; 
  localparam signed [DW-1:0] CONST_N   = 32'sd123386; 

  // Pipeline registers
  reg                   valid_stg1, valid_stg2;
  reg [2:0]             shift_stg1, shift_stg2;
  reg signed [DW-1:0]   D_norm_stg1;
  reg signed [DW-1:0]   x0, x1;

  // Wires / Combinational Regs
  reg [2:0]             shift_comb;
  reg signed [DW-1:0]   D_norm_comb;
  reg signed [2*DW-1:0] mult_t0, mult_x3, mult_x6;
  reg signed [DW-1:0]   t1, x4, x5, x7;

  // =========================================================
  // Stage 0: Normalization 
  // =========================================================
  always @(*) begin
      if (sum_in[19]) begin        
          shift_comb = 4;
          D_norm_comb = sum_in >>> 4;
      end else if (sum_in[18]) begin 
          shift_comb = 3;
          D_norm_comb = sum_in >>> 3;
      end else if (sum_in[17]) begin 
          shift_comb = 2;
          D_norm_comb = sum_in >>> 2;
      end else begin                 
          shift_comb = 1;
          D_norm_comb = sum_in >>> 1;
      end
  end

  // =========================================================
  // Stage 1: Initial Guess 
  // =========================================================
  always @(*) begin
      mult_t0 = CONST_N * D_norm_comb;
      t1 = mult_t0[DW+FRAC-1 : FRAC];
  end

  always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          x0 <= 0;
          D_norm_stg1 <= 0;
          shift_stg1 <= 0;
          valid_stg1 <= 1'b0; // Clear valid on reset
      end else begin
          x0 <= CONST_M - t1;
          D_norm_stg1 <= D_norm_comb; 
          shift_stg1 <= shift_comb;   
          valid_stg1 <= valid_in;     // Pass valid flag forward
      end
  end

  // =========================================================
  // Stage 2: NRD Iteration 1 
  // =========================================================
  always @(*) begin
      mult_x3 = D_norm_stg1 * x0;
      x4 = mult_x3[DW+FRAC-1 : FRAC];
      x5 = CONST_TWO - x4;

      mult_x6 = x0 * x5;
      x7 = mult_x6[DW+FRAC-1 : FRAC];
  end

  always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          x1 <= 0;
          shift_stg2 <= 0;
          valid_stg2 <= 1'b0; // Clear valid on reset
      end else begin
          x1 <= x7;
          shift_stg2 <= shift_stg1; 
          valid_stg2 <= valid_stg1;   // Pass valid flag forward
      end
  end

  // =========================================================
  // Stage 3: Denormalization
  // =========================================================
  assign valid_out = valid_stg2;
  assign inv_out = x1 >>> shift_stg2;

endmodule