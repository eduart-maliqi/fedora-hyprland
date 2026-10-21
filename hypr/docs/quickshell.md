# Quickshell (`~/.config/quickshell/`)

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.
Musik-Panel/Songtexte: `docs/musik.md` · lebendiges Wallpaper: `docs/wallpaper.md`.

## Grundlagen
- Start: per Autostart `qs`. Beim **Speichern einer Datei lädt Quickshell automatisch neu.**
- Logs: `qs log` · Instanzen: `qs list` · IPC-Ziele: `qs ipc show`
- **Bekannter Fallstrick:** Viele Speichervorgänge kurz hintereinander können Quickshell in einem halben
  Neulade-Zustand hängen lassen (`qs ipc …` meldet dann „Not ready to accept queries yet“). Lösung:
  ```sh
  pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'
  ```
  Bei größeren Umbauten: Dateien woanders vorbereiten, dann `qs` beenden, alles auf einmal kopieren, `qs` starten.
- **Ebene eines Fensters** (`WlrLayershell.layer`) wird nur beim Erzeugen gelesen – eine Bindung, die sich später ändert,
  wirkt nicht. Für „mal Desktop, mal über den Fenstern“ zwei Fenster nehmen (siehe `MusicWindow.qml`).
- **Position/Größe von Fenstern:** Ändert man `margins`/`implicitWidth`/`implicitHeight` eines `PanelWindow`, übernimmt
  das automatische Neuladen das manchmal **nicht** – das alte Fenster bleibt an der alten Stelle. Prüfen mit
  `hyprctl layers` (xywh pro Namespace); dann Quickshell wie oben neu starten.
- **Shader (`.qsb`) geändert → Quickshell neu starten:** das automatische Neuladen nimmt die alte `.qsb` aus dem Zwischenspeicher.
- Kein QML-Linter installiert → nach Änderungen `qs log` auf Fehler prüfen und per Screenshot kontrollieren.
- **Große Schrift (≥ ~80 px) mit feinen Haarlinien** (z. B. Cormorant Garamond Light) bekommt mit der Standard-Darstellung
  (Distance Field) ausgefranste Kanten. Abhilfe: `renderType: Text.CurveRendering` (Qt ≥ 6.7, hier 6.10).
- **Gelöschte Objekte in Listen:** Verschwindet ein Eintrag (WLAN-Netz, Fenster, Gerät), wird das QObject gelöscht und
  `modelData`/`var`-Eigenschaften werden still zu `null` – ohne dass Bindings neu rechnen. In Delegates daher mit `?.`
  lesen (`row.net?.name ?? ""`), ein Platzhalter per `modelData ?? {…}` reicht **nicht**.
- Singletons (`pragma Singleton`) werden ohne `qmldir` automatisch erkannt (Theme, Ui, Media, LyricsService, Spotify, NightLight, WindowMode, CalendarService).
- **Farben nur aus `Theme.qml`, nie fest eintragen** – es gibt mehrere Farbthemen (golden/glut/kohle/purpur/mond, siehe `docs/wallpaper.md`).
  `Theme.palettes` hält alle Paletten (auch `red` hängt vom Thema ab), `Theme.name` wählt (beim Start aus dem Symlink `~/.config/hypr/themen/aktiv`, danach per
  IPC `theme set`); die Farb-Eigenschaften blenden mit `Behavior` 1,1 s über. Mit Deckkraft: `Theme.accentA(0.45)`,
  `Theme.glassA(0.36)`, allgemein `Theme.alpha(Theme.green, 0.08)`. Bindings über diese Funktionen aktualisieren sich mit
  (QML verfolgt auch Eigenschaften, die in aufgerufenen Funktionen gelesen werden). Weitere: `glassHover`, `dim`,
  `onAccentMuted` (Nebentext auf Akzent-Fläche).
  Sie entstehen erst, wenn sie irgendwo benutzt werden – ein `IpcHandler` darin gibt es also nur, solange ein Fenster sie verwendet.
