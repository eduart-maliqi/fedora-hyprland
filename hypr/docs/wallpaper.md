# Wallpaper

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.

Wechseln: **Super+W = Galerie** (siehe unten) bzw. `scripts/wallpaper.sh next|<pfad>` (Symlink `current` + Quickshell-IPC +
Verlauf + Farbthema).

## Bilder & Masken

`WallpaperScene.qml` prüft beim Wechsel per `sh`, ob `masken/<name>.png` existiert, und lädt die Maske nur dann – Bilder
ohne Maske erzeugen keine „Cannot open“-Warnungen im Quickshell-Log mehr. Eine Maske, die erst später dazukommt, wird beim
nächsten Bildwechsel erkannt.

```
~/.config/hypr/
└── wallpapers/
    ├── current            ← Symlink auf das aktive Bild (von hyprlock + Quickshell benutzt)
    ├── glut-finsternis.jpg ← Aschefeld unter roter Sonnenfinsternis mit Lichtstrahl (Dark Souls III, Bild vom Benutzer, Vorlage nur
    │                        2000×1125 → Ausschnitt 1800×1125 mit Lanczos auf 2880×1800 hochgerechnet) – Farbthema „glut“; ohne Maske
    ├── glut-ring.jpg      ← rote Ring-Finsternis über Wolken und Wasserfällen (wallhaven j5v28q, 3840×2160) – Thema „glut“
    ├── glut-fuji.jpg      ← Fuji, rote Ahornblätter, Pagode (japan-artistic, 5120×2880) – Thema „glut“
    ├── golden-castle.jpg  ← Burg auf Klippe im See (Grady Frederick, wallhaven qrgjqd) – noch ohne Maske
    ├── golden-manor.jpg   ← Reiter unter Baum vor Schloss (Jessica Woulfe, wallhaven 6ly77w) – noch ohne Maske
    ├── golden-shenron.jpg ← Shenlong über Wolken, Goku winkt (Zach Smithson, 1920×1080 → mittig auf 16:10 geschnitten und mit Lanczos auf 2880×1800 hochgerechnet, 2026-10-09; etwas weich) – Thema „golden“; Maske: Himmel + Wolken ziehen, Mähne/Gokus Haare leichter Wind (`masken/quellen/golden-shenron.py`, Himmel per Farbe erkannt statt GrabCut)
    ├── golden-sunset.jpg  ← Berge + Blumenwiese bei Sonnenuntergang (TheRaspyCupcake, wallhaven 85llgj) – noch ohne Maske
    ├── golden-valley.jpg  ← Bergtal mit Fluss, dunkle Wolken (mit Maske)
    ├── kohle-gargantua.jpg ← Schwarzes Loch Gargantua (5200×3250) – Thema „kohle“
    ├── kohle-goldband.jpg ← schwarzes Stoffband mit Goldsprenkeln (Windows-11-50th, 7680×4320) – Thema „kohle“
    ├── mond-tanjiro.jpg   ← Tanjiro-Auge in Blau (6082×5416, mittig auf 16:10 geschnitten) – Thema „mond“
    ├── mond-titan.jpg    ← Attack on Titan: Silhouette mit ausgebreiteten Armen über Wolken, Logo unten mittig im Bild (3840×2160, mittig auf 16:10 geschnitten, 2026-10-09) – Thema „mond“; ohne Maske
    ├── mond-naruto.jpg   ← Naruto mit Supreme-Maske vor nächtlicher Neon-Stadt (Vorlage nur 236×236 → mit Lanczos auf 1800×1800 hochgerechnet, mittig auf unscharfem, abgedunkeltem Hintergrund 2880×1800, 2026-10-12; sehr weich) – Thema „mond“; ohne Maske
    ├── purpur-kirschbaum.jpg ← surrealer Kirschbaum am Wasser (5120×2880) – Thema „purpur“
    ├── silber-band.jpg    ← schwarzes Band auf Schwarz (Microsoft Surface, 5120×3200) – Thema „silber“
    ├── silber-goku.jpg    ← Goku mit weisser Aura, fast schwarz (5120×2880) – Thema „silber“
    │                        (diese 7 vom Benutzer aus ~/downloads/wallpaper, 2026-10-09)
    ├── kohle-feuerwache.jpg ← Firewatch-Stil: Wanderer auf Fels, gelbe Sonne, Anthrazit (wallhaven mdjrqy, 5120×2880) – Thema „kohle“
    │                        Die neuen Bilder haben noch keine Maske (bleiben auch mit Super+Shift+W still).
    │                        **Der Anfang des Dateinamens bis zum ersten „-“ ist das Farbthema** (siehe „Farbthemen“).
    │                        Neue Bilder: auf 2880×1800 zuschneiden (16:10, wie der Bildschirm), z. B.
    │                        `magick in.jpg -resize 2880x1800^ -gravity center -extent 2880x1800 -strip -quality 92 golden-<name>.jpg`
    ├── aussortiert/       ← nicht mehr im Wechsel (Unterordner → wallpaper.sh ignoriert ihn):
    │                        golden-meadow.jpg + masken/golden-meadow.{png,json} – zurück: beides eine Ebene hoch schieben;
    │                        mond-wolken.jpg (Vollmond über Wolkenmeer, Cael Gibran, wallhaven 73rmme, Thema „mond“; 2026-10-09
    │                        auf Wunsch raus) – zurück: eine Ebene hoch schieben;
    │                        purpur-wolf.jpg (pinke Wüste mit Wolf, kvacm, wallhaven vgexwm, Thema „purpur“; 2026-10-09 raus)
    └── masken/            ← fürs lebendige Wallpaper (Unterordner → wallpaper.sh ignoriert ihn)
        ├── <name>.png     ← Maske pro Bild: R = Himmel, G = Wind (Stärke), B = Wasser
        │                    (fehlt sie, bleibt das Bild still; `qs log` meldet dann harmlos „Cannot open …/masken/<name>.png“)
        ├── <name>.json    ← optional Einstellungen, z. B. {"wind": -1} = Wind nach links
        └── quellen/       ← Python-Skripte, die die Masken erzeugen (gemeinsam.py, <name>.py, rauschen.py)

~/.config/quickshell/
├── shaders/
│   ├── wallpaper.frag     ← GLSL-Quelltext des Wallpaper-Shaders (Wolken, Wind, Wasser, Wolkenschatten)
│   ├── wallpaper.frag.qsb ← kompiliert mit qsb – DAS lädt Quickshell (nach Änderung neu kompilieren!)
│   └── rauschen.png       ← kachelbares Rauschen 256×256 (Böen, Wellen), erzeugt von masken/quellen/rauschen.py
```

