module softmax_top #(
    parameter DW = 32,
    parameter NUM_INST = 10
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    valid_in, // START trigger
    input  wire signed [10*DW-1:0] data_in,  
    output reg                     valid_out,
    output reg  [3:0]              pred_class,
    output reg                     ready     // Tells outside world it can accept new data
);

  // ---------------------------------------------------------
  // Interconnect Wires
  // ---------------------------------------------------------
  wire                    max_valid;
  wire signed [DW-1:0]    max_data;

  wire                    sub_valid;
  wire signed [10*DW-1:0] sub_data;

  wire                    exp_valid;
  wire signed [10*DW-1:0] exp_data;

  wire                    sum_valid;
  wire signed [DW-1:0]    sum_data;

  wire                    inv_valid;
  wire signed [DW-1:0]    inv_data;

  wire                    prob_valid;
  wire signed [10*DW-1:0] prob_data;

  wire                    argmax_valid;
  wire [3:0]              argmax_pred;

  // ---------------------------------------------------------
  // FSM States & Buffers
  // ---------------------------------------------------------
  localparam [2:0]
      IDLE        = 3'd0,
      WAIT_MAX    = 3'd1, // Stage 1
      WAIT_SUB    = 3'd2, // Stage 2
      WAIT_EXP    = 3'd3, // Stage 3
      WAIT_SUM    = 3'd4, // Stage 4
      WAIT_RECIP  = 3'd5, // Stage 5
      WAIT_MULT   = 3'd6, // Stage 6
      WAIT_ARGMAX = 3'd7; // Stage 7

  reg [2:0] state, next_state;

  // BUFFERS: Safely hold transient data for multi-cycle modules
  reg signed [10*DW-1:0] input_buffer; // Holds original input for subtract module
  reg signed [DW-1:0]    max_buffer;   // Holds max value for subtract module
  reg signed [10*DW-1:0] exp_buffer;   // Holds exponentials for multiplier module
  
  // Module Trigger Signals controlled by FSM
  reg trigger_max, trigger_sub, trigger_exp, trigger_sum;
  reg trigger_recip, trigger_mult, trigger_argmax;

  // ---------------------------------------------------------
  // FSM Sequential Logic (State & Buffer updates)
  // ---------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      input_buffer <= 0;
      max_buffer   <= 0;
      exp_buffer   <= 0;
    end else begin
      state <= next_state;
      
      // 1. Latch the incoming data the moment valid_in asserts
      if (state == IDLE && valid_in) begin
        input_buffer <= data_in;
      end

      // 2. Latch the max value so it survives the 3-cycle subtract FSM
      if (max_valid) begin
        max_buffer <= max_data;
      end

      // 3. Latch the exponentials so they survive the 6-cycle denominator calculation
      if (exp_valid) begin
        exp_buffer <= exp_data;
      end
    end
  end

  // ---------------------------------------------------------
  // FSM Combinational Logic (Triggers & Transitions)
  // ---------------------------------------------------------
  always @(*) begin
    // Defaults
    next_state     = state;
    ready          = 1'b0;
    valid_out      = 1'b0;
    pred_class     = 4'd0;
    
    trigger_max    = 1'b0;
    trigger_sub    = 1'b0;
    trigger_exp    = 1'b0;
    trigger_sum    = 1'b0;
    trigger_recip  = 1'b0;
    trigger_mult   = 1'b0;
    trigger_argmax = 1'b0;

    case (state)
      IDLE: begin
        ready = 1'b1; 
        if (valid_in) begin
          trigger_max = 1'b1; 
          next_state  = WAIT_MAX;
        end
      end

      WAIT_MAX: begin
        if (max_valid) begin
          trigger_sub = 1'b1; 
          next_state  = WAIT_SUB;
        end
      end

      WAIT_SUB: begin
        if (sub_valid) begin
          trigger_exp = 1'b1; 
          next_state  = WAIT_EXP;
        end
      end

      WAIT_EXP: begin
        if (exp_valid) begin
          trigger_sum = 1'b1; 
          next_state  = WAIT_SUM;
        end
      end

      WAIT_SUM: begin
        if (sum_valid) begin
          trigger_recip = 1'b1; 
          next_state    = WAIT_RECIP;
        end
      end

      WAIT_RECIP: begin
        if (inv_valid) begin
          trigger_mult = 1'b1; 
          next_state   = WAIT_MULT;
        end
      end

      WAIT_MULT: begin
        if (prob_valid) begin
          trigger_argmax = 1'b1; 
          next_state     = WAIT_ARGMAX;
        end
      end

      WAIT_ARGMAX: begin
        if (argmax_valid) begin
          valid_out  = 1'b1;
          pred_class = argmax_pred;
          next_state = IDLE; 
        end
      end
      
      default: next_state = IDLE;
    endcase
  end

  // ---------------------------------------------------------
  // Stage 1: Max Module
  // ---------------------------------------------------------
  max_function #(
      .DW(DW), 
      .N(NUM_INST)
  ) u_max_function (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_max), 
      .z2_in      (input_buffer), 
      .valid_out  (max_valid), 
      .max_out    (max_data)
  );

  // ---------------------------------------------------------
  // Stage 2: Subtract Module
  // ---------------------------------------------------------
  subtract #(
      .DW(DW), 
      .N(NUM_INST)
  ) u_subtract (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_sub), 
      .z2_in      (input_buffer), // FSM Buffer
      .max_in     (max_buffer),   // FSM Buffer
      .valid_out  (sub_valid), 
      .z_norm_out (sub_data)
  );

  // ---------------------------------------------------------
  // Stage 3: Exponentials
  // ---------------------------------------------------------
  exp_top #(
      .DW(DW)
  ) u_exp_top (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_exp), 
      .x_in       (sub_data), 
      .valid_out  (exp_valid), 
      .y_out      (exp_data)
  );

  // ---------------------------------------------------------
  // Stage 4: Adder Tree
  // ---------------------------------------------------------
  adder_tree #(
      .DW(DW)
  ) u_adder_tree (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_sum), 
      .exp_in     (exp_data), 
      .valid_out  (sum_valid), 
      .sum_out    (sum_data)
  );

  // ---------------------------------------------------------
  // Stage 5: Reciprocal
  // ---------------------------------------------------------
  reciprocal #(
      .DW(DW), 
      .FRAC(16)
  ) u_reciprocal (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_recip), 
      .sum_in     (sum_data), 
      .valid_out  (inv_valid), 
      .inv_out    (inv_data)
  );

  // ---------------------------------------------------------
  // Stage 6: Multiplier
  // ---------------------------------------------------------
  multiplier #(
      .DW(DW), 
      .FRAC(16)
  ) u_multiplier (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_mult),        
      .exp_in     (exp_buffer),   // FSM Buffer
      .inv_out    (inv_data),             
      .valid_out  (prob_valid), 
      .p_out      (prob_data)
  );

  // ---------------------------------------------------------
  // Stage 7: Argmax Prediction
  // ---------------------------------------------------------
  argmax #(
      .DW(DW)
  ) u_argmax (
      .clk        (clk), 
      .rst_n      (rst_n), 
      .valid_in   (trigger_argmax),      
      .prob_in    (prob_data), 
      .valid_out  (argmax_valid), 
      .pred_class (argmax_pred)
  );

endmodule