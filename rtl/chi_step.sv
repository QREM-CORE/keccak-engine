/*
 * Module Name: chi_step
 * Author: Kiet Le
 * Description: The χ (chi) step mapping is the non-linear transformation step.
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module chi_step (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_in,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_out
);
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] chi_step_1;
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] chi_step_2;

    always_comb begin
        // 1. AND Step
        for (int y = 0; y<COL_SIZE; y = y + 1) begin
            for (int x = 0; x<ROW_SIZE; x = x + 1) begin
                int XP1 = (x+1) % 5;
                int XP2 = (x+2) % 5;
                chi_step_1[x][y] = ~state_array_in[XP1][y] & state_array_in[XP2][y];
            end
        end
        // 2. XOR Step
        for (int y = 0; y<COL_SIZE; y = y + 1) begin
            for (int x = 0; x<ROW_SIZE; x = x + 1) begin
                chi_step_2[x][y] = state_array_in[x][y] ^ chi_step_1[x][y];
            end
        end
    end

    assign state_array_out = chi_step_2;
endmodule
