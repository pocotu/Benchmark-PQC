#!/bin/bash
# ============================================================================
# Run All Benchmarks under QEMU for ARM64 and RISC-V64
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Configuration
ITERATIONS=${ITERATIONS:-10000}
WARMUP=${WARMUP:-1000}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║          Running All Benchmarks under QEMU Emulation          ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check prerequisites
check_prerequisites() {
    local missing=0
    
    echo -e "${BLUE}Checking prerequisites...${RESET}"
    echo ""
    
    # Check QEMU
    if ! command -v qemu-aarch64-static &> /dev/null; then
        echo -e "  ${RED}✗${RESET} qemu-aarch64-static not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} qemu-aarch64-static"
    fi
    
    if ! command -v qemu-riscv64-static &> /dev/null; then
        echo -e "  ${RED}✗${RESET} qemu-riscv64-static not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} qemu-riscv64-static"
    fi
    
    # Check ARM64 binaries
    if [ ! -f "$PROJECT_ROOT/build/bin-arm64/benchmark_mlkem" ]; then
        echo -e "  ${RED}✗${RESET} ARM64 benchmark_mlkem not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} ARM64 benchmark_mlkem"
    fi
    
    if [ ! -f "$PROJECT_ROOT/build/bin-arm64/benchmark_mldsa" ]; then
        echo -e "  ${RED}✗${RESET} ARM64 benchmark_mldsa not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} ARM64 benchmark_mldsa"
    fi
    
    # Check RISC-V64 binaries
    if [ ! -f "$PROJECT_ROOT/build/bin-riscv64/benchmark_mlkem" ]; then
        echo -e "  ${RED}✗${RESET} RISC-V64 benchmark_mlkem not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} RISC-V64 benchmark_mlkem"
    fi
    
    if [ ! -f "$PROJECT_ROOT/build/bin-riscv64/benchmark_mldsa" ]; then
        echo -e "  ${RED}✗${RESET} RISC-V64 benchmark_mldsa not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} RISC-V64 benchmark_mldsa"
    fi
    
    # Check liboqs libraries
    if [ ! -f "$PROJECT_ROOT/build/liboqs/build-arm64/lib/liboqs.so" ]; then
        echo -e "  ${RED}✗${RESET} liboqs ARM64 library not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} liboqs ARM64 library"
    fi
    
    if [ ! -f "$PROJECT_ROOT/build/liboqs/build-riscv64/lib/liboqs.so" ]; then
        echo -e "  ${RED}✗${RESET} liboqs RISC-V64 library not found"
        missing=1
    else
        echo -e "  ${GREEN}✓${RESET} liboqs RISC-V64 library"
    fi
    
    echo ""
    
    if [ $missing -eq 1 ]; then
        echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║              Missing Prerequisites                             ║${RESET}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${YELLOW}To build cross-compiled binaries, run:${RESET}"
        echo ""
        echo -e "  ${CYAN}# 1. Build liboqs for ARM64 and RISC-V64 (takes ~15 min each)${RESET}"
        echo -e "  ${BLUE}make build-arm${RESET}"
        echo -e "  ${BLUE}make build-riscv${RESET}"
        echo ""
        echo -e "  ${CYAN}# 2. Cross-compile benchmarks${RESET}"
        echo -e "  ${BLUE}./scripts/compile_cross_benchmarks.sh${RESET}"
        echo ""
        echo -e "  ${CYAN}# 3. Run QEMU benchmarks${RESET}"
        echo -e "  ${BLUE}./scripts/run_all_qemu_benchmarks.sh${RESET}"
        echo ""
        echo -e "${YELLOW}Note: Existing experimental data is available in data/raw/${RESET}"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites satisfied!${RESET}"
    echo ""
}

check_prerequisites

echo -e "${BLUE}Configuration:${RESET}"
echo -e "  Iterations: $ITERATIONS"
echo -e "  Warmup: $WARMUP"
echo -e "  Timestamp: $TIMESTAMP"
echo ""

# Create output directories
mkdir -p "$PROJECT_ROOT/data/raw/arm64/mlkem"
mkdir -p "$PROJECT_ROOT/data/raw/arm64/mldsa"
mkdir -p "$PROJECT_ROOT/data/raw/riscv64/mlkem"
mkdir -p "$PROJECT_ROOT/data/raw/riscv64/mldsa"

# Function to run benchmark
run_benchmark() {
    local arch="$1"
    local algo="$2"
    local qemu_bin="$3"
    local sysroot="$4"
    local lib_path="$5"
    local bin_path="$6"
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}Running: $arch / $algo${RESET}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
    
    local output_dir="$PROJECT_ROOT/data/raw/$arch/$algo"
    local json_file="$output_dir/${algo}_${TIMESTAMP}.json"
    local csv_file="$output_dir/${algo}_${TIMESTAMP}.csv"
    
    echo -e "${BLUE}Output:${RESET}"
    echo -e "  JSON: $json_file"
    echo -e "  CSV: $csv_file"
    echo ""
    
    # Run benchmark
    $qemu_bin -L $sysroot -E LD_LIBRARY_PATH=$lib_path \
        $bin_path \
        -i $ITERATIONS \
        -w $WARMUP \
        -r \
        -j "$json_file" \
        -c "$csv_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Completed successfully${RESET}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Failed${RESET}"
        echo ""
        return 1
    fi
}

# Track results
TOTAL=0
SUCCESS=0
FAILED=0

# ARM64 Benchmarks
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                    ARM64 Benchmarks (QEMU)                     ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

TOTAL=$((TOTAL + 2))

# ML-KEM ARM64
if run_benchmark "arm64" "mlkem" "qemu-aarch64-static" "/usr/aarch64-linux-gnu" \
    "$PROJECT_ROOT/build/liboqs/build-arm64/lib" \
    "$PROJECT_ROOT/build/bin-arm64/benchmark_mlkem"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi

# ML-DSA ARM64
if run_benchmark "arm64" "mldsa" "qemu-aarch64-static" "/usr/aarch64-linux-gnu" \
    "$PROJECT_ROOT/build/liboqs/build-arm64/lib" \
    "$PROJECT_ROOT/build/bin-arm64/benchmark_mldsa"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi

# RISC-V64 Benchmarks
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                  RISC-V64 Benchmarks (QEMU)                    ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

TOTAL=$((TOTAL + 2))

# ML-KEM RISC-V64
if run_benchmark "riscv64" "mlkem" "qemu-riscv64-static" "/usr/riscv64-linux-gnu" \
    "$PROJECT_ROOT/build/liboqs/build-riscv64/lib" \
    "$PROJECT_ROOT/build/bin-riscv64/benchmark_mlkem"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi

# ML-DSA RISC-V64
if run_benchmark "riscv64" "mldsa" "qemu-riscv64-static" "/usr/riscv64-linux-gnu" \
    "$PROJECT_ROOT/build/liboqs/build-riscv64/lib" \
    "$PROJECT_ROOT/build/bin-riscv64/benchmark_mldsa"; then
    SUCCESS=$((SUCCESS + 1))
else
    FAILED=$((FAILED + 1))
fi

# Summary
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                      Benchmark Summary                         ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BLUE}Total benchmarks:${RESET} $TOTAL"
echo -e "${GREEN}Successful:${RESET} $SUCCESS"
echo -e "${RED}Failed:${RESET} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║          All Benchmarks Completed Successfully! 🎉            ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${RESET}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║            Some Benchmarks Failed - Check Logs                 ║${RESET}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${RESET}"
    exit 1
fi
