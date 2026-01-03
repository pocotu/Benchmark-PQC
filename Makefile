# ============================================================================
# Main Makefile - Benchmarks PQC
# National University of San Antonio Abad del Cusco
# ============================================================================

# Default target when running 'make' without arguments
.DEFAULT_GOAL := help

.PHONY: all help clean clean-all clean-temp clean-deep setup build test verify run-benchmarks \
        build-native build-arm build-riscv check-env info \
        clean-logs validate-env benchmark-mlkem compile-benchmarks \
        clean-benchmarks dirs test-timing test-stats test-correctness test-all \
        run-experiments init-experiments validate-data collect-metadata \
        resume-experiments experiments-dry-run \
        install-python-deps run-remote-arm64 run-remote-riscv64 \
        validate-results backup-results run-full-campaign \
        analyze-results analyze-compare analyze-viz analyze-stats install-analysis-deps \
        compile-measure-sizes measure-sizes analyze-overhead \
        analyze-statistical generate-visualizations \
        analyze-performance-factors

# Prevent parallel execution of build targets to avoid race conditions
.NOTPARALLEL: build-native build-arm build-riscv

# Colors for output
RED     := \033[0;31m
GREEN   := \033[0;32m
YELLOW  := \033[0;33m
BLUE    := \033[0;34m
MAGENTA := \033[0;35m
CYAN    := \033[0;36m
RESET   := \033[0m

# Helper function for section headers (SOLID: DRY)
define show_section
	@bash -c "source $(LIB_DIR)/banner-functions.sh && show_section_separator '$(1)'"
endef

# Directories
BUILD_DIR    := build
SRC_DIR      := src
SCRIPTS_DIR  := scripts
DATA_DIR     := data
RESULTS_DIR  := results
DOCS_DIR     := docs
LOG_DIR      := $(BUILD_DIR)/logs
CONFIG_DIR   := config
LIB_DIR      := lib
BIN_DIR      := $(BUILD_DIR)/bin
OBJ_DIR      := $(BUILD_DIR)/obj

# Compilation configuration
LIBOQS_NATIVE_DIR  := $(BUILD_DIR)/liboqs/build-native
LIBOQS_ARM_DIR     := $(BUILD_DIR)/liboqs/build-arm64
LIBOQS_RISCV_DIR   := $(BUILD_DIR)/liboqs/build-riscv64

# Compiler and flags
CC           := gcc
CFLAGS       := -Wall -Wextra -O3 -g
INCLUDES     := -I$(LIBOQS_NATIVE_DIR)/include -I$(SRC_DIR)
LDFLAGS      := -L$(LIBOQS_NATIVE_DIR)/lib
LDLIBS       := -loqs -lm -lpthread

# Source files
UTILS_SRC    := $(SRC_DIR)/utils/logger.c $(SRC_DIR)/utils/timing.c $(SRC_DIR)/utils/stats.c
UTILS_OBJ    := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(UTILS_SRC))

# Binaries
BENCHMARK_MLKEM := $(BIN_DIR)/benchmark_mlkem
BENCHMARK_MLDSA := $(BIN_DIR)/benchmark_mldsa
TEST_TIMING     := $(BIN_DIR)/test_timing
TEST_STATS      := $(BIN_DIR)/test_stats
TEST_MLKEM_CORRECTNESS := $(BIN_DIR)/test_mlkem_correctness
TEST_MLDSA_CORRECTNESS := $(BIN_DIR)/test_mldsa_correctness

# Lock file to prevent concurrent builds
BUILD_LOCK := $(BUILD_DIR)/.build.lock

# Timestamp files for tracking dependencies
NATIVE_TIMESTAMP  := $(LIBOQS_NATIVE_DIR)/.build_timestamp
ARM_TIMESTAMP     := $(LIBOQS_ARM_DIR)/.build_timestamp
RISCV_TIMESTAMP   := $(LIBOQS_RISCV_DIR)/.build_timestamp

# Python configuration
PYTHON := python3
VENV   := venv

# ============================================================================
# Main Targets
# ============================================================================

all: help

## Interactive Menu (Persistent TUI - SOLID: SRP)
menu:
	@echo "$(CYAN)Starting PQC Benchmarking Interactive Menu...$(RESET)"
	@./pqc-bench.sh

# Complete automatic setup (compile + tests)
setup-complete: build-native compile-benchmarks test-all
	@echo ""
	@echo "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "$(GREEN)Setup complete: liboqs compiled, benchmarks ready, tests passed$(RESET)"
	@echo "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(RESET)"
	@echo "  $(BLUE)make benchmark-mlkem$(RESET)  - Run ML-KEM benchmark"
	@echo "  $(BLUE)make benchmark-mldsa$(RESET)  - Run ML-DSA benchmark"
	@echo "  $(BLUE)make help$(RESET)             - Show all available commands"
	@echo ""

help:
	@echo ""
	@bash -c "source $(LIB_DIR)/banner-functions.sh && show_makefile_header"
	@echo ""
	@echo "$(MAGENTA)Interactive Menu:$(RESET)"
	@echo "  $(YELLOW)make menu$(RESET)          - Persistent interactive menu (recommended)"
	@echo ""
	@echo "$(GREEN)Setup Targets:$(RESET)"
	@echo "  $(YELLOW)make install$(RESET)       - Initial environment setup (QEMU, toolchains, Python)"
	@echo "  $(YELLOW)setup-complete$(RESET)     - Automatic setup (compile liboqs + benchmarks + tests)"
	@echo "  $(YELLOW)check-env$(RESET)          - Check environment configuration"
	@echo ""
	@echo "$(GREEN)Compilation Targets:$(RESET)"
	@echo "  $(YELLOW)build$(RESET)              - Compile liboqs for all architectures"
	@echo "  $(YELLOW)build-native$(RESET)       - Compile liboqs for native x86_64"
	@echo "  $(YELLOW)build-arm$(RESET)          - Cross-compile liboqs for ARM64"
	@echo "  $(YELLOW)build-riscv$(RESET)        - Cross-compile liboqs for RISC-V64"
	@echo ""
	@echo "$(GREEN)Testing Targets:$(RESET)"
	@echo "  $(YELLOW)test$(RESET)               - Run setup and compilation tests"
	@echo "  $(YELLOW)test-core-interfaces$(RESET) - Run core interface tests (no external dependencies)"
	@echo "  $(YELLOW)test-timing$(RESET)        - Run timing unit tests"
	@echo "  $(YELLOW)test-stats$(RESET)         - Run statistics unit tests"
	@echo "  $(YELLOW)test-mlkem$(RESET)         - Run ML-KEM correctness tests"
	@echo "  $(YELLOW)test-mldsa$(RESET)         - Run ML-DSA correctness tests"
	@echo "  $(YELLOW)test-all$(RESET)           - Run all unit tests"
	@echo "  $(YELLOW)verify$(RESET)             - Verify compiled binaries"
	@echo ""
	@echo "$(GREEN)Compilation Targets:$(RESET)"
	@echo "  $(YELLOW)compile-benchmarks$(RESET) - Compile all benchmarking programs"
	@echo "  $(YELLOW)clean-benchmarks$(RESET)   - Clean compiled binaries"
	@echo ""
	@echo "$(GREEN)Benchmarking Targets:$(RESET)"
	@echo "  $(YELLOW)run-benchmarks$(RESET)     - Run all benchmarks"
	@echo "  $(YELLOW)benchmark-mlkem$(RESET)    - Run ML-KEM benchmark (512, 768, 1024)"
	@echo "  $(YELLOW)benchmark-mldsa$(RESET)    - Run ML-DSA benchmark (44, 65, 87)"
	@echo ""
	@echo "$(GREEN)Automation Targets (Week 6):$(RESET)"
	@echo "  $(YELLOW)init-experiments$(RESET)   - Initialize experiment structure"
	@echo "  $(YELLOW)run-experiments$(RESET)    - Run complete experiment campaign"
	@echo "  $(YELLOW)resume-experiments$(RESET) - Resume experiments from checkpoint"
	@echo "  $(YELLOW)experiments-dry-run$(RESET) - Experiment simulation (does not execute)"
	@echo "  $(YELLOW)collect-metadata$(RESET)   - Collect system metadata"
	@echo "  $(YELLOW)validate-data$(RESET)      - Validate experimental data integrity"
	@echo ""
	@echo "$(GREEN)Analysis Targets:$(RESET)"
	@echo "  $(YELLOW)install-python-deps$(RESET) - Install Python dependencies (numpy, scipy, etc.)"
	@echo ""
	@echo "$(GREEN)Main Execution Targets:$(RESET)"
	@echo "  $(YELLOW)run-remote-arm64$(RESET)   - Run experiments on ARM64 VM (6 algorithms)"
	@echo "  $(YELLOW)run-remote-riscv64$(RESET) - Run experiments on RISC-V64 VM (6 algorithms)"
	@echo "  $(YELLOW)run-full-campaign$(RESET)  - Run complete campaign (54 experiments)"
	@echo "  $(YELLOW)validate-results$(RESET)   - Validate experimental results (checksums + completeness)"
	@echo "  $(YELLOW)backup-results$(RESET)     - Create incremental backup of results"
	@echo ""
	@echo "$(GREEN)Data Analysis Targets (Week 10):$(RESET)"
	@echo "  $(YELLOW)install-analysis-deps$(RESET) - Install Python dependencies (numpy, matplotlib, scipy)"
	@echo "  $(YELLOW)analyze-results$(RESET)    - Complete analysis (comparative + visualizations + stats)"
	@echo "  $(YELLOW)analyze-compare$(RESET)    - Comparative analysis only multi-architecture"
	@echo "  $(YELLOW)analyze-viz$(RESET)        - Visualization generation only"
	@echo "  $(YELLOW)analyze-stats$(RESET)      - Statistical tests only"
	@echo ""
	@echo "$(GREEN)Sizes and Overhead Targets (Week 11):$(RESET)"
	@echo "  $(YELLOW)compile-measure-sizes$(RESET) - Compile measure_sizes.c"
	@echo "  $(YELLOW)measure-sizes$(RESET)      - Measure PQC artifact sizes (keys, signatures, etc.)"
	@echo "  $(YELLOW)analyze-overhead$(RESET)   - Analyze TLS 1.3, X.509 and PKI storage overhead"
	@echo ""
	@echo "$(GREEN)Statistical Analysis Targets:$(RESET)"
	@echo "  $(YELLOW)analyze-statistical$(RESET) - Statistical analysis (t-test, ratios, CI)"
	@echo "  $(YELLOW)generate-visualizations$(RESET) - Generate charts (boxplots, heatmaps, violin plots)"
	@echo ""
	@echo "$(GREEN)Factor Analysis Targets (Week 14):$(RESET)"
	@echo "  $(YELLOW)analyze-performance-factors$(RESET) - Analyze performance factors (compiler, QEMU, bottlenecks)"
	@echo ""
	@echo "$(GREEN)Cleanup Targets:$(RESET)"
	@echo "  $(YELLOW)clean$(RESET)              - Clean liboqs builds"
	@echo "  $(YELLOW)clean-temp$(RESET)         - Clean temporary files (*.pyc, cache, coverage)"
	@echo "  $(YELLOW)clean-logs$(RESET)         - Clean old logs"
	@echo "  $(YELLOW)clean-all$(RESET)          - Complete cleanup (builds + data + temp)"
	@echo "  $(YELLOW)clean-deep$(RESET)         - Deep cleanup (includes generated results)"
	@echo ""

# ============================================================================
# Environment Validation
# ============================================================================

validate-env:
	$(call show_section,Validating Build Environment)
	@bash -c "source $(LIB_DIR)/common-functions.sh && validate_build_environment native"

# ============================================================================
# Setup and Verification
# ============================================================================

setup: install
	$(call show_section,Configuring Complete Environment)
	@./setup/setup-complete.sh

# Short alias for initial installation
install:
	@./setup/setup-complete.sh

check-env:
	$(call show_section,Verifying Environment Configuration)
	@./setup/verify-environment.sh

# ============================================================================
# Compilation
# ============================================================================

build: build-native build-arm build-riscv
	@echo ""
	@echo "$(GREEN)[OK] Complete compilation for all architectures$(RESET)"
	@echo ""

build-native: validate-env
	$(call show_section,Compiling liboqs for x86_64 (native))
	@./build/build-liboqs-native.sh
	@touch $(NATIVE_TIMESTAMP)

build-arm: build-native validate-env
	$(call show_section,Cross-compiling liboqs for ARM64 (AArch64))
	@./build/build-liboqs-arm.sh
	@touch $(ARM_TIMESTAMP)

build-riscv: build-native validate-env
	$(call show_section,Cross-compiling liboqs for RISC-V64)
	@./build/build-liboqs-riscv.sh
	@touch $(RISCV_TIMESTAMP)

# ============================================================================
# Testing and Verification
# ============================================================================

test: check-env
	$(call show_section,Running Setup Tests)
	@cd $(SRC_DIR)/tests && $(PYTHON) test_setup.py

verify:
	$(call show_section,Verifying Binaries and Algorithms)
	@echo ""
	@echo "$(YELLOW)[NATIVE - x86_64]$(RESET)"
	@if [ -f "$(LIBOQS_NATIVE_DIR)/lib/liboqs.so.0.10.0" ]; then \
		echo "$(GREEN)[OK] Library found:$(RESET)"; \
		file $(LIBOQS_NATIVE_DIR)/lib/liboqs.so.0.10.0 | grep -q "x86-64" && \
		echo "$(GREEN)[OK] Architecture: x86-64$(RESET)" || \
		echo "$(RED)[ERROR] Incorrect architecture$(RESET)"; \
		echo "$(GREEN)[OK] Algoritmos ML-KEM:$(RESET)"; \
		nm -D $(LIBOQS_NATIVE_DIR)/lib/liboqs.so | grep -c "ml_kem" || echo "0"; \
		echo "$(GREEN)[OK] Algoritmos ML-DSA:$(RESET)"; \
		nm -D $(LIBOQS_NATIVE_DIR)/lib/liboqs.so | grep -c "ml_dsa" || echo "0"; \
	else \
		echo "$(RED)[ERROR] Library not found$(RESET)"; \
	fi
	@echo ""
	@echo "$(YELLOW)[ARM64 - AArch64]$(RESET)"
	@if [ -f "$(LIBOQS_ARM_DIR)/lib/liboqs.so.0.10.0" ]; then \
		echo "$(GREEN)[OK] Library found:$(RESET)"; \
		file $(LIBOQS_ARM_DIR)/lib/liboqs.so.0.10.0 | grep -q "ARM aarch64" && \
		echo "$(GREEN)[OK] Architecture: ARM AArch64$(RESET)" || \
		echo "$(RED)[ERROR] Incorrect architecture$(RESET)"; \
	else \
		echo "$(RED)[ERROR] Library not found$(RESET)"; \
	fi
	@echo ""
	@echo "$(YELLOW)[RISC-V64]$(RESET)"
	@if [ -f "$(LIBOQS_RISCV_DIR)/lib/liboqs.so.0.10.0" ]; then \
		echo "$(GREEN)[OK] Library found:$(RESET)"; \
		file $(LIBOQS_RISCV_DIR)/lib/liboqs.so.0.10.0 | grep -q "RISC-V" && \
		echo "$(GREEN)[OK] Architecture: RISC-V$(RESET)" || \
		echo "$(RED)[ERROR] Incorrect architecture$(RESET)"; \
	else \
		echo "$(RED)[ERROR] Library not found$(RESET)"; \
	fi
	@echo ""

# ============================================================================
# Benchmarking
# ============================================================================

# Create necessary directories
dirs:
	@mkdir -p $(BIN_DIR) $(OBJ_DIR)/utils $(OBJ_DIR)/benchmarks $(OBJ_DIR)/tests

# Compile utility objects
$(OBJ_DIR)/utils/%.o: $(SRC_DIR)/utils/%.c | dirs
	@echo "$(CYAN)Compiling $<...$(RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile benchmark objects
$(OBJ_DIR)/benchmarks/%.o: $(SRC_DIR)/benchmarks/%.c | dirs
	@echo "$(CYAN)Compiling $<...$(RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile test objects
$(OBJ_DIR)/tests/%.o: $(SRC_DIR)/tests/%.c | dirs
	@echo "$(CYAN)Compiling $<...$(RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Link ML-KEM benchmark (refactored - uses generic benchmark engine)
$(BENCHMARK_MLKEM): $(UTILS_OBJ) $(OBJ_DIR)/benchmarks/benchmark_mlkem.o $(OBJ_DIR)/benchmarks/generic_benchmark.o $(OBJ_DIR)/adapters/liboqs_adapter.o $(OBJ_DIR)/core/provider_interface.o $(OBJ_DIR)/core/algorithm_interface.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@mkdir -p $(OBJ_DIR)/adapters $(OBJ_DIR)/core
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] ML-KEM benchmark compiled: $@$(RESET)"

# Link ML-DSA benchmark (refactored - uses generic benchmark engine)
$(BENCHMARK_MLDSA): $(UTILS_OBJ) $(OBJ_DIR)/benchmarks/benchmark_mldsa.o $(OBJ_DIR)/benchmarks/generic_benchmark.o $(OBJ_DIR)/adapters/liboqs_adapter.o $(OBJ_DIR)/core/provider_interface.o $(OBJ_DIR)/core/algorithm_interface.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@mkdir -p $(OBJ_DIR)/adapters $(OBJ_DIR)/core
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] ML-DSA benchmark compiled: $@$(RESET)"

# Compile all benchmarks
compile-benchmarks: build-native $(BENCHMARK_MLKEM) $(BENCHMARK_MLDSA)
	@echo ""
	@echo "$(GREEN)[OK] All benchmarks compiled$(RESET)"
	@echo ""

# Link test_timing
$(TEST_TIMING): $(UTILS_OBJ) $(OBJ_DIR)/tests/test_timing.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] Timing test compiled: $@$(RESET)"

# Link test_stats
$(TEST_STATS): $(UTILS_OBJ) $(OBJ_DIR)/tests/test_stats.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] Stats test compiled: $@$(RESET)"

# Link test_mlkem_correctness
$(TEST_MLKEM_CORRECTNESS): $(UTILS_OBJ) $(OBJ_DIR)/tests/test_mlkem_correctness.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] ML-KEM correctness test compiled: $@$(RESET)"

# Link test_mldsa_correctness
$(TEST_MLDSA_CORRECTNESS): $(UTILS_OBJ) $(OBJ_DIR)/tests/test_mldsa_correctness.o | dirs
	@echo "$(CYAN)Linking $@...$(RESET)"
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] ML-DSA correctness test compiled: $@$(RESET)"

