#!/usr/bin/env bash
#
# PQC Benchmarking - Interactive Menu
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Source common functions
if [[ -f "${SCRIPT_DIR}/scripts/common-functions.sh" ]]; then
    source "${SCRIPT_DIR}/scripts/common-functions.sh"
else
    readonly BOLD='\033[1m'
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly RESET='\033[0m'
fi

# Source banner functions
if [[ -f "${SCRIPT_DIR}/lib/banner-functions.sh" ]]; then
    source "${SCRIPT_DIR}/lib/banner-functions.sh"
fi

# =============================================================================
# Display Functions
# =============================================================================

show_header() {
    clear
    if type -t show_project_banner &>/dev/null; then
        show_project_banner
    else
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}       ${BOLD}${MAGENTA}PQC Benchmarking System${RESET}                           ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}    ${BLUE}ML-KEM & ML-DSA Performance Analysis${RESET}                  ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    fi
    echo ""
}

show_main_menu() {
    echo -e "${BOLD}${CYAN}┌─ Main Menu ─────────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Setup${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}1)${RESET} Check Environment"
    echo -e "${CYAN}│${RESET}    ${GREEN}2)${RESET} Setup Complete (liboqs + benchmarks)"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Build${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}3)${RESET} Build liboqs (all architectures)"
    echo -e "${CYAN}│${RESET}    ${GREEN}4)${RESET} Compile Benchmarks"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Benchmarking${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}5)${RESET} Run Benchmarks (x86_64)"
    echo -e "${CYAN}│${RESET}    ${GREEN}6)${RESET} Run QEMU Benchmarks (ARM64 + RISC-V64)"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Analysis${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}7)${RESET} Full Analysis Pipeline"
    echo -e "${CYAN}│${RESET}    ${GREEN}8)${RESET} Full PKI Modeling"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Validation${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}9)${RESET} Validate Data Integrity"
    echo -e "${CYAN}│${RESET}    ${GREEN}10)${RESET} Verify Checksums"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}  ${BOLD}Maintenance${RESET}"
    echo -e "${CYAN}│${RESET}    ${GREEN}11)${RESET} Clean Builds"
    echo -e "${CYAN}│${RESET}    ${GREEN}12)${RESET} Show Help"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}│${RESET}    ${YELLOW}0)${RESET} ${BOLD}Exit${RESET}"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
}

show_status_bar() {
    local status="$1"
    local color="${2:-$GREEN}"
    echo ""
    echo -e "${color}─────────────────────────────────────────────────────────────${RESET}"
    echo -e "${color}${status}${RESET}"
    echo -e "${color}─────────────────────────────────────────────────────────────${RESET}"
}

press_any_key() {
    echo ""
    echo -e "${CYAN}Press any key to continue...${RESET}"
    read -n 1 -s -r
}

# =============================================================================
# Execution Functions
# =============================================================================

execute_make_target() {
    local target="$1"
    local description="$2"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}Executing: ${description}${RESET}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo ""
    
    if make -C "${PROJECT_ROOT}" "${target}"; then
        show_status_bar "✓ ${description} completed" "${GREEN}"
        return 0
    else
        show_status_bar "✗ ${description} failed" "${RED}"
        return 1
    fi
}

execute_script() {
    local script="$1"
    local description="$2"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}Executing: ${description}${RESET}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo ""
    
    if "${PROJECT_ROOT}/${script}"; then
        show_status_bar "✓ ${description} completed" "${GREEN}"
        return 0
    else
        show_status_bar "✗ ${description} failed" "${RED}"
        return 1
    fi
}

# =============================================================================
# Menu Actions
# =============================================================================

action_check_env() {
    execute_make_target "check-env" "Environment Check"
    press_any_key
}

action_setup_complete() {
    execute_make_target "setup-complete" "Complete Setup"
    press_any_key
}

action_build_all() {
    execute_make_target "build" "Build liboqs (all architectures)"
    press_any_key
}

action_compile_benchmarks() {
    execute_make_target "compile-benchmarks" "Compile Benchmarks"
    press_any_key
}

action_run_benchmarks() {
    execute_make_target "run-benchmarks" "x86_64 Benchmarks"
    press_any_key
}

action_run_qemu_benchmarks() {
    execute_script "scripts/run_all_qemu_benchmarks.sh" "QEMU Benchmarks (ARM64 + RISC-V64)"
    press_any_key
}

action_full_analysis() {
    execute_make_target "full-analysis" "Full Analysis Pipeline"
    press_any_key
}

action_full_pki_modeling() {
    execute_make_target "full-pki-modeling" "Full PKI Modeling"
    press_any_key
}

action_validate_data() {
    execute_make_target "validate-data" "Data Validation"
    press_any_key
}

action_verify_checksums() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}Verifying Checksums${RESET}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo ""
    
    if python3 "${PROJECT_ROOT}/verify_checksums.py"; then
        show_status_bar "✓ Checksums verified" "${GREEN}"
    else
        show_status_bar "✗ Checksum verification failed" "${RED}"
    fi
    press_any_key
}

action_clean() {
    echo ""
    echo -e "${YELLOW}This will delete build artifacts (liboqs, binaries).${RESET}"
    echo -e "${YELLOW}Experimental data will NOT be deleted.${RESET}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        execute_make_target "clean" "Clean Builds"
        execute_make_target "clean-benchmarks" "Clean Binaries"
    else
        show_status_bar "Operation cancelled" "${YELLOW}"
    fi
    press_any_key
}

action_show_help() {
    execute_make_target "help" "Show Help"
    press_any_key
}

action_exit() {
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}        ${BOLD}Thank you for using PQC Benchmarking!${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
}

# =============================================================================
# Main Menu Loop
# =============================================================================

main_menu_loop() {
    local choice
    
    while true; do
        show_header
        show_main_menu
        
        echo -ne "${BOLD}${CYAN}Select option [0-12]: ${RESET}"
        read -r choice
        
        case "${choice}" in
            1)  action_check_env ;;
            2)  action_setup_complete ;;
            3)  action_build_all ;;
            4)  action_compile_benchmarks ;;
            5)  action_run_benchmarks ;;
            6)  action_run_qemu_benchmarks ;;
            7)  action_full_analysis ;;
            8)  action_full_pki_modeling ;;
            9)  action_validate_data ;;
            10) action_verify_checksums ;;
            11) action_clean ;;
            12) action_show_help ;;
            0)  action_exit ;;
            *)
                show_status_bar "Invalid option. Please select 0-12." "${RED}"
                press_any_key
                ;;
        esac
    done
}

# =============================================================================
# Entry Point
# =============================================================================

main() {
    if [[ ! -t 0 ]]; then
        echo "Error: This script requires an interactive terminal."
        exit 1
    fi
    main_menu_loop
}

main "$@"
