#!/usr/bin/env bash
# ★ 8155 – HyprWindowShade (Hyprland-Plugin: Shader pro Fenster/Ebene, per Fensterregel-Tag)
#   windowshade.sh build    → Quelltext in ~/.local/opt/HyprWindowShade gegen /usr/include/hyprland bauen,
#                             installieren und (neu) laden
#   windowshade.sh update   → git pull + build
#   windowshade.sh load     → laden (Autostart) – nur wenn das Plugin für genau das laufende Hyprland gebaut
#                             wurde und die Datei unbeschädigt ist; sonst Benachrichtigung statt Absturz
#   windowshade.sh unload   → entladen
src="$HOME/.local/opt/HyprWindowShade"
so="$HOME/.local/share/hyprland/plugins/HyprWindowShade.so"
stamp="$so.stamp"                         # "<hyprland-commit> <md5>" der installierten Datei
headers="/usr/include/hyprland/src/version.h"

running_commit() { hyprctl version -j | grep -oP '(?<="commit": ")[0-9a-f]+'; }
header_commit()  { grep -oP '(?<=GIT_COMMIT_HASH    ")[0-9a-f]+' "$headers" 2>/dev/null; }
is_loaded()      { hyprctl plugin list 2>/dev/null | grep -q HyprWindowShade; }
checksum()       { md5sum < "$so" | cut -d" " -f1; }

unload() {
    is_loaded || return 0
    hyprctl plugin unload "$so" >/dev/null
    sleep 1
}

load() {
    [[ -f "$so" && -f "$stamp" ]] || exit 0               # nicht installiert → nichts tun
    read -r built sum < "$stamp"
    if [[ "$built" != "$(running_commit)" ]]; then
        notify-send -a "HyprWindowShade" "Fenster-Shader nicht geladen" \
            "Hyprland wurde aktualisiert – neu bauen: ~/.config/hypr/scripts/windowshade.sh build"
        exit 1
    fi
    if [[ "$(checksum)" != "$sum" ]]; then
        notify-send -a "HyprWindowShade" "Fenster-Shader nicht geladen" \
            "Plugin-Datei beschädigt – neu bauen: ~/.config/hypr/scripts/windowshade.sh build"
        exit 1
    fi
    is_loaded && exit 0
    hyprctl plugin load "$so"
}

build() {
    hdr="$(header_commit)"; run="$(running_commit)"
    if [[ -z "$hdr" ]]; then
        echo "Header fehlen: Paket hyprland-devel installieren" >&2; exit 1
    fi
    if [[ "$hdr" != "$run" ]]; then
        echo "hyprland-devel ($hdr) passt nicht zum laufenden Hyprland ($run)." >&2
        echo "→ hyprland + hyprland-devel auf dieselbe Version bringen und neu anmelden." >&2
        exit 1
    fi
    make -C "$src" -B all || { echo "Bauen fehlgeschlagen – laufendes Plugin bleibt unverändert." >&2; exit 1; }
    unload
    mkdir -p "$(dirname "$so")"
    cp "$src/HyprWindowShade.so" "$so.new" && sync "$so.new" && mv "$so.new" "$so" && sync "$so"
    printf '%s %s\n' "$run" "$(checksum)" > "$stamp"
    sync "$stamp"
    load
}

case "${1:-}" in
    build)  build ;;
    update) git -C "$src" pull --ff-only && build ;;
    load)   load ;;
    unload) unload ;;
    *)      echo "benutzung: $0 build|update|load|unload" >&2; exit 2 ;;
esac
