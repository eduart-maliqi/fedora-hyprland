pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Synchronisierte Songtexte für den aktuellen MPRIS-Track; liefert die aktuelle + nächste Zeile
// samt Fortschritt innerhalb der Zeile. Gesucht wird von ~/.config/hypr/scripts/lyrics.py:
// Zwischenspeicher → lrclib.net → NetEase → KI (Audio von YouTube + OpenAI Whisper, nur mit Key).
// Pro Lied läuft ein eigener Prozess; wechselt das Lied, läuft er weiter und landet im Cache.
Singleton {
    id: svc

    property var lines: []              // [{ t: Sekunden, text: "…" }]
    property string status: "idle"      // idle | loading | ok | none
    property string stage: ""           // während „loading“: suche | audio | ki
    property string source: ""          // woher der Text kommt: lrclib | netease | ki
    property string trackKey: ""
    property var cache: ({})            // trackKey → { lines, source } (nur Treffer – „nichts“ merkt sich das Skript)
    property var pending: ({})          // trackKey → true, solange die Suche dafür läuft
    property real leadIn: 0.25          // Zeilen minimal früher zeigen
    readonly property string script: Theme.home + "/.config/hypr/scripts/lyrics.py"

    readonly property real pos: Media.position + leadIn
    readonly property int index: {
        const ls = lines
        if (ls.length === 0 || pos < ls[0].t) return -1
        let lo = 0, hi = ls.length - 1
        while (lo < hi) {
            const mid = (lo + hi + 1) >> 1
            if (ls[mid].t <= pos) lo = mid; else hi = mid - 1
        }
        return lo
    }
    readonly property string current: index >= 0 ? lines[index].text : ""
    readonly property string next: index + 1 < lines.length ? lines[index + 1].text : ""
    // 0..1 – wie weit wir in der aktuellen Zeile sind (für den Schreibmaschinen-Effekt)
    readonly property real progress: {
        if (index < 0) return 0
        const start = lines[index].t
        const end = index + 1 < lines.length ? lines[index + 1].t : start + 4
        return Math.max(0, Math.min(1, (pos - start) / Math.max(0.5, end - start)))
    }

    function parseLrc(lrc) {
        const out = []
        const stampRe = /\[(\d+):(\d+(?:\.\d+)?)\]/g
        for (const raw of (lrc || "").split("\n")) {
            const text = raw.replace(/\[[^\]]*\]/g, "").trim()
            stampRe.lastIndex = 0
            let m
            while ((m = stampRe.exec(raw)) !== null)
                out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: text })
        }
        out.sort((a, b) => a.t - b.t)
        return out
    }

    function finish(key, src, lrc) {
        const parsed = parseLrc(lrc)
        if (parsed.length > 0) cache[key] = { lines: parsed, source: src }
        if (key !== trackKey) return
        lines = parsed
        source = parsed.length > 0 ? src : ""
        stage = ""
        status = parsed.length > 0 ? "ok" : "none"
    }

    function fetchFor(artist, title, album, length) {
        const key = artist + "\u0001" + title
        trackKey = key
        const c = cache[key]
        if (c !== undefined) {
            lines = c.lines
            source = c.source
            stage = ""
            status = lines.length > 0 ? "ok" : "none"
            return
        }
        lines = []
        source = ""
        stage = "suche"
        status = "loading"
        if (pending[key]) return            // läuft schon (kurz weg- und wieder zurückgesprungen)
        pending[key] = true
        const p = searchProc.createObject(svc, {
            key: key,
            command: ["python3", script, "find", artist, title, album || "", String(Math.round(length || 0))]
        })
        p.running = true
    }

    Component {
        id: searchProc
        Process {
            id: proc
            property string key
            property bool done: false
            stdout: SplitParser {
                onRead: data => {
                    let d = null
                    try { d = JSON.parse(data) } catch (e) { return }
                    if (d.stage !== undefined) {
                        if (proc.key === svc.trackKey && svc.status === "loading") svc.stage = d.stage
                        return
                    }
                    proc.done = true
                    if (d.error) console.log("lyrics.py:", d.error)
                    svc.finish(proc.key, d.source || "", d.lrc || "")
                }
            }
            // erst nach dem letzten gelesenen stdout aufräumen
            onExited: Qt.callLater(() => {
                delete svc.pending[proc.key]
                if (!proc.done) svc.finish(proc.key, "", "")
                proc.destroy()
            })
        }
    }

    // Track-Wechsel erkennen (kurz entprellen – Metadaten kommen oft stückweise)
    readonly property string wanted: Media.hasPlayer && Media.title !== "" ? Media.artist + "\u0001" + Media.title : ""
    onWantedChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 400
        onTriggered: {
            if (svc.wanted === "") {
                svc.lines = []
                svc.status = "idle"
                svc.trackKey = ""
            } else if (svc.wanted !== svc.trackKey) {
                svc.fetchFor(Media.artist, Media.title, Media.album, Media.length)
            }
        }
    }
}
