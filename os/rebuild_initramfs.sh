#!/usr/bin/env bash
# ==============================================================================
# Script de Reconstrucao do Initramfs Ultraleve (initramfs-tiny.cpio.gz)
# Gera uma imagem minima de boot (~2 MB) para montagem instantanea do /dev/vda
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TINY_DIR="$DIR/tiny_initramfs"
INITRD_OUT="$DIR/initramfs-tiny.cpio.gz"

echo "============================================================="
echo "   RECONSTRUINDO INITRAMFS-TINY PARA BOOT ULTRA RAPIDO (<2s)"
echo "============================================================="

if [ ! -d "$TINY_DIR" ]; then
    echo "Erro: Diretorio $TINY_DIR nao encontrado!"
    exit 1
fi

cd "$TINY_DIR"
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$INITRD_OUT"

echo "============================================================="
echo "  INITRAMFS-TINY RECONSTRUIDO COM SUCESSO!"
echo "  Arquivo gerado: $INITRD_OUT ($(du -h "$INITRD_OUT" | cut -f1))"
echo "============================================================="
