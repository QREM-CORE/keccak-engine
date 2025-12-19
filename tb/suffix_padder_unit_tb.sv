// ==========================================================
// Testbench for Suffix Padder Unit
// Author: Kiet Le
// ==========================================================
`timescale 1ns/1ps

import keccak_pkg::*;

module suffix_padder_unit_tb ();

    // ==========================================================
    // Parameters & Constants
    // ==========================================================
    localparam RATE_SHA3_256 = 1088; // 136 Bytes (17 Lanes)
    localparam RATE_SHAKE128 = 1344; // 168 Bytes (21 Lanes)

    // Suffix Constants (Byte values)
    localparam logic [7:0] SUFFIX_SHA3  = 8'h06; // 01...
    localparam logic [7:0] SUFFIX_SHAKE = 8'h1F; // 1111...

    // DUT Signals
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_i;
    logic [RATE_WIDTH-1:0]        rate_i;
    logic [BYTE_ABSORB_WIDTH-1:0] bytes_absorbed_i;
    logic [SUFFIX_WIDTH-1:0]      suffix_i;
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_o;

    // DUT Instance
    suffix_padder_unit dut (
        .state_array_i    (state_i),
        .rate_i           (rate_i),
        .bytes_absorbed_i (bytes_absorbed_i),
        .suffix_i         (suffix_i),
        .state_array_o    (state_o)
    );

    // ==========================================================
    // Helper Task: Print State (FIPS 202 Format)
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
        input logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] exp_state
    );
        int error_count = 0;
        int x, y;

        for (x = 0; x < ROW_SIZE; x++) begin
            for (y = 0; y < COL_SIZE; y++) begin
                if (state_o[x][y] !== exp_state[x][y]) begin
                    $error("[%s] FAIL: State mismatch at [x=%0d][y=%0d].\n\tExpected: 0x%016h\n\tGot:      0x%016h",
                           test_name, x, y, exp_state[x][y], state_o[x][y]);
                    error_count++;
                end
            end
        end

        if (error_count == 0) begin
            $display("[%s] PASS: All lanes match expected padding.", test_name);
        end
    endtask

    // ==========================================================
    // Main Test Procedure
    // ==========================================================
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] expected_state;

    initial begin
        $display("\n--- Starting Suffix Padder Testbench ---\n");

        // Initialize inputs
        state_i = '0;
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 0;
        suffix_i = SUFFIX_SHA3;
        #10;

        // ----------------------------------------------------------
        // TC1: SHA3-256 "Split" Case
        // Message ends at Byte 8 (Start of Lane 1).
        // Rate ends at Byte 135 (End of Lane 16).
        // ----------------------------------------------------------
        $display("TC1: SHA3-256 Split Case (Head and Tail separate)");
        state_i = '0;
        rate_i = RATE_SHA3_256; // 1088 bits
        bytes_absorbed_i = 8;   // Lane 1, Byte 0
        suffix_i = SUFFIX_SHA3; // 0x06

        expected_state = '0;

        // HEAD: Lane 1 (x=1, y=0). Byte Offset 0.
        // Value: 0x06 << 0 = 0x06...
        expected_state[1][0] = 64'h0000_0000_0000_0006;

        // TAIL: Lane 16 (x=1, y=3). Byte Offset 7.
        // Value: 0x80 << 56 = 0x80...
        expected_state[1][3] = 64'h8000_0000_0000_0000;

        #10;
        check_results("TC1", expected_state);
        print_state_fips(state_o);


        // ----------------------------------------------------------
        // TC2: SHA3-256 "Merged" Case (Critical Edge Case)
        // Message ends at Byte 135 (The very last byte of the rate).
        // Head and Tail must collide in the same byte.
        // ----------------------------------------------------------
        $display("\nTC2: SHA3-256 Merged Case (Head == Tail)");
        state_i = '0;
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 135; // The last byte (0 to 135 = 136 bytes)
        suffix_i = SUFFIX_SHA3; // 0x06

        expected_state = '0;

        // HEAD: Lane 16. Byte Offset 7. Val: 0x06 << 56
        // TAIL: Lane 16. Byte Offset 7. Val: 0x80 << 56
        // RESULT: (0x06 ^ 0x80) = 0x86 at MSB.
        expected_state[1][3] = 64'h8600_0000_0000_0000;

        #10;
        check_results("TC2", expected_state);
        print_state_fips(state_o);


        // ----------------------------------------------------------
        // TC3: SHAKE128 "Spill" Case
        // Bytes absorbed = 0 (Fresh block).
        // Suffix = 0x1F (SHAKE). Rate = 1344 (21 Lanes).
        // ----------------------------------------------------------
        $display("\nTC3: SHAKE128 Spill Case (Start of block)");
        state_i = '0;
        rate_i = RATE_SHAKE128;
        bytes_absorbed_i = 0;   // Lane 0, Byte 0
        suffix_i = SUFFIX_SHAKE; // 0x1F

        expected_state = '0;

        // HEAD: Lane 0. Byte Offset 0. Val: 0x1F
        expected_state[0][0] = 64'h0000_0000_0000_001F;

        // TAIL: Lane 20 (x=0, y=4). Byte Offset 7.
        expected_state[0][4] = 64'h8000_0000_0000_0000;

        #10;
        check_results("TC3", expected_state);
        print_state_fips(state_o);


        // ----------------------------------------------------------
        // TC4: Data Preservation Check
        // Ensure we XOR against existing data, not overwrite it.
        // ----------------------------------------------------------
        $display("\nTC4: Data Preservation (XOR Check)");

        // Fill state with all 1s
        state_i = {25{64'hFFFF_FFFF_FFFF_FFFF}};
        rate_i = RATE_SHA3_256;
        bytes_absorbed_i = 0;
        suffix_i = SUFFIX_SHA3; // 0x06

        // Expected: 
        // Lane 0: 0xFF...FF ^ 0x06 -> 0xFF...F9
        // Lane 16: 0xFF...FF ^ 0x80... -> 0x7F...FF
        // All others: 0xFF...FF
        expected_state = {25{64'hFFFF_FFFF_FFFF_FFFF}};
        expected_state[0][0] = 64'hFFFF_FFFF_FFFF_FFF9;
        expected_state[1][3] = 64'h7FFF_FFFF_FFFF_FFFF;

        #10;
        check_results("TC4", expected_state);
        print_state_fips(state_o);

        $display("\n--- Testbench Complete ---");
    end

endmodule
