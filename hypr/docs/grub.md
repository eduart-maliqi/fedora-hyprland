# GRUB-Bootmenü „ghost“ + Ladebildschirm (Dualboot)

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.

Beim Einschalten: GRUB-Menü im Stil von **Ghost of Tsushima** – Hintergrund = Wallpaper
`wallpapercave.com/wp/wp15726322.png` (Wunsch), Einträge links groß in **Cinzel** (Versalhöhe 105 px, Wunsch „schöner Font,
etwas kleiner“), gewählter Eintrag auf halb durchscheinendem Pinselstrich, Tastenhinweise unten rechts, **kein Countdown**. Nach FEDORA LINUX: schwarz
(wie im Spiel nach CONTINUE), dann Plymouth: dieselbe Szene, fallender Schnee, „LOADING“ (beim Herunterfahren ohne).
Bilder nur privat nutzen (Sucker Punch/Sony).

**Secure Boot ist an → GRUB lädt keine Schriften** („prohibited by secure boot policy“, auch nicht unicode.pf2). Darum:
jeder Eintrag ist ein **Bild** (`icons/<erste --class>.png`), der Titeltext ist im Theme unsichtbar (`#00000000`), und die
Auflösung steht in der **grubenv** (`gfxmode=2880x1800,auto`), weil Fedoras 00_header gfxmode nur im `if loadfont`-Zweig setzt.
Bis 2026-10-08 13:30 lief das Menü deshalb auf dem Laptop in Firmware-Auflösung mit 8×16-Notschrift („winzig, verpixelt“) –
die VM-Tests liefen damals ohne Secure Boot.

## Dateien

```
~/.config/hypr/grub-ghost/
├── wallpaper_bild.py    ← aus dem Wallpaper (~/.cache/grub-ghost/quelle/wallpaper.png, 3822×1600): theme/background.jpg,
│                          background_load.jpg, plymouth/szene.png; auf 1800 px Höhe, Katana bei 64 % der Breite
├── bilder.py            ← icons/ghost-*.png (Einträge als Bild: Cinzel 150, hell + weicher Schatten), Pinselstriche (55 %
│                          deckend), Tastenhinweise, „LOAD GAME“-Titel: `bilder.py theme Cinzel-Medium.ttf`
├── plymouth_bilder.py   ← plymouth/: Schnee, „LOADING“, Schwarz zum Einblenden, Dialogfeld
├── 15_ghost_menu        ← Vorlage für /etc/grub.d/15_ghost_menu: Einträge; LOAD GAME als feste Liste aus
│                          /boot/loader/entries, rendert dabei icons/ghost-k-<version>.png (python3 + Pillow, als root)
├── 95-ghost-menu.install← Kernel-Hook: nach Kernel-Installation/-Entfernung grub2-mkconfig (sonst fehlt er in LOAD GAME)
├── installieren.sh      ← `pkexec ~/.config/hypr/grub-ghost/installieren.sh > /tmp/ghost.log 2>&1` – alles ins System
├── rueckgaengig.sh      ← `pkexec …/rueckgaengig.sh > /tmp/ghost.log 2>&1` – alter Zustand aus *.vor-ghost-*
├── got_bild.py          ← früherer Hintergrund aus dem 1080p-Menüvideo (Schlüsselbild 5,07 s) – nicht mehr benutzt
├── hintergrund.py       ← erste, selbst gerechnete Szene – nicht mehr benutzt
├── Cinzel-Medium.ttf    ← Schrift (OFL, aus Cinzel[wght] per `fonttools varLib.instancer … wght=500`); als theme/schrift.ttf
│                          auch in /boot – 15_ghost_menu rendert damit die Kernel-Bilder. Jost-Regular.ttf = frühere Schrift
├── theme/               ← GRUB-Theme: theme.txt (Hauptmenü), load.txt (LOAD GAME), Bilder, icons/
├── plymouth/            ← Plymouth-Theme: ghost.plymouth, ghost.script, Bilder
└── test/                ← Test-VM (QEMU + OVMF, Fedoras echtes grubx64.efi): vm-bauen.sh, plymouth-test.sh, vm-lauf.py
```
numpy fehlt im System → venv `~/.cache/grub-ghost/venv` (numpy, fonttools): `~/.cache/grub-ghost/venv/bin/python bilder.py …`.

## Im System

- **GRUB:** Theme `/boot/grub2/themes/ghost/`, `/etc/grub.d/15_ghost_menu`, `/etc/kernel/install.d/95-ghost-menu.install`;
  `/etc/default/grub`: `GRUB_THEME=…/ghost/theme.txt`, `GRUB_GFXMODE=2880x1800,auto`, `GRUB_DISABLE_OS_PROBER=true`,
  `GRUB_TIMEOUT=-1`; grubenv: `gfxmode=2880x1800,auto`; `/etc/grub.d/10_linux` + `30_uefi-firmware` sind `chmod -x`.
