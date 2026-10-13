#!/usr/bin/env python3
"""Spotify-Anmeldung für das Musik-Panel (Quickshell: Spotify.qml / MusicPanel.qml).

  spotify-auth.py login [CLIENT_ID]   einmalig: öffnet den Browser, speichert die Tokens
                                      (ohne CLIENT_ID: die zuletzt benutzte)
  spotify-auth.py token [--refresh]   gibt ein gültiges Zugriffs-Token als JSON aus, erneuert es bei Bedarf
                                      → {"access_token": "…", "expires_at": <unix-sekunden>} oder {"error": "…"}
                                      --refresh: auf jeden Fall erneuern (Spotify hat das Token mit 401 abgelehnt)
  spotify-auth.py logout              Tokens löschen (Client-ID bleibt)

Ablauf: Authorization Code mit PKCE – kein Client Secret nötig.
Die App dazu legt man auf https://developer.spotify.com/dashboard an,
Redirect-URI genau: http://127.0.0.1:8898/callback
Zustand: ~/.local/state/8155/spotify.json (nur für den Benutzer lesbar).
"""

import base64
import fcntl
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

STATE = os.path.expanduser("~/.local/state/8155/spotify.json")
PORT = 8898
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
SCOPES = " ".join([
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "user-read-recently-played",
    "playlist-read-private",
    "playlist-read-collaborative",
    "user-library-read",
    "user-library-modify",
])


def load():
    try:
        with open(STATE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(data):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, STATE)


def post_token(form):
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=urllib.parse.urlencode(form).encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def store_tokens(data, tok):
    data["access_token"] = tok["access_token"]
    data["expires_at"] = int(time.time()) + int(tok.get("expires_in", 3600))
    if tok.get("refresh_token"):            # PKCE: Refresh-Token wird bei jeder Erneuerung ausgetauscht
        data["refresh_token"] = tok["refresh_token"]
    if tok.get("scope"):
        data["scope"] = tok["scope"]
    save(data)


PAGE = """<!doctype html><meta charset="utf-8"><title>8155 · spotify</title>
<body style="margin:0;height:100vh;display:grid;place-items:center;background:#12181e;color:#ede6d6;
font-family:'JetBrainsMono Nerd Font',monospace"><div style="text-align:center">
<div style="color:#e3a142;font-size:28px">★</div><p style="font-size:18px">{msg}</p>
<p style="color:#7d8680">du kannst diesen tab jetzt schließen.</p></div></body>"""


def login(client_id):
    data = load()
    client_id = client_id or data.get("client_id")
    if not client_id:
        sys.exit("Client-ID fehlt: spotify-auth.py login <CLIENT_ID>")

    verifier = secrets.token_urlsafe(64)[:128]
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": REDIRECT,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
        "scope": SCOPES,
        "state": state,
    })

    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if not self.path.startswith("/callback"):
                self.send_response(404)
                self.end_headers()
                return
            if q.get("state", [""])[0] != state:
                result["error"] = "state passt nicht"
            elif "error" in q:
                result["error"] = q["error"][0]
            else:
                result["code"] = q.get("code", [""])[0]
            ok = "code" in result
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "spotify ist verbunden ✓" if ok else "anmeldung fehlgeschlagen: " + result.get("error", "?")
            self.wfile.write(PAGE.format(msg=msg).encode())

        def log_message(self, *args):
            pass

    try:
        server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    except OSError as e:
        sys.exit(f"Port {PORT} ist belegt ({e}) – läuft schon eine Anmeldung?")
    server.timeout = 1

    print("Browser öffnet sich – bei Spotify anmelden und zustimmen.")
    print("Falls nicht, diese Adresse öffnen:\n" + url, flush=True)
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    deadline = time.time() + 300
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()

    if "code" not in result:
        sys.exit("Anmeldung fehlgeschlagen: " + result.get("error", "Zeit abgelaufen (5 min)"))

    tok = post_token({
        "grant_type": "authorization_code",
        "code": result["code"],
        "redirect_uri": REDIRECT,
        "client_id": client_id,
        "code_verifier": verifier,
    })
    data = {"client_id": client_id}
    store_tokens(data, tok)
    print("Fertig – Spotify ist verbunden.")


def token(force=False):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    # Sperre: zwei gleichzeitige Erneuerungen würden das Refresh-Token zweimal verbrauchen
    with open(STATE + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = load()
        if not data.get("refresh_token") or not data.get("client_id"):
            return {"error": "not_logged_in"}
        if not force and data.get("access_token") and data.get("expires_at", 0) - time.time() > 90:
            return {"access_token": data["access_token"], "expires_at": data["expires_at"]}
        try:
            tok = post_token({
                "grant_type": "refresh_token",
                "refresh_token": data["refresh_token"],
                "client_id": data["client_id"],
            })
        except urllib.error.HTTPError as e:
            try:
                err = json.load(e).get("error", "")
            except ValueError:
                err = ""
            return {"error": "invalid_grant" if err == "invalid_grant" else f"http_{e.code}"}
        except (urllib.error.URLError, OSError):
            return {"error": "offline"}
        store_tokens(data, tok)
        return {"access_token": data["access_token"], "expires_at": data["expires_at"]}


def logout():
    data = load()
    save({"client_id": data["client_id"]} if data.get("client_id") else {})


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "login":
        login(sys.argv[2].strip() if len(sys.argv) > 2 else None)
    elif cmd == "token":
        print(json.dumps(token("--refresh" in sys.argv)))
    elif cmd == "logout":
        logout()
    else:
        sys.exit(__doc__)
