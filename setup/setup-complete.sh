#!/bin/bash
################################################################################
# Complete Environment Setup de Benchmarking PQC
# 
# This script automates the initial setup del proyecto:
# 1. QEMU installation para ARM y RISC-V
# 2. Toolchain installation de cross-compilación
# 3. Dependency installation de desarrollo
# 4. Complete environment verification
# 5. Directory structure creation
#
# Author: Proyecto Benchmarks PQC
# Version: 1.0
################################################################################

set -e  # Stop on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print with color
print_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_step() {
    echo -e "${MAGENTA}[STEP]${NC} $1"
}

# Verificar si estamos en Ubuntu/Debian
check_system() {
    print_header "CHECKING OPERATING SYSTEM"
    
    if ! [ -f /etc/debian_version ]; then
        print_error "This script is designed for Ubuntu/Debian"
        exit 1
    fi
    
    OS_NAME=$(lsb_release -si 2>/dev/null || echo "Unknown")
    OS_VERSION=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    
    print_status "Operating system: $OS_NAME $OS_VERSION"
    
    # Verificar Ubuntu 20.04+
    if [[ "$OS_NAME" == "Ubuntu" ]]; then
        VERSION_NUM=$(echo $OS_VERSION | cut -d. -f1)
        if [ "$VERSION_NUM" -lt 20 ]; then
            print_warning "Ubuntu recommended 20.04 or higher"
        fi
    fi
}

# Actualizar repositorios
update_repositories() {
    print_header "UPDATING REPOSITORIES"
    print_step "Running apt update..."
    sudo apt update
    print_status "Repositories updated"
}

# Instalar QEMU
install_qemu() {
    print_header "INSTALLING QEMU"
    
    if command -v qemu-system-aarch64 &> /dev/null && command -v qemu-system-riscv64 &> /dev/null; then
        print_warning "QEMU already installed"
        QEMU_VERSION=$(qemu-system-aarch64 --version | head -n1)
        print_info "$QEMU_VERSION"
        read -p "Reinstall anyway? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            return 0
        fi
    fi
    
    print_step "Installing QEMU packages..."
    sudo apt install -y \
        qemu-system-arm \
        qemu-system-misc \
        qemu-user-static \
        qemu-utils \
        binfmt-support
    
    print_status "QEMU installed successfully"
    
    # Verify installation
    if command -v qemu-system-aarch64 &> /dev/null; then
        print_info "QEMU ARM: $(command -v qemu-system-aarch64)"
    fi
    
    if command -v qemu-system-riscv64 &> /dev/null; then
        print_info "QEMU RISC-V: $(command -v qemu-system-riscv64)"
    fi
    
    QEMU_VERSION=$(qemu-system-aarch64 --version | head -n1)
    print_info "Version: $QEMU_VERSION"
}

# Instalar herramientas de compilación base
install_build_tools() {
    print_header "INSTALLING BUILD TOOLS"
    
    print_step "Instalando build-essential, cmake y dependencias..."
    sudo apt install -y \
        build-essential \
        cmake \
        ninja-build \
        git \
        make \
        pkg-config \
        autoconf \
        automake \
        libtool
    
    print_status "Build tools installed"
    
    # Show versions
    print_info "GCC: $(gcc --version | head -1)"
    print_info "CMake: $(cmake --version | head -1)"
    print_info "Git: $(git --version)"
}

# Instalar toolchains de cross-compilación
install_cross_toolchains() {
    print_header "INSTALLING CROSS-COMPILATION TOOLCHAINS"
    
    print_step "Installing toolchain ARM64 (aarch64)..."
    sudo apt install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu \
        libc6-dev-arm64-cross
    
    print_status "Toolchain installed"
    print_info "$(aarch64-linux-gnu-gcc --version | head -1)"
    
    print_step "Installing toolchain RISC-V64 (riscv64)..."
    sudo apt install -y \
        gcc-riscv64-linux-gnu \
        g++-riscv64-linux-gnu \
        binutils-riscv64-linux-gnu \
        libc6-dev-riscv64-cross
    
    print_status "Toolchain installed"
    print_info "$(riscv64-linux-gnu-gcc --version | head -1)"
}

