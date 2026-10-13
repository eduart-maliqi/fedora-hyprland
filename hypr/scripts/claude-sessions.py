#!/usr/bin/env python3
# ★ 8155 – Claude-Code-Sitzungen: welche sind fertig und noch nicht angesehen? (für die Leiste, ClaudeSessions.qml)
#   claude-sessions.py            → JSON {"busy": n, "waiting": [{pid, name, dir, address, since}, …]}
#   claude-sessions.py --ack-all  → alle wartenden als gesehen markieren, dann wie oben
#
# Claude Code schreibt pro Sitzung ~/.claude/sessions/<pid>.json (status busy/idle, statusUpdatedAt, cwd) – Hooks sind
# nicht nötig. „Wartet auf dich“ = Sitzung wurde idle, nachdem du sie zuletzt gesehen hast. Gesehen = ihr Fenster war
# zu einem Abfragezeitpunkt das aktive. Beim ersten Kennenlernen gilt eine idle-Sitzung als gesehen (nach Neustart der
# Leiste meldet sich nicht alles Alte). Sitzungen ohne zuordenbares kitty-Fenster (z. B. IntelliJ-Terminal) werden
# ignoriert – man könnte sie nicht ansteuern.
# Zum Testen: CLAUDE_SESSIONS_DIR / CLAUDE_SEEN_FILE überschreiben die Pfade.
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
SESSIONS = os.environ.get("CLAUDE_SESSIONS_DIR", f"{HOME}/.claude/sessions")
SEEN = os.environ.get("CLAUDE_SEEN_FILE", f"{HOME}/.local/state/8155/claude-gesehen.json")


def hypr(what):
    try:
        out = subprocess.run(["hyprctl", what, "-j"], capture_output=True, text=True, timeout=2).stdout
        return json.loads(out)
    except Exception:
        return None


def stat_fields(pid):
    """(ppid, starttime) aus /proc/<pid>/stat; der Prozessname darf Leerzeichen/Klammern enthalten."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            rest = f.read().rsplit(")", 1)[1].split()
        return int(rest[1]), rest[19]
    except Exception:
        return None, None


def window_of(pid, by_pid):
    for _ in range(15):
        if pid in by_pid:
            return by_pid[pid]
        pid, _start = stat_fields(pid)
        if not pid or pid <= 1:
            return None
    return None


def main():
    ack_all = "--ack-all" in sys.argv[1:]
    try:
        with open(SEEN) as f:
            seen = json.load(f)
    except Exception:
        seen = {}

    clients = hypr("clients") or []
    by_pid = {c["pid"]: c["address"] for c in clients}
    active = (hypr("activewindow") or {}).get("address", "")

    found, busy, waiting = set(), 0, []
    try:
        names = os.listdir(SESSIONS)
    except OSError:
        names = []
    for fn in names:
        if not fn.endswith(".json"):
            continue
        try:
            with open(os.path.join(SESSIONS, fn)) as f:
                s = json.load(f)
            pid, status, updated = int(s["pid"]), s["status"], int(s["statusUpdatedAt"])
        except Exception:
            continue
        _ppid, start = stat_fields(pid)
        if start is None or str(s.get("procStart", start)) != start:
            continue                      # Prozess weg oder PID wiederverwendet
        key = f"{pid}:{start}"
        found.add(key)
        if status == "busy":
            busy += 1
            seen.setdefault(key, 0)       # später idle ⇒ neuer als 0 ⇒ ungesehen
            continue
        address = window_of(pid, by_pid)
        if address is None:
            continue
        if key not in seen or address == active or ack_all:
            seen[key] = updated
        if updated > seen[key]:
            cwd = s.get("cwd", "")
            waiting.append({
                "pid": pid,
                "name": s.get("name", ""),
                "dir": "~" if cwd == HOME else os.path.basename(cwd.rstrip("/")) or cwd,
                "address": address,
                "since": updated,
            })

    seen = {k: v for k, v in seen.items() if k in found}      # Beendetes vergessen
    try:
        os.makedirs(os.path.dirname(SEEN), exist_ok=True)
        with open(SEEN) as f:
            same = json.load(f) == seen
    except Exception:
        same = False
    if not same:
        with open(SEEN, "w") as f:
            json.dump(seen, f)

    waiting.sort(key=lambda w: w["since"])
    print(json.dumps({"busy": busy, "waiting": waiting}, ensure_ascii=False))


main()
