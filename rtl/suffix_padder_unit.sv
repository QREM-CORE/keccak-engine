/*
 * Module Name: suffix_padder_unit
 * Author: Kiet Le
 * Description:
 * - Implements the FIPS 202 '10*1' padding rule combined with the Domain Separation Suffix.
 * - This single-cycle module applies the padding in two parts:
 * 1. HEAD: XORs the Suffix (which includes the starting '1' pad bit) at the byte
 * offset immediately following the message end.
 * 2. TAIL: XORs the final '1' bit (0x80) at the very end of the Rate block.
 * - Supports dynamic Rates (SHA3/SHAKE) by calculating the Tail position at runtime.
 * - Robustly handles the "Merged" edge case where the message ends in the final
 * byte of the block (Head == Tail), applying both XORs to the same lane correctly.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module suffix_padder_unit (
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    input   wire  [RATE_WIDTH-1:0]        rate_i,
    input   wire  [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_i,
    input   wire  [SUFFIX_WIDTH-1:0]      suffix_i,       // e.g., 0x06 or 0x1F

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // ==========================================================
    // 1. CALCULATE COORDINATES
    // ==========================================================

    // HEAD: Where the message ended
    int head_lane_idx;
    int head_byte_offset;
    assign head_lane_idx    = int'(bytes_absorbed_i >> 3);    // / 8
    assign head_byte_offset = int'(bytes_absorbed_i[2:0]);    // % 8

    // TAIL: The very last byte of the Rate block
    // Note: For all standard Keccak rates, the rate is a multiple of 64 bits.
    // Therefore, the last byte is ALWAYS at Byte Offset 7 (MSB) of the last lane.
    int tail_lane_idx;
    assign tail_lane_idx    = int'((rate_i >> 6) - 1); // (rate_bits / 64) - 1

    // ==========================================================
    // 2. CONSTRUCT THE VALUES TO XOR
    // ==========================================================
    logic [63:0] head_pad_val;
    logic [63:0] tail_pad_val;

    // Shift suffix to correct byte position
    assign head_pad_val = 64'(suffix_i) << (head_byte_offset * 8);

    // Tail is always 0x80 at the top byte (Little Endian)
    assign tail_pad_val = 64'h8000_0000_0000_0000;

    // ==========================================================
    // 3. APPLY THE PADDING
    // ==========================================================
    always_comb begin
        // Default
        state_array_o = state_array_i;

        for (int i = 0; i < 25; i++) begin
            int x, y;
            x = i % 5;
            y = i / 5;

            // Apply HEAD (Suffix)
            if (i == head_lane_idx) begin
                state_array_o[x][y] = state_array_o[x][y] ^ head_pad_val;
            end

            // Apply TAIL (0x80)
            // Note: We use state_o on the RHS to accumulate changes.
            // This handles the "Merged" case where i == head == tail.
            if (i == tail_lane_idx) begin
                state_array_o[x][y] = state_array_o[x][y] ^ tail_pad_val;
            end
        end
    end

endmodule

`default_nettype wire
