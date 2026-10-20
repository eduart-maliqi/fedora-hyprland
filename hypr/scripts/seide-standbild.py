#!/usr/bin/env python3
# ★ 8155 – Standbilder fürs Wallpaper „seide“: wallpapers/seide/<thema>.jpg (2880×1800)
#   Nachbau von quickshell/shaders/seide.frag in numpy (Bild bei phase = 0). Gebraucht für alles, was ein echtes Bild
#   will (hyprlock, Helligkeit hinter der Uhr, Galerie-Verlauf); auf dem Desktop läuft der Shader selbst.
#   Braucht numpy + pillow: python3 -m venv /tmp/v && /tmp/v/bin/pip install numpy pillow
#   /tmp/v/bin/python seide-standbild.py            → alle Themen neu rechnen
#   Nach Änderungen an seide.frag hier nachziehen, sonst passt das Standbild nicht mehr zur Animation.
import os, numpy as np
from PIL import Image

W, H = 2880, 1800
# accentDeep, accent, accentSoft – wie die Paletten in quickshell/Theme.qml
PAL = {"golden": ("#b8792b", "#e3a142", "#f2c57c"), "glut": ("#9e2f34", "#ef5a50", "#fdb59a"),
       "kohle": ("#a8740f", "#e8a21c", "#f5c867"), "purpur": ("#8f1f5a", "#f2508a", "#f3b0d6"),
       "lila": ("#6b2fd6", "#a66bff", "#d2b4ff"),
       "mond": ("#4b7aa3", "#8cc0e4", "#cfe3f1"), "silber": ("#6b7684", "#cfd6df", "#eef1f5")}
K1, K2 = [1, 2, 1, 3, 2], [2, 1, 3, 1, 2]

def farbe(h): return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])

def hoehe(x, y, ph):
    for i in range(5):
        fi = i + 1.0
        x, y = (x + 0.95 / fi * np.sin(fi * 0.9 * y + ph * K1[i] + 0.7 * fi),
                y + 0.95 / fi * np.cos(fi * 0.8 * x + ph * K2[i] + 1.3 * fi))
    return np.sin(x * 1.1 + 0.4) * np.cos(y * 0.9 - 0.3)

def bild(deep, mid, soft, ph=0.0):
    u, v = np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)
    x, y = u * (W / H) * 1.7, v * 1.7
    e = 0.004
    h = hoehe(x, y, ph)
    hx, hy = (hoehe(x + e, y, ph) - h) / e, (hoehe(x, y + e, ph) - h) / e
    n = np.stack([-hx * 0.9, -hy * 0.9, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    L = np.array([-0.45, -0.55, 0.7]); L /= np.linalg.norm(L)
    nl = (n * L).sum(-1)
    diff = np.clip(nl, 0, 1)
    spec = np.clip((2 * nl[..., None] * n - L)[..., 2], 0, 1) ** 30
    s = np.clip(diff ** 1.3 * 1.05 + 0.15 * h, 0, 1)[..., None]
    c0, c1, c4 = deep * 0.04, deep * 0.55, soft * 0.6 + 0.4
    col = np.where(s < 0.3, c0 + (c1 - c0) * (s / 0.3),
          np.where(s < 0.55, c1 + (mid - c1) * ((s - 0.3) / 0.25),
          np.where(s < 0.8, mid + (soft - mid) * ((s - 0.55) / 0.25), soft + (c4 - soft) * ((s - 0.8) / 0.2))))
    l = (col * [0.299, 0.587, 0.114]).sum(-1, keepdims=True)
    col = np.clip(l + (col - l) * 1.5 + spec[..., None] * 0.3, 0, 1) * 0.82
    return Image.fromarray((col * 255 + 0.5).astype(np.uint8))

ziel = os.path.expanduser("~/.config/hypr/wallpapers/seide")
os.makedirs(ziel, exist_ok=True)
for name, (d, m, s) in PAL.items():
    bild(farbe(d), farbe(m), farbe(s)).save(f"{ziel}/{name}.jpg", quality=92)
    print(name)
