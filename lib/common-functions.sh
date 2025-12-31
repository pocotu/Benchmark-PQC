#!/bin/bash
################################################################################
# Common Functions Library
################################################################################

# Source configuration (use local variable to avoid polluting caller's environment)
_COMMON_FUNCTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_COMMON_FUNCTIONS_DIR}/../config/build-config.sh"

# Global log file for current execution
export GLOBAL_LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# Logging Functions
################################################################################

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date "${LOG_TIMESTAMP_FORMAT}")
    local color=""
    
    case "$level" in
        DEBUG) color="${COLOR_MAGENTA}" ;;
        INFO)  color="${COLOR_BLUE}" ;;
        WARN)  color="${COLOR_YELLOW}" ;;
        ERROR) color="${COLOR_RED}" ;;
        OK)    color="${COLOR_GREEN}" ;;
    esac
    
    # Console output with color
    echo -e "${color}[${level}]${COLOR_RESET} ${timestamp} - ${message}"
    
    # File output without color
    echo "[${level}] ${timestamp} - ${message}" >> "${GLOBAL_LOG_FILE}"
}

log_debug() { log_message "DEBUG" "$@"; }
log_info()  { log_message "INFO" "$@"; }
log_warn()  { log_message "WARN" "$@"; }
log_error() { log_message "ERROR" "$@"; }
log_ok()    { log_message "OK" "$@"; }
log_success() { log_message "SUCCESS" "$@"; }

# Log section header (for visual separation)
log_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "$@"
    echo "═══════════════════════════════════════════════════════════"
}

################################################################################
# Error Handling
################################################################################

# Cleanup function called on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code: ${exit_code}"
        log_info "Check log file: ${GLOBAL_LOG_FILE}"
    else
        log_ok "Script completed successfully"
    fi
}

# Handle script interruption
handle_interrupt() {
    log_warn "Script interrupted by user (Ctrl+C)"
    log_info "Performing cleanup..."
    exit 130
}

# Setup error handling
setup_error_handling() {
    set -o errexit   # Exit on error
    set -o nounset   # Exit on undefined variable
    set -o pipefail  # Exit on pipe failure
    
    trap cleanup EXIT
    trap handle_interrupt SIGINT SIGTERM
}

################################################################################
# Validation Functions
################################################################################

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Compare version numbers (returns 0 if v1 >= v2)
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Validate GCC version
validate_gcc_version() {
    local compiler="$1"
    local min_version="$2"
    
    if ! command_exists "$compiler"; then
        log_error "Compiler not found: $compiler"
        return 1
    fi
    
    local version=$($compiler --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
    
    if ! version_ge "$version" "$min_version"; then
        log_error "$compiler version $version is too old (minimum: $min_version)"
        return 1
    fi
    
    log_ok "$compiler version: $version"
    return 0
}

# Validate CMake version
validate_cmake_version() {
    local min_version="$1"
    
    if ! command_exists cmake; then
        log_error "CMake not found"
        return 1
    fi
    
    local version=$(cmake --version | head -n1 | grep -oP '\d+\.\d+\.\d+')
    
    if ! version_ge "$version" "$min_version"; then
        log_error "CMake version $version is too old (minimum: $min_version)"
        return 1
    fi
    
    log_ok "CMake version: $version"
    return 0
}

# Check available disk space
validate_disk_space() {
    local min_space_gb="$1"
    local target_dir="$2"
    
    local available_kb=$(df -k "$target_dir" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ $available_gb -lt $min_space_gb ]; then
        log_error "Insufficient disk space: ${available_gb}GB (minimum: ${min_space_gb}GB)"
        return 1
    fi
    
    log_ok "Available disk space: ${available_gb}GB"
    return 0
}

# Check available RAM
validate_ram() {
    local min_ram_gb="$1"
    
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    if [ $total_ram_gb -lt $min_ram_gb ]; then
        log_warn "Low RAM: ${total_ram_gb}GB (recommended: ${min_ram_gb}GB)"
        log_warn "Compilation may be slow or fail"
        return 0  # Warning only, don't fail
    fi
    
    log_ok "Available RAM: ${total_ram_gb}GB"
    return 0
}

# Check if another build is running
check_build_lock() {
    local lock_file="${BUILD_DIR}/.build.lock"
    
    if [ -f "$lock_file" ]; then
        local pid=$(cat "$lock_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_error "Another build is running (PID: $pid)"
            log_error "If this is incorrect, remove: $lock_file"
            return 1
        else
            log_warn "Stale lock file found, removing..."
            rm -f "$lock_file"
        fi
    fi
    
    echo $$ > "$lock_file"
    return 0
}

# Release build lock
release_build_lock() {
    local lock_file="${BUILD_DIR}/.build.lock"
    rm -f "$lock_file"
}

################################################################################
# Pre-execution Validation
################################################################################

validate_build_environment() {
    local arch="$1"  # native, arm, riscv
    
    log_info "Validating build environment for: $arch"
    
    # Common validations
    validate_cmake_version "${MIN_CMAKE_VERSION}" || return 1
    validate_disk_space "${MIN_DISK_SPACE_GB}" "${BUILD_DIR}" || return 1
    validate_ram "${MIN_RAM_GB}" || return 1
    check_build_lock || return 1
    
    # Architecture-specific validations
    case "$arch" in
        native)
            validate_gcc_version "${NATIVE_CC}" "${MIN_GCC_VERSION}" || return 1
            ;;
        arm)
            validate_gcc_version "${ARM_CC}" "${MIN_GCC_VERSION}" || return 1
            ;;
        riscv)
            validate_gcc_version "${RISCV_CC}" "${MIN_GCC_VERSION}" || return 1
            ;;
        *)
            log_error "Unknown architecture: $arch"
            return 1
            ;;
    esac
    
    log_ok "Environment validation passed for: $arch"
    return 0
}

