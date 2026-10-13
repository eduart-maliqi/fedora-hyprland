pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Claude-Code-Sitzungen, die fertig sind und auf dich warten (Kapsel in der Leiste, Bar.qml)
//   Die Auswertung macht ~/.config/hypr/scripts/claude-sessions.py (liest ~/.claude/sessions/*.json); hier wird sie
//   nur alle 2 s abgefragt. `waiting` = [{ pid, name, dir, address, since }, …], älteste zuerst.
//   Klick auf die Kapsel → focusFirst(), Rechtsklick → clear() (alle als gesehen markieren).
Singleton {
    id: root

    property var waiting: []
    property int busy: 0
    readonly property string script: Theme.home + "/.config/hypr/scripts/claude-sessions.py"

    // golden.focus_window holt auch versteckte Fenster zurück und schaltet den Workspace um
    function focusFirst() {
        if (waiting.length === 0) return
        Quickshell.execDetached(["hyprctl", "eval", "golden.focus_window(\"" + waiting[0].address + "\")"])
    }

    function clear() {
        ack.command = ["python3", "-I", script, "--ack-all"]
        ack.running = true
    }

    function parse(text) {
        try {
            const d = JSON.parse(text)
            busy = d.busy
            waiting = d.waiting
        } catch (e) {
            // halbfertige Ausgabe beim Beenden – beim nächsten Durchlauf stimmt es wieder
        }
    }

    Process {
        id: poll
        command: ["python3", "-I", root.script]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Process {
        id: ack
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
}