- **QML-`Timer` sind keine Stoppuhr:** sie laufen auf Qts Animationsuhr, und die zählt Zeit, in der Quickshell blockiert
  (z. B. ~80 ms beim Anlegen eines Fensters mit Vorschauen), **nicht** mit. Muss etwas nach echter Zeit passieren, kurz
  wiederholenden Timer nehmen und `Date.now()` vergleichen (Beispiel: `showTimer` in `TaskView.qml`).
- **Fenster anlegen ist teuer:** `visible: false → true` erzeugt die Wayland-Ebene neu und blockiert Quickshell ~80–100 ms.
  Muss ein Panel sofort da sein, das Fenster dauerhaft als 1×1 px (klick-durchlässig) vorhalten und nur per `anchors`
  groß ziehen (~15–40 ms) – so macht es `TaskView.qml`. Ebenso `ScreencopyView` erst starten, wenn schon etwas zu sehen ist.
- **IPC-Funktionen nicht `show` nennen:** `qs ipc call ziel show …` wird als Befehl `qs ipc show` verstanden
  („argument was not expected“). Stattdessen z. B. `open`.
- Tastenkürzel von Hyprland → Quickshell: `hl.dsp.global("quickshell:<name>")` in hyprland.lua ↔
  `GlobalShortcut { name: "<name>" }` in QML.
- Symbolthema per `//@ pragma IconTheme WhiteSur-dark` in shell.qml. App-Symbole über
  `DesktopEntries.heuristicLookup(klasse)` + `Quickshell.iconPath(…)`.
- Verfügbare Module u. a.: Hyprland, Wayland (inkl. ScreencopyView, ToplevelManagement), Widgets,
  Io (Process, StdioCollector, IpcHandler), Networking, Bluetooth, Services.Pipewire/UPower/Mpris.

## Fenster & Ebenen

| Datei | Namespace | Ebene | Wo / wie geöffnet |
|---|---|---|---|
| Wallpaper.qml | golden-wallpaper | Background | pro Bildschirm, immer |
| ClockWidget.qml | golden-clock | Bottom | pro Bildschirm, oben rechts; klick-durchlässig; `Ui.clockEnabled`. Datumszeile auf hellen Bildern dunkel + fett: `wallpaper.sh` misst die Helligkeit oben rechts → `~/.local/state/8155/uhr-hintergrund` (0–1, > 0.6 = hell). Hat die Palette `clockDate` (zurzeit nur purpur: `#d6286e`), gilt diese Farbe (fett) |
| Lyrics.qml | golden-lyrics | Bottom | pro Bildschirm, oben links (unter der Leiste); klick-durchlässig; nur wenn Songtext gefunden |
| LyricsScreen.qml | golden-lyricsscreen | Overlay | pro Bildschirm, Vollbild; nur auf `Ui.lyricsScreen` (Super+Shift+M); Tastatur `OnDemand` (Esc schließt nach Klick hinein; `Exclusive` sperrte die Tastatur für alle anderen Fenster) |
| Bar.qml | golden-bar | Top | pro Bildschirm, 45 px hoch, oben |
| MusicWindow.qml (2× pro Bildschirm) | golden-music | Bottom + Top | oben links (48/64, 800×470); Bottom-Fenster bei `Ui.musicDesktopOn(screen)` (Musik läuft + Bildschirm leer), Top-Fenster bei `Ui.musicTopOn(screen)`; Inhalt per `Loader` nur, solange sichtbar |
| ControlCenter.qml | golden-control | Top | oben rechts; `Ui.controlOpen` |
| AirdropPanel.qml | golden-airdrop | Top | oben rechts (gleiche Stelle wie das Kontrollzentrum); `Ui.airdropOpen` |
| VolumeOsd.qml | golden-osd | Overlay | unten Mitte, erscheint kurz bei Lautstärke-Änderung |
| ModeOsd.qml | golden-osd | Overlay | unten Mitte, erscheint kurz beim Wechsel des Fenstermodus, des lebendigen Wallpapers oder der Wackelfenster |
| BatteryWarning.qml | golden-osd | Overlay | Akku-Warnungen beim Entladen: 20 % und 10 % kleine Kapsel unten Mitte, 5/4/3/2/1 % jedes Mal grosse Karte in der Bildschirmmitte (je Stufe einmal pro Abstieg, nicht beim Laden/Start) |
| TaskView.qml | golden-taskview | Overlay | pro Bildschirm, **immer da** als 1×1 px (klick-durchlässig); Super+Tab / Alt+Tab → auf dem Bildschirm mit Fokus ganzer Bildschirm |
| KeysHelp.qml | golden-keys | Overlay | Super+I, oben rechts (auch über Vollbild); `Ui.keysOpen` |
| WallpaperGallery.qml | golden-gallery | Overlay | Super+W (`quickshell:galleryToggle`), ganzer Bildschirm mit Fokus, Tastatur `Exclusive` – siehe `docs/wallpaper.md` |
| WallpaperStudio.qml | – (`FloatingWindow`, normales App-Fenster, Klasse `org.quickshell`, Titel `wallpaper · 8155`) | – | App „Wallpaper“ (rofi / `qs ipc call studio open`); Fensterregel `float-wallpaper-studio` in `hyprland.lua` – siehe `docs/wallpaper.md` |

