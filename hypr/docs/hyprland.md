# Hyprland (`hyprland.lua`)

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.

## Aufbau der Datei (in dieser Reihenfolge)
1. **Palette** – `palettes.golden` / `.glut` / `.kohle` / `.purpur` / `.mond` (je `accent`, `accent_soft`, `ink`); welche gilt, setzt `golden.apply_theme`
   (Farbthemen siehe `docs/wallpaper.md`)
2. **Monitore** – `package.loaded["monitors"] = nil` + `pcall(require, "monitors")` lädt **`monitors.lua`** (bei jedem Neuladen frisch;
   Fehler darin → Hyprland-Benachrichtigung, Rest der Konfiguration läuft weiter), danach Regel „alles andere `preferred/auto`“.
   `monitors.lua` schreibt die App **„Bildschirme“** (nwg-displays, siehe `docs/system.md`): Monitore mit der Maus ziehen,
   Auflösung/Hz/Skalierung/Drehung wählen, „Apply“ → Datei neu + `hyprctl reload`, danach 10 s Rückfrage (sonst zurück).
   Dock-Monitore per `desc:` (Option „use-desc“ in `~/.config/nwg-displays/config` ist an). **Achtung:** gespeichert werden nur
   die gerade angeschlossenen Monitore – also am Dock einstellen, sonst fehlen die Samsungs danach in der Datei.
   Ohne Dock steht das Laptop allein an seiner Dock-Position (nicht bei 0x0) – das ist egal
3. **Programme** – `terminal`, `fileManager`, `browser`, `menu`, `scripts`
4. **Autostart** (`hl.on("hyprland.start", …)`): zuerst `hyprlock` (GDM meldet automatisch an → Passwort hier, siehe
   `docs/system.md` → Anmeldung), dbus-Umgebung (siehe Fallstrick unten), `hyprpolkitagent`, `qs` (Quickshell),
   `hypridle`, `mako`, `blueman-applet`, `cliphist` (Text + Bilder),
   `scripts/windowshade.sh load` (Plugin HyprWindowShade, siehe `docs/plugins.md`), `scripts/explorer-modus.py` (Explorer-Modus)
5. **Umgebungsvariablen** – Cursor WhiteSur-cursors 24, Qt Wayland + qt6ct, Electron/Firefox auf Wayland, `PATH` mit `~/.local/bin` vorne (GDM gibt es nicht mit)
6. **Look & Feel** – Lücken, 1-px-Rand in der Akzentfarbe (Verlauf), Rundung 12, Schatten, Glühen in der Akzentfarbe, Blur,
   Animationen/Kurven. Die drei Themenfarben (`active_border`, `glow.color`, `misc.background_color`) stehen **nicht** in diesen
   Blöcken, sondern in `golden.apply_theme` – die läuft beim Laden mit dem Thema aus dem Symlink `themen/aktiv` (per `io.popen`)
7. **Misc / Input** – `ch`-Layout, natürliches Scrollen, Tap-to-Click, Swallowing aus (verschluckte das Claude-Terminal).
   Mausempfindlichkeit: `input.sensitivity` (−1.0 … 1.0, 0 = Standard) gilt für Maus **und** Touchpad;
   einzeln pro Gerät mit `hl.device({ name = "logitech-usb-laser-mouse", sensitivity = … })`
   (Gerätenamen: `hyprctl devices`; Touchpad: `gxtp5100:00-27c6:01e0-touchpad`). Ohne Beschleunigung: `accel_profile = "flat"`.
   **Aktuell:** global 0 (Touchpad), per `hl.device`: `logitech-usb-laser-mouse` **−0.3**,
   `logitech-mx-vertical-advanced-ergonomic-mouse` (MX Vertical, Arbeit) **−0.55**. Neue Maus → eigener `hl.device`-Block, sonst gilt 0. Werte pro Gerät lassen sich nicht per
   `hyprctl getoption` abfragen – nur `hyprctl configerrors` prüfen.
8. **Tastenkürzel** + Lua-Hilfsfunktionen (`golden.*`), darin auch das Laden der Plugins Wackelfenster und Phantomat
   (`hl.plugin.load`). Gleich nach `local mod` stehen `phantom_dispatch`/`phantom_open`/`phantom_or` (siehe `docs/plugins.md` → „Phantom“)
9. **Fenster- & Layer-Regeln**

## Lua-Syntax – wichtig, weil anders als die alte `hyprland.conf`
```lua
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:taskviewToggle"))   -- an Quickshell weiterleiten
hl.bind("SUPER + S", golden.toggle_hidden)                            -- eigene Lua-Funktion
hl.dsp.window.move({ window = "address:0x…", workspace = "special:minimized", follow = false })
```
- `hyprctl dispatch` nimmt einen **Lua-Ausdruck**: `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`
  (die alte Form `hyprctl dispatch exec qs` funktioniert **nicht**).
