package keccak_pkg;
    typedef enum logic [2:0] {
        SHA3_256,
        SHA3_512,
        SHAKE128,
        SHAKE256
    } keccak_mode;

    parameter int LANE_SIZE = 64;
    parameter int ROW_SIZE  = 5;
    parameter int COL_SIZE  = 5;
endpackage : keccak_pkg
