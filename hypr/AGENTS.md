# ★ 8155 – Hyprland-Desktop

Kern-Doku des Desktop-Setups (Hyprland + Quickshell + Hilfsprogramme). Diese Datei wird **immer** geladen und enthält
nur, was man bei jeder Arbeit am Desktop braucht. Alles Weitere steht in `docs/` und wird **nur bei Bedarf** gelesen.

**Stand:** 2026-10-14

---

## ⚠️ Regeln für KI-Assistenten (bitte zuerst lesen)

1. **Details gezielt nachlesen:** Vor einer Änderung die passende Datei aus „Wo steht was“ lesen – **nur die zum Thema**,
   nie alle auf einmal (spart Kontext/Tokens).
2. **Doku aktuell halten – im selben Arbeitsschritt.** Wenn du etwas am Setup änderst (Datei neu/gelöscht/umbenannt,
   Tastenkürzel, IPC-Befehl, Verhalten, Farbe, Paket, Skript):
   - Details in der passenden `docs/*.md` anpassen (Neues ergänzen, Entferntes löschen, nichts Veraltetes stehen lassen),
   - **diese Datei** nur bei Kern-Infos ändern (Tastenkürzel, Dateistruktur, Überblick, Fallstricke, Stil, neue Doku-Datei),
   - Eintrag oben in `CHANGELOG.md` – **höchstens 3 Zeilen** (Datum – was – warum; keine Testprotokolle, keine Zitate),
   - **Stand**-Datum hier oben anpassen.
3. **Diese Datei klein halten** (Ziel: um 20 KB): Ausführliches gehört nach `docs/`. Doku-Dateien **nie** per `@datei`
   einbinden – sonst werden sie wieder bei jeder Nachricht mitgeladen.
4. **Git:** `~/.config` ist ein Repo (nur `hypr`, `quickshell`, `rofi`, `mako`, `kitty`; ausgenommen laut `.gitignore`:
   `wallpapers/`, `*.so`, `scripts/noa-start.sh`, `grub-ghost/test/` + Bilder, Symlink `themen/aktiv`). Remote ist **öffentlich**
   (GitHub `eduart-maliqi/fedora-hyprland`, Push per SSH-Key); `README.md` + `screenshots/` liegen in `~/.config` (nicht in `hypr/`) → **nie Tokens, Schlüssel, Mailadressen, IDs oder Firmeninternes** in verfolgte Dateien schreiben.
   Nach abgeschlossener Änderung committen: `git -C ~/.config add -A && git -C ~/.config commit -m "…"` (Push nur auf Wunsch).
   **Vor größeren Änderungen** zusätzlich (Wallpapers & Co. sind nicht im Git):
   `tar czf ~/.cache/golden-backups/vor-<thema>-$(date +%Y%m%d-%H%M).tar.gz -C ~/.config quickshell hypr`
5. **Kommentare nur, wenn wirklich nötig und sinnvoll** (das *Warum*, nicht das *Was* – siehe `~/CLAUDE.md`), dann
   auf Deutsch. Texte auf Deutsch, im Stil der vorhandenen Dateien (siehe „Design & Stil“).
6. Der Benutzer schreibt Deutsch (Schweiz, Tastatur `ch`) – antworte auf Deutsch.
7. `sudo` braucht ein Passwort → Root-Befehle aus einer KI-Sitzung mit `pkexec …` (grafischer Passwort-Dialog).

---

## Wo steht was (Pfade relativ zu `~/.config/hypr/`)

