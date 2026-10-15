#!/usr/bin/env python3
"""Synchronisierte Songtexte für den Desktop (Quickshell: LyricsService.qml → Lyrics.qml).

  lyrics.py find ARTIST TITEL [ALBUM] [DAUER_S]
        sucht den Songtext und schreibt JSON-Zeilen auf stdout:
          {"stage": "suche" | "audio" | "ki"}                       Zwischenstand (beliebig oft)
          {"source": "lrclib" | "netease" | "ki" | "", "lrc": "…"}  Ergebnis (immer die letzte Zeile;
                                                                     bei Netzfehlern zusätzlich "error")
  lyrics.py key [--remove]          OpenAI-API-Key eingeben (verdeckt) bzw. löschen – nötig für die KI-Songtexte
  lyrics.py forget ARTIST TITEL     gespeicherten Songtext eines Lieds verwerfen (z. B. falscher Treffer)
  lyrics.py line                    aktuelle Zeile des laufenden Lieds aus dem Cache (hyprlock-Sperrbildschirm)
  lyrics.py info                    Key/yt-dlp vorhanden?, Anzahl gespeicherter Texte, bisherige KI-Kosten (Schätzung)

Quellen, in dieser Reihenfolge:
  1. Zwischenspeicher  ~/.cache/8155/lyrics/<hash>.json (Treffer für immer, „nichts gefunden“ befristet)
  2. lrclib.net        frei; erst exakt (Interpret, Titel, Album, Länge), dann Suche mit passender Länge
  3. NetEase           frei; viele internationale Lieder, Länge muss auf ±3 s passen
  4. KI                nur mit OpenAI-Key + yt-dlp: Audio des Lieds von YouTube (gleiche Länge ±3 s, am liebsten
                       „… - Topic“) → OpenAI whisper-1 mit Wort-Zeitstempeln → Zeilen. Kostet ca. 0.006 $ pro
                       Minute, einmal pro Lied. Läuft das Lied vor dem Herunterladen / Hochladen nicht mehr
                       (playerctl), wird abgebrochen – kurz angespielte Lieder kosten nichts.
Key: ~/.local/state/8155/openai.json (Rechte 600) oder Umgebungsvariable OPENAI_API_KEY.
"""

import difflib
import fcntl
import getpass
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/8155/lyrics")
KEY_FILE = os.path.expanduser("~/.local/state/8155/openai.json")
UA = "8155-quickshell/1.0 (https://github.com/quickshell-mirror/quickshell)"
YTDLP = shutil.which("yt-dlp") or os.path.expanduser("~/.local/bin/yt-dlp")
WHISPER_FORMATS = (".mp3", ".mp4", ".mpeg", ".mpga", ".m4a", ".wav", ".webm")
DAY = 86400


class NetError(Exception):
    """Netz/Server gerade nicht erreichbar → Ergebnis nicht speichern, später nochmal versuchen."""


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False), flush=True)


# ─────────────────────────── HTTP ───────────────────────────

def http(url, data=None, headers=None, timeout=15, retries=2):
    """→ (status, bytes). Wiederholt bei Überlastung (429/5xx) und Netzfehlern, andere 4xx kommen zurück."""
    h = {"User-Agent": UA}
    h.update(headers or {})
    err = ""
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h), timeout=timeout) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            if e.code < 500 and e.code != 429:
                return e.code, e.read()
            err = f"HTTP {e.code}"
        except (urllib.error.URLError, OSError) as e:
            err = str(e)
        if attempt < retries:
            time.sleep(1.5 * (attempt + 1))
    raise NetError(f"{url.split('?')[0]}: {err}")


def get_json(url, headers=None):
    status, body = http(url, headers=headers)
    if status != 200:
        return None
    try:
        return json.loads(body)
    except ValueError:
        return None


# ─────────────────────────── Namen vergleichen ───────────────────────────

def clean(s):
    """YouTube-Zusätze weg: „(Official Video)“, „[Lyrics]“, „- Topic“ …"""
    s = re.sub(r"\s*[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|live|hd|4k|mv)[^\)\]]*[\)\]]",
               "", s or "", flags=re.I)
    s = re.sub(r"\s*-\s*topic$", "", s, flags=re.I)
    return " ".join(s.split())