# Run timing tests
test-timing: $(TEST_TIMING)
	$(call show_section,Running Unit Tests - Timing)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$$LD_LIBRARY_PATH $(TEST_TIMING)

# Run stats tests
test-stats: $(TEST_STATS)
	$(call show_section,Running Unit Tests - Stats)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$$LD_LIBRARY_PATH $(TEST_STATS)

# Run correctness tests
test-mlkem: $(TEST_MLKEM_CORRECTNESS)
	$(call show_section,Running Correctness Tests - ML-KEM)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$$LD_LIBRARY_PATH $(TEST_MLKEM_CORRECTNESS)

# Run ML-DSA correctness tests
test-mldsa: $(TEST_MLDSA_CORRECTNESS)
	$(call show_section,Running Correctness Tests - ML-DSA)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$$LD_LIBRARY_PATH $(TEST_MLDSA_CORRECTNESS)

# Run core interface tests
test-core-interfaces:
	$(call show_section,Running Core Interface Tests)
	@$(MAKE) -C $(SRC_DIR)/tests -f Makefile.core_tests test

# Compile and link liboqs adapter test
$(BIN_DIR)/test_liboqs_adapter: $(UTILS_OBJ) $(OBJ_DIR)/tests/test_liboqs_adapter.o $(OBJ_DIR)/adapters/liboqs_adapter.o $(OBJ_DIR)/core/provider_interface.o $(OBJ_DIR)/core/algorithm_interface.o | dirs
	@echo "$(CYAN)Linking test_liboqs_adapter...$(RESET)"
	@mkdir -p $(OBJ_DIR)/adapters $(OBJ_DIR)/core
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] Liboqs adapter test compiled: $@$(RESET)"

