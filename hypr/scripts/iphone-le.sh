#!/usr/bin/env bash
# ★ 8155 – (als root über pkexec, von iphone.sh steuern) Bluetooth nur LE, solange Prozess <pid> läuft
#   iOS behandelt den Dual-Mode-Adapter (Classic + LE auf derselben Adresse) als Classic-Gerät und findet bzw.
#   koppelt die LE-Maus/Tastatur dann nicht. Ohne BR/EDR und mit fester statischer Zufallsadresse ist der Laptop
#   fürs iPhone ein reines LE-Gerät ohne Vorgeschichte. Beides geht nur bei ausgeschaltetem Adapter.
#   Danach wieder Classic + LE mit der normalen Adresse (Kopfhörer usw.), auch wenn der Helfer beendet wird.
pid=$1
[[ $pid =~ ^[0-9]+$ ]] || exit 1
static=C0:81:55:6A:00:2B   # oberste zwei Bits gesetzt = statische Zufallsadresse; fest, damit die Kopplung hält
m() { btmgmt --index 0 "$@" >/dev/null; }
restore() { m power off; m static-addr 00:00:00:00:00:00; m bredr on; m power on; exit 0; }
trap restore TERM INT HUP

m power off; m bredr off; m static-addr "$static"; m power on
while kill -0 "$pid" 2>/dev/null; do sleep 1; done
restore
