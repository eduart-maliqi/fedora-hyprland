pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Termine fürs Kontrollzentrum: hypr/scripts/kalender.py liest alle Kalender aus der Evolution-Datenbank
// (das Google-Konto steckt dort über die GNOME-Online-Konten). Abgerufen wird beim Start und beim Öffnen des
// Kontrollzentrums (frühestens alle 60 s), danach alle 10 Minuten, solange es offen ist.
Singleton {
    id: svc

    property var events: []             // [{ title, start: Date, end: Date, startMs, endMs, allDay, cal }] nach Beginn sortiert
    property var byDay: ({})            // Tages-Schlüssel (JJJJMMTT) → Termine, die an diesem Tag stattfinden
    property bool loaded: false
    property string error: ""
    property real fetched: 0            // Date.now() des letzten erfolgreichen Abrufs
    readonly property string script: Theme.home + "/.config/hypr/scripts/kalender.py"

    function key(d) { return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate() }

    // "2026-11-04" / "2026-11-04T15:45" als lokale Zeit; new Date("2026-11-04") wäre UTC und damit einen Tag daneben
    function parse(s) {
        const m = s.match(/^(\d+)-(\d+)-(\d+)(?:T(\d+):(\d+))?$/)
        if (!m) return null
        return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] ?? 0), +(m[5] ?? 0))
    }

    function refresh(force) {
        if (proc.running) return
        if (!force && Date.now() - fetched < 60000) return
        proc.running = true
    }

    function apply(text) {
        let data
        try { data = JSON.parse(text) } catch (e) {
            error = "keine Antwort vom Kalender"
            return
        }
        error = data.error ?? ""
        if (error !== "" && (data.events ?? []).length === 0) return

        const evs = []
        const days = {}
        for (const e of data.events) {
            const start = parse(e.start)
            const end = parse(e.end)
            if (!start || !end) continue
            // ganztägig: end ist der letzte Tag (inklusive) → Ende = Mitternacht danach
            const endAt = e.allDay ? new Date(end.getFullYear(), end.getMonth(), end.getDate() + 1) : end
            const ev = { title: e.title, start: start, end: endAt, startMs: start.getTime(), endMs: endAt.getTime(),
                         allDay: e.allDay, cal: e.cal }
            evs.push(ev)
            // ein Termin über mehrere Tage steht an jedem seiner Tage (höchstens 62, falls einer ewig dauert)
            let d = new Date(start.getFullYear(), start.getMonth(), start.getDate())
            for (let i = 0; i < 62 && d.getTime() < endAt.getTime(); i++) {
                const k = key(d)
                ;(days[k] = days[k] ?? []).push(ev)
                d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
            }
        }
        events = evs
        byDay = days
        loaded = true
        fetched = Date.now()
    }

    Process {
        id: proc
        command: ["python3", svc.script, "45"]
        stdout: StdioCollector { onStreamFinished: svc.apply(text) }
    }

    Timer {
        interval: 600000
        repeat: true
        running: Ui.controlOpen
        onTriggered: svc.refresh(true)
    }

    Component.onCompleted: refresh(true)
}