## Gemeinsamer Zustand (`Ui.qml`)
`wallpaper` (Bild-URL), Musik-Panel (`musicOpen`, `musicScreen`, `musicAuto`, `musicDismissed`, `musicShown`, `toggleMusic(name)`, `openMusic(name)`,
`closeMusic()`, `musicTopOn(screen)`, `musicDesktopOn(screen)`, `musicOn(screen)`, `screenEmpty(screen)` – siehe `docs/musik.md`), `controlOpen`, `controlSection` (`""` | `"wifi"` | `"bluetooth"` | `"power"` | `"night"` = aufgeklappter Bereich),
`controlScreen` (Bildschirm, auf dem das Kontrollzentrum aufgeht), `keysOpen` (Tastenkürzel-Übersicht), `airdropOpen` (AirDrop-Fenster), `lyricsEnabled`, `clockEnabled`,
`wallpaperAnimated` (lebendiges Wallpaper, gespeichert in `wallpaper.json` – siehe `docs/wallpaper.md`).
Kontrollzentrum, Tastenkürzel-Übersicht und AirDrop liegen alle oben rechts → `Ui.qml` sorgt dafür, dass immer nur eins offen ist
(`onControlOpenChanged` / `onKeysOpenChanged` / `onAirdropOpenChanged`).
Dazu die Funktion `Ui.skipWindow(t)`: `true` für Fenster, die Taskleiste, Alt+Tab und Aufgabenansicht **nicht** zeigen
(zurzeit: schwebende `clawd-on-desk`-Fenster). Weitere auszublendende Apps dort eintragen – Taskleiste (`StarLine.qml`) und Aufgabenansicht/Alt+Tab (`TaskView.qml`) benutzen sie.

## Die obere Leiste (`Bar.qml`)
```
[★ Titel · Interpret] ──✦── [Brave] [kitty] ✦ [App] ──✦── [wlan bt ton 󰅀] [akku 73%] [uhr 23:31 Mi]
     Now Playing              Taskleiste (StarLine)          Kontrollzentrum   immer sichtbar
```
- **Links, Now Playing:** Klick → Musik-Panel auf dem Bildschirm dieser Leiste holen/zurücklegen (`Ui.toggleMusic(bar.screen.name)`;
  Kapsel hell, solange es dort oben liegt), Mittelklick → Play/Pause, Rechtsklick → nächster Titel.
