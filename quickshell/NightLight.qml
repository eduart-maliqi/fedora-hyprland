pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Nachtmodus (Blaulichtfilter) über hyprsunset
//   Geschaltet wird per `hyprctl hyprsunset temperature <K>` bzw. `… identity` (= aus).
//   hyprsunset kann nicht melden, ob der Filter an ist → Zustand (an/aus, Wärme) liegt hier und in
//   ~/.local/state/8155/nachtmodus.json, damit er Neustarts übersteht.
//   Läuft hyprsunset nicht, wird es neutral gestartet (`hyprsunset --identity`).
Singleton {
    id: night

    readonly property bool on: store.on
    readonly property int temperature: store.temperature
    readonly property int warmest: 2500      // Regler ganz rechts
    readonly property int coolest: 5500      // Regler ganz links (kaum sichtbar)

    // Regler-Wert 0..1 (rechts = wärmer)
    readonly property real strength: (coolest - temperature) / (coolest - warmest)

    function toggle() { setOn(!store.on) }
    function setOn(v) {
        store.on = v
        apply()
    }
    function setStrength(s) {
        const k = coolest - Math.max(0, Math.min(1, s)) * (coolest - warmest)
        store.temperature = Math.round(k / 50) * 50
        if (store.on) applyLater.restart()
    }

    // hyprsunset bei Bedarf starten und kurz nachfassen, bis sein Socket bereit ist
    function apply() {
        const cmd = store.on ? "temperature " + store.temperature : "identity"
        Quickshell.execDetached(["sh", "-c",
            "pgrep -x hyprsunset >/dev/null || (hyprsunset --identity >/dev/null 2>&1 &); " +
            "for i in $(seq 1 20); do [ \"$(hyprctl hyprsunset " + cmd + " 2>/dev/null)\" = ok ] && exit 0; sleep 0.25; done; exit 1"])
    }

    // Regler ziehen → nicht bei jedem Pixel einen Prozess starten
    Timer {
        id: applyLater
        interval: 80
        onTriggered: night.apply()
    }

    FileView {
        id: file
        path: Theme.home + "/.local/state/8155/nachtmodus.json"
        onAdapterUpdated: writeAdapter()
        onLoaded: if (store.on) night.apply()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) mkdir.running = true }

        JsonAdapter {
            id: store
            property bool on: false
            property int temperature: 4000
        }
    }

    // erster Start: Ordner anlegen, dann Standardwerte schreiben
    Process {
        id: mkdir
        command: ["mkdir", "-p", Theme.home + "/.local/state/8155"]
        onExited: file.writeAdapter()
    }

    // qs ipc call night toggle | enable | disable
    IpcHandler {
        target: "night"
        function toggle(): void { night.toggle() }
        function enable(): void { night.setOn(true) }
        function disable(): void { night.setOn(false) }
    }
}
