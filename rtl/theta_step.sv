/*
 * Module Name: theta_step
 * Author: Kiet Le
 * Description: Theta in Keccak is a diffusion step that mixes each bit with a parity of neighboring columns.
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module theta_step (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // Column Parity Wires (Algorithm 1: C matrix in FIPS202)
    wire [4:0][LANE_SIZE-1:0] C;

    // Deltas Wires (Algorithm 1: D matrix in FIPS202)
    wire [4:0][LANE_SIZE-1:0] D;

    // Get Parities of each column
    // - From FIPS202: C[x, z] = A[x, 0, z] ⊕ A[x, 1, z] ⊕ A[x, 2, z] ⊕ A[x, 3, z] ⊕ A[x, 4, z]
    // - 5x64 grid array (each entry is a parity of the corresponding column)
    genvar x;
    generate
        for (x = 0; x<ROW_SIZE; x = x + 1) begin : compute_C
            assign C[x] =       state_array_i[x][0] ^
                                state_array_i[x][1] ^
                                state_array_i[x][2] ^
                                state_array_i[x][3] ^
                                state_array_i[x][4];
        end
    endgenerate

    /* Calculate D[x] to mix neighboring column parities with rotation
     * - From FIPS202: D[x, z] = C[(x-1) mod 5, z] ⊕ C[(x+1) mod 5, (z – 1) mod w]
     * - For each column, compute a “delta” by XORing the parity of the previous ...
     *   column (mod 5) with a rotated parity of the next column.
     */
    generate
        for (x = 0; x<ROW_SIZE; x = x + 1) begin : compute_D
            // Efficient Way to implement the modulo in this case
            wire [2:0] xm1 = (x==0) ? 4 : x - 1; // x - 1 modulo 5
            wire [2:0] xp1 = (x==4) ? 0 : x + 1; // x + 1 modulo 5

            // C[x-1] XOR {Rotated C[x+1]}
            // Doing the XOR operation with each lane of the C array
            assign D[x] = C[xm1] ^ {C[xp1][LANE_SIZE-2:0], C[xp1][LANE_SIZE-1]};
        end
    endgenerate

    /*
     * Compute final state array for theta step
     * - From FIPS202: A′[x, y, z] = A[x, y, z] ⊕ D[x, z]
     * - XOR this delta into each bit of the column
     */
    genvar y;
    generate
        for (x = 0; x<ROW_SIZE; x = x + 1) begin
            for (y = 0; y<COL_SIZE; y = y + 1) begin
                assign state_array_o[x][y] = state_array_i[x][y] ^ D[x];
            end
        end
    endgenerate

endmodule
