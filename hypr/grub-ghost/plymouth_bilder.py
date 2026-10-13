#!/usr/bin/env python3
# Erzeugt die Overlay-Bilder fürs Plymouth-Theme „ghost“ (animierter Ladebildschirm) in plymouth/:
#   schwarz.png       – daraus blendet die Szene ein (GRUB ist beim Start schwarz)
#   flocke_1..3.png   – Schneeflocken
#   laden.png         – „LOADING“ unten rechts
#   box.png           – Feld für Passwort-/Fragen (falls Plymouth eins braucht)
# Aufruf: plymouth_bilder.py   (braucht numpy, Pillow)
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HIER = os.path.dirname(os.path.abspath(__file__))
P = f'{HIER}/plymouth'
FONT = f'{HIER}/Cinzel-Medium.ttf'
W, H = 2880, 1800
rng = np.random.default_rng(1274)
f32 = np.float32

# ---------------------------------------------------------------- Schwarz zum Einblenden (Plymouth skaliert es auf den Bildschirm)
Image.new('RGB', (8, 8), (0, 0, 0)).save(f'{P}/schwarz.png')

for alt in ('katana.png', 'katana.pos', 'nebel.png', 'nebel_1.png', 'nebel_2.png'):     # frühere Fassungen
    if os.path.exists(f'{P}/{alt}'):
        os.remove(f'{P}/{alt}')

# ---------------------------------------------------------------- Flocken
for i, r in enumerate((2.2, 3.5, 6.0), 1):
    s = int(r * 4) + 2
    yy, xx = np.mgrid[0:s, 0:s].astype(f32) - (s - 1) / 2
    a = np.exp(-(xx * xx + yy * yy) / (r * r)) * (0.95 if i < 3 else 0.6)
    Image.fromarray((np.dstack([np.full((s, s, 3), 0.93, f32), a]) * 255).astype(np.uint8)).save(f'{P}/flocke_{i}.png')


# ---------------------------------------------------------------- „LOADING“ und Dialogfeld
def tracked(text, size, spacing, fill):
    f = ImageFont.truetype(FONT, size)
    probe = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    w = int(sum(probe.textlength(c, font=f) + spacing for c in text) - spacing)
    im = Image.new('RGBA', (w + 80, size + 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = 40
    for c in text:
        d.text((x, 40), c, font=f, fill=fill)
        x += d.textlength(c, font=f) + spacing
    a = np.asarray(im.getchannel('A').filter(ImageFilter.GaussianBlur(10)), dtype=f32) * 1.4
    sh = np.zeros((im.height, im.width, 4), np.uint8)
    sh[..., :3] = (8, 13, 13)
    sh[..., 3] = np.clip(a, 0, 170).astype(np.uint8)
    out = Image.fromarray(sh)
    out.alpha_composite(im)
    return out


tracked('LOADING', 54, 12, (212, 217, 215, 255)).save(f'{P}/laden.png')
box = Image.new('RGBA', (1200, 260), (0, 0, 0, 0))
ImageDraw.Draw(box).rounded_rectangle((0, 0, 1199, 259), radius=18, fill=(12, 18, 17, 215), outline=(150, 160, 157, 140), width=2)
box.save(f'{P}/box.png')
print('fertig:', sorted(f for f in os.listdir(P) if not f.startswith('gras_')))
