/*
 * Module Name: iota_step
 * Author: Kiet Le
 * Description: - ι (iota) step mapping is responsible for introducing round-dependent
 *                constants into the state to break symmetry between rounds.
 *              - Based off of FIPS202 Section 3.2.5
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module iota_step (
    input   logic   [LANE_SIZE-1:0]         lane00_in,
    input   logic   [ROUND_INDEX_SIZE-1:0]  i_r, // Round Index 0-24

    output  logic   [LANE_SIZE-1:0]         lane00_out
);
    /* ============================================================
     * Step 1: Get Round Constant using input Round Index
     * ============================================================
     *
     * The 64 bit round index only has 7 possible non-zero bits at index positions:
     * (0, 1, 3, 7, 15, 31, 63) -> 2^j - 1 for j=0..6
     *
     * The following array is as such:
     *  - Each row corresponds to each round 0..23
     *  - Each column corresponds to one of the 7 bit positions
     */
    localparam logic RCs [MAX_ROUNDS][L_SIZE] = '{
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
    localparam int bit_mapping [L_SIZE] = '{0, 1, 3, 7, 15, 31, 63};

    // ============================================================
    // Step 2: XOR corresponding bits for lane (0,0)
    // ============================================================
    always_comb begin
        lane00_out = lane00_in; // default assignment
        for (int j = 0; j<L_SIZE; j=j+1) begin
                lane00_out[bit_mapping[j]] = lane00_in[bit_mapping[j]] ^ RCs[i_r][j];
        end
    end

endmodule