| Datei | Lesen, wenn es um … geht |
|---|---|
| `docs/hyprland.md` | `hyprland.lua`: Aufbau, Monitore, Autostart, Maus/Touchpad, Lua-Syntax & `hyprctl`, `golden.*`-Funktionen, Fenstermodus (Super+O), Verstecken, Fenster- & Layer-Regeln, D-Bus-Umgebung |
| `docs/plugins.md` | Wackelfenster (`wobbly`, eigenes C++), Phantom (Phantomat, Super+P), HyprWindowShade + `shaders/`, Neubauen nach Hyprland-Updates |
| `docs/quickshell.md` | QML-Grundlagen & -Fallstricke, Fenster/Ebenen/Namespaces, `Ui.qml`, Leiste, Kontrollzentrum, Aufgabenansicht/Alt+Tab, Super+I-Übersicht, IPC-Befehle |
| `docs/musik.md` | Musik-Panel, Spotify Web API, Songtexte (`lyrics.py`: lrclib/NetEase/KI), yt-dlp |
| `docs/wallpaper.md` | Wallpaper-Bilder, **Galerie (Super+W)**, **Farbthemen** (`thema.sh`, `themen/`), Masken, lebendiges Wallpaper (Shader) |
| `docs/system.md` | hypridle, hyprlock, Anmeldung (GDM-Autoanmeldung + hyprlock beim Start), mako, rofi, Ton/PipeWire, Audiotreiber, Systemuhr/chrony, Dock/DisplayLink, „Bildschirme“ (nwg-displays), Windows-Partition, Explorer-Modus, Outlook, Clawd, Pakete, Kernel-Baustelle, iPhone spiegeln, **AirDrop** (omdrop) |
| `docs/grub.md` | GRUB-Bootmenü „ghost“ (Dualboot) + Plymouth-Ladebildschirm |
| `docs/testen.md` | Shader/QML nur auf der CPU testen, Plugins im verschachtelten Test-Hyprland, Absturzspuren |
| `CHANGELOG.md` | wann/warum etwas geändert wurde – nur bei Bedarf (z. B. Fehlersuche „seit wann ist das so?“) |

---

## Überblick

| | |
|---|---|
| System | Fedora 43, Laptop, Wayland |
| Bildschirm | `eDP-1`, 2880×1800 @120 Hz, Skalierung 1.666667 → logisch **1728×1080** |
| Externe Monitore | über ein **DisplayLink-Dock** („USB 3.0 Dual 4K Dock“, USB `17e9:6000`) → Treiber `displaylink` + Kernelmodul `evdi` (siehe `docs/system.md`). Zwei Samsung 24" 1920×1200 @60, Skalierung 1. Anordnung stellt der Benutzer selbst ein (Stand 2026-10-06 14:28: **S24C450 links**, **Laptop in der Mitte** etwas tiefer, **S24E650 rechts** – genaue Werte in `monitors.lua`). Ausgänge heissen `DVI-I-1`/`DVI-I-2` (Nummern können tauschen) → per `desc:` angesprochen. **Einstellen: App „Bildschirme“ (nwg-displays)** → schreibt `~/.config/hypr/monitors.lua` |
| Compositor | **Hyprland 0.56.2** mit **Lua-Konfiguration** (`hyprland.lua`, *nicht* `hyprland.conf`) |
| Shell / Oberfläche | **Quickshell 0.3.1** (Leiste, Panels, Wallpaper, Uhr, Songtexte, Fensterwechsler) |
| Session | `hyprland.desktop` (ohne uwsm). GNOME 49 ist als zweite Session installiert – einige Werte sind „wie unter GNOME“ gewählt |
| Thema | „8155“: Glas-Flächen mit Blur, Sterne als Leitmotiv. **Farbthemen je nach Wallpaper:** `golden` (Tintenblau + Amber/Gold, helle Bilder), `glut` (Schwarz + Glutrot), `kohle` (Anthrazit + Sonnengelb), `purpur` (Violett + Neonpink), `mond` (Nachtblau + Mondlicht-Blau), `silber` (Schwarz + Silberweiß) → docs/wallpaper.md |
| Tastatur | Schweizerdeutsch (`kb_layout = "ch"`) |
| Pakete | Hyprland-Ökosystem aus COPR `sdegler/hyprland` (auch `hyprland-devel` für Plugins), Quickshell aus COPR `errornointernet/quickshell` |

---

## Dateistruktur

