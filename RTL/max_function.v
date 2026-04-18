module max_function #(
    parameter DW = 32 ,
    parameter  N = 10
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire signed [N*DW-1:0] z2_in,

    output wire                   valid_out,
    output wire signed [DW-1:0]   max_out
);

  // -----------------------------
  // Unpack inputs
  // -----------------------------
  wire signed [DW-1:0] z0, z1, z2, z3, z4, z5, z6, z7, z8, z9;

  assign z0 = z2_in[0*DW +: DW];
  assign z1 = z2_in[1*DW +: DW];
  assign z2 = z2_in[2*DW +: DW];
  assign z3 = z2_in[3*DW +: DW];
  assign z4 = z2_in[4*DW +: DW];
  assign z5 = z2_in[5*DW +: DW];
  assign z6 = z2_in[6*DW +: DW];
  assign z7 = z2_in[7*DW +: DW];
  assign z8 = z2_in[8*DW +: DW];
  assign z9 = z2_in[9*DW +: DW];

  // -----------------------------
  // Stage 1 (10 -> 5)
  // -----------------------------
  reg signed [DW-1:0] s1_0, s1_1, s1_2, s1_3, s1_4;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_0 <= 0; s1_1 <= 0; s1_2 <= 0; s1_3 <= 0; s1_4 <= 0;
    end else begin
      s1_0 <= (z0 > z1) ? z0 : z1;
      s1_1 <= (z2 > z3) ? z2 : z3;
      s1_2 <= (z4 > z5) ? z4 : z5;
      s1_3 <= (z6 > z7) ? z6 : z7;
      s1_4 <= (z8 > z9) ? z8 : z9;
    end
  end

  // -----------------------------
  // Stage 2 (5 -> 3)
  // -----------------------------
  reg signed [DW-1:0] s2_0, s2_1, s2_2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_0 <= 0; s2_1 <= 0; s2_2 <= 0;
    end else begin
      s2_0 <= (s1_0 > s1_1) ? s1_0 : s1_1;
      s2_1 <= (s1_2 > s1_3) ? s1_2 : s1_3;
      s2_2 <= s1_4; // pass-through
    end
  end

  // -----------------------------
  // Stage 3 (3 -> 2)
  // -----------------------------
  reg signed [DW-1:0] s3_0, s3_1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_0 <= 0; s3_1 <= 0;
    end else begin
      s3_0 <= (s2_0 > s2_1) ? s2_0 : s2_1;
      s3_1 <= s2_2;
    end
  end

  // -----------------------------
  // Stage 4 (2 -> 1)
  // -----------------------------
  reg signed [DW-1:0] s4;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      s4 <= 0;
    else
      s4 <= (s3_0 > s3_1) ? s3_0 : s3_1;
  end

  // -----------------------------
  // Valid pipeline
  // -----------------------------
  reg v1, v2, v3, v4, v5;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v1 <= 0; v2 <= 0; v3 <= 0; v4 <= 0; v5 <= 0;
    end else begin
      v1 <= valid_in;
      v2 <= v1;
      v3 <= v2;
      v4 <= v3;
      v5 <= v4;
    end
  end

  assign valid_out = v5;
  assign max_out   = s4;

endmodule