#!/usr/bin/env bash
# ★ 8155 – Bluetooth-Gerät koppeln, vertrauen und verbinden
#   bt-pair.sh AA:BB:CC:DD:EE:FF
addr="$1"
[[ -z "$addr" ]] && exit 1
notify() { notify-send -a bluetooth "$@"; }

name=$(bluetoothctl info "$addr" 2>/dev/null | sed -n 's/^\s*Name: //p')
name=${name:-$addr}
notify "koppeln …" "$name"

if bluetoothctl --timeout 25 pair "$addr" >/dev/null &&
   bluetoothctl trust "$addr" >/dev/null &&
   bluetoothctl --timeout 15 connect "$addr" >/dev/null; then
    notify "verbunden" "$name"
else
    notify -u critical "koppeln fehlgeschlagen" "$name – ist das Gerät im Kopplungsmodus?"
fi
