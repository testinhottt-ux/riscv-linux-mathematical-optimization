#!/usr/bin/env bash
# ==============================================================================
# Script para Instalar Pacotes no Rootfs Alpine RISC-V a partir do Host
# Uso: ./install_packages.sh <pacote1> <pacote2> ...
# Exemplo: ./install_packages.sh python3-dev libsdl2-dev
# ==============================================================================
set -e

if [ $# -eq 0 ]; then
    echo "Uso: $0 <nome-do-pacote> [outros-pacotes...]"
    echo "Exemplo: $0 nano htop git"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$DIR/rootfs"

echo "============================================================="
echo "   INSTALANDO PACOTES NO SISTEMA RISC-V: $*"
echo "============================================================="

# Executa apk add usando qemu-riscv64 transparente
qemu-riscv64 -L "$ROOTFS" "$ROOTFS/sbin/apk" \
    --root "$ROOTFS" \
    --repositories-file "$ROOTFS/etc/apk/repositories" \
    add --no-scripts --force-overwrite "$@"

echo "Reconstruindo imagem de disco rootfs.ext4..."
"$DIR/os/rebuild_rootfs.sh"

echo "============================================================="
echo "  PACOTES INSTALADOS E DISCO ATUALIZADO COM SUCESSO!"
echo "============================================================="
