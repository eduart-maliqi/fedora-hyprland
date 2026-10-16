# Änderungsprotokoll – 8155-Desktop

Wird **nicht** automatisch geladen – nur lesen, wenn die Geschichte einer Änderung wichtig ist (z. B. Fehlersuche).
Neueste Einträge oben. Format: `JJJJ-MM-TT – was (Dateien) – warum`, **höchstens 3 Zeilen** (keine Testprotokolle, keine Zitate). Einträge bis 2026-10-08 sind noch ausführlicher.

- **2026-10-16** – Akku-Warnungen (`BatteryWarning.qml`): 20 %/10 % klein, 5…1 % gross – Wunsch des Benutzers.
- **2026-10-16** – hypr-computer Branch `smaller-after-shots`: Kontrollbilder 900 px statt 1568 (`screen.py`, `server.py`) – weniger Tokens.
- **2026-10-16** – Super+I-Übersicht filtert beim Tippen (`KeysHelp.qml`, Tastatur Exclusive) – Wunsch des Benutzers.
- **2026-10-16** – hypr-computer installiert (MCP für Claude, eigene Agenten-Desktops auf Workspace 4–0, docs/system.md) – Wunsch des Benutzers.
- **2026-10-16** – agentControl installiert (`~/.local/opt/agent-control`) + `hl.env("PATH")` mit `~/.local/bin` – Hyprland/rofi fanden Programme aus `~/.local/bin` nicht.
- **2026-10-16** – Swallowing aus (`misc.enable_swallow`) – vom Terminal gestartete Fenster (Playwright-Browser u. a.) verschluckten das kitty von Claude Code.
- **2026-10-16** – `kitty help` zeigt Kürzel (`~/.config/kitty/help.sh`, Funktion in `~/.bashrc.d/kitty.sh`) – Wunsch des Benutzers.
- **2026-10-15** – hyprlock zeigt unter dem Titel die aktuelle Songtext-Zeile (`lyrics.py line`, nur Cache) – Wunsch des Benutzers.
- **2026-10-15** – Bildschirmaufnahme: wf-recorder + `scripts/aufnahme.sh` auf Strg+Druck – Wunsch des Benutzers.
- **2026-10-15** – Seide blieb nach erneutem Auswählen stehen: `Ui.wallpaperReal` las per Binding den alten Pfad → Befehl im Handler setzen.
- **2026-10-15** – Bewegtes Wallpaper „seide“ (Wabe in der Galerie mit Farbauswahl, Ebene in `Wallpaper.qml`, Standbilder `wallpapers/seide/`
  per `seide-standbild.py`, `wallpaper.sh` liest `glut.jpg` als Thema) – Benutzer wollte die Seiden-Animation als Desktop-Hintergrund.
- **2026-10-15** – Songtext-Bildschirm: Fortschrittslinie spult per Klick/Ziehen – Wunsch des Benutzers.
- **2026-10-15** – Songtext-Bildschirm: Hintergrund „seide“ (Shader `seide.frag`, glänzende 3D-Seide) als neuer Standard – nach einem
  Beispielvideo des Benutzers; „fluss“/„flecken“ bleiben per `qs ipc call lyrics style …`.
- **2026-10-15** – Songtext-Bildschirm: Tastatur `OnDemand` statt `Exclusive` – andere Fenster bekamen keine Eingaben mehr.
- **2026-10-15** – Songtext-Bildschirm: neuer Hintergrund „fluss“ (Shader `fluss.frag`, fließende Farben), alter als „flecken“ per
  `qs ipc call lyrics style flecken` – Benutzer mochte die Flecken-Animation nicht so, will aber zurück können.
- **2026-10-15** – Songtext-Bildschirm: Hintergrund schneller/weiter bewegt, Sättigung hoch, weniger abgedunkelt – war zu wenig bewegt und zu fade.
- **2026-10-15** – Songtext-Bildschirm: Cover von Spotify (640 px) statt MPRIS (`Spotify.qml` dafür aktiv) – Brave liefert nur 150 px, war unscharf.
- **2026-10-15** – Songtext-Bildschirm Super+Shift+M (`LyricsScreen.qml`, Ui, shell.qml, hyprland.lua, KeysHelp): Vollbild wie Apple Music
  mit bewegtem, verschwommenem Hintergrund aus Wallpaper + Themenfarben – Wunsch des Benutzers.

- **2026-10-14** – IntelliJ-Flatpak: `JAVA_HOME` per `flatpak override` auf JDK-21-Kopie in `~/.jdks` (docs/system.md) – Gradle-Sync
  scheiterte auf Java 25 („Incompatible Gradle JVM“).
- **2026-10-14** – AirDrop mit dem iPhone: Kapsel 󰀃 + `AirdropPanel.qml`/`Airdrop.qml` (Dateien hineinziehen, an Geräte senden), Backend omdrop +
  omdrop-owl (OpenDrop-Nachfolger, kann Intel AX211; WLAN ist solange getrennt), Meldungen über `scripts/airdrop-meldung.sh` → docs/system.md.
- **2026-10-14** – Spiegelfenster folgt dem Hoch-/Querformat (`iphone-fenster.py`, Grösse aus UxPlays Debug-Log), `-vsync no` gegen Verzögerung,
  Mausgeschwindigkeit 0,6 (Wunsch: war zu schnell).
- **2026-10-14** – iPhone steuern läuft (iPhone 15 Pro Max): Bewegung in 15-ms-Paketen (Einzelmeldungen bremste iOS auf null), Klick fängt
  die Maus ein, Strg+Alt gibt frei (Wunsch), nur eine Sitzung (flock), Fenster per SIGUSR1 ohne Passwort neu ladbar.
- **2026-10-14** – iPhone steuern: Deckkraft 0,02 statt 0 (sonst keine Maus), Ebene per `alter_zorder` statt Fokus (Zeiger sprang zurück),
  ohne Spiegelung versteckt; Hotspot „iPhone (2)“ bevorzugt + Rückverbinden während der Spiegelung (`iphone-uxplay.sh`).
- **2026-10-14** – iPhone steuern direkt im Spiegelbild: `iphone-steuern.py` ist jetzt ein unsichtbares Fenster über dem UxPlay-Fenster, der
  iPhone-Zeiger folgt der Maus (Ecke + gemessene Strecke) – vorher kleines Fenster mit Einfangen, Zeiger kaum zu finden. Spiegelbild nicht mehr abgedunkelt.
- **2026-10-14** – iPhone steuern: iOS fand bzw. koppelte die LE-Maus am Dual-Mode-Adapter nicht (koppelte über Classic) → `iphone-le.sh`
  schaltet per pkexec während der Steuerung BR/EDR ab + LE-Privacy (statische Adresse brach GATT: Trennung nach 4 s), danach SSP wieder an; `iphone-hid.py` ohne doppelten 180A-Dienst, Alias, Journal-Ausgaben.
- **2026-10-14** – iPhone spiegeln + bedienen: UxPlay-Dienst (Super+Shift+A, Kontrollzentrum-Kachel `Iphone.qml`, `scripts/iphone.sh`), Bluetooth-LE-HID
  (`iphone-hid.py` + `iphone-steuern.py`, Super+Alt+A), Firewall `mdns` offen. AirPlay allein kann das iPhone nicht steuern → docs/system.md.
