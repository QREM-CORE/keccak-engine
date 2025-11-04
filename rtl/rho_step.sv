/*
 * Module Name: rho_step
 * Author: Kiet Le
 * Description: The effect of ρ is to rotate the bits of each lane by a length, called the offset,
 *              which depends on the fixed x and y coordinates of the lane.
 * NOTE: Purely combinational so far. Can be pipelined for higher clock speed if needed.
 */

import keccak_pkg::*;

module rho_step (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_in,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_out
);
    // Rotation Offsets of 64 bit lanes
    // Y=0 goes right to Y=4
    // X=0 goes down to X=4
    localparam int OFFSETS [0:4][0:4] = '{
        '{  0, 36,  3, 41, 18 },
        '{  1, 44, 10, 45,  2 },
        '{ 62,  6, 43, 15, 61 },
        '{ 28, 55, 25, 21, 56 },
        '{ 27, 20, 39,  8, 14 }
    };

    /*
     * Performs left rotation by 'shift' bits
     */
    function automatic [LANE_SIZE-1:0] left_rotate_lane (
        input [LANE_SIZE-1:0] lane_i,
        input int shift
    );
        // Use standard synthesizable bitwise shift and OR for rotation.
        // Left part: lane_i shifted left by 'shift' (high bits)
        // Right part: lane_i shifted right by (LANE_SIZE - shift) (wrapped-around bits)
        left_rotate_lane = (lane_i << shift) | (lane_i >> (LANE_SIZE - shift));
    endfunction

    // Shift every lane by preset offset amount
    genvar x,y;
    generate
        for (x=0; x<ROW_SIZE; x=x+1) begin
            for (y=0; y<COL_SIZE; y=y+1) begin
                assign state_array_out[x][y] = left_rotate_lane(state_array_in[x][y], OFFSETS[x][y]);
            end
        end
    endgenerate

endmodule
