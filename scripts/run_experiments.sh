#!/bin/bash
# ============================================================================
# Benchmark Execution Orchestrator
# ============================================================================
# Coordinates execution of all benchmark experiments for ML-KEM and ML-DSA
# across different security levels and architectures.
# ============================================================================

set -euo pipefail

# Sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Set LD_LIBRARY_PATH for liboqs
export LD_LIBRARY_PATH="${PROJECT_ROOT}/build/liboqs/build-native/lib:${LD_LIBRARY_PATH:-}"

source "${PROJECT_ROOT}/lib/common-functions.sh"
source "${SCRIPT_DIR}/experiment_config.sh"

# ============================================================================
# Global Variables
# ============================================================================

EXPERIMENT_ID=""
DRY_RUN=false
RESUME=false
CHECKPOINT_FILE=""
METADATA_FILE=""
FAILED_EXPERIMENTS=()

# ============================================================================
# Checkpoint Management (Single Responsibility)
# ============================================================================

save_checkpoint() {
    local completed_item="$1"
    
    if [[ -z "${CHECKPOINT_FILE}" ]]; then
        return 0
    fi
    
    echo "${completed_item}" >> "${CHECKPOINT_FILE}"
    log_debug "Checkpoint saved: ${completed_item}"
}

load_checkpoint() {
    if [[ ! -f "${CHECKPOINT_FILE}" ]]; then
        log_info "No checkpoint file found, starting fresh"
        return 0
    fi
    
    log_info "Loading checkpoint from: ${CHECKPOINT_FILE}"
    
    # Count completed items
    local completed_count=$(wc -l < "${CHECKPOINT_FILE}")
    log_success "Found ${completed_count} completed experiments"
    
    return 0
}

is_experiment_completed() {
    local experiment_key="$1"
    
    if [[ ! -f "${CHECKPOINT_FILE}" ]]; then
        return 1  # Not completed
    fi
    
    if grep -Fxq "${experiment_key}" "${CHECKPOINT_FILE}"; then
        return 0  # Completed
    fi
    
    return 1  # Not completed
}

# ============================================================================
# Experiment Execution (Single Responsibility)
# ============================================================================

run_mlkem_benchmark() {
    local arch="$1"
    local algorithm="$2"
    local timestamp="$3"
    
    local experiment_key="mlkem_${arch}_${algorithm}"
    
    # Check if already completed
    if is_experiment_completed "${experiment_key}"; then
        log_info "Skipping completed experiment: ${experiment_key}"
        return 0
    fi
    
    log_info "Running ML-KEM benchmark: ${algorithm} on ${arch}"
    
    # Prepare output files
    local json_file=$(get_output_path "${arch}" "${MLKEM_SUBDIR}" "${algorithm}" "${JSON_EXT}" "${timestamp}")
    local csv_file=$(get_output_path "${arch}" "${MLKEM_SUBDIR}" "${algorithm}" "${CSV_EXT}" "${timestamp}")
    
    # Build command
    local benchmark_cmd="${PROJECT_ROOT}/build/bin/benchmark_mlkem"
    local cmd_args="-i ${DEFAULT_ITERATIONS} -w ${DEFAULT_WARMUP}"
    
    if [[ "${REMOVE_OUTLIERS}" == "true" ]]; then
        cmd_args="${cmd_args} -r"
    fi
    
    cmd_args="${cmd_args} -j ${json_file} -c ${csv_file}"
    
    # Execute benchmark
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: ${benchmark_cmd} ${cmd_args}"
        return 0
    fi
    
    log_debug "Command: ${benchmark_cmd} ${cmd_args}"
    
    if ${benchmark_cmd} ${cmd_args}; then
        log_success "Completed: ${experiment_key}"
        save_checkpoint "${experiment_key}"
        return 0
    else
        log_error "Failed: ${experiment_key}"
        FAILED_EXPERIMENTS+=("${experiment_key}")
        return 1
    fi
}

