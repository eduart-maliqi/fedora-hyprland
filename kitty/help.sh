#!/usr/bin/env bash
cat <<'TXT'
Tabs
  Ctrl+Shift+T          neuer Tab
  Ctrl+Shift+Q          Tab schliessen
  Ctrl+Shift+→ / ←      naechster / vorheriger Tab
  Ctrl+Shift+Alt+T      Tab umbenennen
  Ctrl+Shift+. / ,      Tab nach rechts / links verschieben

Fenster (Splits)
  Ctrl+Shift+Enter      neues Fenster im Tab
  Ctrl+Shift+W          Fenster schliessen
  Ctrl+Shift+] / [      naechstes / vorheriges Fenster
  Ctrl+Shift+L          naechstes Layout
  Ctrl+Shift+N          neues OS-Fenster

Scrollen
  Ctrl+Shift+↑ / ↓      zeilenweise
  Ctrl+Shift+PgUp/PgDn  seitenweise
  Ctrl+Shift+H          Scrollback im Pager
  Ctrl+Shift+G          Ausgabe des letzten Befehls im Pager
  Ctrl+Shift+Z / X      zum vorherigen / naechsten Prompt springen

Kopieren / Hints
  Ctrl+Shift+C / V      kopieren / einfuegen
  Ctrl+Shift+E          URL per Tastatur oeffnen (hints)
  Ctrl+Shift+P, F       Dateipfad per Tastatur waehlen

Schrift / Sonstiges
  Ctrl+Shift++ / -      Schrift groesser / kleiner
  Ctrl+Shift+Backspace  Schrift zuruecksetzen
  Ctrl+Shift+F2         kitty.conf bearbeiten
  Ctrl+Shift+F5         kitty.conf neu laden
  Ctrl+Shift+F6         Debug-Ausgabe der effektiven Config
  Ctrl+Shift+F11        Vollbild

TXT
echo "Eigene Belegungen (kitty.conf)"
grep -E '^\s*map ' ~/.config/kitty/kitty.conf | sed 's/^\s*map /  /'
