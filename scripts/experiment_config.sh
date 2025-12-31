#!/bin/bash
# ============================================================================
# Experiment Configuration
# ============================================================================
# Central configuration file for experimental parameters.
# Sourced by other scripts to ensure consistent settings across all experiments.
# ============================================================================

# Sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common functions if available
if [[ -f "${PROJECT_ROOT}/lib/common-functions.sh" ]]; then
    source "${PROJECT_ROOT}/lib/common-functions.sh"
else
    # Fallback minimal logging if common-functions not available
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
    log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
    log_warn() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
fi

# ============================================================================
# Experiment Parameters
# ============================================================================

# Algorithms to benchmark
declare -a MLKEM_ALGORITHMS=("mlkem512" "mlkem768" "mlkem1024")
declare -a MLDSA_ALGORITHMS=("mldsa44" "mldsa65" "mldsa87")

# Architectures to test
declare -a ARCHITECTURES=("native" "arm64" "riscv64")

# Benchmark iterations
DEFAULT_ITERATIONS=10000
DEFAULT_WARMUP=1000
DEFAULT_MESSAGE_SIZE=1024  # 1KB for ML-DSA

# Enable outlier removal by default
REMOVE_OUTLIERS=true

# ============================================================================
# Directory Structure
# ============================================================================

# Data directories
DATA_RAW_DIR="${PROJECT_ROOT}/data/raw"
DATA_PROCESSED_DIR="${PROJECT_ROOT}/data/processed"
RESULTS_DIR="${PROJECT_ROOT}/results"

# Architecture-specific data directories
DATA_NATIVE_DIR="${DATA_RAW_DIR}/native"
DATA_ARM_DIR="${DATA_RAW_DIR}/arm64"
DATA_RISCV_DIR="${DATA_RAW_DIR}/riscv64"

# Algorithm-specific subdirectories
MLKEM_SUBDIR="mlkem"
MLDSA_SUBDIR="mldsa"

# Checkpoint and metadata directories
CHECKPOINT_DIR="${PROJECT_ROOT}/data/checkpoints"
METADATA_DIR="${PROJECT_ROOT}/data/metadata"

# ============================================================================
# File Naming Conventions
# ============================================================================

# Timestamp format for unique file naming
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

# File extensions
JSON_EXT=".json"
CSV_EXT=".csv"
CHECKPOINT_EXT=".checkpoint"
METADATA_EXT=".metadata.json"

# ============================================================================
# Experiment Metadata
# ============================================================================

# Git information (for reproducibility)
GIT_COMMIT=$(cd "${PROJECT_ROOT}" && git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(cd "${PROJECT_ROOT}" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY=$(cd "${PROJECT_ROOT}" && git diff --quiet 2>/dev/null && echo "false" || echo "true")

# System information
HOSTNAME=$(hostname)
KERNEL=$(uname -r)
OS_INFO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)

# Compiler versions
GCC_VERSION=$(gcc --version | head -n1)
CMAKE_VERSION=$(cmake --version | head -n1)

# liboqs version
LIBOQS_VERSION="0.10.0"

# ============================================================================
# Validation Settings
# ============================================================================

# Acceptable coefficient of variation (CV) threshold
MAX_CV_PERCENT=15.0

# Minimum required iterations for statistical validity
MIN_ITERATIONS=100

# Data validation checksums
ENABLE_CHECKSUMS=true

# ============================================================================
# Parallel Execution Settings
# ============================================================================

# Number of parallel jobs (conservative to avoid contention)
MAX_PARALLEL_JOBS=2

# Delay between starting parallel jobs (seconds)
JOB_STARTUP_DELAY=5

# ============================================================================
# Helper Functions
# ============================================================================

# Get timestamp for file naming
get_timestamp() {
    date +"${TIMESTAMP_FORMAT}"
}

# Get full output path for an experiment
# Usage: get_output_path <arch> <algorithm_type> <algorithm_name> <extension>
get_output_path() {
    local arch="$1"
    local algo_type="$2"
    local algo_name="$3"
    local ext="$4"
    local timestamp="$5"
    
    # Determine architecture directory
    local arch_dir
    case "${arch}" in
        native)  arch_dir="${DATA_NATIVE_DIR}" ;;
        arm64)   arch_dir="${DATA_ARM_DIR}" ;;
        riscv64) arch_dir="${DATA_RISCV_DIR}" ;;
        *)       
            log_error "Unknown architecture: ${arch}"
            return 1
            ;;
    esac
    
    # Create full path
    local subdir="${arch_dir}/${algo_type}"
    mkdir -p "${subdir}"
    
    # Construct filename
    local filename="${algo_name}_${timestamp}${ext}"
    echo "${subdir}/${filename}"
}

# Get checkpoint file path
# Usage: get_checkpoint_path <experiment_id>
get_checkpoint_path() {
    local experiment_id="$1"
    mkdir -p "${CHECKPOINT_DIR}"
    echo "${CHECKPOINT_DIR}/${experiment_id}${CHECKPOINT_EXT}"
}

