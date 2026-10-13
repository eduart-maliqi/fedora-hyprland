import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Die „Sternenlinie“ in der Mitte der Leiste:
// eine hauchdünne Linie in der Akzentfarbe, darauf die offenen Fenster als App-Symbole (Taskleiste).
//   Klick         → zum Fenster wechseln; aktives Fenster anklicken → verstecken (wie bei Windows)
//   Mittelklick   → Fenster schließen
//   Mausrad       → Workspaces durchblättern
// Zwischen zwei Workspaces steht ein kleiner Stern. Fenster anderer Workspaces sind etwas blasser,
// versteckte (special:minimized) stehen ganz rechts und noch blasser.
Item {
    id: line
    property var monitor: null          // HyprlandMonitor dieser Leiste
    property real lineLeft: 0           // x-Bereich, den die Linie abdeckt
    property real lineRight: width
    readonly property int count: 10     // Workspaces fürs Mausrad

    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

    function goTo(id) {
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + id + " })" : "workspace " + id)
    }

    // ── Fenster ────────────────────────────────────────────────
    function wsName(t) { return t.workspace?.name ?? t.lastIpcObject?.workspace?.name ?? "" }
    function isHidden(t) { return wsName(t) === "special:minimized" }
    // Gruppe = Workspace-Nummer, versteckte ganz hinten
    function groupOf(t) { return isHidden(t) ? 1e6 : (t.workspace?.id ?? t.lastIpcObject?.workspace?.id ?? 0) }

    function addr(t) {
        const a = t.lastIpcObject?.address ?? t.address
        return a.startsWith("0x") ? a : "0x" + a
    }
    function iconFor(t) {
        const cls = t.wayland?.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || ""
        const e = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(e?.icon ?? cls, "application-x-executable")
    }

    function click(t) {
        if (t.activated && !isHidden(t)) {
            Quickshell.execDetached(["hyprctl", "eval",
                "hl.dispatch(hl.dsp.window.move({ window = 'address:" + addr(t) + "', workspace = 'special:minimized', follow = false }))"])
        } else {
            Quickshell.execDetached(["hyprctl", "eval", "golden.focus_window('" + addr(t) + "')"])
        }
    }
    function closeWindow(t) {
        if (t.wayland) t.wayland.close()
        else Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.window.close({ window = 'address:" + addr(t) + "' }))"])
    }

    // stabile Reihenfolge: nach Workspace, innerhalb eines Workspaces in Öffnungsreihenfolge
    ScriptModel {
        id: apps
        values: {
            const all = Hyprland.toplevels.values
            return all
                .filter(t => {
                    const ws = line.wsName(t)
                    return ws !== "" && (!ws.startsWith("special:") || ws === "special:minimized") && !Ui.skipWindow(t)
                })
                .sort((a, b) => (line.groupOf(a) - line.groupOf(b)) || (all.indexOf(a) - all.indexOf(b)))
        }
    }

    // ── Linie (links und rechts von den Symbolen, zu den Enden hin ausblendend)
    Rectangle {
        x: line.lineLeft
        width: cluster.x - 10 - line.lineLeft
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.55; color: Theme.accentA(0.22) }
            GradientStop { position: 1.0; color: Theme.accentA(0.55) }
        }
    }
    Rectangle {
        x: cluster.x + cluster.width + 10
        width: line.lineRight - x
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.accentA(0.55) }
            GradientStop { position: 0.45; color: Theme.accentA(0.22) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Deko-Sternchen entlang der Linie (wie ein Sternbild)
    Repeater {
        model: 14
        delegate: Star {
            required property int index
            readonly property bool leftSide: index < 7
            readonly property int k: leftSide ? index : index - 7
            readonly property real span: leftSide ? (cluster.x - 24 - line.lineLeft) : (line.lineRight - cluster.x - cluster.width - 24)
            readonly property real t: (k + 1) / 8
            size: [4, 6, 3.5, 7, 4, 5.5, 3][k]
            color: Theme.accentSoft
            opacity: 0.12 + 0.5 * (leftSide ? t : 1 - t) * ([0.5, 1, 0.4, 1, 0.6, 0.9, 0.5][k])
            x: leftSide ? line.lineLeft + span * t - size / 2
                        : cluster.x + cluster.width + 24 + span * t - size / 2
            y: (line.height - size) / 2 + (k % 2 === 0 ? -0.5 : 0.5)
            visible: span > 60
        }
    }

    // ── Offene Apps
    Row {
        id: cluster
        anchors.centerIn: parent
        height: parent.height
        spacing: 0

        // keine Fenster offen: ein einzelner leuchtender Stern hält die Linie zusammen
        Item {
            visible: apps.values.length === 0
            width: 26
            height: parent.height
            Star {
                anchors.centerIn: parent
                size: 17
                color: Theme.accent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.accent
                    shadowBlur: 0.9
                    shadowOpacity: 0.95
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 16
                }
            }
        }

        Repeater {
            model: apps

            delegate: Row {
                id: slot
                required property var modelData
                required property int index
                readonly property var tl: modelData
                readonly property bool hidden: line.isHidden(tl)
                readonly property bool active: tl.activated && !hidden
                readonly property bool onActiveWs: !hidden && line.groupOf(tl) === line.activeId
                readonly property bool newGroup: index > 0 && line.groupOf(apps.values[index - 1]) !== line.groupOf(tl)
                height: line.height

                // Trenner zwischen Workspaces
                Item {
                    visible: slot.newGroup
                    width: 14
                    height: parent.height
                    Star {
                        anchors.centerIn: parent
                        size: 5
                        color: Theme.accentSoft
                        opacity: 0.55
                    }
                }

                Item {
                    width: 30
                    height: parent.height

                    Rectangle {
                        id: bg
                        anchors.centerIn: parent
                        width: 26
                        height: 22
                        radius: 7
                        color: slot.active ? Theme.accentA(0.18)
                             : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.width: slot.active ? 1 : 0
                        border.color: Theme.accentA(0.55)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    IconImage {
                        anchors.centerIn: bg
                        anchors.verticalCenterOffset: -1
                        implicitSize: 16
                        source: line.iconFor(slot.tl)
                        opacity: slot.active || mouse.containsMouse ? 1 : (slot.hidden ? 0.4 : (slot.onActiveWs ? 0.92 : 0.55))
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    // Strich unter dem Symbol: breit = aktives Fenster, Punkt = auf diesem Workspace
                    Rectangle {
                        anchors { horizontalCenter: bg.horizontalCenter; bottom: bg.bottom; bottomMargin: 2 }
                        width: slot.active ? 10 : 3
                        height: 2
                        radius: 1
                        color: Theme.accent
                        opacity: slot.active ? 1 : (slot.onActiveWs ? 0.55 : 0)
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: m => m.button === Qt.MiddleButton ? line.closeWindow(slot.tl) : line.click(slot.tl)
                        onContainsMouseChanged: {
                            if (containsMouse) line.showTip(parent, slot.tl.title || "")
                            else line.hideTip(parent)
                        }
                    }
                }
            }
        }
    }

    // ── Fenstertitel beim Drüberfahren
    property Item tipItem: null
    property string tipText: ""
    property Item pendingItem: null
    property string pendingText: ""

    function showTip(item, text) {
        pendingItem = item
        pendingText = text
        if (tipItem) {
            // von Symbol zu Symbol: sofort umspringen
            tip.visible = false
            tipItem = item
            tipText = text
            tip.visible = text !== ""
        } else {
            tipDelay.restart()
        }
    }
    function hideTip(item) {
        if (pendingItem !== item) return
        pendingItem = null
        tipDelay.stop()
        tipLinger.restart()
    }

    Timer {
        id: tipDelay
        interval: 450
        onTriggered: {
            line.tipItem = line.pendingItem
            line.tipText = line.pendingText
            tip.visible = line.tipItem !== null && line.tipText !== ""
        }
    }
    Timer {
        id: tipLinger
        interval: 80
        onTriggered: if (line.pendingItem === null) {
            tip.visible = false
            line.tipItem = null
        }
    }

    PopupWindow {
        id: tip
        visible: false
        anchor.item: line.tipItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 4
        implicitWidth: Math.min(tipLabel.implicitWidth, 420) + 20
        implicitHeight: 24
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.glassA(0.94)
            border.width: 1
            border.color: Theme.accentA(0.35)

            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: line.tipText
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 420)
            }
        }
    }

    // Mausrad über der Linie → Workspaces durchblättern
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const dir = e.angleDelta.y > 0 ? -1 : 1
            const target = Math.max(1, Math.min(line.count, line.activeId + dir))
            if (target !== line.activeId) line.goTo(target)
        }
    }
}
