# SystemVerilog Keccak Core (FIPS 202)

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Standard](https://img.shields.io/badge/Standard-FIPS%20202-green)
![Interface](https://img.shields.io/badge/Interface-AXI4--Stream-orange)
![Verification](https://img.shields.io/badge/Verification-SVA%20%26%20NIST-purple)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A high-frequency, fully synthesizable hardware implementation of the **Keccak Permutation** and **SHA-3/SHAKE** hashing algorithms.

This core utilizes a **Multi-Cycle Iterative Architecture**. To maximize operating frequency ($F_{max}$), the Keccak round function is decomposed into 5 distinct clock cycles ($\theta, \rho, \pi, \chi, \iota$). This reduces the combinatorial path depth significantly compared to single-cycle implementations, making it suitable for high-speed FPGA and ASIC targets.

## 🚀 Key Features

* **FIPS 202 Compliant:** Byte-exact implementation of SHA-3 and SHAKE standards.
* **Runtime Configurable:** Switch between 4 modes dynamically via input signals:
    * **Fixed-Length:** SHA3-256, SHA3-512
    * **Extendable-Output (XOF):** SHAKE128, SHAKE256
* **Standard Interface:** **AXI4-Stream** compliant Sink (Input) and Source (Output) with full backpressure support.
* **Robust Architecture:**
    * **Internal Padding:** Automatically handles the FIPS 202 `10*1` padding rule and Domain Separation Suffixes.
    * **Safety Features:** Integrated **SystemVerilog Assertions (SVA)** verify state machine stability, counter overflows, and AXI protocol compliance in real-time.
* **Production Ready:** Written with `default_nettype none` to prevent implicit wire hazards and supports explicit width casting.

## 📊 Supported Modes

| Mode | Security Strength | Rate (r) | Capacity (c) | Suffix |
| :--- | :--- | :--- | :--- | :--- |
| **SHA3-256** | 128-bit | 1088 bits | 512 bits | `01` |
| **SHA3-512** | 256-bit | 576 bits | 1024 bits | `01` |
| **SHAKE128** | 128-bit | 1344 bits | 256 bits | `1111` |
| **SHAKE256** | 256-bit | 1088 bits | 512 bits | `1111` |

## 🛠️ Architecture



The core is controlled by a central FSM utilizing a Sponge Construction:

1.  **Absorber Unit:** Buffers 256-bit AXI data chunks. It handles "carry-over" logic for when input data boundaries do not align with the internal block rate.
2.  **Step Unit (ALU):** The critical path is broken down into 5 sequential steps per round. A full permutation requires 24 rounds $\times$ 5 steps = **120 clock cycles**.
3.  **Suffix Padder:** A dedicated unit that injects the Domain Separation Suffix (e.g., `0x06` or `0x1F`) and the final `1` bit at the end of the message.
4.  **Output Unit:** Linearizes the 3D ($5 \times 5 \times 64$) state array into 256-bit output words and manages "Squeezing" for XOF modes.

## 🔌 Signal Description

### Parameters
* `DWIDTH`: Input Data Width (Default: **256 bits**)
* `MAX_OUTPUT_DWIDTH`: Output Data Width (Default: **256 bits**)

### Ports

| Signal Group | Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- | :--- |
| **System** | `clk` | Input | 1 | System Clock (Rising Edge) |
| | `rst` | Input | 1 | Synchronous Active-High Reset |
| **Control** | `start_i` | Input | 1 | Pulse high to reset FSM and start new hash |
| | `keccak_mode_i` | Input | 2 | `00`: SHA3-256, `01`: SHA3-512, `10`: SHAKE128, `11`: SHAKE256 |
| | `stop_i` | Input | 1 | Stops output generation (Required for XOF modes) |
| **AXI Sink** | `t_data_i` | Input | 256 | Input Message Data |
| | `t_valid_i` | Input | 1 | Master Valid |
| | `t_last_i` | Input | 1 | Assert high on the final chunk of the message |
| | `t_keep_i` | Input | 32 | Byte Enable (1 bit per byte). `t_keep[0]` is LSB. |
| | `t_ready_o` | Output | 1 | Slave Ready. Core pulls low when processing permutation. |
| **AXI Source** | `t_data_o` | Output | 256 | Hash Output Data |
| | `t_valid_o` | Output | 1 | Master Valid |
| | `t_last_o` | Output | 1 | End of Hash (High for SHA3, Low for SHAKE) |
| | `t_keep_o` | Output | 32 | Byte Enable for output data |
| | `t_ready_i` | Input | 1 | Slave Ready (Backpressure from downstream) |

## 💻 Simulation & Verification

This project utilizes a dual-verification strategy: **SystemVerilog Assertions (SVA)** for runtime protocol checking and **Python-generated NIST vectors** for standard compliance. Continuous Integration (CI) is handled via GitHub Actions to ensure build integrity on every Pull Request.

### 1. Prerequisites (Linux/Ubuntu)
The simulation environment relies on **ModelSim (Intel FPGA Lite)**. Since ModelSim ASE is a 32-bit application, running it on modern 64-bit Linux distributions (like Ubuntu 20.04/22.04) requires specific 32-bit compatibility libraries and a kernel check patch.

**Install Dependencies:**
```bash
# 1. Add architecture and update
sudo dpkg --add-architecture i386
sudo apt-get update

# 2. Install core build tools
sudo apt-get install -y wget build-essential

# 3. Install required 32-bit libraries (Required for ModelSim ASE)
sudo apt-get install -y libc6:i386 libncurses5:i386 libstdc++6:i386 \
lib32ncurses6 libxft2 libxft2:i386 libxext6 libxext6:i386
```
**Patching ModelSim (Critical for Modern Linux):**
If ModelSim fails to launch or hangs, apply these patches to the `vco` script (located in `<install_dir>/modelsim_ase/vco`) to fix OS detection and force 32-bit mode:
```bash
# Fix Red Hat directory detection logic
sudo sed -i 's/linux_rh[[:digit:]]\+/linux/g' <path_to_modelsim>/vco

# Force 32-bit mode
sudo sed -i 's/MTI_VCO_MODE:-\"\"/MTI_VCO_MODE:-\"32\"/g' <path_to_modelsim>/vco
```
### 2. Running Simulations
The repository includes a Makefile that handles compiling, running, and waveform generation for multiple testbenches.

**Setup Environment:**
Ensure the path in `env.sh` points to your specific ModelSim installation (e.g., `/opt/intelFPGA_lite/...` or `/pkgcache/...`).
```bash
source env.sh
```

**Run All Tests:** This will execute the entire suite of unit tests and the full core integration test.
```bash
make
```

**Run Specific Test:** You can target individual modules (Unit Tests) using the run_<tb_name> target:
```bash
make run_theta_step_tb
make run_keccak_core_tb
make run_keccak_absorb_unit_tb
```
**Clean Artifacts:** Removes generated work libraries and .vcd waveform files.
```bash
make clean
```
**Viewing Waveforms:** Every simulation run automatically generates a corresponding Value Change Dump (.vcd) file (e.g., keccak_core_tb.vcd) which can be opened in GTKWave or ModelSim.

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
