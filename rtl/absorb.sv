import keccak_pkg::*;

// Compute state array after absorption
module absorb (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input   [RATE_WIDTH-1:0]    rate_i,
    input   [RATE_WIDTH-1:0]    bytes_absorbed_i,
    input   [DWIDTH-1:0]        msg_i,
    input   [KEEP_WIDTH-1:0]    keep_i

    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o,
    output  [RATE_WIDTH-1:0]        bytes_absorbed_o,
    output  [CARRY_WIDTH-1:0]       carry_over_o,
    output                          has_carry_over_o,
    output  [CARRY_KEEP_WIDTH-1:0]  carry_keep_o
);

    /* Need to XOR to correct portions of the data in.
     * bytes_absorbed_i should always be a multiple of 64 bits at least...
     * until the last read in, which can be any value of bytes.
     * This means we dont have to worry about writing into a state that is unaligned (multiple of 64 bits).
     */
endmodule
