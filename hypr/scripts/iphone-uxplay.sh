#!/usr/bin/env bash
# ★ 8155 – UxPlay starten und die PIN als Benachrichtigung zeigen (Aufruf: iphone-uxplay.sh <uxplay-Optionen>)
# stdbuf: ohne Terminal puffert UxPlay seine Ausgabe, die PIN erschiene sonst erst beim Beenden
stdbuf -oL -eL uxplay "$@" 2>&1 | while IFS= read -r line; do
    echo "$line"
    pin=$(grep -oiE 'PIN[^0-9]{0,6}[0-9]{4}' <<<"$line" | grep -oE '[0-9]{4}$')
    [[ -n $pin ]] && notify-send -a iphone -u critical -t 60000 "iphone-pin: $pin" "am iPhone eingeben"
done
