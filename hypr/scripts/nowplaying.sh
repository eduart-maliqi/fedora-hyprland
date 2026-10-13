#!/usr/bin/env bash
# ★ 8155 – aktueller Song für hyprlock
playerctl metadata --format '♪  {{title}}  ·  {{artist}}' 2>/dev/null