- **Mitte, Taskleiste (`StarLine.qml`):** ein Symbol pro offenem Fenster, sortiert nach Workspace, darin nach Öffnungsreihenfolge.
  - Klick → zum Fenster wechseln; Klick auf das **aktive** Fenster → verstecken (wie bei Windows)
  - Mittelklick → Fenster schließen; Titel beim Drüberfahren (PopupWindow)
  - aktives Fenster: goldener Rahmen + breiter Strich; aktueller Workspace: kleiner Punkt; andere Workspaces blasser;
    versteckte ganz rechts und noch blasser; zwischen Workspaces ein kleiner Stern
  - keine Fenster offen → ein leuchtender Stern in der Mitte
  - Mausrad über der Leiste → Workspaces wechseln
- **Rechts:** Kapsel mit WLAN-/Bluetooth-/Lautstärke-Symbol + 󰅀 → öffnet das Kontrollzentrum. Zusätzlich grünes Blatt,
  solange Stromsparen an ist, Fenster-Symbol 󰖲 im freien Fenstermodus und Mond, solange der Nachtmodus an ist.
  **AirDrop-Kapsel 󰀃** (zwischen Kontrollzentrum und Akku): Klick → AirDrop-Fenster; eine Datei darüberziehen öffnet es auch.
  Symbol in Akzentfarbe + Restminuten („9′“), solange AirDrop an ist. Akku-Kapsel (Klick → Kontrollzentrum). Uhr-Kapsel (Klick → Desktop-Uhr an/aus).
  Bluetooth-Symbol grün = Gerät verbunden.
- **Claude-Kapsel 󰚩** (links vom Akku, nur sichtbar, wenn eine Claude-Code-Sitzung fertig und noch nicht angesehen ist):
  zeigt den Ordnernamen der Sitzung, bei mehreren „N fertig“. Klick → zum ältesten wartenden Fenster springen
  (`golden.focus_window`), Rechtsklick → alle als gesehen markieren. Daten: `ClaudeSessions.qml` fragt alle 2 s
  `scripts/claude-sessions.py` ab, das `~/.claude/sessions/<pid>.json` (`status` busy/idle) auswertet – **keine Hooks nötig**.
  „Gesehen“ = das Fenster der Sitzung war zu einem Abfragezeitpunkt aktiv (Zuordnung Sitzung → kitty-Fenster über die
  Elternprozesse); Zustand in `~/.local/state/8155/claude-gesehen.json`. Sitzungen ohne kitty-Fenster (IntelliJ-Terminal)
  werden ignoriert. **Neue Singleton-Datei ⇒ Quickshell einmal neu starten** (Neuladen beim Speichern reicht nicht).
- **Größen:** rechte Kapseln (Kontrollzentrum-Kapsel + `Pill.qml`) 30 px hoch, Symbole/Text 16 px; Now-Playing-Kapsel links
  und Taskleiste noch in der alten, kleineren Größe (20 px hoch, 11–13 px).

## Kontrollzentrum (`ControlCenter.qml` + `WifiList.qml` + `BluetoothList.qml`)
- Kopf „steuerung“ mit ✕
- **Kacheln WLAN / Bluetooth:** linker Teil = an/aus, 󰅀 rechts = Liste auf-/zuklappen (`Ui.controlSection`)
  - WLAN-Liste: sucht nur, solange sie offen ist (`scannerEnabled`); verbunden → Klick trennt; gespeichert/offen → verbinden;
    neues gesichertes Netz → Passwortfeld direkt in der Zeile (`connectWithPsk`); 󰆴 = Netz vergessen; Link zu `nm-connection-editor`
  - Bluetooth-Liste: gekoppelte Geräte (Klick verbindet/trennt), „suchen“ zeigt neue Geräte (Klick koppelt via `bt-pair.sh`), 󰆴 = vergessen
