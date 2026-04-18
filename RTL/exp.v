module exp #(
    parameter DW = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire signed [DW-1:0]   x,
    output reg                    valid_out,
    output reg  signed [DW-1:0]   y
);

  // ---------------------------------------------------------
  // CORRECTED LUT: exp(x) with step size of 0.5
  // Index = abs(x) * 2 
  // ---------------------------------------------------------
  reg signed [DW-1:0] lut [0:15];

  initial begin
    lut[0]  = 32'sd65536; // exp(0.0)
    lut[1]  = 32'sd39749; // exp(-0.5)
    lut[2]  = 32'sd24109; // exp(-1.0)
    lut[3]  = 32'sd14623; // exp(-1.5)
    lut[4]  = 32'sd8869;  // exp(-2.0)
    lut[5]  = 32'sd5379;  // exp(-2.5)
    lut[6]  = 32'sd3262;  // exp(-3.0)
    lut[7]  = 32'sd1978;  // exp(-3.5)
    lut[8]  = 32'sd1200;  // exp(-4.0)
    lut[9]  = 32'sd728;   // exp(-4.5)
    lut[10] = 32'sd441;   // exp(-5.0)
    lut[11] = 32'sd267;   // exp(-5.5)
    lut[12] = 32'sd162;   // exp(-6.0)
    lut[13] = 32'sd98;    // exp(-6.5)
    lut[14] = 32'sd59;    // exp(-7.0)
    lut[15] = 32'sd36;    // exp(-7.5)
  end

  // ---------------------------------------------------------
  // Combinational Logic
  // ---------------------------------------------------------
  reg signed [DW-1:0] abs_x;
  reg [31:0]          shifted_val;
  reg [4:0]           idx; 
  reg signed [DW-1:0] y_comb; 
    
  always @(*) begin
      if (x >= 0) begin
        y_comb = lut[0]; // Cap at 1.0
      end 
      else begin
        // 1. Get the absolute value (make it positive)
        abs_x = -x;
        
        // 2. Shift right by 15. This extracts the integer AND the 0.5 bit!
        shifted_val = abs_x >> 15;
        idx = shifted_val[4:0]; 
        
        // 3. Saturate safely to 0 if the index exceeds our 15 limit (x < -7.5)
        if (shifted_val > 15) begin
             y_comb = 32'sd0; 
        end else begin
             y_comb = lut[idx];
        end
      end
  end

  // ---------------------------------------------------------
  // Pipeline Register (1-Cycle Latency)
  // ---------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y         <= 0;
      valid_out <= 1'b0;
    end else begin
      y         <= y_comb;     
      valid_out <= valid_in;   
    end
  end

endmodule