#!/usr/bin/env bash
# ★ 8155 – iPhone-Spiegelung (AirPlay-Empfänger UxPlay) ein-/ausschalten
#   iphone.sh an|aus|toggle|status   (status: „an“ oder „aus“, für Quickshell)
#   iphone.sh steuern               Maus/Tastatur-Fenster (startet bei Bedarf den Bluetooth-HID-Dienst)
unit=uxplay.service
notify() { notify-send -a iphone "$@"; }
active() { systemctl --user is-active --quiet "$unit"; }

case "${1:-toggle}" in
    status) active && echo an || echo aus ;;
    an)     active || { systemctl --user start "$unit" && notify "iphone-spiegelung an" "Kontrollzentrum am iPhone → Bildschirmsynchronisierung → 8155-Laptop"; } ;;
    aus)    systemctl --user stop iphone-hid.service
            active && systemctl --user stop "$unit" && notify "iphone-spiegelung aus" ;;
    toggle) active && exec "$0" aus || exec "$0" an ;;
    steuern)
        systemctl --user start iphone-hid.service
        exec python3 -I "$(dirname "$0")/iphone-steuern.py" ;;
    *)      echo "Aufruf: $0 an|aus|toggle|status|steuern" >&2; exit 1 ;;
esac
