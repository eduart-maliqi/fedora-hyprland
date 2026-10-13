import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Kleine Lautstärke-Anzeige unten in der Mitte – erscheint kurz bei jeder Änderung
// (Lauter/Leiser/Stumm-Tasten, aber auch wenn eine App die Lautstärke ändert)
PanelWindow {
    id: osd
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors { bottom: true }
    margins { bottom: 64 }
    implicitWidth: 280
    implicitHeight: 46
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: card.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "golden-osd"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    property bool showing: false
    property bool armed: false          // beim Start nicht aufpoppen

    PwObjectTracker { objects: [osd.sink] }

    function pop() {
        if (!armed) return
        showing = true
        hide.restart()
    }

    onVolumeChanged: pop()
    onMutedChanged: pop()

    Timer { interval: 1500; running: true; onTriggered: osd.armed = true }
    Timer { id: hide; interval: 1400; onTriggered: osd.showing = false }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.hairline
        opacity: osd.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            id: icon
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            width: 20
            text: osd.muted || osd.volume <= 0 ? "󰝟" : osd.volume < 0.34 ? "󰕿" : osd.volume < 0.67 ? "󰖀" : "󰕾"
            color: osd.muted ? Theme.faint : Theme.accent
            font.family: Theme.icons
            font.pixelSize: 17
        }

        Rectangle {
            id: track
            anchors { left: icon.right; leftMargin: 12; right: pct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: parent.width * Math.min(1, osd.volume)
                height: parent.height
                radius: 2
                color: osd.muted ? Theme.faint : Theme.accent
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            id: pct
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            width: 34
            horizontalAlignment: Text.AlignRight
            text: osd.muted ? "stumm" : Math.round(osd.volume * 100) + "%"
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }
}
