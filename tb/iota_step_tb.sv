// ==========================================================
// Testbench for Keccak Iota Step
// Author: Kiet Le
// ==========================================================
`timescale 1ns/1ps

import keccak_pkg::*;

module iota_step_tb();

    // DUT signals
    logic [LANE_SIZE-1:0] lane00_in;
    logic [ROUND_INDEX_SIZE-1:0] i_r;
    logic [LANE_SIZE-1:0] lane00_out;

    // Instantiate DUT
    iota_step dut (
        .lane00_in(lane00_in),
        .i_r(i_r),
        .lane00_out(lane00_out)
    );

    // ==========================================================
    // Task to display the result
    // ==========================================================
    task automatic print_result(
        input int round_idx,
        input logic [LANE_SIZE-1:0] lane_in,
        input logic [LANE_SIZE-1:0] lane_out,
        input logic [LANE_SIZE-1:0] expected_rc
    );
        $display("===============================================");
        $display(" Round %0d | Input Lane (0,0): 0x%016h", round_idx, lane_in);
        $display(" Expected RC[%0d] = 0x%016h", round_idx, expected_rc);
        $display(" Lane (0,0) After IOTA Step: 0x%016h", lane_out);
        $display(" Expected XOR Result       : 0x%016h", lane_in ^ expected_rc);
        if (lane_out === (lane_in ^ expected_rc))
            $display("PASS: Iota output matches expected result\n");
        else
            $display("FAIL: Iota output mismatch\n");
    endtask

    // ==========================================================
    // Main Test Procedure
    // ==========================================================
    initial begin
        // Precomputed expected round constants
        // RC[0] = 0x0000000000000001
        // RC[1] = 0x0000000000008082
        // RC[23] = 0x8000000080008008
        logic [LANE_SIZE-1:0] RCs [MAX_ROUNDS] = '{
            64'h0000000000000001, 64'h0000000000008082, 64'h800000000000808A,
            64'h8000000080008000, 64'h000000000000808B, 64'h0000000080000001,
            64'h8000000080008081, 64'h8000000000008009, 64'h000000000000008A,
            64'h0000000000000088, 64'h0000000080008009, 64'h000000008000000A,
            64'h000000008000808B, 64'h800000000000008B, 64'h8000000000008089,
            64'h8000000000008003, 64'h8000000000008002, 64'h8000000000000080,
            64'h000000000000800A, 64'h800000008000000A, 64'h8000000080008081,
            64'h8000000000008080, 64'h0000000080000001, 64'h8000000080008008
        };

        // ================================
        // Test 1: All-zero lane, Round 0
        // ================================
        lane00_in = 64'h0000000000000000;
        i_r = 0;
        #1;
        print_result(i_r, lane00_in, lane00_out, RCs[i_r]);

        // ================================
        // Test 2: All-zero lane, Round 1
        // ================================
        lane00_in = 64'h0000000000000000;
        i_r = 1;
        #1;
        print_result(i_r, lane00_in, lane00_out, RCs[i_r]);

        // ================================
        // Test 3: All-zero lane, Round 23
        // ================================
        lane00_in = 64'h0000000000000000;
        i_r = 23;
        #1;
        print_result(i_r, lane00_in, lane00_out, RCs[i_r]);

        // ================================
        // Test 4: Non-zero lane (A pattern), Round 1
        // ================================
        lane00_in = 64'hAAAAAAAAAAAAAAAA;
        i_r = 1;
        #1;
        print_result(i_r, lane00_in, lane00_out, RCs[i_r]);

        $finish;
    end

endmodule
