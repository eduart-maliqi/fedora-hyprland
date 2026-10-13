# Hyprland-Plugins: Wackelfenster, Phantom, HyprWindowShade

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.

Alle drei hängen an der genauen Hyprland-Version → **nach jedem Hyprland-Update neu bauen**:
`~/.config/hypr/plugins/wobbly/build.sh`, `scripts/phantomat.sh build`, `scripts/windowshade.sh build`
(`hyprland-devel` muss dieselbe Version wie `hyprland` haben: `rpm -q hyprland hyprland-devel`).

## Wackelfenster (Super+G) – eigenes Plugin `wobbly`
Fenster verformen sich beim Verschieben wie Wackelpudding und schwingen nach (wie „wobbly windows“ von Compiz).
Ein fertiges Plugin für Hyprland 0.56 gibt es nicht (WiggleWobble ist seit 2025 verwaist) → selbst geschrieben,
Quelltext `~/.config/hypr/plugins/wobbly/main.cpp`.

```
~/.config/hypr/
├── plugins/
│   └── wobbly/            ← eigenes Hyprland-Plugin „Wackelfenster“ (Super+G), siehe „Wackelfenster“:
│       ├── main.cpp       ← Quelltext (C++, Kommentare deutsch)
│       ├── build.sh       ← bauen + im laufenden Hyprland neu laden (`--nur` = nur bauen); nach jedem Hyprland-Update!
│       └── wobbly.so      ← gebautes Plugin, lädt hyprland.lua per hl.plugin.load
```

- **Funktionsweise:** Vor jedem Bild (`Event::bus()` → `render.pre`) wird geprüft, ob sich ein Fenster bewegt hat
  (`positionAnimation()`). Über jedem Fenster liegt ein Gitter 12×12; bei einer Bewegung bleiben die Gitterpunkte zurück –
  je weiter weg vom **Griffpunkt**, desto mehr (Griff = Maus beim Ziehen mit Super+linke Maus, sonst Fenstermitte mit halber
  Stärke, z. B. bei Tiling-Animationen). Jeder Punkt hängt an einer gedämpften Feder (weiter außen weicher → schwingt versetzt nach).
  Solange ein Fenster wackelt, hängt ein `Render::IWindowTransformer` in `CWindow::m_transformers`: Hyprland zeichnet das
  Fenster dann in einen bildschirmgroßen Puffer, `transform()` zeichnet ihn als verformtes Gitter neu (eigener Shader).
  In Ruhe wird der Transformer wieder entfernt → **im Leerlauf kein Mehraufwand**, keine Extra-Bilder.
- Wackelt **nicht**: Vollbild-Fenster, Fenster mit Regel `no_anim` (Clawd-Pet), Sprünge > 600 px pro Bild (z. B. auf
  anderen Bildschirm geschoben), beim Größe-Ändern per Maus. Popups/Menüs bleiben gerade (Transformer gelten nur fürs Hauptfenster),
  ebenso Screenshots/Live-Vorschauen (Aufgabenansicht), weil Hyprland die „standalone“ zeichnet.
- **Einstellungen** (in `hyprland.lua`, gibt es erst nach dem Laden des Plugins):
  `hl.config({ plugin = { wobbly = { enabled = true, stiffness = 180, damping = 7, strength = 1 } } })` –
  `stiffness` höher = schneller zurück, `damping` höher = weniger Nachschwingen, `strength` 0–2 = wie stark es beim Ziehen zurückbleibt.
  Prüfen: `hyprctl getoption plugin:wobbly:enabled`.
- **An/aus:** `golden.toggle_wobbly()` (Super+G) setzt `plugin.wobbly.enabled` und schreibt `wackelfenster.json`;
  beim Laden der Konfiguration wird der gespeicherte Zustand übernommen (Standard: an). `ModeOsd.qml` zeigt „wackelfenster: an/aus“.
- **Laden:** `hl.plugin.load(…/wobbly.so)` in `hyprland.lua` (nur wenn die Datei existiert). Hyprland lädt Plugins erst
  **nach** dem ersten Einlesen und liest die Konfiguration dann nochmal – deshalb setzt `apply_wobbly()` den Wert nur,
  wenn `hl.get_loaded_plugins()` schon `wobbly` enthält (sonst Fehler „unbekannte Option“).
