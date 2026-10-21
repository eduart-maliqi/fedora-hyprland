#!/usr/bin/env bash
# ★ 8155 – Farbthema umschalten (golden | mond …; Farben in themen/<name>/farben.json, Dateien erzeugt thema-bauen.py)
#   thema.sh <name>   → Symlink themen/aktiv + Quickshell, Hyprland, mako, kitty umschalten
#                       (rofi und hyprlock lesen themen/aktiv bei jedem Start selbst)
#   thema.sh          → zeigt das aktive Thema
# Normalerweise ruft wallpaper.sh das auf: das Thema steht vorne im Dateinamen (mond-wolken.jpg → mond).
dir="$HOME/.config/hypr/themen"

if [[ -z "${1:-}" ]]; then
    basename "$(readlink "$dir/aktiv")"
    exit 0
fi

name="$1"
[[ "$name" =~ ^[a-z]+$ && -d "$dir/$name" ]] || { echo "unbekanntes Thema: $name (gibt es: $(ls "$dir" | grep -vx aktiv | tr '\n' ' '))" >&2; exit 1; }

ln -sfn "$name" "$dir/aktiv"
qs ipc call theme reload >/dev/null 2>&1   # Farben könnten in der App „Wallpaper“ geändert worden sein
qs ipc call theme set "$name" >/dev/null 2>&1
hyprctl eval "golden.apply_theme('$name')" >/dev/null
makoctl reload 2>/dev/null
pkill -USR1 -x kitty                      # kitty liest seine Konfiguration (und damit die Farben) neu
exit 0