def split_title(artist, title):
    """YouTube & Co: „Interpret - Titel“ steckt oft komplett im Titel"""
    a, t = clean(artist), clean(title)
    channel_like = a == "" or re.search(r"topic|vevo|records|official", artist or "", re.I)
    if t.find(" - ") > 0 and (channel_like or t.lower().startswith(a.lower() + " - ")):
        parts = t.split(" - ")
        a, t = parts[0].strip(), " - ".join(parts[1:]).strip()
    return a, t


def simplify(t):
    """„Titel - Remastered 2011“, „Titel (feat. X)“ → „Titel“ (für Suchen)"""
    t = re.sub(r"\s+-\s+.*\b(remaster(ed)?|version|edit|mix|live|mono|stereo|acoustic|from)\b.*$", "", t, flags=re.I)
    t = re.sub(r"\s*[\(\[](feat|ft|with)\.?\s[^\)\]]*[\)\]]", "", t, flags=re.I)
    return t.strip()


def norm(s):
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = re.sub(r"[\(\[].*?[\)\]]", " ", s)
    s = re.sub(r"\b(feat|ft|featuring)\b.*", " ", s)
    s = re.sub(r"[^\w\s]", " ", s)
    return " ".join(s.split())


def similar(a, b):
    na, nb = norm(a), norm(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    if min(len(na), len(nb)) >= 4 and (na in nb or nb in na):
        return 0.9
    return difflib.SequenceMatcher(None, na, nb).ratio()


def title_in(title, text):
    """alle Wörter des Titels kommen im Text vor (z. B. YouTube-Titel „Interpret - Titel (Audio)“)"""
    words = norm(title).split()
    return bool(words) and set(words) <= set(norm(text).split()) or similar(title, text) >= 0.75


def artist_names(s):
    parts = re.split(r",|&|;|/|\bx\b|\bfeat\.?|\bft\.?|\bwith\b|\band\b|\bund\b", s or "", flags=re.I)
    return [n for n in (norm(p) for p in parts) if n]


def artist_match(artist, names):
    want = artist_names(artist)
    for name in names:
        for n in artist_names(name):
            for w in want:
                if n == w or difflib.SequenceMatcher(None, n, w).ratio() >= 0.8:
                    return True
                if min(len(n), len(w)) >= 4 and (n in w or w in n):
                    return True
    return False


# ─────────────────────────── LRC ───────────────────────────

STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
CREDIT = re.compile(r"^\s*(作词|作曲|编曲|制作人?|监制|混音|母带|和声|录音|吉他|贝斯|鼓|弦乐|出品|发行|统筹|企划|"
                    r"lyrics?|composer|producer|written|arranged|mixed|mastered)[^:：]{0,40}[:：]", re.I)


def tidy(lrc):
    """nur Zeilen mit Zeitstempel, ohne Mitwirkenden-Angaben am Anfang (NetEase) – None, wenn nicht synchronisiert"""
    out = []
    for raw in (lrc or "").splitlines():
        if not STAMP.search(raw):
            continue
        text = re.sub(r"\[[^\]]*\]", "", raw).strip()
        if len(out) < 12 and CREDIT.search(text):
            continue
        out.append(raw.strip())
    sung = [l for l in out if re.sub(r"\[[^\]]*\]", "", l).strip()]
    stamps = {s for l in out for s in STAMP.findall(l)}
    if len(sung) < 3 or len(stamps) < 3:
        return None
    return "\n".join(out)


def stamp(sec):
    sec = max(0.0, sec)
    m = int(sec // 60)
    return f"[{m:02d}:{sec - m * 60:05.2f}]"


# ─────────────────────────── Quellen ───────────────────────────

def from_lrclib(a, t, album, dur, hint):
    q = {"artist_name": a, "track_name": t}
    if album:
        q["album_name"] = album
    if dur > 0:
        q["duration"] = round(dur)
    d = get_json("https://lrclib.net/api/get?" + urllib.parse.urlencode(q))
    if d:
        if d.get("syncedLyrics"):
            return d["syncedLyrics"]
        if d.get("instrumental"):
            hint["instrumental"] = True
        if d.get("plainLyrics"):
            hint["plain"] = d["plainLyrics"]
    # Suche, bevorzugt passende Länge
    st = simplify(t)
    res = get_json("https://lrclib.net/api/search?" + urllib.parse.urlencode({"q": f"{a} {st}".strip()})) or []
    res = [r for r in res if isinstance(r, dict) and similar(r.get("trackName"), st) >= 0.6]
    res.sort(key=lambda r: abs((r.get("duration") or 0) - dur))
    for r in res:
        if dur > 0 and abs((r.get("duration") or 0) - dur) >= 8:
            break
        if r.get("syncedLyrics"):
            return r["syncedLyrics"]
        if r.get("plainLyrics") and "plain" not in hint:
            hint["plain"] = r["plainLyrics"]
    return None


def from_netease(a, t, dur, hint):
    ref = {"Referer": "https://music.163.com/"}
    st = simplify(t)
    d = get_json("https://music.163.com/api/cloudsearch/pc?" +
                 urllib.parse.urlencode({"s": f"{a} {st}".strip(), "type": 1, "limit": 10}), ref)
    for s in ((d or {}).get("result") or {}).get("songs") or []:
        if dur > 0 and abs((s.get("dt") or 0) / 1000 - dur) > 3:
            continue
        if not title_in(st, s.get("name") or ""):
            continue
        if a and not artist_match(a, [x.get("name") or "" for x in s.get("ar") or []]):
            continue
        ly = get_json("https://music.163.com/api/song/lyric?" + urllib.parse.urlencode({"id": s["id"], "lv": 1}), ref)
        lrc = ((ly or {}).get("lrc") or {}).get("lyric") or ""
        if "纯音乐" in lrc:                               # „reine Musik, bitte genießen“
            hint["instrumental"] = True
            return None
        good = tidy(lrc)
        if good:
            return good
    return None


def still_playing(title):
    """läuft das Lied noch in irgendeinem Player? (sonst lohnt sich Herunterladen/KI nicht)"""
    try:
        out = subprocess.run(["playerctl", "-a", "metadata", "--format", "{{title}}"],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return True
    return title.strip() in [l.strip() for l in out.splitlines()]


def ytdlp(*args, timeout=120):
    r = subprocess.run([YTDLP, "--js-runtimes", "node", "--no-warnings", *args],
                       capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise NetError("yt-dlp: " + (r.stderr.strip().splitlines() or ["Fehler"])[-1])
    return r.stdout


def youtube_pick(a, t, dur):
    """passendes YouTube-Video: Titel stimmt, Länge ±3 s; „… - Topic“ (Album-Audio) bevorzugt"""
    st = simplify(t)
    for q in (f"{a} {st}", f"{a} - {st} audio"):
        entries = json.loads(ytdlp("--flat-playlist", "-J", f"ytsearch8:{q}")).get("entries") or []
        best = None
        for e in entries:
            ed = e.get("duration") or 0
            if dur > 0 and (not ed or abs(ed - dur) > 3):
                continue
            if not title_in(st, e.get("title") or ""):
                continue
            ch = e.get("channel") or e.get("uploader") or ""
            score = abs(ed - dur) if dur > 0 else 0
            if ch.endswith(" - Topic"):
                score -= 2
            if a and artist_match(a, [ch.replace(" - Topic", "")]):
                score -= 1
            if best is None or score < best[0]:
                best = (score, e)
        if best:
            return best[1].get("url") or f"https://www.youtube.com/watch?v={best[1]['id']}"
    return None


def youtube_audio(url, workdir):
    ytdlp("-q", "--no-playlist", "-f", "bestaudio[ext=m4a]/bestaudio", "-o", os.path.join(workdir, "audio.%(ext)s"),
          url, timeout=300)
    files = [os.path.join(workdir, f) for f in os.listdir(workdir) if f.startswith("audio.")]
    if not files:
        raise NetError("yt-dlp: keine Audiodatei")
    path = files[0]
    if not path.endswith(WHISPER_FORMATS) or os.path.getsize(path) > 24_000_000:
        small = os.path.join(workdir, "klein.mp3")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", "16000", "-b:a", "48k", small],
                       check=True, timeout=180)
        path = small
    return path


def whisper(path, key, prompt):
    boundary = "golden" + secrets.token_hex(12)
    fields = [("model", "whisper-1"), ("response_format", "verbose_json"), ("temperature", "0"),
              ("timestamp_granularities[]", "segment"), ("timestamp_granularities[]", "word")]
    if prompt:
        fields.append(("prompt", prompt))
    body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
                    for k, v in fields)
    with open(path, "rb") as f:
        body += (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(path)}"\r\n'
                 f"Content-Type: application/octet-stream\r\n\r\n").encode() + f.read() + f"\r\n--{boundary}--\r\n".encode()
    status, resp = http("https://api.openai.com/v1/audio/transcriptions", data=body, timeout=300, retries=1,
                        headers={"Authorization": f"Bearer {key}",
                                 "Content-Type": f"multipart/form-data; boundary={boundary}"})
    if status != 200:
        try:
            msg = json.loads(resp)["error"]["message"]
        except (ValueError, KeyError, TypeError):
            msg = resp[:200].decode(errors="replace")
        raise NetError(f"OpenAI {status}: {msg}")
    return json.loads(resp)


# typische Whisper-Halluzinationen in Musik-Pausen
HALLU = re.compile(r"subtit|untertitel|amara\.org|for watching|fürs zuschauen|abonn|subscribe|titra|www\.|\.com\b"
                   r"|^\W*(music|musik|muzik[eë]?|instrumental|applause|applaus)\W*$", re.I)


def to_lrc(resp):
    """Whisper-Antwort → LRC: kurze Segmente als Zeile, lange an Pausen zwischen Wörtern geteilt"""
    words = sorted((w for w in resp.get("words") or [] if "start" in w), key=lambda w: w["start"])
    lines = []                                           # (anfang, ende, text)
    for s in resp.get("segments") or []:
        text = " ".join((s.get("text") or "").split())
        if not text.strip(" .,!?-…♪") or HALLU.search(text):
            continue
        if s.get("no_speech_prob", 0) > 0.6 and s.get("avg_logprob", 0) < -0.7:
            continue
        if s.get("compression_ratio", 0) > 2.6:         # Endlos-Wiederholung
            continue
        ws = [w for w in words if s["start"] - 0.1 <= w["start"] < s["end"]]
        if len(text) <= 42 or not ws:
            lines.append((ws[0]["start"] if ws else s["start"], ws[-1]["end"] if ws else s["end"], text))
            continue
        cur = []
        for w in ws:
            if cur:
                line = " ".join(x["word"].strip() for x in cur)
                gap = w["start"] - cur[-1]["end"]
                if gap > 0.7 or len(line) > 34 or (len(cur) >= 5 and gap > 0.3):
                    lines.append((cur[0]["start"], cur[-1]["end"], line))
                    cur = []
            cur.append(w)
        if cur:
            lines.append((cur[0]["start"], cur[-1]["end"], " ".join(x["word"].strip() for x in cur)))
    lines.sort(key=lambda l: l[0])
    if len({l[2].lower() for l in lines}) < 5:         # immer dieselbe erfundene Zeile = nichts erkannt
        return ""
    out = []
    for i, (start, end, text) in enumerate(lines):
        out.append(stamp(start) + text)
        nxt = lines[i + 1][0] if i + 1 < len(lines) else None
        if nxt is None or nxt - end > 3.5:                # Pause → leere Zeile, Text blendet aus
            out.append(stamp(end + 0.4))
    return "\n".join(out)


def transcribe(audio, key, prompt):
    """→ (lrc, erkannte Sprache). Kam mit Hinweistext nichts Brauchbares heraus, einmal ohne versuchen –
    ein Hinweis kann Whisper auf die falsche Sprache bringen."""
    for p in ([prompt, ""] if prompt else [""]):
        resp = whisper(audio, key, p)
        lrc = to_lrc(resp)
        if lrc:
            break
    return lrc, resp.get("language", "")


# ─────────────────────────── Zwischenspeicher ───────────────────────────

def openai_key():
    k = os.environ.get("OPENAI_API_KEY", "").strip()
    if k:
        return k
    try:
        with open(KEY_FILE) as f:
            return (json.load(f).get("api_key") or "").strip()
    except (OSError, ValueError, AttributeError):
        return ""


def ai_ready():
    return bool(openai_key()) and os.access(YTDLP, os.X_OK)


def cache_path(artist, title):
    a, t = split_title(artist, title)
    return os.path.join(CACHE_DIR, hashlib.sha1(f"{norm(a)}\n{norm(t)}".encode()).hexdigest() + ".json")


def cache_get(path, ai):
    try:
        with open(path) as f:
            d = json.load(f)
    except (OSError, ValueError):
        return None
    if d.get("lrc"):
        return d
    age = time.time() - d.get("time", 0)
    if d.get("ai_tried"):                                 # KI hat nichts gefunden (instrumental, kein Video …)
        return d if age < 30 * DAY else None
    return d if age < DAY and not ai else None            # ohne KI: morgen nochmal (oder sobald ein Key da ist)


def cache_put(path, **d):
    d["time"] = int(time.time())
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, ensure_ascii=False)
    os.replace(tmp, path)
    return d