```
~/.config/hypr/
├── AGENTS.md              ← diese Datei (Kern-Doku, wird immer geladen)
├── CLAUDE.md              ← lädt AGENTS.md für Claude Code
├── CHANGELOG.md           ← Änderungsprotokoll (wird nicht automatisch geladen)
├── docs/                  ← Detail-Doku je Thema (siehe „Wo steht was“) – nur bei Bedarf lesen
├── hyprland.lua           ← Hyprland-Hauptkonfiguration (Lua): Monitore, Autostart, Aussehen,
│                            Eingabe, Tastenkürzel, Fensterregeln, Lua-Hilfsfunktionen (golden.*)
├── monitors.lua           ← Monitor-Anordnung/Auflösung/Skalierung (`hl.monitor`), wird von nwg-displays
│                            („Bildschirme“) beim Übernehmen **überschrieben**; in hyprland.lua per require("monitors")
├── monitors.conf, workspaces.conf ← leer bzw. hyprlang-Format, legt nwg-displays an – werden **nicht** benutzt
├── hypridle.conf          ← Leerlauf: abdunkeln → sperren → Bildschirm aus → Bereitschaft
├── hyprlock.conf          ← Sperrbildschirm (Farben per `source` aus themen/aktiv)
├── themen/                ← Farbthemen: golden/, glut/, kohle/, purpur/, mond/, silber/ (je hyprlock.conf, mako, rofi.rasi, kitty.conf), `aktiv` = Symlink
│                            aufs aktive Thema → docs/wallpaper.md
├── phantomat.lua          ← Einstellungen fürs Plugin Phantomat (Super+P); `phantomat-tuning.lua` (entsteht beim
│                            Live-Einstellen mit Strg+, in der Phantom-Ansicht) gewinnt darüber → docs/plugins.md
├── grub-ghost/            ← Bootmenü (GRUB) + Ladebildschirm (Plymouth) im Stil von Ghost of Tsushima:
│                            Bild-/Schrift-Generatoren, Themes, installieren.sh, rueckgaengig.sh, Test-VM → docs/grub.md
├── plugins/wobbly/        ← eigenes Hyprland-Plugin „Wackelfenster“ (Super+G): main.cpp, build.sh, wobbly.so → docs/plugins.md
├── shaders/               ← Fenster-Shader (GLSL) fürs Plugin HyprWindowShade, Regeln in hyprland.lua → docs/plugins.md
├── scripts/
│   ├── airdrop-meldung.sh ← Meldung „Datei per AirDrop empfangen“ für omdrop (Ersatz für omarchy-notification-send) → docs/system.md
│   ├── bt-pair.sh         ← Bluetooth-Gerät koppeln + vertrauen + verbinden (Arg: MAC)
│   ├── clipboard.sh       ← Zwischenablage-Verlauf (cliphist + rofi)
│   ├── explorer-modus.py  ← Nautilus: Lesezeichen Windows/Linux je nach aktivem Tab (Dienst; `status`, `linux`, `windows`)
│   ├── gnome-sperren.sh   ← unter GNOME nach der Autoanmeldung sofort sperren (Autostart `~/.config/autostart/8155-gnome-sperren.desktop`)
│   ├── lyrics.py          ← Songtexte suchen (Cache → lrclib → NetEase → KI per YouTube-Audio + OpenAI Whisper):
│   │                        `find`, `key` (OpenAI-Key speichern), `forget <artist> <titel>`, `info` → docs/musik.md
│   ├── noa-start.sh       ← NOA-Entwicklungsumgebung hochfahren (Super+Shift+D) → docs/system.md
│   ├── iphone.sh          ← iPhone-Spiegelung (UxPlay-Dienst) `an|aus|toggle|status|steuern` → docs/system.md
│   ├── iphone-uxplay.sh   ← startet UxPlay zeilengepuffert mit Passwort `-pw` (ExecStart von uxplay.service)
│   ├── iphone-hid.py      ← Bluetooth-LE-Maus/Tastatur (HID over GATT, BlueZ-D-Bus) fürs iPhone, Dienst `iphone-hid.service`
│   ├── iphone-le.sh       ← (root via pkexec) Bluetooth nur LE + LE-Privacy, solange das Steuerfenster offen ist
│   ├── iphone-steuern.py  ← SDL-Fenster: fängt Maus/Tastatur und schickt sie an iphone-hid.py (Unix-Socket)
│   ├── kalender.py        ← Termine der nächsten 45 Tage als JSON (Evolution-Datenbank, Google-Konto über GNOME-Online-Konten) → docs/quickshell.md
│   ├── nowplaying.sh      ← aktueller Song als Text (für hyprlock)
│   ├── powermenu.sh       ← Power-Menü (rofi): sperren, Bereitschaft, abmelden, Neustart, aus
│   ├── claude-sessions.py ← Claude-Code-Sitzungen: welche sind fertig und ungesehen? (liest ~/.claude/sessions, für die Leiste) → docs/quickshell.md
│   ├── spotify-auth.py    ← Spotify-Anmeldung fürs Musik-Panel (PKCE): `login [client-id]`, `token [--refresh]`, `logout`
│   ├── thema.sh           ← Farbthema umschalten (`<name>`, ohne Argument: aktives zeigen) → Quickshell, Hyprland, mako, kitty
│   ├── wallpaper.sh       ← Wallpaper wechseln (`next` oder Pfad, `weg <pfad>` = in den Papierkorb) → Symlink + Quickshell-IPC + Verlauf + Farbthema aus dem Dateinamen
│   ├── windowshade.sh     ← Plugin HyprWindowShade: `build`, `update`, `load` (Autostart, mit Versions-/Prüfsummen-Check), `unload`
│   ├── phantomat.sh       ← Plugin Phantomat: `build`, `update`, `an`/`aus` (von Super+P / Super+Strg+P, tauscht dabei
│   │                        HyprWindowShade aus), `unload` (Notbremse) → docs/plugins.md
│   └── wifi.sh            ← WLAN-Auswahl per rofi + nmcli (älter; im Kontrollzentrum gibt es jetzt eine eigene Liste)
└── wallpapers/            ← <thema>-<name>.jpg (golden-, glut-, kohle-, mond-, purpur-, silber-; Name vor dem „-“ = Farbthema), `current` = Symlink aufs aktive Bild,
                             masken/ (lebendiges Wallpaper), aussortiert/ → docs/wallpaper.md

~/.config/quickshell/      ← Quickshell-Konfiguration (QML), Einstieg: shell.qml → Details docs/quickshell.md
├── AGENTS.md              ← Symlink auf ~/.config/hypr/AGENTS.md
├── CLAUDE.md              ← lädt AGENTS.md für Claude Code
├── shell.qml              ← Wurzel: erzeugt alle Fenster + IPC-Handler
├── Theme.qml              ← Singleton: Farben (Paletten golden/glut/kohle/purpur/mond/silber, `Theme.name`), Schriften
├── Ui.qml                 ← Singleton: gemeinsamer UI-Zustand (welches Panel offen ist usw.)
├── Media.qml              ← Singleton: aktiver MPRIS-Player
├── LyricsService.qml      ← Singleton: synchronisierte Songtexte (ruft hypr/scripts/lyrics.py auf)
├── Spotify.qml            ← Singleton: Spotify Web API (Bibliothek, Suche, Abspielen, ♥, Wiedergabe-Status)
├── Iphone.qml             ← Singleton: Zustand des UxPlay-Dienstes (fragt `scripts/iphone.sh status`), Kachel im Kontrollzentrum
├── NightLight.qml         ← Singleton: Nachtmodus (hyprsunset), Zustand in ~/.local/state/8155/nachtmodus.json
├── WindowMode.qml         ← Singleton: liest den Fenstermodus (geordnet/frei) aus ~/.local/state/8155/fenstermodus.json
├── Bar.qml                ← obere Leiste (pro Bildschirm); ohne Musik steht links `Theme.title` = „8155“
├── StarLine.qml           ← Mitte der Leiste: Linie in der Akzentfarbe + Taskleiste (offene Apps)
├── Pill.qml               ← Baustein: Glas-Kapsel [Symbol  Text]
├── Star.qml               ← Baustein: fünfzackiger Vektor-Stern
├── ControlCenter.qml      ← aufklappbares Kontrollzentrum oben rechts (mit Kalender)
├── AirdropPanel.qml       ← AirDrop-Fenster (Kapsel 󰀃 in der Leiste): Dateien hineinziehen, an iPhone/Mac senden
├── Airdrop.qml            ← Singleton: AirDrop-Zustand + Befehle (ruft die omdrop-CLI auf) → docs/system.md
├── CalendarView.qml       ← Kalender im Kontrollzentrum: heute + 1 Monat, Termine als Punkte + Liste
├── CalendarService.qml    ← Singleton: Termine (ruft scripts/kalender.py auf)
├── WifiList.qml           ← WLAN-Liste (im Kontrollzentrum)
├── BluetoothList.qml      ← Bluetooth-Geräteliste (im Kontrollzentrum)
├── MusicWindow.qml        ← Fenster fürs Musik-Panel, pro Bildschirm zwei (Desktop-Ebene / über den Fenstern)
├── MusicPanel.qml         ← Musik-Panel oben links (wie ein kleines Spotify: Playlists, Lieder, Suche, Steuerung)
├── ClockWidget.qml        ← große Desktop-Uhr oben rechts (oben „8155“ in der Akzentfarbe, Uhrzeit, Linie, Datum)
├── Lyrics.qml             ← Songtext oben links auf dem Desktop (Instagram-Stil)
├── Wallpaper.qml          ← Hintergrundbild (mit Überblendung) + Klick-Logik + Uhr fürs lebendige Wallpaper
├── WallpaperScene.qml     ← ein Bild + Maske + Shader (lebendiges Wallpaper), zwei Stück in Wallpaper.qml
├── shaders/               ← wallpaper.frag (GLSL) → wallpaper.frag.qsb (DAS lädt Quickshell – nach Änderung mit qsb
│                            neu kompilieren!), rauschen.png → docs/wallpaper.md
├── VolumeOsd.qml          ← Lautstärke-Anzeige unten in der Mitte
├── ModeOsd.qml            ← kurzer Hinweis unten in der Mitte: Fenstermodus gewechselt / Wallpaper lebendig↔still /
│                            Wackelfenster an↔aus (beobachtet dafür selbst wackelfenster.json)
├── TaskView.qml           ← Aufgabenansicht mit Live-Vorschau: Super+Tab (wie Windows) und Alt+Tab-Fensterwechsler
├── ClaudeSessions.qml     ← Singleton: Claude-Code-Sitzungen, die fertig sind und auf dich warten (Kapsel in der Leiste)
├── KeysHelp.qml           ← Super+I: Übersicht aller Tastenkürzel oben rechts (Liste von Hand gepflegt)
└── WallpaperGallery.qml   ← Super+W: Wallpaper-Galerie (Waben, zuletzt genutzt zuerst) → docs/wallpaper.md

Weitere Konfigurationen im selben Stil:
~/.config/rofi/config.rasi   ← App-Starter/Menüs (Symbolthema WhiteSur-dark; Farben @import themen/aktiv/rofi.rasi)
~/.config/mako/config        ← Benachrichtigungen (oben rechts, Overlay-Ebene; Farben include themen/aktiv/mako)
~/.config/kitty/kitty.conf   ← Terminal (Deckkraft 0.74; Grundfarben include themen/aktiv/kitty.conf)
~/.config/kitty/smart_paste.py ← Strg+V: Text → kitty fügt ein; Bild → geht ans Programm (z. B. Claude Code)
~/.cache/golden-backups/     ← Sicherungen (tar.gz) vor größeren Änderungen
~/.local/opt/phantomat/      ← Quelltext Phantomat (git, github.com/kaolti/phantomat), gebaut nach
                               ~/.local/share/hyprland/plugins/phantomat.so (intern heisst das Plugin „spatialoverview“)
~/.local/opt/omdrop-plugin/   ← AirDrop-CLI `omdrop` (git), ~/.local/opt/omdrop-owl/ ← Funk-Teil (git, gebaut als RPM → /usr/lib/omdrop) → docs/system.md
~/.local/state/spatial-overview/canvas-memory.tsv ← Phantom merkt sich Fensterplätze + Kamera (über Neustarts)
~/.local/state/8155/  ← gespeicherter Zustand: nachtmodus.json (an/aus + Wärme), fenstermodus.json ({"free": true|false}),
                               wallpaper.json ({"animated": true|false}, „an“ erst nach 60 s Laufzeit gespeichert),
                               wallpaper-verlauf (Pfade, zuletzt genutztes oben – für die Galerie, schreibt wallpaper.sh),
                               wackelfenster.json ({"enabled": true|false}, schreibt hyprland.lua bei Super+G),
                               spotify.json (Client-ID + Tokens, Rechte 600 – nicht weitergeben),
                               openai.json (OpenAI-API-Key für KI-Songtexte, Rechte 600 – nicht weitergeben),
                               lesezeichen-linux / lesezeichen-windows (Nautilus-Lesezeichen je Modus), explorer-modus (`linux`|`windows`)
~/.cache/8155/lyrics/ ← gefundene Songtexte (eine JSON pro Lied, von lyrics.py) – löschen = alles neu suchen
~/bildschirmfotos/           ← Ziel für Screenshots (hyprshot)
~/airdrop/                   ← per AirDrop empfangene Dateien
```

