#!/bin/bash
# ============================================================================
# Experimental Results Validator
# ============================================================================
# Validates experimental results for completeness and integrity.
# Checks file formats, data consistency, and generates validation reports.
# ============================================================================

set -euo pipefail

# Sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/common-functions.sh"
source "${SCRIPT_DIR}/experiment_config.sh"

# ============================================================================
# Validation Configuration
# ============================================================================

# Expected file counts
EXPECTED_MLKEM_ALGORITHMS=3  # 512, 768, 1024
EXPECTED_MLDSA_ALGORITHMS=3  # 44, 65, 87
EXPECTED_ARCHITECTURES=3     # native, arm64, riscv64

# File types to validate
declare -a FILE_EXTENSIONS=("json" "csv")

# Checksum algorithm
CHECKSUM_ALGO="sha256sum"

# Output files
CHECKSUM_FILE="checksums.sha256"
VALIDATION_REPORT="validation_report.txt"

# ============================================================================
# Completeness Validation (SRP - Completeness checks only)
# ============================================================================

check_directory_structure() {
    local base_dir="$1"
    
    log_info "Checking directory structure..."
    
    local missing_dirs=()
    
    # Check architecture directories
    for arch in "${ARCHITECTURES[@]}"; do
        local arch_dir="${base_dir}/${arch}"
        
        if [[ ! -d "${arch_dir}" ]]; then
            missing_dirs+=("${arch_dir}")
            continue
        fi
        
        # Check algorithm subdirectories
        if [[ ! -d "${arch_dir}/${MLKEM_SUBDIR}" ]]; then
            missing_dirs+=("${arch_dir}/${MLKEM_SUBDIR}")
        fi
        
        if [[ ! -d "${arch_dir}/${MLDSA_SUBDIR}" ]]; then
            missing_dirs+=("${arch_dir}/${MLDSA_SUBDIR}")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_warn "Missing directories:"
        for dir in "${missing_dirs[@]}"; do
            log_warn "  - ${dir}"
        done
        return 1
    fi
    
    log_success "Directory structure is complete"
    return 0
}

count_result_files() {
    local dir="$1"
    local pattern="$2"
    
    if [[ ! -d "${dir}" ]]; then
        echo "0"
        return
    fi
    
    find "${dir}" -name "${pattern}" -type f 2>/dev/null | wc -l
}

check_file_completeness() {
    local base_dir="$1"
    
    log_info "Checking file completeness..."
    
    local total_expected=0
    local total_found=0
    local incomplete=false
    
    for arch in "${ARCHITECTURES[@]}"; do
        log_debug "Checking ${arch}..."
        
        # ML-KEM files
        local mlkem_dir="${base_dir}/${arch}/${MLKEM_SUBDIR}"
        local mlkem_json_count=$(count_result_files "${mlkem_dir}" "*.json")
        local mlkem_csv_count=$(count_result_files "${mlkem_dir}" "*.csv")
        
        # ML-DSA files
        local mldsa_dir="${base_dir}/${arch}/${MLDSA_SUBDIR}"
        local mldsa_json_count=$(count_result_files "${mldsa_dir}" "*.json")
        local mldsa_csv_count=$(count_result_files "${mldsa_dir}" "*.csv")
        
        # Calculate expected vs found
        local arch_expected=$((EXPECTED_MLKEM_ALGORITHMS * 2 + EXPECTED_MLDSA_ALGORITHMS * 2))
        local arch_found=$((mlkem_json_count + mlkem_csv_count + mldsa_json_count + mldsa_csv_count))
        
        total_expected=$((total_expected + arch_expected))
        total_found=$((total_found + arch_found))
        
        log_info "  ${arch}: ${arch_found}/${arch_expected} files"
        log_debug "    ML-KEM: ${mlkem_json_count} JSON, ${mlkem_csv_count} CSV"
        log_debug "    ML-DSA: ${mldsa_json_count} JSON, ${mldsa_csv_count} CSV"
        
        if [[ ${arch_found} -lt ${arch_expected} ]]; then
            incomplete=true
        fi
    done
    
    log_info "Total: ${total_found}/${total_expected} files"
    
    if [[ "${incomplete}" == "true" ]]; then
        log_warn "Some result files are missing"
        return 1
    fi
    
    log_success "All expected files are present"
    return 0
}

# ============================================================================
# Data Quality Validation (SRP - Quality checks only)
# ============================================================================