- **2026-10-14** – Wackelfenster: Nachschwingen ruckelte/lief in Zeitlupe (`plugins/wobbly/main.cpp`): Plugin treibt die Bilder jetzt per
  Timer selbst an (vorher 2–4 fps nach der Fensteranimation), `MAX_DT` 1/30 → 1/15 s. Nachschwingen fertig nach ~1,5 s statt ~5 s.
- **2026-10-13** – Kalender im Kontrollzentrum (`CalendarView.qml`, `CalendarService.qml`, `scripts/kalender.py`): heute + 1 Monat rollend, Termine aus dem
  Google-Konto über die Evolution-Datenbank (GNOME-Online-Konten, kein eigenes Token). Neue Singleton-Datei → Quickshell einmal neu starten.
- **2026-10-13** – Wallpaper-Galerie: Rest des letzten Wabenbands liegt in einer Reihe statt im Zickzack (`WallpaperGallery.qml`) – eine einzelne Wabe hing weit unten.
- **2026-10-13** – `README.md` + `screenshots/` im Repo-Wurzelverzeichnis (`~/.config`), Repo heisst `fedora-hyprland`. Screenshots nur auf leerem
  Workspace und mit Testfenstern aufnehmen, vorher ansehen – das Repo ist öffentlich.
- **2026-10-13** – Songtext für „Cu mbush mali plot me rrush“ (Irini Qirjako) dauerhaft entfernt (`docs/musik.md`): Whisper hielt das albanische Lied
  für russisch, Text war Kyrillisch/Hebräisch-Kauderwelsch.
- **2026-10-13** – Git für `~/.config` (hypr, quickshell, rofi, mako, kitty; `.gitignore` mit Ausnahmen), Remote öffentlich auf GitHub – Versionsverlauf statt tar;
  Mailadresse aus `docs/system.md` entfernt, weil öffentlich.
- **2026-10-13** – Clawd-Hooks (15) aus `~/.claude/settings.json` entfernt, Clawd wird nicht mehr gebraucht – sie starteten bei jedem Werkzeugaufruf `node`.
- **2026-10-13** – Strg+Druck (Screenshot + gleich einfügen, `scripts/screenshot-paste.sh`) wieder entfernt: klappte beim Benutzer nicht
  zuverlässig und wird nicht gebraucht. Fallstrick falls neu gebaut: `hyprshot` endet auch bei Erfolg mit Exit-Code 1.
- **2026-10-13** – Claude-Kapsel in der Leiste (`ClaudeSessions.qml`, `scripts/claude-sessions.py`, `Bar.qml`): zeigt fertige, noch nicht angesehene
  Claude-Code-Sitzungen, Klick springt hin – aus `~/.claude/sessions/*.json`, ohne Hooks – Wunsch.
- **2026-10-13** – Absturzserie ausgewertet (nur gelesen, nichts geändert): nicht die Plugins (Abstürze auch ohne), auffällig Standby + Dock-
  Monitore; Details in `docs/testen.md`. Shader-Plugin deshalb bewusst **nicht** abgeschaltet.
- **2026-10-13** – Abmelden jetzt Super+Strg+Shift+M (vorher Super+Shift+M, lag neben Super+M = Musik); `noa-start.sh` startet nichts doppelt
  (Prozess-Erkennung + `flock`); `WallpaperScene.qml` lädt Masken nur, wenn sie existieren (Log-Warnungen) – offene Punkte der Durchsicht.
- **2026-10-13** – Strg+Shift+←/→ = voriges/nächstes Lied, Super+Alt+←/→ = 5 s zurück/vor (`playerctl`, `hyprland.lua`, KeysHelp) – Wunsch;
  Alt+Shift+←/→ war zuerst vorgesehen, kollidiert aber mit VS Code (Auswahl erweitern).
- **2026-10-13** – Strg+Shift+Leertaste = Musik pausieren/weiter (`playerctl play-pause`, `hyprland.lua`, KeysHelp) – Wunsch.
- **2026-10-13** – `zoxide` installiert (+ `fzf` als Abhängigkeit), Einrichtung in `~/.bashrc.d/zoxide.sh`; NOA-Ordner vorbefüllt – Wunsch.
- **2026-10-13** – `scripts/noa-start.sh` meldet per Benachrichtigung, was gestartet wurde und was schon lief – vorher passierte sichtbar
  nichts, wenn alles schon lief.
- **2026-10-13** – Dropdown-Terminal verwischt/dimmt den Rest nicht mehr (`special_look()` in `hyprland.lua` schaltet `dim_special`/`blur.special`
  nur solange es offen ist) – Wunsch; die Versteckt-Ansicht behält ihren Blur.
- **2026-10-13** – Super+Shift+Enter = Dropdown-Terminal (`golden.dropdown_terminal`, Regel `dropdown-terminal`, Special-Workspace);
  Super+Shift+D = NOA hochfahren (`scripts/noa-start.sh`: noadb, Backend/Frontend-Tabs, IntelliJ) – Wunsch. KeysHelp ergänzt.
- **2026-10-13** – Zwischenablage-Verlauf (Super+Shift+V, `scripts/clipboard.sh`) fügt die Auswahl jetzt selbst ein (`send_shortcut` Strg+V);
  Esc löscht die Zwischenablage nicht mehr – vorher wurde nur kopiert, man musste von Hand Strg+V drücken.
- **2026-10-13** – Aufgeräumt: `hyprland.lua.bak-clawd` und `scripts/__pycache__` gelöscht, wirkungslose `master`-Einstellung
  (Layout ist dwindle) und veralteten Themen-Kommentar in `hyprland.lua` entfernt – Durchsicht des Setups.
- **2026-10-13** – Benutzerordner kleingeschrieben (`~/applications`, `bildschirmfotos`, `dokumente`, `downloads`, `videos`, `themes_etc`, `bilder/camera`;
  Pfade in `hyprland.lua`, Lesezeichen, `user-dirs.dirs`, `.desktop`-Dateien angepasst) – Wunsch.
- **2026-10-12** – Versteckt-Ansicht schließt sich beim Wechsel auf einen anderen Bildschirm (`hyprland.lua`, `monitor.focused`) – Fehler:
  Ansicht blieb rechts offen → mit Super+H versteckte Fenster erschienen dort.
- **2026-10-12** – Neues Wallpaper `mond-naruto.jpg` (Naruto, aus ~/Downloads/wallpaper, nur 236×236 → hochgerechnet) – Wunsch.
- **2026-10-09** – Maske für `golden-shenron` (Himmel/Wolken, Wind an Mähne + Gokus Haare, kein Wasser) – Wunsch: lebendiges Wallpaper.
- **2026-10-09** – Neues Wallpaper `golden-shenron.jpg` (Dragon Ball, aus ~/Downloads/wallpaper, nur 1920×1080 → hochgerechnet) – Wunsch.
- **2026-10-09** – Neues Wallpaper `mond-titan.jpg` (Attack on Titan, aus ~/Downloads/wallpaper, Thema mond) – Wunsch.
- **2026-10-09** – Clawd on Desk startet nicht mehr automatisch (Autostart-Zeile in `hyprland.lua` entfernt) – Wunsch.
- **2026-10-09** – Thema purpur: Datum der Desktop-Uhr in kräftigem Pink (`clockDate`) – Wunsch beim Kirschbaum-Wallpaper.
- **2026-10-09** – Desktop-Uhr: Datum auf hellen Wallpapern dunkel + fett (Helligkeit misst `wallpaper.sh` → `uhr-hintergrund`)
  – Wunsch: Datum auf glut-fuji nicht lesbar; Uhrzeit und Scheibe bewusst unverändert.