- **Kacheln Stromsparen / Nachtmodus** (zweite Reihe, gleiches Prinzip):
  - Stromsparen: Energieprofil über `PowerProfiles` (Quickshell.Services.UPower → tuned-ppd). Kachel = Stromsparen ↔ ausgewogen;
    aufgeklappt drei Knöpfe stromsparen / ausgewogen / leistung. Umschalten braucht kein Passwort. tuned merkt sich das Profil selbst.
  - Nachtmodus: `NightLight.qml` schaltet **hyprsunset** per `hyprctl hyprsunset temperature <K>` / `identity`.
    Aufgeklappt: Regler für die Wärme (5500 K links … 2500 K rechts, Standard 4000 K); Ziehen schaltet ihn ein, Mond-Symbol = an/aus.
    hyprsunset wird bei Bedarf von NightLight gestartet (`hyprsunset --identity`), steht also **nicht** im Autostart.
    Da hyprsunset nicht melden kann, ob der Filter an ist, wird der Zustand in `~/.local/state/8155/nachtmodus.json`
    gespeichert und beim Start von Quickshell wieder angewendet.
- **Regler:** Lautstärke (Pipewire; Symbol-Klick = stumm) und Helligkeit (`brightnessctl`, wird jede Sekunde nachgelesen, solange offen); Mausrad ±5 %
- **Kalender** (`CalendarView.qml`, Daten von `CalendarService.qml` ← `scripts/kalender.py`), unter den Reglern:
  - **rollend**: ab Montag dieser Woche bis heute + 1 Monat (5–6 Zeilen), keine feste Monatsseite; heute = gefüllter Kreis,
    Punkte = Termine (bis 3), am 1. des Monats steht der Monatsname. Tag anklicken → seine Termine, nochmal → „nächste termine“ (6 Stück)
  - **Quelle:** Evolution-Datenbank (EDS, `gi.repository.ECal`) – das Google-Konto steckt dort über die GNOME-Online-Konten
    (`~/.config/goa-1.0`), es braucht **kein eigenes Passwort/Token**. Alle aktiven Kalender (Google, Feiertage Schweiz, Geburtstage, lokal),
    Wiederholungen werden ausgeklappt. Neuer Google-Kalender in GNOME/Evolution anhaken → erscheint von selbst.
  - **Abruf:** beim Start, beim Öffnen (frühestens alle 60 s), solange offen alle 10 min; ~1 s. Test: `python3 scripts/kalender.py 45`
  - **Fallstrick:** `ECal.Client.connect_sync(…, 0, …)` wartet **ewig**; das Skript nimmt 1 s (Daten kommen dann aus dem Zwischenspeicher).
    Schlägt alles fehl → „kalender nicht erreichbar“. **Nur lesen** – Termine anlegen/ändern geht hier nicht (dafür Google Kalender/Evolution).
- **Fuß:** Akku-Details (lädt / voll in … / noch …), Knöpfe Sperren und Power-Menü
- Schließen: ✕, Esc (nach Klick hinein, Tastatur ist `OnDemand`), nochmal auf die Kapsel, Klick aufs Wallpaper

## AirDrop (`AirdropPanel.qml` + Singleton `Airdrop.qml`)
Technik/Installation (omdrop, omdrop-owl, WLAN-Trennung): `docs/system.md`, Abschnitt „AirDrop“.
- Kachel oben: an/aus (`omdrop on 10m` / `off`), zeigt Name „8155-Laptop“ und Restzeit. Fehlt der Funk-Teil → rote Zeile „funk-treiber fehlt“.
- Ablagefläche: Dateien/Bilder hineinziehen (auch Links aus dem Browser) oder klicken → `zenity`-Dateiauswahl → liegen bereit (✕ verwirft).
  DropAreas nehmen immer als **Kopie** an (bei „verschieben“ würde Nautilus die Quelle löschen).
- „geräte in der nähe“ (nur solange Fenster offen + AirDrop an): `omdrop peers --json` alle 2 s, Namen über
  `peers --json -n --stream` (kündigt dabei per Bluetooth an, läuft deshalb nur bei offenem Fenster). Gerät anklicken = bereitliegende
  Dateien senden, Dateien direkt aufs Gerät ziehen = sofort senden, während des Sendens 󰅖 = abbrechen. Status (omdrops Sätze, übersetzt) in der Zeile.
