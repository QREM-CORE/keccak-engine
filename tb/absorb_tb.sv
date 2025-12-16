// ==========================================================
// Testbench for Keccak Absorb Module
// ==========================================================
`timescale 1ns/1ps

import keccak_pkg::*;

module absorb_tb ();

    // ==========================================================
    // Parameters & Constants
    // ==========================================================
    localparam RATE_SHA3_256 = 1088; // 136 Bytes (17 Lanes)
    localparam RATE_SHA3_512 = 576;  // 72 Bytes  (9 Lanes)

    // DUT signals
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_in;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_out;

    logic [RATE_WIDTH-1:0]        rate_i;
    logic [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_i;
    logic [DWIDTH-1:0]            msg_i;
    logic [KEEP_WIDTH-1:0]        keep_i;
    logic [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_o;
    logic [CARRY_WIDTH-1:0]       carry_over_o;
    logic                         has_carry_over_o;
    logic [CARRY_KEEP_WIDTH-1:0]  carry_keep_o;

    // Instance
    absorb dut (
        .state_array_i      (state_in),
        .rate_i             (rate_i),
        .bytes_absorbed_i   (bytes_absorbed_i),
        .msg_i              (msg_i),
        .keep_i             (keep_i),
        .state_array_o      (state_out),
        .bytes_absorbed_o   (bytes_absorbed_o),
        .carry_over_o       (carry_over_o),
        .has_carry_over_o   (has_carry_over_o),
        .carry_keep_o       (carry_keep_o)
    );

    // ==========================================================
    // Helper Task: Print State (Provided by User)
    // ==========================================================
    task automatic print_state_fips(
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
        $display($sformatf("%s%s",  "     x=0                 x=1                 ",
                                    "x=2                 x=3                 x=4\n"));
    endtask

    // ==========================================================
    // Helper Task: Verify Expected Results
    // ==========================================================
    task automatic check_results(
        input string test_name,
        input int exp_bytes_abs,
        input logic exp_has_carry,
        input logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] exp_state_diff
        // exp_state_diff: Just pass the expected non-zero lane value for simple checks
    );
        if (bytes_absorbed_o !== exp_bytes_abs)
            $error("[%s] FAIL: Bytes Absorbed mismatch. Exp: %0d, Got: %0d", test_name, exp_bytes_abs, bytes_absorbed_o);
        else if (has_carry_over_o !== exp_has_carry)
            $error("[%s] FAIL: Carry mismatch. Exp: %0b, Got: %0b", test_name, exp_has_carry, has_carry_over_o);
        else
            $display("[%s] PASS: Bytes: %0d, Carry: %0b", test_name, bytes_absorbed_o, has_carry_over_o);
    endtask


    // ==========================================================
    // Main Test Procedure
    // ==========================================================
    initial begin
        $display("\n--- Starting Keccak Absorb Testbench ---\n");

        // Initialize
        state_in = '0;
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 0;
        msg_i = '0;
        keep_i = '0;
        #10;

        // ----------------------------------------------------------
        // TEST CASE 1: SHA3-256 Clean Start
        // Absorbing first 32 bytes into an empty state.
        // ----------------------------------------------------------
        $display("TC1: SHA3-256 Start (0 bytes absorbed)");
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 0;
        msg_i = {4{64'h1111_2222_3333_4444}}; // Fill 4 lanes with pattern
        keep_i = {32{1'b1}};                  // All 32 bytes valid

        #10;
        check_results("TC1", 32, 0, '0);
        // Visual check: Lanes (0,0), (1,0), (2,0), (3,0) should be filled.
        if (state_out[0][0] !== 64'h1111_2222_3333_4444) $error("TC1: Lane mapping incorrect!");
        print_state_fips(state_out);


        // ----------------------------------------------------------
        // TEST CASE 2: SHA3-256 Partial Masking
        // Absorbing 32 bytes, but keep_i only enables first 8 bytes (1 lane).
        // ----------------------------------------------------------
        $display("\nTC2: SHA3-256 Partial Mask (Only 8 bytes valid)");
        bytes_absorbed_i = 32; // Starting after previous block
        msg_i = {4{64'hDEAD_BEEF_DEAD_BEEF}};
        keep_i = { {24{1'b0}}, {8{1'b1}} }; // Top 24 bytes invalid, Bottom 8 valid

        #10;
        // Expected: 32 + 8 = 40 bytes absorbed.
        // Logic: Should fill Lane 4 (which is x=4, y=0) and ignore lanes 5,6,7.
        check_results("TC2", 40, 0, '0);

        if (state_out[4][0] !== 64'hDEAD_BEEF_DEAD_BEEF) $error("TC2: Lane 4 failed");
        if (state_out[0][1] !== 64'h0) $error("TC2: Lane 5 should be empty (masked out)!");
        print_state_fips(state_out);


        // ----------------------------------------------------------
        // TEST CASE 3: SHA3-256 "The Straddle" (Carry Over)
        // Rate = 136 bytes. We are at 128 bytes. We input 32 bytes.
        // Only 8 bytes fit. 24 bytes must carry over.
        // ----------------------------------------------------------
        $display("\nTC3: SHA3-256 Straddle Boundary (Trigger Carry Over)");
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 128; // 16 Lanes full (0-15). Next is Lane 16 (Last one).

        // Pattern: Bottom 64 bits (Lane 16) = AAAA...
        //          Top 192 bits (Carry)     = BBBB...
        msg_i = { {3{64'hBBBB_BBBB_BBBB_BBBB}}, 64'hAAAA_AAAA_AAAA_AAAA };
        keep_i = {32{1'b1}};

        #10;
        // Expected:
        // 1. bytes_absorbed_o should be 136 (Full Rate).
        // 2. has_carry_over_o should be 1.
        // 3. state_out should have Lane 16 (x=1, y=3) filled with AAAA...
        // 4. carry_over_o should contain BBBB...

        check_results("TC3", 136, 1, '0);

        if (state_out[1][3] !== 64'hAAAA_AAAA_AAAA_AAAA) $error("TC3: Lane 16 (Last Lane) not filled correctly");
        if (carry_over_o[63:0] !== 64'hBBBB_BBBB_BBBB_BBBB) $error("TC3: Carry over data incorrect");

        print_state_fips(state_out);


        // ----------------------------------------------------------
        // TEST CASE 4: SHA3-512 Mode (Smaller Rate)
        // Rate = 72 bytes (9 Lanes).
        // Let's ensure logic respects the smaller rate limit.
        // ----------------------------------------------------------
        $display("\nTC4: SHA3-512 Boundary Check");
        rate_i = RATE_SHA3_512;
        bytes_absorbed_i = 64; // 8 Lanes full. Lane 8 is the last one.
        msg_i = {4{64'hCCCC_CCCC_CCCC_CCCC}};
        keep_i = {32{1'b1}};

        #10;
        // Expected: Fits 1 lane (Lane 8). Carries 3 lanes.
        // Lane 8 is Index 8 -> x=3, y=1.

        check_results("TC4", 72, 1, '0); // 72 bytes = full rate

        if (state_out[3][1] !== 64'hCCCC_CCCC_CCCC_CCCC) $error("TC4: SHA3-512 Boundary Lane failed");
        // Ensure Lane 9 (Capacity for SHA3-512) was NOT written to
        if (state_out[4][1] !== 64'h0) $error("TC4: Wrote into Capacity! Logic failed rate check.");

        print_state_fips(state_out);

        // ----------------------------------------------------------
        // TEST CASE 5: Random/Misaligned input
        // Absorbing 5 bytes (partial lane)
        // ----------------------------------------------------------
        $display("\nTC5: Partial Lane (5 bytes)");
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 0;
        state_in = '0;
        msg_i = {216'h0, 40'hAA_BB_CC_DD_EE}; // 5 bytes
        keep_i = 32'b00000000_00000000_00000000_00011111; // Bottom 5 bits high

        #10;
        check_results("TC5", 5, 0, '0);
        // Lane 0 should contain 0x00...00AABBCCDDEE
        if (state_out[0][0] !== 64'h0000_00AA_BBCC_DDEE) $error("TC5: Partial lane mask failed");
        print_state_fips(state_out);

        // ----------------------------------------------------------
        // TEST CASE 6: SHAKE128 Max Rate Boundary
        // Rate = 1344 bits (168 bytes).
        // This is 21 Lanes (Indices 0 to 20).
        // We want to verify we can write to Lane 20 (x=0, y=4)
        // but NOT Lane 21 (x=1, y=4).
        // ----------------------------------------------------------
        $display("\nTC6: SHAKE128 Max Rate (Lane 20 valid, Lane 21 cap)");
        rate_i = 1344;
        bytes_absorbed_i = 160; // 20 Lanes full (Indices 0-19). Next is Lane 20.

        // Input 4 lanes.
        // Lane 0 of input -> Lane 20 of State (Should write)
        // Lane 1 of input -> Lane 21 of State (Should mask/ignore)
        msg_i = { {2{64'hBAD0_BAD0_BAD0_BAD0}}, 64'hCAFE_F00D_CAFE_F00D, 64'h9999_8888_7777_6666 };
        keep_i = {32{1'b1}};

        #10;

        // Expected:
        // 1. Fits 1 lane (Lane 20).
        // 2. Carries 3 lanes (Input Lanes 1, 2, 3).
        // 3. Bytes absorbed becomes 168 (Full Rate).
        check_results("TC6", 168, 1, '0);

        // Check Lane 20 (x=0, y=4) - The last valid lane for SHAKE128
        if (state_out[0][4] !== 64'h9999_8888_7777_6666)
            $error("TC6: SHAKE128 Last Lane (Lane 20) failed to write.");

        // Check Lane 21 (x=1, y=4) - The first Capacity lane
        if (state_out[1][4] !== 64'h0)
            $error("TC6: Wrote into Capacity (Lane 21)! Protection failed.");

        print_state_fips(state_out);


        // ----------------------------------------------------------
        // TEST CASE 7: SHAKE256 (Same as SHA3-256)
        // Rate = 1088 bits. Just a sanity check.
        // ----------------------------------------------------------
        $display("\nTC7: SHAKE256 (Sanity Check - Same rate as SHA3-256)");
        rate_i = 1088;
        bytes_absorbed_i = 0;
        msg_i = {4{64'h1234_5678_9ABC_DEF0}};
        keep_i = {32{1'b1}};

        #10;
        check_results("TC7", 32, 0, '0);
        if (state_out[0][0] !== 64'h1234_5678_9ABC_DEF0) $error("TC7: Write failed");

        $display("\n--- Testbench Complete ---");
    end

endmodule
