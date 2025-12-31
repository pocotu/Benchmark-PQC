#!/bin/bash
# ============================================================================
# System and Experiment Metadata Collector
# ============================================================================
# Gathers comprehensive metadata for reproducibility including system info,
# software versions, hardware specs, and experiment configuration.
# ============================================================================

set -euo pipefail

# Sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/common-functions.sh"
source "${SCRIPT_DIR}/experiment_config.sh"

# ============================================================================
# System Information Collection
# ============================================================================

collect_cpu_info() {
    local cpu_info=""
    
    # CPU model
    if [[ -f /proc/cpuinfo ]]; then
        cpu_info=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | xargs)
    fi
    
    # CPU count
    local cpu_count=$(nproc 2>/dev/null || echo "unknown")
    
    # CPU architecture
    local cpu_arch=$(uname -m)
    
    cat <<EOF
{
  "model": "${cpu_info}",
  "count": ${cpu_count},
  "architecture": "${cpu_arch}"
}
EOF
}

collect_memory_info() {
    local total_mem=""
    local free_mem=""
    
    if [[ -f /proc/meminfo ]]; then
        total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        free_mem=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    else
        total_mem="unknown"
        free_mem="unknown"
    fi
    
    cat <<EOF
{
  "total_kb": ${total_mem:-0},
  "available_kb": ${free_mem:-0}
}
EOF
}

collect_disk_info() {
    local disk_total=""
    local disk_used=""
    local disk_available=""
    
    if command -v df &>/dev/null; then
        local df_output=$(df -k "${PROJECT_ROOT}" | tail -n1)
        disk_total=$(echo "${df_output}" | awk '{print $2}')
        disk_used=$(echo "${df_output}" | awk '{print $3}')
        disk_available=$(echo "${df_output}" | awk '{print $4}')
    else
        disk_total="unknown"
        disk_used="unknown"
        disk_available="unknown"
    fi
    
    cat <<EOF
{
  "total_kb": ${disk_total:-0},
  "used_kb": ${disk_used:-0},
  "available_kb": ${disk_available:-0},
  "path": "${PROJECT_ROOT}"
}
EOF
}

collect_os_info() {
    cat <<EOF
{
  "hostname": "${HOSTNAME}",
  "kernel": "${KERNEL}",
  "distribution": "${OS_INFO}",
  "architecture": "$(uname -m)"
}
EOF
}

# ============================================================================
# Software Stack Information
# ============================================================================

collect_compiler_info() {
    local gcc_version_full=""
    local gcc_path=""
    
    if command -v gcc &>/dev/null; then
        gcc_version_full=$(gcc --version | head -n1)
        gcc_path=$(command -v gcc)
    else
        gcc_version_full="not found"
        gcc_path="not found"
    fi
    
    cat <<EOF
{
  "gcc": {
    "version": "${gcc_version_full}",
    "path": "${gcc_path}"
  },
  "cmake": {
    "version": "${CMAKE_VERSION}",
    "path": "$(command -v cmake 2>/dev/null || echo 'not found')"
  }
}
EOF
}

collect_liboqs_info() {
    local liboqs_dir="${PROJECT_ROOT}/build/liboqs/build-native"
    local liboqs_lib="${liboqs_dir}/lib/liboqs.a"
    local liboqs_size="unknown"
    
    if [[ -f "${liboqs_lib}" ]]; then
        liboqs_size=$(stat -c%s "${liboqs_lib}" 2>/dev/null || echo "unknown")
    fi
    
    cat <<EOF
{
  "version": "${LIBOQS_VERSION}",
  "path": "${liboqs_dir}",
  "library_size_bytes": "${liboqs_size}",
  "build_timestamp": "$(stat -c%y "${liboqs_lib}" 2>/dev/null || echo 'unknown')"
}
EOF
}

collect_git_info() {
    cat <<EOF
{
  "commit": "${GIT_COMMIT}",
  "branch": "${GIT_BRANCH}",
  "dirty": ${GIT_DIRTY},
  "remote": "$(cd "${PROJECT_ROOT}" && git remote get-url origin 2>/dev/null || echo 'unknown')"
}
EOF
}

# ============================================================================
# Experiment Configuration
# ============================================================================

collect_experiment_config() {
    cat <<EOF
{
  "mlkem_algorithms": [$(printf '"%s",' "${MLKEM_ALGORITHMS[@]}" | sed 's/,$//')],
  "mldsa_algorithms": [$(printf '"%s",' "${MLDSA_ALGORITHMS[@]}" | sed 's/,$//')],
  "architectures": [$(printf '"%s",' "${ARCHITECTURES[@]}" | sed 's/,$//')],
  "iterations": ${DEFAULT_ITERATIONS},
  "warmup_iterations": ${DEFAULT_WARMUP},
  "message_size_bytes": ${DEFAULT_MESSAGE_SIZE},
  "remove_outliers": ${REMOVE_OUTLIERS},
  "max_cv_percent": ${MAX_CV_PERCENT}
}
EOF
}

# ============================================================================
# Main Metadata Collection
# ============================================================================

collect_all_metadata() {
    local experiment_id="${1:-$(date +%Y%m%d_%H%M%S)}"
    local output_file="${2:-}"
    
    log_info "Collecting system and experiment metadata..."
    
    # Generate complete metadata JSON
    local metadata=$(cat <<EOF
{
  "experiment_id": "${experiment_id}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "system": {
    "os": $(collect_os_info),
    "cpu": $(collect_cpu_info),
    "memory": $(collect_memory_info),
    "disk": $(collect_disk_info)
  },
  "software": {
    "compilers": $(collect_compiler_info),
    "liboqs": $(collect_liboqs_info),
    "git": $(collect_git_info)
  },
  "configuration": $(collect_experiment_config)
}
EOF
)
    
    # Output to file if specified, otherwise to stdout
    if [[ -n "${output_file}" ]]; then
        echo "${metadata}" | python3 -m json.tool > "${output_file}" 2>/dev/null || \
            echo "${metadata}" > "${output_file}"
        log_success "Metadata saved to: ${output_file}"
    else
        echo "${metadata}"
    fi
    
    return 0
}

# ============================================================================
# Metadata Validation
# ============================================================================

validate_metadata() {
    local metadata_file="$1"
    
    if [[ ! -f "${metadata_file}" ]]; then
        log_error "Metadata file not found: ${metadata_file}"
        return 1
    fi
    
    # Check if valid JSON
    if ! python3 -m json.tool "${metadata_file}" >/dev/null 2>&1; then
        log_error "Invalid JSON in metadata file: ${metadata_file}"
        return 1
    fi
    
    # Check required fields
    local required_fields=(
        "experiment_id"
        "timestamp"
        "system"
        "software"
        "configuration"
    )
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "\"${field}\"" "${metadata_file}"; then
            log_error "Missing required field in metadata: ${field}"
            return 1
        fi
    done
    
    log_success "Metadata validated: ${metadata_file}"
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local experiment_id="${1:-}"
    local output_file="${2:-}"
    
    # If no experiment ID provided, generate one
    if [[ -z "${experiment_id}" ]]; then
        experiment_id="metadata_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # If no output file provided, use default location
    if [[ -z "${output_file}" ]]; then
        output_file=$(get_metadata_path "${experiment_id}")
    fi
    
    # Collect metadata
    collect_all_metadata "${experiment_id}" "${output_file}"
    
    # Validate the generated metadata
    validate_metadata "${output_file}"
    
    return $?
}

# Execute main if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
