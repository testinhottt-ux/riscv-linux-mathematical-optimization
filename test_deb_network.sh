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
    -append "console=ttyS0 root=/dev/vda1 rw init=/bin/sh -- -c '
        mount -t proc proc /proc
        mount -t sysfs sys /sys
        ip link set lo up
        IFACE=\$(ip -br link | grep -v lo | awk \"{print \\\$1}\")
        echo \"Interface detectada: \$IFACE\"
        ip link set \$IFACE up
        ip addr add 10.0.2.15/24 dev \$IFACE
        ip route add default via 10.0.2.2 dev \$IFACE
        echo \"nameserver 1.1.1.1\" > /etc/resolv.conf
        echo \"=== OS-RELEASE ===\"
        cat /etc/os-release
        echo \"=== TESTANDO REDE (PING) ===\"
        ping -c 2 1.1.1.1 || true
        echo \"=== FIM DO TESTE ===\"
        poweroff -f
    '" \
    -serial file:/tmp/debian_net_test.log \
    -display none \
    -daemonize
