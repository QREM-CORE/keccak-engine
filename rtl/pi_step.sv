/*
 * Module Name: pi_step
 * Author: Kiet Le
 * Description:
 * - Implements the π (Pi) step mapping, which permutes the positions of the
 * 25 lanes within the State Array.
 * - Logic: Shifts lanes based on the arithmetic formula:
 * A'[x, y] = A[(x + 3y) mod 5, x]
 * - Implementation: This module contains NO logic gates. It is implemented
 * entirely via wire routing (hardwired permutation), consuming zero
 * combinational area on FPGAs/ASICs.
 * - Reference: FIPS 202 Section 3.2.3
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module pi_step (
    input   wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    output  wire [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
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

`default_nettype wire