# ─────────────────────────── Befehle ───────────────────────────

def find(raw_artist, raw_title, album="", dur=0.0):
    a, t = split_title(raw_artist, raw_title)
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = cache_path(raw_artist, raw_title)
    ai = ai_ready()
    hit = cache_get(path, ai)
    if hit:
        return emit({"source": hit.get("source", ""), "lrc": hit.get("lrc", "")})

    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)               # gleiches Lied läuft schon → warten, dann Ergebnis nehmen
        hit = cache_get(path, ai)
        if hit:
            return emit({"source": hit.get("source", ""), "lrc": hit.get("lrc", "")})

        meta = {"artist": a, "title": t, "duration": round(dur)}
        emit({"stage": "suche"})
        hint, errors = {}, []
        for name, fn in (("lrclib", lambda: from_lrclib(a, t, album, dur, hint)),
                         ("netease", lambda: from_netease(a, t, dur, hint))):
            try:
                lrc = fn()
            except NetError as e:
                errors.append(str(e))
                continue
            if lrc:
                cache_put(path, source=name, lrc=lrc, **meta)
                return emit({"source": name, "lrc": lrc})

        if hint.get("instrumental"):
            cache_put(path, source="", lrc="", ai_tried=True, **meta)
            return emit({"source": "", "lrc": ""})
        if not ai:
            if not errors:
                cache_put(path, source="", lrc="", ai_tried=False, **meta)
            return emit({"source": "", "lrc": "", **({"error": errors[0]} if errors else {})})

        # ── KI: Audio von YouTube → Whisper ──
        if not still_playing(raw_title):
            return emit({"source": "", "lrc": "", "error": "lied läuft nicht mehr"})
        emit({"stage": "audio"})
        try:
            url = youtube_pick(a, t, dur)
            if not url:
                cache_put(path, source="", lrc="", ai_tried=True, **meta)
                return emit({"source": "", "lrc": ""})
            with tempfile.TemporaryDirectory(prefix="golden-lyrics-") as work:
                audio = youtube_audio(url, work)
                if not still_playing(raw_title):
                    return emit({"source": "", "lrc": "", "error": "lied läuft nicht mehr"})
                emit({"stage": "ki"})
                signal.signal(signal.SIGTERM, signal.SIG_IGN)   # bezahlte Anfrage zu Ende führen
                # kein „Interpret – Titel“ als Hinweis: Whisper hat ihn nur wiederholt oder das Lied deshalb
                # für russisch gehalten (Gold AG, Vëllezërit Bajra)
                lrc, language = transcribe(audio, openai_key(), (hint.get("plain") or "")[:700])
        except (NetError, subprocess.SubprocessError, OSError, ValueError) as e:
            return emit({"source": "", "lrc": "", "error": str(e)})
        cache_put(path, source="ki" if lrc else "", lrc=lrc, ai_tried=True, video=url, language=language, **meta)
        return emit({"source": "ki" if lrc else "", "lrc": lrc})


