#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialização da Imagem Oficial Debian 13 (Trixie) Cloud RISC-V 64
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="$DIR/Image"
DISK="$DIR/debian-rootfs/disk.raw"

export DISPLAY="${DISPLAY:-:1}"

echo "============================================================="
echo "   INICIANDO IMAGEM OFICIAL DEBIAN 13 (TRIXIE) RISC-V 64"
echo "============================================================="
echo "  SO          : Debian GNU/Linux 13 (Trixie) Cloud Oficial"
echo "  Kernel      : Linux 6.12 SMP RISC-V"
echo "  Disco       : 3 GB GPT /dev/vda1"
echo "  Aceleracao  : Multi-Thread TCG (1GB Cache) + GPU VirGL 3D"
echo "============================================================="

exec qemu-system-riscv64 \
    -M virt \
    -accel tcg,thread=multi,tb-size=1024 \
    -cpu rv64 \
    -smp 8 \
    -m 4G \
    -kernel "$KERNEL" \
    -drive file="$DISK",format=raw,id=hd0,if=none,cache=writeback \
    -device virtio-blk-pci,drive=hd0 \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-gpu-gl-pci \
    -device virtio-tablet-pci \
    -device virtio-keyboard-pci \
    -audiodev pa,id=snd0 \
    -device intel-hda \
    -device hda-duplex,audiodev=snd0 \
    -append "console=tty0 console=ttyS0 earlycon root=/dev/vda1 rw" \
    -display gtk,gl=on
