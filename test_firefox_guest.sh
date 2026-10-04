#!/usr/bin/env bash
# ==============================================================================
# Teste Automatizado do Firefox ESR no Guest Linux RISC-V 64 via QEMU
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="$DIR/vmlinux"
INITRD="$DIR/initramfs-tiny.cpio.gz"
DISK="$DIR/rootfs.ext4"

echo "=== INICIANDO TESTE DO FIREFOX ESR NO GUEST RISC-V ==="

qemu-system-riscv64 \
    -M virt \
    -accel tcg,thread=multi,tb-size=1024 \
    -cpu rv64,zba=true,zbb=true,zbs=true \
    -smp 8 \
    -m 4G \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -drive file="$DISK",format=raw,id=hd0,if=none \
    -device virtio-blk-pci,drive=hd0 \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -append "console=ttyS0 earlycon test_firefox" \
    -nographic

echo "=== TESTE FINALIZADO ==="
