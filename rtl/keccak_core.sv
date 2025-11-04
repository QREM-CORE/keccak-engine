
import keccak_pkg::*;

module keccak_core (
    input clk,
    input rst,

    input start_i,
    input [255:0] seed_i,
    input [2:0] keccak_mode_i,

    input ready_i,

    output [511:0] hash_o,
    output reg done_o
);

    /*
     * 1600-bit State Array using to hold the state of keccak core.
     * This architecture splits the state array into 25 lanes of 64 bits.
     * See FIPS202 Section 3.1.1 for more information on state array.
     */
    reg [4:0][4:0][63:0] state_array;

    // Each output requires 24 rounds of permutations (θ-theta, ρ, π, χ, ι)
    reg [4:0] round;

    // Control enables
    reg en_theta, en_rho, en_pi, en_chi, en_iota;

    // Step Module Outputs
    wire [4:0][4:0][63:0] theta_out, rho_out, pi_out, chi_out, iota_out;

    // TODO: IMPLEMENT STEP MAPPING MODULES
    // Instantiate Step Mapping Modules
    // theta_step u_theta (.state_in(state_array), .state_out(theta_out));
    // rho_step   u_rho   (.state_in(state_array), .state_out(rho_out));
    // pi_step    u_pi    (.state_in(state_array), .state_out(pi_out));
    // chi_step   u_chi   (.state_in(state_array), .state_out(chi_out));
    // iota_step  u_iota  (.state_in(state_array), .state_out(iota_out));

    // FSM States
    typedef enum reg [2:0] {
        IDLE, THETA, RHO, PI, CHI, IOTA, DONE
    } state_t;
    state_t fsm_state;

    // Keccak Control FSM
    always @(posedge clk) begin
        
    end

endmodule
