#!/bin/bash
# ============================================================================
# Incremental Backup System for Experimental Data
# ============================================================================
# Creates incremental backups of experimental results with integrity checks
# using rsync and SHA256 checksums.
# ============================================================================

set -euo pipefail

# Sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/common-functions.sh"

# ============================================================================
# Backup Configuration
# ============================================================================

# Source directories
DATA_DIR="${PROJECT_ROOT}/data"
RESULTS_DIR="${PROJECT_ROOT}/results"

# Default backup destination
DEFAULT_BACKUP_DIR="${PROJECT_ROOT}/backups"

# Backup naming
BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PREFIX="backup"

# Compression settings
USE_COMPRESSION=true
COMPRESSION_LEVEL=6  # 1 (fast) to 9 (best compression)

# Integrity checks
GENERATE_CHECKSUMS=true
CHECKSUM_ALGORITHM="sha256"

# Retention policy (in days)
RETENTION_DAYS=30

# ============================================================================
# Backup Functions
# ============================================================================

create_backup() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_name="$3"
    
    log_info "Creating backup: ${backup_name}"
    log_debug "Source: ${source_dir}"
    log_debug "Destination: ${dest_dir}"
    
    # Create destination directory
    mkdir -p "${dest_dir}"
    
    # Build rsync command
    local rsync_opts="-av --progress"
    
    if [[ "${USE_COMPRESSION}" == "true" ]]; then
        rsync_opts+=" -z --compress-level=${COMPRESSION_LEVEL}"
    fi
    
    # Incremental backup using hard links (saves space)
    local latest_link="${dest_dir}/latest"
    if [[ -d "${latest_link}" ]]; then
        rsync_opts+=" --link-dest=${latest_link}"
        log_info "Using incremental backup from: $(basename $(readlink -f ${latest_link}))"
    else
        log_info "Creating full backup (no previous backup found)"
    fi
    
    # Execute rsync
    local backup_path="${dest_dir}/${backup_name}"
    
    if rsync ${rsync_opts} "${source_dir}/" "${backup_path}/"; then
        log_success "Backup created: ${backup_path}"
        
        # Update latest symlink
        ln -sfn "${backup_path}" "${latest_link}"
        log_debug "Updated latest symlink"
        
        return 0
    else
        log_error "Backup failed for ${source_dir}"
        return 1
    fi
}

# ============================================================================
# Checksum Functions
# ============================================================================

generate_checksums() {
    local backup_dir="$1"
    local checksum_file="${backup_dir}/checksums.${CHECKSUM_ALGORITHM}"
    
    log_info "Generating checksums for ${backup_dir}"
    
    # Find all data files
    local file_count=$(find "${backup_dir}" -type f \
        \( -name "*.json" -o -name "*.csv" -o -name "*.txt" \) | wc -l)
    
    if [[ ${file_count} -eq 0 ]]; then
        log_warn "No data files found in ${backup_dir}"
        return 0
    fi
    
    log_info "Processing ${file_count} files..."
    
    # Generate checksums
    (cd "${backup_dir}" && \
     find . -type f \( -name "*.json" -o -name "*.csv" -o -name "*.txt" \) \
     -exec ${CHECKSUM_ALGORITHM}sum {} \; | sort -k2 > "${checksum_file}")
    
    if [[ $? -eq 0 ]]; then
        log_success "Checksums saved to: ${checksum_file}"
        log_info "Total files: $(wc -l < ${checksum_file})"
        return 0
    else
        log_error "Failed to generate checksums"
        return 1
    fi
}

verify_checksums() {
    local backup_dir="$1"
    local checksum_file="${backup_dir}/checksums.${CHECKSUM_ALGORITHM}"
    
    if [[ ! -f "${checksum_file}" ]]; then
        log_warn "No checksum file found: ${checksum_file}"
        return 1
    fi
    
    log_info "Verifying checksums in ${backup_dir}"
    
    (cd "${backup_dir}" && ${CHECKSUM_ALGORITHM}sum -c "${checksum_file}" --quiet)
    
    if [[ $? -eq 0 ]]; then
        log_success "All checksums verified successfully"
        return 0
    else
        log_error "Checksum verification failed"
        return 1
    fi
}

# ============================================================================
# Metadata Functions
# ============================================================================

