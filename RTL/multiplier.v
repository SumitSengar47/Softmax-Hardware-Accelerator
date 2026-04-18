module multiplier #(
    parameter DW = 32,
    parameter FRAC = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire signed [10*DW-1:0] exp_in,  // Flattened 10 exponentials
    input  wire signed [DW-1:0]    inv_out, // Single reciprocal value (denominator)
    output reg                    valid_out,
    output wire signed [10*DW-1:0] p_out    // Flattened 10 probabilities
);

  // ---------------------------------------------------------
  // 1. Manual Unpack (No Loops)
  // ---------------------------------------------------------
  wire signed [DW-1:0] e0, e1, e2, e3, e4, e5, e6, e7, e8, e9;
  
  assign e0 = exp_in[0*DW +: DW];
  assign e1 = exp_in[1*DW +: DW];
  assign e2 = exp_in[2*DW +: DW];
  assign e3 = exp_in[3*DW +: DW];
  assign e4 = exp_in[4*DW +: DW];
  assign e5 = exp_in[5*DW +: DW];
  assign e6 = exp_in[6*DW +: DW];
  assign e7 = exp_in[7*DW +: DW];
  assign e8 = exp_in[8*DW +: DW];
  assign e9 = exp_in[9*DW +: DW];

  // ---------------------------------------------------------
  // 2. Simple Multiplications (64-bit intermediate)
  // ---------------------------------------------------------
  reg signed [2*DW-1:0] m0, m1, m2, m3, m4, m5, m6, m7, m8, m9;
  
  always @(*) begin
      m0 = e0 * inv_out;
      m1 = e1 * inv_out;
      m2 = e2 * inv_out;
      m3 = e3 * inv_out;
      m4 = e4 * inv_out;
      m5 = e5 * inv_out;
      m6 = e6 * inv_out;
      m7 = e7 * inv_out;
      m8 = e8 * inv_out;
      m9 = e9 * inv_out;
  end

  // ---------------------------------------------------------
  // 3. Pipeline Register & Truncation back to Q16.16
  // ---------------------------------------------------------
  reg signed [DW-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8, p9;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0;
      p5 <= 0; p6 <= 0; p7 <= 0; p8 <= 0; p9 <= 0;
      valid_out <= 1'b0;
    end else begin
      // Slice the middle 32 bits to discard extra fractions and maintain Q16.16 format
      p0 <= m0[DW+FRAC-1 : FRAC];
      p1 <= m1[DW+FRAC-1 : FRAC];
      p2 <= m2[DW+FRAC-1 : FRAC];
      p3 <= m3[DW+FRAC-1 : FRAC];
      p4 <= m4[DW+FRAC-1 : FRAC];
      p5 <= m5[DW+FRAC-1 : FRAC];
      p6 <= m6[DW+FRAC-1 : FRAC];
      p7 <= m7[DW+FRAC-1 : FRAC];
      p8 <= m8[DW+FRAC-1 : FRAC];
      p9 <= m9[DW+FRAC-1 : FRAC];
      
      valid_out <= valid_in;
    end
  end

  // ---------------------------------------------------------
  // 4. Manual Pack (No Loops)
  // ---------------------------------------------------------
  assign p_out = {p9, p8, p7, p6, p5, p4, p3, p2, p1, p0};

endmodule