# Weitere Programme & System

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.
Plugins: `docs/plugins.md` · Songtexte/yt-dlp: `docs/musik.md` · GRUB-Bootmenü: `docs/grub.md`.

| Programm | Konfiguration / Zweck |
|---|---|
| hypridle | 4 min abdunkeln (10 %) → 5 min sperren → 5,5 min Bildschirm aus → 30 min Bereitschaft |
| hyprlock | Sperrbildschirm, auch direkt nach dem Booten (siehe „Anmeldung“): Wallpaper (`wallpapers/current`) geblurrt, „★ 8155“ (Cormorant kursiv 42, `lnum`), große Uhr, Datum, Passwortfeld, aktueller Song. Farben per `source =` aus `themen/aktiv/hyprlock.conf` (Variablen `$akzent`, `$uhrfarbe` …, auch `$helligkeit`) |
| mako | Benachrichtigungen oben rechts, 6 s; Farben per `include=` aus `themen/aktiv/mako` (`thema.sh` → `makoctl reload`) |
| rofi | App-Starter, Power-Menü, WLAN (wifi.sh), Zwischenablage; Farben per `@import` aus `themen/aktiv/rofi.rasi` |
| kitty | Terminal, `smart_paste.py` für Strg+V; Grundfarben/Auswahl/Cursor/Tabs per `include` aus `themen/aktiv/kitty.conf` (`thema.sh` → `pkill -USR1 -x kitty` lädt neu), ANSI-Farben fest in kitty.conf |
| hyprshot | Screenshots → `~/bildschirmfotos` |
| cliphist | Zwischenablage-Verlauf (Text + Bilder) |
| blueman-applet | Bluetooth-Agent (für Kopplungs-Anfragen) |
| hyprpolkitagent | Passwort-Dialoge (auch für `pkexec`) |
| brightnessctl, wpctl, playerctl | Helligkeit, Lautstärke, Medien |
| hyprsunset 0.4 | Blaulichtfilter für den Nachtmodus; gesteuert von `NightLight.qml` (`hyprctl hyprsunset …`) |
| tuned + tuned-ppd | Energieprofile (stellt die PowerProfiles-D-Bus-Schnittstelle bereit; `tuned-adm active` zeigt das Profil) |

## Anmeldung (GDM + hyprlock)

GDM (`gdm.service`) meldet **automatisch** an (`/etc/gdm/custom.conf`: `AutomaticLoginEnable=True`, `AutomaticLogin=edu`) –
in die zuletzt gewählte Session (AccountsService `/var/lib/AccountsService/users/edu` → `Session=hyprland`). Das Passwort
verlangt erst der **8155-Sperrbildschirm**: `hyprlock` ist die erste Zeile im Autostart von `hyprland.lua` (seit 2026-10-08).
Stürzt hyprlock ab, bleibt Hyprland trotzdem gesperrt (Session-Lock-Protokoll). Wird GNOME gewählt, sperrt
`~/.config/autostart/8155-gnome-sperren.desktop` (`OnlyShowIn=GNOME`) → `scripts/gnome-sperren.sh` (D-Bus
`org.gnome.ScreenSaver.Lock`, bis zu 20 s Wiederholung) – unter GNOME noch nicht ausprobiert.
Nachteil der Autoanmeldung: Der GNOME-Schlüsselbund wird nicht per PAM entsperrt (`/etc/pam.d/hyprlock` → `login` hat kein
`pam_gnome_keyring`). Stattdessen GDM-Passwort: `AutomaticLoginEnable=False` + hyprlock-Zeile raus (Sicherung der Datei:
`~/.cache/golden-backups/gdm-custom.conf.vor-passwort-20261008`). **Nie `systemctl restart gdm`** in der laufenden Sitzung.

## PipeWire + WirePlumber 0.5

