#!/usr/bin/env bash
# ★ 8155 · Wackelfenster-Plugin bauen (wobbly.so)
#
# Muss nach jedem Hyprland-Update neu laufen – ein Plugin passt immer nur zu genau der Hyprland-Version,
# mit deren Headern es gebaut wurde (sonst lädt Hyprland es nicht und zeigt einen Hinweis).
# Braucht: gcc-c++, hyprland-devel (gleiche Version wie hyprland), pkg-config.
#
#   ./build.sh          bauen + im laufenden Hyprland neu laden
#   ./build.sh --nur    nur bauen
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SO="$DIR/wobbly.so"

if ! pkg-config --exists hyprland; then
    echo "Fehlt: hyprland-devel  →  pkexec dnf install hyprland-devel" >&2
    exit 1
fi

HEADERS="$(pkg-config --modversion hyprland)"
RUNNING="$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null || echo '?')"
if [[ "$HEADERS" != "$RUNNING" ]]; then
    echo "Header ($HEADERS) passen nicht zu Hyprland ($RUNNING) → pkexec dnf upgrade hyprland hyprland-devel" >&2
    exit 1
fi

echo "baue wobbly für Hyprland $HEADERS …"
# erst in eine neue Datei bauen, dann umbenennen: die geladene .so darf nie überschrieben werden (Absturz)
g++ -shared -fPIC -O2 -std=c++26 --no-gnu-unique "$DIR/main.cpp" -o "$SO.neu" \
    $(pkg-config --cflags pixman-1 libdrm hyprland pangocairo libinput libudev wayland-server xkbcommon)
mv -f "$SO.neu" "$SO"
echo "fertig: $SO"

if [[ "${1:-}" != "--nur" ]] && command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    # entladen + neu laden, damit die neue Datei wirklich benutzt wird
    hyprctl plugin unload "$SO" >/dev/null 2>&1 || true
    hyprctl plugin load "$SO"
    hyprctl reload >/dev/null   # Einstellungen (an/aus) aus hyprland.lua wieder anwenden
fi
