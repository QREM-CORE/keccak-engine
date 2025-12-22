/*
 * Module Name: rho_step
 * Author: Kiet Le
 * Description:
 * - Implements the ρ (Rho) step mapping, responsible for intra-lane diffusion.
 * - Performs a circular bitwise left-rotation on each of the 25 lanes individually.
 * - The rotation offset is a fixed constant unique to each (x,y) coordinate,
 * defined by the Keccak algorithm's offset matrix.
 * - Hardware Note: Since the rotation amounts are compile-time constants,
 * synthesis tools implement this entirely via wire re-routing (zero logic gates),
 * making it extremely area-efficient.
 * - Reference: FIPS 202 Section 3.2.2
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module rho_step (
    input   wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    // Rotation Offsets of 64 bit lanes
    // Y=0 goes right to Y=4
    // X=0 goes down to X=4
    localparam int OFFSETS [ROW_SIZE][COL_SIZE] = '{
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
        input logic [LANE_SIZE-1:0] lane_i,
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
        for (x=0; x<ROW_SIZE; x=x+1) begin : g_rho_x_col
            for (y=0; y<COL_SIZE; y=y+1) begin : g_rho_y_row
                assign state_array_o[x][y] = left_rotate_lane(state_array_i[x][y],
                                                                OFFSETS[x][y]);
            end
        end
    endgenerate

endmodule

`default_nettype wire