- **Plymouth:** Paket `plymouth-plugin-script`, Theme `/usr/share/plymouth/themes/ghost/`, `/etc/plymouth/plymouthd.conf`
  = `Theme=ghost` + `DeviceScale=1`; das Theme steckt im initramfs (~64 MB) → kommt bei Kernel-Updates von selbst mit.
- **Einträge:** `FEDORA LINUX` (Untermenü mit `timeout=0` + `blscfg` → startet sofort den Standard-Kernel), `WINDOWS`
  (chainloader `bootmgfw.efi`, Id `osprober-efi-DEDC-28B7` → `grub2-reboot` geht weiter), `LOAD GAME` (feste Liste aller
  Kernel inkl. Rettungssystem, Theme `load.txt`), `OPTIONS` (UEFI, `fwsetup`), `QUIT GAME` (aus, `halt`).
- **Nie automatisch starten** (Wunsch): Menü wartet beliebig lange, auch bei Neustarts nach Updates.
- **Standard-Kernel:** `saved_entry` in grubenv (BLS-Id, pflegen grubby/kernel-install); 15_ghost_menu macht daraus
  `default="ghost-fedora>Id"` und überschreibt `savedefault`, damit die nackte Id gespeichert bleibt (grubby versteht nur die).

## Ändern & Testen

Bilder neu erzeugen (Befehle oben) → **immer mit Secure Boot testen:** `GHOST_SB=1 test/vm-bauen.sh` (oder
`GHOST_SB=1 test/plymouth-test.sh` mit Ladebildschirm) + `GHOST_SB=1 test/vm-lauf.py wait:12 shot:menu key:down shot:win`
(shim + MS-Schlüssel wie am Laptop; ohne `GHOST_SB` laden Schriften, die es am Laptop nicht gibt). Die VM findet kein Root,
Plymouth läuft ~90 s weiter. `GHOST_DEBUG=1 test/plymouth-test.sh` blendet refresh-Zähler + Uhr ein. `type:<text>` in
vm-lauf.py tippt (z. B. in der GRUB-Konsole `c`). Bilder: `~/.cache/grub-ghost-test/`. Dann `pkexec …/installieren.sh > /tmp/ghost.log 2>&1`.

## Fallstricke

- Secure Boot: keine Schriften (siehe oben) und nur eingebaute Module (regexp, blscfg, gfxmenu, jpeg, png, halt ja –
  `background_image`, `videoinfo` nein). `terminal_output console` → `gfxterm` zum Umschalten der Auflösung hängt unter SB
  im Textmodus → gfxmode nur über die grubenv. Die GRUB-Konsole (`c`, `e`) zeigt nur die 8×16-Notschrift (winzig).
- GRUB kann nichts animieren und den gewählten Eintrag ohne Schriften nicht umfärben → Text bleibt hell, der Strich ist nur
  55 % deckend (bei 100 % ist heller Text darauf kaum lesbar). GRUB leert vor jedem Start sein Konsolenfenster schwarz → bildschirmfüllend.
- Plymouth zeichnet auf der CPU: Vollbild-Ebenen mit Deckkraft (Nebel, Überblenden) drücken es auf ~20 Bilder/s → keine
  Dauer-Ebenen, Bilder in voller Auflösung, Zeit aus `SetBootProgressFunction` (echte Uhr). `DeviceScale=1`, sonst 1440×900.
- Bewegtes Gras aus Videobildern sah blockig aus und lief hin und zurück → entfernt (Wunsch).
- Ein angehängtes zweites cpio hinter dem zstd-initramfs übernimmt der Kernel nicht → in Tests `dracut --include`.
- `grub2-tools`-Update kann `10_linux`/`30_uefi-firmware` wieder ausführbar machen → doppelte Einträge → `installieren.sh`
  nochmal. `grub2-mkconfig` **mit** aktivem 10_linux schreibt die `options` aller BLS-Einträge neu.
- `fwsetup --is-supported` nie als eigene Zeile – ohne die Option startet das sofort die Firmware; wie Fedora `if [ … ]`.
- Ausgabe von `pkexec …/installieren.sh` **nie pipen** (SIGPIPE bricht mitten in grub2-mkconfig ab) → `> datei 2>&1`.
- `tr`-Zeichenklassen: `-` ans Ende (`'A-Za-z0-9._\n-'`), sonst Bereichsfehler → 15_ghost_menu bricht ab.
- Sicherungen: `/etc/default/grub.vor-ghost-20261008-*`, `/boot/grub2/grub.cfg.vor-ghost-20261008-*`,
  `/etc/plymouth/plymouthd.conf.vor-ghost-20261008-*`.
