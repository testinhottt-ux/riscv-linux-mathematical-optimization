#!/bin/bash
START_TIME=$(date +%s%N)
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
    -append "console=ttyS0 root=/dev/vda rw init=/bin/sh -- -c '
        echo \"=== VERIFICANDO AMBIENTE DE JOGOS E MULTIMIDIA RISC-V ===\"
        echo \"[1] Chocolate DOOM binary:\"
        /usr/bin/chocolate-doom --version || true
        echo \"[2] Freedoom WADs:\"
        ls -lh /usr/share/games/doom/ || true
        echo \"[3] Teste rapido headless chocolate-doom:\"
        /usr/bin/chocolate-doom -iwad /usr/share/games/doom/freedoom1.wad -nodraw -nosound || true
        echo \"[4] Verificacao de bibliotecas graficas e jogos:\"
        ldd /usr/bin/chocolate-doom | head -n 10
        which dillo links tetris snake worm
        echo \"=== FIM DOS TESTES DE JOGOS ===\"
        poweroff -f
    '" \
    -nographic

END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
echo "Tempo total de execucao: ${ELAPSED_MS} ms"