- `hyprctl eval "<lua>"` führt beliebiges Lua aus, z. B. `hyprctl eval "golden.focus_window('0x55e4…')"`.
- Fehler prüfen: `hyprctl configerrors`. Neu laden: passiert beim Speichern automatisch, sonst `hyprctl reload`.
- **API-Referenz:** `/usr/share/hypr/stubs/hl.meta.lua` (alle `hl.*`-Funktionen, Dispatcher, Ereignisse wie `window.open`,
  Felder von `HL.Window`/`HL.Monitor`), Beispielkonfiguration `/usr/share/hypr/hyprland.lua`.
- `hyprctl eval` antwortet nur mit `ok` – Werte aus Lua auslesen, indem man sie per `io.open(...)` in eine Datei schreibt
  (`io` und `os` sind verfügbar). Nützliche Dispatcher: `hl.dsp.window.float({ action = "enable"|"disable"|"toggle", window = sel })`,
  `…resize({ x = B, y = H, window = sel })` und `…move({ x = X, y = Y, window = sel })` (exakt, logische Pixel),
  `…tag({ tag = "+name"|"-name", window = sel })`; Abfrage `hl.get_windows({ tag = "name" })`.

## Fallstrick: Umgebung für Programme, die über D-Bus/systemd starten
Programme wie **Nautilus** (und alles, was man dort mit „Öffnen mit …“ startet) bekommen **nicht** die Umgebung von Hyprland,
sondern die von `systemd --user`. Diese füllt die erste Autostart-Zeile per `dbus-update-activation-environment --systemd …`
mit: `WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE ELECTRON_OZONE_PLATFORM_HINT QT_QPA_PLATFORM`.
Fehlen `ELECTRON_OZONE_PLATFORM_HINT`/`XDG_SESSION_TYPE`, startet VS Code (Flatpak `com.visualstudio.code`) aus Nautilus
**ohne Fenster** und hängt. Neue `hl.env`-Variablen, die solche Apps brauchen, dort mit eintragen. Für die laufende Sitzung
den Befehl einmal von Hand ausführen und `nautilus -q` (Nautilus startet beim nächsten Öffnen mit der neuen Umgebung).
Prüfen: `systemctl --user show-environment`, bzw. `/proc/$(pgrep -x nautilus)/environ`.

## Globale Lua-Funktionen (`golden.*`) – werden von Quickshell per `hyprctl eval` aufgerufen
| Funktion | Zweck |
|---|---|
| `golden.desktop_click()` | Klick aufs Wallpaper: offene Versteckt-Ansicht schließen, sonst aktives Fenster verstecken |
| `golden.toggle_hidden()` | Super+S: Versteckt-Ansicht zeigen, oder ausgewähltes verstecktes Fenster zurückholen |
| `golden.focus_window(addr)` | zu Fenster wechseln (holt versteckte auf den aktuellen Workspace zurück, bringt es nach vorn) |
| `golden.toggle_window_mode()` | Super+O: Fenstermodus geordnet ↔ frei (siehe unten) |
| `golden.toggle_wobbly()` | Super+G: Wackelfenster an/aus (siehe `docs/plugins.md`); Plugin nicht geladen → Hinweis „build.sh ausführen“ |
| `golden.phantom()` | Super+P: Fläche zu → `scripts/phantomat.sh an`; offen → rauszoomen ↔ 100 % (siehe `docs/plugins.md` → „Phantom“) |
| `golden.phantom_off()` | Super+Strg+P: Fläche offen → `scripts/phantomat.sh aus` |
| `golden.dropdown_terminal()` | Super+Shift+Enter: kitty-Klasse `dropterm` auf dem Special-Workspace `dropterm` ein-/ausblenden (gibt es das Fenster noch nicht, startet es); beim Einblenden wird der Fokus ausdrücklich gesetzt – Hyprland tut das nicht von selbst |
| `golden.apply_theme(name)` | Farbthema (golden, glut, kohle, purpur, mond): Fensterrand, Glühen, Hintergrund (ruft `scripts/thema.sh` auf) |

## Fenstermodus (Super+O): „geordnet“ ↔ „frei“
- **geordnet** (Standard): Tiling (dwindle), neue Fenster werden automatisch angeordnet, `input.follow_mouse = 1`.
- **frei**: wie bei Windows – alle Fenster schweben. Verschieben mit Super+linke Maus, Größe am Rand ziehen
  (`resize_on_border`, Greifbereich `extend_border_grab_area = 25` px außerhalb des Rands). Neue Fenster öffnen schwebend, mittig, 60 % × 70 % (`hl.on("window.open", …)`).
  Tastatur-Fokus nur per Klick (`input.follow_mouse = 2`), damit überlappende Fenster beim Drüberfahren nicht den Fokus klauen.
- Umschalten lässt jedes Fenster an Ort und Stelle (Maße werden vorher gemerkt und nach dem Schweben wieder gesetzt).
- Fenster, die der Modus schwebend gemacht hat, bekommen den Hyprland-Tag **`freed`**. Beim Zurückschalten werden nur
  diese wieder eingereiht – von Natur aus schwebende Fenster (Bild-im-Bild, kleine Tools, Dialoge, Clawd) bleiben schwebend.
  Tags überstehen ein Neuladen der Konfiguration.