# Instalar librerías de desarrollo
install_dev_libraries() {
    print_header "INSTALLING DEVELOPMENT LIBRARIES"
    
    print_step "Installing OpenSSL and other dependencies..."
    sudo apt install -y \
        libssl-dev \
        zlib1g-dev \
        libgmp-dev \
        libmpfr-dev \
        libmpc-dev
    
    print_status "Development libraries installed"
    
    if pkg-config --exists openssl; then
        print_info "OpenSSL: $(pkg-config --modversion openssl)"
    fi
}

# Instalar Python y dependencias
install_python_tools() {
    print_header "INSTALLING PYTHON AND DEPENDENCIES"
    
    print_step "Installing Python 3 and tools..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv
    
    print_status "Python installed"
    print_info "$(python3 --version)"
    print_info "pip: $(pip3 --version | cut -d' ' -f1-2)"
    
    print_step "Installing Python packages para análisis de datos..."
    pip3 install --user --upgrade \
        numpy \
        pandas \
        matplotlib \
        scipy \
        seaborn 2>/dev/null || print_warning "Some Python packages may require manual installation"
    
    print_status "Basic Python packages installed"
}

# Crear estructura de directorios
create_project_structure() {
    print_header "CREATING DIRECTORY STRUCTURE"
    
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    cd "$PROJECT_ROOT"
    
    REQUIRED_DIRS=(
        "setup"
        "build"
        "src/benchmarks"
        "src/utils"
        "src/tests"
        "scripts"
        "data/raw/native/mlkem"
        "data/raw/native/mldsa"
        "data/raw/arm64/mlkem"
        "data/raw/arm64/mldsa"
        "data/raw/riscv64/mlkem"
        "data/raw/riscv64/mldsa"
        "data/processed"
        "analysis"
        "docs"
        "results/figures"
        "results/tables"
    )
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_step "Created: $dir/"
        else
            print_info "Exists: $dir/"
        fi
    done
    
    # Crear archivos .gitkeep en directorios vacíos
    find data results -type d -empty -exec touch {}/.gitkeep \; 2>/dev/null || true
    
    print_status "Directory structure ready"
}

# Verify installation
verify_installation() {
    print_header "VERIFYING INSTALLATION"
    
    ERRORS=0
    
    # Verificar QEMU
    echo -e "\n${YELLOW}QEMU:${NC}"
    if command -v qemu-system-aarch64 &> /dev/null; then
        print_status "qemu-system-aarch64"
    else
        print_error "qemu-system-aarch64"
        ((ERRORS++))
    fi
    
    if command -v qemu-system-riscv64 &> /dev/null; then
        print_status "qemu-system-riscv64"
    else
        print_error "qemu-system-riscv64"
        ((ERRORS++))
    fi
    
    # Verificar compiladores nativos
    echo -e "\n${YELLOW}Native Compilers:${NC}"
    for cmd in gcc g++ cmake make; do
        if command -v $cmd &> /dev/null; then
            print_status "$cmd"
        else
            print_error "$cmd"
            ((ERRORS++))
        fi
    done
    
    # Verificar cross-compiladores
    echo -e "\n${YELLOW}Cross-Compilers:${NC}"
    if command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_status "aarch64-linux-gnu-gcc"
    else
        print_error "aarch64-linux-gnu-gcc"
        ((ERRORS++))
    fi
    
    if command -v riscv64-linux-gnu-gcc &> /dev/null; then
        print_status "riscv64-linux-gnu-gcc"
    else
        print_error "riscv64-linux-gnu-gcc"
        ((ERRORS++))
    fi
    
    # Verificar Python
    echo -e "\n${YELLOW}Python:${NC}"
    if command -v python3 &> /dev/null; then
        print_status "python3 ($(python3 --version 2>&1 | cut -d' ' -f2))"
    else
        print_error "python3"
        ((ERRORS++))
    fi
    
    # Verificar OpenSSL
    echo -e "\n${YELLOW}Librerías:${NC}"
    if pkg-config --exists openssl; then
        print_status "libssl-dev ($(pkg-config --modversion openssl))"
    else
        print_error "libssl-dev"
        ((ERRORS++))
    fi
    
    echo ""
    if [ $ERRORS -eq 0 ]; then
        print_status "ALL CHECKS PASSED"
        return 0
    else
        print_error "FOUND.*ERRORS"
        return 1
    fi
}

