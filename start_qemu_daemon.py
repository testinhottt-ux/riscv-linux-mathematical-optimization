#!/usr/bin/env python3
import os
import sys
import subprocess
import time

os.environ["DISPLAY"] = ":1"
cmd = [
    "/home/teste/riscv-linux/start-vm-gui.sh"
]

log_file = open("/tmp/qemu_gui_boot.log", "w")

p = subprocess.Popen(
    cmd,
    stdin=subprocess.DEVNULL,
    stdout=log_file,
    stderr=subprocess.STDOUT,
    start_new_session=True,
    cwd="/home/teste/riscv-linux"
)

print(f"QEMU iniciado com PID {p.pid} em nova sessão!")
time.sleep(3)
if p.poll() is None:
    print(f"QEMU está rodando normalmente (PID {p.pid}).")
    sys.exit(0)
else:
    print(f"QEMU encerrou com código {p.returncode}")
    sys.exit(1)