def cmd_key(remove=False):
    if remove:
        try:
            os.remove(KEY_FILE)
            print("OpenAI-Key gelöscht.")
        except FileNotFoundError:
            print("Es war kein Key gespeichert.")
        return 0
    k = getpass.getpass("OpenAI-API-Key (wird nicht angezeigt): ").strip()
    if not k:
        print("Abgebrochen.")
        return 1
    if not k.startswith("sk-") or any(c.isspace() for c in k):
        print(f"Das sieht nicht nach einem OpenAI-Key aus (beginnt mit „{k[:6]}…“, ein Key beginnt mit „sk-“) – "
              "nicht gespeichert. Key auf https://platform.openai.com/api-keys kopieren und nochmal versuchen.")
        return 1
    try:
        status, _ = http("https://api.openai.com/v1/models", headers={"Authorization": f"Bearer {k}"}, retries=0)
    except NetError as e:
        status = 0
        print(f"Konnte den Key nicht prüfen ({e}) – speichere ihn trotzdem.")
    if status in (400, 401):
        print(f"Der Key ist ungültig (OpenAI meldet {status}) – nicht gespeichert.")
        return 1
    if status == 403:
        print("Hinweis: Der Key darf die Modell-Liste nicht lesen (eingeschränkter Key) – "
              "für die Songtexte braucht er Zugriff auf „Audio“ (/v1/audio).")
    os.makedirs(os.path.dirname(KEY_FILE), exist_ok=True)
    fd = os.open(KEY_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"api_key": k}, f)
    os.chmod(KEY_FILE, 0o600)
    print(f"Gespeichert in {KEY_FILE}." + (" Key ist gültig." if status == 200 else ""))
    if not os.access(YTDLP, os.X_OK):
        print("Achtung: yt-dlp fehlt – ohne kann die KI kein Audio holen.")
    return 0


