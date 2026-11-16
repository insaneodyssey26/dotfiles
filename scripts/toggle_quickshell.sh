#!/usr/bin/env bash
if pgrep -x "quickshell" >/dev/null 2>&1; then
    pkill -9 -x "quickshell" 2>/dev/null
    notify-send "Quickshell" "Killed quickshell process" -u low -t 2000 2>/dev/null || true
else
    quickshell -p /home/masum/dotfiles/quickshell/shell.qml >/dev/null 2>&1 &
    disown
    notify-send "Quickshell" "Started quickshell" -u low -t 2000 2>/dev/null || true
fi
