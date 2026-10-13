#!/usr/bin/env python3
# Erzeugt den Hintergrund fürs GRUB-Theme „ghost“: Sturmhimmel, Katana im Silbergras, fallende Flocken.
# Aufruf: hintergrund.py <ausgabe-ordner> [breite höhe]
# Schreibt background.jpg (Hauptmenü) und background_load.jpg (abgedunkelt/weich für „LOAD GAME“).
import math
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
W = int(sys.argv[2]) if len(sys.argv) > 2 else 2880
H = int(sys.argv[3]) if len(sys.argv) > 3 else 1800
K = H / 1800.0                      # alle Längen sind für 1800 px Höhe gedacht
rng = np.random.default_rng(8155)
f32 = np.float32


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t


def col(hexs):
    h = hexs.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=f32)


def value_noise(w, h, cx, cy):
    """Weiches Rauschen: grobes Zufallsgitter (cx × cy Zellen) bikubisch hochskaliert."""
    gw, gh = int(cx) + 4, int(cy) + 4
    g = rng.standard_normal((gh, gw)).astype(f32)
    sw, sh = int(math.ceil(gw * w / cx)), int(math.ceil(gh * h / cy))
    a = np.asarray(Image.fromarray(g).resize((sw, sh), Image.BICUBIC))
    ox = rng.integers(int(w / cx), max(int(w / cx) + 1, sw - w - int(w / cx)))
    oy = rng.integers(int(h / cy), max(int(h / cy) + 1, sh - h - int(h / cy)))
    return a[oy:oy + h, ox:ox + w]


def fbm(w, h, cx, cy, octaves, gain=0.5):
    acc = np.zeros((h, w), f32)
    amp, tot = 1.0, 0.0
    for i in range(octaves):
        acc += amp * value_noise(w, h, cx * 2 ** i, cy * 2 ** i)
        tot += amp
        amp *= gain
    acc /= tot
    lo, hi = np.percentile(acc, [1, 99])
    return np.clip((acc - lo) / (hi - lo), 0, 1)


def sample(F, X, Y):
    """Bilineares Nachschlagen in F an (X, Y), Ränder geklemmt."""
    h, w = F.shape
    X = np.clip(X, 0, w - 1.001)
    Y = np.clip(Y, 0, h - 1.001)
    x0 = X.astype(np.int32)
    y0 = Y.astype(np.int32)
    fx = X - x0
    fy = Y - y0
    return (F[y0, x0] * (1 - fx) * (1 - fy) + F[y0, x0 + 1] * fx * (1 - fy)
            + F[y0 + 1, x0] * (1 - fx) * fy + F[y0 + 1, x0 + 1] * fx * fy)


def _box(a, r, axis):
    """Box-Unschärfe mit Radius r entlang einer Achse (über kumulierte Summen)."""
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode='edge'), axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(f32)


def blur(a, r):
    """Gauß-ähnliche Unschärfe (3× Box) für 2D- oder 3D-Arrays, r ≈ Sigma in Pixeln."""
    if r < 0.5:
        return a
    b = max(1, int(round(math.sqrt(12 * r * r / 3 + 1) / 2 - 0.5)))
    out = a.astype(f32)
    for _ in range(3):
        out = _box(_box(out, b, 0), b, 1)
    return out


yy, xx = np.mgrid[0:H, 0:W].astype(f32)
u = xx / W
v = yy / H
aspect = W / H

# ---------------------------------------------------------------- Himmel
# Vorlage: oben rechts bricht Licht durch, oben links und ein Band in der Mitte sind dunkle Sturmwolken.
glow_c = (0.80, 0.17)                       # helle Stelle (oben rechts)
gd = ((u - glow_c[0]) * aspect) ** 2 / 1.1 + (v - glow_c[1]) ** 2 / 0.16
glow = np.exp(-gd * 3.0).astype(f32)
glow_wide = np.exp(-gd * 0.8).astype(f32)
band = np.exp(-((v - 0.50 + 0.06 * u) / 0.13) ** 2).astype(f32)     # dunkles Wolkenband

