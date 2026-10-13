#!/usr/bin/env python3
# Erzeugt die kleinen Bilder fürs GRUB-Theme „ghost“:
#   icons/ghost-*.png  – die Menüeinträge als Bild (FEDORA LINUX, WINDOWS …): unter Secure Boot lädt GRUB keine
#                        Schriften („prohibited by secure boot policy“), Text geht nur als Bild
#   select_c.png       – heller Pinselstrich hinter dem gewählten Eintrag (Hauptmenü)
#   load_select_c.png  – breiter, flacher Strich fürs „LOAD GAME“-Menü
#   load_title.png     – Überschrift „LOAD GAME“ mit feinem Pinselstrich darunter
#   hints.png / load_hints.png – Tastenhinweise unten rechts (wie die Knopf-Hinweise im Spiel)
#   terminal_box_c.png – Hintergrund der GRUB-Konsole (c) und des Editors (e), durchsichtig
# Aufruf: bilder.py <ausgabe-ordner> <schrift.ttf>   (Schrift: Cinzel-Medium.ttf)
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT, FONT = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(1274)
f32 = np.float32


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def noise1d(n, scale):
    """Weiches 1D-Rauschen der Länge n, Strukturgröße ≈ scale Pixel."""
    k = int(n / scale) + 4
    g = rng.random(k)
    x = np.arange(n) / scale + 1
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return g[i] * (1 - f) + g[i + 1] * f


COLOR = (0.86, 0.88, 0.88)          # hellgrau wie der Strich im Spiel (nicht reinweiß)


def brush(w, h, solid=0.6, reach=0.92, bristles=360, ss=2):
    """Trockener Pinselstrich wie im Spiel („Kamm“): gleich hoch bis zum Ende; bis `solid` (Anteil der Breite)
    decken alle Borsten → satt, danach enden die Borsten nach und nach bis `reach` → feine parallele Linien."""
    W, H = w * ss, h * ss
    x = np.arange(W, dtype=f32)[None, :]
    y = np.arange(H, dtype=f32)[:, None]
    keep = np.ones((H, W), f32)                       # Produkt (1 - a_i) → Deckung = 1 - keep
    for _ in range(bristles):
        yc = rng.uniform(0.03, 0.97)                  # relative Lage der Borste
        e = abs(2 * yc - 1)                           # 0 = Mitte, 1 = Rand
        th = rng.uniform(1.0, 2.4) * h / 144 * ss
        xs = W * (0.004 + 0.012 * e ** 4) + rng.uniform(0, 0.007 * W)      # linke Kante: rau, fast senkrecht
        xe = W * (solid + (reach - solid) * rng.uniform() ** 1.5)    # die meisten enden bald nach `solid`
        if e > 0.88:                                  # oberste/unterste Borsten: Rand leicht ausgefranst
            xe = min(xe, W * rng.uniform(0.25, solid + 0.1))
        fade = W * rng.uniform(0.03, 0.12)
        yy = yc * H + rng.normal(0, 0.5) * ss * np.sin(x / W * math.pi * rng.uniform(0.5, 1.5) + rng.uniform(0, 6))
        n = noise1d(W, rng.uniform(50, 160) * ss)[None, :]
        dry = np.clip((x - W * solid) / (W * (reach - solid)), 0, 1)
        gate = np.where(x < W * solid, 1.0, smoothstep(0.18, 0.30, n))   # im trockenen Teil ab und zu Lücken
        op = (0.9 + 0.1 * n) * gate * smoothstep(xe, xe - fade, x) * smoothstep(xs, xs + 3 * ss, x)
        op = op * (1 - 0.7 * dry)                                        # trockene Spuren durchscheinender …
        prof = np.exp(-((y - yy) / (th * (1 - 0.45 * dry))) ** 2)       # … und dünner
        keep *= 1 - np.clip(op * prof * 0.9, 0, 1)
    a = 1 - keep
    a = a.reshape(h, ss, w, ss).mean((1, 3))
    a = np.clip(a * 1.04, 0, 1)
    rgb = np.ones((h, w, 3), f32) * np.array(COLOR, f32)
    return Image.fromarray((np.dstack([rgb, a]) * 255 + 0.5).astype(np.uint8))


# Pinselstriche in der Größe des Menü-Eintrags bei 2880×1800 (theme.txt/load.txt) → GRUB skaliert kaum
def halbdurchsichtig(im, deckkraft):
    # GRUB kann den gewählten Text nicht dunkel färben → heller Text auf halb durchscheinendem Strich bleibt lesbar
    a = np.asarray(im, dtype=f32)
    a[..., 3] *= deckkraft
    return Image.fromarray((a + 0.5).astype(np.uint8))


halbdurchsichtig(brush(1460, 210, solid=0.88, reach=0.98, bristles=520), 0.55).save(f'{OUT}/select_c.png')
halbdurchsichtig(brush(1500, 150, solid=0.82, reach=0.97, bristles=420), 0.55).save(f'{OUT}/load_select_c.png')