# Compile adapter objects
$(OBJ_DIR)/adapters/%.o: $(SRC_DIR)/adapters/%.c | dirs
	@mkdir -p $(OBJ_DIR)/adapters
	@echo "$(CYAN)Compiling $<...$(RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile core objects
$(OBJ_DIR)/core/%.o: $(SRC_DIR)/core/%.c | dirs
	@mkdir -p $(OBJ_DIR)/core
	@echo "$(CYAN)Compiling $<...$(RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Run liboqs adapter tests
test-liboqs-adapter: $(BIN_DIR)/test_liboqs_adapter
	$(call show_section,Running liboqs Adapter Tests)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$LD_LIBRARY_PATH $(BIN_DIR)/test_liboqs_adapter

# Compile and link provider abstraction property test
$(BIN_DIR)/test_provider_abstraction_property: $(UTILS_OBJ) $(OBJ_DIR)/tests/test_provider_abstraction_property.o $(OBJ_DIR)/adapters/liboqs_adapter.o $(OBJ_DIR)/core/provider_interface.o $(OBJ_DIR)/core/algorithm_interface.o $(OBJ_DIR)/benchmarks/generic_benchmark.o | dirs
	@echo "$(CYAN)Linking test_provider_abstraction_property...$(RESET)"
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@
	@echo "$(GREEN)[OK] Provider abstraction property test compiled: $@$(RESET)"

