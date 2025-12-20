import keccak_pkg::*;

module keccak_core (
    input   logic                           clk,
    input   logic                           rst,

    input   logic                           start_i,
    input   logic [MODE_SEL_WIDTH-1:0]      keccak_mode_i,
    input   logic                           stop_i,

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
    output  logic [KEEP_WIDTH-1:0]          t_keep_o,
    input   logic                           t_ready_i
);
    /*
     * 1600-bit State Array using to hold the state of keccak core.
     * See FIPS202 Section 3.1.1 for more information on state array.
     */
    reg [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array;

    // FSM States
    typedef enum {
        STATE_IDLE,
        STATE_ABSORB,
        STATE_SUFFIX_PADDING,
        STATE_THETA,
        STATE_RHO,
        STATE_PI,
        STATE_CHI,
        STATE_IOTA,
        STATE_SQUEEZE
    } state_t;
    state_t state, next_state;

    // State Array Write Selector Options
    typedef enum {
        KSU_SEL,
        ABSORB_SEL,
        PADDING_SEL
    } sa_in_sel_t;
    sa_in_sel_t state_array_in_sel;

    // KSU Signals
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] ksu_out;
    reg [ROUND_INDEX_SIZE-1:0] round_idx;
    reg [STEP_SEL_WIDTH-1:0] step_sel;

    // SHA3 Paramter Setup Signals
    wire    [RATE_WIDTH-1:0] rate_wire;
    logic   [RATE_WIDTH-1:0] rate;
    wire    [CAPACITY_WIDTH-1:0] capacity_wire;
    logic   [CAPACITY_WIDTH-1:0] capacity;
    wire    [SUFFIX_WIDTH-1:0] suffix_wire;
    logic   [SUFFIX_WIDTH-1:0] suffix;

    // FSM Control Signals
    logic state_array_wr_en;
    logic [MODE_SEL_WIDTH-1:0] keccak_mode;
    logic init_wr_en;
    logic rst_round_idx_en;
    logic inc_round_idx_en;

    // Absorbing Signals
    logic                           absorb_done; // Absorb stage fully complete flag
    logic                           complete_absorb_en;
    logic                           absorb_wr_en;
    logic                           max_bytes_absorbed;
    logic                           perm_en; // Enable Absorb Stage to permutate state
    logic   [DWIDTH-1:0]            ABSORB_UNIT_MSG_I;
    logic   [KEEP_WIDTH-1:0]        ABSORB_UNIT_KEEP_I;

    logic   [RATE_WIDTH-1:0]        bytes_absorbed; // # of bytes absorbed in the current rate block
    reg     [CARRY_WIDTH-1:0]       carry_over;     // If rate is full, need to carry over values
    reg                             has_carry_over; // Carry over flag
    reg     [CARRY_KEEP_WIDTH-1:0]  carry_keep;
    logic                           msg_recieved;   // Full message has been received
    // Absorb Module Outputs
    wire    [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] absorb_state_out;
    logic   [RATE_WIDTH-1:0]                            bytes_absorbed_o;
    logic                                               has_carry_over_o;
    logic   [CARRY_KEEP_WIDTH-1:0]                      carry_keep_o;
    logic   [CARRY_WIDTH-1:0]                           carry_over_o;

    // Suffix/Padding Signals
    wire    [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] padding_state_out;

    // Squeeze Signals
    logic                       squeeze_wr_en;
    wire                        squeeze_perm_needed_wire;
    logic   [RATE_WIDTH-1:0]    bytes_squeezed;
    wire    [RATE_WIDTH-1:0]    bytes_squeezed_o;

    // Module to get sha3 parameters during initializtion
    sha3_setup sha3_setup (
        .keccak_mode_i(keccak_mode_i),
        .rate_o(rate_wire),
        .capacity_o(capacity_wire),
        .suffix_o(suffix_wire)
    );

    // Keccak Step Mapping Operations Module
    keccak_step_unit KSU (
        .state_array_i(state_array),
        .round_index_i(round_idx),
        .step_sel_i(step_sel),
        .step_array_o(ksu_out)
    );

    // Absorb Functionality Module
    absorb_unit absorb_unit_i (
        .state_array_i(state_array),
        .rate_i(rate_wire),
        .bytes_absorbed_i(bytes_absorbed),
        .msg_i(ABSORB_UNIT_MSG_I),
        .keep_i(ABSORB_UNIT_KEEP_I),

        .state_array_o(absorb_state_out),
        .bytes_absorbed_o(bytes_absorbed_o),
        .has_carry_over_o(has_carry_over_o),
        .carry_keep_o(carry_keep_o),
        .carry_over_o(carry_over_o)
    );
    assign ABSORB_UNIT_MSG_I    = has_carry_over ? { 64'b0, carry_over} : t_data_i;
    assign ABSORB_UNIT_KEEP_I   = has_carry_over ? {  8'b0, carry_keep} : t_keep_i;

    // Max Byte Absorb Value
    assign max_bytes_absorbed = rate_wire >> 3;

    suffix_padder_unit suf_padder_i (
        .state_array_i    (state_array),
        .rate_i           (rate_wire),
        .bytes_absorbed_i (bytes_absorbed),
        .suffix_i         (suffix_wire),
        .state_array_o    (padding_state_out)
    );

    squeeze_unit squeeze_unit_i (
        .state_array_i(state_array),
        .keccak_mode_i(keccak_mode),
        .rate_i(rate_wire),
        .bytes_squeezed_i(bytes_squeezed),

        .bytes_squeezed_o(bytes_squeezed_o),
        .squeeze_perm_needed_o(squeeze_perm_needed_wire),
        .data_o(t_data_o),
        .keep_o(t_keep_o),
        .last_o(t_last_o)
    );

    // Sequential Control FSM Updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state               <= STATE_IDLE;
            state_array         <= 'b0;
            round_idx           <= 'b0;
            msg_recieved        <= 'b0;

            // Absorb Signals
            absorb_done     <= 'b0;
            bytes_absorbed  <= 'b0;
            carry_over      <= 'b0;
            has_carry_over  <= 'b0;
            carry_keep      <= 'b0;

            // Squeeze Signals
            bytes_squeezed  <= 'b0;
        end else begin
            // FSM State Updating
            state <= next_state;

            // Initialization
            if (init_wr_en) begin
                // 1. Setup Parameters
                keccak_mode <= keccak_mode_i;
                rate        <= rate_wire;
                capacity    <= capacity_wire;
                suffix      <= suffix_wire;

                // 2. CRITICAL: Wipe the State Logic
                state_array     <= '0;  // Must be 0 before starting new Absorb
                bytes_absorbed  <= '0;
                bytes_squeezed  <= '0;
                msg_recieved    <= '0;

                // 3. Clear Internal Flags
                absorb_done     <= '0;
                has_carry_over  <= '0;
                carry_over      <= '0;
                carry_keep      <= '0;
                round_idx       <= '0;

            // Reset bytes absorbed after absorb permutation
            end else if (perm_en) begin
                bytes_absorbed <= '0;
                bytes_squeezed <= '0;
            end

            // State Array Updating
            if (state_array_wr_en) begin
                case (state_array_in_sel)
                    KSU_SEL : begin
                        state_array <= ksu_out;
                    end
                    ABSORB_SEL : begin
                        state_array <= absorb_state_out;
                    end
                    PADDING_SEL : begin
                        state_array <= padding_state_out;
                    end
                    default : begin
                        state_array <= state_array;
                    end
                endcase
            end

            // Absorb Stage Updating
            if (absorb_wr_en) begin
                bytes_absorbed  <= bytes_absorbed_o;

                if (has_carry_over_o) begin
                    has_carry_over  <= 1'b1;
                    carry_over      <= carry_over_o;
                    carry_keep      <= carry_keep_o;
                end else begin
                    has_carry_over  <= 1'b0;
                end
            end
            // Set flag for absorb completion
            if (complete_absorb_en) begin
                absorb_done <= 1'b1;
            end
            // If source has completed full message transfer
            if (t_last_i) begin
                msg_recieved <= 1'b1;
            end

            // Permutation Round Updating
            if (rst_round_idx_en) begin
                round_idx <= 'b0;
            end else if (inc_round_idx_en) begin
                round_idx <= round_idx + 'b1;
            end

            // Squeeze Updating
            if (squeeze_wr_en) begin
                bytes_squeezed <= bytes_squeezed_o;
            end
        end
    end

    // Combinational Control FSM
    always_comb begin
        // Default FSM Control Signals:
        next_state          = STATE_IDLE;
        state_array_wr_en   = 1'b0;
        step_sel            = IDLE_STEP;
        init_wr_en          = 1'b0;

        // Absorb Wires
        absorb_wr_en        = 1'b0;
        complete_absorb_en     = 1'b0;
        perm_en      = 1'b0;

        // Default Output Signals
        t_ready_o           = 1'b0;
        t_valid_o           = 1'b0;
        t_last_o            = 1'b0;

        // State Transitions
        case(state)
            STATE_IDLE : begin
                if (start_i) begin
                    next_state = STATE_ABSORB;
                    init_wr_en = 1'b1;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_ABSORB : begin
                // Step 1: If current rate block is full, run permutation
                if (bytes_absorbed == max_bytes_absorbed) begin
                    next_state = STATE_THETA;
                    perm_en = 1'b1;

                // Step 2: Check if there is a unhandled carry over
                end else if (has_carry_over) begin
                    absorb_wr_en = 1'b1;
                    state_array_wr_en = 1'b1;
                    state_array_in_sel = ABSORB_SEL;

                // Step 3: Check if there is valid input and to process if so
                end else if (t_valid_i) begin
                    absorb_wr_en = 1'b1;
                    state_array_wr_en = 1'b1;
                    state_array_in_sel = ABSORB_SEL;

                    // Output
                    t_ready_o = 1'b1; // ready for more data

                // Message fully received, move on to padding stage
                end else if (msg_recieved) begin
                    next_state = STATE_SUFFIX_PADDING;
                    complete_absorb_en = 1'b1;

                // Message not yet fully received, waiting for t_valid
                end else begin
                    next_state = STATE_ABSORB;

                    // Output
                    t_ready_o = 1'b1; // ready for more data
                end
            end

            STATE_SUFFIX_PADDING : begin
                state_array_wr_en = 1'b1;
                state_array_in_sel = PADDING_SEL;
                next_state = STATE_THETA;
                perm_en = 1'b1;
            end

            STATE_THETA : begin
                next_state          = STATE_RHO;
                state_array_wr_en   = 1'b1;
                step_sel            = THETA_STEP;
                state_array_in_sel  = KSU_SEL;
            end

            STATE_RHO : begin
                next_state          = STATE_PI;
                state_array_wr_en   = 1'b1;
                step_sel            = RHO_STEP;
                state_array_in_sel  = KSU_SEL;
            end

            STATE_PI : begin
                next_state          = STATE_CHI;
                state_array_wr_en   = 1'b1;
                step_sel            = PI_STEP;
                state_array_in_sel  = KSU_SEL;
            end

            STATE_CHI : begin
                next_state          = STATE_IOTA;
                state_array_wr_en   = 1'b1;
                step_sel            = CHI_STEP;
                state_array_in_sel  = KSU_SEL;
            end

            STATE_IOTA : begin
                if (round_idx == 'd23) begin
                    if (absorb_done) begin
                        next_state = STATE_SQUEEZE;
                    end else begin
                        next_state = STATE_ABSORB;
                    end
                    rst_round_idx_en = 1'b1;
                end else begin
                    next_state = STATE_THETA;
                    inc_round_idx_en = 1'b1;
                end

                state_array_wr_en   = 1'b1;
                step_sel            = IOTA_STEP;
                state_array_in_sel  = KSU_SEL;
            end

            STATE_SQUEEZE : begin
                // PRIORITY 1: External Stop
                if (stop_i) begin
                    next_state = STATE_IDLE;
                    init_wr_en = 1'b1;

                // PRIORITY 2: Output Data
                end else if (t_ready_i) begin
                    t_valid_o = 1'b1;

                    // A. Check Fixed Hash Done (SHA3-*)
                    if (t_last_o) begin
                        next_state = STATE_IDLE;
                        init_wr_en = 1'b1;

                    // B. Check Rate Empty -> Re-Permute (SHAKE)
                    end else if (squeeze_perm_needed_wire) begin
                        next_state = STATE_THETA;
                        perm_en = 1'b1; // Reset counters

                    // C. Continue Squeezing
                    end else begin
                        next_state = STATE_SQUEEZE;
                        squeeze_wr_en = 1'b1;
                    end
                end
            end

            default : begin
                next_state = STATE_IDLE;
            end
        endcase
    end

endmodule
