#!/usr/bin/env bash
# ★ 8155 – WLAN-Auswahl (rofi + nmcli)
notify() { command -v notify-send >/dev/null && notify-send -a "wlan" "$@"; }

list=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto 2>/dev/null |
    awk -F: '$4 != "" && !seen[$4]++ {
        mark = ($1 == "*") ? "★" : " ";
        lock = ($3 == "" || $3 == "--") ? " " : "󰌾";
        printf "%s %3s%%  %s  %s\n", mark, $2, lock, $4
    }')

choice=$(printf '%s\n%s\n' "󰖩  wlan ein/aus" "$list" | rofi -dmenu -i -p "wlan" -theme-str 'window { width: 420px; }')
[[ -z "$choice" ]] && exit 0

if [[ "$choice" == *"wlan ein/aus"* ]]; then
    [[ "$(nmcli radio wifi)" == "enabled" ]] && nmcli radio wifi off || nmcli radio wifi on
    exit 0
fi

ssid=$(sed -E 's/^.{1} +[0-9]+%  .  //' <<<"$choice")
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
    nmcli connection up id "$ssid" && notify "verbunden" "$ssid"
else
    pass=$(rofi -dmenu -password -p "passwort" -theme-str 'window { width: 420px; } listview { lines: 0; }' </dev/null)
    nmcli device wifi connect "$ssid" ${pass:+password "$pass"} && notify "verbunden" "$ssid" || notify "fehlgeschlagen" "$ssid"
fi
