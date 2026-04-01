# ============================================================================
# RISCV-DV + VCS + Spike verification Makefile for ArchGen RV32I cores
# ============================================================================
# Usage:
#   make smoke_single          - Run smoke test on single-cycle core
#   make smoke_5pipe            - Run smoke test on pipeline core
#   make run_single TEST=<test> SEED=<seed>  - Run RISCV-DV test on single-cycle
#   make run_5pipe  TEST=<test> SEED=<seed>  - Run RISCV-DV test on pipeline
#   make regress CORE=single    - Run full regression
# ============================================================================

# ---- Tool paths ----
RISCV_GCC      ?= riscv64-unknown-elf-gcc
RISCV_OBJCOPY  ?= riscv64-unknown-elf-objcopy
RISCV_OBJDUMP  ?= riscv64-unknown-elf-objdump
ELF2HEX        ?= elf2hex
SPIKE          ?= spike
VCS            ?= vcs
PYTHON         ?= python3

# ---- Project paths ----
PROJ_ROOT  := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DV_ROOT    := $(PROJ_ROOT)/dv
RISCV_DV   := $(DV_ROOT)/riscv-dv
COMMON     := $(DV_ROOT)/common
OUT_DIR    := $(DV_ROOT)/out

# ---- RISCV-DV paths ----
RISCV_DV_SCRIPTS := $(RISCV_DV)/scripts
SPIKE_LOG_TO_CSV := $(RISCV_DV_SCRIPTS)/spike_log_to_trace_csv.py
TRACE_COMPARE    := $(RISCV_DV_SCRIPTS)/instr_trace_compare.py
RTL_TRACE_TO_CSV := $(COMMON)/rtl_trace_to_csv.py
ELF_TO_HEX      := $(COMMON)/elf_to_hex.py

# ---- Target configuration ----
TARGET_DIR  := $(DV_ROOT)/target/archgen_rv32i
TESTLIST    := $(TARGET_DIR)/testlist.yaml

# ---- Default parameters ----
CORE       ?= single
TEST       ?= riscv_arithmetic_basic_test
SEED       ?= 0
ISA        ?= rv32i
PRIV       ?= m
MAX_CYCLES ?= 500000

# ---- GCC flags ----
GCC_MARCH  := rv32i_zicsr
GCC_MABI   := ilp32
GCC_FLAGS  := -march=$(GCC_MARCH) -mabi=$(GCC_MABI) -nostdlib -nostartfiles \
              -T $(COMMON)/link.ld -Wl,--no-relax -I$(TARGET_DIR)

# ---- Core-specific paths (deferred evaluation for target-specific CORE) ----
CORE_DIR = $(DV_ROOT)/$(CORE)
FILES_F  = $(CORE_DIR)/files.f

# ---- Derived paths (deferred for CORE/TEST/SEED target-specific vars) ----
WORK_DIR    = $(OUT_DIR)/$(CORE)/$(TEST)_seed$(SEED)
ASM_FILE    = $(WORK_DIR)/test.S
ELF_FILE    = $(WORK_DIR)/test.elf
TEXT_HEX    = $(WORK_DIR)/text.hex
DATA_HEX    = $(WORK_DIR)/data.hex
SPIKE_LOG   = $(WORK_DIR)/spike.log
SPIKE_CSV   = $(WORK_DIR)/spike_trace.csv
RTL_LOG     = $(WORK_DIR)/rtl_trace.log
RTL_CSV     = $(WORK_DIR)/rtl_trace.csv
SIM_DIR     = $(WORK_DIR)/sim
COMPARE_LOG = $(WORK_DIR)/compare.log

# Smoke test paths
SMOKE_DIR  = $(OUT_DIR)/$(CORE)/smoke
SMOKE_ELF  = $(SMOKE_DIR)/smoke_test.elf
SMOKE_TEXT = $(SMOKE_DIR)/text.hex
SMOKE_DATA = $(SMOKE_DIR)/data.hex
SMOKE_LOG  = $(SMOKE_DIR)/rtl_trace.log

# ---- Coverage control ----
COV          ?= 0
COV_METRICS  := line+cond+fsm+tgl+branch
# Per-test coverage paths (deferred)
COV_DIR           = $(WORK_DIR)/coverage
COV_REPORT        = $(WORK_DIR)/coverage/report
# Smoke coverage paths
SMOKE_COV_DIR     = $(SMOKE_DIR)/coverage
SMOKE_COV_REPORT  = $(SMOKE_DIR)/coverage/report
# Regression merged coverage paths
REGRESS_COV_DIR     = $(OUT_DIR)/$(CORE)/regress_coverage
REGRESS_COV_REPORT  = $(OUT_DIR)/$(CORE)/regress_coverage/report