sky = mix(col('#24302f'), col('#5f7473'), smoothstep(0.0, 0.7, v)[..., None])
sky = mix(sky, col('#bcd0d1'), (glow_wide * 0.75 + glow * 0.25)[..., None])

# Wolken: verwirbeltes fBm (große, weiche Ballen)
wx = fbm(W, H, 2.5, 2.0, 5)
wy = fbm(W, H, 2.5, 2.0, 5)
base = fbm(W, H, 2.2, 2.4, 7, gain=0.55)
X = xx + (wx - 0.5) * 300 * K
Y = yy + (wy - 0.5) * 170 * K
dens = sample(base, X, Y)
detail = fbm(W, H, 8.0, 7.0, 5)
dens = dens * 0.85 + detail * 0.15
want = np.clip(0.30 + 0.30 * (1 - u) ** 0.8 + 0.25 * (1 - u) ** 2 + 0.30 * band + 0.25 * smoothstep(0.25, 0.0, v) * (1 - glow_wide)
               - 0.55 * glow_wide, 0.02, 0.98)
cloud = smoothstep(1 - want - 0.28, 1 - want + 0.28, dens)

# Licht kommt von der hellen Stelle: der ihr zugewandte Rand einer Wolke wird heller
lx = glow_c[0] * W - xx
ly = glow_c[1] * H - yy
ln = np.sqrt(lx * lx + ly * ly) + 1e-3
step = 40 * K
toward = sample(cloud, xx + lx / ln * step, yy + ly / ln * step)
lit = np.clip(0.45 + 1.8 * (cloud - toward), 0, 1)
lit = blur(lit, 7 * K)
inner = blur(cloud, 30 * K)                   # dicke Wolkenmitte = dunkler

c_dark = col('#121b1a')
c_mid = col('#2e3f3e')
c_lit = col('#a9bfc0')
ccol = mix(c_mid, c_dark, smoothstep(0.4, 0.95, inner)[..., None] * (1 - 0.6 * glow_wide[..., None]))
ccol = mix(ccol, c_lit, (smoothstep(0.5, 1.0, lit) * (0.30 + 0.70 * glow_wide))[..., None])
ccol = ccol * (0.85 + 0.45 * glow_wide[..., None]) * (1 - 0.25 * band[..., None])
img = mix(sky, ccol, (cloud * 0.95)[..., None])

# feine Fetzen/Schleier
wisp = fbm(W, H, 14.0, 6.0, 4)
img = img + ((wisp - 0.5) * 0.06 * (0.3 + glow_wide))[..., None]


# ---------------------------------------------------------------- Gras: Hilfsfunktionen
def horizon_y(x):
    """Obere Kante des Grasfelds (y in px) für x in px."""
    s = x / W
    return H * (0.69 - 0.06 * np.exp(-((s - 0.55) / 0.30) ** 2) + 0.02 * np.sin(s * 9.0 + 1.3))


