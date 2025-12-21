/*
 * Module Name: chi_step
 * Author: Kiet Le
 * Description: The χ (chi) step mapping is the non-linear transformation step.
 *              Based off of FIPS202 Section 3.2.4
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module chi_step (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] chi_step_1;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] chi_step_2;

    // Compute chi step: nonlinear transformation across each row
    // Formula: A′[x,y]=A[x,y]⊕((¬A[(x+1)mod5,y])∧A[(x+2)mod5,y])
    always_comb begin
        // Step 1: AND of inverted next lane with lane after next
        for (int y = 0; y<COL_SIZE; y = y + 1) begin
            for (int x = 0; x<ROW_SIZE; x = x + 1) begin
                automatic int XP1 = (x+1) % 5;
                automatic int XP2 = (x+2) % 5;
                chi_step_1[x][y] = ~state_array_i[XP1][y] & state_array_i[XP2][y];
            end
        end
        // Step 2: XOR original lane with result of step 1
        for (int y = 0; y<COL_SIZE; y = y + 1) begin
            for (int x = 0; x<ROW_SIZE; x = x + 1) begin
                chi_step_2[x][y] = state_array_i[x][y] ^ chi_step_1[x][y];
            end
        end
    end

    assign state_array_o = chi_step_2;
endmodule