- **2026-10-09** – 7 Bilder aus ~/Downloads/wallpaper (volle Auflösung) + Thema „silber“ für schwarz-graue Bilder – Wunsch:
  alle aus dem Ordner als Wallpaper, gute Qualität.
- **2026-10-09** – Die vier hochgerechneten Bilder (windmuehle, abyss, goldband, fuji) wieder in den Papierkorb – zu unscharf.
- **2026-10-09** – Bilder golden-windmuehle, golden-abyss, kohle-goldband, glut-fuji (vom Benutzer, hochgerechnet); Galerie:
  Strg+Entf löscht das gewählte Bild in den Papierkorb (`wallpaper.sh weg`) – Wunsch: Wallpaper per Tastenkürzel löschen.
- **2026-10-09** – `purpur-wolf.jpg` nach aussortiert/ (Thema purpur bleibt) – Wunsch: Wolf-Bild weg.
- **2026-10-09** – Super+W = Wallpaper-Galerie (`WallpaperGallery.qml`, Waben, zuletzt genutzt zuerst über `wallpaper-verlauf`)
  statt „nächstes Bild“; neue Bilder glut-ring, kohle-feuerwache, purpur-wolf + Themen kohle/purpur – Wunsch: Galerie mit
  Sechsecken, sortiert nach zuletzt genutzt.
- **2026-10-09** – Neues Wallpaper `glut-finsternis.jpg` (Dark Souls III, vom Benutzer, hochgerechnet) + Farbthema „glut“
  (Glutrot; `red` jetzt pro Thema, in glut orange); `mond-wolken.jpg` nach aussortiert/, Thema mond bleibt – Wunsch: dieses Bild
  statt des Mond-Bilds.
- **2026-10-08** – Dunkles Wallpaper `mond-wolken.jpg` + Farbthemen golden/mond: Thema = Dateiname-Anfang, `scripts/thema.sh`
  schaltet Quickshell (Theme.qml-Paletten, `Theme.accent*` statt `amber*`), Hyprland, hyprlock, mako, rofi, kitty (`themen/`) um.
  Dazu Fehler in WallpaperScene.qml behoben (Bild nach valley bekam dessen Maske) – Wunsch: dunkles 4K-Wallpaper mit passender Leiste/Uhr.
- **2026-10-08** – GRUB „ghost“: Schrift Cinzel statt Jost, Versalhöhe 105 statt 140 px, Pinselstrich 55 % deckend
  (`bilder.py`, `theme/`, `15_ghost_menu`, `plymouth_bilder.py`) – Wunsch: „etwas kleiner und ein schöner Font“.
- **2026-10-08** – Nach dem Booten Passwort im 8155-Sperrbildschirm: GDM-Autoanmeldung bleibt, `hyprlock` als erste
  Autostart-Zeile (hyprland.lua); unter GNOME sperrt `scripts/gnome-sperren.sh` (Autostart). Vorher ganz ohne Passwort;
  GDM-Anmeldebildschirm verworfen – Wunsch: eigener Sperrbildschirm statt GNOME-Look.
- **2026-10-08** – Musik: „zuletzt gehört“ lud nicht (Spotify verwarf das Token vor Ablauf, Panel holte es bei 401 erneut) →
  `spotify-auth.py token --refresh` + Spotify.qml. KI-Songtexte (lyrics.py): kein „Interpret – Titel“ mehr als Whisper-Hinweis
  (wurde wiederholt / Sprache als russisch erkannt), < 5 verschiedene Zeilen = nichts, dann einmal ohne Hinweis.
- **2026-10-08** – GRUB „ghost“ unter Secure Boot repariert (lud keine Schriften → Notschrift, Firmware-Auflösung): Einträge
  als Bilder (`theme/icons`), gfxmode in grubenv, LOAD GAME fest + Kernel-Hook `95-ghost-menu.install`; Hintergrund =
  Wallpaper wp15726322 (`wallpaper_bild.py`), Text ~140 px – Wunsch: „fünfmal so groß“ + genau dieses Wallpaper.
- **2026-10-08** – Systemupdate nachgeholt (1455 Pakete, Kernel 7.2.9, evdi gebaut): 211 doppelte Pakete aus dem abgebrochenen
  Update vom 2026-04-26 per `rpm -e --justdb` ausgetragen, dann `dnf upgrade` (docs/system.md → Bekannte Baustelle).
- **2026-10-08** – `/etc/chrony.conf`: `makestep 1.0 -1` statt `1.0 3` (docs/system.md → Systemuhr) – Ton stockte überall:
  Uhr nach Standby 2 h vor (RTC in Ortszeit wegen Windows), chrony bremste sie um 8,3 % ab → Audio-Timing kaputt.
- **2026-10-08** – GRUB „ghost“: Schrift Jost 150 (≈1,9×), andere Einträge gedimmt, Hintergrund aus Schlüsselbild + abgedunkelt
  unten links; Plymouth ohne Gras-Animation (nur Szene + Schnee) – Wunsch: „Schrift vieeel größer“, Auswahl deutlicher,
  Animation hin und zurück sah schlecht aus, „verpixelt“ (YouTube-Blöcke im bewegten Gras).
- **2026-10-08** – GRUB „ghost“ 1:1 wie GoT: echtes Bild aus dem Menü-Video (`got_bild.py`), Jost 1,4× größer, Strich wie im
  Spiel; neu animierter Plymouth-Ladebildschirm (`plymouth/`, `plymouth_bilder.py`, Paket plymouth-plugin-script, initramfs
  neu) – Wunsch: Schrift größer, Hintergrund bewegt, „1 zu 1 wie Ghost of Tsushima“ (GRUB selbst kann nicht animieren).
- **2026-10-08** – Regel: Code-Kommentare nur, wenn wirklich nötig und sinnvoll (`~/CLAUDE.md`, `AGENTS.md` Regel 5) – Wunsch.

- **2026-10-08** – Doku aufgeteilt: `AGENTS.md` ist nur noch der Kern (wird immer geladen), Details nach `docs/*.md`,
  Protokoll hierher; Regeln in `AGENTS.md`, `~/CLAUDE.md` und beiden `CLAUDE.md` angepasst – weniger Tokens pro Sitzung
  (vorher 114 KB ≈ 35k Tokens). Sicherung: `vor-doku-aufteilen-20261008-0905.tar.gz`.


