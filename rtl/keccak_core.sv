import keccak_pkg::*;

module keccak_core (
    input                                   clk,
    input                                   rst,

    input                                   start_i,
    input [MODE_SEL_WIDTH-1:0]              keccak_mode_i,

    // AXI4-Stream Signals - Sink
    input   logic [DWIDTH-1:0]              t_data_i,
    input   logic                           t_valid_i,
    input   logic                           t_last_i,
    input   logic [KEEP_WIDTH-1:0]          t_keep_i,
    output  logic                           t_ready_o,
    // AXI4-Stream Signals - Source
    output  logic [MAX_OUTPUT_DWIDTH-1:0]   t_data_o,
    output  logic                           t_valid_o,
    output  logic                           t_last_o,
    input   logic                           t_ready_i
);
    /*
     * 1600-bit State Array using to hold the state of keccak core.
     * See FIPS202 Section 3.1.1 for more information on state array.
     */
    reg     [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array;
    wire    [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] ksu_out;
    wire    [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_new;

    typedef enum {
        KSU_SEL,
        ABSORB_SEL
    } sa_in_sel;
    sa_in_sel state_array_in_sel;

    // Each output requires 24 rounds of permutations (θ, ρ, π, χ, ι)
    reg [ROUND_INDEX_SIZE-1:0] round_index;
    reg [STEP_SEL_WIDTH-1:0] step_sel;

    // SHA3 Paramter Setup
    wire    [RATE_WIDTH-1:0] rate_wire;
    logic   [RATE_WIDTH-1:0] rate;
    wire    [CAPACITY_WIDTH-1:0] capacity_wire;
    logic   [CAPACITY_WIDTH-1:0] capacity;
    wire    [SUFFIX_WIDTH-1:0] suffix_wire;
    logic   [SUFFIX_WIDTH-1:0] suffix;
    wire    [SUFFIX_LEN_WIDTH-1:0] suffix_len_wire;
    logic   [SUFFIX_LEN_WIDTH-1:0] suffix_len;

    // FSM Control Signals
    logic state_array_wr_en;
    logic [MODE_SEL_WIDTH-1:0] keccak_mode;
    logic init_settings_en;

    // Absorbing Signals
    logic   [RATE_WIDTH-1:0]        bytes_absorbed; // Num of bytes absorbed in the current rate block
    reg     [CARRY_WIDTH-1:0]       carry_over;     // If rate is full, need to carry over values from input
    reg                             has_carry_over; // Carry over flag
    reg     [CARRY_LEN_WIDTH-1:0]   carry_keep;
    logic                           msg_recieved;   // Full message has been received

    // FSM States
    typedef enum {
        STATE_IDLE,
        STATE_ABSORB,
        STATE_SUFFIX,
        STATE_PADDING,
        STATE_THETA,
        STATE_RHO,
        STATE_PI,
        STATE_CHI,
        STATE_IOTA,
        STATE_DONE
    } state_t;
    state_t state, next_state;

    sha3_setup sha3_setup (
        .keccak_mode_i(keccak_mode_i),
        .rate_o(rate_wire),
        .capacity_o(capacity_wire),
        .suffix_o(suffix_wire),
        .suffix_len_o(suffix_len_wire)
    );

    keccak_step_unit KSU (
        .state_array_i(state_array),
        .round_index_i(round_index),
        .step_sel_i(step_sel),
        .step_array_o(ksu_out)
    );

    // Keccak Control FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state               <= STATE_IDLE;
            state_array         <= 'b0;
            state_array_wr_en   <= 1'b0;
            round_index         <= 'b0;
            step_sel            <= IDLE_STEP;
            msg_recieved        <= 1'b0;
        end else begin
            state <= next_state;

            if (state_array_wr_en) begin
                case (state_array_in_sel)
                    KSU_SEL : begin
                        state_array <= ksu_out;
                    end
                    ABSORB_SEL : begin
                        state_array <= state_out;
                    end
                    default : begin
                        state_array <= state_array;
                    end
                endcase
            end

            if (t_last_i) begin
                msg_recieved <= 1'b1;
            end
        end
    end

    always @(*) begin
        // Default FSM Control Signals:
        state_array_wr_en   <= 1'b0;
        step_sel            <= IDLE_STEP;
        init_settings_en    <= 1'b0;

        // Default Output Signals
        t_ready_o           <= 1'b0;
        t_valid_o           <= 1'b0;
        t_last_o            <= 1'b0;

        // State Transitions
        case(state)
            STATE_IDLE : begin
                if (start_i) begin
                    next_state = STATE_ABSORB;
                    init_settings_en = 1'b1;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_ABSORB : begin
                if (has_carry_over) begin
                    
                end else if (t_valid_i) begin
                    
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        // Initialization
        if (init_settings_en) begin
            // Setup Parameters
            keccak_mode <= keccak_mode_i;
            rate        <= rate_wire;
            capacity    <= capacity_wire;
            suffix      <= suffix_wire;
            suffix_len  <= suffix_len_wire;

            bytes_absorbed <= 'b0;
        end
    end

endmodule
