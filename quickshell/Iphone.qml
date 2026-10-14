pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// iPhone-Spiegelung: AirPlay-Empfänger UxPlay als systemd-User-Dienst (hypr/scripts/iphone.sh)
//   Zustand kommt vom Dienst selbst (auch Super+Shift+A schaltet ihn) → regelmässig nachfragen.
//   qs ipc call iphone toggle
Singleton {
    id: root

    readonly property string script: Theme.home + "/.config/hypr/scripts/iphone.sh"
    property bool on: false

    function toggle() {
        Quickshell.execDetached([script, "toggle"])
        recheck.restart()
    }

    Process {
        id: poll
        command: [root.script, "status"]
        stdout: StdioCollector { onStreamFinished: root.on = text.trim() === "an" }
    }

    Timer {
        id: recheck
        interval: 600
        onTriggered: poll.running = true
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    IpcHandler {
        target: "iphone"
        function toggle(): void { root.toggle() }
    }
}