# ---- VCS flags ----
# DataMem loading: DATA_HEX / DATA_HEX_PATH defined in dv/common/config.sv
# Both cores need -ignore initializer_driver_checks for DataMem's
# initial $readmemh + always_ff pattern
VCS_FLAGS    = -full64 -sverilog +v2k -timescale=1ns/1ps \
               -debug_access+all +lint=TFIPC-L \
               -ignore initializer_driver_checks \
               -f $(FILES_F)

# Conditional coverage flags (enabled with COV=1)
VCS_COV_COMP =
VCS_COV_SIM  =
ifeq ($(COV),1)
  VCS_COV_COMP = -cm $(COV_METRICS)
  VCS_COV_SIM  = -cm $(COV_METRICS)
endif

# ============================================================================
# PHONY targets
# ============================================================================
.PHONY: help gen compile_test spike_sim rtl_compile rtl_sim compare \
        run_single run_5pipe regress smoke_single smoke_5pipe \
        cov_report smoke_cov_report cov_regress clean

help:
	@echo "=== ArchGen RISCV-DV Verification ==="
	@echo ""
	@echo "Smoke tests:"
	@echo "  make smoke_single         - Smoke test on single-cycle core"
	@echo "  make smoke_5pipe          - Smoke test on pipeline core"
	@echo ""
	@echo "RISCV-DV flow:"
	@echo "  make run_single TEST=<test> SEED=<n>"
	@echo "  make run_5pipe  TEST=<test> SEED=<n>"
	@echo ""
	@echo "Individual steps:"
	@echo "  make gen          - Generate random assembly (RISCV-DV)"
	@echo "  make compile_test - Compile assembly to ELF and HEX"
	@echo "  make spike_sim    - Run Spike ISS and generate trace CSV"
	@echo "  make rtl_compile  - Compile RTL with VCS"
	@echo "  make rtl_sim      - Run RTL simulation"
	@echo "  make compare      - Compare Spike vs RTL traces"
	@echo ""
	@echo "Regression:"
	@echo "  make regress CORE=single"
	@echo "  make regress CORE=5pipe-stall"
	@echo ""
	@echo "Coverage (append COV=1 to enable):"
	@echo "  make smoke_single COV=1"
	@echo "  make smoke_cov_report CORE=single"
	@echo "  make run_single TEST=<test> SEED=<n> COV=1"
	@echo "  make cov_report CORE=single TEST=<test> SEED=<n>"
	@echo "  make cov_regress CORE=single"
	@echo ""
	@echo "Available tests (from testlist.yaml):"
	@echo "  riscv_arithmetic_basic_test"
	@echo "  riscv_rand_instr_test"
	@echo "  riscv_load_store_test"
	@echo "  riscv_jump_branch_test"

# ============================================================================
# Step 1: Generate random assembly with RISCV-DV
# ============================================================================
gen:
	@mkdir -p $(WORK_DIR)
	@echo "==== [GEN] Generating test: $(TEST) seed=$(SEED) ===="
	cd $(RISCV_DV) && $(PYTHON) run.py \
		--test $(TEST) \
		--target rv32i \
		-ct $(TARGET_DIR) \
		--isa $(ISA) \
		--priv $(PRIV) \
		--iterations 1 \
		-o $(WORK_DIR) \
		-s gen \
		--simulator_yaml $(RISCV_DV)/yaml/simulator.yaml \
		-si vcs \
		--start_seed $(SEED) 2>&1 | tee $(WORK_DIR)/gen.log
	@# Find generated .S file and copy to work dir
	@find $(WORK_DIR) -name "*.S" -not -name "smoke_test.S" | head -1 | \
		xargs -I{} cp {} $(ASM_FILE) 2>/dev/null || true
	@echo "==== [GEN] Done ===="

# ============================================================================
# Step 2: Compile assembly to ELF and convert to HEX
# ============================================================================
compile_test:
	@mkdir -p $(WORK_DIR)
	@echo "==== [COMPILE] Compiling $(ASM_FILE) ===="
	$(RISCV_GCC) $(GCC_FLAGS) -o $(ELF_FILE) $(ASM_FILE)
	$(RISCV_OBJDUMP) -d $(ELF_FILE) > $(WORK_DIR)/test.objdump
	@echo "==== [COMPILE] Generating HEX files ===="
	$(PYTHON) $(ELF_TO_HEX) --elf $(ELF_FILE) --text $(TEXT_HEX) --data $(DATA_HEX) --base 0x00400000
	@echo "==== [COMPILE] Done ===="