# Run provider abstraction property test
test-provider-abstraction: $(BIN_DIR)/test_provider_abstraction_property
	$(call show_section,Running Property Test - Provider Abstraction)
	@LD_LIBRARY_PATH=$(LIBOQS_NATIVE_DIR)/lib:$LD_LIBRARY_PATH $(BIN_DIR)/test_provider_abstraction_property

# Run all unit tests
test-all: test-core-interfaces test-timing test-stats test-mlkem test-mldsa test-liboqs-adapter test-provider-abstraction
	@echo ""
	@echo "$(GREEN)[OK] All unit tests completed$(RESET)"
	@echo ""

# Run ML-KEM benchmark
benchmark-mlkem: $(BENCHMARK_MLKEM)
	@$(SCRIPTS_DIR)/benchmark_mlkem_summary.sh

# Run ML-DSA benchmark
benchmark-mldsa: $(BENCHMARK_MLDSA)
	@$(SCRIPTS_DIR)/benchmark_mldsa_summary.sh
# Clean benchmark artifacts
clean-benchmarks:
	@echo "$(CYAN)Cleaning benchmarks...$(RESET)"
	@rm -rf $(BIN_DIR) $(OBJ_DIR)
	@echo "$(GREEN)[OK] Benchmarks cleaned$(RESET)"

