# SystemVerilog Keccak Core (FIPS 202)

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Standard](https://img.shields.io/badge/Standard-FIPS%20202-green)
![Interface](https://img.shields.io/badge/Interface-AXI4--Stream-orange)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A high-performance, fully synthesizable hardware implementation of the **Keccak Permutation** and **SHA-3/SHAKE** hashing algorithms. This core is designed for high-frequency FPGA and ASIC applications, featuring a standard AXI4-Stream interface and a 5-stage pipelined round function.

## 🚀 Key Features

* **Standards Compliant:** Fully supports **FIPS 202** (SHA-3 Standard).
* **Multi-Mode Support:** Runtime configurable for:
    * **Fixed-Length:** SHA3-256, SHA3-512
    * **Extendable-Output (XOF):** SHAKE128, SHAKE256
* **Standard Interface:** **AXI4-Stream** Sink (Input) and Source (Output) interfaces with backpressure support.
* **Robust Architecture:**
    * Handles arbitrary message lengths with internal **'10*1' Padding**.
    * **5-Stage Pipeline:** (Theta, Rho, Pi, Chi, Iota) for optimal critical path timing.
    * **Safety Features:** Includes SystemVerilog Assertions (SVA) for overflow and protocol checking.
* **Production Ready:** Includes `default_nettype none` safety and explicit width casting.

## 📊 Supported Modes

| Mode | Security Strength | Rate (r) | Capacity (c) | Output Size |
| :--- | :--- | :--- | :--- | :--- |
| **SHA3-256** | 128-bit | 1088 bits | 512 bits | 256 bits |
| **SHA3-512** | 256-bit | 576 bits | 1024 bits | 512 bits |
| **SHAKE128** | 128-bit | 1344 bits | 256 bits | Infinite (XOF) |
| **SHAKE256** | 256-bit | 1088 bits | 512 bits | Infinite (XOF) |

## 🛠️ Architecture

The core utilizes a **Sponge Construction** architecture controlled by a central FSM:

1.  **Absorber Unit:** Buffers input data from AXI Stream and performs the XOR operation into the State Array. Handles carry-over for unaligned data chunks.
2.  **Suffix Padder:** Automatically applies the Domain Separation Suffix and the '10*1' padding rule at the end of the message.
3.  **Step Unit (ALU):** The heart of the permutation, executing the 5 Keccak steps (θ, ρ, π, χ, ι).
4.  **Output Unit:** Linearizes the 3D state array and manages the "Squeezing" phase for output generation.

## 🔌 Signal Description

| Signal Group | Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- | :--- |
| **System** | `clk` | Input | 1 | System Clock |
| | `rst` | Input | 1 | Synchronous Active-High Reset |
| **Control** | `start_i` | Input | 1 | Pulses high to initialize core for new hash |
| | `keccak_mode_i` | Input | 2 | Mode Selector (See Package) |
| | `stop_i` | Input | 1 | Stops output generation (Used for XOF modes) |
| **AXI Sink** | `t_data_i` | Input | W | Input Message Data |
| | `t_valid_i` | Input | 1 | Valid flag for input data |
| | `t_last_i` | Input | 1 | Indicates last transfer of message |
| | `t_ready_o` | Output | 1 | Core Ready (Backpressure) |
| **AXI Source** | `t_data_o` | Output | W | Hash Output Data |
| | `t_valid_o` | Output | 1 | Valid flag for output hash |
| | `t_last_o` | Output | 1 | End of Hash (Fixed modes only) |

## 💻 Simulation

The project includes a SystemVerilog testbench (`keccak_core_tb.sv`) and other testbenches for all modules.

### Running with Modelsim
1.  bash
2.  source env.sh
3.  make

## 📂 File Structure

The repository is organized into RTL source, testbenches, and verification scripts:

```text
.
├── rtl/                        # SystemVerilog Source Code
│   ├── keccak_core.sv          # Top Level Module
│   ├── keccak_step_unit.sv     # Permutation Round Logic (ALU)
│   ├── keccak_absorb_unit.sv   # Input Buffering & XOR Logic
│   ├── keccak_output_unit.sv   # Output Linearization & Squeeze
│   ├── keccak_param_unit.sv    # Parameter LUT (Rate/Suffix)
│   ├── suffix_padder_unit.sv   # FIPS 202 Padding Logic
│   └── ...                     # Individual Step Modules (Chi, Theta, etc.)
├── tb/                         # SystemVerilog Testbenches
│   ├── keccak_core_tb.sv       # Main Integration Testbench
│   ├── keccak_core_heavy_tb.sv # Long-running Stress Tests
│   └── ...                     # Unit Testbenches for sub-modules
├── verif/                      # Compliance Verification
│   ├── parse_nist_vectors.py   # Script to parse official NIST .rsp files
│   └── test_vectors/           # Official NIST SHA3/SHAKE Test Vectors
├── python_testing/             # Golden Model Generators
│   └── ...                     # Python reference implementations for step logic
└── Makefile                    # Build and Simulation scripts