---

## Tastenkürzel

`SUPER` = Windows-Taste. Definiert in `hyprland.lua`, Abschnitt „TASTENKÜRZEL“.
**Super+I** zeigt alle Kürzel als Spickzettel (`KeysHelp.qml`). Diese Liste ist **von Hand gepflegt** –
wer ein Kürzel neu anlegt, ändert oder entfernt, muss es **auch dort** nachtragen (Eigenschaft `columns`).

**Apps & Menüs**

| Kürzel | Aktion |
|---|---|
| Super+Enter | Terminal (kitty) |
| Super+Shift+Enter | **Dropdown-Terminal**: kitty (Klasse `dropterm`) oben 80 % × 45 %, ein-/ausblenden (Special-Workspace `dropterm`) |
| Super+Shift+D | **NOA hochfahren** (`scripts/noa-start.sh`): Container `noadb`, Backend + Frontend in kitty-Tabs, IntelliJ |
| **Super+Shift+A** | **iPhone spiegeln** an/aus (AirPlay-Empfänger UxPlay als User-Dienst, `scripts/iphone.sh`; auch Kachel im Kontrollzentrum). Am iPhone: Kontrollzentrum → Bildschirmsynchronisierung → „8155-Laptop“, Passwort steht in der Meldung beim Einschalten (`iphone.sh passwort`) → docs/system.md |
| **Super+Alt+A** | **iPhone steuern**: kleines Fenster anklicken → Maus/Tastatur gehören dem iPhone (Bluetooth-LE-HID), **Strg+Alt+G** gibt sie frei. Fragt einmal nach dem Passwort (Bluetooth solange nur LE → Kopfhörer getrennt) |
| Super+Leertaste / Super+D | App-Starter (`rofi -show drun`) |
| Super+E | Dateimanager (nautilus) |
| Super+B | Browser (brave-browser) |
| Super+Shift+V | Zwischenablage-Verlauf (`scripts/clipboard.sh`): Auswahl wird kopiert **und** per Strg+V ins aktive Fenster eingefügt |
| Super+Esc | Power-Menü (`scripts/powermenu.sh`) |
| Super+L | Bildschirm sperren |
| Super+N | alle Benachrichtigungen schließen |
| **Super+I** | **Tastenkürzel-Übersicht** oben rechts an/aus (`KeysHelp.qml`) |
| **Super+W** | **Wallpaper-Galerie** (Waben, zuletzt genutzt zuerst; Pfeile/Maus wählen, Enter/Klick übernehmen, **Strg+Entf löscht** (Papierkorb), Esc zu) – das **Farbthema wechselt mit** |
| **Super+Shift+W** | **lebendiges Wallpaper** an/aus (Wolken ziehen, Gras/Bäume im Wind, Wasser glitzert) |
| **Super+G** | **Wackelfenster** an/aus (Fenster wackeln beim Verschieben wie Wackelpudding, Plugin `wobbly`) |
| **Super+P** | **Phantom** (Plugin Phantomat): erster Druck = alle Fenster auf eine unendliche Fläche + rauszoomen (tippen = Fenster suchen, Enter = hin, Esc = zurück); danach rauszoomen ↔ 100 %. Siehe docs/plugins.md |
| **Super+Strg+P** | **Phantom aus** → Fenster zurück auf ihre Workspaces (gekachelt) |
| Super+M | Musik-Panel auf dem **Bildschirm unter der Maus** über die Fenster holen / zurück auf den Desktop; liegt es auf einem anderen Bildschirm oben → wechselt dorthin; liegt es dort schon frei sichtbar: ausblenden. Bind ist eine Lua-Funktion (`hl.get_monitor_at_cursor()` → `qs ipc call music toggleOn <name>`) |
| Strg+Shift+Leertaste | Musik pausieren / weiter (`playerctl play-pause`, wie die Medientaste; auch bei gesperrtem Bildschirm) |
| Strg+Shift+←/→ | voriges / nächstes Lied (`playerctl previous/next`) – überdeckt kitty-Tabwechsel und Wortauswahl in Textfeldern |
| Super+Alt+←/→ | Musik 5 s zurück / vor (`playerctl position 5-/5+`, ein Druck = 5 s) |
| Super+Shift+L | Songtexte auf dem Desktop an/aus |
| Super+Shift+C | Desktop-Uhr an/aus |
| Druck / Super+Shift+S | Screenshot Bereich → `~/bildschirmfotos` + Zwischenablage |
| Shift+Druck | Screenshot ganzer Bildschirm |
**Fenster**

