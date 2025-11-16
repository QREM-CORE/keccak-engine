/*
 * Module Name: iota_step
 * Author: Kiet Le
 * Description: - ι (iota) step mapping is responsible for introducing round-dependent
 *                constants into the state to break symmetry between rounds.
 *              - Based on FIPS202 Section 3.2.5
 *              - We only input, modify, and output the (0, 0) 64-bit lane
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module iota_step (
    input  logic [LANE_SIZE-1:0]        lane00_i,       // Only inputting the (0, 0) lane (64 bits)
    input  logic [ROUND_INDEX_SIZE-1:0] round_index_i,  // Current round index (0-23)
    output logic [LANE_SIZE-1:0]        lane00_o        // (0,0) lane after XOR with round constant
);
    /* ============================================================
     * Step 1: Get Round Constant using input Round Index
     * ============================================================
     *
     * A keccak permutation has 24 rounds, so we have 24 different round constants.
     * The 64-bit round constant only has 7 possible non-zero bits at index positions:
     * (0, 1, 3, 7, 15, 31, 63) == 2^j - 1 for j=0..6
     * So we will only store the 7 bits that can be non-zero.
     *
     * The following array is as such:
     *  - Each row corresponds to each round 0..23
     *  - Each column corresponds to one of the 7 bit positions
     */
    localparam logic ROUNDCONSTANTS [MAX_ROUNDS][L_SIZE] = '{
       //  Bit-0    Bit-1    Bit-3    Bit-7    Bit-15    Bit 31    Bit-63
        '{ 1,       0,       0,       0,       0,        0,        0      }, // Round 0
        '{ 0,       1,       0,       1,       1,        0,        0      }, // Round 1
        '{ 0,       1,       1,       1,       1,        0,        1      }, // Round 2
        '{ 0,       0,       0,       0,       1,        1,        1      }, // Round 3
        '{ 1,       1,       1,       1,       1,        0,        0      }, // Round 4
        '{ 1,       0,       0,       0,       0,        1,        0      }, // Round 5
        '{ 1,       0,       0,       1,       1,        1,        1      }, // Round 6
        '{ 1,       0,       1,       0,       1,        0,        1      }, // Round 7
        '{ 0,       1,       1,       1,       0,        0,        0      }, // Round 8
        '{ 0,       0,       1,       1,       0,        0,        0      }, // Round 9
        '{ 1,       0,       1,       0,       1,        1,        0      }, // Round 10
        '{ 0,       1,       1,       0,       0,        1,        0      }, // Round 11
        '{ 1,       1,       1,       1,       1,        1,        0      }, // Round 12
        '{ 1,       1,       1,       1,       0,        0,        1      }, // Round 13
        '{ 1,       0,       1,       1,       1,        0,        1      }, // Round 14
        '{ 1,       1,       0,       0,       1,        0,        1      }, // Round 15
        '{ 0,       1,       0,       0,       1,        0,        1      }, // Round 16
        '{ 0,       0,       0,       1,       0,        0,        1      }, // Round 17
        '{ 0,       1,       1,       0,       1,        0,        0      }, // Round 18
        '{ 0,       1,       1,       0,       0,        1,        1      }, // Round 19
        '{ 1,       0,       0,       1,       1,        1,        1      }, // Round 20
        '{ 0,       0,       0,       1,       1,        0,        1      }, // Round 21
        '{ 1,       0,       0,       0,       0,        1,        0      }, // Round 22
        '{ 0,       0,       1,       0,       1,        1,        1      }  // Round 23
    };

    // Bit position mapping: 2^j - 1 for j = 0..6
    localparam int BITMAPPING [L_SIZE] = '{0, 1, 3, 7, 15, 31, 63};

    // ============================================================
    // Step 2: XOR corresponding round constants into lane (0,0)
    // ============================================================
    always_comb begin
        lane00_o = lane00_i; // Default assignment to avoid latches

        // Iterate through the 7 pre-defined bit positions for this round
        for (int j = 0; j<L_SIZE; j=j+1) begin
                lane00_o[BITMAPPING[j]] = lane00_i[BITMAPPING[j]] ^ ROUNDCONSTANTS[i_r][j];
        end
    end

endmodule
