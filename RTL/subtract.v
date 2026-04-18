module subtract #(
    parameter DW = 32,
    parameter N  = 10
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   valid_in,
    input  wire signed [N*DW-1:0] z2_in,
    input  wire signed [DW-1:0]   max_in,

    output reg                    valid_out,
    output wire signed [10*DW-1:0] z_norm_out
);

  // --------------------------------------------------
  // FSM States
  // --------------------------------------------------
  localparam [1:0]
    IDLE    = 2'd0,
    LOAD    = 2'd1,
    COMPUTE = 2'd2,
    DONE    = 2'd3;

  reg [1:0] state;

  // --------------------------------------------------
  // Registers
  // --------------------------------------------------
  reg signed [DW-1:0] z0, z1, z2, z3, z4, z5, z6, z7, z8, z9;
  reg signed [DW-1:0] n0, n1, n2, n3, n4, n5, n6, n7, n8, n9;

  // --------------------------------------------------
  // FSM Logic
  // --------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid_out <= 0;

      z0<=0; z1<=0; z2<=0; z3<=0; z4<=0;
      z5<=0; z6<=0; z7<=0; z8<=0; z9<=0;

      n0<=0; n1<=0; n2<=0; n3<=0; n4<=0;
      n5<=0; n6<=0; n7<=0; n8<=0; n9<=0;

    end else begin
      case (state)

        // ---------------- IDLE ----------------
        IDLE: begin
          valid_out <= 0;

          if (valid_in) begin
            state <= LOAD;
          end
        end

        // ---------------- LOAD ----------------
        LOAD: begin
          // unpack input
          z0 <= z2_in[0*DW +: DW];
          z1 <= z2_in[1*DW +: DW];
          z2 <= z2_in[2*DW +: DW];
          z3 <= z2_in[3*DW +: DW];
          z4 <= z2_in[4*DW +: DW];
          z5 <= z2_in[5*DW +: DW];
          z6 <= z2_in[6*DW +: DW];
          z7 <= z2_in[7*DW +: DW];
          z8 <= z2_in[8*DW +: DW];
          z9 <= z2_in[9*DW +: DW];

          state <= COMPUTE;
        end

        // ---------------- COMPUTE ----------------
        COMPUTE: begin
          n0 <= z0 - max_in;
          n1 <= z1 - max_in;
          n2 <= z2 - max_in;
          n3 <= z3 - max_in;
          n4 <= z4 - max_in;
          n5 <= z5 - max_in;
          n6 <= z6 - max_in;
          n7 <= z7 - max_in;
          n8 <= z8 - max_in;
          n9 <= z9 - max_in;

          state <= DONE;
        end

        // ---------------- DONE ----------------
        DONE: begin
          valid_out <= 1;
          state <= IDLE;
        end
        
        default: begin
          state <= IDLE;
        end

      endcase
    end
  end

  // --------------------------------------------------
  // Pack output
  // --------------------------------------------------
  assign z_norm_out = {
    n9, n8, n7, n6, n5, n4, n3, n2, n1, n0
  };

endmodule