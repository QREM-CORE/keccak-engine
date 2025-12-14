import keccak_pkg::*;

// SHA3 Parameter Setup Module
module sha3_setup (
    input  logic [MODE_SEL_WIDTH-1:0]   keccak_mode_i, // 00: SHA3-256, 01: SHA3-512, 10: SHAKE128, 11: SHAKE256
    output logic [RATE_WIDTH-1:0]       rate_o,
    output logic [CAPACITY_WIDTH-1:0]   capacity_o,
    output logic [SUFFIX_WIDTH-1:0]     suffix_o,
    output logic [SUFFIX_LEN_WIDTH-1:0] suffix_len_o // Tells downstream logic how many bits to use
);
    always_comb begin
        case (keccak_mode_i)
            SHA3_256: begin
                rate_o          = 1088;
                capacity_o      = 512;
                suffix_o        = 4'b0001; // '01' padded to 4 bits
                suffix_len_o    = 2;       // Only use bottom 2 bits
            end

            SHA3_512: begin
                rate_o          = 576;
                capacity_o      = 1024;
                suffix_o        = 4'b0001; // '01'
                suffix_len_o    = 2;
            end

            SHAKE128: begin
                rate_o          = 1344;
                capacity_o      = 256;
                suffix_o        = 4'b1111; // '1111'
                suffix_len_o    = 4;
            end

            SHAKE256: begin
                rate_o          = 1088;
                capacity_o      = 512;
                suffix_o        = 4'b1111; // '1111'
                suffix_len_o    = 4;
            end

            default: begin
                rate_o          = '0;
                capacity_o      = '0;
                suffix_o        = '0;
                suffix_len_o    = '0;
            end
        endcase
    end

endmodule
