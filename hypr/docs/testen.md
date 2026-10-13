# Testen & Fehlersuche

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.
Die Grundbefehle (`qs log`, `hyprctl configerrors`, Testfenster …) stehen im Kern.

**Shader/QML-Effekte testen – nur auf der CPU (llvmpipe)!** Am 2026-10-01 hat ein Test mit `grabToImage` auf der
Intel-GPU (Meteor Lake, i915) einen **GPU-Hang** ausgelöst (`GUC: TLB invalidation response timed out` → `GPU HANG`)
und damit Hyprland abgeschossen (Neustart nötig). Ursache vermutlich riesige Puffer: `grabToImage(…, Qt.size(w, h))`
rechnet die Skalierung 1.67 noch drauf (2880×1800 → 4800×3000). Darum eigene Testinstanz mit Software-Rendering:
```sh
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
  QSG_RHI_BACKEND=opengl qs -p /tmp/test/shell.qml &          # 2×2-Fenster, Szene darin per IPC grabToImage
ls -la /proc/$(pgrep -f 'qs -p /tmp/test')/fd | grep -c dri  # muss 0 sein (= keine GPU)
```
Shader-Dateien dabei als **Kopie** in den Testordner legen – Quickshell folgt keinem symlinkten Unterordner.
Absturzspuren: `coredumpctl list`, `journalctl -k -b -1 | grep -E 'GPU HANG|TLB'`.

**Wiederkehrende Hyprland-Abstürze (Auswertung 2026-10-13, 8 Crash-Reports 1.–12.10.):** Signal 6 (ABRT), Assertion in
`CHyprOpenGLImpl::begin()` / `beginSimple()` beim Rendern eines Monitors (einmal über `renderHWCursorBuffer`).
- **Nicht die Plugins:** zwei Abstürze vom 1.10. passierten ganz ohne Plugin (Reports `1551`/`1553`, gleiche Spur).
- **Auffällig: Standby.** Vier der Sitzungen hatten kurz vorher `PM: suspend exit` (s2idle); am 12.10. 11:52 stürzte
  Hyprland 1 s nach dem Aufwachen ab. Im Log davor ein Neu-Scan der DRM-Anschlüsse (Dock-Monitore HDMI-A-1/DP-2
  „has crtc -1, will be rechecked“) → Verdacht: DisplayLink/evdi-Monitore tauchen nach dem Aufwachen neu auf, während gerendert wird.
- Nicht belegt (Ursache nur Verdacht), ein Hyprland-Update gab es am 2026-10-13 nicht (0.56.2 ist aktuell). Ein Fix wäre
  Sache von Hyprland/aquamarine – per Konfiguration ist die Assertion nicht zu beheben.
- Nachprüfen: `journalctl --no-pager -o short-iso | grep -E 'Hyprland has crashed|PM: suspend (entry|exit)' | grep -B3 crashed`
  zeigt, was direkt vor jedem Absturz passierte; die Dumps (`coredumpctl list Hyprland`) liegen in `/var/lib/systemd/coredump`.

**Hyprland-Plugins testen – in einem verschachtelten Test-Hyprland** (Absturz dort trifft den echten Desktop nicht;
das DRM-Backend scheitert dort harmlos mit „Could not take control of session“, es läuft im Fenster/headless):
```sh
env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland -c /tmp/test/test.lua &   # eigene Mini-Konfig mit hl.plugin.load(…)
hyprctl instances -j                                                    # Instanz + wl_socket (z. B. wayland-2) ablesen
hyprctl -i <instanz> output create headless WTEST                      # Bildschirm, der ohne sichtbares Fenster rendert
WAYLAND_DISPLAY=wayland-2 grim -o WTEST /tmp/test/shot.png             # Screenshot davon
```
- Die Position des Headless-Bildschirms **in der Test-Konfig** festlegen (`hl.monitor({ output = "WTEST", … position = "2000x0" })`) –
  sonst setzt jedes Neuladen ihn auf 0x0, Fenster liegen danach im Nirgendwo und `grim` wartet ewig auf ein Bild.
- Das Testfenster selbst kann im echten Desktop versteckt werden (z. B. Klick aufs Wallpaper) – dann rendert es nicht mehr,
  der Headless-Bildschirm aber weiter. Absturzbericht: `~/.cache/hyprland/hyprlandCrashReport<pid>.txt`,
  Plugin-Zeile auflösen mit `addr2line -f -C -e plugin.so 0x<offset>`.
- Beim Testen nie `pkill -f "<muster>"` benutzen, wenn das Muster in der eigenen Befehlszeile steht (beendet die eigene Shell).