| Kürzel | Aktion |
|---|---|
| Super+Q | Fenster schließen |
| Super+F | Vollbild **ohne** App-Vollbild: Fenster füllt den Bildschirm, die App erfährt nichts davon (`fullscreen_state` internal 2 / client 0) → Browser behalten Tabs + Adressleiste. Echtes App-Vollbild: F11 in der App |
| Super+Shift+F | maximieren |
| Super+V | schwebend an/aus |
| Super+C | zentrieren |
| Super+Shift+P | pseudo-tiling (bis 2026-10-08 Super+P) |
| Super+J | Teilung umschalten |
| **Super+O** | **Fenstermodus** umschalten: geordnet (Tiling) ↔ frei (alle Fenster schweben, wie bei Windows) |
| Super+Pfeile | Fokus bewegen (auf der Phantom-Fläche: nächstes Fenster in der Richtung, Kamera fährt mit) |
| Super+Shift+Pfeile | Fenster verschieben (auf der Phantom-Fläche: einen Rasterschritt, 80 px) |
| Super+Strg+Pfeile | Größe ändern (wiederholend) |
| Super+linke Maus ziehen | Fenster verschieben |
| Super+rechte Maus ziehen | Größe ändern |
| Super+Strg+Shift+M | Hyprland beenden (abmelden) – mit Strg abgesichert, bis 2026-10-13 Super+Shift+M |