Ton. Eigene Regeln in `~/.config/wireplumber/wireplumber.conf.d/`: `51-disable-suspension.conf` + `disable-suspend.conf` (ALSA-Ausgänge nie schlafen legen – doppelt, gleiche Wirkung), `52-dock-spdif-niedrig.conf` (S/PDIF-Ein-/Ausgang **aller** DisplayLink-Docks Priorität 100 statt 1108/2108 – sonst geht der Ton beim Andocken an den leeren Digitalausgang und man hört nichts). Bevorzugter Ausgang = Kopfhörer **WH-CH720N** (Bluetooth); nicht verbunden → interne Lautsprecher (Verlauf in `~/.local/state/wireplumber/default-nodes`, `….sink` = bevorzugt, `….sink.0` = nächster). Ausgang wechseln: `wpctl status` + `wpctl set-default <id>` oder `pavucontrol` – das Kontrollzentrum hat **keine** Ausgangswahl. Regeln wirken erst nach `systemctl --user restart wireplumber`.
Eigene PipeWire-Einstellungen in `~/.config/pipewire/`: `pipewire.conf.d/99-force-quantum.conf` (feste Blockgröße 4096 = 85 ms), `pipewire-pulse.conf.d/custom.conf` (`pulse.min.quantum` 4096), `pipewire.conf.d/10-bluetooth.conf` (wirkungslos – `bluez5.*` gehört in WirePlumber). **Ton stockt überall (Bluetooth und Lautsprecher) → zuerst die Systemuhr prüfen** (siehe „Systemuhr“): PipeWire taktet alles nach ihr.

## Audiotreiber (Kernel)

Laptop **Lenovo Yoga 7 2-in-1 14IML9**, Meteor Lake, Codec Realtek ALC287. Das **eingebaute Mikrofon ist ein digitales Mikro (DMIC) am DSP** → geht nur mit dem **SOF**-Treiber (`snd_sof_pci_intel_mtl`, Firmware `alsa-sof-firmware`), nicht mit dem alten `snd_hda_intel` (dann gibt es nur den Mikro-Eingang der Kopfhörerbuchse, „nicht verfügbar“). `/etc/modprobe.d/audio_disable_powersave.conf` hatte seit 2025-12-24 `dsp_driver=1` (= alten Treiber erzwingen, Grund unbekannt) – seit 2026-10-06 auskommentiert, der Kernel wählt selbst. Prüfen: `lspci -k -s 00:1f.3` („Kernel driver in use“), `arecord -l`. Mit SOF heißen Karte/Ausgänge anders (`…platform-skl_hda_dsp_generic`, Profil „HiFi“). Zurück: Zeile wieder aktivieren + Neustart (Sicherung `~/.cache/golden-backups/audio_disable_powersave.conf.vor-sof-20261006`). `audio-disable-powersave.conf` + Kernel-Parameter `snd_hda_intel.power_save=0 …` gelten nur für den alten Treiber.

## DisplayLink 1.15.1 (Dock)

