#!/usr/bin/env python3
"""★ 8155 – iPhone mit Maus und Tastatur des Laptops bedienen (Gegenstück zu iphone-hid.py)

Fenster anklicken → Maus und Tastatur gehören dem iPhone (relative Mausbewegung, alle Tasten).
Strg+Alt+G gibt beides wieder frei. Das Fenster zeigt nur den Zustand; das Bild kommt vom
UxPlay-Fenster (AirPlay-Spiegelung, scripts/iphone.sh).
"""
import os
import socket
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "wayland")
os.environ.setdefault("SDL_VIDEO_WAYLAND_WMCLASS", "iphone-steuern")   # Klasse für die Fensterregel
import sdl2

SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "iphone-hid.sock")
# SDL-Scancodes 4..231 sind identisch mit den USB-HID-Usage-IDs; 224..231 sind die Modifier
LCTRL, LALT, RCTRL, RALT, G = 224, 226, 228, 230, 10
BTN_BIT = {sdl2.SDL_BUTTON_LEFT: 1, sdl2.SDL_BUTTON_RIGHT: 2, sdl2.SDL_BUTTON_MIDDLE: 4}

out = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)


def send(msg):
    try:
        out.sendto(msg.encode(), SOCK)
    except OSError:
        print("iphone-hid.py läuft nicht (Socket fehlt)", file=sys.stderr)


def main():
    sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO)
    win = sdl2.SDL_CreateWindow(b"iphone steuern", sdl2.SDL_WINDOWPOS_CENTERED, sdl2.SDL_WINDOWPOS_CENTERED,
                                360, 160, sdl2.SDL_WINDOW_SHOWN)
    ren = sdl2.SDL_CreateRenderer(win, -1, 0)
    held, buttons, grabbed = set(), 0, False

    def paint():
        r, g, b = (0xE3, 0xA1, 0x42) if grabbed else (0x12, 0x18, 0x1E)
        sdl2.SDL_SetRenderDrawColor(ren, r, g, b, 255)
        sdl2.SDL_RenderClear(ren)
        sdl2.SDL_RenderPresent(ren)
        sdl2.SDL_SetWindowTitle(win, b"iphone steuern - aktiv (Strg+Alt+G loslassen)" if grabbed
                                else b"iphone steuern - hier klicken")

    def grab(on):
        nonlocal grabbed, buttons
        grabbed = on
        sdl2.SDL_SetRelativeMouseMode(on)
        sdl2.SDL_SetWindowKeyboardGrab(win, on)
        if not on:
            held.clear()
            buttons = 0
            send("b 0")
            send("k 0")
        paint()

    def send_keys():
        mods = sum(1 << (c - 224) for c in held if c >= 224)
        keys = [c for c in held if c < 224][:6]
        send("k %d %s" % (mods, " ".join(map(str, keys))))

    paint()
    ev = sdl2.SDL_Event()
    while sdl2.SDL_WaitEvent(ev):
        t = ev.type
        if t == sdl2.SDL_QUIT:
            break
        if t == sdl2.SDL_WINDOWEVENT:
            if ev.window.event == sdl2.SDL_WINDOWEVENT_FOCUS_LOST:
                grab(False)
            paint()
        elif not grabbed:
            if t == sdl2.SDL_MOUSEBUTTONDOWN:
                grab(True)
        elif t == sdl2.SDL_MOUSEMOTION:
            send("m %d %d" % (ev.motion.xrel, ev.motion.yrel))
        elif t in (sdl2.SDL_MOUSEBUTTONDOWN, sdl2.SDL_MOUSEBUTTONUP):
            bit = BTN_BIT.get(ev.button.button, 0)
            buttons = buttons | bit if t == sdl2.SDL_MOUSEBUTTONDOWN else buttons & ~bit
            send("b %d" % buttons)
        elif t == sdl2.SDL_MOUSEWHEEL:
            send("m 0 0 %d" % ev.wheel.y)
        elif t in (sdl2.SDL_KEYDOWN, sdl2.SDL_KEYUP):
            if ev.key.repeat:
                continue
            sc = ev.key.keysym.scancode
            if t == sdl2.SDL_KEYDOWN:
                held.add(sc)
                if G in held and held & {LCTRL, RCTRL} and held & {LALT, RALT}:
                    grab(False)
                    continue
            else:
                held.discard(sc)
            send_keys()
    grab(False)
    sdl2.SDL_Quit()


if __name__ == "__main__":
    main()