**Workspaces, Wechseln, Verstecken**

| Kürzel | Aktion |
|---|---|
| Super+1…0 | zu Workspace 1–10 (wie alle Workspace-Tasten und Super+V/J/O/Shift+P: auf der Phantom-Fläche **ohne Wirkung**) |
| Super+Shift+1…0 | Fenster auf Workspace 1–10 schieben |
| **Super+Tab** | **Aufgabenansicht** (alle Fenster mit Live-Vorschau, `TaskView.qml`) |
| Super+Shift+Tab | vorheriger belegter Workspace |
| Super+Mausrad | Workspaces durchblättern |
| 3 Finger wischen (horizontal) | Workspace wechseln |
| Alt+Tab / Alt+Shift+Tab | Fensterwechsler vor/zurück (gleiche Ansicht wie Super+Tab, mit Live-Vorschau), Alt loslassen = wechseln, Alt+Esc = abbrechen |
| Super+H / Super+Alt+S | aktives Fenster verstecken („minimieren“) |
| Super+S | versteckte Fenster anzeigen / ausgewähltes zurückholen |
| Klick aufs Wallpaper | offene Panels schließen; sonst aktives Fenster verstecken |

**Laptop-Tasten:** Lauter/Leiser (heben auch „stumm“ auf), Stumm, Mikro-Stumm, Helligkeit ±5 %,
Medien vor/zurück/Play-Pause. Alle funktionieren auch bei gesperrtem Bildschirm.

