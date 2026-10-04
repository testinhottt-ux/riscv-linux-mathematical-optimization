#!/bin/sh
export XDG_CURRENT_DESKTOP=MATE
export DESKTOP_SESSION=mate
export XDG_SESSION_TYPE=x11
export XDG_DATA_DIRS=/usr/local/share:/usr/share
export GSETTINGS_BACKEND=dconf

# Desativa economia de energia da tela (evita tela preta durante emulacao)
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Define o cursor padrao de seta (left_ptr)
xsetroot -cursor_name left_ptr 2>/dev/null || true

# Inicia a sessao MATE Desktop completa via D-Bus
exec dbus-launch --exit-with-session mate-session
