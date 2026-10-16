import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

// Akku-Warnungen beim Entladen: bei 20 % und 10 % ein kleiner Hinweis unten in der Mitte (wie ModeOsd),
// bei 5, 4, 3, 2 und 1 % jedes Mal eine grosse Warnung in der Bildschirmmitte. Beides klickdurchlässig.
Scope {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property int pct: {
        const p = battery?.percentage ?? 100
        return Math.round(p <= 1.0 ? p * 100 : p)
    }
    readonly property bool discharging: battery?.state === UPowerDeviceState.Discharging

    property int last: -1               // -1 = noch kein Wert gesehen → beim Start nicht warnen
    property int shown: 0
    property bool big: false

    onPctChanged: {
        if (!(battery?.isPresent ?? false)) return
        if (discharging && last > 0) {
            // bei einem Sprung über mehrere Stufen zählt die dringendste
            const hit = [1, 2, 3, 4, 5, 10, 20].find(t => pct <= t && last > t)
            if (hit !== undefined) warn(hit)
        }
        last = pct
    }

    function warn(level) {
        shown = pct
        big = level <= 5
        hide.restart()
        card.show = true
    }

    Timer { id: hide; interval: root.big ? 6000 : 3500; onTriggered: card.show = false }

    QtObject {
        id: card
        property bool show: false
    }

    PanelWindow {
        id: small
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        anchors { bottom: true }
        margins { bottom: 64 }
        implicitWidth: smallRow.implicitWidth + 44
        implicitHeight: 52
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        visible: smallCard.opacity > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "golden-osd"

        Rectangle {
            id: smallCard
            anchors.fill: parent
            radius: height / 2
            color: Theme.glassStrong
            border.width: 1
            border.color: Theme.alpha(Theme.red, 0.7)
            opacity: card.show && !root.big ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                id: smallRow
                anchors.centerIn: parent
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰁺"
                    color: Theme.red
                    font.family: Theme.icons
                    font.pixelSize: 18
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "akku bei " + root.shown + " %  ·  bitte laden"
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }
    }

    PanelWindow {
        id: large
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        implicitWidth: 520
        implicitHeight: 280
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        visible: bigCard.opacity > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "golden-osd"

        Rectangle {
            id: bigCard
            anchors.fill: parent
            radius: 24
            color: Theme.glassStrong
            border.width: 2
            border.color: Theme.red
            opacity: card.show && root.big ? 1 : 0
            scale: opacity > 0 ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂃"
                    color: Theme.red
                    font.family: Theme.icons
                    font.pixelSize: 64
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.shown + " %"
                    color: Theme.cream
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: 72
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "akku fast leer  ·  jetzt laden"
                    color: Theme.red
                    font.family: Theme.mono
                    font.pixelSize: 16
                }
            }
        }
    }
}
