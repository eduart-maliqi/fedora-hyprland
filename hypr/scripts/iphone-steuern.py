#!/usr/bin/env python3
"""★ 8155 – iPhone mit Maus und Tastatur des Laptops bedienen (Gegenstück zu iphone-hid.py)

Ein durchsichtiges Fenster liegt genau über dem Spiegelbild (UxPlay-Fenster, scripts/iphone.sh steuern).
Klick aufs Spiegelbild → die Maus ist eingefangen, der iPhone-Zeiger springt an die Klickstelle und folgt der Maus;
Klicks, Mausrad und Tastatur gehen ans iPhone. Strg+Alt gibt Maus und Tastatur wieder frei. Schliessen: Super+Q.
Verschieben/Grösse ändern mit Super+Maus (wenn nicht eingefangen) zieht das Spiegelfenster mit.
"""
import json
import math
import os
import signal
import socket
import subprocess
import sys
import time

os.environ.setdefault("SDL_VIDEODRIVER", "wayland")
os.environ.setdefault("SDL_VIDEO_WAYLAND_WMCLASS", "iphone-steuern")   # Klasse für die Fensterregel
os.environ.setdefault("SDL_MOUSE_RELATIVE_SYSTEM_SCALE", "1")   # eingefangen: Mausbeschleunigung wie auf dem Desktop
import sdl2

SOCK = os.environ.get("IPHONE_HID_SOCK") or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "iphone-hid.sock")
# shortcut: feste Masse des iPhone 15 Pro Max im Hochformat; bei anderem iPhone/Querformat anpassen
PHONE_W, PHONE_H = 430, 932   # Punkte
# iOS kennt nur relative Mäuse und beschleunigt stark: kleine Meldungen bewegen den Zeiger kaum. Gemessen
# (Spiegelbild, 2026-10-14): Meldungen (4,4) alle 15 ms → ~2 Punkte pro Einheit; dieselben alle 8 ms nur halb so viel.
# Darum: beim Einfangen Zeiger in die Ecke drücken (dort klemmt er, Position bekannt) und mit genau diesem Muster
# zur Klickstelle fahren; danach Mausbewegung wie eine echte Maus in 15-ms-Paketen weitergeben (SPEED Einheiten/Pixel).
# Abweichungen sieht man nicht, weil der Laptop-Zeiger eingefangen und unsichtbar ist – man führt nach Sicht.
GAIN = 2.0          # Punkte pro Einheit beim Hinfahren
STEP = 4 * math.sqrt(2)
TICK = 0.015
SPEED = 1.0
SYNC_EVERY = 0.3
HIDE = "iphone-steuern"   # Special-Workspace, solange keine Spiegelung läuft
DEBUG = bool(os.environ.get("IPHONE_DEBUG"))   # Ereignisse nach stderr (Fehlersuche)
CTRL_L, ALT_L, CTRL_R, ALT_R = 224, 226, 228, 230   # HID-Usage = SDL-Scancode; Strg+Alt = loslassen
BTN_BIT = {sdl2.SDL_BUTTON_LEFT: 1, sdl2.SDL_BUTTON_RIGHT: 2, sdl2.SDL_BUTTON_MIDDLE: 4}

out = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)


def send(msg):
    try:
        out.sendto(msg.encode(), SOCK)
    except OSError:
        pass   # iphone-hid.py läuft (noch) nicht


def glide(ux, uy):
    """Zeiger um (ux, uy) Einheiten in gleich grossen Schritten bewegen (gleiche Beschleunigung wie beim Messen)."""
    n = max(1, round(math.hypot(ux, uy) / STEP))
    sx = sy = 0
    for i in range(1, n + 1):
        x, y = round(ux * i / n), round(uy * i / n)
        send("m %d %d" % (x - sx, y - sy))
        sx, sy = x, y
        time.sleep(TICK)


def hypr_clients():
    try:
        return json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout)
    except (OSError, ValueError):
        return []


def geometry(c):
    return (*c["at"], *c["size"])


def dispatch(d):
    subprocess.run(["hyprctl", "dispatch", d], capture_output=True)


