import keccak_pkg::*;

module keccak_core (
    input clk,
    input rst,

    input start_i,
    input [2:0] keccak_mode_i,

    input [DATA_SIZE-1:0] t_data_i,
    input t_valid_i,
    input t_last_i,
    input [VALID_BYTES_WIDTH-1:0] t_valid_bytes, // Which bytes to keep

    output t_ready_o,
    output [MAX_OUTPUT_DWIDTH-1:0] hash_o,
    output reg t_valid_o
);
    /*
     * 1600-bit State Array using to hold the state of keccak core.
     * See FIPS202 Section 3.1.1 for more information on state array.
     */
    reg [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array;
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] ksu_out;

    // Each output requires 24 rounds of permutations (θ, ρ, π, χ, ι)
    reg [ROUND_INDEX_SIZE-1:0] round_index;
    reg [STEP_SEL_WIDTH-1:0] step_sel;

    keccak_step_unit KSU (
        .state_array_i(state_array),
        .round_index_i(round_index),
        .step_sel_i(step_sel),
        .step_array_o(ksu_out)
    );

    // FSM States
    typedef enum reg {
        STATE_IDLE,
        STATE_PADDING,
        STATE_XOR,
        STATE_THETA,
        STATE_RHO,
        STATE_PI,
        STATE_CHI,
        STATE_IOTA,
        STATE_SLICE,
        STATE_DONE
    } state_t;
    state_t state, next_state;

    // Keccak Control FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            state_array <= 'b0;
            round_index <= 'b0;
            step_sel <= IDLE_STEP;
        end else begin
            state <= next_state;
            state_array <= state_array_next;
        end
    end

    always @(*) begin
        case(state)
            STATE_IDLE : begin
                if (start_i) begin
                    next_state = STATE_PADDING;
                    step_sel = 
                end else begin
                    next_state = STATE_IDLE;;
                    step_sel = IDLE_STEP;
                end
            end
            STATE_PADDING : begin

            end
            STATE_XOR : begin

            end
            STATE_THETA : begin

            end
            STATE_RHO : begin

            end
            STATE_PI : begin

            end
            STATE_CHI : begin

            end
            STATE_IOTA : begin

            end
            STATE_SLICE : begin

            end
            STATE_DONE : begin

            end
        endcase
    end

endmodule