################################################################################
# Build Helper Functions
################################################################################

# Execute command with logging
execute_logged() {
    local description="$1"
    shift
    
    log_info "$description"
    log_debug "Executing: $*"
    
    if ! "$@" >> "${GLOBAL_LOG_FILE}" 2>&1; then
        log_error "Failed: $description"
        log_error "Check log: ${GLOBAL_LOG_FILE}"
        return 1
    fi
    
    log_ok "Completed: $description"
    return 0
}

# Clone or update repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local version="$3"
    
    if [ -d "$target_dir/.git" ]; then
        log_info "Repository already exists, updating..."
        (cd "$target_dir" && git fetch --tags && git checkout "$version") >> "${GLOBAL_LOG_FILE}" 2>&1
    else
        log_info "Cloning repository..."
        execute_logged "Cloning $repo_url" \
            git clone --depth 1 --branch "$version" "$repo_url" "$target_dir"
    fi
}

# Verify binary architecture
verify_binary_arch() {
    local binary="$1"
    local expected_arch="$2"
    
    if [ ! -f "$binary" ] && [ ! -L "$binary" ]; then
        log_error "Binary not found: $binary"
        return 1
    fi
    
    # Follow symbolic links to get the real file
    local real_binary
    if [ -L "$binary" ]; then
        real_binary=$(readlink -f "$binary")
        log_debug "Following symlink: $binary -> $real_binary"
    else
        real_binary="$binary"
    fi
    
    if [ ! -f "$real_binary" ]; then
        log_error "Real binary file not found: $real_binary"
        return 1
    fi
    
    local actual_arch=$(file "$real_binary" | grep -oE '(x86-64|ARM aarch64|RISC-V)')
    
    case "$expected_arch" in
        native|x86_64)
            if echo "$actual_arch" | grep -q "x86-64"; then
                log_ok "Binary architecture verified: x86-64"
                return 0
            fi
            ;;
        arm|aarch64)
            if echo "$actual_arch" | grep -q "ARM aarch64"; then
                log_ok "Binary architecture verified: ARM aarch64"
                return 0
            fi
            ;;
        riscv|riscv64)
            if echo "$actual_arch" | grep -q "RISC-V"; then
                log_ok "Binary architecture verified: RISC-V"
                return 0
            fi
            ;;
    esac
    
    log_error "Binary architecture mismatch: expected $expected_arch, got '$actual_arch'"
    log_error "Binary file: $real_binary"
    return 1
}

# Clean old logs
cleanup_old_logs() {
    log_info "Cleaning old logs (retention: ${LOG_RETENTION_DAYS} days)..."
    find "${LOG_DIR}" -name "build-*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete
}

################################################################################
# Export all functions
################################################################################

export -f log_message log_debug log_info log_warn log_error log_ok
export -f cleanup handle_interrupt setup_error_handling
export -f command_exists version_ge
export -f validate_gcc_version validate_cmake_version
export -f validate_disk_space validate_ram check_build_lock release_build_lock
export -f validate_build_environment
export -f execute_logged clone_or_update_repo verify_binary_arch cleanup_old_logs
