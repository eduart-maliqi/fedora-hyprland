import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Desktop-Uhr oben rechts:
//          8155
//        22:15
//      ───────────
//   Montag · 6. Juli
// Klare Glasscheibe ohne Blur (Layer-Regel in hyprland.lua) – ein weicher Schatten hält die Schrift lesbar.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { top: true; right: true }
    margins { top: 22; right: 34 }
    implicitWidth: 450
    implicitHeight: 321
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}                      // klick-durchlässig → Klick landet auf dem Wallpaper
    visible: Ui.clockEnabled
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "golden-clock"

    // Helligkeit des Wallpapers hinter der Uhr (0–1, misst wallpaper.sh) → auf hellen Bildern (z. B. glut-fuji,
    // golden-manor) wird die dünne Datumszeile dunkel, sonst geht sie unter. Uhrzeit und Scheibe bleiben gleich.
    property real bgLight: 0
    readonly property bool onLight: bgLight > 0.6
    FileView {
        path: Theme.home + "/.local/state/8155/uhr-hintergrund"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.bgLight = Math.max(0, Math.min(1, parseFloat(text()) || 0))
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Theme.glassA(0.08)   // nur ein Hauch Tönung → Wallpaper scheint durch
        border.width: 1
        border.color: Theme.hairline

        Column {
            anchors.centerIn: parent
            spacing: 3

            // weicher Schatten unter der ganzen Schrift → lesbar auch vor hellen Wolken
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 0.7
                shadowVerticalOffset: 1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "8155"
                color: Theme.accent
                font.family: Theme.serif
                font.italic: true
                font.weight: Font.Medium
                font.pixelSize: 24
                font.letterSpacing: 4.5
                font.features: ({ "lnum": 1 })      // gleich hohe Ziffern statt Mediävalziffern
            }

            Text {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.cream
                font.family: "SF Pro Display"       // schlichte, dünne Ziffern (wie Sperrbildschirm am iPhone)
                font.weight: Font.Light
                font.pixelSize: 132
                renderType: Text.CurveRendering     // große Schrift als Vektor → saubere Kanten
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 285
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.accentA(0.55) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Item { width: 1; height: 12 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Qt.locale(), "dddd  ·  d. MMMM")
                // eigene Datumsfarbe pro Thema (Theme.palettes.*.clockDate), sonst dunkel auf hellen Bildern
                color: Theme.p.clockDate ?? (root.onLight ? Theme.ink : Theme.muted)
                font.weight: Theme.p.clockDate || root.onLight ? Font.Bold : Font.Normal
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 23
                font.letterSpacing: 3.75
                font.features: ({ "lnum": 1 })
            }
        }
    }
}
