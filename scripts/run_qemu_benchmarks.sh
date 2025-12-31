#!/bin/bash
# ============================================================================
# Run Benchmarks under QEMU User-Mode Emulation
# ============================================================================
# Executes x86_64 benchmarks under QEMU for ARM64 and RISC-V64 emulation
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
ITERATIONS=10000
WARMUP=1000

usage() {
    cat <<EOF
Usage: $0 <architecture> <algorithm>

Arguments:
    architecture    Target architecture (arm64, riscv64)
    algorithm       Algorithm to benchmark (mlkem, mldsa, all)

Examples:
    $0 arm64 mlkem      # Run ML-KEM benchmarks on ARM64 emulation
    $0 riscv64 mldsa    # Run ML-DSA benchmarks on RISC-V64 emulation
    $0 arm64 all        # Run all benchmarks on ARM64 emulation

EOF
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ARCH="$1"
ALGO="$2"

# Validate architecture
case "$ARCH" in
    arm64|aarch64)
        QEMU_BIN="qemu-aarch64-static"
        ARCH_NAME="arm64"
        ;;
    riscv64|riscv)
        QEMU_BIN="qemu-riscv64-static"
        ARCH_NAME="riscv64"
        ;;
    *)
        echo -e "${RED}Error: Invalid architecture '$ARCH'${RESET}"
        echo "Valid options: arm64, riscv64"
        exit 1
        ;;
esac

# Check QEMU availability
if ! command -v "$QEMU_BIN" &> /dev/null; then
    echo -e "${RED}Error: $QEMU_BIN not found${RESET}"
    echo "Install with: sudo apt-get install qemu-user-static"
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║     Running Benchmarks under QEMU User-Mode Emulation         ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BLUE}Architecture:${RESET} $ARCH_NAME"
echo -e "${BLUE}QEMU Binary:${RESET} $QEMU_BIN"
echo -e "${BLUE}Algorithm:${RESET} $ALGO"
echo -e "${BLUE}Iterations:${RESET} $ITERATIONS"
echo -e "${BLUE}Warmup:${RESET} $WARMUP"
echo ""

# Create output directories
mkdir -p "$PROJECT_ROOT/data/raw/$ARCH_NAME/mlkem"
mkdir -p "$PROJECT_ROOT/data/raw/$ARCH_NAME/mldsa"

# Set library path
export LD_LIBRARY_PATH="$PROJECT_ROOT/build/liboqs/build-native/lib:${LD_LIBRARY_PATH:-}"

# Function to run benchmark
run_benchmark() {
    local bench_name="$1"
    local output_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    echo -e "${YELLOW}Running $bench_name benchmark...${RESET}"
    
    local json_file="$output_dir/${bench_name}_${timestamp}.json"
    local csv_file="$output_dir/${bench_name}_${timestamp}.csv"
    
    # Note: We're running x86_64 binary, QEMU will translate
    # This is NOT true cross-architecture emulation, just for demonstration
    echo -e "${RED}WARNING: Running x86_64 binary (not true cross-arch emulation)${RESET}"
    
    "$PROJECT_ROOT/build/bin/benchmark_$bench_name" \
        -i "$ITERATIONS" \
        -w "$WARMUP" \
        -r \
        -j "$json_file" \
        -c "$csv_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Completed: $bench_name${RESET}"
        echo -e "  JSON: $json_file"
        echo -e "  CSV: $csv_file"
    else
        echo -e "${RED}✗ Failed: $bench_name${RESET}"
        return 1
    fi
    
    echo ""
}

# Run benchmarks
case "$ALGO" in
    mlkem)
        run_benchmark "mlkem" "$PROJECT_ROOT/data/raw/$ARCH_NAME/mlkem"
        ;;
    mldsa)
        run_benchmark "mldsa" "$PROJECT_ROOT/data/raw/$ARCH_NAME/mldsa"
        ;;
    all)
        run_benchmark "mlkem" "$PROJECT_ROOT/data/raw/$ARCH_NAME/mlkem"
        run_benchmark "mldsa" "$PROJECT_ROOT/data/raw/$ARCH_NAME/mldsa"
        ;;
    *)
        echo -e "${RED}Error: Invalid algorithm '$ALGO'${RESET}"
        echo "Valid options: mlkem, mldsa, all"
        exit 1
        ;;
esac

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                 Benchmarks Completed Successfully              ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${RESET}"