# ============================================================================
# Step 3: Run Spike ISS simulation
# ============================================================================
spike_sim:
	@echo "==== [SPIKE] Running Spike simulation ===="
	$(SPIKE) --isa=$(ISA) --priv=$(PRIV) \
		-m0x00400000:0x40000 \
		-l --log-commits \
		$(ELF_FILE) 2>$(SPIKE_LOG) 1>/dev/null || true
	@echo "==== [SPIKE] Converting Spike log to CSV ===="
	$(PYTHON) $(SPIKE_LOG_TO_CSV) \
		--log $(SPIKE_LOG) \
		--csv $(SPIKE_CSV)
	@echo "==== [SPIKE] Done: $(SPIKE_CSV) ===="

# ============================================================================
# Step 4: Compile RTL with VCS
# ============================================================================
rtl_compile:
	@mkdir -p $(SIM_DIR)
	@echo "==== [VCS] Compiling RTL (CORE=$(CORE)) ===="
	cd $(PROJ_ROOT) && $(VCS) $(VCS_FLAGS) $(VCS_COV_COMP) \
		$(if $(VCS_COV_COMP),-cm_dir $(COV_DIR)/cov.vdb) \
		-Mdir=$(SIM_DIR)/csrc \
		-o $(SIM_DIR)/simv \
		-l $(SIM_DIR)/compile.log 2>&1
	@echo "==== [VCS] Compile done ===="

# ============================================================================
# Step 5: Run RTL simulation
# ============================================================================
rtl_sim:
	@echo "==== [SIM] Running RTL simulation ===="
	cd $(WORK_DIR) && $(SIM_DIR)/simv \
		+text_file=$(TEXT_HEX) \
		+data_file=$(DATA_HEX) \
		+trace_log=$(RTL_LOG) \
		+vcd_file=$(WORK_DIR)/dump.vcd \
		+max_cycles=$(MAX_CYCLES) \
		$(if $(VCS_COV_SIM),$(VCS_COV_SIM) -cm_dir $(COV_DIR)/cov.vdb -cm_name $(TEST)_seed$(SEED)) \
		-l $(WORK_DIR)/sim.log 2>&1
	@echo "==== [SIM] Converting RTL trace to CSV ===="
	$(PYTHON) $(RTL_TRACE_TO_CSV) \
		-i $(RTL_LOG) \
		-o $(RTL_CSV)
	@echo "==== [SIM] Done: $(RTL_CSV) ===="

# ============================================================================
# Step 6: Compare Spike vs RTL traces
# ============================================================================
compare:
	@echo "==== [COMPARE] Comparing traces ===="
	$(PYTHON) $(TRACE_COMPARE) \
		--csv_file_1 $(SPIKE_CSV) \
		--csv_file_2 $(RTL_CSV) \
		--csv_name_1 spike \
		--csv_name_2 rtl \
		--log $(COMPARE_LOG) \
		--in_order_mode 1 \
		--verbose 1 2>&1 | tee -a $(COMPARE_LOG)
	@echo "==== [COMPARE] Result in $(COMPARE_LOG) ===="

# ============================================================================
# Convenience: full single-core flow
# ============================================================================
run_single: CORE=single
run_single: gen compile_test spike_sim rtl_compile rtl_sim compare
ifeq ($(COV),1)
	@$(MAKE) cov_report CORE=single TEST=$(TEST) SEED=$(SEED)
endif

run_5pipe: CORE=5pipe-stall
run_5pipe: gen compile_test spike_sim rtl_compile rtl_sim compare
ifeq ($(COV),1)
	@$(MAKE) cov_report CORE=5pipe-stall TEST=$(TEST) SEED=$(SEED)
endif

# ============================================================================
# Smoke test: compile hand-written test → VCS → run → check trace
# ============================================================================
smoke_single: CORE=single
smoke_single: _smoke_run

smoke_5pipe: CORE=5pipe-stall
smoke_5pipe: _smoke_run

_smoke_run:
	@mkdir -p $(SMOKE_DIR)/sim
	@echo "==== [SMOKE] Compiling smoke test (CORE=$(CORE)) ===="
	$(RISCV_GCC) $(GCC_FLAGS) -o $(SMOKE_ELF) $(DV_ROOT)/tests/smoke_test.S
	$(RISCV_OBJDUMP) -d $(SMOKE_ELF) > $(SMOKE_DIR)/smoke_test.objdump
	$(PYTHON) $(ELF_TO_HEX) --elf $(SMOKE_ELF) --text $(SMOKE_TEXT) --data $(SMOKE_DATA) --base 0x00400000
	@echo "==== [SMOKE] Compiling RTL with VCS ===="
	cd $(PROJ_ROOT) && $(VCS) $(VCS_FLAGS) $(VCS_COV_COMP) \
		$(if $(VCS_COV_COMP),-cm_dir $(SMOKE_COV_DIR)/cov.vdb) \
		-Mdir=$(SMOKE_DIR)/sim/csrc \
		-o $(SMOKE_DIR)/sim/simv \
		-l $(SMOKE_DIR)/sim/compile.log 2>&1
	@echo "==== [SMOKE] Running simulation ===="
	cd $(SMOKE_DIR) && $(SMOKE_DIR)/sim/simv \
		+text_file=$(SMOKE_TEXT) \
		+data_file=$(SMOKE_DATA) \
		+trace_log=$(SMOKE_LOG) \
		+vcd_file=$(SMOKE_DIR)/dump.vcd \
		+max_cycles=10000 \
		$(if $(VCS_COV_SIM),$(VCS_COV_SIM) -cm_dir $(SMOKE_COV_DIR)/cov.vdb -cm_name smoke) \
		-l $(SMOKE_DIR)/sim.log 2>&1
	@echo "==== [SMOKE] Trace output: ===="
	@head -30 $(SMOKE_LOG) 2>/dev/null || echo "(no trace output)"
	@echo "==== [SMOKE] Done ===="

