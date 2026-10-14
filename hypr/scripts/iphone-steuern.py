#!/usr/bin/env python3
"""★ 8155 – iPhone mit Maus und Tastatur des Laptops bedienen (Gegenstück zu iphone-hid.py)

Ein durchsichtiges Fenster liegt genau über dem Spiegelbild (UxPlay-Fenster, scripts/iphone.sh steuern).
Maus darüber → der Laptop-Zeiger verschwindet, der iPhone-Zeiger (im Spiegelbild) folgt der Maus;
Klicks, Mausrad und Tastatur gehen ans iPhone. Maus raus → wieder Laptop. Schliessen: Super+Q.
Verschieben/Grösse ändern mit Super+Maus zieht das Spiegelfenster mit.
"""
import json
import os
import socket
import subprocess
import time

os.environ.setdefault("SDL_VIDEODRIVER", "wayland")
os.environ.setdefault("SDL_VIDEO_WAYLAND_WMCLASS", "iphone-steuern")   # Klasse für die Fensterregel
import sdl2

SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "iphone-hid.sock")
# shortcut: feste Masse des iPhone 15 Pro Max im Hochformat; bei anderem iPhone/Querformat anpassen
PHONE_W, PHONE_H = 430, 932   # Punkte
# iOS kennt nur relative Mäuse mit Beschleunigung. Gemessen (Spiegelbild, 2026-10-14): Schritte von 4 Einheiten
# bewegen den Zeiger ~2 Punkte pro Einheit. Darum: beim Hineinfahren Zeiger in die Ecke drücken (dort klemmt er,
# Position bekannt), dann zur Maus fahren; danach nur noch relativ nachführen. Abweichungen sieht man nicht,
# weil der Laptop-Zeiger über dem Fenster ausgeblendet ist – man führt den iPhone-Zeiger nach Sicht.
GAIN = 2.0
SYNC_EVERY = 0.3
HIDE = "iphone-steuern"   # Special-Workspace, solange keine Spiegelung läuft
BTN_BIT = {sdl2.SDL_BUTTON_LEFT: 1, sdl2.SDL_BUTTON_RIGHT: 2, sdl2.SDL_BUTTON_MIDDLE: 4}

out = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)


def send(msg):
    try:
        out.sendto(msg.encode(), SOCK)
    except OSError:
        pass   # iphone-hid.py läuft (noch) nicht


def glide(ux, uy):
    """Zeiger um (ux, uy) Einheiten in gleichmässigen Schritten bewegen (gleiche Beschleunigung wie beim Messen)."""
    n = max(1, int(max(abs(ux), abs(uy)) / 4))
    sx = sy = 0
    for i in range(1, n + 1):
        x, y = round(ux * i / n), round(uy * i / n)
        send("m %d %d" % (x - sx, y - sy))
        sx, sy = x, y
        time.sleep(0.008)


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
    sdl2.SDL_ShowCursor(sdl2.SDL_DISABLE)   # gilt nur über diesem Fenster
    held, buttons = set(), 0
    synced = False                          # iPhone-Zeiger steht (ungefähr) unter der Maus
    fx = fy = 0.0                           # Bruchteile von Einheiten, die noch nicht gesendet sind
    wheel = 0.0
    last_me = last_ux = None
    raised_for = [None, False]              # [Adresse des Spiegelfensters, hatte es den Fokus]
    next_sync = 0.0

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

    def sync_pointer():
        nonlocal synced, fx, fy
        for _ in range(30):
            send("m -60 -60")                  # in die Ecke oben links, dort klemmt der Zeiger
            time.sleep(0.006)
        time.sleep(0.05)
        mx, my = sdl2.c_int(), sdl2.c_int()
        sdl2.SDL_GetMouseState(mx, my)
        ox, oy, s = content()
        px = min(max((mx.value - ox) / s, 0), PHONE_W)
        py = min(max((my.value - oy) / s, 0), PHONE_H)
        glide(round(px / GAIN), round(py / GAIN))
        sdl2.SDL_FlushEvent(sdl2.SDL_MOUSEMOTION)
        synced, fx, fy = True, 0.0, 0.0

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
    while True:
        if time.monotonic() >= next_sync:
            follow_mirror()
            next_sync = time.monotonic() + SYNC_EVERY
        if not sdl2.SDL_WaitEventTimeout(ev, 100):
            continue
        t = ev.type
        if t == sdl2.SDL_QUIT:
            break
        if t == sdl2.SDL_WINDOWEVENT:
            e = ev.window.event
            if e == sdl2.SDL_WINDOWEVENT_ENTER:
                sync_pointer()
            elif e == sdl2.SDL_WINDOWEVENT_LEAVE:
                synced = False
            elif e == sdl2.SDL_WINDOWEVENT_FOCUS_LOST:
                release_all()
            paint()
        elif t == sdl2.SDL_MOUSEMOTION:
            if not synced:
                sync_pointer()
                continue
            ox, oy, s = content()
            fx += ev.motion.xrel / s / GAIN
            fy += ev.motion.yrel / s / GAIN
            # am Rand nachdrücken: langsame Bewegungen beschleunigt iOS weniger, sonst käme man nie bis an den Rand
            px, py = (ev.motion.x - ox) / s, (ev.motion.y - oy) / s
            if (px < 4 and ev.motion.xrel < 0) or (px > PHONE_W - 4 and ev.motion.xrel > 0):
                fx += 8 if ev.motion.xrel > 0 else -8
            if (py < 4 and ev.motion.yrel < 0) or (py > PHONE_H - 4 and ev.motion.yrel > 0):
                fy += 8 if ev.motion.yrel > 0 else -8
            dx, dy = int(fx), int(fy)
            if dx or dy:
                send("m %d %d" % (dx, dy))
                fx -= dx
                fy -= dy
        elif t in (sdl2.SDL_MOUSEBUTTONDOWN, sdl2.SDL_MOUSEBUTTONUP):
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
            send_keys()
    release_all()
    sdl2.SDL_Quit()


if __name__ == "__main__":
    main()
