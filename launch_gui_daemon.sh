#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Iniciando QEMU MATE Desktop em background no display :1..."
DISPLAY=:1 nohup "$DIR/start-vm-gui.sh" </dev/null >/tmp/qemu_gui_boot.log 2>&1 &
PID=$!
echo "Processo QEMU lançado com PID: $PID"
sleep 4
if ps -p $PID > /dev/null; then
    echo "QEMU está rodando com sucesso (PID $PID)!"
else
    echo "Aviso: QEMU encerrou logo após o início. Verifique o log:"
    cat /tmp/qemu_gui_boot.log
    exit 1
fi
