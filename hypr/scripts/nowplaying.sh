#!/usr/bin/env bash
# ★ 8155 – aktueller Song + aktuelle Songtext-Zeile für hyprlock
playerctl metadata --format '♪  {{title}}  ·  {{artist}}' 2>/dev/null || exit 0
~/.config/hypr/scripts/lyrics.py line 2>/dev/null
