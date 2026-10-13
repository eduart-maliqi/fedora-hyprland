import QtQuick
import Quickshell
import Quickshell.Networking

// WLAN-Liste (aufgeklappt im Kontrollzentrum)
//   Klick auf Netzwerk   → verbinden (neue gesicherte Netze: Passwort direkt eingeben) / trennen
//   󰆴 beim Drüberfahren  → gespeichertes Netzwerk vergessen
Column {
    id: root
    spacing: 6

    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool on: Networking.wifiEnabled
    property string pwFor: ""           // Netzwerk, für das gerade das Passwort eingegeben wird
    property string failed: ""          // zuletzt fehlgeschlagene Verbindung

    // Umgebung nur absuchen, solange die Liste offen ist
    Binding {
        when: root.dev !== null
        target: root.dev
        property: "scannerEnabled"
        value: root.visible && root.on
        restoreMode: Binding.RestoreNone
    }
    onVisibleChanged: if (!visible) { pwFor = ""; failed = "" }

    ScriptModel {
        id: nets
        values: !root.dev ? [] : root.dev.networks.values
            .filter(n => n.name !== "")
            .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    }

    function signalIcon(s) {
        return s > 0.8 ? "󰤨" : s > 0.6 ? "󰤥" : s > 0.4 ? "󰤢" : s > 0.2 ? "󰤟" : "󰤯"
    }
    function secured(n) {
        if (!n) return false
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe
    }
    function statusFor(n) {
        if (!n) return ""
        if (n.stateChanging) return n.connected ? "trennt …" : "verbindet …"
        if (n.connected) return "verbunden"
        if (root.failed === n.name) return "fehlgeschlagen – nochmal klicken"
        if (n.known) return "gespeichert"
        return secured(n) ? "gesichert" : "offen"
    }
    function activate(n) {
        failed = ""
        if (n.connected) {
            n.disconnect()
        } else if (n.known || !secured(n)) {
            pwFor = ""
            n.connect()
        } else {
            pwFor = pwFor === n.name ? "" : n.name
        }
    }

    // ── Hinweise
    Text {
        visible: !root.on
        leftPadding: 6
        text: "wlan ist aus"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
    }
    Text {
        visible: root.on && nets.values.length === 0
        leftPadding: 6
        text: "suche netzwerke …"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
    }

    ListView {
        id: list
        visible: root.on
        width: root.width
        height: Math.min(contentHeight, 270)
        spacing: 2
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: nets

        delegate: Rectangle {
            id: row
            required property var modelData
            // verschwindet ein Netz beim Suchen, wird sein Objekt gelöscht und net kurz null → überall mit ?. lesen
            readonly property var net: modelData
            readonly property bool askPw: root.pwFor === (net?.name ?? "")

            width: list.width
            height: askPw ? 84 : 42
            radius: 8
            color: net?.connected ? Theme.alpha(Theme.green, 0.08)
                 : (askPw ? Theme.accentA(0.08)
                 : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"))
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Connections {
                target: row.modelData
                function onConnectionFailed() { root.failed = row.net?.name ?? "" }
            }

            MouseArea {
                id: rowMouse
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 42
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(row.net)
            }

            Text {
                id: sigIcon
                x: 10
                y: (42 - height) / 2
                text: root.signalIcon(row.net?.signalStrength ?? 0)
                color: row.net?.connected ? Theme.green : (row.net?.known ? Theme.cream : Theme.muted)
                font.family: Theme.icons
                font.pixelSize: 17
            }

            Column {
                anchors { left: sigIcon.right; leftMargin: 12; right: forget.left; rightMargin: 8 }
                y: (42 - height) / 2
                spacing: 2
                Row {
                    width: parent.width
                    spacing: 6
                    Text {
                        width: Math.min(implicitWidth, parent.width - (lock.visible ? lock.width + 6 : 0))
                        text: row.net?.name ?? ""
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        id: lock
                        visible: root.secured(row.net)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"
                        color: Theme.faint
                        font.family: Theme.icons
                        font.pixelSize: 10
                    }
                }
                Text {
                    width: parent.width
                    text: root.statusFor(row.net)
                    color: row.net?.connected ? Theme.green : (root.failed !== "" && root.failed === row.net?.name ? Theme.red : Theme.faint)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            // vergessen (nur gespeicherte Netze, beim Drüberfahren)
            Text {
                id: forget
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: (42 - height) / 2
                visible: row.net?.known ?? false
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
                    onClicked: row.net.forget()
                }
            }

            // Passwort für neue gesicherte Netze
            Row {
                visible: row.askPw
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                height: 28
                spacing: 6

                Rectangle {
                    width: parent.width - goBtn.width - parent.spacing
                    height: parent.height
                    radius: 7
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: 1
                    border.color: pw.activeFocus ? Theme.accentA(0.6) : Theme.hairline

                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.cream
                        selectionColor: Theme.accentDeep
                        font.family: Theme.mono
                        font.pixelSize: 12
                        clip: true
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                        onAccepted: goBtn.submit()
                        Keys.onEscapePressed: root.pwFor = ""

                        Text {
                            visible: pw.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "passwort"
                            color: Theme.faint
                            font: pw.font
                        }
                    }
                }

                Rectangle {
                    id: goBtn
                    width: 74
                    height: parent.height
                    radius: 7
                    color: goMouse.containsMouse ? Theme.accentSoft : Theme.accent
                    function submit() {
                        if (pw.text === "") return
                        row.net.connectWithPsk(pw.text)
                        root.pwFor = ""
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "verbinden"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: goMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: goBtn.submit()
                    }
                }
            }
        }
    }

    // ── weitere Einstellungen (NetworkManager-Editor)
    Text {
        leftPadding: 6
        text: "weitere einstellungen  󰁔"
        color: moreMouse.containsMouse ? Theme.accentSoft : Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Ui.controlOpen = false
                Quickshell.execDetached(["nm-connection-editor"])
            }
        }
    }
}
