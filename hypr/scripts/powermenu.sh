#!/usr/bin/env bash
# ★ 8155 – Power-Menü (rofi)
choice=$(printf '%s\n' \
    "󰌾  sperren" \
    "󰤄  bereitschaft" \
    "󰍃  abmelden" \
    "󰜉  neustart" \
    "󰐥  herunterfahren" |
    rofi -dmenu -i -p "★" -theme-str 'window { width: 280px; } listview { lines: 5; }')

case "$choice" in
    *sperren)         loginctl lock-session ;;
    *bereitschaft)    systemctl suspend ;;
    *abmelden)        command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
    *neustart)        systemctl reboot ;;
    *herunterfahren)  systemctl poweroff ;;
esac
