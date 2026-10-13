#!/usr/bin/env python3
# Macht aus dem Hauptmenü-Video von Ghost of Tsushima (YouTube 2gDPSewa5x8, 1080p) die Hintergründe fürs Theme „ghost“:
#   theme/background.jpg       – Hauptmenü (2880×1800), Original-Menütext wegretuschiert, Helligkeit wie Screenshot
#   theme/background_load.jpg  – „LOAD GAME“: weichgezeichnet + links abgedunkelt
#   plymouth/szene.png         – dasselbe Bild für den Ladebildschirm (Plymouth kann nur PNG)
# Nur für den privaten Gebrauch (Bild gehört Sucker Punch/Sony).
# Video holen:  yt-dlp --js-runtimes node -f 299 --download-sections "*0-25" -o menu.mp4 https://www.youtube.com/watch?v=2gDPSewa5x8
# Aufruf:       got_bild.py menu.mp4 [sekunde=5.071733]   (braucht numpy, Pillow, ffmpeg)
# Die Sekunde sollte ein Schlüsselbild sein (YouTube speichert die ~7× größer → viel weniger Blöcke im Gras):
#   ffprobe -v error -select_streams v -show_entries packet=pts_time,flags -of csv=p=0 menu.mp4 | grep K
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageFilter

HIER = os.path.dirname(os.path.abspath(__file__))
VIDEO = sys.argv[1]
T = float(sys.argv[2]) if len(sys.argv) > 2 else 5.071733
W, H = 2880, 1800
f32 = np.float32


def blur(a, r):
    """Gauß-ähnliche Unschärfe (3× Box über kumulierte Summen), a: HxW oder HxWxC."""
    k = max(1, int(round(r)))
    for ax in (0, 1):
        for _ in range(3):
            pad = [(0, 0)] * a.ndim
            pad[ax] = (k + 1, k)
            c = np.cumsum(np.pad(a, pad, mode='edge'), axis=ax, dtype=np.float64)
            n = a.shape[ax]
            a = ((np.take(c, np.arange(2 * k + 1, 2 * k + 1 + n), axis=ax) - np.take(c, np.arange(n), axis=ax))
                 / (2 * k + 1)).astype(f32)
    return a


def frames(t, n):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-ss', f'{t:.4f}', '-i', VIDEO, '-frames:v', str(n),
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, 1080, 1920, 3)


# Gegen YouTube-Kompression: wo sich nichts bewegt (Himmel), den Median von 31 Bildern (½ s) nehmen – entfernt
# Blockrauschen und Flocken; wo sich etwas bewegt (Gras), nur das Schlüsselbild selbst (Mitteln verschmiert dort).
N = 31
st = frames(T - N / 2 / 59.94, N)
mitte = frames(T, 1)[0].astype(f32) / 255
ruhig = np.median(st, axis=0).astype(f32) / 255
lum = st.astype(f32) @ np.array([0.299, 0.587, 0.114], f32) / 255
bewegung = blur(lum.std(0), 6)
del st, lum
w = np.clip((bewegung - 0.012) / 0.03, 0, 1)[..., None]
img = ruhig * (1 - w) + mitte * w


# ---------------------------------------------------------------- Original-Menü entfernen (Koordinaten in 1080p)
def box(m, x0, y0, x1, y1):
    m[y0:y1, x0:x1] = True


# (x0, y0, x1, y1, dx, dy): Lochrechteck + Versatz einer textfreien Stelle, deren Wolkenstruktur hineinkommt
BOXES = [(80, 224, 622, 306, 0, -110),    # CONTINUE + Pinselstrich (inkl. auslaufender Borsten) ← Wolken darüber
         (110, 326, 305, 370, 420, 0),    # LOAD GAME ← Wolken rechts daneben
         (110, 408, 295, 452, 420, 0),    # NEW GAME
         (110, 490, 270, 534, 420, 0)]    # OPTIONS
hole = np.zeros((1080, 1920), bool)
for x0, y0, x1, y1, _, _ in BOXES:
    box(hole, x0, y0, x1, y1)

