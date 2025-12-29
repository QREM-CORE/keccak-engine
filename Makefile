# =====================
# ModelSim Multi-TB Makefile (Updated for new file structure)
# =====================

# List of testbenches (example: TESTBENCHES = theta_step_tb rho_step_tb)
TESTBENCHES = theta_step_tb rho_step_tb pi_step_tb chi_step_tb iota_step_tb keccak_absorb_unit_tb suffix_padder_unit_tb keccak_output_unit_tb keccak_core_tb

# RTL design and package files
PKG_SRCS = rtl/keccak_pkg.sv
DESIGN_SRCS = $(wildcard rtl/*.sv)
COMMON_SRCS = $(wildcard rtl/*.svh)

# Work library
WORK = work

# Default target
all: $(WORK)
	@if [ -z "$(strip $(TESTBENCHES))" ]; then \
		echo "No testbenches specified. Compiling RTL only..."; \
		vlog -work $(WORK) -sv $(PKG_SRCS); \
		vlog -work $(WORK) -sv $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS); \
	else \
		$(MAKE) run_all TESTBENCHES="$(TESTBENCHES)"; \
	fi


# Create ModelSim work library
$(WORK):
	vlib $(WORK)

# Run all testbenches
.PHONY: run_all clean run_%

run_all:
	@for tb in $(TESTBENCHES); do \
		$(MAKE) run_$$tb; \
	done

# Rule for each testbench
run_%: $(WORK)
	@if [ "$*" = "all" ]; then exit 0; fi
	@echo "=== Running $* ==="
	vlog -work $(WORK) -sv $(PKG_SRCS)
	vlog -work $(WORK) -sv $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS) tb/$*.sv
	@echo 'vcd file "$*.vcd"' > run_$*.macro
	@echo 'vcd add -r /$*/*' >> run_$*.macro
	@echo 'run -all' >> run_$*.macro
	@echo 'quit' >> run_$*.macro
	vsim -c -do run_$*.macro $(WORK).$*
	rm -f run_$*.macro

# Add the new TB to the list
TESTBENCHES += keccak_core_heavy_tb

# Special rule for the "Heavy" TB (Running ALL, NO VCD)
# We override the standard run_% rule for this specific target to avoid huge VCDs
run_keccak_core_heavy_tb: $(WORK)
	@echo "=== Running Heavy Regression (No VCD) ==="
	vlog -work $(WORK) -sv $(PKG_SRCS)
	vlog -work $(WORK) -sv $(filter-out $(PKG_SRCS), $(DESIGN_SRCS)) $(COMMON_SRCS) tb/keccak_core_heavy_tb.sv
	@echo 'run -all' > run_heavy.macro
	@echo 'quit' >> run_heavy.macro
	vsim -c -do run_heavy.macro $(WORK).keccak_core_heavy_tb
	rm -f run_heavy.macro

# Special rule for Re-running a FAILURE (With VCD)
# Usage: make run_heavy_fail TEST_ID=123
run_heavy_fail: $(WORK)
	@echo "=== Debugging Test ID $(TEST_ID) ==="
	@echo 'vcd file "keccak_core_heavy_tb.vcd"' > run_fail.macro
	@echo 'vcd add -r /keccak_core_heavy_tb/*' >> run_fail.macro
	@echo 'run -all' >> run_fail.macro
	@echo 'quit' >> run_fail.macro
	vsim -c -do run_fail.macro $(WORK).keccak_core_heavy_tb +TEST_ID=$(TEST_ID)
	rm -f run_fail.macro

# Clean build files
clean:
	rm -rf $(WORK) *.vcd transcript vsim.wlf run_*.macro
