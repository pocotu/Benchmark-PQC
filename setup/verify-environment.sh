#!/bin/bash
################################################################################
# Script de verificación del entorno
################################################################################

set -e

echo "Verificación del Entorno de Desarrollo"
echo "========================================="

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ERRORS=0

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
        ((ERRORS++))
    fi
}

echo "QEMU:"
check_command qemu-system-aarch64
check_command qemu-system-riscv64

echo "Compiladores:"
check_command gcc
check_command aarch64-linux-gnu-gcc
check_command riscv64-linux-gnu-gcc

echo "Herramientas:"
check_command cmake
check_command git
check_command python3

echo "Librerías:"
if pkg-config --exists openssl; then
    echo -e "${GREEN}[OK]${NC} openssl-dev"
else
    echo -e "${RED}[FAIL]${NC} openssl-dev"
    ((ERRORS++))
fi

echo "========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}[OK] Entorno verificado correctamente${NC}"
    exit 0
else
    echo -e "${RED}[✗] Se encontraron $ERRORS errores${NC}"
    echo "Por favor, instala las herramientas faltantes"
    exit 1
fi