def cmd_forget(artist, title):
    path = cache_path(artist, title)
    try:
        os.remove(path)
        print("Gespeicherter Songtext gelöscht – wird beim nächsten Abspielen neu gesucht.")
    except FileNotFoundError:
        print("Für dieses Lied war nichts gespeichert.")
    return 0


def cmd_info():
    print("OpenAI-Key:", "ja" if openai_key() else "nein (lyrics.py key)")
    print("yt-dlp:    ", YTDLP if os.access(YTDLP, os.X_OK) else "fehlt")
    counts, ki_min = {}, 0.0
    if os.path.isdir(CACHE_DIR):
        for f in os.listdir(CACHE_DIR):
            if not f.endswith(".json"):
                continue
            try:
                with open(os.path.join(CACHE_DIR, f)) as fh:
                    d = json.load(fh)
            except (OSError, ValueError):
                continue
            src = d.get("source") or "nichts gefunden"
            counts[src] = counts.get(src, 0) + 1
            if d.get("ai_tried") and d.get("video"):
                ki_min += (d.get("duration") or 240) / 60
    print("Gespeichert:", ", ".join(f"{n}× {s}" for s, n in sorted(counts.items())) or "nichts")
    print(f"KI bisher:   ca. {ki_min:.0f} min Audio ≈ {ki_min * 0.006:.2f} $")
    return 0


