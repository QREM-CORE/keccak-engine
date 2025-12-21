/*
 * Module Name: pi_step
 * Author: Kiet Le
 * Description: The effect of π is to rearrange the positions of the lanes.
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module pi_step (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] permuted;

    genvar x,y;
    generate
        for (x=0; x<ROW_SIZE; x=x+1) begin : g_pi_x_col
            for (y=0; y<COL_SIZE; y=y+1) begin : g_rho_y_row
                // Transformation as specified by FIPS202 3.2.3
                localparam int SRCX = (x + 3*y) % 5;
                localparam int SRCY = x;
                assign permuted[x][y] = state_array_i[SRCX][SRCY];
            end
        end
    endgenerate

    assign state_array_o = permuted;

endmodule