validate_data_python() {
    local data_dir="$1"
    
    log_info "Running Python data validator..."
    
    local validator="${SCRIPT_DIR}/validate_data.py"
    
    if [[ ! -f "${validator}" ]]; then
        log_error "Python validator not found: ${validator}"
        return 1
    fi
    
    if python3 "${validator}" "${data_dir}" --recursive; then
        log_success "Python data validation passed"
        return 0
    else
        log_error "Python data validation failed"
        return 1
    fi
}

# ============================================================================
# Integrity Validation (SRP - Integrity checks only)
# ============================================================================

generate_checksums() {
    local base_dir="$1"
    local output_file="$2"
    
    log_info "Generating checksums..."
    
    # Find all result files
    local file_count=$(find "${base_dir}" -type f \
        \( -name "*.json" -o -name "*.csv" \) 2>/dev/null | wc -l)
    
    if [[ ${file_count} -eq 0 ]]; then
        log_warn "No result files found in ${base_dir}"
        return 1
    fi
    
    log_info "Processing ${file_count} files..."
    
    # Generate checksums (sorted by filename)
    (cd "${base_dir}" && \
     find . -type f \( -name "*.json" -o -name "*.csv" \) \
     -exec ${CHECKSUM_ALGO} {} \; | sort -k2 > "${output_file}")
    
    if [[ $? -eq 0 ]]; then
        log_success "Checksums saved to: ${output_file}"
        log_info "Total files: $(wc -l < ${output_file})"
        return 0
    else
        log_error "Failed to generate checksums"
        return 1
    fi
}

verify_checksums() {
    local base_dir="$1"
    local checksum_file="$2"
    
    if [[ ! -f "${checksum_file}" ]]; then
        log_warn "No checksum file found: ${checksum_file}"
        return 1
    fi
    
    log_info "Verifying checksums..."
    
    local total=$(wc -l < "${checksum_file}")
    log_info "Verifying ${total} files..."
    
    (cd "${base_dir}" && ${CHECKSUM_ALGO} -c "${checksum_file}" --quiet)
    
    if [[ $? -eq 0 ]]; then
        log_success "All checksums verified successfully"
        return 0
    else
        log_error "Checksum verification failed"
        return 1
    fi
}

# ============================================================================
# Report Generation (SRP - Reporting only)
# ============================================================================

generate_validation_report() {
    local base_dir="$1"
    local report_file="$2"
    
    log_info "Generating validation report..."
    
    {
        echo "=============================================="
        echo "Experimental Results Validation Report"
        echo "=============================================="
        echo ""
        echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo "Base Directory: ${base_dir}"
        echo "Hostname: $(hostname)"
        echo ""
        echo "=============================================="
        echo "Directory Structure"
        echo "=============================================="
        echo ""
        
        for arch in "${ARCHITECTURES[@]}"; do
            echo "Architecture: ${arch}"
            echo "  ML-KEM directory: ${base_dir}/${arch}/${MLKEM_SUBDIR}"
            echo "    Exists: $([ -d "${base_dir}/${arch}/${MLKEM_SUBDIR}" ] && echo "Yes" || echo "No")"
            echo "    JSON files: $(count_result_files "${base_dir}/${arch}/${MLKEM_SUBDIR}" "*.json")"
            echo "    CSV files: $(count_result_files "${base_dir}/${arch}/${MLKEM_SUBDIR}" "*.csv")"
            echo ""
            echo "  ML-DSA directory: ${base_dir}/${arch}/${MLDSA_SUBDIR}"
            echo "    Exists: $([ -d "${base_dir}/${arch}/${MLDSA_SUBDIR}" ] && echo "Yes" || echo "No")"
            echo "    JSON files: $(count_result_files "${base_dir}/${arch}/${MLDSA_SUBDIR}" "*.json")"
            echo "    CSV files: $(count_result_files "${base_dir}/${arch}/${MLDSA_SUBDIR}" "*.csv")"
            echo ""
        done
        
        echo "=============================================="
        echo "File Statistics"
        echo "=============================================="
        echo ""
        
        local total_json=$(find "${base_dir}" -name "*.json" -type f 2>/dev/null | wc -l)
        local total_csv=$(find "${base_dir}" -name "*.csv" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sh "${base_dir}" 2>/dev/null | cut -f1)
        
        echo "Total JSON files: ${total_json}"
        echo "Total CSV files: ${total_csv}"
        echo "Total size: ${total_size}"
        echo ""
        
        echo "=============================================="
        echo "Expected vs Actual"
        echo "=============================================="
        echo ""
        
        local expected_total=$((EXPECTED_ARCHITECTURES * (EXPECTED_MLKEM_ALGORITHMS + EXPECTED_MLDSA_ALGORITHMS) * 2))
        local actual_total=$((total_json + total_csv))
        
        echo "Expected files: ${expected_total}"
        echo "Actual files: ${actual_total}"
        echo "Completeness: $(awk "BEGIN {printf \"%.1f\", (${actual_total}/${expected_total})*100}")%"
        echo ""
        
    } > "${report_file}"
    
    log_success "Validation report saved to: ${report_file}"
    
    # Print summary to console
    cat "${report_file}"
}

