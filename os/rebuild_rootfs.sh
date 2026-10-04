#!/usr/bin/env bash
# ==============================================================================
# Script de Reconstrucao do Disco Virtual Ext4 (rootfs.ext4)
# Empacota todo o diretorio rootfs/ em um disco ext4 persistente em ~3 segundos
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS_DIR="$DIR/rootfs"
DISK_IMG="$DIR/rootfs.ext4"
DISK_SIZE="3G"

echo "============================================================="
echo "   RECONSTRUINDO DISCO EXT4 DO SISTEMA OPERACIONAL RISC-V"
echo "============================================================="
echo "  Origem  : $ROOTFS_DIR"
echo "  Destino : $DISK_IMG"
echo "  Tamanho : $DISK_SIZE"
echo "============================================================="

# Assegura permissoes de leitura
if [ -n "$ROOT_PASSWORD" ]; then
    echo "$ROOT_PASSWORD" | sudo -S chmod -R a+rX "$ROOTFS_DIR"
else
    sudo chmod -R a+rX "$ROOTFS_DIR" 2>/dev/null || true
fi

# Cria e popula o sistema de arquivos ext4
/sbin/mkfs.ext4 -F -L "RISCV_ROOT" -d "$ROOTFS_DIR" "$DISK_IMG" "$DISK_SIZE"

echo "============================================================="
echo "  DISCO EXT4 RECONSTRUIDO COM SUCESSO!"
echo "  Arquivo gerado: $DISK_IMG ($(du -h "$DISK_IMG" | cut -f1))"
echo "============================================================="
