#!/usr/bin/env python3
# ★ 8155 – Farbthemen aus themen/<name>/farben.json (die eine Quelle aller Themenfarben)
#   thema-bauen.py bauen <name>      → hyprlock.conf, mako, rofi.rasi, kitty.conf, hypr.lua daraus neu schreiben
#   thema-bauen.py speichern <name>  → farben.json von stdin übernehmen (prüft die Felder) + bauen
#   thema-bauen.py vorschlag <bild>  → {"accent", "ink", "base"} als JSON, aus den Hauptfarben des Bilds
#   thema-bauen.py loeschen <name>   → Ordner in den Papierkorb (nicht golden = Rückfall, nicht das aktive)
#   thema-bauen.py liste             → alle Themen als eine JSON-Zeile je Thema (liest Theme.qml beim Start)
#   thema-bauen.py --test            → Selbsttest: bauen ergibt byte-gleich die vorhandenen Dateien
# Benutzt vom Wallpaper-Studio (quickshell/WallpaperStudio.qml); Umschalten macht weiter thema.sh.
import json, os, re, subprocess, sys, tempfile

DIR = os.path.expanduser("~/.config/hypr/themen")
NAME = re.compile(r"^[a-z]{2,16}$")       # landet in Dateinamen, Shell und hyprctl eval
HEX = re.compile(r"^#[0-9a-f]{6}$")
FARBEN = ["accent", "accentSoft", "accentDeep", "cream", "muted", "dim", "faint", "ink", "onAccentMuted", "red",
          "panel", "term", "termInk", "termTab"]


def pruefen(name, f):
    if not NAME.match(name):
        raise SystemExit(f"ungültiger Name: {name!r} (nur a–z, 2–16 Zeichen)")
    for k in FARBEN + (["clockDate"] if "clockDate" in f else []):
        if not HEX.match(str(f.get(k, ""))):
            raise SystemExit(f"{k}: keine Farbe #rrggbb ({f.get(k)!r})")
    if not re.match(r"^#[0-9a-f]{8}$", str(f.get("rofiHair", ""))):
        raise SystemExit("rofiHair: keine Farbe #rrggbbaa")
    for k, n in (("base", 3), ("hover", 3), ("hair", 4)):
        v = f.get(k)
        if not (isinstance(v, list) and len(v) == n and all(isinstance(x, (int, float)) and 0 <= x <= 1 for x in v)):
            raise SystemExit(f"{k}: {n} Zahlen 0…1 erwartet")
    b = f.get("lockBrightness")
    if not (isinstance(b, (int, float)) and 0 <= b <= 1):
        raise SystemExit("lockBrightness: Zahl 0…1 erwartet")


def dateien(name, f):
    h = lambda k: f[k][1:]
    return {
        "hyprlock.conf": f"""# ★ 8155 – Farben des Sperrbildschirms, Thema {name} (eingebunden von hyprlock.conf über themen/aktiv)
$akzent     = rgb({h('accent')})
$zweitfarbe = rgba({h('accentSoft')}cc)
$uhrfarbe   = rgba({h('cream')}f0)
$datumfarbe = rgba({h('muted')}ee)
$randfarbe  = rgba({h('accent')}70)
$feldfarbe  = rgba({h('ink')}99)
$textfarbe  = rgb({h('cream')})
# Hintergrundbild abdunkeln (1 = gar nicht; dunkle Bilder höher)
$helligkeit = {f['lockBrightness']:g}
""",
        "kitty.conf": f"""# ★ 8155 – kitty-Farben, Thema {name} (eingebunden von kitty.conf über themen/aktiv)
foreground            {f['cream']}
background            {f['term']}
selection_foreground  {f['termInk']}
selection_background  {f['accent']}
cursor                {f['accentSoft']}
cursor_text_color     {f['termInk']}
url_color             {f['accentSoft']}

active_tab_foreground   {f['termInk']}
active_tab_background   {f['accent']}
inactive_tab_foreground {f['muted']}
inactive_tab_background {f['termTab']}
tab_bar_background      {f['term']}
""",
        "mako": f"""# ★ 8155 – Farben der Benachrichtigungen, Thema {name} (eingebunden von mako/config über themen/aktiv)
background-color={f['panel']}d6
text-color={f['cream']}
border-color={f['accent']}66
progress-color=over {f['accent']}44
""",
        "rofi.rasi": f"""/* ★ 8155 – rofi-Farben, Thema {name} (eingebunden von rofi/config.rasi über themen/aktiv) */
* {{
    accent:      {f['accent']};
    accent-soft: {f['accentSoft']};
    cream:       {f['cream']};
    muted:       {f['muted']};
    faint:       {f['faint']};
    ink:         {f['ink']};
    hairline:    {f['rofiHair']};
    panel:       {f['panel']}b8;
}}
""",
        "hypr.lua": f"""-- ★ 8155 – Farben fürs Thema {name} in hyprland.lua (golden.apply_theme), erzeugt von scripts/thema-bauen.py
return {{ accent = "{h('accent')}", accent_soft = "{h('accentSoft')}", ink = "{h('ink')}" }}
""",
    }


