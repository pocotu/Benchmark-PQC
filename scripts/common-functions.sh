#!/usr/bin/env bash
#
# Common Functions Library for PQC Benchmarks
# Single Responsibility: Provide reusable utility functions
#
# Follows SOLID principles:
# - SRP: Each function has one responsibility
# - OCP: Extensible without modification
# - LSP: Functions can be substituted
# - ISP: Small, focused interfaces
# - DIP: Depends on abstractions (env vars, not concrete implementations)
#

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'

# =============================================================================
# Logging Functions (Single Responsibility Principle)
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_ok() {
    echo -e "${GREEN}[OK]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}$*${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
}

# =============================================================================
# Validation Functions (Interface Segregation Principle)
# =============================================================================

check_command() {
    local cmd="$1"
    if command -v "${cmd}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_file_exists() {
    local file="$1"
    [[ -f "${file}" ]]
}

check_dir_exists() {
    local dir="$1"
    [[ -d "${dir}" ]]
}

check_executable() {
    local file="$1"
    [[ -x "${file}" ]]
}

# =============================================================================
# Error Handling (Dependency Inversion Principle)
# =============================================================================

setup_error_handling() {
    set -euo pipefail
    trap 'error_handler $? $LINENO' ERR
}

error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Script failed with exit code ${exit_code} at line ${line_number}"
    exit "${exit_code}"
}

# =============================================================================
# File Operations (Single Responsibility Principle)
# =============================================================================

ensure_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        log_debug "Created directory: ${dir}"
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${file}" "${backup}"
        log_debug "Backed up ${file} to ${backup}"
    fi
}

# =============================================================================
# Process Management (Single Responsibility Principle)
# =============================================================================

check_process_running() {
    local process_name="$1"
    pgrep -f "${process_name}" > /dev/null 2>&1
}

wait_for_process() {
    local process_name="$1"
    local timeout="${2:-30}"
    local elapsed=0
    
    while ! check_process_running "${process_name}"; do
        sleep 1
        elapsed=$((elapsed + 1))
        if [[ ${elapsed} -ge ${timeout} ]]; then
            log_error "Timeout waiting for process: ${process_name}"
            return 1
        fi
    done
    return 0
}

# =============================================================================
# System Information (Interface Segregation Principle)
# =============================================================================

get_cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1"
}

get_available_ram_gb() {
    local ram_kb
    ram_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    echo $((ram_kb / 1024 / 1024))
}

get_available_disk_gb() {
    local path="${1:-.}"
    df -BG "${path}" | tail -1 | awk '{print $4}' | sed 's/G//'
}

# =============================================================================
# Version Checking (Open/Closed Principle)
# =============================================================================

version_compare() {
    local version1="$1"
    local version2="$2"
    
    if [[ "${version1}" == "${version2}" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    for ((i=0; i<${#ver1[@]} || i<${#ver2[@]}; i++)); do
        if [[ ${ver1[i]:-0} -gt ${ver2[i]:-0} ]]; then
            return 0
        elif [[ ${ver1[i]:-0} -lt ${ver2[i]:-0} ]]; then
            return 1
        fi
    done
    return 0
}

# =============================================================================
# Execution Helpers (Dependency Inversion Principle)
# =============================================================================

execute_with_retry() {
    local max_attempts="${1}"
    shift
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        else
            log_warn "Attempt ${attempt}/${max_attempts} failed, retrying..."
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    log_error "All ${max_attempts} attempts failed"
    return 1
}

execute_logged() {
    local description="$1"
    shift
    
    log_debug "Executing: ${description}"
    if "$@"; then
        log_ok "Completed: ${description}"
        return 0
    else
        log_error "Failed: ${description}"
        return 1
    fi
}

# =============================================================================
# Initialization
# =============================================================================

# Export functions for subshells (if needed)
export -f log_info log_success log_ok log_warn log_error log_debug log_section
export -f check_command check_file_exists check_dir_exists check_executable
export -f ensure_dir backup_file
export -f get_cpu_count get_available_ram_gb get_available_disk_gb

# Log that library was loaded
log_debug "common-functions.sh loaded successfully"
