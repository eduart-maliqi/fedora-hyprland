#!/usr/bin/env bash
# ★ 8155 – iPhone-Spiegelung (AirPlay-Empfänger UxPlay) ein-/ausschalten
#   iphone.sh an|aus|toggle|status   (status: „an“ oder „aus“, für Quickshell)
#   iphone.sh passwort              AirPlay-Passwort anzeigen (Benachrichtigung)
#   iphone.sh steuern               Maus/Tastatur-Fenster (startet bei Bedarf den Bluetooth-HID-Dienst)
#                                   IPHONE_BTMON=<datei> schneidet die Sitzung mit btmon mit
unit=uxplay.service
notify() { notify-send -a iphone "$@"; }
pwfile="$HOME/.local/state/8155/iphone-passwort"
active() { systemctl --user is-active --quiet "$unit"; }

case "${1:-toggle}" in
    status) active && echo an || echo aus ;;
    an)     active || { systemctl --user start "$unit" && notify -t 60000 "iphone-spiegelung an" "Bildschirmsynchronisierung → 8155-Laptop · Passwort: $(<"$pwfile")"; } ;;
    aus)    systemctl --user stop iphone-hid.service
            active && systemctl --user stop "$unit" && notify "iphone-spiegelung aus" ;;
    toggle) active && exec "$0" aus || exec "$0" an ;;
    passwort) notify -t 60000 "iphone-passwort" "$(<"$pwfile")" ;;
    steuern)
        dir=$(dirname "$(readlink -f "$0")")
        le_only() { local s; s=$(btmgmt --index 0 info 2>/dev/null | grep "current settings:"); [[ $s == *powered* && $s != *br/edr* ]]; }
        python3 -I "$dir/iphone-steuern.py" & win=$!
        # Root-Helfer (ein Passwort-Dialog): Bluetooth nur LE, solange das Fenster offen ist – danach wieder Classic + LE
        irkfile="$HOME/.local/state/8155/iphone-irk"   # fester IRK, damit das iPhone die Kopplung wiedererkennt
        [[ -s $irkfile ]] || (umask 077; od -An -tx1 -N16 /dev/urandom | tr -d ' \n' >"$irkfile")
        pkexec "$dir/iphone-le.sh" "$win" "$(<"$irkfile")" ${IPHONE_BTMON:+"$IPHONE_BTMON"} &
        # HID-Dienst erst danach starten, sonst wirbt er wieder als Dual-Mode-Gerät
        for _ in $(seq 60); do le_only && break; sleep 1; done
        le_only || notify -u critical "iphone steuern" "Bluetooth ist nicht im LE-Modus – Passwort-Dialog abgebrochen?"
        systemctl --user restart iphone-hid.service && le_only &&
            notify -t 20000 "iphone steuern bereit" "am iPhone unter Bluetooth „8155-Laptop-HID“ koppeln, dann ins Fenster klicken"
        wait "$win"
        systemctl --user stop iphone-hid.service ;;
    *)      echo "Aufruf: $0 an|aus|toggle|status|passwort|steuern" >&2; exit 1 ;;
esac
