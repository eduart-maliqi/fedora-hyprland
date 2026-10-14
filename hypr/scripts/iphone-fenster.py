#!/usr/bin/env python3
"""★ 8155 – Spiegelfenster (UxPlay) an die Bildgrösse des iPhones anpassen: iphone-fenster.py <breite> <höhe>

Aufgerufen von iphone-uxplay.sh, sobald UxPlay eine neue Bildgrösse meldet (Start, iPhone gedreht).
Hochformat: 85 % der Bildschirmhöhe, Querformat: 80 % der Bildschirmbreite – mittig auf dem Bildschirm des Fensters.
Das Steuerfenster (iphone-steuern.py) zieht von selbst mit.
"""
import json
import subprocess
import sys
import time


def hypr(*args):
    return json.loads(subprocess.run(["hyprctl", *args, "-j"], capture_output=True, text=True).stdout)


def main():
    w, h = float(sys.argv[1]), float(sys.argv[2])
    if w <= 0 or h <= 0:
        return
    # das Fenster entsteht erst mit dem ersten Bild – kurz darauf warten
    for _ in range(30):
        ux = next((c for c in hypr("clients") if c.get("class") == "uxplay"), None)
        if ux:
            break
        time.sleep(0.2)
    else:
        return
    mon = next(m for m in hypr("monitors") if m["id"] == ux["monitor"])
    mw, mh = mon["width"] / mon["scale"], mon["height"] / mon["scale"]
    if w > h:
        tw = mw * 0.8
        th = tw * h / w
        if th > mh * 0.85:
            th = mh * 0.85
            tw = th * w / h
    else:
        th = mh * 0.85
        tw = th * w / h
    x, y = mon["x"] + (mw - tw) / 2, mon["y"] + (mh - th) / 2
    for d in ('hl.dsp.window.resize({x=%d, y=%d, window="address:%s"})' % (tw, th, ux["address"]),
              'hl.dsp.window.move({x=%d, y=%d, window="address:%s"})' % (x, y, ux["address"])):
        subprocess.run(["hyprctl", "dispatch", d], capture_output=True)


if __name__ == "__main__":
    main()
