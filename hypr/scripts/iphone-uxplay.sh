#!/usr/bin/env bash
# ★ 8155 – UxPlay mit Passwort starten (Aufruf: iphone-uxplay.sh <uxplay-Optionen>)
# -pin geht mit UxPlay 1.73.7 nicht: es lehnt den 20-Byte-SRP-Beweis des iPhones ab ("client_proof_len 20 invalid").
# -pw nutzt HTTP-Digest und ist davon nicht betroffen. Das Passwort liegt in ~/.local/state/8155 (nicht im Git).
pwfile="$HOME/.local/state/8155/iphone-passwort"
[[ -s $pwfile ]] || { mkdir -p "${pwfile%/*}"; (umask 077; tr -dc 'a-z0-9' </dev/urandom | head -c8 >"$pwfile"); }

# Solange gespiegelt wird, den iPhone-Hotspot dem Gast-WLAN vorziehen: Gast-WLANs isolieren die Geräte, und
# NetworkManager wechselt von sich aus nie zurück, wenn der Hotspot kurz weg war (Kernel: „missed beacons“).
hotspot="iPhone (2)"
(
    ssid=$(nmcli -g 802-11-wireless.ssid connection show "$hotspot" 2>/dev/null) || exit 0
    while sleep 20; do
        nmcli -t -f NAME connection show --active | grep -qxF "$hotspot" && continue
        nmcli -t -f SSID dev wifi list --rescan auto 2>/dev/null | grep -qxF "$ssid" &&
            nmcli connection up "$hotspot" >/dev/null 2>&1 && echo "zurück im Hotspot $hotspot"
    done
) &

# stdbuf: ohne Terminal puffert UxPlay seine Ausgabe, das Journal bekäme sie sonst erst beim Beenden.
# -d 1: nur im Debug-Log meldet UxPlay die Bildgrösse (Start, iPhone gedreht) → Spiegelfenster anpassen.
dir=$(dirname "$(readlink -f "$0")")
size_re='width_source = [0-9.]+ height_source = [0-9.]+ width = ([0-9.]+) height = ([0-9.]+)'
stdbuf -oL -eL uxplay "$@" -d 1 -pw "$(<"$pwfile")" 2>&1 | while IFS= read -r line; do
    [[ $line =~ $size_re ]] && python3 -I "$dir/iphone-fenster.py" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" &
    echo "$line"
done
