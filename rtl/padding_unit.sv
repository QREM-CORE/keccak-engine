module padding_unit (
    input   [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_i, // Zeroed input state
    input   [MODE_SEL_WIDTH-1:0]                        mode_sel_i,
    output  [ROW_SIZE-1:0][COL_SIZE-1:0][LANE_SIZE-1:0] state_array_o // Padded output state
);
    
endmodule
