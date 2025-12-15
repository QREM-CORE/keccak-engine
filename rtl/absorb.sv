import keccak_pkg::*;

// Compute state array after absorption
module absorb (
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input   logic [RATE_WIDTH-1:0]        rate_i,
    input   logic [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_i,
    input   logic [DWIDTH-1:0]            msg_i,
    input   logic [KEEP_WIDTH-1:0]        keep_i

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o,
    output  logic [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_o,
    output  logic [CARRY_WIDTH-1:0]       carry_over_o,
    output  logic                         has_carry_over_o,
    output  logic [CARRY_KEEP_WIDTH-1:0]  carry_keep_o
);
    localparam INPUT_LANE_NUM = 4;
    localparam BYTES_PER_LANE = LANE_SIZE/BYTE_SIZE;
    localparam TOTAL_BYTES = DWIDTH/BYTE_SIZE;
    localparam CARRY_KEEP_LOWER_INDEX = 64;
    localparam CARRY_OVER_LOWER_INDEX = KEEP_WIDTH-CARRY_KEEP_WIDTH;
    localparam BYTE_DIV_32_WIDTH = 3;
    localparam INPUT_BYTES_NUM = DWIDTH/8;

    // Physical Limit: The absolute max rate defined by the spec (SHAKE128)
    // 1344 bits / 64 = 21 lanes. Indices 0 to 20 are valid.
    localparam int MAX_POSSIBLE_LANES = 21;

    /* Need to XOR to correct portions of the data in.
     * bytes_absorbed_i should always be a multiple of 64 bits at least...
     * until the last read in, which can be any value of bytes.
     * This means we dont have to worry about writing into a state that is unaligned (multiple of 64 bits).
     */

    // Valid Handling and carry over wires
    logic [$clog2(KEEP_WIDTH)-1:0] valid_byte_count;
    assign valid_byte_count = $countones(keep_i);
    logic [RATE_WIDTH-1:0] potential_absorbed;
    assign potential_absorbed = bytes_absorbed_i + valid_byte_count;

    logic [DWIDTH-1:0] processed_msg;

    // Step 1: Process Carry and Input MSG
    always_comb begin
        // Carry Over Needed
        if (potential_absorbed > (rate_i >> 3)) begin // Convert rate_i bits to bytes (>> 3 == /8)
            has_carry_over_o = 'b1;

            /* Always know that the carry over is always the latter 192 bits of the input.
             * Need to use valid bits to know which bytes are valid
             */

            /* Most Significant 24-bits of keep_i correspond to the most significant 192-bits
              of the carry over (which is the most signficant 192 bits of the msg_i) */
            carry_keep_o = keep_i[KEEP_WIDTH-1:CARRY_KEEP_LOWER_INDEX];
            carry_over_o = msg_i[DWIDTH-1:CARRY_OVER_LOWER_INDEX];

            // Only process the lower 64-bits of msg_i
            processed_msg = {192'b0, msg_i[CARRY_OVER_LOWER_INDEX-1:0]};

            // Guaranteed 8-bytes (64 bits) absorbed when there is a carry
            bytes_absorbed_o = bytes_absorbed_i + 'd8;

        // Carry not needed
        end else begin
            has_carry_over_o = 'b0;
            carry_keep_o = 'b0;

            for (int i = 0; i<TOTAL_BYTES; i=i+1) begin
                processed_msg[i*BYTE_SIZE +: BYTE_SIZE] =   keep_i[i] ?
                                                            msg_i[i*BYTE_SIZE +: BYTE_SIZE] :
                                                            8'b0;
            end

            bytes_absorbed_o = potential_absorbed;
        end
    end

    // Step 2: Split the processed_msg into four 64-bit lanes
    wire [LANE_SIZE-1:0] split_lanes [INPUT_LANE_NUM];
    genvar i;
    generate
        for (i = 0; i<INPUT_LANE_NUM; i=i+1) begin : split_loop
            assign split_lanes[i] = processed_msg[i*LANE_SIZE +: LANE_SIZE];
        end
    endgenerate

    // Step 3: Find the corresponding lanes and XOR into result
    logic [BYTE_DIV_32_WIDTH-1:0] block_beats_absorbed;
    assign block_beats_absorbed = bytes_absorbed_i/INPUT_BYTES_NUM;
    logic [4:0] rate_lane_limit;
    assign rate_lane_limit = rate_i[RATE_WIDTH-1:6]; // rate_i / 64

    always_comb begin
        // Default
        state_array_o = state_array_i;

        // Determine the starting linear lane index (0, 32, 64, 96, ...)
        // Logic: bytes / 8 bytes_per_lane
        int start_lane_idx;
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
            if (current_lane_idx < rate_lane_limit && current_lane_idx < MAX_POSSIBLE_LANES) begin
                state_array_o[x][y] = state_array_i[x][y] ^ split_lanes[i];
            end
        end
    end

endmodule
