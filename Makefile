# =====================
# ModelSim Multi-TB Makefile (Updated for new file structure)
# =====================

# List of testbenches (example: TESTBENCHES = theta_step_tb rho_step_tb)
TESTBENCHES = theta_step_tb rho_step_tb pi_step_tb chi_step_tb iota_step_tb absorb_tb suffix_padder_unit_tb

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


# Clean build files
clean:
	rm -rf $(WORK) *.vcd transcript vsim.wlf run_*.macro