- Betroffen: normale Workspaces + `special:minimized`, keine Vollbild-Fenster.
- Zustand in `~/.local/state/8155/fenstermodus.json`, wird beim Laden der Konfiguration übernommen (übersteht Neustarts;
  fehlt die Datei, legt Hyprland sie an). Quickshell beobachtet die Datei (`WindowMode.qml`) → Symbol 󰖲 in der Leisten-Kapsel
  und kurzer Hinweis (`ModeOsd.qml`). Von außen umschalten: `hyprctl eval "golden.toggle_window_mode()"`.

## „Verstecken“ = Minimieren
Es gibt kein echtes Minimieren. Versteckte Fenster liegen auf dem Spezial-Workspace **`special:minimized`**.
Taskleiste, Alt+Tab und Super+Tab zeigen sie (blasser) mit an und holen sie beim Auswählen zurück.
Die Versteckt-Ansicht (Super+S) schließt sich, sobald ein anderer Bildschirm den Fokus bekommt (`hl.on("monitor.focused")`) –
sonst bliebe sie dort offen, und jedes neu versteckte Fenster erschiene sichtbar auf jenem Bildschirm. Das Ereignis kommt,
**bevor** der Fokus umgestellt ist (`hl.get_active_monitor()` = noch der alte Bildschirm). Notfalls von Hand schließen:
`hyprctl monitors -j | jq '.[].specialWorkspace'` zeigt, wo sie offen ist → Maus dorthin, Super+S.

## Fensterregeln
- `float-small-tools`: pavucontrol, blueman-manager, nm-connection-editor, qt6ct, nwg-look, Rechner, Klasse `floating-tui` → schwebend, mittig, 50 %×60 %
- `float-nwg-displays`: Klasse `nwg-displays` (App „Bildschirme“) → schwebend, mittig, eigene Größe
- `pip`: Bild-im-Bild schwebend, angeheftet, unten rechts
- `dropdown-terminal`: Klasse `dropterm` → Special-Workspace `dropterm`, schwebend, oben mittig (80 % × 45 % des Monitors unter dem Cursor).
  Teilt sich die Special-Workspace-Animation mit der Versteckt-Ansicht; vom Fenstermodus (Super+O) bleibt es unberührt.
  **Dim/Blur:** Special-Workspaces dimmen (`decoration.dim_special`, Standard 0.2) und verwischen (`blur.special = true`) den Rest
  – das gilt für *alle* gleichzeitig. Darum schaltet `special_look()` beide nur während das Dropdown offen ist ab und beim
  Schliessen / in `golden.toggle_hidden()` wieder an; die Versteckt-Ansicht behält ihren Blur.
- `clawd-on-desk-pet`: schwebende Fenster der Klasse `clawd-on-desk` (Pet, Blasen, HUD) → angeheftet (alle Workspaces),
  ohne Rand/Schatten/Glow/Blur/Rundung/Animation. Gekachelte Clawd-Fenster (Einstellungen, Dashboard) bleiben normal.
- `suppress-maximize-events`, `fix-xwayland-drags`, `move-hyprland-run`
- `shader-open|inactive|focus|urgent` (Schleife am Ende der Regeln; **kein** `close` – Schliessen ohne Shader, nur Hyprlands Ausblenden): Tags `+shader_<art>:<pfad>` fürs Plugin
  HyprWindowShade auf **allen** Fenstern außer Klasse `clawd-on-desk` und Bild-im-Bild (`negative:`-Regex im `match`,
  beide Felder müssen passen). Shader siehe `shaders/` und `docs/plugins.md` → HyprWindowShade.

## Layer-Regeln (Blur hinter Quickshell)
```lua
hl.layer_rule({ match = { namespace = "^golden-(bar|music|taskview|control|osd|keys|gallery)$" }, blur = true, ignore_alpha = 0.05 })
```
**Neues Quickshell-Panel mit Glas-Look? → Namespace hier in die Liste eintragen**, sonst kein Blur.
`golden-clock` steht **bewusst nicht** drin: die Desktop-Uhr soll eine klare Glasscheibe sein (Blur dunkelt mit
`brightness 0.82` ab und verwischt das Wallpaper – dann wirkt die Karte trotz wenig Tönung undurchsichtig).
Außerdem Blur für `rofi` und `notifications` (mako).
`golden-taskview` hat zusätzlich `no_anim = true`: Alt+Tab soll sofort da sein – kein Einblenden (`fadeLayersIn`, 200 ms)
und kein animiertes Großziehen der dauerhaft bereitliegenden 1×1-Fenster (siehe `docs/quickshell.md` → Aufgabenansicht).
`golden-gallery` (Super+W) ebenfalls `no_anim` – die Galerie blendet in QML selbst ein.
