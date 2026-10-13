import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth-Geräteliste (aufgeklappt im Kontrollzentrum)
//   Klick auf Gerät      → verbinden / trennen (neue Geräte: koppeln)
//   󰆴 beim Drüberfahren  → Gerät vergessen
//   „suchen“             → neue Geräte in der Nähe finden
Column {
    id: root
    spacing: 6

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property bool searching: adapter?.discovering ?? false

    readonly property var paired: Bluetooth.devices.values
        .filter(d => d.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // unbekannte Geräte nur während der Suche, und nur mit echtem Namen
    readonly property var found: searching
        ? Bluetooth.devices.values.filter(d => !d.paired && d.name !== "" && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name))
        : []

    // Suche stoppen, wenn die Liste zugeklappt wird
    onVisibleChanged: if (!visible && searching) adapter.discovering = false

    function iconFor(d) {
        const i = d.icon || ""
        if (/headset|headphone/.test(i)) return "󰋋"
        if (/speaker|audio/.test(i)) return "󰓃"
        if (/mouse/.test(i)) return "󰍽"
        if (/keyboard/.test(i)) return "󰌌"
        if (/phone/.test(i)) return "󰏲"
        if (/computer/.test(i)) return "󰌢"
        if (/gaming|joystick/.test(i)) return "󰊴"
        return "󰂯"
    }

    function statusFor(d) {
        if (d.pairing) return "koppelt …"
        if (d.state === BluetoothDeviceState.Connecting) return "verbindet …"
        if (d.state === BluetoothDeviceState.Disconnecting) return "trennt …"
        if (d.connected) {
            if (!d.batteryAvailable) return "verbunden"
            const b = d.battery <= 1 ? d.battery * 100 : d.battery
            return "verbunden  ·  " + Math.round(b) + " %"
        }
        return d.paired ? "getrennt" : "neu · klicken zum koppeln"
    }

    function activate(d) {
        if (!d.paired) {
            Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/bt-pair.sh " + d.address])
        } else if (d.connected) {
            d.disconnect()
        } else {
            d.connect()
        }
    }

    // Eine Gerätezeile
    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var dev: modelData

        width: root.width
        height: 42
        radius: 8
        color: dev.connected ? Theme.alpha(Theme.green, 0.08)
             : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            id: devIcon
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: root.iconFor(row.dev)
            color: row.dev.connected ? Theme.green : (row.dev.paired ? Theme.cream : Theme.muted)
            font.family: Theme.icons
            font.pixelSize: 18
        }

        Column {
            anchors { left: devIcon.right; leftMargin: 12; right: forget.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                text: row.dev.name || row.dev.address
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.statusFor(row.dev)
                color: row.dev.connected ? Theme.green : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(row.dev)
        }

        // vergessen (nur gekoppelte Geräte, beim Drüberfahren)
        Text {
            id: forget
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            visible: row.dev.paired
            opacity: rowMouse.containsMouse || forgetMouse.containsMouse ? 1 : 0
            text: "󰆴"
            color: forgetMouse.containsMouse ? Theme.red : Theme.faint
            font.family: Theme.icons
            font.pixelSize: 14
            Behavior on opacity { NumberAnimation { duration: 140 } }
            MouseArea {
                id: forgetMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.dev.forget()
            }
        }
    }

    // ── Hinweise
    Text {
        visible: !root.on
        leftPadding: 6
        text: "bluetooth ist aus"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
    }
    Text {
        visible: root.on && root.paired.length === 0 && root.found.length === 0
        leftPadding: 6
        text: root.searching ? "suche geräte in der nähe …" : "noch keine geräte – unten auf „suchen“"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
    }

    // ── Gekoppelte Geräte
    Repeater {
        model: root.on ? root.paired : []
        delegate: DeviceRow {}
    }

    // ── Neue Geräte in der Nähe
    Text {
        visible: root.found.length > 0
        leftPadding: 6
        topPadding: 4
        text: "in der nähe"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
    }
    Repeater {
        model: root.found
        delegate: DeviceRow {}
    }

    // ── Suchen
    Rectangle {
        visible: root.on
        width: searchRow.implicitWidth + 22
        height: 26
        radius: 13
        color: searchMouse.containsMouse || root.searching ? Theme.accentA(0.16) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: root.searching ? Theme.accentA(0.5) : Theme.hairline
        Behavior on color { ColorAnimation { duration: 140 } }

        Row {
            id: searchRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰑐"
                color: Theme.accent
                font.family: Theme.icons
                font.pixelSize: 13
                RotationAnimation on rotation {
                    running: root.searching
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1400
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.searching ? "suche läuft … (stoppen)" : "suchen"
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: searchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }
}
