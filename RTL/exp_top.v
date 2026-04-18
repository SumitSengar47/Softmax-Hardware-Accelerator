module exp_top #(
    parameter DW = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    valid_in,
    input  wire signed [10*DW-1:0] x_in,
    output wire                    valid_out,
    output wire signed [10*DW-1:0] y_out
);

  // ---------------------------------------------------------
  // 1. Manual Unpack of the Flattened Input
  // ---------------------------------------------------------
  wire signed [DW-1:0] x0, x1, x2, x3, x4, x5, x6, x7, x8, x9;

  assign x0 = x_in[0*DW +: DW];
  assign x1 = x_in[1*DW +: DW];
  assign x2 = x_in[2*DW +: DW];
  assign x3 = x_in[3*DW +: DW];
  assign x4 = x_in[4*DW +: DW];
  assign x5 = x_in[5*DW +: DW];
  assign x6 = x_in[6*DW +: DW];
  assign x7 = x_in[7*DW +: DW];
  assign x8 = x_in[8*DW +: DW];
  assign x9 = x_in[9*DW +: DW];

  // ---------------------------------------------------------
  // 2. Intermediate Wires for Outputs
  // ---------------------------------------------------------
  wire signed [DW-1:0] y0, y1, y2, y3, y4, y5, y6, y7, y8, y9;
  
  // We only need one valid wire to route to the top, 
  // but we can declare them all for completeness.
  wire v0, v1, v2, v3, v4, v5, v6, v7, v8, v9;

  // ---------------------------------------------------------
  // 3. Explicit Instantiations
  // ---------------------------------------------------------
  exp #(.DW(DW)) u_exp_0 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x0), .valid_out(v0), .y(y0));
  exp #(.DW(DW)) u_exp_1 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x1), .valid_out(v1), .y(y1));
  exp #(.DW(DW)) u_exp_2 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x2), .valid_out(v2), .y(y2));
  exp #(.DW(DW)) u_exp_3 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x3), .valid_out(v3), .y(y3));
  exp #(.DW(DW)) u_exp_4 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x4), .valid_out(v4), .y(y4));
  exp #(.DW(DW)) u_exp_5 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x5), .valid_out(v5), .y(y5));
  exp #(.DW(DW)) u_exp_6 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x6), .valid_out(v6), .y(y6));
  exp #(.DW(DW)) u_exp_7 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x7), .valid_out(v7), .y(y7));
  exp #(.DW(DW)) u_exp_8 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x8), .valid_out(v8), .y(y8));
  exp #(.DW(DW)) u_exp_9 (.clk(clk), .rst_n(rst_n), .valid_in(valid_in), .x(x9), .valid_out(v9), .y(y9));

  // ---------------------------------------------------------
  // 4. Manual Pack of the Flattened Output
  // ---------------------------------------------------------
  assign y_out = {y9, y8, y7, y6, y5, y4, y3, y2, y1, y0};
  
  // Since all instances run perfectly in parallel, their valid_out signals 
  // are identical. We just route the first one to the top module output.
  assign valid_out = v0; 

endmodule