- **2026-10-08** – **Phantom** (Plugin Phantomat, unendliche Arbeitsfläche) mit **Super+P**; Pseudo-Tiling wandert auf
  **Super+Shift+P**, neu **Super+Strg+P** = Phantom aus. Neu: `hypr/phantomat.lua`, `hypr/scripts/phantomat.sh`, Quelltext
  `~/.local/opt/phantomat` (Commit `d62ba67`) → `~/.local/share/hyprland/plugins/phantomat.so`. `hyprland.lua`: Helfer
  `phantom_dispatch/open/or` nach `local mod`, Abschnitt „Phantom“ nach dem Wackelfenster (`hl.plugin.load`, `golden.phantom`,
  `golden.phantom_off`, Binds), Super+V/J/Shift+P/O + Workspace-Tasten tun auf der Fläche nichts, Super+(Shift+)Pfeile
  navigieren/schieben dort. `KeysHelp.qml`: zwei Zeilen unter „desktop“, Pseudo-Tiling auf Shift+P – Wunsch: „mach phantom als
  plugin rein … das was so wie infinite desktop macht … mit super + p, das was jetzt mit super p ist soll eine andere kürzel
  bekommen“. Beim Test gefunden: HyprWindowShade blockiert die Hooks von Phantomat → die beiden wechseln sich ab (siehe „Phantom“).
  Getestet im verschachtelten Hyprland (siehe dort); live nur geladen + Einstellungen geprüft, Fläche noch nicht geöffnet.
  Sicherung davor: `vor-phantomat-20261008-0825.tar.gz`.

- **2026-10-08** – GRUB-Menü „ghost“ startet **nie mehr automatisch**: `GRUB_TIMEOUT=-1` (in `grub-ghost/installieren.sh`,
  mit Prüfung), Countdown-Label aus `grub-ghost/theme/theme.txt` entfernt, Test-Header in `test/vm-bauen.sh` angepasst;
  `installieren.sh` räumt Reste eines abgebrochenen Laufs weg – Wunsch: „es soll nie automatisch starten, egal wie lang
  ich nicht klicke“. In der VM geprüft (32 s ohne Taste → Menü unverändert, Enter → Fedora startet).
- **2026-10-08** – **GRUB-Bootmenü „ghost“** im Stil des Ghost-of-Tsushima-Startbildschirms: neuer Ordner `hypr/grub-ghost/`
  (Bildgenerator, Pinselstriche, Schriften, Menü-Skript, installieren/rueckgaengig, Test-VM); im System
  `/boot/grub2/themes/ghost/`, `/etc/grub.d/15_ghost_menu`, `/etc/default/grub` (Theme, 2880×1800, os-prober aus),
  `10_linux` + `30_uefi-firmware` `chmod -x` – Wunsch: Dualboot-Bildschirm soll aussehen „als wäre ich im Spiel“.
  Einträge FEDORA LINUX · WINDOWS · LOAD GAME (Kernel-Liste) · OPTIONS (UEFI) · QUIT GAME (aus); vorher in QEMU mit
  Fedoras grubx64.efi getestet (Menü, Countdown/Autostart, Windows-Chainload, älterer Kernel + gespeicherter Standard,
  UEFI, Ausschalten). Sicherungen: `vor-grub-ghost-20261008-0826.tar.gz`, `*.vor-ghost-20261008-*` (siehe „Weitere Programme“).

- **2026-10-07** – **Neue Wallpaper**: `wallpapers/golden-castle.jpg`, `golden-sunset.jpg`, `golden-manor.jpg` (von wallhaven.cc,
  auf 2880×1800 zugeschnitten), `golden-meadow.jpg` + Maske nach `wallpapers/aussortiert/` verschoben – Wunsch: aktuelles
  Bild (golden-valley) behalten, das zweite war nicht gut; aus den Vorschlägen 1, 3 und 4 gewählt, mit Super+W durchblättern.
  `wallpaper.sh` und Bind unverändert. Getestet: `wallpaper.sh next` 4× → alle vier der Reihe nach, zurück bei golden-valley.
  Die neuen Bilder haben noch **keine Maske** (bleiben beim lebendigen Wallpaper still). Sicherung: `vor-wallpaper-neu-20261007-1627.tar.gz`.
- **2026-10-07** – Inaktive Fenster: `shaders/dim-inaktiv.glsl` `STAERKE` 0.5 → **0.6** – Wunsch: „mach 6“.
- **2026-10-07** – Inaktive Fenster wieder weniger dunkel: `shaders/dim-inaktiv.glsl` `STAERKE` 0.7 → **0.5** – Wunsch: „mach das verdunkeln von nicht benutzen fenstern weniger“.
- **2026-10-07** – **Alt+Tab nochmals schneller, ohne Animation** – Wunsch: „immer noch zu langsam … mache die animation
  weg … kann einfach so aufpoppen“. Neu gemessen: Fenster neu anlegen allein ~80–100 ms, Vorschauen starten ~60 ms (beides
  blockiert Quickshell). `TaskView.qml` umgebaut: Wurzel `Scope` + `Variants` → pro Bildschirm ein dauerhaftes
  `PanelWindow` (in Ruhe 1×1 px, klick-durchlässig), beim Öffnen nur per Anker groß gezogen; Karten immer vorhanden
  (unsichtbar); Vorschauen starten erst nach dem ersten sichtbaren Bild (`win.capturing` über `onFrameSwapped`);
  kein Ein-/Ausblenden, keine Farb-Animation bei der Auswahl; `showDelay` 90 → 50 ms; `layout` rechnet mit `targetScreen`;
  IPC `switcher state` zeigt zusätzlich `screen`. `hyprland.lua`: nur Kommentar an der `no_anim`-Regel angepasst.
  Ergebnis: komplett da nach ~60–80 ms (vorher ~210 ms, ursprünglich ~420 ms), Vorschauen nach ~100–160 ms.
  Neuer Fallstrick „Fenster anlegen ist teuer“ unter Quickshell → Grundlagen.
- **2026-10-07** – **Alt+Tab/Super+Tab erscheinen schneller** – Wunsch: „alt tab braucht immer so lang bis es anzeigt“.
  Gemessen (Zeitstempel in QML + Hyprland-Ereignis `openlayer`): 110 ms Wartezeit, **danach** erst ~100 ms Fenster anlegen
  (Ebene + 6 Vorschauen), dann 200 ms Hyprland-Einblenden → ganz sichtbar erst nach ~420 ms. Änderungen:
  `TaskView.qml` – Fenster schon ab `open` anlegen (durchsichtig, `mask` leer), Wartezeit 110 → 90 ms und nach echter
  Uhrzeit (`showDelay`, `openedAt`, Timer prüft alle 10 ms `Date.now()`; ein normaler 90-ms-Timer kam wegen Qts
  Animationsuhr erst nach ~170 ms), Super+Tab läuft über denselben Timer, Einblenden 150/180 → 100/120 ms.
  `hyprland.lua` – neue Layer-Regel `golden-taskview` → `no_anim = true`. Ergebnis: sichtbar nach ~100–110 ms, ganz da
  nach ~210 ms. Neuer Fallstrick „QML-`Timer` sind keine Stoppuhr“ unter Quickshell → Grundlagen.
  Sicherung: `~/.cache/golden-backups/vor-alttab-schneller-20261007-1352.tar.gz`.
- **2026-10-07** – hyprlock: Schriftzug „★ 8155“ grösser, `font_size` 22 → **42**, `position` 0, 250 → 0, 275 (damit er die
  Uhrzeit nicht berührt) – Wunsch: „mache das 8155 beim sperrbildschirm grösser“. Geprüft per hyprlock im verschachtelten
  Test-Hyprland (headless 2880×1800, Skalierung 1,667) + grim: deutlicher Abstand zur Uhrzeit.