## Wallpaper-Galerie (Super+W, `WallpaperGallery.qml`)
Overlay auf dem Bildschirm mit Fokus: alle Bilder als **Waben** (spitze Sechsecke) in einem Zickzack-Band – das aktive
(mit Stern) vorne links, dann **zuletzt genutzt** zuerst, nie benutzte hinten nach Name. Ist das Band voll, geht es
darunter weiter (lückenloses Wabenmuster); die Wabengröße (max. 300 px) passt sich Anzahl und Bildschirm an.
- Pfeile ←/→, Tab, Mausrad = vor/zurück (im Band), ↑/↓ = ein Band hoch/runter, Maus drüber = wählen
- Enter / Leertaste / Klick = übernehmen (`wallpaper.sh <pfad>` → Farbthema wechselt mit), Esc / Super+W / Klick daneben = zu
- **Strg+Entf = gewähltes Bild löschen** → `wallpaper.sh weg <pfad>`: Bild + `masken/<name>.{png,json}` per `gio trash` in den
  Papierkorb (zurückholbar), raus aus dem Verlauf; war es aktiv, wird vorher das zuletzt davor genutzte gesetzt; das letzte
  Bild wird nie gelöscht. Galerie bleibt offen und liest neu ein.
- Rand der gewählten Wabe = Akzentfarbe **ihres** Themas; darunter Name (Dateiname ohne Themen-Präfix) + Thema
- Reihenfolge aus `~/.local/state/8155/wallpaper-verlauf` (ein Pfad pro Zeile, neuestes oben; schreibt `wallpaper.sh` bei
  jedem Wechsel). Gelesen wird beim Öffnen per `Process` (aktives Bild, Verlauf, `find` im Ordner) – neue Bilder sind sofort drin.
