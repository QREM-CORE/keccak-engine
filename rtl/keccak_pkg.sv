package keccak_pkg;
    // Misc. Bit Sizes
    parameter int BYTE_SIZE = 8;

    // Keccak Structure
    parameter int DWIDTH = 256; // Input data is 32 bytes
    parameter int DATA_BYTE_NUM = DATA_SIZE/8;
    parameter int VALID_BYTES_WIDTH = $clog2(DATA_BIT_WIDTH*BYTE_SIZE);
    parameter int MAX_OUTPUT_DWIDTH = 2*VALID_BYTES_BIT_WIDTH;

    // Different Keccak Modes
    typedef enum logic {
        SHA3_256,
        SHA3_512,
        SHAKE128,
        SHAKE256
    } keccak_mode;
    parameter int MODE_NUM = 4;
    parameter int MODE_SEL_WIDTH = $clog2(MODE_NUM);

    // Different step selector options
    typedef enum logic {
        ZERO_STEP,
        THETA_STEP,
        RHO_STEP,
        PI_STEP,
        CHI_STEP,
        IOTA_STEP,
    } keccak_step;

    // State Array Dimension Bit Sizes
    parameter int LANE_SIZE = 64;
    parameter int ROW_SIZE  = 5;
    parameter int COL_SIZE  = 5;

    // Step Map
    parameter int STEP_NUM = 5;
    parameter int STEP_SEL_WIDTH = $clog2(STEP_NUM);

    // Iota Step
    parameter int ROUND_INDEX_SIZE = 5;
    parameter int MAX_ROUNDS = 24;
    parameter int L_SIZE = 7;

endpackage : keccak_pkg