- Unten: Kurzanleitung beide Richtungen + „empfangen · ~/airdrop“ (öffnet den Ordner). Empfangene Dateien melden sich über mako.
- Status-Abfrage `omdrop status --json` alle 2 s (Fenster offen oder AirDrop an), sonst alle 10 s.

## Aufgabenansicht (`TaskView.qml`, Super+Tab **und** Alt+Tab)
Vollbild-Overlay mit abgedunkeltem, geblurrtem Hintergrund. Alle Fenster (auch versteckte) als Karten mit
**Live-Vorschau** (`ScreencopyView`), Symbol, Titel und Workspace, in „zuletzt benutzt“-Reihenfolge. Anordnung wie
Windows 11: gleiche Höhe, Breite nach Fensterform, zeilenweise zentriert, Größe passt sich der Anzahl an.
- **Super+Tab** (`quickshell:taskviewToggle`): bleibt offen, holt sich die Tastatur (`Exclusive`).
  Klick/Enter = wechseln · ✕/Mittelklick/Entf = schließen · Pfeile/Tab = auswählen · Esc/Super+Tab/Klick daneben = zu.
- **Alt+Tab** = Fensterwechsler in derselben Ansicht (`altTab = true`). Hyprland meldet Next/Prev/Commit/Cancel als
  globale Kürzel (`quickshell:switcher…`); Commit kommt beim Loslassen von Alt (Release-Bind mit `transparent = true`).
  Erstes Alt+Tab markiert das zuletzt benutzte andere Fenster. Keine Tastatur (`None`) – das Fenster darunter behält
  den Fokus. Hover wählt hier **nicht** aus (sonst springt die Auswahl auf die Karte, die unter der Maus aufgeht),
  Klick wechselt sofort. Notbremse schließt nach 10 s.
- **Aufbau, auf Tempo getrimmt** (Wunsch: so schnell wie möglich, ohne Animation): Wurzel ist ein `Scope` (Logik,
  Kürzel, IPC) mit `Variants` → **ein `PanelWindow` pro Bildschirm, dauerhaft da**: in Ruhe 1×1 px oben links,
  durchsichtig, klick-durchlässig (`mask` = leere Region) – in `hyprctl layers` stehen also immer drei `golden-taskview`
  mit 1×1. Beim Öffnen wird das Fenster des Bildschirms mit Fokus (`targetScreen`, `win.active`) per Anker groß gezogen.
  Gemessen (Quickshell blockiert jeweils so lange): Fenster neu anlegen ~80–100 ms, groß ziehen ~15–40 ms, Karten anlegen
  ~25 ms, Live-Vorschauen starten ~60 ms. Darum: **Karten gibt es immer** (`ScriptModel windows` = `list`, unsichtbar in
  jedem Fenster), **Vorschauen starten erst nach dem ersten sichtbaren Bild** (`win.capturing`, gesetzt in
  `onFrameSwapped` des Fensters; bis dahin großes App-Symbol) und enden beim Schließen. Sichtbar (`shown`) wird die Ansicht
  nach `showDelay` = **50 ms echter Zeit** ab dem Tastendruck (gegen Aufblitzen bei kurzem Antippen; gemessen mit
  `Date.now()`, siehe Fallstrick „QML-`Timer`“), **ohne** Ein-/Ausblenden, Auswahl-Farbe wechselt ebenfalls sofort.
  Hyprland animiert die Ebene nicht (`no_anim`, siehe `docs/hyprland.md` → Layer-Regeln). Gemessen am 2026-10-07 (7 Fenster): komplett da nach
  **~60–80 ms**, Vorschauen nach ~100–160 ms (ursprünglich ~220 ms bis zum ersten Bild + 200 ms Einblenden).
  Noch schneller: `showDelay` kleiner (0 = sofort, dann blitzt kurzes Alt+Tab-Antippen auf).