---

## Wichtigste Fallstricke (Details in `docs/`)

- **Hyprland ist Lua, nicht hyprlang:** `hyprctl dispatch` nimmt einen Lua-Ausdruck – `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`
  (die alte Form `hyprctl dispatch exec qs` geht **nicht**). Beliebiges Lua: `hyprctl eval "<lua>"`. Speichern lädt neu,
  Fehler: `hyprctl configerrors`. API-Referenz: `/usr/share/hypr/stubs/hl.meta.lua`. → docs/hyprland.md
- **Quickshell lädt beim Speichern neu**, kein Linter → `qs log` prüfen. Hängt es („Not ready to accept queries yet“) oder bleibt
  ein Fenster nach Änderung von `margins`/Größe an der alten Stelle: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- **Farben nie fest eintragen** (es gibt mehrere Farbthemen): in QML `Theme.accent`, `Theme.accentA(0.45)`, `Theme.glassA(…)`,
  `Theme.alpha(Theme.green, …)`; in hyprland.lua `palettes` + `golden.apply_theme`; sonst `themen/<name>/…`. → docs/wallpaper.md
- **Neues Tastenkürzel** → auch in `KeysHelp.qml` (Eigenschaft `columns`) eintragen, die Super+I-Liste ist von Hand gepflegt.
- **Neues Quickshell-Panel mit Glas-Look** → Namespace in die Layer-Regel `^golden-(…)$` in `hyprland.lua`, sonst kein Blur.
- **Plugins** (wobbly, Phantomat, HyprWindowShade) nach **jedem Hyprland-Update neu bauen**; eine geladene `.so` nie direkt
  überschreiben (Absturz). HyprWindowShade und Phantomat vertragen sich nicht – `phantomat.sh an|aus` tauscht sie aus.
