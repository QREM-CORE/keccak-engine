/*
 * Module Name: keccak_core
 * Author: Kiet Le
 * Description: Top level module of Keccak Core
 */

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
    // ==========================================================
    // 1. KECCAK LOGIC, WIRES, REGISTERS AND ENUMS
    // ==========================================================

    // 1A. Enum Instantiations
    // ----------------------------------------------------------

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

    // 1B. Registers
    // ----------------------------------------------------------

    // 1600-bit State Array using to hold the state of keccak core.
    // See FIPS202 Section 3.1.1 for more information on state array.
    reg [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array;

    // KSU Permutation Registers
    reg [ROUND_INDEX_SIZE-1:0]      round_idx;
    reg [STEP_SEL_WIDTH-1:0]        step_sel;

    // Keccak Parameter Setup Registers
    reg [RATE_WIDTH-1:0]            rate;
    reg [CAPACITY_WIDTH-1:0]        capacity;
    reg [SUFFIX_WIDTH-1:0]          suffix;

    // Keccak Mode Register
    reg [MODE_SEL_WIDTH-1:0]        keccak_mode;

    // Absorb Phase Registers
    reg                             absorb_done; // Absorb stage fully complete flag
    reg     [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed; // # of bytes absorbed in the current rate block
    reg     [DWIDTH-1:0]            carry_over;     // If rate is full, need to carry over values
    reg                             has_carry_over; // Carry over flag
    reg     [KEEP_WIDTH-1:0]        carry_keep;
    reg                             msg_recieved;   // Full message has been received

    // Squeeze Signals
    logic   [BYTE_ABSORB_WIDTH-1:0] bytes_squeezed;

    // 1C. Enable Wires
    // ----------------------------------------------------------

    // Misc. FSM Enables
    logic state_array_wr_en;
    logic init_wr_en;
    logic rst_round_idx_en;
    logic inc_round_idx_en;

    // Absorb Enable Wires
    logic absorb_wr_en;
    logic complete_absorb_en;

    // Permutation Enable
    logic perm_en;

    // Squeeze Enable
    logic squeeze_wr_en;

    // 1D. Module Wires and Registers
    // ----------------------------------------------------------

    // Keccak Parameter Unit (KPU) Module Wires
    wire [MODE_SEL_WIDTH-1:0]       KPU_MODE_I;

    wire [RATE_WIDTH-1:0]           KPU_RATE_O;
    wire [CAPACITY_WIDTH-1:0]       KPU_CAPACITY_O;
    wire [SUFFIX_WIDTH-1:0]         KPU_SUFFIX_O;

    // Keccak Step Unit (KSU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KSU_STATE_ARRAY_I;
    wire [ROUND_INDEX_SIZE-1:0]     KSU_ROUND_INDEX_I;
    wire [STEP_SEL_WIDTH-1:0]       KSU_STEP_SEL_I;

    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KSU_STATE_ARRAY_O;

    // Keccak Absorb Unit (KAU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KAU_STATE_ARRAY_I;
    wire [RATE_WIDTH-1:0]           KAU_RATE_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    KAU_BYTES_ABSORBED_I;
    wire [DWIDTH-1:0]               KAU_MSG_I;
    wire [KEEP_WIDTH-1:0]           KAU_KEEP_I;

    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KAU_STATE_ARRAY_O;
    wire [BYTE_ABSORB_WIDTH-1:0]    KAU_BYTES_ABSORBED_O;
    wire                            KAU_HAS_CARRY_OVER_O;
    wire [KEEP_WIDTH-1:0]           KAU_CARRY_KEEP_O;
    wire [DWIDTH-1:0]               KAU_CARRY_OVER_O;

    // Suffix Padder Unit (SPU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] SPU_STATE_ARRAY_I;
    wire [RATE_WIDTH-1:0]           SPU_RATE_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    SPU_BYTES_ABSORBED_I;
    wire [SUFFIX_WIDTH-1:0]         SPU_SUFFIX_I;

    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] SPU_STATE_ARRAY_O;

    // Squeeze Output Unit (KOU) Module Wires
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] KOU_STATE_ARRAY_I;
    wire [MODE_SEL_WIDTH-1:0]       KOU_MODE_I;
    wire [RATE_WIDTH-1:0]           KOU_RATE_I;
    wire [BYTE_ABSORB_WIDTH-1:0]    KOU_BYTES_SQUEEZED_I;

    wire [BYTE_ABSORB_WIDTH-1:0]    KOU_BYTES_SQUEEZED_O;
    wire                            KOU_PERM_NEEDED_O;
    wire [DWIDTH-1:0]               KOU_DATA_O;
    wire [KEEP_WIDTH-1:0]           KOU_KEEP_O;
    wire                            KOU_LAST_O;

    // 1E. Wire Assignments
    // ----------------------------------------------------------

    // Max Byte Absorb Value
    logic [RATE_WIDTH-1:0] max_bytes_absorbed;
    assign max_bytes_absorbed   = rate >> 3;

    assign t_data_o             = KOU_DATA_O;
    assign t_keep_o             = KOU_KEEP_O;

    // ==========================================================
    // 2. HELPER MODULE INSTANTIATIONS
    // ==========================================================

    // 2A. KECCAK PARAMETER UNIT (KPU)
    // ----------------------------------------------------------
    // Module to get sha3 parameters during initializtion
    keccak_param_unit KPU (
        .keccak_mode_i  (KPU_MODE_I),

        .rate_o         (KPU_RATE_O),
        .capacity_o     (KPU_CAPACITY_O),
        .suffix_o       (KPU_SUFFIX_O)
    );
    assign KPU_MODE_I = keccak_mode_i;

    // 2B. KECCAK STEP UNIT (KSU)
    // ----------------------------------------------------------
    // Keccak Step Mapping Operations Module
    keccak_step_unit KSU (
        .state_array_i  (KSU_STATE_ARRAY_I),
        .round_index_i  (KSU_ROUND_INDEX_I),
        .step_sel_i     (KSU_STEP_SEL_I),

        .state_array_o  (KSU_STATE_ARRAY_O)
    );
    assign KSU_STATE_ARRAY_I    = state_array;
    assign KSU_ROUND_INDEX_I    = round_idx;
    assign KSU_STEP_SEL_I       = step_sel;

    // 2C. KECCAK ABSORB UNIT (KAU)
    // ----------------------------------------------------------
    // Module to handle absorbing of input message
    keccak_absorb_unit KAU (
        .state_array_i      (KAU_STATE_ARRAY_I),
        .rate_i             (KAU_RATE_I),
        .bytes_absorbed_i   (KAU_BYTES_ABSORBED_I),
        .msg_i              (KAU_MSG_I),
        .keep_i             (KAU_KEEP_I),

        .state_array_o      (KAU_STATE_ARRAY_O),
        .bytes_absorbed_o   (KAU_BYTES_ABSORBED_O),
        .has_carry_over_o   (KAU_HAS_CARRY_OVER_O),
        .carry_keep_o       (KAU_CARRY_KEEP_O),
        .carry_over_o       (KAU_CARRY_OVER_O)
    );
    assign KAU_STATE_ARRAY_I    = state_array;
    assign KAU_RATE_I           = rate;
    assign KAU_BYTES_ABSORBED_I = bytes_absorbed;
    assign KAU_MSG_I            = has_carry_over ? { 64'b0, carry_over} : t_data_i;
    assign KAU_KEEP_I           = has_carry_over ? {  8'b0, carry_keep} : t_keep_i;

    // 2D. SUFFIX PADDER UNIT (SPU)
    // ----------------------------------------------------------
    suffix_padder_unit SPU (
        .state_array_i    (SPU_STATE_ARRAY_I),
        .rate_i           (SPU_RATE_I),
        .bytes_absorbed_i (SPU_BYTES_ABSORBED_I),
        .suffix_i         (SPU_SUFFIX_I),

        .state_array_o    (SPU_STATE_ARRAY_O)
    );
    assign SPU_STATE_ARRAY_I    = state_array;
    assign SPU_RATE_I           = rate;
    assign SPU_BYTES_ABSORBED_I = bytes_absorbed;
    assign SPU_SUFFIX_I         = suffix;

    // 2E. SQUEEZE OUTPUT UNIT (KOU)
    // ----------------------------------------------------------
    keccak_output_unit KOU (
        .state_array_i          (KOU_STATE_ARRAY_I),
        .keccak_mode_i          (KOU_MODE_I),
        .rate_i                 (KOU_RATE_I),
        .bytes_squeezed_i       (KOU_BYTES_SQUEEZED_I),

        .bytes_squeezed_o       (KOU_BYTES_SQUEEZED_O),
        .squeeze_perm_needed_o  (KOU_PERM_NEEDED_O),
        .data_o                 (KOU_DATA_O),
        .keep_o                 (KOU_KEEP_O),
        .last_o                 (KOU_LAST_O)
    );
    assign KOU_STATE_ARRAY_I    = state_array;
    assign KOU_MODE_I           = keccak_mode;
    assign KOU_RATE_I           = rate;
    assign KOU_BYTES_SQUEEZED_I = bytes_squeezed;

    // ==========================================================
    // 3. SEQUENTIAL CONTROL FSM UPDATES
    // ==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state               <= STATE_IDLE;
            state_array         <= 'b0;
            round_idx           <= 'b0;
            msg_recieved        <= 'b0;

            // Absorb Signals
            absorb_done         <= 'b0;
            bytes_absorbed      <= 'b0;
            carry_over          <= 'b0;
            has_carry_over      <= 'b0;
            carry_keep          <= 'b0;

            // Squeeze Signals
            bytes_squeezed  <= 'b0;
        end else begin
            // FSM State Updating
            state <= next_state;

            // Initialization
            if (init_wr_en) begin
                // 1. Setup Parameters
                keccak_mode     <= keccak_mode_i;
                rate            <= KPU_RATE_O;
                capacity        <= KPU_CAPACITY_O;
                suffix          <= KPU_SUFFIX_O;

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
                        state_array <= KSU_STATE_ARRAY_O;
                    end
                    ABSORB_SEL : begin
                        state_array <= KAU_STATE_ARRAY_O;
                    end
                    PADDING_SEL : begin
                        state_array <= SPU_STATE_ARRAY_O;
                    end
                    default : begin
                        state_array <= state_array;
                    end
                endcase
            end

            // Absorb Stage Updating
            if (absorb_wr_en) begin
                bytes_absorbed  <= KAU_BYTES_ABSORBED_O;

                if (KAU_HAS_CARRY_OVER_O) begin
                    has_carry_over  <= 1'b1;
                    carry_over      <= KAU_CARRY_OVER_O;
                    carry_keep      <= KAU_CARRY_KEEP_O;
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
                bytes_squeezed <= KOU_BYTES_SQUEEZED_O;
            end
        end
    end

    // ==========================================================
    // 4. COMBINATIONAL CONTROL FSM
    // ==========================================================
    always_comb begin
        // Default FSM Control Signals:
        next_state          = STATE_IDLE;
        state_array_wr_en   = 1'b0;
        step_sel            = IDLE_STEP;
        init_wr_en          = 1'b0;

        // Absorb Wires
        absorb_wr_en        = 1'b0;
        complete_absorb_en  = 1'b0;
        perm_en             = 1'b0;

        // Step Mapping
        rst_round_idx_en    = 1'b0;
        inc_round_idx_en    = 1'b0;

        // Squeeze Signals
        squeeze_wr_en       = 1'b0;

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
                    next_state = STATE_ABSORB;
                    absorb_wr_en = 1'b1;
                    state_array_wr_en = 1'b1;
                    state_array_in_sel = ABSORB_SEL;

                // Step 3: Check if there is valid input and to process if so
                end else if (t_valid_i) begin
                    next_state = STATE_ABSORB;
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
                    t_valid_o   = 1'b1;
                    t_last_o    = KOU_LAST_O;

                    // A. Check Fixed Hash Done (SHA3-*)
                    if (KOU_LAST_O) begin
                        next_state = STATE_IDLE;
                        init_wr_en = 1'b1;

                    // B. Check Rate Empty -> Re-Permute (SHAKE)
                    end else if (KOU_PERM_NEEDED_O) begin
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