- **Nach jedem Hyprland-Update neu bauen:** `~/.config/hypr/plugins/wobbly/build.sh` (braucht `hyprland-devel` in **derselben**
  Version wie `hyprland`; baut in `wobbly.so.neu` und benennt dann um – eine geladene `.so` nie direkt überschreiben,
  sonst stürzt Hyprland ab). Passt die `.so` nicht zur Version, verweigert das Plugin den Start mit Hinweis.
- **Fallstricke beim Programmieren** (für Änderungen an `main.cpp`):
  `CMonitor::resources()` ist ein WP auf ein **UP** → niemals `.lock()` (Assertion „tried to lock a CWeakPointer over a
  CUniquePointer“ → Absturz), direkt `->` benutzen. `g_pHyprOpenGL` liegt im Namensraum `Render::GL`. GL-Zustand nur über
  Hyprlands Cache ändern (`useShader`, `blend`, `scissor`), sonst stimmt der Cache nicht mehr. Dasselbe Plugin nie unter zwei
  Pfaden gleichzeitig laden: die zweite Kopie bekommt ihre Einstellungen nicht registriert (Namenskollision) und tut nichts.
  Erst im **verschachtelten Test-Hyprland** ausprobieren (siehe `docs/testen.md`) – ein Absturz dort trifft den Desktop nicht.

## Phantom (Super+P) – Plugin Phantomat, unendliche Arbeitsfläche
Fremdes Plugin [Phantomat](https://github.com/kaolti/phantomat) (kaolti, BSD-3, gebaut auf Hyprland 0.56 + Lua-Konfig, Fork von
hyprland-scroll-overview). Statt Workspaces liegen alle Fenster schwebend auf **einer** endlosen Fläche; die Bildschirme zeigen
nebeneinanderliegende Teile davon (wie auf dem Tisch angeordnet) und wandern zusammen. Rausgezoomt: gewölbte Linse, Punkteraster,
Minikarte unten rechts, Suchfeld (Anzeige englisch, Großbuchstaben, Akzent Amber).
- **Bedienung:** Super+P (erstes Mal: Fläche anlegen + rauszoomen, danach rauszoomen ↔ 100 %), Super+Strg+P = ganz aus.
  Rausgezoomt: tippen = Fenster suchen (Kamera fliegt mit), Enter = hin (100 %), Shift+Enter = Fenster herholen, Esc = zurück,
  Pfeile = Fenster in der Richtung, Strg+0 = alle zeigen, Strg+A = nach App aufräumen, Strg+Z = rückgängig, **Strg+, = Aussehen
  live einstellen** (speichert in `phantomat-tuning.lua`), F1 = alle Tasten. Maus: Mittelklick ziehen = Fläche schieben,
  Strg + Mausrad = zoomen, Klick = hin, Ziehen = Fenster verschieben. Vollbild (Super+F/F11) nimmt nur den eigenen Bildschirm.
- **Dateien:** Quelltext `~/.local/opt/phantomat` (Commit `d62ba67`, 2026-10-01), installiert `~/.local/share/hyprland/plugins/phantomat.so`,
  Einstellungen `hypr/phantomat.lua` (ersetzt die Omarchy-Beispielkonfig des Projekts – die würde Alt+Tab, Super+O/G/L/T, die
  Pfeil- und Workspace-Tasten überschreiben), Skript `scripts/phantomat.sh`. **Nicht** benutzt: `scripts/install.sh` des Projekts
  (hängt Zeilen an hyprland.lua an und legt `spatialoverview.lua` an).
- **Intern heisst es noch „spatialoverview“:** Einstellungen `plugin.spatialoverview.*`, Lua `hl.plugin.spatialoverview.*`,
  Zustand `hyprctl spatialoverview` (JSON; `"screens": []` = Fläche zu), Plugin-Name in `hyprctl plugin list`.
- **Laden:** `hl.plugin.load(PHANTOM_SO)` in hyprland.lua (nur wenn die Datei existiert), danach `pcall(dofile, phantomat.lua)` –
  Fehler darin → Hyprland-Meldung, der Rest der Konfiguration läuft weiter. phantomat.lua kehrt sofort zurück, solange das Plugin
  noch nicht geladen ist (erster Durchgang). Beim Laden hängt es sich nur in `CXWM::handleClientMessage` – alle anderen Hooks erst
  beim Öffnen der Fläche, beim Schließen werden sie wieder gelöst → **zu = kein Mehraufwand**.
