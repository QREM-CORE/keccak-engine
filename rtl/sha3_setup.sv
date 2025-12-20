import keccak_pkg::*;

// SHA3 Parameter Setup Module
module sha3_setup (
    input  logic [MODE_SEL_WIDTH-1:0]   keccak_mode_i,
    output logic [RATE_WIDTH-1:0]       rate_o,
    output logic [CAPACITY_WIDTH-1:0]   capacity_o,
    output logic [SUFFIX_WIDTH-1:0]     suffix_o
);
    always_comb begin
        case (keccak_mode_i)
            SHA3_256: begin
                rate_o          = 1088;
                capacity_o      = 512;
                suffix_o        = 8'b0000_0110; // Suffix '01' + Padding '1' (Hex 0x06)
            end

            SHA3_512: begin
                rate_o          = 576;
                capacity_o      = 1024;
                suffix_o        = 8'b0000_0110; // Suffix '01' + Padding '1' (Hex 0x06)
            end

            SHAKE128: begin
                rate_o          = 1344;
                capacity_o      = 256;
                suffix_o        = 8'b0001_1111; // Suffix '1111' + Padding '1' (Hex 0x1F)
            end

            SHAKE256: begin
                rate_o          = 1088;
                capacity_o      = 512;
                suffix_o        = 8'b0001_1111; // Suffix '1111' + Padding '1' (Hex 0x1F)
            end

            default: begin
                rate_o          = '0;
                capacity_o      = '0;
                suffix_o        = '0;
            end
        endcase
    end

endmodule
