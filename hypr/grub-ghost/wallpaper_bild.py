#!/usr/bin/env python3
# Hintergrund fürs Theme „ghost“ aus dem Wallpaper (wallpapercave.com/wp/wp15726322.png, 3822×1600, Wunsch des Benutzers):
#   theme/background.jpg, theme/background_load.jpg (LOAD GAME: weich + links dunkel), plymouth/szene.png
# Auf 1800 px Höhe skaliert und so zugeschnitten, dass das Katana bei ~64 % steht – links bleibt dunkler Himmel fürs Menü.
# Aufruf: wallpaper_bild.py ~/.cache/grub-ghost/quelle/wallpaper.png
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HIER = os.path.dirname(os.path.abspath(__file__))
W, H = 2880, 1800
KATANA_X = 2078                      # Griff des Katanas im Original (px), landet bei 64 % der Breite

wp = Image.open(sys.argv[1]).convert('RGBA')
flach = Image.new('RGB', wp.size, (0, 0, 0))
flach.paste(wp, mask=wp.getchannel('A'))
s = H / wp.height
gross = flach.resize((round(wp.width * s), H), Image.LANCZOS)
x0 = min(max(0, round(KATANA_X * s - 0.64 * W)), gross.width - W)
bild = gross.crop((x0, 0, x0 + W, H))

os.makedirs(f'{HIER}/theme', exist_ok=True)
os.makedirs(f'{HIER}/plymouth', exist_ok=True)
bild.save(f'{HIER}/theme/background.jpg', quality=95, optimize=True, progressive=False, subsampling=0)
bild.save(f'{HIER}/plymouth/szene.png', optimize=True)

u = np.linspace(0, 1, W, dtype=np.float32)[None, :]
dunkel = np.asarray(bild.filter(ImageFilter.GaussianBlur(16)), dtype=np.float32) / 255
dunkel = dunkel * (0.28 + 0.47 * np.clip((u - 0.12) / 0.8, 0, 1))[..., None]
Image.fromarray((np.clip(dunkel, 0, 1) * 255 + 0.5).astype(np.uint8)).save(
    f'{HIER}/theme/background_load.jpg', quality=90, optimize=True, progressive=False, subsampling=0)
print('fertig: Ausschnitt ab x =', x0, 'von', gross.width)
