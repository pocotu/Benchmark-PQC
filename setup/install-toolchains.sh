#!/bin/bash
# filepath: /home/k4li/proyecto/PQC/Benchmarks-PQC/setup/install-toolchains.sh
# Instala cross-compilation toolchains para ARM64 y RISC-V64

set -e

echo "Instalando Cross-Compilation Toolchains"
echo "========================================="

echo "Actualizando repositorios..."
sudo apt update

echo "Instalando toolchains ARM64..."
sudo apt install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu

echo "Instalando toolchains RISC-V64..."
sudo apt install -y \
    gcc-riscv64-linux-gnu \
    g++-riscv64-linux-gnu \
    binutils-riscv64-linux-gnu

echo "Instalando herramientas adicionales..."
sudo apt install -y \
    qemu-user-static \
    binfmt-support

echo "========================================="
echo "✓ Toolchains instalados correctamente"
echo "ARM64:   $(aarch64-linux-gnu-gcc --version | head -1)"
echo "RISC-V:  $(riscv64-linux-gnu-gcc --version | head -1)"