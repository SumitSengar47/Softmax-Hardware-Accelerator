module argmax #(
    parameter DW = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    valid_in,
    input  wire signed [10*DW-1:0] prob_in,
    output reg                     valid_out,
    output reg  [3:0]              pred_class
);

  // ---------------------------------------------------------
  // 1. Manual Unpack
  // ---------------------------------------------------------
  wire signed [DW-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8, p9;
  
  assign p0 = prob_in[0*DW +: DW];
  assign p1 = prob_in[1*DW +: DW];
  assign p2 = prob_in[2*DW +: DW];
  assign p3 = prob_in[3*DW +: DW];
  assign p4 = prob_in[4*DW +: DW];
  assign p5 = prob_in[5*DW +: DW];
  assign p6 = prob_in[6*DW +: DW];
  assign p7 = prob_in[7*DW +: DW];
  assign p8 = prob_in[8*DW +: DW];
  assign p9 = prob_in[9*DW +: DW];

  // ---------------------------------------------------------
  // 2. INTERNAL BUFFER (The Fix!)
  // ---------------------------------------------------------
  reg signed [DW-1:0] prob_buffer [0:9];

  // ---------------------------------------------------------
  // 3. FSM States
  // ---------------------------------------------------------
  localparam [1:0]
      IDLE    = 2'b00,
      COMPARE = 2'b01,
      DONE    = 2'b10;

  reg [1:0] state, next_state;

  reg [3:0]             idx, next_idx;
  reg signed [DW-1:0]   current_max, next_max;
  reg [3:0]             best_class, next_best_class;

  // ---------------------------------------------------------
  // 4. Sequential Logic
  // ---------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      idx         <= 4'd0;
      current_max <= 0;
      best_class  <= 4'd0;
      
      prob_buffer[0] <= 0; prob_buffer[1] <= 0; prob_buffer[2] <= 0;
      prob_buffer[3] <= 0; prob_buffer[4] <= 0; prob_buffer[5] <= 0;
      prob_buffer[6] <= 0; prob_buffer[7] <= 0; prob_buffer[8] <= 0;
      prob_buffer[9] <= 0;
    end else begin
      state       <= next_state;
      idx         <= next_idx;
      current_max <= next_max;
      best_class  <= next_best_class;
      
      // LATCH the data when it arrives so it doesn't disappear!
      if (state == IDLE && valid_in) begin
        prob_buffer[0] <= p0;
        prob_buffer[1] <= p1;
        prob_buffer[2] <= p2;
        prob_buffer[3] <= p3;
        prob_buffer[4] <= p4;
        prob_buffer[5] <= p5;
        prob_buffer[6] <= p6;
        prob_buffer[7] <= p7;
        prob_buffer[8] <= p8;
        prob_buffer[9] <= p9;
      end
    end
  end

  // ---------------------------------------------------------
  // 5. Combinational FSM Logic
  // ---------------------------------------------------------
  always @(*) begin
    next_state      = state;
    next_idx        = idx;
    next_max        = current_max;
    next_best_class = best_class;
    
    valid_out  = 1'b0;
    pred_class = best_class;

    case (state)
      IDLE: begin
        if (valid_in) begin
          next_state      = COMPARE;
          next_idx        = 4'd1;        
          next_max        = p0; // Take p0 directly from the wire for cycle 0
          next_best_class = 4'd0;
        end
      end

      COMPARE: begin
        // Read from the BUFFER, not the live input wires!
        if (prob_buffer[idx] > current_max) begin
          next_max        = prob_buffer[idx];
          next_best_class = idx;
        end
        
        if (idx == 4'd9) begin
          next_state = DONE;
        end else begin
          next_idx   = idx + 4'd1;
        end
      end

      DONE: begin
        valid_out  = 1'b1;
        pred_class = best_class;
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end

endmodule