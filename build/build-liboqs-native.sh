#!/bin/bash
################################################################################
# Build Script: liboqs Native (x86_64)
# Compiles liboqs for native x86_64 architecture with full validation
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
    log_info "Starting liboqs Native Build (x86_64)"
    log_info "========================================="
    log_info "Log file: ${GLOBAL_LOG_FILE}"
    
    # Validate environment
    validate_build_environment "native" || exit 1
    
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
    if [ -d "build-native" ]; then
        log_info "Cleaning previous build..."
        rm -rf build-native
    fi
    
    mkdir -p build-native
    
    # Configure with CMake
    execute_logged "Configuring CMake for x86_64" \
        cmake -S . -B build-native \
            -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
            -DBUILD_SHARED_LIBS=ON \
            -DOQS_USE_OPENSSL=ON \
            -DOQS_BUILD_ONLY_LIB=ON \
            -DOQS_DIST_BUILD=OFF
    
    # Compile
    execute_logged "Compiling liboqs (using ${PARALLEL_JOBS} cores)" \
        cmake --build build-native --parallel "${PARALLEL_JOBS}"
    
    # Verify binary
    local lib_path="build-native/lib/liboqs.so"
    verify_binary_arch "$lib_path" "native" || exit 1
    
    # Display info
    log_info "Build artifacts:"
    ls -lh build-native/lib/liboqs.so* | tee -a "${GLOBAL_LOG_FILE}"
    
    log_ok "========================================="
    log_ok "Native build completed successfully"
    log_ok "========================================="
}

# Execute main function
main "$@"