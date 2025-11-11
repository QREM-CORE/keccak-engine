package keccak_pkg;
    typedef enum logic [2:0] {
        SHA3_256,
        SHA3_512,
        SHAKE128,
        SHAKE256
    } keccak_mode;

    // Misc. Bit Sizes
    parameter int BYTE_SIZE = 8;

    // State Array Dimension Bit Sizes
    parameter int LANE_SIZE = 64;
    parameter int ROW_SIZE  = 5;
    parameter int COL_SIZE  = 5;

    // Iota Step
    parameter int ROUND_INDEX_SIZE = 5;
    parameter int MAX_ROUNDS = 24;
    parameter int L_SIZE = 7;

endpackage : keccak_pkg