def cmd_line():
    """Aktuelle Zeile des laufenden Lieds aus dem Cache (für hyprlock; kein Netz, sperrt nie)."""
    r = subprocess.run(["playerctl", "metadata", "--format", "{{artist}}\n{{title}}\n{{position}}"],
                       capture_output=True, text=True)
    parts = r.stdout.split("\n")
    if r.returncode or len(parts) < 3 or not parts[2].strip().isdigit():
        return 0
    d = cache_get(cache_path(parts[0], parts[1]), True) or {}
    pos, line = int(parts[2]) / 1e6, ""
    for m in re.finditer(r"^\[(\d+):(\d+(?:\.\d+)?)\](.*)$", d.get("lrc", ""), re.M):
        if int(m[1]) * 60 + float(m[2]) > pos:
            break
        line = m[3].strip()
    print(line)
    return 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "find" and len(argv) >= 4:
        try:
            dur = float(argv[5]) if len(argv) > 5 else 0.0
        except ValueError:
            dur = 0.0
        try:
            find(argv[2], argv[3], argv[4] if len(argv) > 4 else "", dur)
        except Exception as e:                           # QML wartet auf eine Ergebniszeile
            emit({"source": "", "lrc": "", "error": f"{type(e).__name__}: {e}"})
        return 0
    if cmd == "key":
        return cmd_key("--remove" in argv)
    if cmd == "forget" and len(argv) >= 4:
        return cmd_forget(argv[2], argv[3])
    if cmd == "info":
        return cmd_info()
    if cmd == "line":
        return cmd_line()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
