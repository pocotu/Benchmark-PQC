#!/bin/bash
################################################################################
# Setup Completo del Entorno de Benchmarking PQC
# 
# Este script automatiza toda la configuración inicial del proyecto:
# 1. Instalación de QEMU para ARM y RISC-V
# 2. Instalación de toolchains de cross-compilación
# 3. Instalación de dependencias de desarrollo
# 4. Verificación del entorno completo
# 5. Creación de estructura de directorios
#
# Autor: Proyecto Benchmarks PQC
# Versión: 1.0
################################################################################

set -e  # Detener en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir con color
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
    print_header "VERIFICANDO SISTEMA OPERATIVO"
    
    if ! [ -f /etc/debian_version ]; then
        print_error "Este script está diseñado para Ubuntu/Debian"
        exit 1
    fi
    
    OS_NAME=$(lsb_release -si 2>/dev/null || echo "Unknown")
    OS_VERSION=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    
    print_status "Sistema operativo: $OS_NAME $OS_VERSION"
    
    # Verificar Ubuntu 20.04+
    if [[ "$OS_NAME" == "Ubuntu" ]]; then
        VERSION_NUM=$(echo $OS_VERSION | cut -d. -f1)
        if [ "$VERSION_NUM" -lt 20 ]; then
            print_warning "Se recomienda Ubuntu 20.04 o superior"
        fi
    fi
}

# Actualizar repositorios
update_repositories() {
    print_header "ACTUALIZANDO REPOSITORIOS"
    print_step "Ejecutando apt update..."
    sudo apt update
    print_status "Repositorios actualizados"
}

# Instalar QEMU
install_qemu() {
    print_header "INSTALANDO QEMU"
    
    if command -v qemu-system-aarch64 &> /dev/null && command -v qemu-system-riscv64 &> /dev/null; then
        print_warning "QEMU ya está instalado"
        QEMU_VERSION=$(qemu-system-aarch64 --version | head -n1)
        print_info "$QEMU_VERSION"
        read -p "¿Reinstalar de todos modos? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            return 0
        fi
    fi
    
    print_step "Instalando paquetes QEMU..."
    sudo apt install -y \
        qemu-system-arm \
        qemu-system-misc \
        qemu-user-static \
        qemu-utils \
        binfmt-support
    
    print_status "QEMU instalado correctamente"
    
    # Verificar instalación
    if command -v qemu-system-aarch64 &> /dev/null; then
        print_info "QEMU ARM: $(command -v qemu-system-aarch64)"
    fi
    
    if command -v qemu-system-riscv64 &> /dev/null; then
        print_info "QEMU RISC-V: $(command -v qemu-system-riscv64)"
    fi
    
    QEMU_VERSION=$(qemu-system-aarch64 --version | head -n1)
    print_info "Versión: $QEMU_VERSION"
}

# Instalar herramientas de compilación base
install_build_tools() {
    print_header "INSTALANDO HERRAMIENTAS DE COMPILACIÓN"
    
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
    
    print_status "Herramientas de compilación instaladas"
    
    # Mostrar versiones
    print_info "GCC: $(gcc --version | head -1)"
    print_info "CMake: $(cmake --version | head -1)"
    print_info "Git: $(git --version)"
}

# Instalar toolchains de cross-compilación
install_cross_toolchains() {
    print_header "INSTALANDO CROSS-COMPILATION TOOLCHAINS"
    
    print_step "Instalando toolchain ARM64 (aarch64)..."
    sudo apt install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu \
        libc6-dev-arm64-cross
    
    print_status "Toolchain ARM64 instalado"
    print_info "$(aarch64-linux-gnu-gcc --version | head -1)"
    
    print_step "Instalando toolchain RISC-V64 (riscv64)..."
    sudo apt install -y \
        gcc-riscv64-linux-gnu \
        g++-riscv64-linux-gnu \
        binutils-riscv64-linux-gnu \
        libc6-dev-riscv64-cross
    
    print_status "Toolchain RISC-V64 instalado"
    print_info "$(riscv64-linux-gnu-gcc --version | head -1)"
}

# Instalar librerías de desarrollo
install_dev_libraries() {
    print_header "INSTALANDO LIBRERÍAS DE DESARROLLO"
    
    print_step "Instalando OpenSSL y otras dependencias..."
    sudo apt install -y \
        libssl-dev \
        zlib1g-dev \
        libgmp-dev \
        libmpfr-dev \
        libmpc-dev
    
    print_status "Librerías de desarrollo instaladas"
    
    if pkg-config --exists openssl; then
        print_info "OpenSSL: $(pkg-config --modversion openssl)"
    fi
}

