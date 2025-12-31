#!/bin/bash
# Script to clean temporary and generated files from the project
# Usage: ./scripts/clean_project.sh [--all]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Get project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║           Benchmarks-PQC Project Cleanup                  ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""

cd "$PROJECT_ROOT"

# Function to show progress
clean_item() {
    local description="$1"
    local command="$2"
    
    echo -n "  Cleaning $description... "
    if eval "$command" 2>/dev/null; then
        echo -e "${GREEN}✓${RESET}"
        return 0
    else
        echo -e "${YELLOW}⚠${RESET}"
        return 1
    fi
}

# ============================================================================
# Basic cleanup (always runs)
# ============================================================================

echo -e "${BLUE}[1/3]${RESET} Cleaning Python temporary files"
clean_item "__pycache__" "find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true"
clean_item "*.pyc, *.pyo, *.pyd" "find . -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.pyd' \) -delete"
clean_item ".pytest_cache" "rm -rf .pytest_cache"
clean_item "Hypothesis examples" "rm -rf .hypothesis/examples"
echo ""

echo -e "${BLUE}[2/3]${RESET} Cleaning coverage files"
clean_item "htmlcov/" "rm -rf htmlcov"
clean_item ".coverage*" "rm -f .coverage .coverage.* coverage.xml coverage.json"
clean_item "coverage/" "rm -rf coverage/c coverage/python coverage/combined"
echo ""

echo -e "${BLUE}[3/3]${RESET} Cleaning temporary files"
clean_item "*.backup, *.bak" "find . -type f \( -name '*.backup' -o -name '*.bak' -o -name '*~' \) -delete"
clean_item "*.tmp, *.swp" "find . -type f \( -name '*.tmp' -o -name '*.swp' -o -name '*.swo' \) -delete"
clean_item "*.log (build)" "find build/ -name '*.log' -delete 2>/dev/null || true"
echo ""

# ============================================================================
# Deep cleanup (only with --all)
# ============================================================================

if [[ "$1" == "--all" ]]; then
    echo -e "${YELLOW}[DEEP CLEANUP]${RESET} Removing generated files"
    echo ""
    
    clean_item "Build artifacts" "rm -rf build/bin/* build/obj/* build/liboqs/"
    clean_item "Object files" "find . -type f \( -name '*.o' -o -name '*.a' -o -name '*.so' \) -delete"
    clean_item "Generated results" "rm -rf results/*.json results/*.csv results/figures/*.png results/figures/*.svg"
    clean_item "Processed data" "rm -rf data/processed/*.json data/processed/*.csv"
    clean_item "Checkpoints" "rm -rf data/checkpoints/*.checkpoint"
    clean_item "Metadata" "rm -rf data/metadata/*.json"
    clean_item "Generated metrics" "rm -rf metrics/complexity/*.txt metrics/complexity/*.json metrics/duplication/*.txt metrics/reports/"
    clean_item "Backups" "rm -rf backups/"
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                  Cleanup Completed                         ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""

if [[ "$1" == "--all" ]]; then
    echo -e "${GREEN}✓${RESET} Deep cleanup completed"
    echo -e "  ${YELLOW}Note:${RESET} Generated files and builds were removed"
    echo -e "  ${YELLOW}Run 'make build-native' to rebuild${RESET}"
else
    echo -e "${GREEN}✓${RESET} Basic cleanup completed"
    echo -e "  ${BLUE}Tip:${RESET} Use './scripts/clean_project.sh --all' for deep cleanup"
fi

echo ""
echo -e "${CYAN}Files removed:${RESET}"
echo -e "  • Python temporary files (__pycache__, *.pyc)"
echo -e "  • Coverage files (htmlcov/, .coverage)"
echo -e "  • Temporary files (*.tmp, *.swp, *.backup)"

if [[ "$1" == "--all" ]]; then
    echo -e "  • Build artifacts (*.o, *.a, binaries)"
    echo -e "  • Generated results (JSON, CSV, PNG)"
    echo -e "  • Processed data and checkpoints"
    echo -e "  • Generated metrics and reports"
fi

echo ""
exit 0