Treiber fürs Dock (`17e9:6000`): RPM `fedora-43-displaylink-*.x86_64.rpm` von [displaylink-rpm](https://github.com/displaylink-rpm/displaylink-rpm/releases) (kein Repo → **Updates von Hand**: neues RPM laden, `dnf install ./…rpm`). Kernelmodul `evdi` per **DKMS** (`dkms status`), wird bei neuen Kerneln automatisch gebaut (`40-dkms.install`, `dkms.service`). **Secure Boot ist an** → DKMS signiert mit `/var/lib/dkms/mok.key`; der Schlüssel `/var/lib/dkms/mok.pub` („DKMS module signing key“) muss als MOK angemeldet sein (`mokutil --test-key /var/lib/dkms/mok.pub`). Ohne angemeldeten Schlüssel: `Loading of module with unavailable key is rejected`. Ablauf: udev-Regel `/etc/udev/rules.d/99-displaylink.rules` startet beim Einstecken `displaylink-driver.service` (`modprobe evdi` + `DisplayLinkManager`) → neue DRM-Karte (evdi) → Hyprland/aquamarine nimmt sie im laufenden Betrieb auf (Multi-GPU-Blit über die Intel-GPU). Anordnung/Auflösung der Dock-Monitore: App „Bildschirme“ → `monitors.lua`. Prüfen: `systemctl status displaylink-driver`, `lsmod | grep evdi`, `hyprctl monitors all`, Log `/var/log/displaylink/`.

## nwg-displays 0.4.4 („Bildschirme“)

GUI zum Anordnen der Monitore ([GitHub](https://github.com/nwg-piotr/nwg-displays)), schreibt `~/.config/hypr/monitors.lua` (siehe `docs/hyprland.md` → Aufbau, Punkt 2). Nicht in Fedora → Quelltext (reines Python, GTK3) in `~/.local/opt/nwg-displays/nwg_displays`, Starter `~/.local/bin/nwg-displays` (setzt `sys.path`, kein pip nötig), Desktop-Eintrag `~/.local/share/applications/nwg-displays.desktop` (Name „Bildschirme“, im App-Starter auch unter Monitor/Display/Dock), Symbol `~/.local/share/icons/hicolor/scalable/apps/nwg-displays.svg`, Einstellungen `~/.config/nwg-displays/config` (`use-desc: true`). Braucht `python3-gobject`, `gtk3`, `gtk-layer-shell`, `python3-i3ipc` (alle installiert). Oberfläche englisch (keine deutsche Übersetzung). Hat auch Profile (z. B. „Dock“/„unterwegs“). Ihre `hyprctl dispatch dpms …`-Aufrufe sind alte Syntax und wirken unter Lua nicht – egal. Update: neues Release-Archiv laden, Ordner `nwg_displays` ersetzen, `VERSION` anpassen.

## Windows-Partition

Dualboot: `nvme0n1p3` „Windows-SSD“ (NTFS, 805 GB, **kein BitLocker**, UUID `DA44DC9944DC79A9`). In `/etc/fstab` mit `ntfs-3g` nach **`/mnt/windows`**, Optionen `uid=1000,gid=1000,umask=022,windows_names,hide_hid_files,noatime,nofail,x-systemd.automount,x-systemd.idle-timeout=10min,x-systemd.device-timeout=5s,x-gvfs-show,x-gvfs-name=Windows` → wird beim ersten Zugriff ohne Passwort eingehängt, nach 10 min ohne Zugriff wieder ausgehängt, Boot wartet nie darauf. Link **`~/Windows`** → `/mnt/windows`; Benutzerordner `~/Windows/Users/eduar` (Desktop, Documents, Downloads, OneDrive). `windows_names` verhindert Dateinamen, die Windows nicht kann. `hide_hid_files`: in Windows versteckte Dateien (Attribut hidden, z. B. `desktop.ini`, Office-Sperrdateien `~$…`, `NTUSER.DAT`, `AppData`) sind unter Linux **gar nicht** gelistet (auch nicht mit Strg+H), per vollem Pfad aber erreichbar (Strg+L → `~/Windows/Users/eduar/AppData`). Attribute prüfen: `getfattr --only-values -n system.ntfs_attrib_be <datei> | od -An -tx1` (0x02 = versteckt, 0x04 = System). Neue Mount-Optionen greifen erst nach dem Aushängen (`systemctl stop mnt-windows.mount`, geht nur, wenn kein Programm drin ist). **Fallstricke:** Windows im Schnellstart/Ruhezustand heruntergefahren → `ntfs-3g` verweigert das Einhängen (`~/Windows` meldet Fehler) – in Windows „Neu starten“ statt „Herunterfahren“ oder Schnellstart aus; OneDrive-Dateien „nur online“ sind nur Platzhalter und lassen sich unter Linux nicht öffnen. Prüfen: `pkexec ntfs-3g.probe --readwrite /dev/nvme0n1p3` (0 = ok). Sicherung der alten fstab: `/etc/fstab.vor-windows-<datum>`. `findmnt --verify` warnt bei ntfs-3g (FUSE) – harmlos.

## Systemuhr (chrony, Dualboot)

Die Hardware-Uhr (RTC) läuft wegen Windows in **Ortszeit** (`timedatectl`: „RTC in local TZ: yes“). Am 2026-10-08 sprang die Systemuhr beim Aufwachen aus dem Standby um genau 2 h vor; chrony durfte nur in den ersten 3 Abgleichen springen (`makestep 1.0 3`) und bremste die Uhr deshalb mit maximal 8,3 % ab (hätte ~1 Tag gedauert) → ganzes Audio-Timing falsch (Bluetooth: 2 s Ton / 1 s Pause, Lautsprecher: XRun alle 0,85 s). Seitdem in `/etc/chrony.conf` **`makestep 1.0 -1`** → bei > 1 s Abweichung springt chrony immer sofort. Von Hand korrigieren: `pkexec chronyc makestep`. Prüfen: `chronyc tracking` („System time“ muss Bruchteile einer Sekunde sein), `journalctl -u chronyd | grep wrong`. Saubere Alternative (nicht gemacht): RTC auf UTC (`timedatectl set-local-rtc 0`) + in Windows Registry `RealTimeIsUniversal=1`.

## Explorer-Modus (Nautilus)

`scripts/explorer-modus.py`, Dienst aus dem Autostart (eine Instanz, Lock `$XDG_RUNTIME_DIR/explorer-modus.lock`). Seitenleisten-Lesezeichen wechseln je nach **aktivem Tab**: Ordner unter `/mnt/windows` oder `~/Windows` → Windows-Satz, sonst Linux-Satz. Erkennung: Tabs aller Fenster über D-Bus `org.freedesktop.FileManager1` → `OpenWindowsWithLocations` (ohne Angabe, welcher aktiv ist) + Hyprland-socket2 (`activewindow`, `activewindowv2`, `windowtitlev2`; Titel = Ordnername des aktiven Tabs). Regeln: alle Tabs gleiche Welt → diese; ein Tab hat gerade navigiert → dessen Welt (dann **nicht** nach dem Titel gehen, der kommt oft erst danach); sonst Tabs, deren Anzeigename/Ordnername/Mount-Name (`/mnt/windows` = „Windows“) zum Titel passt; zweideutig (z. B. beide „Videos“) → bleibt. Nur wenn Nautilus das aktive Fenster ist. Nautilus zu (keine Tabs) bzw. beim Start ohne Nautilus → Linux (Datei-Dialoge anderer Apps lesen dieselbe Datei). Lesezeichen: `~/.config/gtk-3.0/bookmarks` wird ausgetauscht (Nautilus lädt sie sofort neu); Sätze in `~/.local/state/8155/lesezeichen-{linux,windows}`, beim Wechsel wird der aktuelle Inhalt erst in den alten Satz zurückgeschrieben → im Modus angelegte/gelöschte Lesezeichen bleiben. Windows-Satz (Pfade über `~/Windows/…`): **windows** = direkt `~/Windows/Users/eduar`, desktop, dokumente, downloads, bilder, musik, videos (`WIN_DEFAULT`); C: selbst über den Laufwerk-Eintrag „Windows“ unten in der Seitenleiste (x-gvfs-show). Die festen Einträge der Seitenleiste (Persönlicher Ordner, Papierkorb, Laufwerke …) kommen von Nautilus/GTK und wechseln **nicht**. Neu starten: `pkill -f '^python3 .*explorer-modus.py'` + `hyprctl dispatch 'hl.dsp.exec_cmd("~/.config/hypr/scripts/explorer-modus.py")'` (Achtung: `pkill -f` mit dem nackten Pfad trifft auch die eigene Shell).

## Outlook (Noser Young)

Geschäfts-Mail (Microsoft 365; Adresse steht nicht hier, weil die Doku öffentlich im Git liegt). Outlook im Web als eigenes Brave-App-Fenster (`--app`) mit **eigenem Profil** `~/.local/share/outlook-noseryoung` (Anmeldung kollidiert nicht mit anderen Microsoft-Konten im normalen Brave, bleibt gespeichert). Desktop-Eintrag `~/.local/share/applications/outlook-noseryoung.desktop` (Name „Outlook“, Symbol `ms-outlook`), Fensterklasse `brave-outlook.office.com__mail_-Default` = `StartupWMClass` → Taskleiste findet das Symbol. `--class` wirkt unter Wayland nicht. Benachrichtigungen nur, solange das Fenster offen ist. Im Exec muss die URL in Anführungszeichen stehen (`?` ist reserviert).

## Clawd on Desk 1.2.0

Desktop-Pet, das Claude-Code-Sessions anzeigt ([GitHub](https://github.com/rullerzhou-afk/clawd-on-desk)). Entpacktes AppImage in `~/.local/opt/clawd-on-desk`, Starter `~/.local/bin/clawd-on-desk` (`--no-sandbox`; **kein Autostart mehr**, nur per Hand/rofi starten), Desktop-Eintrag `~/.local/share/applications/clawd-on-desk.desktop`. Startet sich selbst unter XWayland neu (sonst nicht ziehbar). Trägt beim Start seine Hooks in `~/.claude/settings.json` ein (Zustands-Server `127.0.0.1:23333`) – **am 2026-10-13 alle 15 Hooks entfernt**
(Clawd wird nicht mehr benutzt; Sicherung `~/.claude/settings.json.vor-clawd-hooks-entfernt-*.bak`). Wird Clawd wieder gestartet, trägt es sie neu ein.
Die Fensterregel `clawd-on-desk-pet` und `Ui.skipWindow()` sind noch da, tun aber ohne Clawd nichts. Kein Auto-Update: neues AppImage mit `--appimage-extract` entpacken und den Ordner ersetzen.

## NOA-Entwicklungsumgebung (Super+Shift+D)

`scripts/noa-start.sh`: `podman start noadb` (Postgres, wartet auf `pg_isready`), dann **ein** kitty-Fenster (Klasse `noa-dev`)
mit Tab „backend“ (`gradlew bootRun`) und Tab „frontend“ (`npm start`, kein yarn installiert), danach IntelliJ (Flatpak,
öffnet `noabackend`). Läuft ein Teil schon (Port 8080 / 3000 belegt **oder** der Gradle-/vite-Prozess ist da, IntelliJ offen),
wird er übersprungen; ein zweiter Druck während das Skript noch läuft tut nichts (`flock` auf `$XDG_RUNTIME_DIR/noa-start.lock`,
das Skript wartet bis zu 10 s, bis die Prozesse sichtbar sind). Am Ende meldet
eine Benachrichtigung „gestartet: …“ / „lief schon: …“ (alles schon da: „NOA läuft schon“). Die Tabs entstehen
über eine kitty-Sitzungsdatei in `$XDG_RUNTIME_DIR`; `--hold` lässt sie bei Fehlern offen.
**Fallstrick:** Java 25 ist Standard, Gradle 8.14 läuft darauf nicht → das Skript setzt `JAVA_HOME=/usr/lib/jvm/java-21-openjdk`
nur für den Backend-Tab. Keycloak lokal wird nicht gestartet (`KEYCLOAK_ENABLED=false` in `noabackend/.env`).

## Pakete & Quellen

**Pakete/Quellen:** Hyprland-Ökosystem aus COPR `sdegler/hyprland` (auch `hyprland-devel` für Plugins), Quickshell aus COPR `errornointernet/quickshell`.
`qt6-qtshadertools` (Fedora) liefert `/usr/lib64/qt6/bin/qsb` zum Kompilieren der Shader.
`sudo` braucht ein Passwort → für Root-Befehle aus einer KI-Sitzung `pkexec …` benutzen (grafischer Passwort-Dialog).
`zoxide` (Fedora, `z <ordnerteil>` / `zi`): Einrichtung in `~/.bashrc.d/zoxide.sh` (die `.bashrc` liest `~/.bashrc.d/` ein).
`fzf` ist als Abhängigkeit dabei, seine Tastenkürzel (Strg+R/T, Alt+C) sind **nicht** aktiv – dafür müsste
`/usr/share/fzf/shell/key-bindings.bash` eingebunden werden.

## Bekannte Baustelle (nicht vom Desktop)

Kernel `6.19.12` ist als Paket installiert, hat aber **keinen Boot-Eintrag** (kein `vmlinuz` in `/boot`). Darum schlägt
`dracut --regenerate-all --force` (`post_transaction` in `/etc/dkms/framework.conf`) jedes Mal fehl:
`Can't write to /boot/efi/<machine-id>/6.19.12…` – harmlos, die bootbaren Kernel bekommen ihre initramfs trotzdem.
Seit es 7.2.9 gibt, wird 6.19.12 nicht mehr gebraucht → loswerden mit `sudo dnf remove kernel-core-6.19.12-200.fc43`.

**Erledigt 2026-10-08:** Ein abgebrochenes Update vom 2026-04-26 hatte 211 Pakete doppelt in der Paketdatenbank hinterlassen
(daher auch 6.19.12 ohne Boot-Eintrag). `dnf remove --duplicates` gibt es in dnf 5 nicht, `dnf upgrade` scheiterte an
Dateikonflikten der i686-Pakete mit den alten x86_64-Einträgen. Gelöst mit
`rpm -e --justdb --nodeps --noscripts --notriggers $(dnf repoquery --installed --duplicates --latest-limit=-1 -q | sed -E 's/-[0-9]+:/-/')`
+ `dnf upgrade --refresh` → Kernel **7.2.9** (evdi per DKMS gebaut + signiert). Sicherung der alten Paketdatenbank:
`/var/lib/rpmdb-sicherung-20261008-*.tar.gz` (kann weg, wenn alles läuft). Prüfen: `dnf check`, Duplikate:
`rpm -qa --qf '%{NAME}.%{ARCH}\n' | sort | uniq -d`.


## iPhone spiegeln & bedienen (UxPlay + Bluetooth-HID)

**Anzeige:** Paket `uxplay` (AirPlay-Mirroring-Empfänger, GPLv3), User-Dienst `~/.config/systemd/user/uxplay.service`
(`-n 8155-Laptop -vs waylandsink -fps 60`, gestartet über `scripts/iphone-uxplay.sh`: zeilenweise Ausgabe + Passwort `-pw`). Wird **nicht** automatisch gestartet – sonst ist der Laptop dauernd
AirPlay-Ziel im Netz. Ein/Aus: **Super+Shift+A**, Kachel „iphone spiegeln“ im Kontrollzentrum (`Iphone.qml`) oder
`scripts/iphone.sh an|aus|toggle|status`. Verbinden: iPhone → Kontrollzentrum → Bildschirmsynchronisierung → „8155-Laptop“;
am iPhone das **Passwort** eingeben (steht in der Benachrichtigung beim Einschalten, später: `scripts/iphone.sh passwort`;
Datei `~/.local/state/8155/iphone-passwort`, 8 Zeichen, zufällig, nicht im Git). **`-pin` nicht verwenden:** UxPlay 1.73.7 lehnt
den 20-Byte-SRP-Beweis des iPhones ab (`client_proof_len 20 invalid`, Prüfung auf 64 Byte in `lib/raop_handlers.h`) → PIN-Fenster
kommt immer wieder; `-pw` nutzt HTTP-Digest und umgeht das. Bei neueren UxPlay-Versionen erneut mit `-pin` probieren.
Netz: **kein Gast-WLAN mit Client-Isolation** (mDNS erreicht das iPhone nicht) – der Persönliche Hotspot des iPhones geht. Firewall: Dienst `mdns` (5353/udp) in
der Zone FedoraWorkstation freigegeben (sonst findet das iPhone den Empfänger nicht), die Datenports liegen im offenen Bereich 1025–65535.
Fensterregel `iphone-spiegel` (Klasse `uxplay`, schwebend 420×910) – Klasse beim ersten echten Spiegeln mit `hyprctl clients -j` prüfen.
Debuggen: `journalctl --user -u uxplay`, `avahi-browse -rt _airplay._tcp`; bei Flackern/Schwarz `-vs glimagesink`.

**Bedienung** (AirPlay ist eine Einbahnstrasse, das Bild gibt keine Eingaben zurück): Der Laptop gibt sich per BlueZ als
Bluetooth-LE-HID-Gerät „8155-Laptop-HID“ aus (HID over GATT, Dienst `iphone-hid.service`, Skript `iphone-hid.py`).
**Nur-LE-Modus während der Steuerung:** Der Adapter ist Dual-Mode (Classic + LE auf derselben Adresse). Ein sichtbarer Adapter
liess das iPhone über Classic koppeln (btmon: BR-ACL, Passkey-Abfrage, nach ~30 s `Authentication Failure`; dort gibt es kein
HID-Profil); nur die LE-Werbung als auffindbar (Flags 0x06, per btmon geprüft) reichte iOS nicht, das Gerät tauchte gar nicht auf.
Deshalb ruft `iphone.sh steuern` per **pkexec** (ein Passwort-Dialog) `scripts/iphone-le.sh <pid> <irk>` auf: Adapter aus →
`bredr off` → `privacy on <irk>` (wechselnde Zufallsadressen, fester IRK in `~/.local/state/8155/iphone-irk`) → an; sobald das
Steuerfenster zu ist (oder der Helfer beendet wird) zurück: `privacy off`, `bredr on`, **`ssp on`** (BR/EDR aus löscht SSP mit).
**Keine statische Adresse** (`static-addr`): sie wird zur Identität der LE-Verbindung, bluetoothd lauscht für GATT aber auf der
öffentlichen Adresse → das iPhone bekam auf „Exchange MTU“ keine Antwort, der Kernel trennte nach 4 s (btmon, 2026-10-14). **Solange gesteuert wird, gehen klassische Geräte (Kopfhörer WH-CH720N) nicht.**
Eine polkit-Regel für passwortloses Umschalten wurde bewusst nicht angelegt. Erst danach startet `iphone-hid.service`.
Der Dienst registriert einen eigenen BlueZ-Agenten (`NoInputNoOutput`, Just Works), setzt während er läuft den Alias
„8155-Laptop-HID“ (= GAP-Gerätename) und protokolliert Verbinden/Koppeln/Abonnieren im Journal (`journalctl --user -u iphone-hid`).
Geräteinformation (PnP-ID) liefert BlueZ selbst (DeviceID in der EIR) – kein eigener 180A-Dienst. Prüfen: `btmgmt info` (ohne Root)
→ „current settings“ ohne `br/edr`. Debuggen: `pkexec btmon -T > datei` mitschneiden, dabei am iPhone koppeln.
`iphone-steuern.py` (Super+Alt+A): **unsichtbares** SDL-Fenster (Fensterregel `iphone-steuern`, Deckkraft 0,02 – **bei 0 bekommt es in
Hyprland keine Maus**) liegt genau über dem
Spiegelfenster (`uxplay`, folgt per `hyprctl` alle 0,3 s; Super+Maus aufs Steuerfenster verschiebt das Spiegelbild mit).
Maus darüber → Laptop-Zeiger ausgeblendet, der iPhone-Zeiger folgt; Klick, Mausrad, Tastatur gehen ans iPhone; Super+Q beendet.
iOS kennt nur **relative** Mäuse mit Beschleunigung: beim Hineinfahren wird der Zeiger in die Ecke gedrückt (klemmt dort =
bekannte Position) und dann zur Maus gefahren (Schritte à 4 Einheiten, gemessen ~2 Punkte/Einheit, `GAIN`), danach relativ
nachgeführt; an den Rändern wird nachgedrückt. Kleine Abweichungen sieht man nicht – man führt den iPhone-Zeiger nach Sicht.
Bekommt das Spiegelfenster den Fokus (Klick, neue Spiegelung), rutscht es nach oben → das Steuerfenster holt sich dann den Fokus zurück.
Ohne Spiegelfenster wandert das Steuerfenster auf den Special-Workspace `iphone-steuern` (sonst finge es unsichtbar Klicks ab).
**WLAN:** Der Laptop fiel zweimal aus dem iPhone-Hotspot (Kernel: `missed beacons`) zurück ins Gast-WLAN → Spiegelung weg; am iPhone
Hotspot-Einstellungen öffnen und `nmcli connection up "iPhone (2)"`, dann neu spiegeln.
Achtung: der grosse graue Kreis im Spiegelbild ist der AssistiveTouch-Knopf, der Zeiger ist ein kleiner Punkt.
SDL statt evdev, weil der Benutzer nicht in der Gruppe `input` ist (kein Rechtegewinn nötig).
Einmalig am iPhone: Einstellungen → Bedienungshilfen → Tippen → AssistiveTouch **an**, dann Bluetooth → „8155-Laptop-HID“ koppeln.
Protokoll Fenster → Dienst: Unix-Datagramme an `$XDG_RUNTIME_DIR/iphone-hid.sock` (`m dx dy [rad]`, `b maske`, `k mods tasten…`).
Stand 2026-10-14: Kopplung mit iPhone 15 Pro Max (iOS 26) klappt, Bewegen und Klicken getestet (Klick per Socket, Spiegelbild per grim geprüft).

## AirDrop (omdrop + omdrop-owl)

Dateien/Bilder zwischen iPhone und Laptop per echtem AirDrop (AWDL), in beide Richtungen. Bedienung über die 󰀃-Kapsel in der
Leiste → `AirdropPanel.qml` (siehe docs/quickshell.md). OpenDrop (seemoo-lab) selbst ist veraltet; benutzt wird der Nachfolger:
- **CLI `omdrop`** (Python/Bash, MIT): Quelltext `~/.local/opt/omdrop-plugin` (git, github.com/brentkearney/omdrop-plugin – eigentlich
  ein Omarchy-Plugin, die CLI läuft aber allein). Symlink `~/.local/bin/omdrop`. Quickshell ruft sie **mit vollem Pfad** auf
  (Hyprlands PATH enthält `~/.local/bin` nicht). Wichtig: `omdrop on [min]`, `off`, `status --json`, `peers --json [-n --stream]`,
  `send --to MAC -- DATEIEN…`, `name`, `dir`. Empfänger = User-Dienst `airdrop-receiver.service` (Port 8771, nur während eines Fensters),
  Zeitfenster = Timer `omdrop-window`, Watcher `omdrop-watch` meldet jede angekommene Datei (kopiert sie auch in die Zwischenablage).
- **Funk-Teil `omdrop-owl`** (github.com/t4t5/omdrop-owl, GPL): OWL (Open Wireless Link, AWDL im Userspace) + Helfer. Quelltext
  `~/.local/opt/omdrop-owl`, gebaut mit `tools/build-rpm.sh` → RPM installiert nach `/usr/lib/omdrop` (+ polkit-Regel
  `allow_active=yes` → kein Passwort beim Ein-/Ausschalten, NetworkManager ignoriert `awdl0`/`mon0`/`awdlibss0`).
  Build-Abhängigkeiten: `rpm-build gcc gcc-c++ make libev-devel libpcap-devel libnl3-devel`.
- **Intel AX211 kann nur „exclusive“:** solange AirDrop an ist, ist das **WLAN getrennt** (AWDL läuft auf Kanal 6), danach verbindet
  `omdrop-discoverable` die vorige Verbindung wieder. Deshalb immer mit Zeitfenster (Panel: 10 min). Log der Root-Seite: `/run/omdrop-owl/log`,
  Check: `/usr/lib/omdrop/omdrop-discoverable probe --json`.
- Name für Apple-Geräte „8155-Laptop“ (`omdrop name`), Ziel **`~/airdrop`** (`omdrop dir`, schreibt Drop-in
  `~/.config/systemd/user/airdrop-receiver.service.d/10-download-dir.conf`). Identität: selbstsigniert in `~/.omdrop/keys` →
  iPhones sehen den Laptop nur, wenn sie selbst auf **„Für alle (10 Minuten)“** stehen bzw. beim Senden ans iPhone muss es so eingestellt sein.
- **Meldungen:** omdrop ruft `omarchy-notification-send` auf → Ersatz `scripts/airdrop-meldung.sh` (notify-send/mako, Klick öffnet die Datei),
  Symlink `~/.local/bin/omarchy-notification-send`; der Drop-in `~/.config/systemd/user/omdrop-watch.service.d/path.conf` legt
  `~/.local/bin` in den PATH des Watchers (systemd-User-PATH ist nur `/usr/local/bin:/usr/bin`; Drop-ins greifen auch bei `systemd-run`-Units).
- Firewall: nichts nötig, Zone FedoraWorkstation hat 1025–65535 offen (`omdrop firewall` ist nur für UFW).
- `omdrop doctor` meldet fälschlich fehlende Bibliotheken (sucht `/usr/lib/libkeyutils.so.1`, Fedora hat `/usr/lib64/…`) – harmlos.
- **Aktualisieren:** `git -C ~/.local/opt/omdrop-plugin pull` (CLI sofort aktiv); Funk-Teil: `git -C ~/.local/opt/omdrop-owl pull &&
  ~/.local/opt/omdrop-owl/tools/build-rpm.sh && pkexec dnf install ~/.local/opt/omdrop-owl/omdrop-owl-*.rpm`.
