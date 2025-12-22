// =========================================================================
// Keccak Core Testbench - Reusable Verification Framework
// Supports: SHA3-256, SHA3-512, SHAKE128, SHAKE256
// Context: DWIDTH=256, Little Endian Byte Packing
// =========================================================================
`timescale 1ns/1ps

import keccak_pkg::*;

module keccak_core_tb;

    // =====================================================================
    // 1. TB Configuration & Signals
    // =====================================================================
    localparam CLK_PERIOD = 10;

    // Derived from your Package
    // DWIDTH is 256 bits (32 Bytes)
    localparam int BYTES_PER_BEAT = DWIDTH / 8;

    logic clk;
    logic rst;

    // DUT Control
    logic                      start_i;
    keccak_mode                keccak_mode_i; // Use Enum from Pkg
    logic                      stop_i;

    // AXI4-Stream Sink (Input to Core)
    logic [DWIDTH-1:0]         t_data_i;
    logic                      t_valid_i;
    logic                      t_last_i;
    logic [KEEP_WIDTH-1:0]     t_keep_i;
    logic                      t_ready_o;

    // AXI4-Stream Source (Output from Core)
    logic [MAX_OUTPUT_DWIDTH-1:0]   t_data_o;
    logic                           t_valid_o;
    logic                           t_last_o;
    logic [MAX_OUTPUT_DWIDTH/8-1:0] t_keep_o;
    logic                           t_ready_i;

    // Test Vector Structure
    typedef struct {
        string      name;
        keccak_mode mode;            // Enum: SHA3_256, etc.
        string      msg_hex_str;     // Input Message (e.g., "b1ca...")
        string      exp_md_hex_str;  // Expected Hash
        int         output_len_bits; // Length of output to check
    } test_vector_t;

    test_vector_t vectors[$];

    // =====================================================================
    // 2. DUT Instantiation
    // =====================================================================
    keccak_core dut (
        .clk            (clk),
        .rst            (rst),
        .start_i        (start_i),
        .keccak_mode_i  (keccak_mode_i), // Passes Enum directly
        .stop_i         (stop_i),

        // Sink
        .t_data_i       (t_data_i),
        .t_valid_i      (t_valid_i),
        .t_last_i       (t_last_i),
        .t_keep_i       (t_keep_i),
        .t_ready_o      (t_ready_o),

        // Source
        .t_data_o       (t_data_o),
        .t_valid_o      (t_valid_o),
        .t_last_o       (t_last_o),
        .t_keep_o       (t_keep_o),
        .t_ready_i      (t_ready_i)
    );

    // =====================================================================
    // 3. Clock & Reset
    // =====================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    task automatic reset_dut();
        rst = 1;
        start_i = 0;
        stop_i = 0;
        t_valid_i = 0;
        t_last_i = 0;
        t_keep_i = 0;
        t_data_i = 0;
        t_ready_i = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
    endtask

    // =====================================================================
    // 4. Helper Functions: Hex String <-> Byte Array
    // =====================================================================

    // Helper: Char to 4-bit val
    function automatic logic [3:0] hex_char_to_val(byte c);
        if (c >= "0" && c <= "9") return c - "0";
        if (c >= "a" && c <= "f") return c - "a" + 10;
        if (c >= "A" && c <= "F") return c - "A" + 10;
        return 0;
    endfunction

    // Convert string "b1ca" -> dynamic array {0xb1, 0xca}
    function automatic void str_to_byte_array(input string s, output logic [7:0] b_arr[]);
        int len = s.len();
        int byte_len = len / 2; // Assuming even length strings
        b_arr = new[byte_len];

        for (int i = 0; i < byte_len; i++) begin
            b_arr[i] = {hex_char_to_val(s[i*2]), hex_char_to_val(s[i*2+1])};
        end
    endfunction

    // =====================================================================
    // 5. Driver Task: Drive Message
    // =====================================================================
    task automatic drive_msg(input string msg_str);
        logic [7:0] msg_bytes[];
        int total_bytes;
        int sent_bytes = 0;
        int k;

        // Convert string to bytes
        str_to_byte_array(msg_str, msg_bytes);
        total_bytes = msg_bytes.size();

        // Handle empty message case (Len=0)
        if (total_bytes == 0) begin
            // Depending on protocol, might need to send one transaction with keep=0 and last=1
            // Or just rely on padding in core. Assuming standard AXI behavior:
            @(posedge clk);
            while (!t_ready_o) @(posedge clk);
            t_valid_i <= 1;
            t_last_i  <= 1;
            t_keep_i  <= '0;
            t_data_i  <= '0;
            @(posedge clk);
            t_valid_i <= 0;
            t_last_i  <= 0;
            return;
        end

        // Loop until all bytes sent
        while (sent_bytes < total_bytes) begin

            // 1. Wait for the clock edge
            @(posedge clk);

            // 2. NOW check signals.
            // If valid is low (we are starting) OR ready is high (RTL accepted prev data)
            // Note: Since we are at the edge, we sample the pre-update value of ready
            if (!t_valid_i || t_ready_o) begin

                // Drive the NEW data using Non-Blocking Assignments (<=).
                // Updates happen at the end of the time step (clean waveform).
                t_valid_i <= 1;
                t_data_i  <= '0;
                t_keep_i  <= '0;
                t_last_i  <= 0;

                // Pack up to 32 bytes (BYTES_PER_BEAT) into t_data_i
                // FIPS Order: Msg Byte 0 -> t_data_i[7:0]
                for (k = 0; k < BYTES_PER_BEAT; k++) begin
                    if ((sent_bytes + k) < total_bytes) begin
                        t_data_i[k*8 +: 8] <= msg_bytes[sent_bytes + k];
                        t_keep_i[k]        <= 1'b1;
                    end
                end

                sent_bytes += BYTES_PER_BEAT;

                // Assert T_LAST if this is the final chunk
                if (sent_bytes >= total_bytes) begin
                    t_last_i <= 1'b1;
                end

            end
            // If ready was low (Busy), we do nothing.
            // The loop repeats, waits for next @(posedge clk), and checks ready again.
        end

        // Cleanup
        @(posedge clk);
        while (!t_ready_o) @(posedge clk); // Wait for final handshake if pending
        t_valid_i <= 0;
        t_last_i  <= 0;
        t_keep_i  <= 0;
    endtask

    // =====================================================================
    // 6. Monitor Task: Check Response
    // =====================================================================
    /**
     * Reconstructs the hash from the AXI4-Stream Source interface,
     * compares it against the NIST expected vector, and logs the result.
     */
    task automatic check_response(
        input string      test_name,       // Description for the log
        input string      exp_hex,         // NIST expected MD (hex string)
        input int         out_bits,        // Number of bits to collect
        input keccak_mode mode             // Current mode (SHA3 vs SHAKE)
    );
        logic [7:0] collected_bytes[$];    // Queue to store byte-by-byte result
        logic [MAX_OUTPUT_DWIDTH-1:0] current_word;
        logic [MAX_OUTPUT_DWIDTH/8-1:0] current_keep;
        int bytes_needed;
        int i;
        string res_str = "";               // Reconstructed result string
        bit is_shake;

        // Determine if we are in XOF (Extendable Output) mode
        is_shake = (mode == SHAKE128 || mode == SHAKE256);
        bytes_needed = out_bits / 8;

        // Signal to the DUT that the TB is ready to accept data
        t_ready_i = 1;

        $display("[%s] Monitor: Waiting for %0d bytes of output...", test_name, bytes_needed);

        // --- Data Collection Loop ---
        forever begin
            @(posedge clk);

            // Handshake check (Valid from DUT, Ready from TB)
            if (t_valid_o && t_ready_i) begin
                current_word = t_data_o;
                current_keep = t_keep_o;

                // Extract only the bytes marked as valid by t_keep
                // FIPS 202: The first byte of the hash is at t_data_o[7:0]
                for (i = 0; i < (MAX_OUTPUT_DWIDTH/8); i++) begin
                    if (current_keep[i]) begin
                        collected_bytes.push_back(current_word[i*8 +: 8]);
                    end
                end

                // --- Termination Logic ---

                // For SHAKE: The core will squeeze forever until we tell it to stop.
                // We stop once we've collected the specific amount requested by the test.
                if (is_shake && collected_bytes.size() >= bytes_needed) begin
                    stop_i = 1;      // Pulse stop to reset the FSM
                    @(posedge clk);
                    stop_i = 0;
                    break;
                end

                // For SHA3: The core has a fixed length and will assert t_last
                // once the final chunk of the digest is driven.
                if (!is_shake && t_last_o) begin
                    break;
                end
            end
        end

        // De-assert ready after loop completion
        t_ready_i = 0;

        // --- Result Reconstruction ---
        // Converts the queue of bytes into a single hex string for comparison.
        for (i = 0; i < bytes_needed; i++) begin
            if (i < collected_bytes.size())
                res_str = {res_str, $sformatf("%02x", collected_bytes[i])};
            else
                res_str = {res_str, "XX"}; // Marker for underflow (missing data)
        end

        // --- Logging & Comparison ---
        if (res_str.tolower() == exp_hex.tolower()) begin
            $display("    [PASS] %s", test_name);
            $display("    MD: %s", res_str.tolower());
        end else begin
            $error("    [FAIL] %s", test_name);
            $display("    Expected: %s", exp_hex.tolower());
            $display("    Got:      %s", res_str.tolower());
        end
    endtask

    // =====================================================================
    // 7. Main Test Execution
    // =====================================================================
    task automatic run_test(test_vector_t tv);
        $display("----------------------------------------------------------");
        $display("STARTING: %s", tv.name);

        reset_dut();

        fork
            begin
                // Stimulus Thread
                @(posedge clk);
                start_i = 1;
                keccak_mode_i = tv.mode;
                @(posedge clk);
                start_i = 0;

                drive_msg(tv.msg_hex_str);
            end
            begin
                // Monitor Thread
                check_response(tv.name, tv.exp_md_hex_str, tv.output_len_bits, tv.mode);
            end
        join

        #(CLK_PERIOD * 5);
    endtask

    initial begin
        test_vector_t tv;

        // =====================================================================
        // 1. SHA3-256 (Rate = 1088 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHA3-256 Empty"; tv.mode = SHA3_256; tv.msg_hex_str = "";
        tv.exp_md_hex_str = "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Short Message (Single beat)
        tv.name = "SHA3-256 Short"; tv.mode = SHA3_256; tv.msg_hex_str = "616263"; // "abc"
        tv.exp_md_hex_str = "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Full Rate Message (Spans entire block i.e., 1088 bits)
        tv.name = "SHA3-256 Full Rate"; tv.mode = SHA3_256;
        tv.msg_hex_str = "56ea14d7fcb0db748ff649aaa5d0afdc2357528a9aad6076d73b2805b53d89e73681abfad26bee6c0f3d20215295f354f538ae80990d2281be6de0f6919aa9eb048c26b524f4d91ca87b54c0c54aa9b54ad02171e8bf31e8d158a9f586e92ffce994ecce9a5185cc80364d50a6f7b94849a914242fcb73f33a86ecc83c3403630d20650ddb8cd9c4";
        tv.exp_md_hex_str = "4beae3515ba35ec8cbd1d94567e22b0d7809c466abfbafe9610349597ba15b45";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Long Message (Spans multiple blocks/permutations)
        tv.name = "SHA3-256 Long"; tv.mode = SHA3_256;
        tv.msg_hex_str = "b1caa396771a09a1db9bc20543e988e359d47c2a616417bbca1b62cb02796a888fc6eeff5c0b5c3d5062fcb4256f6ae1782f492c1cf03610b4a1fb7b814c057878e1190b9835425c7a4a0e182ad1f91535ed2a35033a5d8c670e21c575ff43c194a58a82d4a1a44881dd61f9f8161fc6b998860cbe4975780be93b6f87980bad0a99aa2cb7556b478ca35d1f3746c33e2bb7c47af426641cc7bbb3425e2144820345e1d0ea5b7da2c3236a52906acdc3b4d34e474dd714c0c40bf006a3a1d889a632983814bbc4a14fe5f159aa89249e7c738b3b73666bac2a615a83fd21ae0a1ce7352ade7b278b587158fd2fabb217aa1fe31d0bda53272045598015a8ae4d8cec226fefa58daa05500906c4d85e7567";
        tv.exp_md_hex_str = "cb5648a1d61c6c5bdacd96f81c9591debc3950dcf658145b8d996570ba881a05";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // =====================================================================
        // 2. SHA3-512 (Rate = 576 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHA3-512 Empty"; tv.mode = SHA3_512; tv.msg_hex_str = "";
        tv.exp_md_hex_str = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // Short Message
        tv.name = "SHA3-512 Short"; tv.mode = SHA3_512;
        tv.msg_hex_str = "54746a7ba28b5f263d2496bd0080d83520cd2dc503";
        tv.exp_md_hex_str = "d77048df60e20d03d336bfa634bc9931c2d3c1e1065d3a07f14ae01a085fe7e7fe6a89dc4c7880f1038938aa8fcd99d2a782d1bbe5eec790858173c7830c87a2";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // Long Message
        tv.name = "SHA3-512 Long"; tv.mode = SHA3_512;
        tv.msg_hex_str = "22e1df25c30d6e7806cae35cd4317e5f94db028741a76838bfb7d5576fbccab001749a95897122c8d51bb49cfef854563e2b27d9013b28833f161d520856ca4b61c2641c4e184800300aede3518617c7be3a4e6655588f181e9641f8df7a6a42ead423003a8c4ae6be9d767af5623078bb116074638505c10540299219b0155f45b1c18a74548e4328de37a911140531deb6434c534af2449c1abe67e18030681a61240225f87ede15d519b7ce2500bccf33e1364e2fbe6a8a2fe6c15d73242610ed36b0740080812e8902ee531c88e0359020797cbdd1fb78848ae6b5105961d05cdddb8af5fef21b02db94c9810464b8d3ea5f047b94bf0d23931f12df37e102b603cd8e5f5ffa83488df257ddde110106262e0ef16d7ef213e7b49c69276d4d048f";
        tv.exp_md_hex_str = "a6375ff04af0a18fb4c8175f671181b4cf79653a3d70847c6d99694b3f5d41601f1dbef809675c63cac4ec83153b1c78131a7b61024ce36244f320ab8740cb7e";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // =====================================================================
        // 3. SHAKE128 (XOF - Rate = 1344 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHAKE128 Empty"; tv.mode = SHAKE128; tv.msg_hex_str = "";
        tv.exp_md_hex_str = "7f9c2ba4e88f827d616045507605853e";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // Short Message
        tv.name = "SHAKE128 Short"; tv.mode = SHAKE128;
        tv.msg_hex_str = "84f6cb3dc77b9bf856caf54e";
        tv.exp_md_hex_str = "56538d52b26f967bb9405e0f54fdf6e2";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // Long Message
        tv.name = "SHAKE128 Long"; tv.mode = SHAKE128;
        tv.msg_hex_str = "a6fe00064257aa318b621c5eb311d32bb8004c2fa1a969d205d71762cc5d2e633907992629d1b69d9557ff6d5e8deb454ab00f6e497c89a4fea09e257a6fa2074bd818ceb5981b3e3faefd6e720f2d1edd9c5e4a5c51e5009abf636ed5bca53fe159c8287014a1bd904f5c8a7501625f79ac81eb618f478ce21cae6664acffb30572f059e1ad0fc2912264e8f1ca52af26c8bf78e09d75f3dd9fc734afa8770abe0bd78c90cc2ff448105fb16dd2c5b7edd8611a62e537db9331f5023e16d6ec150cc6e706d7c7fcbfff930c7281831fd5c4aff86ece57ed0db882f59a5fe403105d0592ca38a081fed84922873f538ee774f13b8cc09bd0521db4374aec69f4bae6dcb66455822c0b84c91a3474ffac2ad06f0a4423cd2c6a49d4f0d6242d6a1890937b5d9835a5f0ea5b1d01884d22a6c1718e1f60b3ab5e232947c76ef70b344171083c688093b5f1475377e3069863";
        tv.exp_md_hex_str = "3109d9472ca436e805c6b3db2251a9bc";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // =====================================================================
        // 4. SHAKE256 (XOF - Rate = 1088 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHAKE256 Empty"; tv.mode = SHAKE256; tv.msg_hex_str = "";
        tv.exp_md_hex_str = "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Short Message
        tv.name = "SHAKE256 Short"; tv.mode = SHAKE256;
        tv.msg_hex_str = "765db6ab3af389b8c775c8eb99fe72";
        tv.exp_md_hex_str = "ccb6564a655c94d714f80b9f8de9e2610c4478778eac1b9256237dbf90e50581";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Long Message
        tv.name = "SHAKE256 Long"; tv.mode = SHAKE256;
        tv.msg_hex_str = "dc5a100fa16df1583c79722a0d72833d3bf22c109b8889dbd35213c6bfce205813edae3242695cfd9f59b9a1c203c1b72ef1a5423147cb990b5316a85266675894e2644c3f9578cebe451a09e58c53788fe77a9e850943f8a275f830354b0593a762bac55e984db3e0661eca3cb83f67a6fb348e6177f7dee2df40c4322602f094953905681be3954fe44c4c902c8f6bba565a788b38f13411ba76ce0f9f6756a2a2687424c5435a51e62df7a8934b6e141f74c6ccf539e3782d22b5955d3baf1ab2cf7b5c3f74ec2f9447344e937957fd7f0bdfec56d5d25f61cde18c0986e244ecf780d6307e313117256948d4230ebb9ea62bb302cfe80d7dfebabc4a51d7687967ed5b416a139e974c005fff507a96";
        tv.exp_md_hex_str = "2bac5716803a9cda8f9e84365ab0a681327b5ba34fdedfb1c12e6e807f45284b";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Execute all
        foreach(vectors[i]) begin
            run_test(vectors[i]);
        end

        $display("==========================================================");
        $display("TEST SUITE COMPLETE");
        $display("==========================================================");
        $finish;
    end

endmodule
