import keccak_pkg::*;

module keccak_step_unit (
    input   logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i,
    // Current round index (0-23)
    input   logic [ROUND_INDEX_SIZE-1:0]                      round_index_i,
    // Step Selector
    input   logic [STEP_SEL_WIDTH-1:0]                        step_sel_i,

    output  logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o
);
    logic [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0]   theta_out,
                                                        rho_out,
                                                        pi_out,
                                                        chi_out,
                                                        iota_out;

    // Instantiate Step Mapping Modules
    theta_step u_theta (.state_array_i(state_array_i), .state_array_o(theta_out));
    rho_step   u_rho   (.state_array_i(state_array_i), .state_array_o(rho_out));
    pi_step    u_pi    (.state_array_i(state_array_i), .state_array_o(pi_out));
    chi_step   u_chi   (.state_array_i(state_array_i), .state_array_o(chi_out));
    iota_step  u_iota  (.state_array_i(state_array_i),
                        .round_index_i(round_index),
                        .state_array_o(iota_out));

    // Multiplexor for step mappings
    always @(*) begin
        case(step_sel_i)
            THETA_STEP          : state_array_o = theta_out;
            RHO_STEP            : state_array_o = rho_out;
            PI_STEP             : state_array_o = pi_out;
            CHI_STEP            : state_array_o = chi_out;
            IOTA_STEP           : state_array_o = iota_out;
            IDLE_STEP           : state_array_o = 'b0;
            default             : state_array_o = 'b0;
        endcase
    end

endmodule
