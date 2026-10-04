#!/bin/bash
qemu-system-riscv64 \
    -M virt \
    -cpu rv64 \
    -smp 8 \
    -m 4G \
    -accel tcg,thread=multi,tb-size=1024 \
    -kernel Image \
    -drive file=/home/teste/riscv-linux/debian-rootfs/disk.raw,format=raw,id=hd0,if=none \
    -device virtio-blk-pci,drive=hd0 \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -append "console=ttyS0 root=/dev/vda1 rw init=/bin/bash" \
    -serial file:/tmp/debian_apt.log \
    -display none \
    -daemonize