- Waben: `MultiEffect`-Maske (Sechseck als `Shape`) über dem `Image` (`sourceSize` = Vorschaugröße, nicht 2880×1800 dekodieren);
  Maus-Treffer nur in der Wabe (`containmentMask` = Umriss-`Shape` mit `FillContains`), weil sich die Rechtecke überlappen.
- Holt sich die Tastatur (`Exclusive`) – beim Testen also nicht öffnen, während jemand tippt (Tasten landen in der Galerie,
  Leertaste übernimmt!). Gefahrlos testen: Kopie mit Stub-`Ui.qml` in einem verschachtelten Hyprland (`docs/testen.md`).
- IPC: `qs ipc call gallery toggle|open|close`. Layer-Regel: Blur + `no_anim` (blendet selbst ein, 180 ms).

## Farbthemen (golden / glut / kohle / purpur / mond)
Zu hellen Bildern passt Amber/Gold, zu rot-schwarzen Glutrot, zu Anthrazit Sonnengelb, zu Neon-Violett Pink, zu blauen
Nachtbildern Mondlicht-Blau. Das Thema hängt am Wallpaper:
`wallpaper.sh` nimmt den Dateinamen-Anfang (`golden-castle.jpg` → `golden`, `glut-finsternis.jpg` → `glut`; unbekannt → `golden`)
und ruft bei einem Wechsel `scripts/thema.sh <name>` auf. Von Hand: `thema.sh glut` (ohne Argument: zeigt das aktive Thema).
`silber` (Silberweiß auf Schwarz: accent `#cfd6df`, soft `#eef1f5`, deep `#6b7684`, cream `#eceef1`, ink `#0c0d0f`,
Glas (0.06, 0.065, 0.075)) für schwarz-graue Bilder.

| | golden | glut | kohle | purpur | mond |
|---|---|---|---|---|---|
| Akzent (`accent`) | `#e3a142` | `#ef5a50` | `#e8a21c` | `#f2508a` | `#8cc0e4` |
| `accentSoft` (Sterne, Cursor) | `#f2c57c` | `#fdb59a` | `#f5c867` | `#f3b0d6` | `#cfe3f1` |
| `accentDeep` (Textauswahl) | `#b8792b` | `#9e2f34` | `#a8740f` | `#8f1f5a` | `#4b7aa3` |
| `cream` | `#ede6d6` | `#ece5e3` | `#e8e6e1` | `#f0e6ef` | `#e3ebf2` |
| `muted` / `faint` | `#aab0aa` / `#7d8680` | `#ada4a6` / `#776d70` | `#a9a8a4` / `#74736f` | `#b5a3b6` / `#7c6b80` | `#a2afbc` / `#6e7d8c` |
| `ink` | `#12181e` | `#0d0b10` | `#121212` | `#12071a` | `#0b1219` |
| `red` (Warnung, Akku leer) | `#e0714f` | `#ffb054` | `#e0714f` | `#ffb054` | `#e0714f` |
| Glas-Grundton | (0.07, 0.09, 0.11) | (0.07, 0.055, 0.07) | (0.08, 0.08, 0.085) | (0.08, 0.03, 0.11) | (0.04, 0.07, 0.11) |

`red` ist bei glut und purpur orange, weil der Akzent dort schon rot/pink ist.

`thema.sh <name>` schaltet alles um:
- Symlink `~/.config/hypr/themen/aktiv` → `<name>` (Ordner `themen/<name>/` mit `hyprlock.conf`, `mako`, `rofi.rasi`, `kitty.conf`)
- Quickshell: `qs ipc call theme set <name>` → `Theme.qml` (Paletten dort, Farben blenden 1,1 s über – zusammen mit dem Bild)
- Hyprland: `hyprctl eval "golden.apply_theme('<name>')"` (Fensterrand, Glühen, Hintergrund; Paletten in `hyprland.lua`)
- mako: `makoctl reload` · kitty: `pkill -USR1 -x kitty` (lädt die Konfiguration neu) · rofi und hyprlock lesen `themen/aktiv` bei jedem Start
- Beim Start der Sitzung lesen alle den Symlink `themen/aktiv` – er muss also zum Bild in `current` passen (macht `wallpaper.sh`).

