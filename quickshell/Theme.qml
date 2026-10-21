pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ★ 8155 – Farben & Schriften an einer Stelle
// Farbthemen, gewählt über das Wallpaper (Dateiname <thema>-<name>.jpg, siehe hypr/scripts/thema.sh),
// Farben je Thema in hypr/themen/<name>/farben.json (z. B. golden – Amber/Gold, mond – Mondlicht-Blau, glut – Glutrot).
// Umschalten: `qs ipc call theme set <name>` (macht thema.sh); beim Start gilt ~/.config/hypr/themen/aktiv.
// Beim Wechsel blenden die Farben weich über (wie das Wallpaper).
Singleton {
    id: theme

    readonly property string title: "8155"

    // Paletten aus ~/.config/hypr/themen/<name>/farben.json (die eine Quelle, bearbeitbar in der App „Wallpaper“);
    // golden steht hier nur als Rückfall, bis die Dateien gelesen sind. Neu einlesen: reload() (`qs ipc call theme reload`).
    property var palettes: ({
        golden: {
            accent: "#e3a142", accentSoft: "#f2c57c", accentDeep: "#b8792b",
            cream: "#ede6d6", muted: "#aab0aa", dim: "#98a19b", faint: "#7d8680", ink: "#12181e",
            onAccentMuted: "#4a3414", red: "#e0714f",
            base: [0.07, 0.09, 0.11], hover: [0.12, 0.14, 0.16], hair: [1, 1, 1, 0.08]
        }
    })
    readonly property var names: Object.keys(palettes).sort()

    property string name: "golden"
    readonly property var p: palettes[name] ?? palettes.golden

    property color accent: p.accent
    property color accentSoft: p.accentSoft
    property color accentDeep: p.accentDeep
    property color cream: p.cream
    property color muted: p.muted
    property color dim: p.dim
    property color faint: p.faint
    property color ink: p.ink
    property color onAccentMuted: p.onAccentMuted
    property color red: p.red
    property color glassBase: Qt.rgba(p.base[0], p.base[1], p.base[2], 1)
    property color glassHover: Qt.rgba(p.hover[0], p.hover[1], p.hover[2], 0.62)
    property color hairline: Qt.rgba(p.hair[0], p.hair[1], p.hair[2], p.hair[3])

    Behavior on accent { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on accentSoft { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on accentDeep { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on cream { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on muted { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on dim { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on faint { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on ink { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on onAccentMuted { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on red { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on glassBase { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on glassHover { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
    Behavior on hairline { ColorAnimation { duration: 1100; easing.type: Easing.InOutQuad } }

    readonly property color green: "#8fd18a"     // „verbunden“

    // Glas-Flächen (Blur kommt von Hyprland über layer_rule)
    readonly property color glass: glassA(0.50)
    readonly property color glassLight: glassA(0.26)
    readonly property color glassStrong: glassA(0.68)

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function accentA(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    function glassA(a) { return Qt.rgba(glassBase.r, glassBase.g, glassBase.b, a) }

    readonly property string serif: "Cormorant Garamond"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "Symbols Nerd Font"

    readonly property string home: Quickshell.env("HOME")

    function reload() { loader.running = true }

    Process {
        id: loader
        running: true
        command: ["python3", theme.home + "/.config/hypr/scripts/thema-bauen.py", "liste"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = {}
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue
                    try { const t = JSON.parse(line); all[t.name] = t } catch (e) {}
                }
                if (all.golden) theme.palettes = all
                active.running = true
            }
        }
    }

    Process {
        id: active
        command: ["readlink", theme.home + "/.config/hypr/themen/aktiv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().replace(/\/$/, "").split("/").pop()
                if (theme.palettes[n]) theme.name = n
            }
        }
    }
}