# Mostrar resumen final
show_summary() {
    print_header "INSTALLATION SUMMARY"
    
    echo "[+] QEMU 8.2+ installed (ARM y RISC-V)"
    echo "[+] GCC nativo installed"
    echo "[+] Toolchains cross-compilation (ARM64, RISC-V64)"
    echo "[+] CMake y herramientas de build"
    echo "[+] Python 3 y paquetes de análisis"
    echo "[+] Librerías de desarrollo (OpenSSL, etc.)"
    echo "[+] Directory structure created"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Installation completed successfully.${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo ""
    echo -e "${MAGENTA}Opción 1 - Complete automatic setup:${NC}"
    echo -e "    ${BLUE}make setup-complete${NC}  ${CYAN}(compile liboqs + benchmarks + run tests)${NC}"
    echo ""
    echo -e "${MAGENTA}Opción 2 - Step by step:${NC}"
    echo -e "    ${BLUE}make build-native${NC}        ${CYAN}# Compile liboqs${NC}"
    echo -e "    ${BLUE}make compile-benchmarks${NC}  ${CYAN}# Compile benchmarks${NC}"
    echo -e "    ${BLUE}make test-all${NC}            ${CYAN}# Run tests${NC}"
    echo ""
    echo -e "${MAGENTA}Optional - Other architectures:${NC}"
    echo -e "    ${BLUE}make build-arm${NC}           ${CYAN}# ARM64${NC}"
    echo -e "    ${BLUE}make build-riscv${NC}         ${CYAN}# RISC-V64${NC}"
    echo ""
    echo -e "${MAGENTA}View all commands:${NC}"
    echo -e "    ${BLUE}make help${NC}                ${CYAN}# Show complete help${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Run from: ${BLUE}$(pwd)${NC}"
    echo ""
}

# Función principal
main() {
    # Banner inicial
    clear
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                                                                                ${NC}"
    echo -e "${CYAN}                    ${MAGENTA}Post-Quantum Cryptography Benchmarks${CYAN}                    ${NC}"
    echo -e "${CYAN}                                                                                ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}ML-KEM & ML-DSA Performance Analysis${NC}"
    echo -e "  ${BLUE}ARM (AArch64) vs RISC-V (RV64GC) Comparative Study${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}Post-Quantum Cryptography Benchmarking Project${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Verificar si se ejecuta con privilegios adecuados
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root directamente"
        print_info "The script will request sudo permissions when necessary"
        exit 1
    fi
    
    # Solicitar confirmación
    print_warning "This script will install:"
    echo "  • QEMU (ARM y RISC-V)"
    echo "  • Compiladores y toolchains"
    echo "  • Librerías de desarrollo"
    echo "  • Python y paquetes de análisis"
    echo ""
    read -p "¿Continue with installation? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Installation cancelled by user"
        exit 0
    fi
    
    # Ejecutar pasos
    check_system
    update_repositories
    install_qemu
    install_build_tools
    install_cross_toolchains
    install_dev_libraries
    install_python_tools
    create_project_structure
    
    # Verificación final
    echo ""
    if verify_installation; then
        show_summary
        exit 0
    else
        print_header "INSTALLATION COMPLETED WITH WARNINGS"
        print_warning "Some tools were not installed correctly"
        print_info "Review previous errors e install manually if necessary"
        exit 1
    fi
}

# Execute main function
main "$@"
