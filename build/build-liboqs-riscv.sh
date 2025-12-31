#!/bin/bash
################################################################################
# Build Script: liboqs RISC-V64
# Cross-compiles liboqs for RISC-V64 architecture with full validation
################################################################################

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common-functions.sh"

# Setup error handling
setup_error_handling

# Ensure build lock is released on exit
trap release_build_lock EXIT

################################################################################
# Main Build Process
################################################################################

main() {
    log_info "========================================="
    log_info "Starting liboqs RISC-V64 Build"
    log_info "========================================="
    log_info "Log file: ${GLOBAL_LOG_FILE}"
    
    # Validate environment
    validate_build_environment "riscv" || exit 1
    
    # Clean old logs
    cleanup_old_logs
    
    # Create build directory
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    
    # Clone or update repository
    clone_or_update_repo \
        "${LIBOQS_REPO}" \
        "${LIBOQS_DIR}" \
        "${LIBOQS_VERSION}"
    
    cd "${LIBOQS_DIR}"
    
    # Clean previous build
    if [ -d "build-riscv64" ]; then
        log_info "Cleaning previous build..."
        rm -rf build-riscv64
    fi
    
    mkdir -p build-riscv64
    
    # Create toolchain file
    local toolchain_file="toolchain-riscv64.cmake"
    log_info "Creating RISC-V64 toolchain file..."
    cat > "$toolchain_file" <<'EOF'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

set(CMAKE_C_COMPILER riscv64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER riscv64-linux-gnu-g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Flags for RISC-V64 with GC extensions (General + Compressed)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=rv64gc")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=rv64gc")
EOF
    
    # Configure with CMake
    execute_logged "Configuring CMake for RISC-V64" \
        cmake -S . -B build-riscv64 \
            -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
            -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
            -DBUILD_SHARED_LIBS=ON \
            -DOQS_USE_OPENSSL=OFF \
            -DOQS_BUILD_ONLY_LIB=ON \
            -DOQS_DIST_BUILD=OFF
    
    # Compile
    execute_logged "Compiling liboqs for RISC-V64 (using ${PARALLEL_JOBS} cores)" \
        cmake --build build-riscv64 --parallel "${PARALLEL_JOBS}"
    
    # Verify binary
    local lib_path="build-riscv64/lib/liboqs.so"
    verify_binary_arch "$lib_path" "riscv" || exit 1
    
    # Display info
    log_info "Build artifacts:"
    ls -lh build-riscv64/lib/liboqs.so* | tee -a "${GLOBAL_LOG_FILE}"
    
    log_ok "========================================="
    log_ok "RISC-V64 build completed successfully"
    log_ok "========================================="
}

# Execute main function
main "$@"