- **Shader/QML-Effekte nie mit `grabToImage` auf der echten GPU testen** (GPU-Hang am 2026-10-01 → Hyprland weg) – nur mit
  Software-Rendering. Plugins nur im verschachtelten Test-Hyprland ausprobieren. → docs/testen.md
- **Nie `pkill -f "<muster>"`**, wenn das Muster in der eigenen Befehlszeile steht (beendet die eigene Shell).
- **Programme über D-Bus/systemd** (Nautilus, „Öffnen mit …“) bekommen die Umgebung von `systemd --user`, nicht die von
  Hyprland → neue `hl.env`-Variablen, die solche Apps brauchen, in die `dbus-update-activation-environment`-Zeile. → docs/hyprland.md

---

## Design & Stil

**Farben** (`Theme.qml`, Paletten golden/glut/kohle/purpur/mond; in `hyprland.lua` als `palettes`; übrige Programme in
`themen/<name>/`). Hier die Werte von **golden**, alle Themen nebeneinander in `docs/wallpaper.md`:

| Name | golden | Verwendung |
|---|---|---|
| accent | `#e3a142` | Akzent, Symbole, aktive Elemente |
| accentSoft | `#f2c57c` | sekundärer Akzent, Deko-Sterne |
| accentDeep | `#b8792b` | Textauswahl |
| cream | `#ede6d6` | Haupttext |
| muted / faint | `#aab0aa` / `#7d8680` | Nebentext / Hinweise, inaktiv |
| ink | `#12181e` | Hintergrund, Text auf Akzent |
| green | `#8fd18a` (alle Themen) | „verbunden“ |
| red | `#e0714f` (glut/purpur: orange) | Warnung, löschen, Akku niedrig |
| glass / glassLight / glassStrong | Glas-Grundton mit 50 % / 26 % / 68 % | Flächen (Blur kommt von Hyprland) |
| hairline | weiß 8 % | dünne Rahmen/Trennlinien |

**Schriften:** Überschriften `Cormorant Garamond` kursiv (Theme.serif) · Text `JetBrainsMono Nerd Font` (Theme.mono) ·
Symbole `Symbols Nerd Font` (Theme.icons, Nerd-Font-Glyphen wie 󰅖 󰅀 󰂯 󰤨). Songtexte: `SF Pro Display` Bold (direkt in `Lyrics.qml`).
Uhrzeit der Desktop-Uhr: `SF Pro Display` Light 132 px mit `Text.CurveRendering` (direkt in `ClockWidget.qml`; die Zeile „8155“ darüber + Datum bleiben Cormorant).
**Symbole/Cursor:** WhiteSur-dark / WhiteSur-cursors.

**Konventionen:**
- Beschriftungen in der Oberfläche **klein geschrieben und deutsch** („steuerung“, „suchen“, „verbunden“).
- Panels: `Theme.glassStrong`, Radius 12–14, 1-px-`hairline`-Rahmen; bei Hover/aktiv Akzent-Rahmen `Theme.accentA(0.45–0.8)`
  und Akzent-Tönung `Theme.accentA(0.14–0.22)`.
- Animationen kurz und weich: 120–240 ms, `Easing.OutCubic`; Öffnen = Deckkraft 0→1 + Skalierung 0.97→1.
- Sterne (`Star.qml`) als Deko und Trenner.
- Jede QML-Datei beginnt mit einem Kommentar, was sie tut und wie man sie bedient.

---

## Testen & Fehlersuche

```sh
qs log                                    # Quickshell-Fehler
qs ipc show                               # IPC-Ziele (zeigt auch, ob Quickshell bereit ist)
qs ipc call taskview open                 # Panels ohne Tastatur öffnen …
grim -o eDP-1 /pfad/shot.png              # … und per Screenshot prüfen
hyprctl configerrors                      # Hyprland-Konfigfehler
hyprctl clients -j                        # Fenster (Adresse, Klasse, Workspace)
hyprctl layers                            # welche golden-*-Ebenen gerade existieren
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class tvtest --title tvtest -e sleep 120")'   # Testfenster
```
Testfenster und Screenshots danach wieder aufräumen.

Shader/QML-Effekte (nur CPU!) und Plugins (verschachteltes Hyprland): `docs/testen.md`.