# Get metadata file path
# Usage: get_metadata_path <experiment_id>
get_metadata_path() {
    local experiment_id="$1"
    mkdir -p "${METADATA_DIR}"
    echo "${METADATA_DIR}/${experiment_id}${METADATA_EXT}"
}

# Export all configuration for child processes
export_config() {
    # Export arrays as space-separated strings
    export MLKEM_ALGORITHMS_STR="${MLKEM_ALGORITHMS[*]}"
    export MLDSA_ALGORITHMS_STR="${MLDSA_ALGORITHMS[*]}"
    export ARCHITECTURES_STR="${ARCHITECTURES[*]}"
    
    # Export parameters
    export DEFAULT_ITERATIONS
    export DEFAULT_WARMUP
    export DEFAULT_MESSAGE_SIZE
    export REMOVE_OUTLIERS
    
    # Export directories
    export DATA_RAW_DIR
    export DATA_PROCESSED_DIR
    export RESULTS_DIR
    export CHECKPOINT_DIR
    export METADATA_DIR
    
    # Export metadata
    export GIT_COMMIT
    export GIT_BRANCH
    export GIT_DIRTY
    export HOSTNAME
    export KERNEL
    export OS_INFO
    export GCC_VERSION
    export CMAKE_VERSION
    export LIBOQS_VERSION
    
    # Export validation settings
    export MAX_CV_PERCENT
    export MIN_ITERATIONS
    export ENABLE_CHECKSUMS
    
    # Export parallel settings
    export MAX_PARALLEL_JOBS
    export JOB_STARTUP_DELAY
}

# ============================================================================
# Initialization
# ============================================================================

# Create directory structure if it doesn't exist
init_experiment_dirs() {
    log_info "Initializing experiment directory structure..."
    
    # Create main directories
    mkdir -p "${DATA_RAW_DIR}"
    mkdir -p "${DATA_PROCESSED_DIR}"
    mkdir -p "${RESULTS_DIR}"
    mkdir -p "${CHECKPOINT_DIR}"
    mkdir -p "${METADATA_DIR}"
    
    # Create architecture-specific directories
    for arch in "${ARCHITECTURES[@]}"; do
        case "${arch}" in
            native)  arch_dir="${DATA_NATIVE_DIR}" ;;
            arm64)   arch_dir="${DATA_ARM_DIR}" ;;
            riscv64) arch_dir="${DATA_RISCV_DIR}" ;;
        esac
        
        mkdir -p "${arch_dir}/${MLKEM_SUBDIR}"
        mkdir -p "${arch_dir}/${MLDSA_SUBDIR}"
    done
    
    log_success "Directory structure initialized"
}

# Validate experiment configuration
validate_experiment_config() {
    log_info "Validating experiment configuration..."
    
    # Check minimum iterations
    if [[ ${DEFAULT_ITERATIONS} -lt ${MIN_ITERATIONS} ]]; then
        log_error "DEFAULT_ITERATIONS (${DEFAULT_ITERATIONS}) < MIN_ITERATIONS (${MIN_ITERATIONS})"
        return 1
    fi
    
    # Check that binaries exist
    local bin_dir="${PROJECT_ROOT}/build/bin"
    if [[ ! -x "${bin_dir}/benchmark_mlkem" ]]; then
        log_error "benchmark_mlkem binary not found or not executable"
        return 1
    fi
    
    if [[ ! -x "${bin_dir}/benchmark_mldsa" ]]; then
        log_error "benchmark_mldsa binary not found or not executable"
        return 1
    fi
    
    log_success "Configuration validated"
    return 0
}

# ============================================================================
# Main Execution (when sourced, only functions are defined)
# ============================================================================

# If executed directly (not sourced), show configuration
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "=== Experiment Configuration ==="
    echo ""
    echo "ML-KEM Algorithms: ${MLKEM_ALGORITHMS[*]}"
    echo "ML-DSA Algorithms: ${MLDSA_ALGORITHMS[*]}"
    echo "Architectures: ${ARCHITECTURES[*]}"
    echo ""
    echo "Default Iterations: ${DEFAULT_ITERATIONS}"
    echo "Default Warmup: ${DEFAULT_WARMUP}"
    echo "Message Size: ${DEFAULT_MESSAGE_SIZE} bytes"
    echo "Remove Outliers: ${REMOVE_OUTLIERS}"
    echo ""
    echo "Data Directory: ${DATA_RAW_DIR}"
    echo "Checkpoint Directory: ${CHECKPOINT_DIR}"
    echo ""
    echo "Git Commit: ${GIT_COMMIT}"
    echo "Git Branch: ${GIT_BRANCH}"
    echo "Git Dirty: ${GIT_DIRTY}"
    echo ""
    
    # Initialize and validate if requested
    if [[ "$1" == "--init" ]]; then
        init_experiment_dirs
        validate_experiment_config
    fi
fi