def textbild(text, groesse, breite, hoehe, x, pfad):
    """Schriftzug als PNG mit weichem dunklem Schatten (lesbar auf Himmel, Gras und Strich). Nur Pillow – dieselbe
    Darstellung steckt in 15_ghost_menu (läuft als root ohne numpy)."""
    f = ImageFont.truetype(FONT, groesse)
    b = f.getbbox('H')
    im = Image.new('RGBA', (breite, hoehe), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((x, (hoehe + b[3] - b[1]) // 2), text, font=f, fill=(240, 240, 234, 255), anchor='ls',
                            stroke_width=1, stroke_fill=(10, 14, 13, 200))
    schatten = im.getchannel('A').filter(ImageFilter.GaussianBlur(groesse / 15)).point(lambda v: int(v * 0.8))
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.putalpha(schatten)
    out.alpha_composite(im)
    out.save(pfad)


import os
os.makedirs(f'{OUT}/icons', exist_ok=True)
for klasse, text in (('ghost-fedora', 'FEDORA LINUX'), ('ghost-windows', 'WINDOWS'), ('ghost-load', 'LOAD GAME'),
                     ('ghost-options', 'OPTIONS'), ('ghost-quit', 'QUIT GAME')):
    textbild(text, 150, 1360, 210, 100, f'{OUT}/icons/{klasse}.png')


def text_w(draw, s, font, track):
    return sum(draw.textlength(ch, font=font) + track for ch in s) - track


def draw_tracked(draw, xy, s, font, fill, track):
    x, y = xy
    for ch in s:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + track


CREAM = (217, 222, 219, 255)
MUTED = (170, 180, 176, 235)


def with_shadow(im, m=40):
    """Weicher dunkler Schatten + leichte Platte hinter Text/Linien, damit sie auch über hellem Gras lesbar sind."""
    big = Image.new('RGBA', (im.width + 2 * m, im.height + 2 * m), (0, 0, 0, 0))
    a = Image.new('L', big.size, 0)
    a.paste(im.getchannel('A'), (m, m))
    glow = np.asarray(a.filter(ImageFilter.GaussianBlur(9)), dtype=f32) * 1.6
    plate = Image.new('L', big.size, 0)
    ImageDraw.Draw(plate).rounded_rectangle((m // 2, m // 2, big.width - m // 2, big.height - m // 2), radius=m, fill=110)
    plate = np.asarray(plate.filter(ImageFilter.GaussianBlur(m / 3)), dtype=f32)
    sa = np.clip(np.maximum(glow, plate), 0, 200)
    sh = np.zeros((big.height, big.width, 4), f32)
    sh[..., :3] = (8, 13, 13)
    sh[..., 3] = sa
    out = Image.fromarray(sh.astype(np.uint8))
    out.alpha_composite(im, (m, m))
    return out


def hints(items, path, size=54):
    """Hinweise wie im Spiel: Taste in einem Rahmen, daneben was sie tut."""
    f = ImageFont.truetype(FONT, size)
    fk = ImageFont.truetype(FONT, int(size * 0.72))
    probe = ImageDraw.Draw(Image.new('RGBA', (10, 10)))
    pad, gap, kh = int(size * 0.42), int(size * 1.4), int(size * 1.35)
    parts = []
    total = 0
    for key, label in items:
        kw = max(kh, int(text_w(probe, key, fk, 2) + 2 * pad))
        lw = int(text_w(probe, label, f, 2))
        parts.append((key, label, kw, lw))
        total += kw + int(size * 0.5) + lw
    total += gap * (len(items) - 1)
    im = Image.new('RGBA', (total + 8, kh + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = 4
    for key, label, kw, lw in parts:
        d.rounded_rectangle((x, 4, x + kw, 4 + kh), radius=kh // 2, outline=MUTED, width=3)
        kx = x + (kw - text_w(d, key, fk, 2)) / 2
        draw_tracked(d, (kx, 4 + (kh - fk.size) / 2 - 2), key, fk, CREAM, 2)
        x += kw + int(size * 0.5)
        draw_tracked(d, (x, 4 + (kh - f.size) / 2 - 3), label, f, CREAM, 2)
        x += lw + gap
    im = with_shadow(im)
    im.save(path)
    print(path, im.size)


hints([('ENTER', 'SELECT'), ('E', 'EDIT')], f'{OUT}/hints.png')
hints([('ENTER', 'LOAD'), ('ESC', 'BACK')], f'{OUT}/load_hints.png')

# Überschrift „LOAD GAME“ mit kurzem Pinselstrich darunter
ft = ImageFont.truetype(FONT, 140)
probe = ImageDraw.Draw(Image.new('RGBA', (10, 10)))
tw = int(text_w(probe, 'LOAD GAME', ft, 4))
im = Image.new('RGBA', (tw + 260, 240), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
draw_tracked(d, (0, 0), 'LOAD GAME', ft, (230, 234, 231, 255), 4)
line = brush(tw + 250, 24, solid=0.35, reach=0.95, bristles=80)
la = np.asarray(line).astype(f32)
la[..., 3] *= 0.75
im.alpha_composite(Image.fromarray(la.astype(np.uint8)), (0, 192))
im.save(f'{OUT}/load_title.png')
print('load_title', im.size)

# Konsole/Editor: durchsichtig – GRUB zeigt diese Box auch kurz beim Starten eines Eintrags; so bleibt die Szene stehen
Image.new('RGBA', (8, 8), (0, 0, 0, 0)).save(f'{OUT}/terminal_box_c.png')
