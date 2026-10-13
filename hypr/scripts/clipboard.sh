#!/usr/bin/env bash
# ★ 8155 – Zwischenablage-Verlauf (cliphist + rofi): Auswahl kopieren und gleich ins aktive Fenster einfügen
# Esc/leere Auswahl ⇒ abbrechen, sonst würde wl-copy mit leerer Eingabe die Zwischenablage löschen.
sel=$(cliphist list | rofi -dmenu -i -p "󰅍" -display-columns 2 -theme-str 'window { width: 560px; }') || exit 0
[ -n "$sel" ] || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
# Fokus ist erst kurz nach dem Schließen von rofi wieder im vorherigen Fenster
sleep 0.15
hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL", key = "V" })'
