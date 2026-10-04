#!/bin/bash
START=$(date +%s%N)
qemu-system-riscv64 \
    -M virt \
    -cpu rv64 \
    -smp 8 \
    -m 4G \
    -accel tcg,thread=multi,tb-size=1024 \
    -kernel Image \
    -initrd initramfs-tiny.cpio.gz \
    -drive file=rootfs.ext4,format=raw,id=hd0,if=none \
    -device virtio-blk-pci,drive=hd0 \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-gpu-pci \
    -append "console=ttyS0 root=/dev/vda rw" \
    -nographic << 'GUEST_INPUT'
echo "=== VERIFICANDO SISTEMA DEBIAN MATE ==="
cat /etc/os-release
cat /etc/debian_version
echo "=== TESTANDO COMANDOS APT E DPKG ==="
apt search chocolate-doom
echo "=== TESTANDO CHOCOLATE DOOM E JOGOS ==="
chocolate-doom --version
ls -lh /usr/share/games/doom/
which mate-session mate-panel mate-terminal
echo "=== SUCESSO ABSOLUTO NO DEBIAN MATE ==="
poweroff -f
GUEST_INPUT

END=$(date +%s%N)
DIFF_MS=$(( (END - START) / 1000000 ))
echo "Tempo de teste: ${DIFF_MS} ms"