def place(addr, g):
    x, y, w, h = g
    dispatch('hl.dsp.window.resize({x=%d, y=%d, window="address:%s"})' % (w, h, addr))
    dispatch('hl.dsp.window.move({x=%d, y=%d, window="address:%s"})' % (x, y, addr))


def main():
    sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO)
    win = sdl2.SDL_CreateWindow(b"iphone steuern", sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED,
                                420, 910, sdl2.SDL_WINDOW_SHOWN | sdl2.SDL_WINDOW_RESIZABLE | sdl2.SDL_WINDOW_BORDERLESS)
    ren = sdl2.SDL_CreateRenderer(win, -1, 0)
    held, buttons = set(), 0
    captured = False                        # Maus eingefangen (relativer Modus), Eingaben gehen ans iPhone
    swallow = None                          # Maustaste, deren Loslassen zum Einfang-Klick gehört
    fx = fy = 0.0                           # Bruchteile von Einheiten, die noch nicht gesendet sind
    wheel = 0.0
    last_me = last_ux = None
    raised_for = [None, False]              # [Adresse des Spiegelfensters, hatte es den Fokus]
    next_sync = 0.0
    next_tick = 0.0
    reload = []
    signal.signal(signal.SIGUSR1, lambda *_: reload.append(1))   # neu laden, ohne die Sitzung (Bluetooth) zu beenden

    def paint():
        sdl2.SDL_SetRenderDrawColor(ren, 0, 0, 0, 255)
        sdl2.SDL_RenderClear(ren)
        sdl2.SDL_RenderPresent(ren)

    def content():
        """Bildfläche des iPhones im Fenster (UxPlay zeigt das Bild mittig mit Rand, wenn das Seitenverhältnis abweicht)."""
        w, h = sdl2.c_int(), sdl2.c_int()
        sdl2.SDL_GetWindowSize(win, w, h)
        w, h = w.value, h.value
        s = min(w / PHONE_W, h / PHONE_H)
        cw, ch = PHONE_W * s, PHONE_H * s
        return (w - cw) / 2, (h - ch) / 2, s   # Versatz x, y; Pixel pro Punkt

    def capture(mx, my):
        """iPhone-Zeiger an die Klickstelle fahren, dann Maus einfangen."""
        nonlocal captured, fx, fy
        for _ in range(30):
            send("m -60 -60")                  # in die Ecke oben links, dort klemmt der Zeiger
            time.sleep(0.006)
        time.sleep(0.05)
        ox, oy, s = content()
        px = min(max((mx - ox) / s, 0), PHONE_W)
        py = min(max((my - oy) / s, 0), PHONE_H)
        glide(round(px / GAIN), round(py / GAIN))
        sdl2.SDL_FlushEvent(sdl2.SDL_MOUSEMOTION)
        sdl2.SDL_SetRelativeMouseMode(sdl2.SDL_TRUE)
        captured, fx, fy = True, 0.0, 0.0
        subprocess.Popen(["notify-send", "-a", "iphone", "-t", "3000", "iphone steuern", "Strg+Alt gibt die Maus wieder frei"])

    def free():
        nonlocal captured
        sdl2.SDL_SetRelativeMouseMode(sdl2.SDL_FALSE)
        captured = False
        release_all()

    def release_all():
        nonlocal buttons
        if held or buttons:
            held.clear()
            buttons = 0
            send("b 0")
            send("k 0")

    def send_keys():
        mods = sum(1 << (c - 224) for c in held if c >= 224)   # SDL-Scancodes 4..231 = USB-HID-Usage-IDs
        keys = [c for c in held if c < 224][:6]
        send("k %d %s" % (mods, " ".join(map(str, keys))))

    def follow_mirror():
        """Über das Spiegelfenster legen; wird das Steuerfenster verschoben, zieht das Spiegelfenster nach."""
        nonlocal last_me, last_ux
        cl = hypr_clients()
        me = next((c for c in cl if c.get("pid") == os.getpid()), None)
        ux = next((c for c in cl if c.get("class") == "uxplay"), None)
        if not me:
            return
        hidden = me["workspace"]["name"] == "special:" + HIDE
        if not ux:
            # ohne Spiegelbild würde das unsichtbare Fenster irgendwo Klicks abfangen → wegräumen
            if not hidden:
                dispatch('hl.dsp.window.move({workspace="special:%s", follow=false, window="address:%s"})' % (HIDE, me["address"]))
            return
        if hidden or me["workspace"]["id"] != ux["workspace"]["id"]:
            dispatch('hl.dsp.window.move({workspace="%s", follow=false, window="address:%s"})' % (ux["workspace"]["name"], me["address"]))
        gm, gu = geometry(me), geometry(ux)
        if gm != gu:
            if last_me is not None and gm != last_me and gu == last_ux:
                place(ux["address"], gm)
                gu = gm
            else:
                place(me["address"], gu)
                gm = gu
        last_me, last_ux = gm, gu
        # neues oder fokussiertes Spiegelfenster liegt oben und schluckt die Maus → Steuerfenster nur in der Ebene
        # nach oben holen; kein focus-Dispatch: der setzt den Mauszeiger in die Fenstermitte (Zurück-Teleportieren)
        raise_now = ux["address"] != raised_for[0] or (ux["focusHistoryID"] == 0) != raised_for[1]
        if raise_now:
            dispatch('hl.dsp.window.alter_zorder({mode="top", window="address:%s"})' % me["address"])
        raised_for[:] = [ux["address"], ux["focusHistoryID"] == 0]

    paint()
    ev = sdl2.SDL_Event()
    while not reload:
        now = time.monotonic()
        if now >= next_sync:
            follow_mirror()
            next_sync = now + SYNC_EVERY
        if now >= next_tick:
            dx, dy = int(fx), int(fy)
            if dx or dy:
                send("m %d %d" % (dx, dy))
                fx -= dx
                fy -= dy
            next_tick = now + TICK
        if not sdl2.SDL_WaitEventTimeout(ev, 5):
            continue
        t = ev.type
        if DEBUG:
            print("%.3f" % time.monotonic(), t, ev.window.event if t == sdl2.SDL_WINDOWEVENT else "",
                  (ev.motion.x, ev.motion.y, ev.motion.xrel, ev.motion.yrel) if t == sdl2.SDL_MOUSEMOTION else "",
                  "captured" if captured else "-", file=sys.stderr, flush=True)
        if t == sdl2.SDL_QUIT:
            break
        if t == sdl2.SDL_WINDOWEVENT:
            if ev.window.event == sdl2.SDL_WINDOWEVENT_FOCUS_LOST and captured:
                free()
            paint()
        elif not captured:
            if t == sdl2.SDL_MOUSEBUTTONDOWN and ev.button.button == sdl2.SDL_BUTTON_LEFT:
                swallow = ev.button.button
                capture(ev.button.x, ev.button.y)
        elif t == sdl2.SDL_MOUSEMOTION:
            fx += ev.motion.xrel * SPEED
            fy += ev.motion.yrel * SPEED
        elif t in (sdl2.SDL_MOUSEBUTTONDOWN, sdl2.SDL_MOUSEBUTTONUP):
            if t == sdl2.SDL_MOUSEBUTTONUP and ev.button.button == swallow:
                swallow = None                 # Loslassen des Einfang-Klicks nicht ans iPhone
                continue
            bit = BTN_BIT.get(ev.button.button, 0)
            buttons = buttons | bit if t == sdl2.SDL_MOUSEBUTTONDOWN else buttons & ~bit
            send("b %d" % buttons)
        elif t == sdl2.SDL_MOUSEWHEEL:
            wheel += ev.wheel.preciseY
            w = int(wheel)
            if w:
                send("m 0 0 %d" % w)
                wheel -= w
        elif t in (sdl2.SDL_KEYDOWN, sdl2.SDL_KEYUP):
            if ev.key.repeat:
                continue
            sc = ev.key.keysym.scancode
            (held.add if t == sdl2.SDL_KEYDOWN else held.discard)(sc)
            if held & {CTRL_L, CTRL_R} and held & {ALT_L, ALT_R}:
                free()
                continue
            send_keys()
    release_all()
    sdl2.SDL_Quit()
    if reload:
        sys.exit(75)   # iphone.sh startet das Fenster dann neu


if __name__ == "__main__":
    main()
