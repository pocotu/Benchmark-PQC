#!/usr/bin/env bash
#
# Banner Functions - Centralized banner/header display
# SOLID Principle: Single Responsibility - All banners in one place
#
# Usage:
#   source lib/banner-functions.sh
#   show_project_banner
#   show_makefile_header
#

# Colors (if not already defined)
# Note: Checking if variables are set to work with set -u
if ! declare -p CYAN &>/dev/null; then
    readonly CYAN='\033[0;36m'
fi
if ! declare -p BLUE &>/dev/null; then
    readonly BLUE='\033[0;34m'
fi
if ! declare -p MAGENTA &>/dev/null; then
    readonly MAGENTA='\033[0;35m'
fi
if ! declare -p BOLD &>/dev/null; then
    readonly BOLD='\033[1m'
fi
if ! declare -p RESET &>/dev/null; then
    readonly RESET='\033[0m'
fi

# =============================================================================
# Banner Functions (DRY Principle - Define Once, Use Everywhere)
# =============================================================================

## Show main project banner (for interactive menu)
show_project_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}                  ${BOLD}${MAGENTA}PQC Benchmarking System${RESET}                              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${BLUE}ML-KEM & ML-DSA Performance Analysis${RESET}                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${RESET}"
}

## Show Makefile help header (shorter version for make help)
show_makefile_header() {
    echo "$(tput setaf 6)╔════════════════════════════════════════════════════════════╗$(tput sgr0)"
    echo "$(tput setaf 6)║  Benchmarks PQC - Makefile Principal                      ║$(tput sgr0)"
    echo "$(tput setaf 6)║  ML-KEM & ML-DSA Performance en ARM vs RISC-V            ║$(tput sgr0)"
    echo "$(tput setaf 6)╚════════════════════════════════════════════════════════════╝$(tput sgr0)"
}

## Show section separator
show_section_separator() {
    local title="$1"
    local color="${2:-6}" # Default: cyan (6)
    echo "$(tput setaf ${color})═══════════════════════════════════════════════════════════$(tput sgr0)"
    echo "$(tput setaf ${color})   ${title}$(tput sgr0)"
    echo "$(tput setaf ${color})═══════════════════════════════════════════════════════════$(tput sgr0)"
}

## Show completion banner
show_completion_banner() {
    local message="$1"
    echo ""
    echo "$(tput setaf 2)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(tput sgr0)"
    echo "$(tput setaf 2)${message}$(tput sgr0)"
    echo "$(tput setaf 2)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(tput sgr0)"
    echo ""
}

## Show info box
show_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    
    echo ""
    echo "$(tput setaf 6)╔════════════════════════════════════════════════════════════╗$(tput sgr0)"
    echo "$(tput setaf 6)║             ${title}                       ║$(tput sgr0)"
    echo "$(tput setaf 6)╚════════════════════════════════════════════════════════════╝$(tput sgr0)"
    echo ""
    for line in "${lines[@]}"; do
        echo "${line}"
    done
    echo ""
}