run_mldsa_benchmark() {
    local arch="$1"
    local algorithm="$2"
    local timestamp="$3"
    
    local experiment_key="mldsa_${arch}_${algorithm}"
    
    # Check if already completed
    if is_experiment_completed "${experiment_key}"; then
        log_info "Skipping completed experiment: ${experiment_key}"
        return 0
    fi
    
    log_info "Running ML-DSA benchmark: ${algorithm} on ${arch}"
    
    # Prepare output files
    local json_file=$(get_output_path "${arch}" "${MLDSA_SUBDIR}" "${algorithm}" "${JSON_EXT}" "${timestamp}")
    local csv_file=$(get_output_path "${arch}" "${MLDSA_SUBDIR}" "${algorithm}" "${CSV_EXT}" "${timestamp}")
    
    # Build command
    local benchmark_cmd="${PROJECT_ROOT}/build/bin/benchmark_mldsa"
    local cmd_args="-i ${DEFAULT_ITERATIONS} -w ${DEFAULT_WARMUP} -m ${DEFAULT_MESSAGE_SIZE}"
    
    if [[ "${REMOVE_OUTLIERS}" == "true" ]]; then
        cmd_args="${cmd_args} -r"
    fi
    
    cmd_args="${cmd_args} -j ${json_file} -c ${csv_file}"
    
    # Execute benchmark
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY RUN] Would execute: ${benchmark_cmd} ${cmd_args}"
        return 0
    fi
    
    log_debug "Command: ${benchmark_cmd} ${cmd_args}"
    
    if ${benchmark_cmd} ${cmd_args}; then
        log_success "Completed: ${experiment_key}"
        save_checkpoint "${experiment_key}"
        return 0
    else
        log_error "Failed: ${experiment_key}"
        FAILED_EXPERIMENTS+=("${experiment_key}")
        return 1
    fi
}

# ============================================================================
# Main Orchestration
# ============================================================================