- **Konflikt mit HyprWindowShade:** beide hängen sich in `CGLElementRenderer::draw(CTexPassElement)`. Ist HyprWindowShade geladen,
  scheitert das Öffnen mit „failed enabling overview hooks (is other overview plugin enabled?)“. Darum laufen Super+P/Super+Strg+P
  über `phantomat.sh an|aus`: `an` entlädt HyprWindowShade (Merker `$XDG_RUNTIME_DIR/phantomat-shade.<instanz>`) und öffnet dann;
  `aus` schließt, wartet bis `"screens": []` (Hooks gelöst), lädt HyprWindowShade per `windowshade.sh load` + `hyprctl reload`
  (Shader-Tags neu lesen). **Auf der Fläche also kein Goldstaub, kein Abdunkeln, kein Fokus-Glanz.** Lock-Datei
  `$XDG_RUNTIME_DIR/phantomat.lock` gegen Doppeldrücken. Wackelfenster laufen auf der Fläche mit (getestet).
- **Tasten auf der Fläche** (`phantom_or(aktion, normal)` gleich nach `local mod` in hyprland.lua): Workspace-Tasten
  (Super+1…0, Super+Shift+1…0, Super+Shift+Tab, Super+Mausrad), Super+V, Super+J, Super+Shift+P und Super+O tun dort **nichts** –
  ein Workspace-Wechsel zeigt sonst einen leeren Bildschirm (Fenster bleiben auf dem alten Workspace), „geordnet“ würde Fenster
  der Fläche einreihen. Super+Pfeile → `navigate`, Super+Shift+Pfeile → `nudge`. Alt+Tab/Super+Tab/Taskleiste funktionieren
  unverändert (`golden.focus_window` → Kamera fährt zum Fenster). 3-Finger-Wischen (Workspace) ist **nicht** abgefangen.
- **Lua-Fallstrick:** `hl.plugin.spatialoverview.canvas(…)`/`overview(…)` laufen nur **innerhalb eines Tastenkürzels** sofort
  (und werfen dann bei Misserfolg einen Fehler); sonst (z. B. `hyprctl eval`) geben sie nur einen Dispatcher zurück. Darum benutzt
  hyprland.lua `hl.plugin.spatialoverview._dispatch(name, arg)` – läuft immer sofort. „Ist die Fläche offen?“ =
  `pcall(_dispatch, "canvas", "noop")` (gelingt nur bei offener Fläche). `navigate` meldet auch ohne Fläche Erfolg → vorher prüfen.
- **Beim Ausschalten** stellt das Plugin den alten Zustand jedes Fensters her (Workspace, schwebend/gekachelt, Vollbild); die
  **Reihenfolge der Kacheln** kann sich dabei ändern (dwindle reiht neu ein).
- **Bauen** nach jedem Hyprland-Update: `scripts/phantomat.sh build` (prüft hyprland-devel = laufende Version, baut mit `make`
  ~30 s, installiert über `.neu` + `mv`, tauscht ein geladenes Plugin über das Hilfs-Plugin `safe-unload` des Projekts aus).
  Neue Version holen: `phantomat.sh update`. Falsche Version → das Plugin verweigert selbst den Start (rote Meldung), kein Absturz.
  Notbremse bei Problemen: `phantomat.sh unload` (entlädt, Fenster zurück, Fenster-Shader wieder an). Ganz entfernen: Abschnitt
  „Phantom“ + `phantom_*`-Helfer in hyprland.lua raus, `.so` löschen.
- **Getestet** (2026-10-08, verschachteltes Hyprland mit der echten hyprland.lua ohne Autostart, zwei Bildschirme, auch
  Skalierung 1,667, zusammen mit Wackelfenster + HyprWindowShade): an/aus 3× hintereinander, Suche/HUD, Zoom, Super+3 auf der
  Fläche ohne Wirkung, Nudge, Fensterwechsel, Wackeln auf der Fläche. Auf dem echten Desktop bisher nur geladen (Fläche noch nie
  geöffnet) – das erste echte Super+P macht der Benutzer.

## HyprWindowShade – Fenster-Shader (Hyprland-Plugin)