def push_pull(a, m):
    """Löcher (m=True) aus der Umgebung auffüllen: Bildpyramide mit Gewichten nach unten, Werte wieder nach oben."""
    if not m.any():
        return a
    w = (~m).astype(f32)
    h, wd = m.shape
    if min(h, wd) < 4:
        fill = (a * w[..., None]).sum((0, 1)) / max(w.sum(), 1e-6)
        return np.where(m[..., None], fill, a)
    h2, w2 = h // 2 * 2, wd // 2 * 2
    aw = (a * w[..., None])[:h2, :w2].reshape(h2 // 2, 2, w2 // 2, 2, 3).sum((1, 3))
    ww = w[:h2, :w2].reshape(h2 // 2, 2, w2 // 2, 2).sum((1, 3))
    small = aw / np.maximum(ww, 1e-6)[..., None]
    small = push_pull(small, ww < 0.5)
    big = np.stack([np.asarray(Image.fromarray(small[..., c]).resize((wd, h), Image.BILINEAR)) for c in range(3)], -1)
    return np.where(m[..., None], big, a)


filled = push_pull(img, hole)
# Wolkenstruktur zurückgeben: feines Detail einer textfreien Stelle (siehe BOXES) dazurechnen
detail = img - blur(img, 3)
for x0, y0, x1, y1, dx, dy in BOXES:
    filled[y0:y1, x0:x1] += detail[y0 + dy:y1 + dy, x0 + dx:x1 + dx] * 0.8
soft = np.asarray(Image.fromarray((hole * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
                  .filter(ImageFilter.GaussianBlur(4)), dtype=f32)[..., None] / 255
img = img * (1 - soft) + filled * soft

# ---------------------------------------------------------------- Aufbereiten: Tonkurve, 16:9 → 16:10, hochrechnen
def aufbereiten(img):
    """1080p-Bild (float RGB) → 2880×1800 wie der Screenshot (mehr Kontrast, hellere Lichter), als PIL-Bild."""
    lum = img @ np.array([0.299, 0.587, 0.114], f32)
    src = np.array([0, 19, 40, 77, 121, 134, 160, 255], f32) / 255
    dst = np.array([0, 18, 35, 65, 137, 188, 215, 255], f32) / 255
    gain = np.interp(lum, src, dst) / np.maximum(lum, 1e-4)
    img = np.clip(img * gain[..., None], 0, 1)
    im = Image.fromarray((img * 255 + 0.5).astype(np.uint8)).resize((3200, 1800), Image.LANCZOS).crop((160, 0, 160 + W, H))
    return im.filter(ImageFilter.UnsharpMask(radius=2.0, percent=35, threshold=2))


# ---------------------------------------------------------------- Standbild (GRUB + Grundbild für Plymouth)
a = np.asarray(aufbereiten(img), dtype=f32) / 255
# hinter den unteren Menüeinträgen (große Schrift reicht bis ins helle Gras) sanft abdunkeln, sonst unlesbar
yy, xx = np.mgrid[0:H, 0:W].astype(f32)
schatten = np.clip(1 - xx / (W * 0.55), 0, 1) ** 1.5 * np.clip((yy - H * 0.45) / (H * 0.25), 0, 1)
a = a * (1 - 0.55 * schatten)[..., None]
del yy, xx
rng = np.random.default_rng(8155)
a = np.clip(a + rng.normal(0, 0.008, (H, W, 1)).astype(f32), 0, 1)      # feines Korn überdeckt Restblöcke
out = Image.fromarray((a * 255 + 0.5).astype(np.uint8))
os.makedirs(f'{HIER}/theme', exist_ok=True)
os.makedirs(f'{HIER}/plymouth', exist_ok=True)
out.save(f'{HIER}/theme/background.jpg', quality=94, optimize=True, progressive=False, subsampling=0)
for f in os.listdir(f'{HIER}/plymouth'):
    if f.startswith('gras_') or f == 'szene_oben.png':
        os.remove(f'{HIER}/plymouth/{f}')
out.save(f'{HIER}/plymouth/szene.png', optimize=True)

u = np.linspace(0, 1, W, dtype=f32)[None, :]
dark = np.asarray(out.filter(ImageFilter.GaussianBlur(16)), dtype=f32) / 255
dark = dark * (0.28 + 0.47 * np.clip((u - 0.12) / 0.8, 0, 1))[..., None]
Image.fromarray((np.clip(dark, 0, 1) * 255 + 0.5).astype(np.uint8)).save(
    f'{HIER}/theme/background_load.jpg', quality=90, optimize=True, progressive=False, subsampling=0)
print('fertig:', f'{HIER}/theme/background.jpg')
