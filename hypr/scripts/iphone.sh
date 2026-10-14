#!/usr/bin/env bash
# ★ 8155 – iPhone-Spiegelung (AirPlay-Empfänger UxPlay) ein-/ausschalten
#   iphone.sh an|aus|toggle|status   (status: „an“ oder „aus“, für Quickshell)
#   iphone.sh passwort              AirPlay-Passwort anzeigen (Benachrichtigung)
#   iphone.sh steuern               Maus/Tastatur-Fenster (startet bei Bedarf den Bluetooth-HID-Dienst)
unit=uxplay.service
notify() { notify-send -a iphone "$@"; }
pwfile="$HOME/.local/state/8155/iphone-passwort"
active() { systemctl --user is-active --quiet "$unit"; }

case "${1:-toggle}" in
    status) active && echo an || echo aus ;;
    an)     active || { systemctl --user start "$unit" && notify "iphone-spiegelung an" "Bildschirmsynchronisierung → 8155-Laptop · Passwort: $(<"$pwfile")"; } ;;
    aus)    systemctl --user stop iphone-hid.service
            active && systemctl --user stop "$unit" && notify "iphone-spiegelung aus" ;;
    toggle) active && exec "$0" aus || exec "$0" an ;;
    passwort) notify "iphone-passwort" "$(<"$pwfile")" ;;
    steuern)
        systemctl --user start iphone-hid.service
        exec python3 -I "$(dirname "$0")/iphone-steuern.py" ;;
    *)      echo "Aufruf: $0 an|aus|toggle|status|passwort|steuern" >&2; exit 1 ;;
esac