Fragment-Shader pro Fenster/Ebene/Klasse, auch Öffnen-/Schließen-Animationen ([GitHub](https://github.com/ManofJELLO/HyprWindowShade)).
- **Ohne hyprpm** gebaut: Quelltext (git) in `~/.local/opt/HyprWindowShade`, gebaut gegen das Paket **`hyprland-devel`** (gleiche COPR-Version wie `hyprland`, Header-Commit = laufender Commit), installiert nach `~/.local/share/hyprland/plugins/HyprWindowShade.so` + `….so.stamp` („<Hyprland-Commit> <md5>“). Geladen im Autostart per `scripts/windowshade.sh load` – lädt **nur**, wenn der Stamp-Commit zum laufenden Hyprland passt und die Prüfsumme stimmt, sonst Benachrichtigung (ein Plugin mit falscher ABI würde Hyprland abstürzen lassen).
- **Nach jedem Hyprland-Update:** `windowshade.sh build` (neue Quelltext-Version: `windowshade.sh update`); `hyprland-devel` muss dieselbe Version wie `hyprland` haben (`rpm -q hyprland hyprland-devel`).
- **Eingerichtet** (seit 2026-10-07, Regeln `shader-*` in `hyprland.lua`, Dateien in `hypr/shaders/`): Goldstaub beim Öffnen (Schliessen bewusst ohne Shader), inaktive Fenster warm abgedunkelt (`+shader_inactive`, kostet beim aktiven Fenster nichts), Glanz beim Fokus (`+shader_focus` – kommt auch bei jedem Workspace-Wechsel und im geordneten Modus beim Drüberfahren mit der Maus), Puls bei urgent.
- Stärke/Dauer: Konstanten oben in der jeweiligen `.glsl` (`// @duration` = Länge); Speichern lädt den Shader sofort neu, Fehler kommen als rote Hyprland-Meldung. Ein Close-Shader **muss** bei `progress = 1` ganz durchsichtig sein; er gibt auch die Dauer fürs Nachrutschen der Nachbarfenster vor. Vollbild-Fenster bekommen keine Shader. `v_texcoord`: y = 0 oben; beim Schliessen ist die Textur bildschirmgroß → Lage über `window_rect` rechnen.
- **Fallstrick:** Regel entfernen nimmt den Tag offenen Fenstern **nicht** weg (auch nicht beim Neuladen) → von Hand: `hyprctl dispatch 'hl.dsp.window.tag({ tag = "-<tag>*", window = "address:0x…" })'` (mit `*` am Ende = von einer Regel gesetzter Tag), danach `hyprctl reload`, damit das Plugin die Tags neu liest.
- **Allgemein:** Fensterregel mit Tag `+shader:/pfad.glsl` (auch `shader_active`, `shader_inactive`, `shader_open`, `shader_close`, `shader_floating`, `shader_fullscreen` …) oder Lua `hl.plugin.HyprWindowShade.classshader(klasse, pfad|"clear")`, `…togglewindowshader(pfad)`, `…layershader(namespace, pfad)`, `…reloadshaders()` – Aufrufe nur in `hyprland.start`-Callbacks/Binds (beim Parsen ist das Plugin noch nicht geladen).
- Shader: GLSL ES 3.20 (`#version 320 es`, `in vec2 v_texcoord`, `out vec4 fragColor`, `uniform sampler2D tex`), vormultipliziertes Alpha. Hängt sich in `CHyprOpenGLImpl::draw/useShader` und die Fade-out-Funktionen ein; fremde Shader (z. B. vom Wackelfenster-Plugin) laufen unverändert durch. Prüfen: `hyprctl plugin list`.
- **Verträgt sich nicht mit Phantomat** (gleiche Zeichenfunktion) → wird entladen, solange die Phantom-Fläche offen ist (siehe „Phantom“ oben).

Shader-Dateien:
```
~/.config/hypr/
└── shaders/              ← Fenster-Shader fürs Plugin HyprWindowShade (GLSL ES 3.20, Kommentare deutsch), Regeln in hyprland.lua:
    ├── goldstaub-oeffnen.glsl    ← Öffnen: Fenster setzt sich aus Körnern zusammen (unten → oben), Körner glühen amber, 0,55 s
    ├── goldstaub-schliessen.glsl ← Schliessen: verglüht in Körner (unten → oben), 0,6 s – **nicht aktiv** (Wunsch), liegt bereit
    ├── dim-inaktiv.glsl          ← inaktive Fenster Richtung Tintenblau abdunkeln (`STAERKE` 0.6) + leicht entsättigen
    ├── fokus-glanz.glsl          ← beim Fokus: warmer Lichtstreifen schräg über das Fenster, 0,45 s
    └── alarm-puls.glsl           ← „Aufmerksamkeit“ (urgent): 2× amber Schein vom Rand, 1,2 s
```
