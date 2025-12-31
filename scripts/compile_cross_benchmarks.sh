#!/bin/bash
# ============================================================================
# Cross-Compile Benchmarks for ARM64 and RISC-V64
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

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║        Cross-Compiling Benchmarks for ARM64 & RISC-V64        ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Create output directories
mkdir -p "$PROJECT_ROOT/build/bin-arm64"
mkdir -p "$PROJECT_ROOT/build/bin-riscv64"
mkdir -p "$PROJECT_ROOT/build/obj-arm64"
mkdir -p "$PROJECT_ROOT/build/obj-riscv64"

# Source files
SRC_DIR="$PROJECT_ROOT/src"
UTILS_SRC="$SRC_DIR/utils/logger.c $SRC_DIR/utils/timing.c $SRC_DIR/utils/stats.c"
CORE_SRC="$SRC_DIR/core/provider_interface.c $SRC_DIR/core/algorithm_interface.c"
ADAPTER_SRC="$SRC_DIR/adapters/liboqs_adapter.c"
GENERIC_SRC="$SRC_DIR/benchmarks/generic_benchmark.c"

# Compile for ARM64
echo -e "${YELLOW}Compiling for ARM64...${RESET}"

ARM64_CC="aarch64-linux-gnu-gcc"
ARM64_CFLAGS="-O3 -Wall -Wextra -I$PROJECT_ROOT/build/liboqs/build-arm64/include -I$SRC_DIR"
ARM64_LDFLAGS="-L$PROJECT_ROOT/build/liboqs/build-arm64/lib"
ARM64_LDLIBS="-loqs -lm -lpthread"

# Compile ML-KEM benchmark for ARM64
echo -e "  ${BLUE}→${RESET} benchmark_mlkem (ARM64)"
$ARM64_CC $ARM64_CFLAGS \
    $UTILS_SRC $CORE_SRC $ADAPTER_SRC $GENERIC_SRC \
    $SRC_DIR/benchmarks/benchmark_mlkem.c \
    $ARM64_LDFLAGS $ARM64_LDLIBS \
    -o "$PROJECT_ROOT/build/bin-arm64/benchmark_mlkem"

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✓ Compiled successfully${RESET}"
else
    echo -e "    ${RED}✗ Compilation failed${RESET}"
    exit 1
fi

# Compile ML-DSA benchmark for ARM64
echo -e "  ${BLUE}→${RESET} benchmark_mldsa (ARM64)"
$ARM64_CC $ARM64_CFLAGS \
    $UTILS_SRC $CORE_SRC $ADAPTER_SRC $GENERIC_SRC \
    $SRC_DIR/benchmarks/benchmark_mldsa.c \
    $ARM64_LDFLAGS $ARM64_LDLIBS \
    -o "$PROJECT_ROOT/build/bin-arm64/benchmark_mldsa"

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✓ Compiled successfully${RESET}"
else
    echo -e "    ${RED}✗ Compilation failed${RESET}"
    exit 1
fi

echo ""

# Compile for RISC-V64
echo -e "${YELLOW}Compiling for RISC-V64...${RESET}"

RISCV64_CC="riscv64-linux-gnu-gcc"
RISCV64_CFLAGS="-O3 -Wall -Wextra -I$PROJECT_ROOT/build/liboqs/build-riscv64/include -I$SRC_DIR"
RISCV64_LDFLAGS="-L$PROJECT_ROOT/build/liboqs/build-riscv64/lib"
RISCV64_LDLIBS="-loqs -lm -lpthread"

# Compile ML-KEM benchmark for RISC-V64
echo -e "  ${BLUE}→${RESET} benchmark_mlkem (RISC-V64)"
$RISCV64_CC $RISCV64_CFLAGS \
    $UTILS_SRC $CORE_SRC $ADAPTER_SRC $GENERIC_SRC \
    $SRC_DIR/benchmarks/benchmark_mlkem.c \
    $RISCV64_LDFLAGS $RISCV64_LDLIBS \
    -o "$PROJECT_ROOT/build/bin-riscv64/benchmark_mlkem"

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✓ Compiled successfully${RESET}"
else
    echo -e "    ${RED}✗ Compilation failed${RESET}"
    exit 1
fi

# Compile ML-DSA benchmark for RISC-V64
echo -e "  ${BLUE}→${RESET} benchmark_mldsa (RISC-V64)"
$RISCV64_CC $RISCV64_CFLAGS \
    $UTILS_SRC $CORE_SRC $ADAPTER_SRC $GENERIC_SRC \
    $SRC_DIR/benchmarks/benchmark_mldsa.c \
    $RISCV64_LDFLAGS $RISCV64_LDLIBS \
    -o "$PROJECT_ROOT/build/bin-riscv64/benchmark_mldsa"

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✓ Compiled successfully${RESET}"
else
    echo -e "    ${RED}✗ Compilation failed${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║           Cross-Compilation Completed Successfully            ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Binaries created:${RESET}"
echo -e "  ARM64:"
ls -lh "$PROJECT_ROOT/build/bin-arm64/"
echo ""
echo -e "  RISC-V64:"
ls -lh "$PROJECT_ROOT/build/bin-riscv64/"
echo ""
echo -e "${YELLOW}Next step: Run benchmarks under QEMU${RESET}"
echo -e "  ${BLUE}qemu-aarch64-static -L /usr/aarch64-linux-gnu build/bin-arm64/benchmark_mlkem${RESET}"
echo -e "  ${BLUE}qemu-riscv64-static -L /usr/riscv64-linux-gnu build/bin-riscv64/benchmark_mlkem${RESET}"