create_backup_metadata() {
    local backup_dir="$1"
    local metadata_file="${backup_dir}/backup_metadata.json"
    
    log_info "Creating backup metadata"
    
    # Count files by type
    local json_count=$(find "${backup_dir}" -name "*.json" -type f | wc -l)
    local csv_count=$(find "${backup_dir}" -name "*.csv" -type f | wc -l)
    local total_size=$(du -sh "${backup_dir}" | cut -f1)
    
    # Generate metadata JSON
    cat > "${metadata_file}" <<EOF
{
  "backup_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_name": "$(basename ${backup_dir})",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "source_directories": [
    "${DATA_DIR}",
    "${RESULTS_DIR}"
  ],
  "statistics": {
    "json_files": ${json_count},
    "csv_files": ${csv_count},
    "total_size": "${total_size}"
  },
  "checksum_algorithm": "${CHECKSUM_ALGORITHM}",
  "compression_used": ${USE_COMPRESSION},
  "compression_level": ${COMPRESSION_LEVEL}
}
EOF
    
    log_success "Metadata saved to: ${metadata_file}"
    log_info "  JSON files: ${json_count}"
    log_info "  CSV files: ${csv_count}"
    log_info "  Total size: ${total_size}"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup_old_backups() {
    local backup_base_dir="$1"
    local retention_days="$2"
    
    log_info "Cleaning up backups older than ${retention_days} days"
    
    # Find old backups
    local old_backups=$(find "${backup_base_dir}" -maxdepth 1 -type d \
        -name "${BACKUP_PREFIX}_*" -mtime +${retention_days} 2>/dev/null)
    
    if [[ -z "${old_backups}" ]]; then
        log_info "No old backups to remove"
        return 0
    fi
    
    local count=0
    while IFS= read -r backup; do
        log_info "Removing old backup: $(basename ${backup})"
        rm -rf "${backup}"
        ((count++))
    done <<< "${old_backups}"
    
    log_success "Removed ${count} old backup(s)"
}

# ============================================================================
# Orchestration
# ============================================================================

perform_full_backup() {
    local backup_base_dir="$1"
    local backup_name="${BACKUP_PREFIX}_${BACKUP_TIMESTAMP}"
    
    log_section "Starting Backup Process"
    
    local failed=false
    
    # Backup data directory
    if [[ -d "${DATA_DIR}" ]]; then
        log_info "Backing up data directory..."
        if ! create_backup "${DATA_DIR}" "${backup_base_dir}/data" "${backup_name}"; then
            failed=true
        fi
    else
        log_warn "Data directory not found: ${DATA_DIR}"
    fi
    
    # Backup results directory
    if [[ -d "${RESULTS_DIR}" ]]; then
        log_info "Backing up results directory..."
        if ! create_backup "${RESULTS_DIR}" "${backup_base_dir}/results" "${backup_name}"; then
            failed=true
        fi
    else
        log_warn "Results directory not found: ${RESULTS_DIR}"
    fi
    
    if [[ "${failed}" == "true" ]]; then
        log_error "Some backups failed"
        return 1
    fi
    
    # Generate checksums if enabled
    if [[ "${GENERATE_CHECKSUMS}" == "true" ]]; then
        log_section "Generating Integrity Checksums"
        
        if [[ -d "${backup_base_dir}/data/${backup_name}" ]]; then
            generate_checksums "${backup_base_dir}/data/${backup_name}"
        fi
        
        if [[ -d "${backup_base_dir}/results/${backup_name}" ]]; then
            generate_checksums "${backup_base_dir}/results/${backup_name}"
        fi
    fi
    
    # Create backup metadata
    log_section "Creating Backup Metadata"
    
    for subdir in data results; do
        local backup_path="${backup_base_dir}/${subdir}/${backup_name}"
        if [[ -d "${backup_path}" ]]; then
            create_backup_metadata "${backup_path}"
        fi
    done
    
    log_success "Backup process completed successfully"
    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Create incremental backups of experimental data and results.

OPTIONS:
    -h, --help                  Show this help message
    -d, --dest DIRECTORY        Backup destination (default: ${DEFAULT_BACKUP_DIR})
    -n, --name NAME             Custom backup name
    --no-compression            Disable compression
    --no-checksums              Skip checksum generation
    --verify-only BACKUP_DIR    Only verify checksums of existing backup
    --cleanup                   Remove backups older than retention period
    --retention-days N          Retention period in days (default: ${RETENTION_DAYS})
    
EXAMPLES:
    # Create full backup with default settings
    $0
    
    # Create backup to custom location
    $0 --dest /mnt/external/pqc-backups
    
    # Create backup without compression (faster)
    $0 --no-compression
    
    # Verify existing backup
    $0 --verify-only /path/to/backup_20251110_120000
    
    # Cleanup old backups
    $0 --cleanup --retention-days 7
    
EOF
}

main() {
    local backup_dest="${DEFAULT_BACKUP_DIR}"
    local custom_name=""
    local verify_only=""
    local cleanup_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dest)
                backup_dest="$2"
                shift 2
                ;;
            -n|--name)
                custom_name="$2"
                shift 2
                ;;
            --no-compression)
                USE_COMPRESSION=false
                shift
                ;;
            --no-checksums)
                GENERATE_CHECKSUMS=false
                shift
                ;;
            --verify-only)
                verify_only="$2"
                shift 2
                ;;
            --cleanup)
                cleanup_only=true
                shift
                ;;
            --retention-days)
                RETENTION_DAYS="$2"
                shift 2
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
║           PQC Benchmarking - Backup System                     ║
╚════════════════════════════════════════════════════════════════╝

Destination: ${backup_dest}
Compression: ${USE_COMPRESSION}
Checksums: ${GENERATE_CHECKSUMS}
Retention: ${RETENTION_DAYS} days

EOF
    
    # Verify-only mode
    if [[ -n "${verify_only}" ]]; then
        log_section "Verification Mode"
        verify_checksums "${verify_only}"
        exit $?
    fi
    
    # Cleanup-only mode
    if [[ "${cleanup_only}" == "true" ]]; then
        log_section "Cleanup Mode"
        cleanup_old_backups "${backup_dest}/data" "${RETENTION_DAYS}"
        cleanup_old_backups "${backup_dest}/results" "${RETENTION_DAYS}"
        exit 0
    fi
    
    # Normal backup mode
    if perform_full_backup "${backup_dest}"; then
        log_section "Backup Completed Successfully"
        
        # Auto-cleanup old backups
        log_section "Cleanup"
        cleanup_old_backups "${backup_dest}/data" "${RETENTION_DAYS}"
        cleanup_old_backups "${backup_dest}/results" "${RETENTION_DAYS}"
        
        # Print backup location
        log_info "Backup saved to: ${backup_dest}"
        log_info "Latest backup: ${backup_dest}/data/latest"
        log_info "               ${backup_dest}/results/latest"
        
        exit 0
    else
        log_section "Backup Completed with Errors"
        exit 1
    fi
}

# Execute main
main "$@"