run_all_experiments() {
    local timestamp="$1"
    
    log_section "Starting Experimental Campaign"
    log_info "Experiment ID: ${EXPERIMENT_ID}"
    log_info "Timestamp: ${timestamp}"
    
    # Calculate total experiments
    local mlkem_count=${#MLKEM_ALGORITHMS[@]}
    local mldsa_count=${#MLDSA_ALGORITHMS[@]}
    local arch_count=${#ARCHITECTURES[@]}
    local total_experiments=$(( (mlkem_count + mldsa_count) * arch_count ))
    
    log_info "Total experiments to run: ${total_experiments}"
    echo ""
    
    local current=0
    local success=0
    local failed=0
    local skipped=0
    
    # Run ML-KEM benchmarks
    log_section "ML-KEM Benchmarks"
    for arch in "${ARCHITECTURES[@]}"; do
        for algorithm in "${MLKEM_ALGORITHMS[@]}"; do
            current=$((current + 1))
            log_info "[${current}/${total_experiments}] ${arch} :: ${algorithm}"
            
            if run_mlkem_benchmark "${arch}" "${algorithm}" "${timestamp}"; then
                if is_experiment_completed "mlkem_${arch}_${algorithm}"; then
                    skipped=$((skipped + 1))
                else
                    success=$((success + 1))
                fi
            else
                failed=$((failed + 1))
            fi
            
            # Small delay between experiments
            sleep 1
        done
    done
    
    # Run ML-DSA benchmarks
    log_section "ML-DSA Benchmarks"
    for arch in "${ARCHITECTURES[@]}"; do
        for algorithm in "${MLDSA_ALGORITHMS[@]}"; do
            current=$((current + 1))
            log_info "[${current}/${total_experiments}] ${arch} :: ${algorithm}"
            
            if run_mldsa_benchmark "${arch}" "${algorithm}" "${timestamp}"; then
                if is_experiment_completed "mldsa_${arch}_${algorithm}"; then
                    skipped=$((skipped + 1))
                else
                    success=$((success + 1))
                fi
            else
                failed=$((failed + 1))
            fi
            
            # Small delay between experiments
            sleep 1
        done
    done
    
    # Print summary
    echo ""
    log_section "Experiment Summary"
    log_info "Total experiments: ${total_experiments}"
    log_success "Successful: ${success}"
    log_warn "Skipped (already done): ${skipped}"
    if [[ ${failed} -gt 0 ]]; then
        log_error "Failed: ${failed}"
    else
        log_success "Failed: ${failed}"
    fi
    
    # List failed experiments if any
    if [[ ${#FAILED_EXPERIMENTS[@]} -gt 0 ]]; then
        echo ""
        log_error "Failed experiments:"
        for exp in "${FAILED_EXPERIMENTS[@]}"; do
            echo "  - ${exp}"
        done
        return 1
    fi
    
    return 0
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

preflight_check() {
    log_section "Pre-flight Checks"
    
    # Check binaries exist
    if [[ ! -x "${PROJECT_ROOT}/build/bin/benchmark_mlkem" ]]; then
        log_error "benchmark_mlkem not found or not executable"
        log_info "Run: make compile-benchmarks"
        return 1
    fi
    
    if [[ ! -x "${PROJECT_ROOT}/build/bin/benchmark_mldsa" ]]; then
        log_error "benchmark_mldsa not found or not executable"
        log_info "Run: make compile-benchmarks"
        return 1
    fi
    
    log_success "Benchmarks compiled"
    
    # Check directory structure
    init_experiment_dirs
    log_success "Directory structure ready"
    
    # Validate configuration
    if ! validate_experiment_config; then
        return 1
    fi
    log_success "Configuration valid"
    
    log_success "All pre-flight checks passed"
    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Orchestrates execution of all benchmark experiments.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be executed without running
    -r, --resume            Resume from checkpoint
    -i, --id EXPERIMENT_ID  Set custom experiment ID
    -n, --no-metadata       Skip metadata collection
    
EXAMPLES:
    # Run full experimental campaign
    $0
    
    # Dry run to see what will be executed
    $0 --dry-run
    
    # Resume interrupted experiment
    $0 --resume --id exp_20251110_120000
    
EOF
}

main() {
    local no_metadata=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--resume)
                RESUME=true
                shift
                ;;
            -i|--id)
                EXPERIMENT_ID="$2"
                shift 2
                ;;
            -n|--no-metadata)
                no_metadata=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Generate experiment ID if not provided
    if [[ -z "${EXPERIMENT_ID}" ]]; then
        EXPERIMENT_ID="exp_$(get_timestamp)"
    fi
    
    # Setup checkpoint and metadata files
    CHECKPOINT_FILE=$(get_checkpoint_path "${EXPERIMENT_ID}")
    METADATA_FILE=$(get_metadata_path "${EXPERIMENT_ID}")
    
    # Print banner
    cat <<EOF

╔════════════════════════════════════════════════════════════════╗
║              PQC Benchmarking - Experiment Runner              ║
╚════════════════════════════════════════════════════════════════╝

Experiment ID: ${EXPERIMENT_ID}
Dry Run: ${DRY_RUN}
Resume: ${RESUME}

EOF
    
    # Pre-flight checks
    if ! preflight_check; then
        log_error "Pre-flight checks failed"
        exit 1
    fi
    
    # Collect metadata (unless disabled)
    if [[ "${no_metadata}" == "false" ]]; then
        log_info "Collecting system metadata..."
        "${SCRIPT_DIR}/collect_metadata.sh" "${EXPERIMENT_ID}" "${METADATA_FILE}"
    fi
    
    # Load checkpoint if resuming
    if [[ "${RESUME}" == "true" ]]; then
        load_checkpoint
    fi
    
    # Get timestamp for file naming
    local timestamp=$(get_timestamp)
    
    # Run all experiments
    if run_all_experiments "${timestamp}"; then
        log_section "Experimental Campaign Completed Successfully"
        
        # Validate generated data
        log_info "Validating generated data..."
        if python3 "${SCRIPT_DIR}/validate_data.py" "${DATA_RAW_DIR}" --recursive; then
            log_success "All data files validated successfully"
        else
            log_warn "Some data validation issues found (see above)"
        fi
        
        exit 0
    else
        log_section "Experimental Campaign Completed with Errors"
        log_error "Check failed experiments above"
        exit 1
    fi
}

# Execute main
main "$@"