def laden(name):
    with open(f"{DIR}/{name}/farben.json") as fh:
        return json.load(fh)


def bauen(name, ziel=None):
    f = laden(name)
    pruefen(name, f)
    ziel = ziel or f"{DIR}/{name}"
    for datei, text in dateien(name, f).items():
        with open(f"{ziel}/{datei}", "w") as fh:
            fh.write(text)


def themen():
    return sorted(d for d in os.listdir(DIR) if d != "aktiv" and os.path.isfile(f"{DIR}/{d}/farben.json"))


def vorschlag(bild):
    out = subprocess.run(["magick", bild, "-resize", "200x200", "-colors", "10", "-format", "%c", "histogram:info:"],
                         capture_output=True, text=True, check=True).stdout
    farben = []                                   # (anzahl, r, g, b)
    for m in re.finditer(r"^\s*(\d+):.*?#([0-9A-Fa-f]{6})", out, re.M):
        c = m.group(2)
        farben.append((int(m.group(1)), *(int(c[i:i + 2], 16) for i in (0, 2, 4))))
    if not farben:
        raise SystemExit("keine Farben gefunden")

    def hsv(r, g, b):
        mx, mn = max(r, g, b) / 255, min(r, g, b) / 255
        return (mx - mn) / mx if mx else 0, mx
    gesamt = sum(f[0] for f in farben)
    # Akzent: kräftig und hell genug, Fläche zählt etwas mit; Tinte: die dunkelste nennenswerte Farbe
    akzent = max(farben, key=lambda f: hsv(*f[1:])[0] * hsv(*f[1:])[1] * (0.5 + f[0] / gesamt))
    dunkel = min((f for f in farben if f[0] / gesamt > 0.03), key=lambda f: sum(f[1:]), default=farben[0])
    hex_ = lambda r, g, b: f"#{r:02x}{g:02x}{b:02x}"
    # Tinte sehr dunkel halten (Text auf Akzent, Hintergrund), Glas = Tinte etwas aufgehellt, Farbton behalten
    s = 22 / max(1, max(dunkel[1:]))
    ink = [min(255, round(c * s)) for c in dunkel[1:]] if max(dunkel[1:]) > 22 else list(dunkel[1:])
    base = [round(min(1, c / 255 * 1.0 + 0.03), 3) for c in ink]
    # Akzent muss auf dunklem Glas leuchten → mindestens 85 % Helligkeit, Farbton und Sättigung bleiben
    k = max(1, 0.85 * 255 / max(1, max(akzent[1:])))
    akzent = [min(255, round(c * k)) for c in akzent[1:]]
    return {"accent": hex_(*akzent), "ink": hex_(*ink), "base": base}


def selbsttest():
    alle = themen()
    assert alle, "keine farben.json gefunden"
    with tempfile.TemporaryDirectory() as tmp:
        for name in alle:
            os.makedirs(f"{tmp}/{name}")
            bauen(name, f"{tmp}/{name}")
            for datei in ("hyprlock.conf", "mako", "rofi.rasi", "kitty.conf", "hypr.lua"):
                with open(f"{tmp}/{name}/{datei}") as a, open(f"{DIR}/{name}/{datei}") as b:
                    assert a.read() == b.read(), f"{name}/{datei} weicht ab"
    for falsch in ("Gross", "a", "x;rm", "../x"):
        try:
            pruefen(falsch, {})
        except SystemExit:
            continue
        raise AssertionError(f"Name {falsch!r} durchgelassen")
    print(f"ok: {len(alle)} Themen")


def main():
    a = sys.argv[1:]
    if a == ["--test"]:
        selbsttest()
    elif a == ["liste"]:
        for name in themen():
            try:
                print(json.dumps({"name": name, **laden(name)}))
            except (OSError, ValueError) as e:
                print(f"{name}: {e}", file=sys.stderr)
    elif len(a) == 2 and a[0] == "bauen":
        bauen(a[1])
    elif len(a) == 2 and a[0] == "speichern":
        f = json.load(sys.stdin)
        f.pop("name", None)
        pruefen(a[1], f)
        os.makedirs(f"{DIR}/{a[1]}", exist_ok=True)
        with open(f"{DIR}/{a[1]}/farben.json", "w") as fh:
            json.dump(f, fh, indent=2)
            fh.write("\n")
        bauen(a[1])
    elif len(a) == 2 and a[0] == "vorschlag":
        print(json.dumps(vorschlag(a[1])))
    elif len(a) == 2 and a[0] == "loeschen":
        name = a[1]
        if not NAME.match(name) or not os.path.isdir(f"{DIR}/{name}"):
            raise SystemExit(f"unbekanntes Thema: {name}")
        if name == "golden" or os.readlink(f"{DIR}/aktiv").rstrip("/") == name:
            raise SystemExit(f"{name} wird nicht gelöscht (Rückfallthema oder gerade aktiv)")
        subprocess.run(["gio", "trash", f"{DIR}/{name}"], check=True)
    else:
        sys.exit(__doc__ or "Aufruf siehe Kopf der Datei")


if __name__ == "__main__":
    main()