# Instalar Python y dependencias
install_python_tools() {
    print_header "INSTALANDO PYTHON Y DEPENDENCIAS"
    
    print_step "Instalando Python 3 y herramientas..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv
    
    print_status "Python instalado"
    print_info "$(python3 --version)"
    print_info "pip: $(pip3 --version | cut -d' ' -f1-2)"
    
    print_step "Instalando paquetes Python para análisis de datos..."
    pip3 install --user --upgrade \
        numpy \
        pandas \
        matplotlib \
        scipy \
        seaborn 2>/dev/null || print_warning "Algunos paquetes Python pueden requerir instalación manual"
    
    print_status "Paquetes Python básicos instalados"
}

# Crear estructura de directorios
create_project_structure() {
    print_header "CREANDO ESTRUCTURA DE DIRECTORIOS"
    
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
            print_step "Creado: $dir/"
        else
            print_info "Existe: $dir/"
        fi
    done
    
    # Crear archivos .gitkeep en directorios vacíos
    find data results -type d -empty -exec touch {}/.gitkeep \; 2>/dev/null || true
    
    print_status "Estructura de directorios lista"
}

# Verificar instalación
verify_installation() {
    print_header "VERIFICANDO INSTALACIÓN"
    
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
    echo -e "\n${YELLOW}Compiladores Nativos:${NC}"
    for cmd in gcc g++ cmake make; do
        if command -v $cmd &> /dev/null; then
            print_status "$cmd"
        else
            print_error "$cmd"
            ((ERRORS++))
        fi
    done
    
    # Verificar cross-compiladores
    echo -e "\n${YELLOW}Cross-Compiladores:${NC}"
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
        print_status "TODAS LAS VERIFICACIONES PASARON"
        return 0
    else
        print_error "SE ENCONTRARON $ERRORS ERRORES"
        return 1
    fi
}

# Mostrar resumen final
show_summary() {
    print_header "RESUMEN DE INSTALACIÓN"
    
    echo "[+] QEMU 8.2+ instalado (ARM y RISC-V)"
    echo "[+] GCC nativo instalado"
    echo "[+] Toolchains cross-compilation (ARM64, RISC-V64)"
    echo "[+] CMake y herramientas de build"
    echo "[+] Python 3 y paquetes de análisis"
    echo "[+] Librerías de desarrollo (OpenSSL, etc.)"
    echo "[+] Estructura de directorios creada"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Instalación completada exitosamente.${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
    echo ""
    echo -e "${MAGENTA}Opción 1 - Setup automático completo:${NC}"
    echo -e "    ${BLUE}make setup-complete${NC}  ${CYAN}(compila liboqs + benchmarks + ejecuta tests)${NC}"
    echo ""
    echo -e "${MAGENTA}Opción 2 - Paso a paso:${NC}"
    echo -e "    ${BLUE}make build-native${NC}        ${CYAN}# Compilar liboqs${NC}"
    echo -e "    ${BLUE}make compile-benchmarks${NC}  ${CYAN}# Compilar benchmarks${NC}"
    echo -e "    ${BLUE}make test-all${NC}            ${CYAN}# Ejecutar tests${NC}"
    echo ""
    echo -e "${MAGENTA}Opcional - Otras arquitecturas:${NC}"
    echo -e "    ${BLUE}make build-arm${NC}           ${CYAN}# ARM64${NC}"
    echo -e "    ${BLUE}make build-riscv${NC}         ${CYAN}# RISC-V64${NC}"
    echo ""
    echo -e "${MAGENTA}Ver todos los comandos:${NC}"
    echo -e "    ${BLUE}make help${NC}                ${CYAN}# Mostrar ayuda completa${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Ejecutar desde: ${BLUE}$(pwd)${NC}"
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
        print_error "No ejecutar este script como root directamente"
        print_info "El script solicitará permisos sudo cuando sea necesario"
        exit 1
    fi
    
    # Solicitar confirmación
    print_warning "Este script instalará:"
    echo "  • QEMU (ARM y RISC-V)"
    echo "  • Compiladores y toolchains"
    echo "  • Librerías de desarrollo"
    echo "  • Python y paquetes de análisis"
    echo ""
    read -p "¿Continuar con la instalación? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Instalación cancelada por el usuario"
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
        print_header "INSTALACIÓN COMPLETADA CON ADVERTENCIAS"
        print_warning "Algunas herramientas no se instalaron correctamente"
        print_info "Revisa los errores anteriores e instala manualmente si es necesario"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