- **2026-10-07** – **Name „golden hour“ → „8155“ überall**: Kopfkommentare aller Dateien, `Theme.title` (Leiste ohne Musik,
  jetzt mit `lnum`), hyprlock-Schriftzug (`lnum` per Pango-`font_features`), Spotify-Anmeldeseite, Plugin-Beschreibung in
  `wobbly/main.cpp` (neu gebaut mit `build.sh --nur` → `hyprctl plugin list` zeigt es erst nach dem nächsten Hyprland-Start),
  User-Agent in `lyrics.py`, Doku (`AGENTS.md`, beide `CLAUDE.md`, `~/CLAUDE.md`), Kommentar in `~/.claude/statusline.sh`.
  Ordner umbenannt: `~/.local/state/golden-hour` → `~/.local/state/8155`, `~/.cache/golden-hour` → `~/.cache/8155`,
  `~/.local/share/fonts/golden-hour` → `~/.local/share/fonts/8155` (+ `fc-cache`); Pfade in `hyprland.lua`, `NightLight.qml`,
  `WindowMode.qml`, `ModeOsd.qml`, `Ui.qml`, `lyrics.py`, `spotify-auth.py`, `explorer-modus.py` angepasst – Wunsch:
  „überall wo man goldenhour sieht mach weg und schreibe 8155 hin“. **Bewusst geblieben:** `golden.*` (Lua), Namespaces
  `golden-*`, `~/.cache/golden-backups/`, Wallpaper `golden-*.jpg` (heissen „golden“, nicht „golden hour“), alte Sicherungen
  (`hyprland.lua.bak-clawd`, tar.gz) und der Name der Spotify-App im Dashboard. Sicherung davor: `vor-8155-20261007-1101.tar.gz`.

- **2026-10-07** – Windows-Partition: `/etc/fstab` + `hide_hid_files` (Sicherung `/etc/fstab.vor-hide-<datum>`) – Wunsch: Windows-
  Systemdateien wie `desktop.ini` und liegengebliebene Office-Sperrdateien `~$…` (u. a. 13 Stück in Documents/Downloads/Noseryoung)
  sollen wie unter Windows unsichtbar sein. Geprüft: weg aus den Listen, `AppData` per Pfad weiter erreichbar.

- **2026-10-07** – Explorer-Modus: Lesezeichen „windows (c:)“ → „windows“ = `~/Windows/Users/eduar`, „eduar“ entfernt,
  alle Windows-Lesezeichen über `~/Windows/…` (`lesezeichen-windows`, `WIN_DEFAULT` in `explorer-modus.py`) – Wunsch:
  Klick auf „windows“ soll direkt in den Benutzerordner führen.

- **2026-10-07** – **Explorer-Modus**: neues `scripts/explorer-modus.py` + Autostart-Zeile in `hyprland.lua`, Zustand
  `lesezeichen-linux`/`-windows`/`explorer-modus` in `~/.local/state/8155/` – Wunsch: im Dateimanager je ein „Tab“ für
  Windows und Linux, beim Wechseln sollen die Lesezeichen mitwechseln. Nautilus kann keine Seitenleiste pro Tab → Dienst
  tauscht die (globale) Lesezeichen-Datei je nach aktivem Tab. Logik in einer Sandbox getestet (Tabwechsel, Navigation in
  beiden Reihenfolgen, zweideutige Namen, eigene Lesezeichen bleiben). Sicherung davor: `vor-explorer-modus-20261007-0847.tar.gz`
  (enthält auch die alten Lesezeichen).

- **2026-10-07** – **Windows-Partition automatisch**: `/etc/fstab`-Eintrag (ntfs-3g, systemd-Automount) für `/mnt/windows`,
  Link `~/Windows` – Wunsch: ohne Passwort auf alle Windows-Dateien zugreifen. Vorher geprüft: kein BitLocker, Volume sauber
  (`ntfs-3g.probe` rw = 0). Getestet: Lesen + Schreiben als `edu`. Keine Änderung an hyprland.lua/Quickshell.

- **2026-10-07** – `hyprland.lua`: Logitech MX Vertical (`logitech-mx-vertical-advanced-ergonomic-mouse`) per `hl.device` auf
  −0.3, danach auf Wunsch **−0.55** – Wunsch: Maus langsamer; die bisherige Regel galt nur für die andere Logitech-Maus (Gerätename passt nicht).

- **2026-10-07** – Inaktive Fenster noch dunkler: `shaders/dim-inaktiv.glsl` `STAERKE` 0.45 → **0.7** (Wunsch des Benutzers).

