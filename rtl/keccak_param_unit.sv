/*
 * Module Name: keccak_param_unit
 * Author: Kiet Le
 * Description:
 * - Acts as a Look-Up Table (LUT) for FIPS 202 standard parameters.
 * - decodes the input 'keccak_mode_i' to output the correct Rate (block size)
 * and Domain Separation Suffix bits.
 * - Supports the following configurations:
 * 1. SHA3-256 (Rate: 1088, Suffix: 01)
 * 2. SHA3-512 (Rate: 576,  Suffix: 01)
 * 3. SHAKE128 (Rate: 1344, Suffix: 1111)
 * 4. SHAKE256 (Rate: 1088, Suffix: 1111)
 * - Note: The suffix output includes the first '1' bit of the '10*1' padding rule
 * pre-appended for simplified padding logic downstream.
 */

`default_nettype none
`timescale 1ns / 1ps

import keccak_pkg::*;

module keccak_param_unit (
    input  wire  [MODE_SEL_WIDTH-1:0]   keccak_mode_i,

    output logic [RATE_WIDTH-1:0]       rate_o,
    output logic [SUFFIX_WIDTH-1:0]     suffix_o
);

    // ==========================================================
    // 1. INTERNAL CONSTANTS
    // ==========================================================
    // Rates in bits
    localparam int R_SHA3_256 = 1088;
    localparam int R_SHA3_512 = 576;
    localparam int R_SHAKE128 = 1344;
    localparam int R_SHAKE256 = 1088;

    // Suffixes (Domain + Padding Start Bit)
    // Format: {Padding_Bit, Domain_Bits} padded to 8 bits
    localparam logic [7:0] S_SHA3  = 8'b0000_0110; // '01' + '1' = 011 (0x6)
    localparam logic [7:0] S_SHAKE = 8'b0001_1111; // '1111' + '1' = 11111 (0x1F)

    // ==========================================================
    // 2. LOGIC
    // ==========================================================
    always_comb begin
        case (keccak_mode_i)
            SHA3_256: begin
                rate_o   = R_SHA3_256;
                suffix_o = S_SHA3;
            end

            SHA3_512: begin
                rate_o   = R_SHA3_512;
                suffix_o = S_SHA3;
            end

            SHAKE128: begin
                rate_o   = R_SHAKE128;
                suffix_o = S_SHAKE;
            end

            SHAKE256: begin
                rate_o   = R_SHAKE256;
                suffix_o = S_SHAKE;
            end

            // Safety Fallback: Default to SHA3-256 settings.
            // Returning 0 for rate causes FSM deadlocks (max_bytes=0).
            default: begin
                rate_o   = R_SHA3_256;
                suffix_o = S_SHA3;
            end
        endcase
    end

endmodule

`default_nettype wire
