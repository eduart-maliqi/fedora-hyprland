#!/usr/bin/env python3
"""Explorer-Modus: Nautilus zeigt in der Seitenleiste andere Lesezeichen, je nachdem ob der aktive Tab
in einem Windows-Ordner (/mnt/windows bzw. ~/Windows) oder in einem Linux-Ordner steht.

  explorer-modus.py            läuft im Hintergrund (Autostart in hyprland.lua), nur eine Instanz
  explorer-modus.py status     zeigt den aktuellen Modus
  explorer-modus.py linux|windows   Modus von Hand setzen (der Hintergrund-Dienst übernimmt beim nächsten Wechsel)

Wie der aktive Tab erkannt wird (Nautilus meldet ihn nicht direkt):
  - Nautilus meldet über D-Bus (org.freedesktop.FileManager1, OpenWindowsWithLocations) alle offenen Tabs.
  - Hyprland meldet über socket2 das aktive Fenster und dessen Titel = Ordnername des aktiven Tabs.
  - Liegen alle Tabs in derselben Welt → diese. Sonst: Tab(s), deren Ordnername zum Fenstertitel passt.
    Gerade neu geöffneter Ort (Tab hat navigiert) zählt ebenfalls. Bleibt es zweideutig → Modus bleibt.
Lesezeichen: GTK liest ~/.config/gtk-3.0/bookmarks, Nautilus übernimmt Änderungen sofort. Die beiden Sätze liegen in
~/.local/state/8155/lesezeichen-linux bzw. -windows. Beim Wechsel wird der aktuelle Inhalt zuerst in den alten
Satz zurückgeschrieben – Lesezeichen, die man im Modus anlegt oder löscht (Strg+D, Rechtsklick), bleiben also erhalten.
Datei-Dialoge anderer Programme benutzen dieselbe Datei → solange Nautilus offen ist, zeigen sie die Lesezeichen des
zuletzt aktiven Modus; ist Nautilus zu (keine Tabs mehr), schaltet der Dienst auf Linux zurück.
"""
import fcntl
import os
import socket
import sys
from collections import Counter
from urllib.parse import unquote, urlparse

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

HOME = os.path.expanduser("~")
BOOKMARKS = os.path.join(HOME, ".config/gtk-3.0/bookmarks")
STATE_DIR = os.path.join(HOME, ".local/state/8155")
SETS = {m: os.path.join(STATE_DIR, f"lesezeichen-{m}") for m in ("linux", "windows")}
MODE_FILE = os.path.join(STATE_DIR, "explorer-modus")
WIN_ROOTS = ("/mnt/windows", os.path.join(HOME, "Windows"))
NAUTILUS = "org.gnome.Nautilus"

# erster Satz für Windows (danach gilt, was in lesezeichen-windows steht)
# „windows“ führt direkt in den Windows-Benutzerordner; C: selbst erreicht man über den Laufwerk-Eintrag „Windows“
WIN_DEFAULT = """file:///home/edu/Windows/Users/eduar windows
file:///home/edu/Windows/Users/eduar/Desktop desktop
file:///home/edu/Windows/Users/eduar/Documents dokumente
file:///home/edu/Windows/Users/eduar/Downloads downloads
file:///home/edu/Windows/Users/eduar/Pictures bilder
file:///home/edu/Windows/Users/eduar/Music musik
file:///home/edu/Windows/Users/eduar/Videos videos
"""


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def world(uri):
    """'windows' / 'linux' für Ordner, None für Sonderorte (zuletzt verwendet, Papierkorb, andere Orte …)."""
    if not uri.startswith("file://"):
        return None
    path = unquote(urlparse(uri).path).rstrip("/") or "/"
    for root in WIN_ROOTS:
        if path == root or path.startswith(root + "/"):
            return "windows"
    return "linux"


