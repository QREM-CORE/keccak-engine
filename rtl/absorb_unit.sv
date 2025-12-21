/*
 * Module Name: absorb_unit
 * Author: Kiet Le
 * Description: Absorb 32 byte input into state array and output state array.
 *              All inputs shall have valid 32 byte input except the final transfer of full message...
 *              which can have any value equal or less than 32 bytes.
 *              Carry output always assumes 64 bits of input is valid, and the rest will be carried...
 *              over with corresponding carry keep valid flags.
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

// Compute state array after absorption
module absorb_unit (
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input   logic [RATE_WIDTH-1:0]          rate_i,
    input   logic [BYTE_ABSORB_WIDTH-1:0]   bytes_absorbed_i,
    input   logic [DWIDTH-1:0]              msg_i,
    input   logic [KEEP_WIDTH-1:0]          keep_i,

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o,
    output  logic [BYTE_ABSORB_WIDTH-1:0]   bytes_absorbed_o,
    output  logic                           has_carry_over_o,
    output  logic [DWIDTH-1:0]              carry_over_o,
    output  logic [KEEP_WIDTH-1:0]          carry_keep_o
);
    localparam int INPUT_LANE_NUM = 4;
    localparam int BYTES_PER_LANE = LANE_SIZE/BYTE_SIZE;
    localparam int TOTAL_BYTES = DWIDTH/BYTE_SIZE;
    localparam int CARRY_KEEP_LOWER_INDEX = 8;
    localparam int CARRY_OVER_LOWER_INDEX = 64;
    localparam int BYTE_DIV_32_WIDTH = 3;
    localparam int INPUT_BYTES_NUM = DWIDTH/8;

    // Physical Limit: The absolute max rate defined by the spec (SHAKE128)
    // 1344 bits / 64 = 21 lanes. Indices 0 to 20 are valid.
    localparam int MAX_POSSIBLE_LANES = 21;

    // ==========================================================
    // Step 0: Mask Input Data
    // ==========================================================
    // Zero out invalid bytes in msg_i
    logic [DWIDTH-1:0] msg_masked;
    always_comb begin
        for (int b = 0; b < (DWIDTH/8); b++) begin
            // Byte-wise masking
            msg_masked[b*8 +: 8] = keep_i[b] ? msg_i[b*BYTE_SIZE +: BYTE_SIZE] : 8'h00;
        end
    end

    // ==========================================================
    // Step 1: Calculate Space and Valid Counts
    // ==========================================================
    logic [RATE_WIDTH-1:0] rate_bytes;
    assign rate_bytes = rate_i >> 3; // Convert bits to bytes

    logic [RATE_WIDTH-1:0] space_in_block;
    assign space_in_block = rate_bytes - bytes_absorbed_i;

    logic [$clog2(KEEP_WIDTH + 1)-1:0] valid_byte_count;
    assign valid_byte_count = $countones(keep_i);

    // ==========================================================
    // Step 2: Process Carry (Dynamic Logic)
    // ==========================================================
    always_comb begin
        // Check if input data exceeds the remaining space in the rate block
        if (valid_byte_count > space_in_block) begin
            // Carry Over Needed
            has_carry_over_o = 'b1;
            bytes_absorbed_o = rate_bytes;

            // Calculate Carry Data
            // We take the upper bytes (that didn't fit) and SHIFT them down to 0.
            // This aligns them for the NEXT absorption cycle.
            // Example: space=8. We use msg[63:0]. Carry starts at msg[64].
            // We shift msg right by 64 bits.
            carry_over_o = DWIDTH'(msg_masked >> (space_in_block * 8));
            carry_keep_o = KEEP_WIDTH'(keep_i >> space_in_block);

        end else begin
            // Carry not needed
            has_carry_over_o    = '0;
            bytes_absorbed_o    = bytes_absorbed_i + valid_byte_count;
            carry_keep_o        = '0;
            carry_over_o        = '0;
        end
    end

    // ==========================================================
    // Step 3: Split Lanes
    // ==========================================================
    // Split the msg_masked into four 64-bit lanes
    wire [LANE_SIZE-1:0] split_lanes [INPUT_LANE_NUM];
    genvar i;
    generate
        for (i = 0; i<INPUT_LANE_NUM; i=i+1) begin : g_split_loop
            assign split_lanes[i] = msg_masked[i*LANE_SIZE +: LANE_SIZE];
        end
    endgenerate

    // ==========================================================
    // Step 4: XOR into State (With Boundary Checks)
    // ==========================================================
    // Find the corresponding lanes and XOR into result
    // Note: This logic assumes inputs are aligned to 64-bit boundaries relative to the full state.
    logic [4:0] rate_lane_limit;
    assign rate_lane_limit = rate_i[RATE_WIDTH-1:6]; // rate_i / 64

    int start_lane_idx;

    always_comb begin
        // Default
        state_array_o = state_array_i;

        // Determine the starting linear lane index (0, 32, 64, 96, ...)
        // Logic: bytes / 8 bytes_per_lane
        start_lane_idx = int'(bytes_absorbed_i >> 3);

        // Loop through 4 input lanes
        for (int i = 0; i<INPUT_LANE_NUM; i=i+1) begin
            int current_lane_idx;
            int x, y;

            // Linear index for current lane
            current_lane_idx = start_lane_idx + i;

            /* Coordinate Mapping:
             * x = index % 5 (Column)
             * y = index / 5 (Row)
             */
            x = current_lane_idx % COL_SIZE;
            y = current_lane_idx / ROW_SIZE;

            // Check if lane is valid
            // If we have a carry, the upper lanes of 'split_lanes' will correspond
            // to current_lane_idx >= rate_lane_limit, so they will be IGNORED here.
            if (current_lane_idx < rate_lane_limit && current_lane_idx < MAX_POSSIBLE_LANES) begin
                state_array_o[x][y] = state_array_i[x][y] ^ split_lanes[i];
            end
        end
    end

endmodule
