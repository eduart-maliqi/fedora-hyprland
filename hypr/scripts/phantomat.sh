#!/usr/bin/env bash
# ★ 8155 – Phantomat (Hyprland-Plugin „Phantom“: unendliche Arbeitsfläche, SUPER+P)
#   phantomat.sh build    → Quelltext in ~/.local/opt/phantomat gegen /usr/include/hyprland bauen, installieren
#                           und im laufenden Hyprland austauschen (Fenster bleiben, wo sie sind)
#   phantomat.sh update   → git pull + build
#   phantomat.sh an       → Fläche öffnen (SUPER+P, solange sie zu ist): erst HyprWindowShade entladen, dann öffnen
#   phantomat.sh aus      → Fläche schließen (SUPER+CTRL+P): Fenster zurück auf ihre Workspaces, HyprWindowShade wieder laden
#   phantomat.sh unload   → sicher entladen (Fenster zurück auf ihre Workspaces) – Notbremse
# Nach jedem Hyprland-Update: build. Passt die .so nicht zur Version, verweigert das Plugin selbst den Start
# (Hinweis oben rechts) – Hyprland stürzt nicht ab. Geladen wird es von hyprland.lua (Abschnitt „Phantom“).
#
# Warum an/aus über dieses Skript: HyprWindowShade und Phantomat hängen sich beide in Hyprlands
# CGLElementRenderer::draw – beide gleichzeitig geht nicht (Phantomat meldet dann „failed enabling overview hooks“).
# Phantomat hängt sich erst beim Öffnen der Fläche ein und löst sich beim Schließen wieder → die zwei wechseln sich ab.
set -euo pipefail

src="$HOME/.local/opt/phantomat"
so="$HOME/.local/share/hyprland/plugins/phantomat.so"
shade_so="$HOME/.local/share/hyprland/plugins/HyprWindowShade.so"
# Merker „HyprWindowShade wurde für Phantom entladen“ (nur dann beim Ausschalten wieder laden)
marker="${XDG_RUNTIME_DIR:-/tmp}/phantomat-shade.${HYPRLAND_INSTANCE_SIGNATURE:-x}"

# Hilfsfunktionen des Projekts: safe_unload (entlädt über ein kleines Hilfs-Plugin, das vorher kaputte
# Layout-Zustände repariert) und remember_canvas_layout (Fensterplätze merken)
project_dir="$src"
source "$src/scripts/common.sh"

running_version() { hyprctl version -j | python3 -c 'import json, sys; print(json.load(sys.stdin).get("version", ""))'; }

unload() {
    hyprland_session && spatialoverview_loaded || return 0
    remember_canvas_layout
    safe_unload
}

# Notbremse: entladen und – falls für Phantom entladen – die Fenster-Shader zurückholen
notbremse() {
    unload
    if [[ -f "$marker" ]]; then
        rm -f "$marker"
        "$HOME/.config/hypr/scripts/windowshade.sh" load && hyprctl reload >/dev/null
    fi
}

build() {
    local headers
    headers="$(pkg-config --modversion hyprland 2>/dev/null)" || { echo "Header fehlen: Paket hyprland-devel installieren" >&2; exit 1; }
    if hyprland_session && [[ "$headers" != "$(running_version)" ]]; then
        echo "hyprland-devel ($headers) passt nicht zum laufenden Hyprland ($(running_version))." >&2
        echo "→ hyprland + hyprland-devel auf dieselbe Version bringen und neu anmelden." >&2
        exit 1
    fi
    echo "baue Phantomat für Hyprland $headers …"
    make -C "$src" -j"$(nproc)" all || { echo "Bauen fehlgeschlagen – laufendes Plugin bleibt unverändert." >&2; exit 1; }
    # erst neue Datei, dann umbenennen: eine geladene .so nie direkt überschreiben (Absturz)
    mkdir -p "$(dirname "$so")"
    install -m 0755 "$src/spatialoverview.so" "$so.neu"
    mv -f "$so.neu" "$so"
    echo "fertig: $so"

    hyprland_session || exit 0
    local war_an=0
    if spatialoverview_loaded; then
        canvas_open && war_an=1
        unload
        hyprctl plugin load "$so" >/dev/null
    fi
    hyprctl reload >/dev/null      # lädt es (falls noch nicht) und wendet phantomat.lua an
    sleep 0.5
    spatialoverview_loaded || { echo "Hyprland hat das Plugin nicht geladen – Hinweis oben rechts beachten." >&2; exit 1; }
    # war die Fläche offen → wieder öffnen, Fenster an ihren Plätzen
    ((war_an)) && hyprctl dispatch 'hl.plugin.spatialoverview.overview("on all")' >/dev/null
    echo "Phantomat läuft – SUPER+P"
}

canvas_open() { hyprctl spatialoverview 2>/dev/null | grep -q '"monitor"'; }

an() {
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/phantomat.lock"
    flock -n 9 || exit 0                     # doppelter Tastendruck während des Umschaltens
    spatialoverview_loaded || { notify-send -a Phantom "Phantom" "Plugin nicht geladen – phantomat.sh build ausführen"; exit 1; }
    if hyprctl plugin list | grep -q '^Plugin HyprWindowShade '; then
        hyprctl plugin unload "$shade_so" >/dev/null
        for _ in $(seq 30); do hyprctl plugin list | grep -q '^Plugin HyprWindowShade ' || break; sleep 0.05; done
        touch "$marker"
    fi
    hyprctl dispatch 'hl.plugin.spatialoverview.overview("toggle all")' >/dev/null
}

aus() {
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/phantomat.lock"
    flock 9
    canvas_open && hyprctl dispatch 'hl.plugin.spatialoverview.overview("off all")' >/dev/null
    # warten, bis die Fläche wirklich weg ist (Animation) – erst dann sind ihre Hooks gelöst
    for _ in $(seq 60); do canvas_open || break; sleep 0.05; done
    if [[ -f "$marker" ]] && ! canvas_open; then
        rm -f "$marker"
        "$HOME/.config/hypr/scripts/windowshade.sh" load && hyprctl reload >/dev/null   # reload: Shader-Tags neu lesen
    fi
}

case "${1:-}" in
    build)  build ;;
    update) git -C "$src" pull --ff-only && build ;;
    an)     an ;;
    aus)    aus ;;
    unload) notbremse ;;
    *)      echo "benutzung: $0 build|update|an|aus|unload" >&2; exit 2 ;;
esac
