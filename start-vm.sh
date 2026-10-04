#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialização da VM Linux RISC-V (64-bit) com 32 Cores no QEMU
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="$DIR/vmlinux"
INITRD="$DIR/initramfs-tiny.cpio.gz"
DISK="$DIR/rootfs.ext4"

if [ ! -f "$KERNEL" ] || [ ! -f "$INITRD" ] || [ ! -f "$DISK" ]; then
    echo "Erro: Arquivos necessários não encontrados em $DIR"
    exit 1
fi

echo "============================================================="
echo "   INICIANDO VM LINUX RISC-V 64-BIT COM 32 CORES NO QEMU"
echo "============================================================="
echo "  Arquitetura : RISC-V (rv64)"
echo "  Cores (SMP) : 32 Cores Harts"
echo "  Memória RAM : 2 GB"
echo "  Disco Ext4  : 2 GB Persistente (/dev/vda)"
echo "  Boot        : Ultra rápido (initramfs 2.1 MB)"
echo "  Kernel      : Linux 6.12 (porta Debian riscv64)"
echo "  SO          : Debian GNU/Linux 13 (Trixie) Desktop MATE (IDE 'micro'/'geany' e 'links'/'dillo')"
echo "  Rede        : VirtIO Net com acesso à Internet"
echo "-------------------------------------------------------------"
echo " Dica para sair da VM: Pressione Ctrl+A e depois X"
echo "============================================================="
echo "Iniciando..."

exec qemu-system-riscv64 \
    -M virt \
    -accel tcg,thread=multi,tb-size=1024 \
    -cpu rv64 \
    -smp 16 \
    -m 4G \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -drive file="$DISK",format=raw,id=hd0,if=none,cache=writeback \
    -device virtio-blk-pci,drive=hd0 \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-tablet-pci \
    -device virtio-keyboard-pci \
    -append "console=tty0 console=ttyS0 earlycon loglevel=4" \
    -nographic