# ============================================================================
# Regression: run all tests from testlist with multiple seeds
# ============================================================================
regress:
	@echo "==== [REGRESS] Starting regression for CORE=$(CORE) ===="
	@mkdir -p $(OUT_DIR)/$(CORE)
	@pass=0; fail=0; total=0; \
	for test in riscv_arithmetic_basic_test riscv_rand_instr_test riscv_load_store_test riscv_jump_branch_test; do \
		for seed in 0 1 2; do \
			total=$$((total+1)); \
			echo "--- Running $$test seed=$$seed ---"; \
			$(MAKE) -s gen compile_test spike_sim rtl_compile rtl_sim compare \
				CORE=$(CORE) TEST=$$test SEED=$$seed 2>&1 | tail -5; \
			if grep -q "PASSED" $(OUT_DIR)/$(CORE)/$${test}_seed$${seed}/compare.log 2>/dev/null; then \
				pass=$$((pass+1)); echo "[PASS] $$test seed=$$seed"; \
			else \
				fail=$$((fail+1)); echo "[FAIL] $$test seed=$$seed"; \
			fi; \
		done; \
	done; \
	echo ""; \
	echo "==== [REGRESS] Summary: $$pass/$$total passed, $$fail failed ===="

# ============================================================================
# Coverage report targets
# ============================================================================
# Single test coverage report
cov_report:
	@echo "==== [COV] Generating coverage report ===="
	urg -dir $(COV_DIR)/cov.vdb -report $(COV_REPORT) -format both
	@echo "==== [COV] Report: $(COV_REPORT) ===="

# Smoke test coverage report
smoke_cov_report:
	@echo "==== [COV] Generating smoke coverage report ===="
	urg -dir $(SMOKE_COV_DIR)/cov.vdb -report $(SMOKE_COV_REPORT) -format both
	@echo "==== [COV] Report: $(SMOKE_COV_REPORT) ===="

# Regression with coverage: run all tests then merge and report
cov_regress:
	@echo "==== [COV-REGRESS] Running regression with coverage for CORE=$(CORE) ===="
	@mkdir -p $(OUT_DIR)/$(CORE)
	@pass=0; fail=0; total=0; \
	for test in riscv_arithmetic_basic_test riscv_rand_instr_test riscv_load_store_test riscv_jump_branch_test; do \
		for seed in 0 1 2; do \
			total=$$((total+1)); \
			echo "--- Running $$test seed=$$seed ---"; \
			$(MAKE) -s gen compile_test spike_sim rtl_compile rtl_sim compare \
				CORE=$(CORE) TEST=$$test SEED=$$seed COV=1 2>&1 | tail -5; \
			if grep -q "PASSED" $(OUT_DIR)/$(CORE)/$${test}_seed$${seed}/compare.log 2>/dev/null; then \
				pass=$$((pass+1)); echo "[PASS] $$test seed=$$seed"; \
			else \
				fail=$$((fail+1)); echo "[FAIL] $$test seed=$$seed"; \
			fi; \
		done; \
	done; \
	echo ""; \
	echo "==== [COV-REGRESS] Summary: $$pass/$$total passed, $$fail failed ===="; \
	echo "==== [COV-REGRESS] Merging coverage databases ===="; \
	mkdir -p $(REGRESS_COV_DIR); \
	urg -dir $(OUT_DIR)/$(CORE)/*/coverage/cov.vdb \
		-dbname $(REGRESS_COV_DIR)/cov.vdb \
		-report $(REGRESS_COV_REPORT) \
		-format both; \
	echo "==== [COV-REGRESS] Merged report: $(REGRESS_COV_REPORT) ===="

# ============================================================================
# Clean
# ============================================================================
clean:
	rm -rf $(OUT_DIR)/*
	@echo "Cleaned output directory"
