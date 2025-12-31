#!/bin/bash
################################################################################
# Build Configuration - Centralized Settings
# All build scripts source this file for consistent configuration
################################################################################

# Project Information
export PROJECT_NAME="Benchmarks-PQC"
export PROJECT_VERSION="0.1.0"
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# liboqs Configuration
export LIBOQS_VERSION="0.15.0"
export LIBOQS_REPO="https://github.com/open-quantum-safe/liboqs.git"

# Directory Structure
export BUILD_DIR="${PROJECT_ROOT}/build"
export LIBOQS_DIR="${BUILD_DIR}/liboqs"
export LIBOQS_NATIVE_DIR="${LIBOQS_DIR}/build-native"
export LIBOQS_ARM_DIR="${LIBOQS_DIR}/build-arm64"
export LIBOQS_RISCV_DIR="${LIBOQS_DIR}/build-riscv64"
export LOG_DIR="${BUILD_DIR}/logs"
export BIN_DIR="${PROJECT_ROOT}/bin"

# Compiler Configuration
export NATIVE_CC="gcc"
export NATIVE_CXX="g++"
export ARM_CC="aarch64-linux-gnu-gcc"
export ARM_CXX="aarch64-linux-gnu-g++"
export RISCV_CC="riscv64-linux-gnu-gcc"
export RISCV_CXX="riscv64-linux-gnu-g++"

# Build Flags
export CMAKE_BUILD_TYPE="Release"
export PARALLEL_JOBS="$(nproc)"

# ARM Optimization Flags
export ARM_ARCH_FLAGS="-march=armv8-a+crc -mtune=cortex-a72"

# RISC-V Optimization Flags
export RISCV_ARCH_FLAGS="-march=rv64gc"

# Minimum Requirements
export MIN_DISK_SPACE_GB=10
export MIN_RAM_GB=4
export MIN_GCC_VERSION="12.0.0"
export MIN_CMAKE_VERSION="3.22.0"

# Logging Configuration
export LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
export LOG_TIMESTAMP_FORMAT="+%Y-%m-%d %H:%M:%S"
export LOG_RETENTION_DAYS=30

# Colors for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_RESET='\033[0m'

# Ensure log directory exists
mkdir -p "${LOG_DIR}"