**Neues Thema** (z. B. für ein weiteres dunkles Bild mit anderer Stimmung): Ordner `themen/<name>/` aus einem vorhandenen kopieren
und Farben anpassen, Palette in `Theme.qml` (`palettes`) und `hyprland.lua` (`palettes`) ergänzen, Bild `<name>-<bild>.jpg` nennen.
**Neues Bild in einem vorhandenen Thema:** einfach `glut-<name>.jpg` bzw. `mond-<name>.jpg` nennen.

## Lebendiges Wallpaper (`Wallpaper.qml` + `WallpaperScene.qml` + `shaders/wallpaper.frag`)
Ein GPU-Shader bewegt Teile des Standbilds – kein Video. **Super+Shift+W** schaltet an/aus (Hinweis über `ModeOsd`),
Stärke blendet 1,5 s weich über; aus = normales `Image`, der Shader läuft dann gar nicht.
- **Maske pro Bild** `wallpapers/masken/<name>.png` (gleiche Größe wie das Bild, RGB, kein Alpha):
  **R = Himmel** (Wolken ziehen mit dem Wind + quellen leicht; direkt an Bergkanten bleibt der Himmel stehen,
  damit kein Berg in den Himmel gezogen wird), **G = Wind** (Gras, Baumkronen, Stoff; Wert = Stärke, vorne/oben stärker),
  **B = Wasser** (Kräuseln + dezentes Glitzern). Dazu schwache Wolkenschatten, die über alles außer Himmel ziehen.
  Kein Maske → Bild bleibt still. Die Maske wird über den **echten** Pfad gesucht (`readlink -f`, da `current` ein Symlink ist).
- `<name>.json` optional: `{"wind": 1}` = Wind nach rechts (Standard), `-1` = nach links.
- **Neue Maske machen:** Koordinaten im Bild ablesen (Raster-Ausschnitte), Skript nach Vorbild von
  `masken/quellen/golden-valley.py` schreiben (Polygone, `grabcut()` für saubere Himmelskanten, `baeume()` für Kronen),
  ausführen mit einem venv: `python3 -m venv /tmp/v && /tmp/v/bin/pip install numpy opencv-python-headless`,
  dann `cd masken/quellen && /tmp/v/bin/python <name>.py vorschau.png` (Vorschau: rot/grün/blau über dem Bild).
- **Masken-Pfad:** `WallpaperScene.resolvePath()` setzt den `readlink`-Befehl selbst (nicht per Binding) – sonst lief der Prozess
  manchmal noch mit dem alten Pfad, und das Bild nach `golden-valley` bekam dessen Maske (verschobenes Doppelbild, behoben 2026-10-08).
- **Uhr:** `Wallpaper.qml` zählt `time` mit 30 Bildern/s von 0 bis 2000 s, dann nahtlos von vorn. Jeder Zeit-Faktor
  im Shader × 2000 muss ganzzahlig sein. Pausiert, solange `strength` 0 ist oder auf dem Bildschirm ein Vollbild-Fenster
  offen ist (`HyprlandWorkspace.hasFullscreen`).
- **Shader ändern:** `cd ~/.config/quickshell/shaders && /usr/lib64/qt6/bin/qsb --qt6 -o wallpaper.frag.qsb wallpaper.frag`.
  **Fallstrick:** GLSL-reservierte Namen (`imageSize`, `noise`, `texture` …) benennt qsb still um (`_imageSize`) –
  dann kommt der Wert aus QML nie an (bleibt 0). Nach dem Kompilieren mit `qsb -d wallpaper.frag.qsb` prüfen.
  Uniform-Typen: `vector2d` statt `size` benutzen.
- **Sicherheit:** Gespeichert wird „an“ erst nach 60 s Laufzeit (`Ui.qml`). Hängt die Grafik direkt nach dem
  Einschalten, startet die nächste Sitzung still.
- **Testen nur mit Software-Rendering**, siehe `docs/testen.md` – nicht mit `grabToImage` auf der echten GPU.
