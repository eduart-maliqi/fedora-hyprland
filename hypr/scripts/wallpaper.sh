#!/usr/bin/env bash
# ★ 8155 – Wallpaper wechseln
#   wallpaper.sh next        → nächstes Bild aus ~/.config/hypr/wallpapers
#   wallpaper.sh /pfad.jpg   → bestimmtes Bild setzen (so ruft es die Galerie auf, Super+W);
#                              wallpapers/seide/<thema>.jpg = bewegte Seide (Standbild für hyprlock, Desktop zeigt den Shader)
#   wallpaper.sh weg /pfad.jpg → Bild (+ Maske) in den Papierkorb (Strg+Entf in der Galerie); war es aktiv,
#                              kommt vorher das zuletzt davor genutzte
# Jeder Wechsel kommt oben in ~/.local/state/8155/wallpaper-verlauf → Galerie sortiert „zuletzt genutzt“
dir="$HOME/.config/hypr/wallpapers"
current="$(readlink -f "$dir/current" 2>/dev/null)"
verlauf="$HOME/.local/state/8155/wallpaper-verlauf"

if [[ "${1:-}" == "weg" ]]; then
    weg="$(readlink -f "$2")"
    [[ -f "$weg" && "$(dirname "$weg")" == "$dir" ]] || { echo "kein Wallpaper: $2" >&2; exit 1; }
    if [[ "$weg" == "$current" ]]; then
        naechstes="$(grep -vxF "$weg" "$verlauf" 2>/dev/null | while read -r p; do [[ -f "$p" ]] && { echo "$p"; break; }; done)"
        [[ -n "$naechstes" ]] || naechstes="$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) ! -path "$weg" | sort | head -1)"
        [[ -n "$naechstes" ]] || { echo "letztes Bild – wird nicht gelöscht" >&2; exit 1; }
        "$0" "$naechstes"
    fi
    name="$(basename "${weg%.*}")"
    gio trash "$weg"
    for m in "$dir/masken/$name.png" "$dir/masken/$name.json"; do [[ -f "$m" ]] && gio trash "$m"; done
    grep -vxF "$weg" "$verlauf" > "$verlauf.neu" 2>/dev/null; mv "$verlauf.neu" "$verlauf"
    exit 0
fi

if [[ "${1:-next}" == "next" ]]; then
    mapfile -t walls < <(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
    (( ${#walls[@]} == 0 )) && exit 1
    target="${walls[0]}"
    for i in "${!walls[@]}"; do
        if [[ "${walls[$i]}" == "$current" ]]; then
            target="${walls[$(( (i + 1) % ${#walls[@]} ))]}"
            break
        fi
    done
else
    target="$(readlink -f "$1")"
fi

[[ -f "$target" ]] || { echo "nicht gefunden: $target" >&2; exit 1; }
ln -sfn "$target" "$dir/current"          # hyprlock nutzt current
qs ipc call wallpaper set "$target"       # Quickshell blendet über

mkdir -p "${verlauf%/*}"
# Helligkeit hinter der Desktop-Uhr (oben rechts) → ClockWidget.qml dunkelt seine Scheibe danach ab
magick "$target" -gravity northeast -crop 28%x30%+0+0 +repage -colorspace gray -resize 1x1\! -format "%[fx:mean]" info: \
    > "${verlauf%/*}/uhr-hintergrund" 2>/dev/null &
{ echo "$target"; grep -vxF "$target" "$verlauf" 2>/dev/null; } > "$verlauf.neu" && mv "$verlauf.neu" "$verlauf"

# Farbthema = Anfang des Dateinamens (golden-castle.jpg → golden, purpur-wolf.jpg → purpur, seide/glut.jpg → glut); unbekannt → golden
thema="$(basename "$target")"; thema="${thema%%-*}"; thema="${thema%%.*}"
[[ -d "$HOME/.config/hypr/themen/$thema" ]] || thema=golden
[[ "$(readlink "$HOME/.config/hypr/themen/aktiv")" == "$thema" ]] || "$HOME/.config/hypr/scripts/thema.sh" "$thema"