- Die Fensterliste (`list`) wird immer aktuell gehalten (`refreshToplevels` bei Hyprland-Ereignissen), damit schon das
  erste Alt+Tab stimmt. Die Anordnung (`layout`) rechnet mit der Größe von `targetScreen`.

## Tastenkürzel-Übersicht (`KeysHelp.qml`, Super+I)
Glas-Karte oben rechts (≈ 750 × 630 px) mit allen Kürzeln in zwei Spalten: links „apps & menüs“, „desktop“, „workspaces“,
rechts „fenster“, „maus & gesten“, „bildschirmfoto“; unten ein Hinweis auf die Laptop-Tasten. Jede Taste als kleine
Kappe, daneben eine kurze Erklärung. Hyprland meldet Super+I als `quickshell:keysToggle`; geht auf dem Bildschirm mit
Fokus auf. Schließen: Super+I, 󰅖, Esc (bei leerer Suche), Klick aufs Wallpaper, oder das Kontrollzentrum öffnen.
- **Filter:** Tastatur ist `Exclusive` → sofort tippen (Super+I bleibt als Hyprland-Bind trotzdem wirksam). Suchwörter (Leerzeichen/`+`
  getrennt, alle müssen passen, `ctrl` = `strg`) treffen, wenn eine Taste oder ein Erklärungswort damit **beginnt**; leere Abschnitte/Spalten
  verschwinden. Esc löscht erst die Suche, dann schliesst es. Ablauf in `matches()` / `anyMatch()`.
- **Liste pflegen:** Eigenschaft `columns` = [linke Spalte, rechte Spalte] → Abschnitte `{ title, keys: [[Tasten, Erklärung], …] }`.
  Tasten mit `" + "` verbinden, Alternativen mit `" / "` trennen (`"super + leer / d"` → [super][leer] / [d]).
  Erklärungen kurz halten (≤ 24 Zeichen), sonst werden sie abgeschnitten (`infoW`); Tasten-Spalte `keyW` = 160 px.

## IPC-Befehle (`qs ipc call <ziel> <funktion>`)
| Ziel | Funktionen |
|---|---|
| `wallpaper` | `set <pfad>`, `animate` (lebendig an/aus) |
| `gallery` | `toggle`, `open`, `close` (Wallpaper-Galerie, Super+W) |
| `theme` | `set <name>` (Farbthema, ruft `scripts/thema.sh` auf), `get`, `reload` (`themen/*/farben.json` neu einlesen) |
| `studio` | `open`, `close`, `toggle` (App „Wallpaper“, `WallpaperStudio.qml` – siehe `docs/wallpaper.md`) |
| `music` | `toggle` (holen/zurücklegen auf dem Bildschirm mit Fokus), `toggleOn <bildschirm>` (dasselbe auf z. B. `DVI-I-1`; benutzt Super+M), `open` (über die Fenster), `close` (ausblenden wie ✕) |
| `lyrics` | `toggle` (Songtext auf dem Desktop), `screenOn <bildschirm>` (Songtext-Bildschirm auf/zu/dorthin wechseln; benutzt Super+Shift+M), `screenClose`, `style seide\|fluss\|flecken` (Hintergrund des Songtext-Bildschirms) |
| `clock` | `toggle` |
| `airdrop` | `toggle`, `open`, `close` (Fenster), `on`, `off` (AirDrop 10 min an / aus) |
| `control` | `toggle`, `close`, `open <bereich>` (bereich: `wifi`, `bluetooth`, `power`, `night` oder `""`) |
| `night` | `toggle`, `enable`, `disable` (Nachtmodus) |
| `wifi` | `toggle`, `close` (Kontrollzentrum mit WLAN-Liste) |
| `bluetooth` | `toggle`, `close` (Kontrollzentrum mit Bluetooth-Liste) |
| `taskview` | `toggle`, `open`, `close` |
| `keys` | `toggle`, `open`, `close` (Tastenkürzel-Übersicht) |
| `switcher` | `state`, `items` (Debug für Alt+Tab, liegt in `TaskView.qml`) |
