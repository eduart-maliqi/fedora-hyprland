#!/bin/bash
# Bildschirmaufnahme (wf-recorder) per Strg+Druck: Bereich wählen → aufnehmen, erneuter Druck beendet.
ziel=~/videos/bildschirmaufzeichnungen
notify() { notify-send -a aufnahme "$@"; }

if pgrep -x wf-recorder >/dev/null; then
    # SIGINT, damit wf-recorder die Datei sauber abschliesst
    pkill -INT -x wf-recorder
    notify "aufnahme beendet" "gespeichert in $ziel"
    exit 0
fi

bereich=$(slurp) || exit 0   # Esc beim Auswählen = abbrechen
mkdir -p "$ziel"
notify "aufnahme läuft" "Strg+Druck beendet sie"
exec wf-recorder -g "$bereich" -f "$ziel/aufnahme-$(date +%F_%H-%M-%S).mp4"