- **2026-10-07** – Fenster-Shader angepasst: **Schliessen ohne Goldstaub** (`close` aus der Shader-Schleife in `hyprland.lua`, Datei bleibt liegen; Tag bei offenen Fenstern von Hand entfernt) und **inaktive Fenster dunkler** (`shaders/dim-inaktiv.glsl` `STAERKE` 0.28 → 0.45; Weiß wird jetzt ≈ #8E9193 statt #B7B7B7) – Wunsch des Benutzers. Sicherung davor: `vor-shader-anpassung-20261007-0212.tar.gz`.

- **2026-10-07** – **Fenster-Shader eingerichtet** (Plugin HyprWindowShade): neuer Ordner `hypr/shaders/` mit `goldstaub-oeffnen`, `goldstaub-schliessen`, `dim-inaktiv`, `fokus-glanz`, `alarm-puls` (.glsl); `hyprland.lua`: Regeln `shader-*` am Ende der Fensterregeln (alle Fenster außer Clawd-Pet und Bild-im-Bild). Wunsch: Goldstaub beim Öffnen/Schliessen, inaktive Fenster abdunkeln, kurzes Aufleuchten bei Fokus/Aufmerksamkeit. Getestet (Testfenster, Animation per `@4` gestreckt + grim): Öffnen und Schliessen laufen von unten nach oben mit Amber-Körnern, am Ende nichts stehen geblieben; inaktiv grau-blau abgedunkelt, Fokus-Glanz zieht durch und endet beim normalen Bild; Clawd hat keine Shader-Tags; `configerrors` leer. Alarm-Puls nur kompiliert (glslangValidator), nicht live ausgelöst. Keine neuen Tastenkürzel. Sicherung erst **nach** der Änderung gemacht (`mit-shader-20261007-0210.tar.gz`, enthält die Shader) – zurück: Block „Fenster-Shader“ in `hyprland.lua` löschen.

- **2026-10-07** – **Wackelfenster** (wobbly windows) mit **Super+G** an/aus: neues eigenes Hyprland-Plugin
  `hypr/plugins/wobbly/` (`main.cpp` – Feder-Gitter + `IWindowTransformer`, `build.sh`, `wobbly.so`), `hyprland.lua`
  (Abschnitt nach dem Fenstermodus: `hl.plugin.load`, `golden.toggle_wobbly`, Zustand `wackelfenster.json`, Bind `SUPER + G`),
  `ModeOsd.qml` (Hinweis „wackelfenster: an/aus“, beobachtet die Zustandsdatei), `KeysHelp.qml` (Zeile unter „desktop“) –
  Wunsch: „mache wobbly window bei mir und mache dass ich es mit einem Shortcut aus- und anmachen kann“. Es gibt kein
  gepflegtes Plugin für 0.56 (WiggleWobble verwaist), deshalb selbst geschrieben. Getestet im verschachtelten Hyprland
  (headless, auch Skalierung 1,667 und zusammen mit HyprWindowShade; dabei einen Absturz gefunden und behoben, siehe
  Fallstricke), Entladen/Neuladen, an/aus per `hyprctl eval`, danach live: Testfenster auf eDP-1 verformt sich und schwingt aus,
  OSD + Spickzettel per Screenshot geprüft. Ziehen mit der Maus (Griffpunkt) konnte nur der Benutzer selbst testen.
  Sicherung davor: `vor-wackelfenster-20261006-1617.tar.gz`.

- **2026-10-06** – **Plugin HyprWindowShade installiert** (Shader pro Fenster): Quelltext `~/.local/opt/HyprWindowShade` (Commit `4414596`), neues Skript `hypr/scripts/windowshade.sh`, Autostart-Zeile in `hyprland.lua`, Paket `hyprland-devel` (+ `*-devel`-Abhängigkeiten; dnf hat dabei ≈ 40 Fedora-Updates mitgezogen: systemd 258.11, wayland 1.26, Xwayland 24.1.13, util-linux 2.41.5, libpng, expat – Hyprland selbst unverändert 0.56.2-2; Neustart irgendwann empfohlen). Ohne hyprpm, weil das per sudo nach `/var/cache/hyprpm` schreibt und Hyprland komplett aus dem Quelltext bauen würde. Getestet: Plugin geladen, Test-Shader per `classshader` auf ein Testfenster (magenta) und mit `clear` wieder weg, `configerrors` leer. Noch keine Shader-Regeln eingerichtet – Wunsch: „installiere hyprwindowshade von github“. Sicherung davor: `vor-windowshade-20261006-1617.tar.gz`.

- **2026-10-06** – KI-Songtexte **erstmals echt getestet** (Key eingetragen): „Ilir Shaqiri – Zemra E Kumanovës“ → 27 s,
  43 Zeilen mit Zeitstempeln, ≈ 0.03 $. Zeitpunkte plausibel, Wörter bei albanischem Gesang (Dialekt) oft ungenau.
  `lyrics.py`: Whisper-Füllzeilen wie „Music“/„Musik“/„Muzikë“/„Instrumental“ werden jetzt gefiltert (`HALLU`).

- **2026-10-06** – `lyrics.py key` prüft den Key jetzt richtig: muss mit `sk-` beginnen, ohne Leerzeichen; OpenAI-Antwort
  400/401 → nicht gespeichert, 403 → Hinweis „eingeschränkter Key, braucht Audio“. Vorher wurde beim ersten Versuch
  statt des Keys der Befehlstext gespeichert (Zwischenablage), weil 400 nicht als Fehler galt. Falscher Eintrag gelöscht.

- **2026-10-06** – **Songtexte aus mehreren Quellen + KI**: neues Skript `hypr/scripts/lyrics.py` (Cache → lrclib → NetEase →
  YouTube-Audio + OpenAI whisper-1), `LyricsService.qml` ruft es pro Lied als eigenen Prozess auf (statt lrclib per
  XMLHttpRequest; neue Eigenschaften `stage`, `source`, `pending`), `MusicPanel.qml` zeigt den Fortschritt („♪ lade audio …“,
  „♪ ki hört zu …“, „♪ lyrics · ki“). yt-dlp nach `~/.local/opt/yt-dlp` installiert. Wunsch: bei Liedern ohne Lyrics
  (v. a. albanische) woanders suchen, OpenAI-Key vorhanden. Nebenbei behoben: lrclib-Überlastung (503) galt vorher als
  „kein Text“ und blieb bis zum Neustart von Quickshell so. Getestet: lrclib-Treffer + Cache (auch im laufenden
  Quickshell), NetEase-Treffer, YouTube-Auswahl (richtiges Video, Länge 301 vs. 300 s), LRC aus Whisper-Antwort (Testdaten),
  Multipart-Anfrage, OpenAI-Fehler 401. **Noch offen:** echter KI-Lauf – erst wenn der Benutzer `lyrics.py key` ausgeführt hat.
  Sicherung davor: `vor-lyrics-fallback-20261006-1505.tar.gz`.

- **2026-10-06** – **Alt+Tab mit Live-Vorschau**: Alt+Tab öffnet jetzt dieselbe Ansicht wie Super+Tab (`TaskView.qml`
  bekommt den Alt+Tab-Modus: `altTab`, `shown`, `step()`, `commit()`, `cancel()`, globale Kürzel `switcher…`, IPC `switcher`),
  `Switcher.qml` gelöscht, `Switcher {}` aus `shell.qml` raus, `golden-switcher` aus der Blur-Layer-Regel (`hyprland.lua`).
  Binds in `hyprland.lua` unverändert. Wunsch: bei Alt+Tab sehen, was in den Fenstern gerade passiert (vorher nur Symbol + Titel).
  Getestet: Ansicht mit Vorschauen, Weiterschalten, Abbrechen, kurzes Antippen wechselt ohne Aufblitzen.
  Sicherung davor: `vor-alttab-vorschau-20261006-1445.tar.gz`.

- **2026-10-06** – **Musik-Panel pro Bildschirm**: `shell.qml` (MusicWindow per `Variants` 2× pro Bildschirm, IPC `music toggleOn`),
  `MusicWindow.qml` (Bildschirm aus `modelData`, `Loader` + Nachlauf-Timer statt `content.fading`), `MusicPanel.qml` (`ready` fürs
  Einblenden nach dem Laden, `fading` entfernt, Suchtext mit `Spotify.query` abgleichen), `Ui.qml` (`musicScreen`, `openMusic`,
  `musicTopOn/DesktopOn/On`, `screenEmpty`; `desktopCovered` entfernt), `Lyrics.qml` (rutscht nur unter das Panel des eigenen
  Bildschirms), `Bar.qml` (Titel-Klick öffnet auf dem Bildschirm der Leiste), `hyprland.lua` (Super+M als Lua-Funktion mit
  `hl.get_monitor_at_cursor()`) – Wunsch: Super+M auf dem Bildschirm mit der Maus; bei laufender Musik auf jedem leeren
  Bildschirm automatisch Panel + Songtext. Vorher nur auf `Quickshell.screens[0]`. Getestet: `toggleOn` öffnet/wechselt/schließt
  richtig, Maus-Bildschirm stimmt; Automatik bei laufender Musik noch vom Benutzer zu prüfen.
  Sicherung davor: `vor-musik-pro-bildschirm-20261006-1433.tar.gz`.

- **2026-10-06** – **App „Bildschirme“ (nwg-displays 0.4.4)** zum selbst Anordnen der Monitore: installiert nach
  `~/.local/opt/nwg-displays` + Starter + Desktop-Eintrag + Symbol + `~/.config/nwg-displays/config` (use-desc). `hyprland.lua`:
  feste `hl.monitor`-Einträge raus → `pcall(require, "monitors")`, Anordnung (unverändert) jetzt in neuer Datei `monitors.lua`;
  Fensterregel `float-nwg-displays`. Getestet: Änderung in monitors.lua greift beim Neuladen. Wunsch: Monitore selbst einstellen
  können statt über die KI. Sicherung davor: `vor-monitore-20261006-1421.tar.gz` (Stand vor beiden Monitor-Änderungen).

- **2026-10-06** – **Monitor-Anordnung am Dock** (`hyprland.lua`, Abschnitt „MONITORE“): S24C450 links `0x0`, S24E650 rechts
  `1920x0` (beide `desc:`, 1920×1200@59.95, Skalierung 1), Laptop `eDP-1` von `0x0` nach `1056x1200` (mittig darunter) –
  vorher standen alle drei automatisch nebeneinander, Laptop links; Wunsch: so wie sie auf dem Tisch stehen.
  Sicherung davor: `vor-monitore-20261006-1421.tar.gz`.

- **2026-10-06** – **Eingebautes Mikrofon**: in `/etc/modprobe.d/audio_disable_powersave.conf` `options snd-intel-dspcfg dsp_driver=1`
  auskommentiert (per `pkexec`, Sicherung in `~/.cache/golden-backups/`) → nach dem Neustart SOF-Treiber statt `snd_hda_intel` –
  Mikrofon ging nicht (DMIC braucht SOF, im alten Modus „nicht verfügbar“). Wirkt erst nach Neustart; **Ergebnis noch nicht
  geprüft** (Lautsprecher + Mikro unter SOF testen; geht der Lautsprecher dann nicht mehr, war das evtl. der Grund für die Zeile).
- **2026-10-06** – **Kein Ton am Dock**: neue WirePlumber-Regel `~/.config/wireplumber/wireplumber.conf.d/52-dock-spdif-niedrig.conf`
  (S/PDIF der DisplayLink-Docks Priorität 100), `~/.local/state/wireplumber/default-nodes` = Kopfhörer WH-CH720N bevorzugt,
  danach interne Lautsprecher; interne Lautsprecher auf 40 % – Benutzer hörte nichts: Kopfhörer nicht verbunden →
  WirePlumber nahm den Ausgang mit der höchsten Priorität, den leeren S/PDIF-Ausgang des Docks (1108 > intern 1009).
  Siehe „Weitere Programme“. Keine Änderung an hyprland.lua/Quickshell.
- **2026-10-06** – **DisplayLink-Dock**: Paket `displaylink-1.15.1-1.github_evdi` (aus GitHub displaylink-rpm, zieht
  `xorg-x11-server-Xorg` als Abhängigkeit mit), `evdi` per DKMS für 6.18.16, 6.18.9 und 6.19.12 gebaut und signiert,
  DKMS-Schlüssel per `mokutil --import` zur MOK-Anmeldung vorgemerkt (Einmal-Passwort `12345678`, Anmeldung im blauen
  MokManager beim nächsten Neustart) – Laptop am Dock zeigte nichts auf den Monitoren (DisplayLink braucht eigenen
  Treiber; die DP/HDMI-Ausgänge des Laptops blieben „disconnected“). Keine Änderung an hyprland.lua/Quickshell.

- **2026-10-06** – **Outlook für die Noser-Young-Mail**: Desktop-Eintrag `~/.local/share/applications/outlook-noseryoung.desktop`
  (Brave `--app` mit eigenem Profil `~/.local/share/outlook-noseryoung`), siehe „Weitere Programme“ – die Mail ging bisher nur
  unter Windows, für jede Bestätigungs-Mail war ein Neustart nötig. Keine Änderung an hyprland.lua/Quickshell.

- **2026-10-06** – **Musik-Panel wie ein kleines Spotify** (ersetzt die Musik-Karte): neu `MusicPanel.qml` (Inhalt),
  `MusicWindow.qml` (2 Fenster: Bottom/Top), `Spotify.qml` (Web API), `hypr/scripts/spotify-auth.py` (PKCE-Login, Tokens in
  `~/.local/state/8155/spotify.json`); `MusicCard.qml` gelöscht. Geändert: `Ui.qml` (`musicAuto`, `musicDismissed`,
  `musicShown`, `toggleMusic()`, `closeMusic()`), `shell.qml` (zwei `MusicWindow`, IPC `music open/close`), `Bar.qml`
  (Klick → `Ui.toggleMusic()`), `Lyrics.qml` (rutscht unter das Panel), `KeysHelp.qml` („musik-panel“). Geht von selbst auf,
  solange Musik läuft; transparent (36 % Tönung) – Wunsch: Lieder/Playlists direkt am Desktop steuern statt in Spotify,
  Panel immer offen bei laufender Musik, durchsichtig wie im Vorlage-Bild. Benutzer hat Premium (nötig für die Web API).
  Sicherung davor: `vor-musikpanel-20261006-1117.tar.gz`. Danach: ohne Titel kein Cover (Brave meldet sonst sein Logo).
- **2026-10-06** – Desktop-Uhr (`ClockWidget.qml`): Kopfzeile (Stern + `Theme.title`, damals noch der alte Name) ersetzt durch
  „8155“ (gleicher Stil: Gold, Cormorant kursiv 24 px, mit `lnum`) – Wunsch des Benutzers. `Theme.title` bleibt für die Leiste
  bestehen, hyprlock unverändert.
- **2026-10-06** – **Desktop-Uhr durchsichtiger + neue Ziffern** (`ClockWidget.qml`, `hyprland.lua`): Karte ohne Blur
  (`golden-clock` aus der Blur-Layer-Regel genommen), Tönung 26 % → 8 %, weicher Schatten (`MultiEffect`) unter der Schrift
  für die Lesbarkeit; Uhrzeit statt Cormorant Garamond Light (ausgefranste Haarlinien) jetzt `SF Pro Display` Light 132 px
  mit `Text.CurveRendering`, `Text.Raised` entfernt – Wunsch: Uhr transparenter, Zahlen sahen „komisch“ aus (Screenshot).
  Sicherung davor: `vor-uhr-schrift-20261006-1121.tar.gz`.
- **2026-10-06** – **Songtexte im Instagram-Stil** (`Lyrics.qml` neu geschrieben): statt goldener Serifenzeile mit
  Schreibmaschinen-Effekt in der Bildschirmmitte jetzt oben links drei Zeilen (vorherige grau / aktuelle weiß fett /
  nächste grau), SF Pro Display Bold, mittig gesetzt mit Umbruch, weiches Hochrutschen bei jeder neuen Zeile, weicht
  der offenen Musik-Karte aus – Wunsch: Lyrics mehr oben links statt mittig, Aussehen wie bei Instagram (Screenshot).
  Sicherung davor: `vor-lyrics-insta-20261006-1104.tar.gz`. Neue Lage wurde erst nach Neustart von `qs` übernommen
  (Fallstrick unter „Grundlagen“ ergänzt).
- **2026-10-06** – **Tastenkürzel-Übersicht** mit Super+I: neues Panel `KeysHelp.qml` (oben rechts, Overlay, zwei Spalten,
  Tasten als Kappen + kurze Erklärung, IPC `keys`), `Ui.keysOpen` + gegenseitiges Schließen mit dem Kontrollzentrum (`Ui.qml`),
  `KeysHelp {}` in `shell.qml`, Klick aufs Wallpaper schließt es (`Wallpaper.qml`), Bind `SUPER + I` → `quickshell:keysToggle`
  und Layer-Regel `golden-keys` (`hyprland.lua`) – Wunsch: mit Super+I ein kleines Fenster oben rechts mit allen Kürzeln
  und kurzer Erklärung. Sicherung davor: `vor-tastenhilfe-20261006-1021.tar.gz`.

- **2026-10-01** – Rechte Leisten-Kapseln und Desktop-Uhr **50 % größer**: `Bar.qml` (Leiste 30 → 45 px, Kontrollzentrum-Kapsel
  20 → 30 px, Symbole 11 → 16 px, Abstände ×1,5), `Pill.qml` (30 px hoch, Text/Symbol 16 px), `ClockWidget.qml`
  (300×214 → 450×321, Uhrzeit 92 → 138 px, Titel/Datum/Stern/Linie/Radius ×1,5; Ränder unverändert). Now-Playing-Kapsel
  und Taskleiste unverändert – Wunsch: „alles im Screenshot 50 % größer“ (Screenshot zeigte nur rechte Kapseln + Uhr).
  Sicherung davor: `vor-groesser-20261001-1119.tar.gz`.

- **2026-10-01** – **Lebendiges Wallpaper**: Wolken ziehen, Gras/Bäume wiegen sich im Wind, Fluss glitzert, Wolkenschatten.
  Neu: `WallpaperScene.qml`, `shaders/` (wallpaper.frag + .qsb, rauschen.png), `wallpapers/masken/` (Masken für
  golden-valley + golden-meadow, Skripte in `quellen/`). Geändert: `Wallpaper.qml` (zwei Szenen, Uhr, Pause bei Vollbild),
  `Ui.qml` (`wallpaperAnimated`, `wallpaper.json`), `ModeOsd.qml` (Hinweis lebendig/still), `shell.qml` (IPC `wallpaper animate`),
  `hyprland.lua` (Super+Shift+W). Paket `qt6-qtshadertools` installiert. Startet **aus**, bis man es einschaltet –
  Wunsch: Wallpaper soll sich bewegen (Wolken, Gras, Bäume). Beim Entwickeln GPU-Hang durch einen Test (siehe
  „Testen & Fehlersuche“). Sicherung davor: `vor-animiertes-wallpaper-20261001-1020.tar.gz`.
- **2026-10-01** – `hyprland.lua`: Super+F nutzt `hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" })`
  statt `window.fullscreen` – im Browser (Brave) sollen bei Super+F die Tabs sichtbar bleiben. Achtung: ohne
  `action = "toggle"` wird nur gesetzt, nicht umgeschaltet. Sicherung: `~/.cache/golden-backups/hyprland.lua.vor-vollbild-20261001-0920`.
- **2026-10-01** – `hyprland.lua` Autostart: `dbus-update-activation-environment` gibt zusätzlich `DISPLAY XDG_SESSION_TYPE
  ELECTRON_OZONE_PLATFORM_HINT QT_QPA_PLATFORM` weiter – VS Code ließ sich aus Nautilus („Öffnen mit“) nicht öffnen
  (Prozess lief, aber kein Fenster).
- **2026-10-01** – `hyprland.lua`: Logitech-Maus langsamer, `hl.device({ name = "logitech-usb-laser-mouse", sensitivity = -0.3 })`;
  Touchpad unverändert – Wunsch: nur die Maus langsamer.
- **2026-10-01** – `hyprland.lua`: `general.extend_border_grab_area = 25` (vorher Standard 15) – Fensterrand zum
  Größe-Ändern war zu schwer zu treffen.
- **2026-10-01** – **Fenstermodus** mit Super+O: geordnet (Tiling) ↔ frei (alles schwebt, wie Windows). Logik in `hyprland.lua`
  (`golden.toggle_window_mode`, Tag `freed`, `window.open`-Handler, follow_mouse 1/2, Zustand `fenstermodus.json`);
  Anzeige `WindowMode.qml` + `ModeOsd.qml` (neu), Symbol in `Bar.qml`, `ModeOsd {}` in `shell.qml` –
  Wunsch: zwischen automatisch geordneten und frei verschiebbaren Fenstern wechseln können.
  Sicherung davor: `vor-fenstermodus-20260930-2356.tar.gz`.
- **2026-09-30** – Kontrollzentrum: Kacheln **Stromsparen** (Energieprofile via tuned-ppd) und **Nachtmodus** (Blaulichtfilter)
  mit aufklappbaren Bereichen (`ControlCenter.qml`); neuer Singleton `NightLight.qml` (hyprsunset, Zustand in
  `~/.local/state/8155/nachtmodus.json`); Blatt-/Mond-Symbol in der Leisten-Kapsel (`Bar.qml`); IPC `night` und
  `control open <bereich>` (`shell.qml`); `Ui.controlSection` kennt `power`/`night`; Paket `hyprsunset` installiert –
  Wunsch: Stromsparmodus und Nachtmodus im Kontrollzentrum. Sicherung davor: `vor-strom-nacht-20260930-2344.tar.gz`.
- **2026-09-30** – Clawd-Fenster aus Taskleiste, Alt+Tab und Aufgabenansicht ausgeblendet: neue Funktion `Ui.skipWindow(t)`
  (`Ui.qml`), benutzt in `StarLine.qml`, `Switcher.qml`, `TaskView.qml` – das Pet soll dort nicht als App auftauchen.
  Sicherung davor: `~/.cache/golden-backups/vor-clawd-filter-20260930-2344.tar.gz`.
- **2026-09-30** – Clawd on Desk installiert (`~/.local/opt/clawd-on-desk`, Starter, Desktop-Eintrag), Autostart und
  Fensterregel `clawd-on-desk-pet` in `hyprland.lua` – Desktop-Pet für Claude Code, auf allen Workspaces ohne Deko.
  Sicherung davor: `hypr/hyprland.lua.bak-clawd`.

- **2026-09-30** – `WifiList.qml`: Zugriffe auf Netz-Eigenschaften mit `?.` abgesichert – beim Suchen verschwundene
  Netze erzeugten TypeError-Warnungen im Log.
- **2026-09-30** – Diese Doku angelegt (`hypr/AGENTS.md`, `hypr/CLAUDE.md`, `quickshell/CLAUDE.md`,
  Symlink `quickshell/AGENTS.md`, Hinweis in `~/CLAUDE.md`) – damit KI-Assistenten das Setup kennen und aktuell halten.
- **2026-09-30** – Leiste umgebaut: Workspace-Sterne in der Mitte → Taskleiste mit offenen Apps (`StarLine.qml`);
  Einzel-Kapseln (Power, WLAN, Bluetooth, „n versteckt“) → aufklappbares Kontrollzentrum (`ControlCenter.qml`,
  `WifiList.qml`, `BluetoothList.qml`); `BluetoothPanel.qml` entfernt; `Ui.bluetoothOpen` → `Ui.controlOpen` /
  `controlSection` / `controlScreen`; IPC `control` und `wifi` neu; Layer-Regel `golden-control` statt `golden-bluetooth` –
  Wunsch: Apps oben sehen, Status-Kram aufklappbar, Akku immer sichtbar.
  Sicherung davor: `~/.cache/golden-backups/vor-taskleiste-20260930-2327.tar.gz`.
- **2026-09-30** – Super+Tab öffnet die Aufgabenansicht (`TaskView.qml`, Bind in `hyprland.lua`, Layer-Regel `golden-taskview`);
  vorher: nächster Workspace – Wunsch: Fensterübersicht wie bei Windows mit Auswählen/Schließen.
- **2026-09-30** – Setup „8155“ aufgebaut (Hyprland-Lua-Konfiguration, Quickshell, hypridle, hyprlock, mako, rofi, kitty).
  Ältere Einzeländerungen sind nicht protokolliert.
