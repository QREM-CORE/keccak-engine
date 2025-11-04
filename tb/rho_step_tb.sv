// ==========================================================
// Testbench for Keccak Rho Step
// Author: Kiet Le
// ==========================================================
`timescale 1ns/1ps

import keccak_pkg::*;

module rho_step_tb();
    // DUT signals
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_in;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_out;

    // Instantiate DUT
    rho_step dut (
        .state_array_in(state_in),
        .state_array_out(state_out)
    );

    // ==========================================================
    // Task to print the Keccak state in FIPS-202 coordinate layout
    // ==========================================================
    task print_state_fips(
        input logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state
    );
        int y, x;
        $display("Keccak state (FIPS 202 coordinates):\n");
        for (y = COL_SIZE-1; y >= 0; y--) begin
            $write("y=%0d: ", y);
            for (x = 0; x < ROW_SIZE; x++) begin
                $write("0x%016h  ", state[x][y]);
            end
            $display("");
        end
        $display("     x=0                 x=1                 x=2                 x=3                 x=4\n");
    endtask

    // ==========================================================
    // Main Test Procedure
    // ==========================================================
    initial begin
        // -------------------------
        // Test 1: Single bit at (1,0)
        // -------------------------
        state_in = '0;
        state_in[1][0] = 64'h0000000000000001;

        #1; // wait for combinational propagation

        $display("==== Initial State (Single Bit) ====");
        print_state_fips(state_in);

        $display("==== After Rho Step ====");
        print_state_fips(state_out);

        // -------------------------
        // Test 2: All lanes set to 1
        // -------------------------
        state_in = '{default:64'h1};

        #1;

        $display("==== Initial State (All Ones) ====");
        print_state_fips(state_in);

        $display("==== After Rho Step ====");
        print_state_fips(state_out);

        $finish;
    end

endmodule
