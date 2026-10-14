#!/usr/bin/env bash
# ★ 8155 – (als root über pkexec, von iphone.sh steuern) Bluetooth nur LE, solange Prozess <pid> läuft
#   iphone-le.sh <pid> <irk> [btmon-datei]
#   iOS behandelt den Dual-Mode-Adapter (Classic + LE auf derselben Adresse) als Classic-Gerät und findet bzw.
#   koppelt die LE-Maus/Tastatur dann nicht → BR/EDR aus. LE-Privacy (wechselnde Zufallsadressen, fester IRK) lässt
#   das iPhone den Laptop als neues Gerät sehen. Keine statische Adresse: dann wäre sie die Identität der Verbindung,
#   bluetoothd lauscht aber auf der öffentlichen – das iPhone bekam keine GATT-Antwort, Trennung nach 4 s.
#   Alles nur bei ausgeschaltetem Adapter. Danach wieder normal (Kopfhörer usw.), auch wenn der Helfer beendet wird.
pid=$1 irk=$2 log=$3
[[ $pid =~ ^[0-9]+$ && $irk =~ ^[0-9a-fA-F]{32}$ ]] || exit 1
m() { btmgmt --index 0 "$@" >/dev/null; }
# ssp on: das Abschalten von BR/EDR löscht auch SSP, bredr on bringt es nicht zurück
restore() { [[ -n $bt ]] && kill "$bt"; m power off; m privacy off; m static-addr 00:00:00:00:00:00; m bredr on; m ssp on; m power on; exit 0; }
trap restore TERM INT HUP

[[ -n $log ]] && { btmon -T >"$log" 2>&1 & bt=$!; }
m power off; m static-addr 00:00:00:00:00:00; m bredr off; m privacy on "$irk"; m power on
while kill -0 "$pid" 2>/dev/null; do sleep 1; done
restore
