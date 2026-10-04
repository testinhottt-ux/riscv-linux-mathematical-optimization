#!/usr/bin/env bash
# ==============================================================================
# Script de Compilacao do Kernel Linux 6.12 para RISC-V 64-bit (128 Cores SMP)
# Utiliza os 32 threads do processador Intel Xeon E5-2698 v3 para compilar a toda velocidade
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VER="6.12.16"
KERNEL_DIR="$DIR/linux-$KERNEL_VER"
KERNEL_TAR="linux-$KERNEL_VER.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/$KERNEL_TAR"

echo "============================================================="
echo "   COMPILADOR AUTOMATIZADO DO KERNEL LINUX PARA RISC-V 64"
echo "============================================================="
echo "  Diretorio do Kernel : $DIR"
echo "  Versao Alvo         : Linux $KERNEL_VER (LTS)"
echo "  Configuracao Base   : $DIR/config-6.12-riscv64"
echo "  Threads de Build    : $(nproc) Threads Paralelos"
echo "============================================================="

# 1. Instala toolchain de cross-compilacao se necessario
if ! command -v riscv64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "Instalando cross-compilador gcc-riscv64-linux-gnu..."
    if [ -n "$ROOT_PASSWORD" ]; then
        echo "$ROOT_PASSWORD" | sudo -S apt-get update -qq
        echo "$ROOT_PASSWORD" | sudo -S apt-get install -y -qq gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu bc flex bison libssl-dev libelf-dev
    else
        sudo apt-get update -qq && sudo apt-get install -y -qq gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu bc flex bison libssl-dev libelf-dev
    fi
fi

# 2. Download do codigo-fonte do Linux Kernel se nao existir
if [ ! -d "$KERNEL_DIR" ]; then
    if [ ! -f "$DIR/$KERNEL_TAR" ]; then
        echo "Baixando codigo-fonte oficial do Linux $KERNEL_VER..."
        wget -c "$KERNEL_URL" -O "$DIR/$KERNEL_TAR"
    fi
    echo "Extraindo codigo-fonte do Kernel..."
    tar -xf "$DIR/$KERNEL_TAR" -C "$DIR"
fi

# 3. Aplicar Configuracao do Kernel
echo "Copiando configuracao otimizada para o kernel..."
cp "$DIR/config-6.12-riscv64" "$KERNEL_DIR/.config"

cd "$KERNEL_DIR"

# 4. Compilacao Paralela com os 32 threads do Xeon
echo "Compilando imagem de boot do Kernel (Image e vmlinux)..."
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc) Image vmlinux modules

# 5. Copiar artefatos finais para o diretorio principal
echo "Instalando artefatos compilados em $DIR/../..."
cp arch/riscv/boot/Image "$DIR/../Image"
cp vmlinux "$DIR/../vmlinux"

echo "============================================================="
echo "  COMPILACAO CONCLUIDA COM SUCESSO!"
echo "  Artefatos gerados: $DIR/../Image e $DIR/../vmlinux"
echo "============================================================="