class Explorer:
    def __init__(self):
        self.mode = (read(MODE_FILE) or "linux").strip()
        if self.mode not in SETS:
            self.mode = "linux"
        # der jetzige Inhalt gehört zum jetzigen Modus; fehlende Sätze anlegen
        if read(SETS[self.mode]) is None:
            write(SETS[self.mode], read(BOOKMARKS) or "")
        for m, path in SETS.items():
            if read(path) is None:
                write(path, WIN_DEFAULT if m == "windows" else "")

        self.active_class = ""
        self.active_title = ""
        self.active_addr = ""
        self.names = {}                 # uri → mögliche Fenstertitel (Zwischenspeicher)
        self.tabs = Counter()           # alle offenen Nautilus-Tabs (uri → Anzahl)

        self.proxy = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START,   # Nautilus nicht extra starten
            None, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1", None)
        self.proxy.connect("g-properties-changed", self.on_tabs_changed)
        self.tabs = self.read_tabs()

    # ── Nautilus ──────────────────────────────────────────────────────────────
    def read_tabs(self):
        v = self.proxy.get_cached_property("OpenWindowsWithLocations")
        tabs = Counter()
        if v is not None:
            for uris in v.unpack().values():
                tabs.update(uris)
        return tabs

    def titles_for(self, uri):
        if uri in self.names:
            return self.names[uri]
        f = Gio.File.new_for_uri(uri)
        n = set()
        if f.get_basename():
            n.add(f.get_basename())
        try:
            n.add(f.query_info("standard::display-name", Gio.FileQueryInfoFlags.NONE, None).get_display_name())
        except GLib.Error:
            pass
        try:
            mount = f.find_enclosing_mount(None)
            if mount.get_root().equal(f):
                n.add(mount.get_name())             # /mnt/windows heisst in Nautilus „Windows“
        except GLib.Error:
            pass
        if f.get_path() == HOME:
            n |= {"Persönlicher Ordner", "Home"}
        self.names[uri] = n
        return n

    def on_tabs_changed(self, *_):
        new = self.read_tabs()
        added = {world(u) for u in (new - self.tabs)} - {None}
        self.tabs = new
        # Nautilus zu → wieder Linux, damit Datei-Dialoge anderer Programme die normalen Lesezeichen zeigen
        if not new:
            self.set_mode("linux")
            return
        # ein Tab hat gerade irgendwohin navigiert → dort ist man. Nicht zusätzlich nach dem Titel gehen:
        # der kann noch vom alten Ordner sein (kommt oft erst danach) und würde zurückschalten.
        if self.active_class == NAUTILUS and len(added) == 1:
            self.set_mode(added.pop())
        else:
            self.decide()

    # ── Entscheidung ─────────────────────────────────────────────────────────
    def decide(self):
        if self.active_class != NAUTILUS or not self.tabs:
            return
        worlds = {world(u) for u in self.tabs} - {None}
        if len(worlds) == 1:
            self.set_mode(worlds.pop())
            return
        hits = {world(u) for u in self.tabs if self.active_title in self.titles_for(u)} - {None}
        if len(hits) == 1:
            self.set_mode(hits.pop())

    def set_mode(self, new):
        # Datei ist massgebend – sie kann von Hand (explorer-modus.py linux|windows) geändert worden sein
        saved = (read(MODE_FILE) or "").strip()
        if saved in SETS:
            self.mode = saved
        if new == self.mode:
            return
        current = read(BOOKMARKS)
        if current is not None:
            write(SETS[self.mode], current)         # Änderungen im alten Modus behalten
        write(BOOKMARKS, read(SETS[new]) or "")
        self.mode = new
        write(MODE_FILE, new + "\n")

    # ── Hyprland ─────────────────────────────────────────────────────────────
    def on_event(self, line):
        ev, _, arg = line.partition(">>")
        if ev == "activewindow":
            self.active_class, _, self.active_title = arg.partition(",")
            self.decide()
        elif ev == "activewindowv2":
            self.active_addr = arg
        elif ev == "windowtitlev2":
            addr, _, title = arg.partition(",")
            if addr == self.active_addr and self.active_class == NAUTILUS:
                self.active_title = title
                self.decide()


def run():
    lock = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "explorer-modus.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return                                      # läuft schon

    ex = Explorer()
    if not ex.tabs:                                 # Nautilus gerade zu → normale Lesezeichen
        ex.set_mode("linux")
    sig = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", sig, ".socket2.sock"))
    loop = GLib.MainLoop()
    buf = b""

    def on_data(*_):
        nonlocal buf
        data = sock.recv(65536)
        if not data:                                # Hyprland beendet
            loop.quit()
            return False
        buf += data
        *lines, buf = buf.split(b"\n")
        for line in lines:
            ex.on_event(line.decode("utf-8", "replace"))
        return True

    GLib.io_add_watch(sock.fileno(), GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN | GLib.IOCondition.HUP, on_data)
    loop.run()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "status":
        print((read(MODE_FILE) or "linux").strip())
    elif len(sys.argv) > 1 and sys.argv[1] in SETS:
        Explorer().set_mode(sys.argv[1])
    else:
        run()
