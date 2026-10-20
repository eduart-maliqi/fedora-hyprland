pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ★ 8155 – Farben & Schriften an einer Stelle
// Farbthemen, gewählt über das Wallpaper (Dateiname <thema>-<name>.jpg, siehe hypr/scripts/thema.sh):
//   golden – Amber/Gold zu den hellen Bildern, mond – Mondlicht-Blau zu Nachtbildern,
//   glut – Glutrot zu dunklen, rot-schwarzen Bildern (Finsternis), kohle – Sonnengelb auf Anthrazit,
//   purpur – Neonpink auf Violett, lila – Lavendel auf Nachtviolett, silber – Silberweiß auf Schwarz.
// Umschalten: `qs ipc call theme set <name>` (macht thema.sh); beim Start gilt ~/.config/hypr/themen/aktiv.
// Beim Wechsel blenden die Farben weich über (wie das Wallpaper).
Singleton {
    id: theme

    readonly property string title: "8155"

    readonly property var palettes: ({
        golden: {
            accent: "#e3a142", accentSoft: "#f2c57c", accentDeep: "#b8792b",
            cream: "#ede6d6", muted: "#aab0aa", dim: "#98a19b", faint: "#7d8680", ink: "#12181e",
            onAccentMuted: "#4a3414",                 // Nebentext auf Akzent-Fläche (Interpret in der aktiven Zeile)
            red: "#e0714f",
            base: [0.07, 0.09, 0.11], hover: [0.12, 0.14, 0.16], hair: [1, 1, 1, 0.08]
        },
        mond: {
            accent: "#8cc0e4", accentSoft: "#cfe3f1", accentDeep: "#4b7aa3",
            cream: "#e3ebf2", muted: "#a2afbc", dim: "#8f9dab", faint: "#6e7d8c", ink: "#0b1219",
            onAccentMuted: "#23415a",
            red: "#e0714f",
            base: [0.04, 0.07, 0.11], hover: [0.09, 0.13, 0.19], hair: [0.85, 0.92, 1, 0.09]
        },
        glut: {
            accent: "#ef5a50", accentSoft: "#fdb59a", accentDeep: "#9e2f34",
            cream: "#ece5e3", muted: "#ada4a6", dim: "#9a9092", faint: "#776d70", ink: "#0d0b10",
            onAccentMuted: "#4a1518",
            red: "#ffb054",                           // Akzent ist schon rot → Warnungen orange, sonst nicht zu unterscheiden
            base: [0.07, 0.055, 0.07], hover: [0.14, 0.10, 0.12], hair: [1, 0.9, 0.9, 0.08]
        },
        kohle: {
            accent: "#e8a21c", accentSoft: "#f5c867", accentDeep: "#a8740f",
            cream: "#e8e6e1", muted: "#a9a8a4", dim: "#969591", faint: "#74736f", ink: "#121212",
            onAccentMuted: "#4a3306",
            red: "#e0714f",
            base: [0.08, 0.08, 0.085], hover: [0.15, 0.15, 0.155], hair: [1, 1, 1, 0.08]
        },
        silber: {
            accent: "#cfd6df", accentSoft: "#eef1f5", accentDeep: "#6b7684",
            cream: "#eceef1", muted: "#a6abb2", dim: "#959aa1", faint: "#70757c", ink: "#0c0d0f",
            onAccentMuted: "#3a414a",
            red: "#e0714f",
            base: [0.06, 0.065, 0.075], hover: [0.13, 0.135, 0.145], hair: [1, 1, 1, 0.08]
        },
        purpur: {
            accent: "#f2508a", accentSoft: "#f3b0d6", accentDeep: "#8f1f5a",
            clockDate: "#d6286e",                     // Datum der Desktop-Uhr: kräftiges Pink, lesbar auf hellem Rosa
            cream: "#f0e6ef", muted: "#b5a3b6", dim: "#a090a3", faint: "#7c6b80", ink: "#12071a",
            onAccentMuted: "#4d0f2c",
            red: "#ffb054",
            base: [0.08, 0.03, 0.11], hover: [0.15, 0.07, 0.19], hair: [1, 0.9, 1, 0.09]
        },
        lila: {
            accent: "#a66bff", accentSoft: "#d2b4ff", accentDeep: "#6b2fd6",
            cream: "#ece6f5", muted: "#aaa3ba", dim: "#978fa9", faint: "#736b85", ink: "#100820",
            onAccentMuted: "#2e1460",
            red: "#e0714f",
            base: [0.08, 0.04, 0.16], hover: [0.15, 0.09, 0.26], hair: [0.95, 0.88, 1, 0.10]
        }
    })

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

    Process {
        running: true
        command: ["readlink", theme.home + "/.config/hypr/themen/aktiv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().replace(/\/$/, "").split("/").pop()
                if (theme.palettes[n]) theme.name = n
            }
        }
    }
}
