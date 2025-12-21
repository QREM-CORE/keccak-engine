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
            t_valid_i = 1;
            t_last_i  = 1;
            t_keep_i  = '0;
            t_data_i  = '0;
            @(posedge clk);
            t_valid_i = 0;
            t_last_i  = 0;
            return;
        end

        // Drive Data in 256-bit chunks
        while (sent_bytes < total_bytes) begin
            // Wait for handshake opportunity
            if (!t_valid_i || t_ready_o) begin 
                @(posedge clk); // Move to next edge
                
                t_valid_i = 1;
                t_data_i  = '0;
                t_keep_i  = '0;
                t_last_i  = 0;

                // Pack up to 32 bytes (BYTES_PER_BEAT) into t_data_i
                // FIPS Order: Msg Byte 0 -> t_data_i[7:0]
                for (k = 0; k < BYTES_PER_BEAT; k++) begin
                    if ((sent_bytes + k) < total_bytes) begin
                        t_data_i[k*8 +: 8] = msg_bytes[sent_bytes + k];
                        t_keep_i[k]        = 1'b1;
                    end
                end

                sent_bytes += BYTES_PER_BEAT;

                // Assert T_LAST if this is the final chunk
                if (sent_bytes >= total_bytes) begin
                    t_last_i = 1'b1;
                end
            end else begin
                @(posedge clk); // Wait while valid is high but ready is low
            end
        end

        // Wait for final handshake to complete
        do begin
            @(posedge clk);
        end while (!(t_valid_i && t_ready_o));

        t_valid_i = 0;
        t_last_i  = 0;
        t_keep_i  = 0;
        t_data_i  = 0;
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

        // Long Message (Spans multiple blocks/permutations)
        tv.name = "SHA3-256 Long"; tv.mode = SHA3_256; 
        tv.msg_hex_str = "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"; 
        tv.exp_md_hex_str = "361427183617182283737206e2327a3c75d970341775f0a0558b29c97b861214";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // =====================================================================
        // 2. SHA3-512 (Rate = 576 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHA3-512 Empty"; tv.mode = SHA3_512; tv.msg_hex_str = ""; 
        tv.exp_md_hex_str = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // Short Message
        tv.name = "SHA3-512 Short"; tv.mode = SHA3_512; tv.msg_hex_str = "616263"; // "abc"
        tv.exp_md_hex_str = "b751850b1a57168a5693cd924b6c0512ea249927f9828c22423547657d92a46bd514a142abc2b8ce36105a07d1737e618899d630d603a110a30b5683938e55e5";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // Long Message
        tv.name = "SHA3-512 Long"; tv.mode = SHA3_512; 
        tv.msg_hex_str = "4d657373616765204c656e677468205465737420566563746f72207573696e6720534841332d3531322077697468206d756c7469706c6520626c6f636b73206f66206461746120746f20666f726365207065726d75746174696f6e73"; 
        tv.exp_md_hex_str = "13636778f941199341662973127814a799a7719601d36585108603612f0e03e913a8904e2231269992d527236521798e29a8a7281f9b3711833772221379ec86";
        tv.output_len_bits = 512; vectors.push_back(tv);

        // =====================================================================
        // 3. SHAKE128 (XOF - Rate = 1344 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHAKE128 Empty"; tv.mode = SHAKE128; tv.msg_hex_str = ""; 
        tv.exp_md_hex_str = "7f9c2ba4e88f827d616045507605853e";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // Short Message
        tv.name = "SHAKE128 Short"; tv.mode = SHAKE128; tv.msg_hex_str = "4c6173736f6e6465"; // "Lassonde"
        tv.exp_md_hex_str = "6e5760613a04297127e9970349b109e2";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // Long Message
        tv.name = "SHAKE128 Long"; tv.mode = SHAKE128; 
        tv.msg_hex_str = "5348414b4531323820697320616e20657874656e6461626c65206f75747075742066756e6374696f6e20746861742063616e2067656e657261746520616e20617262697472617279206c656e677468206f662064617461";
        tv.exp_md_hex_str = "a05a415b3e6c0c2a2977823e5907406c";
        tv.output_len_bits = 128; vectors.push_back(tv);

        // =====================================================================
        // 4. SHAKE256 (XOF - Rate = 1088 bits)
        // =====================================================================

        // Empty Message
        tv.name = "SHAKE256 Empty"; tv.mode = SHAKE256; tv.msg_hex_str = ""; 
        tv.exp_md_hex_str = "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Short Message
        tv.name = "SHAKE256 Short"; tv.mode = SHAKE256; tv.msg_hex_str = "414d44"; // "AMD"
        tv.exp_md_hex_str = "4f22c199589d813735e1659f776269707823f37651a131b2383842f483664d60";
        tv.output_len_bits = 256; vectors.push_back(tv);

        // Long Message
        tv.name = "SHAKE256 Long"; tv.mode = SHAKE256; 
        tv.msg_hex_str = "5348414b453235362070726f7669646573206120686967686572207365637572697479206c6576656c20636f6d706172656420746f205348414b4531323820616e64206973207573656420696e206d616e792063727970746f67726170686963206170706c69636174696f6e73";
        tv.exp_md_hex_str = "c4d7b37243c22425a1f6a1d46c651139417855b7662c162637952a6f7b9f87c9";
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