class Layer:
    def __init__(self):
        self.d = np.zeros(W * H, np.float64)      # Dichte der Fasern
        self.l = np.zeros(W * H, np.float64)      # Dichte × Helligkeit
        self.s = np.zeros(W * H, np.float64)      # dunkle Halme/Blätter

    def splat(self, px, py, w, lum=None, dark=False):
        ok = (px >= 0) & (px < W - 1) & (py >= 0) & (py < H - 1)
        px, py, w = px[ok], py[ok], w[ok]
        if lum is not None:
            lum = lum[ok]
        x0 = px.astype(np.int64)
        y0 = py.astype(np.int64)
        fx = px - x0
        fy = py - y0
        for dx, dy, ww in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)),
                           (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
            idx = (y0 + dy) * W + (x0 + dx)
            if dark:
                self.s += np.bincount(idx, w * ww, W * H)
            else:
                self.d += np.bincount(idx, w * ww, W * H)
                self.l += np.bincount(idx, w * ww * lum, W * H)


def stroke_points(x0, y0, ang, length, bend, n):
    """Punkte entlang einer gebogenen Linie (Winkel ab Senkrechte, + = nach rechts)."""
    s = np.linspace(0, 1, n, dtype=f32)
    a = ang + bend * s ** 2
    ds = length / max(n - 1, 1)
    dx = np.sin(a) * ds
    dy = -np.cos(a) * ds
    return x0 + np.concatenate([[0], np.cumsum(dx[:-1])]), y0 + np.concatenate([[0], np.cumsum(dy[:-1])]), a


def plume(layer, bx, by, L, ang, bend, bright, density=1.0):
    """Eine Silbergras-Rispe (Susuki): Mittelachse + viele feine, nach außen/oben laufende Fasern."""
    n_sp = max(8, int(L / 3))
    sx, sy, sa = stroke_points(bx, by, ang, L, bend, n_sp)
    wmax = L * rng.uniform(0.13, 0.20)
    nf = int(density * L * wmax / 5.0) + 20
    s0 = rng.random(nf) ** 0.75
    i0 = np.minimum((s0 * (n_sp - 1)).astype(int), n_sp - 1)
    prof = np.sin(np.pi * np.clip(s0, 0, 1) ** 0.65) ** 0.9 + 0.08
    side = rng.choice([-1.0, 1.0], nf)
    spread = rng.uniform(0.18, 0.75, nf)
    fa = sa[i0] + side * spread
    flen = wmax * prof * rng.uniform(0.6, 1.35, nf) / np.maximum(np.sin(spread), 0.25)
    flen = np.minimum(flen, L * 0.45)
    fbend = rng.uniform(0.05, 0.45, nf) * np.sign(ang + 0.2) + side * rng.uniform(-0.1, 0.1, nf)
    m = max(6, int(flen.max() / 0.75))
    tt = np.linspace(0, 1, m, dtype=f32)[None, :]
    a = fa[:, None] + fbend[:, None] * tt
    stepl = (flen / (m - 1))[:, None]
    px = sx[i0][:, None] + np.cumsum(np.sin(a) * stepl, 1) - np.sin(a[:, :1]) * stepl
    py = sy[i0][:, None] - np.cumsum(np.cos(a) * stepl, 1) + np.cos(a[:, :1]) * stepl
    wgt = (1 - tt) ** 0.7 * rng.uniform(0.25, 1.0, nf)[:, None] * (flen[:, None] / m) * 0.55
    # Licht von oben rechts: Fasern, die dorthin zeigen, und die Rispenspitze sind heller
    facing = 0.5 + 0.5 * np.sin(a - 0.6)
    lum = np.clip(bright * (0.55 + 0.45 * facing + 0.25 * s0[:, None]) + rng.normal(0, 0.06, (nf, 1)), 0, 1.2)
    layer.splat(px.ravel(), py.ravel(), wgt.ravel(), lum.ravel())
    # die Achse selbst (feiner, etwas dunkler Strich)
    layer.splat(sx, sy, np.full(n_sp, 0.25 * L / n_sp, f32), np.full(n_sp, bright * 0.6, f32))
    return sx[0], sy[0], sa[0]


def stem(layer, x, y, ang, thick):
    """Halm von der Rispe nach unten bis aus dem Bild."""
    L = (H - y) * 1.15 + 40
    n = max(10, int(L / 0.8))
    px, py, _ = stroke_points(x, y, ang + math.pi, L, rng.uniform(-0.15, 0.15), n)
    for o in np.linspace(-thick / 2, thick / 2, max(1, int(thick))):
        layer.splat(px + o, py, np.full(n, 0.8, f32), dark=True)


def leaf(layer, x, y, L, ang, bend, thick):
    """Langes, schmales Grasblatt vom Boden aus, im Wind gebogen."""
    n = max(10, int(L / 0.8))
    px, py, a = stroke_points(x, y, ang, L, bend, n)
    s = np.linspace(0, 1, n, dtype=f32)
    w = thick * (1 - s) ** 0.7
    for o in np.linspace(-1, 1, max(2, int(thick) + 1)):
        layer.splat(px + o * w * np.cos(a), py + o * w * np.sin(a), np.full(n, 0.7, f32), dark=True)


def render_layer(layer, img, blur_r, haze, c_hi, c_lo, c_dark, opacity=1.0, glow_amt=0.25):
    d = blur(layer.d.reshape(H, W).astype(f32), blur_r + 0.35)
    lm = blur(layer.l.reshape(H, W).astype(f32), blur_r + 0.35)
    s = blur(layer.s.reshape(H, W).astype(f32), blur_r * 0.8 + 0.4)
    lum = np.clip(lm / (d + 1e-4), 0, 1.2)
    a_f = 1 - np.exp(-d * 1.0)
    a_s = 1 - np.exp(-s * 0.9)
    # dunkle Halme zuerst
    dark = mix(c_dark, img, haze)
    img = mix(img, np.broadcast_to(dark, img.shape) if dark.ndim == 1 else dark, (a_s * opacity)[..., None])
    c = mix(c_lo, c_hi, np.clip(lum, 0, 1)[..., None]) * (1 + 0.15 * np.clip(lum - 1, 0, 1))[..., None]
    c = mix(c, img, haze)
    img = mix(img, c, (a_f * opacity)[..., None])
    # weicher Schimmer um helle Rispen (Gegenlicht)
    g = blur(a_f * np.clip(lum, 0, 1), 14 * K + blur_r * 2)
    img = img + (g * glow_amt)[..., None] * np.array([0.85, 0.92, 0.9], f32)
    return img


def field(z0, z1, count, scale, stems=True, leaves=0, density=1.0, xs=None):
    layer = Layer()
    zs = np.sort(rng.uniform(z0, z1, count))
    for z in zs:
        x = rng.uniform(-0.05, 1.05) * W if xs is None else xs()
        hy = horizon_y(np.array([x]))[0]
        y = hy + (z ** 1.6) * (H * 1.12 - hy) + rng.normal(0, 18 * K)
        L = scale * (0.35 + 1.9 * z ** 2.2) * rng.uniform(0.7, 1.3) * K * 150
        ang = rng.normal(0.42, 0.28)
        bend = rng.uniform(0.25, 0.9) * (1 if ang > -0.1 else -0.5)
        bright = np.clip(0.55 + 0.45 * (x / W) * 0.6 + rng.normal(0, 0.12) + 0.25 * np.exp(-((x / W - 0.75) / 0.25) ** 2), 0.3, 1.1)
        bx, by, ba = plume(layer, x, y, L, ang, bend, bright, density)
        if stems:
            stem(layer, bx, by, ba * 0.35, max(1.0, L / 110))
    for _ in range(leaves):
        z = rng.uniform(z0, z1)
        x = rng.uniform(-0.05, 1.05) * W
        hy = horizon_y(np.array([x]))[0]
        y = hy + (z ** 1.6) * (H * 1.12 - hy) + 160 * K
        L = (0.4 + 2.2 * z ** 2) * rng.uniform(0.6, 1.4) * 260 * K
        leaf(layer, x, y, L, rng.normal(0.25, 0.35), rng.uniform(0.6, 1.8), max(1.0, 3.5 * z * K))
    return layer


# ---------------------------------------------------------------- Boden hinter dem Gras
hz = horizon_y(xx[0])[None, :]
ground = smoothstep(hz - 40 * K, hz + 220 * K, yy)
img = mix(img, mix(col('#3a4743'), col('#121816'), smoothstep(hz, H, yy)[..., None]), (ground * 0.92)[..., None])

HI = col('#dfe6d8')
LO = col('#5f6c5f')
DK = col('#1e2622')

print('Gras hinten …', flush=True)
img = render_layer(field(0.0, 0.18, 650, 0.6, stems=False, density=0.55), img, 1.6, 0.45, HI, LO, DK, glow_amt=0.18)
img = render_layer(field(0.18, 0.42, 380, 0.8, leaves=120, density=0.6), img, 0.8, 0.22, HI, LO, DK, glow_amt=0.22)


# ---------------------------------------------------------------- Katana
def katana(img):
    print('Katana …', flush=True)
    # Lage (an 16:9-Vorlage angelehnt, auf 16:10 umgerechnet)
    tx, ty = 0.612 * W, 0.355 * H           # Mitte des Stichblatts (Tsuba)
    ang = math.radians(23.0)                 # Neigung ab Senkrechte, Klinge nach unten rechts
    du = np.array([math.sin(ang), math.cos(ang)])      # entlang Klinge (nach unten)
    dv = np.array([math.cos(ang), -math.sin(ang)])     # quer, + = oben rechts (Lichtseite)
    Lh, Lb = 375 * K, 1000 * K
    curv = 0.00005 / K
    ss = 3                                   # Überabtastung für glatte Kanten
    # Begrenzungsrechteck
    pts = [(tx + du[0] * a + dv[0] * b, ty + du[1] * a + dv[1] * b) for a in (-Lh - 40 * K, Lb) for b in (-70 * K, 70 * K)]
    x0 = int(max(0, min(p[0] for p in pts) - 10)); x1 = int(min(W, max(p[0] for p in pts) + 10))
    y0 = int(max(0, min(p[1] for p in pts) - 10)); y1 = int(min(H, max(p[1] for p in pts) + 10))
    gy, gx = np.mgrid[y0 * ss:y1 * ss, x0 * ss:x1 * ss].astype(f32)
    gx = (gx + 0.5) / ss - tx
    gy = (gy + 0.5) / ss - ty
    U = gx * du[0] + gy * du[1]
    V = gx * dv[0] + gy * dv[1]
    V = V - curv * U * U * np.sign(U + 1e-6) * -1     # leichte Krümmung (Sori)
    rgb = np.zeros(U.shape + (3,), f32)
    a = np.zeros(U.shape, f32)

    def put(mask, c):
        nonlocal rgb, a
        rgb = np.where(mask[..., None], c, rgb)
        a = np.where(mask, 1.0, a)

    # Klinge
    hab_end = 50 * K
    bw = (31 - 6 * np.clip(U / Lb, 0, 1)) * K
    vn = V / (bw / 2)
    m_bl = (U > 8 * K) & (U < Lb) & (np.abs(vn) <= 1)
    along = np.clip(U / Lb, 0, 1)
    nz = np.sin(U / (37 * K) + np.sin(U / (91 * K)) * 2.0) * 0.08 + np.sin(U / (13 * K)) * 0.03
    steel_dark = col('#3b4544'); steel_mid = col('#7b8684'); steel_hi = col('#d3dbd9')
    c = mix(steel_dark, steel_mid, smoothstep(-1.0, -0.15, vn)[..., None])
    c = mix(c, steel_hi * 0.92, smoothstep(-0.1, 0.25, vn)[..., None] * 0.55)
    hamon = smoothstep(0.38 + nz, 0.62 + nz, vn)
    c = mix(c, col('#e6ece9'), (hamon * 0.5)[..., None])
    ridge = np.exp(-((vn + 0.12) / 0.06) ** 2)
    c = c + (ridge * 0.35)[..., None]
    edge = np.exp(-((vn - 0.93) / 0.07) ** 2)
    c = c + (edge * 0.3)[..., None]
    c = c * (1.0 - 0.18 * along)[..., None]
    put(m_bl, c)
    # Habaki (Klingenhülse)
    m_hb = (U >= 6 * K) & (U < hab_end) & (np.abs(V) <= 19 * K)
    hb = mix(col('#3b3a35'), col('#8a8571'), smoothstep(-19 * K, 19 * K, V)[..., None])
    put(m_hb, hb)
    # Tsuba (Stichblatt), von schräg oben: flache Ellipse quer zur Achse
    m_ts = (U / (13 * K)) ** 2 + (V / (64 * K)) ** 2 <= 1
    rim = smoothstep(0.75, 1.0, (U / (13 * K)) ** 2 + (V / (64 * K)) ** 2)
    ts = mix(col('#191b1b'), col('#4a4f4e'), (rim * smoothstep(-40 * K, 60 * K, V))[..., None])
    put(m_ts, ts)
    # Fuchi (Ring am Griff)
    m_fu = (U < -10 * K) & (U > -30 * K) & (np.abs(V) <= 23.5 * K)
    put(m_fu, mix(col('#1e2020'), col('#5d6260'), smoothstep(-23 * K, 23 * K, V)[..., None]))
    # Griff (Tsuka) mit Wicklung: helles Band, dunkle Rauten
    hw = (22 - 1.6 * np.sin(np.clip((-U - 30 * K) / (Lh - 30 * K), 0, 1) * np.pi)) * K
    m_tk = (U <= -30 * K) & (U > -Lh) & (np.abs(V) <= hw)
    P = 46 * K
    q = np.mod(-U - 30 * K, P) / P
    hn = V / hw
    diamond = np.abs(q - 0.5) * 2 + np.abs(hn) / 0.62 < 1
    sa_ = np.mod(q + 0.40 * hn, 1.0)
    sb_ = np.mod(q - 0.40 * hn, 1.0)
    groove = np.minimum(np.minimum(sa_, 1 - sa_), np.minimum(sb_, 1 - sb_))
    cord = col('#e4e2da') * (0.70 + 0.30 * smoothstep(0, 0.09, groove))[..., None]
    cyl = (1 - 0.42 * hn ** 2) * (0.82 + 0.25 * smoothstep(-1, 1, hn))
    cord = cord * cyl[..., None]
    same = mix(col('#151716'), col('#2f3332'), smoothstep(-1, 1, hn)[..., None])
    put(m_tk, np.where(diamond[..., None], same, cord))
    # Kashira (Knauf)
    m_ka = (U <= -Lh + 2 * K) & (U > -Lh - 24 * K) & (np.abs(V) <= 23 * K - np.clip(-U - Lh - 14 * K, 0, None))
    put(m_ka, mix(col('#151716'), col('#4c5150'), smoothstep(-23 * K, 23 * K, V)[..., None]))

    # herunterrechnen
    hh, ww = (y1 - y0), (x1 - x0)
    rgb = rgb[:hh * ss, :ww * ss].reshape(hh, ss, ww, ss, 3).mean((1, 3))
    a = a[:hh * ss, :ww * ss].reshape(hh, ss, ww, ss).mean((1, 3))
    rgb = rgb / np.maximum(a[..., None], 1e-4)
    # unten steckt die Klinge im Gras: weich (mit unruhiger Kante) ausblenden
    ay = np.arange(y0, y1, dtype=f32)[:, None]
    ax = np.arange(x0, x1, dtype=f32)[None, :]
    jag = 14 * K * np.sin(ax / (9 * K)) + 9 * K * np.sin(ax / (4.3 * K) + 1.7)
    a = a * (1 - smoothstep(0.745 * H, 0.81 * H, ay + jag))
    region = img[y0:y1, x0:x1]
    rgb = mix(rgb, region, 0.10)                       # etwas Dunst
    img[y0:y1, x0:x1] = mix(region, rgb, a[..., None])
    return img


img = katana(img)

print('Gras vorne …', flush=True)
front = field(0.42, 0.70, 200, 0.9, leaves=90, density=0.6)
# ein paar Rispen extra direkt vor der Klinge, damit sie wirklich im Gras steckt
kfield = field(0.40, 0.55, 45, 0.9, leaves=20, density=0.7, xs=lambda: rng.normal(0.735, 0.035) * W)
front.d += kfield.d; front.l += kfield.l; front.s += kfield.s
img = render_layer(front, img, 0.5, 0.08, HI, LO, DK, glow_amt=0.25)
img = render_layer(field(0.70, 0.88, 45, 0.9, leaves=50, density=0.6), img, 2.4, 0.03, HI, LO, DK, glow_amt=0.25)
img = render_layer(field(0.88, 1.0, 10, 0.95, leaves=16, density=0.5), img, 9.0, 0.0, HI * 0.97, LO * 0.9, DK * 0.8, glow_amt=0.3)

# ---------------------------------------------------------------- Flocken / Asche
print('Flocken …', flush=True)
fl = np.zeros((H, W), f32)
n = 420
fx = rng.uniform(0, W, n)
fy = rng.uniform(0, H * 0.8, n)
for x, y in zip(fx, fy):
    r = rng.choice([0.9, 1.3, 1.8, 2.6], p=[0.45, 0.3, 0.17, 0.08]) * K
    b = rng.uniform(0.35, 0.95)
    ln_ = rng.uniform(0, 6) * K            # leichte Bewegungsunschärfe nach unten rechts
    for k in range(int(ln_) + 1):
        cx, cy = x + k * 0.8, y + k * 0.5
        xi, yi = int(cx), int(cy)
        rr = int(r * 2) + 2
        if 0 <= xi - rr and xi + rr < W and 0 <= yi - rr and yi + rr < H:
            sy_, sx_ = np.mgrid[-rr:rr + 1, -rr:rr + 1]
            fl[yi - rr:yi + rr + 1, xi - rr:xi + rr + 1] += b * np.exp(-((sx_ - (cx - xi)) ** 2 + (sy_ - (cy - yi)) ** 2) / (r * r)) / (ln_ + 1)
bok = np.zeros((H, W), f32)
for _ in range(26):
    x, y = rng.uniform(0, W), rng.uniform(0, H)
    r = rng.uniform(10, 26) * K
    xi, yi, rr = int(x), int(y), int(r * 2.2)
    if rr < xi < W - rr and rr < yi < H - rr:
        sy_, sx_ = np.mgrid[-rr:rr + 1, -rr:rr + 1]
        bok[yi - rr:yi + rr + 1, xi - rr:xi + rr + 1] += rng.uniform(0.05, 0.14) * smoothstep(r, r * 0.6, np.sqrt(sx_ ** 2 + sy_ ** 2))
img = img + (np.clip(fl, 0, 1) * 0.85 + blur(bok, 3 * K))[..., None] * col('#eef2ef')

# ---------------------------------------------------------------- Farbe, Vignette, Korn
lumi = img @ np.array([0.30, 0.59, 0.11], f32)
img = mix(lumi[..., None], img, 0.8)                   # leicht entsättigt
vig = 1 - 0.38 * smoothstep(0.35, 1.05, np.sqrt(((u - 0.55) * 1.25) ** 2 + ((v - 0.45) * 1.1) ** 2))
left = 0.58 + 0.42 * smoothstep(0.0, 0.5, u)         # links dunkler, damit das Menü gut lesbar ist
bottom = 1 - 0.30 * smoothstep(0.80, 1.0, v) * (0.55 + 0.45 * smoothstep(0.25, 0.0, np.minimum(u, 1 - u)))
img = img * (vig * left * bottom)[..., None]       # unten dunkler: Countdown und Tastenhinweise lesbar
img = np.clip(img, 0, 1)
img = img ** 1.04 * 0.97 + 0.025                       # Schwarz leicht angehoben (filmisch)
img = img + rng.normal(0, 0.009, (H, W, 1)).astype(f32)
img = np.clip(img, 0, 1)

out = Image.fromarray((img * 255 + 0.5).astype(np.uint8), )
out.save(f'{OUT}/background.jpg', quality=92, optimize=True, progressive=False, subsampling=0)
out.save(f'{OUT}/background_preview.png')

# „LOAD GAME“: weichgezeichnet und links stark abgedunkelt
dark = np.asarray(out.filter(ImageFilter.GaussianBlur(10 * K)), dtype=f32) / 255.0
shade = 0.30 + 0.45 * smoothstep(0.15, 0.95, u)
dark = dark * shade[..., None]
Image.fromarray((np.clip(dark, 0, 1) * 255 + 0.5).astype(np.uint8), ).save(
    f'{OUT}/background_load.jpg', quality=90, optimize=True, progressive=False, subsampling=0)
print('fertig', flush=True)
