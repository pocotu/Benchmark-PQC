#!/bin/bash
################################################################################
# Script de instalación de QEMU 8.1.2+ con soporte ARM y RISC-V
################################################################################

set -e  # Detener en caso de error

echo "========================================="
echo "Instalación de QEMU para ARM y RISC-V"
echo "========================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Verificar si estamos en Ubuntu/Debian
if ! [ -f /etc/debian_version ]; then
    print_error "Este script está diseñado para Ubuntu/Debian"
    exit 1
fi

print_status "Sistema operativo compatible detectado"

# Actualizar repositorios
print_status "Actualizando repositorios..."
sudo apt update

# Instalar QEMU
print_status "Instalando QEMU..."
sudo apt install -y \
    qemu-system-arm \
    qemu-system-misc \
    qemu-user-static \
    qemu-utils

# Verificar instalación
print_status "Verificando instalación de QEMU..."

if ! command -v qemu-system-aarch64 &> /dev/null; then
    print_error "qemu-system-aarch64 no está instalado"
    exit 1
fi

if ! command -v qemu-system-riscv64 &> /dev/null; then
    print_error "qemu-system-riscv64 no está instalado"
    exit 1
fi

# Obtener versión
QEMU_VERSION=$(qemu-system-aarch64 --version | head -n1)
print_status "Versión instalada: $QEMU_VERSION"

# Verificar soporte de arquitecturas
print_status "Verificando soporte de arquitecturas..."

echo ""
echo "Arquitecturas ARM soportadas:"
qemu-system-aarch64 -cpu help | grep -E "Cortex-A|Neoverse" | head -5

echo ""
echo "Arquitecturas RISC-V soportadas:"
qemu-system-riscv64 -cpu help | grep -i "rv64"

# Instalar dependencias adicionales
print_status "Instalando dependencias adicionales..."
sudo apt install -y \
    build-essential \
    git \
    cmake \
    ninja-build \
    libssl-dev \
    python3 \
    python3-pip

print_status "¡Instalación completada exitosamente!"

echo ""
echo "========================================="
echo "Resumen de instalación"
echo "========================================="
echo "QEMU ARM:    $(command -v qemu-system-aarch64)"
echo "QEMU RISC-V: $(command -v qemu-system-riscv64)"
echo "Versión:     $QEMU_VERSION"
echo ""
print_status "Ejecuta './setup/verify-environment.sh' para verificar el setup completo"