run-benchmarks: benchmark-mlkem benchmark-mldsa
	@echo ""
	@echo "$(GREEN)[OK] Benchmarks completed$(RESET)"
	@echo ""

# ============================================================================
# Cleanup
# ============================================================================

clean:
	$(call show_section,Cleaning liboqs builds)
	@rm -rf $(BUILD_DIR)/liboqs/build-*
	@rm -f $(NATIVE_TIMESTAMP) $(ARM_TIMESTAMP) $(RISCV_TIMESTAMP)
	@rm -f $(BUILD_LOCK)
	@echo "$(GREEN)[OK] Cleanup completed$(RESET)"

clean-logs:
	@echo "$(CYAN)Cleaning old logs...$(RESET)"
	@find $(LOG_DIR) -name "build-*.log" -type f -mtime +30 -delete 2>/dev/null || true
	@echo "$(GREEN)[OK] Old logs removed$(RESET)"

clean-temp:
	@echo "$(CYAN)Cleaning temporary files...$(RESET)"
	@bash $(SCRIPTS_DIR)/clean_project.sh
	@echo "$(GREEN)[OK] Temporary files removed$(RESET)"

clean-all: clean clean-logs clean-benchmarks clean-temp
	$(call show_section,Complete project cleanup)
	@rm -rf $(DATA_DIR)/raw/*
	@rm -rf $(DATA_DIR)/processed/*
	@rm -rf $(RESULTS_DIR)/*
	@rm -rf $(VENV)
	@echo "$(GREEN)[OK] Complete cleanup done$(RESET)"

clean-deep:
	@echo "$(YELLOW)Deep cleanup (includes builds and results)...$(RESET)"
	@bash $(SCRIPTS_DIR)/clean_project.sh --all
	@echo "$(GREEN)[OK] Deep cleanup completed$(RESET)"

# ============================================================================
# Experiment Automation
# ============================================================================

init-experiments:
	$(call show_section,Initializing Experiment Structure)
	@$(SCRIPTS_DIR)/experiment_config.sh --init

collect-metadata:
	$(call show_section,Collecting System Metadata)
	@$(SCRIPTS_DIR)/collect_metadata.sh

validate-data:
	$(call show_section,Validating Experimental Data)
	@$(PYTHON) $(SCRIPTS_DIR)/validate_data.py $(DATA_DIR)/raw --recursive

## Run complete campaign (SOLID: Dependency Inversion - auto-compiles if necessary)
run-experiments: compile-benchmarks
	$(call show_section,Running Complete Experiment Campaign)
	@$(SCRIPTS_DIR)/run_experiments.sh

## Reanudar experimentos desde checkpoint (SOLID: Dependency Inversion - auto-compila si es necesario)
resume-experiments: compile-benchmarks
	$(call show_section,Resuming Experiments from Checkpoint)
	@$(SCRIPTS_DIR)/run_experiments.sh --resume

## Experiment simulation (SOLID: Dependency Inversion - auto-compiles if necessary)
experiments-dry-run: compile-benchmarks
	$(call show_section,Experiment Simulation (Dry Run))
	@$(SCRIPTS_DIR)/run_experiments.sh --dry-run

# ============================================================================
# Analysis and Validation
# ============================================================================

install-python-deps:
	$(call show_section,Installing Python Dependencies)
	@$(PYTHON) -m pip install --upgrade pip
	@$(PYTHON) -m pip install numpy scipy matplotlib jupyter pandas

# ============================================================================
# Main Experiment Execution
# ============================================================================

run-remote-arm64:
	$(call show_section,Running Experiments on ARM64 VM)
	@$(SCRIPTS_DIR)/run_remote_experiments.sh arm64

run-remote-riscv64:
	$(call show_section,Running Experiments on RISC-V64 VM)
	@$(SCRIPTS_DIR)/run_remote_experiments.sh riscv64

validate-results:
	$(call show_section,Validating Experimental Results)
	@$(SCRIPTS_DIR)/validate_results.sh $(DATA_DIR)/raw --report

backup-results:
	$(call show_section,Creating Incremental Backup)
	@$(SCRIPTS_DIR)/backup_results.sh

run-full-campaign: compile-benchmarks run-experiments run-remote-arm64 run-remote-riscv64
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)   Complete Experimental Campaign Finished$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(CYAN)Validating results...$(RESET)"
	@$(MAKE) validate-results
	@echo ""
	@echo "$(CYAN)Creating backup...$(RESET)"
	@$(MAKE) backup-results
	@echo ""
	@echo "$(GREEN)✓ All experiments completed and validated$(RESET)"

# ============================================================================
# Project Information
# ============================================================================

info:
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║             Project Information                           ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)Project:$(RESET)        Benchmarks PQC - ML-KEM & ML-DSA"
	@echo "$(GREEN)Institution:$(RESET)     National University of San Antonio Abad del Cusco"
	@echo "$(GREEN)Objective:$(RESET)        Compare performance of post-quantum cryptography"
	@echo "                 on ARM vs RISC-V architectures"
	@echo ""
	@echo "$(GREEN)Algorithms:$(RESET)"
	@echo "  • ML-KEM (FIPS 203): 512, 768, 1024 bits"
	@echo "  • ML-DSA (FIPS 204): 44, 65, 87 bits"
	@echo ""
	@echo "$(GREEN)Architectures:$(RESET)"
	@echo "  • x86_64    (native baseline)"
	@echo "  • ARM64     (AArch64 Cortex-A72)"
	@echo "  • RISC-V64  (RV64GC)"
	@echo ""
	@echo "$(GREEN)Tools:$(RESET)"
	@echo "  • liboqs 0.10.0"
	@echo "  • QEMU 8.2.2"
	@echo "  • GCC 13.3.0"
	@echo ""

# ============================================================================
# Data Analysis
# ============================================================================

## Install Python analysis dependencies
install-analysis-deps:
	@echo "$(CYAN)Installing analysis dependencies...$(RESET)"
	@python3 -m pip install --user --break-system-packages --quiet numpy matplotlib scipy pandas seaborn 2>/dev/null || \
		echo "$(YELLOW)Note: Some dependencies may already be installed$(RESET)"

## Run complete analysis of results
analyze-results: install-analysis-deps
	@echo "$(CYAN)Running complete analysis...$(RESET)"
	@./scripts/analyze_results.sh

## Comparative analysis only
analyze-compare: install-analysis-deps
	@echo "$(CYAN)Running comparative analysis...$(RESET)"
	@./scripts/analyze_results.sh --compare-only

## Visualization generation only
analyze-viz: install-analysis-deps
	@echo "$(CYAN)Generating visualizations...$(RESET)"
	@./scripts/analyze_results.sh --viz-only

## Statistical tests only
analyze-stats: install-analysis-deps
	@echo "$(CYAN)Running statistical tests...$(RESET)"
	@./scripts/analyze_results.sh --stats-only

# ============================================================================
# Deep Statistical Analysis
# ============================================================================

## Verificar que existan datos experimentales
check-data-raw:
	@if [ ! -d "data/raw" ] || [ -z "$$(find data/raw -name '*.json' 2>/dev/null)" ]; then \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"; \
		echo "$(RED)ERROR: No experimental data found in data/raw/$(RESET)"; \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"; \
		echo ""; \
		echo "$(YELLOW)This command requires complete experimental data.$(RESET)"; \
		echo ""; \
		echo "$(CYAN)Option 1 - Run full experimental campaign:$(RESET)"; \
		echo "  $(BLUE)make run-experiments$(RESET)"; \
		echo ""; \
		echo "$(CYAN)Option 2 - Use current benchmark results for testing:$(RESET)"; \
		echo "  $(BLUE)mkdir -p data/raw$(RESET)"; \
		echo "  $(BLUE)cp results/mlkem_results.json data/raw/$(RESET)"; \
		echo "  $(BLUE)cp results/mldsa_results.json data/raw/$(RESET)"; \
		echo "  $(BLUE)make analyze-statistical$(RESET)"; \
		echo "  $(BLUE)make generate-visualizations$(RESET)"; \
		echo ""; \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"; \
		exit 1; \
	fi

## Run statistical analysis (t-test, ratios, CI)
analyze-statistical: install-analysis-deps
	@echo "$(CYAN)Running statistical analysis...$(RESET)"
	@python3 src/analysis/statistical_analysis.py
	@echo "$(GREEN)✓ Results saved in results/analysis/$(RESET)"

## Generate visualizations (boxplots, heatmaps, violin plots)
generate-visualizations: install-analysis-deps
	@echo "$(CYAN)Generating visualizations...$(RESET)"
	@python3 src/analysis/generate_figures.py
	@echo "$(GREEN)✓ Charts saved in results/figures/$(RESET)"

# ============================================================================
# Sizes and Overhead
# ============================================================================

## Compilar measure_sizes.c (SOLID: Dependency Inversion - checks dependencies first)
compile-measure-sizes:
	@echo "$(CYAN)Compiling measure_sizes.c...$(RESET)"
	@if [ ! -f "$(SRC_DIR)/benchmarks/measure_sizes.c" ]; then \
		echo "$(YELLOW)Warning: measure_sizes.c not found, skipping...$(RESET)"; \
		echo "$(YELLOW)This is an optional feature for measuring artifact sizes$(RESET)"; \
		exit 0; \
	fi
	@mkdir -p $(BUILD_DIR)/bin
	@if [ ! -d "$(LIBOQS_DIR)/build-native/include/oqs" ]; then \
		echo "$(YELLOW)Warning: liboqs headers not found, compiling liboqs first...$(RESET)"; \
		$(MAKE) build-native; \
	fi
	@gcc -O3 -Wall -Wextra \
		-I$(LIBOQS_DIR)/build-native/include \
		-L$(LIBOQS_DIR)/build-native/lib \
		-Wl,-rpath,$(LIBOQS_DIR)/build-native/lib \
		$(SRC_DIR)/benchmarks/measure_sizes.c \
		$(SRC_DIR)/utils/logging.c \
		$(SRC_DIR)/utils/timing.c \
		$(SRC_DIR)/utils/stats.c \
		-loqs -lm -o $(BUILD_DIR)/bin/measure_sizes
	@echo "$(GREEN)✓ measure_sizes compiled: $(BUILD_DIR)/bin/measure_sizes$(RESET)"

## Measure PQC artifact sizes and analyze overhead
measure-sizes: compile-measure-sizes
	@echo "$(CYAN)Running size measurement and overhead analysis...$(RESET)"
	@./scripts/measure_all_sizes.sh

## Overhead analysis only (requires previous measure-sizes)
analyze-overhead:
	@echo "$(CYAN)Running overhead analysis...$(RESET)"
	@python3 analysis/overhead_analysis.py

# ============================================================================
# PKI Throughput Modeling
# ============================================================================
# Performance Factors Analysis
# ============================================================================

## Analyze performance factors (compiler, QEMU, algorithmic bottlenecks)
analyze-performance-factors:
	$(call show_section,Analyzing Performance Factors)
	@mkdir -p results/analysis
	python3 analysis/performance_factors.py \
		--input data/processed/processed_data.json \
		--output results/analysis/performance_factors.json \
		--markdown results/analysis/performance_factors.md
	@echo "$(GREEN)✓ Complete factor analysis$(RESET)"
	@echo ""
	@echo "$(CYAN)Generated outputs:$(RESET)"
	@echo "  • JSON analysis:     results/analysis/performance_factors.json"
	@echo "  • Markdown report:  results/analysis/performance_factors.md"
	@echo ""
	@echo "$(YELLOW)To review:$(RESET)"
	@echo "  $ cat results/analysis/performance_factors.md"
	@echo "  $ less results/analysis/performance_factors.json"