# ============================================================================
# Orchestration (SRP - Coordination only)
# ============================================================================

perform_full_validation() {
    local data_dir="$1"
    local generate_report="$2"
    
    log_section "Starting Comprehensive Validation"
    
    local validation_passed=true
    
    # 1. Directory structure check
    log_section "Step 1: Directory Structure"
    if ! check_directory_structure "${data_dir}"; then
        log_warn "Directory structure validation failed (non-fatal)"
    fi
    
    # 2. File completeness check
    log_section "Step 2: File Completeness"
    if ! check_file_completeness "${data_dir}"; then
        log_warn "File completeness check failed (non-fatal)"
    fi
    
    # 3. Python data validation
    log_section "Step 3: Data Quality Validation"
    if ! validate_data_python "${data_dir}"; then
        validation_passed=false
    fi
    
    # 4. Generate and verify checksums
    log_section "Step 4: Integrity Validation"
    local checksum_path="${data_dir}/${CHECKSUM_FILE}"
    
    if generate_checksums "${data_dir}" "${checksum_path}"; then
        verify_checksums "${data_dir}" "${checksum_path}"
    else
        log_warn "Checksum generation failed (non-fatal)"
    fi
    
    # 5. Generate report if requested
    if [[ "${generate_report}" == "true" ]]; then
        log_section "Step 5: Generating Report"
        local report_path="${data_dir}/${VALIDATION_REPORT}"
        generate_validation_report "${data_dir}" "${report_path}"
    fi
    
    if [[ "${validation_passed}" == "true" ]]; then
        log_success "Validation completed successfully"
        return 0
    else
        log_error "Validation completed with errors"
        return 1
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 <DIRECTORY> [OPTIONS]

Comprehensive validation of experimental results.

ARGUMENTS:
    DIRECTORY               Directory containing experimental results

OPTIONS:
    -h, --help              Show this help message
    -r, --report            Generate validation report
    --no-checksums          Skip checksum generation/verification
    --verify-only           Only verify existing checksums
    --generate-only         Only generate checksums (skip validation)
    
EXAMPLES:
    # Full validation with report
    $0 data/raw --report
    
    # Quick validation without checksums
    $0 data/raw/native --no-checksums
    
    # Only verify existing checksums
    $0 data/raw --verify-only
    
    # Only generate checksums
    $0 data/raw --generate-only
    
EOF
}

main() {
    # Check for directory argument
    if [[ $# -eq 0 ]]; then
        log_error "Directory not specified"
        usage
        exit 1
    fi
    
    local data_dir="$1"
    shift
    
    # Validate directory exists
    if [[ ! -d "${data_dir}" ]]; then
        log_error "Directory not found: ${data_dir}"
        exit 1
    fi
    
    # Parse options
    local generate_report=false
    local skip_checksums=false
    local verify_only=false
    local generate_only=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--report)
                generate_report=true
                shift
                ;;
            --no-checksums)
                skip_checksums=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --generate-only)
                generate_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Print banner
    cat <<EOF

╔════════════════════════════════════════════════════════════════╗
║         PQC Benchmarking - Result Validation System            ║
╚════════════════════════════════════════════════════════════════╝

Directory: ${data_dir}
Generate Report: ${generate_report}
Skip Checksums: ${skip_checksums}

EOF
    
    # Verify-only mode
    if [[ "${verify_only}" == "true" ]]; then
        log_section "Checksum Verification Mode"
        verify_checksums "${data_dir}" "${data_dir}/${CHECKSUM_FILE}"
        exit $?
    fi
    
    # Generate-only mode
    if [[ "${generate_only}" == "true" ]]; then
        log_section "Checksum Generation Mode"
        generate_checksums "${data_dir}" "${data_dir}/${CHECKSUM_FILE}"
        exit $?
    fi
    
    # Full validation mode
    if perform_full_validation "${data_dir}" "${generate_report}"; then
        log_section "Validation Completed Successfully"
        exit 0
    else
        log_section "Validation Completed with Errors"
        exit 1
    fi
}

# Execute main
main "$@"
