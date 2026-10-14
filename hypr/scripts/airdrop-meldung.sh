#!/usr/bin/env bash
# Für omdrop (AirDrop): ersetzt Omarchys Befehl `omarchy-notification-send` durch notify-send (mako).
#   [-t MS] TITEL [TEXT] [--image BILD] [--exec BEFEHL …]   Klick auf die Meldung führt BEFEHL aus
# Erreichbar über den Symlink ~/.local/bin/omarchy-notification-send; der Drop-in
# ~/.config/systemd/user/omdrop-watch.service.d/path.conf legt ~/.local/bin in den PATH des Watchers.
t=8000 img= text=() run=()
while (( $# )); do
  case $1 in
    -t) t=$2; shift 2 ;;
    --image) img=$2; shift 2 ;;
    --exec) shift; run=("$@"); break ;;
    *) text+=("$1"); shift ;;
  esac
done
args=(-a airdrop -t "$t" -i "${img:-network-wireless}")
if (( ${#run[@]} )); then
  [[ $(notify-send "${args[@]}" -A default=öffnen "${text[@]}") == default ]] && exec "${run[@]}"
else
  notify-send "${args[@]}" "${text[@]}"
fi
