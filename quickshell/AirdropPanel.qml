import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AirDrop-Fenster (Klick auf die 󰀃-Kapsel in der Leiste, Zustand und Befehle in Airdrop.qml)
//   Kachel oben       AirDrop an/aus: 10 min sichtbar für alle (WLAN ist solange getrennt – Intel-Karte)
//   Ablagefläche      Dateien/Bilder hineinziehen oder klicken (Dateiauswahl) → liegen bereit
//   Geräte            Gerät anklicken = bereitliegende Dateien senden; Dateien direkt aufs Gerät ziehen = sofort senden
//   unten             Ordner mit empfangenen Dateien (~/airdrop)
//   Schließen: 󰅖, Esc, nochmal auf die Kapsel oder Klick aufs Wallpaper
PanelWindow {
    id: root
    screen: Ui.controlScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    anchors { top: true; right: true }
    margins { top: 6; right: 10 }
    implicitWidth: 340
    implicitHeight: card.implicitHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    visible: Ui.airdropOpen || card.opacity > 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "golden-airdrop"
    WlrLayershell.keyboardFocus: Ui.airdropOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function clock(s) {
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    function deviceIcon(name) {
        if (/ipad/i.test(name)) return "󰓶"
        if (/mac/i.test(name)) return "󰌢"
        return "󰄜"
    }

    function signalIcon(rssi) {
        if (rssi === null || rssi === undefined) return "󰢿"
        return rssi > -60 ? "󰢾" : rssi > -75 ? "󰢽" : "󰢼"
    }

    Process {
        id: chooser
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=airdrop: dateien wählen"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(p => p !== "")
                if (list.length) Airdrop.staged = list
            }
        }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 28
        radius: 14
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.hairline
        opacity: Ui.airdropOpen ? 1 : 0
        scale: Ui.airdropOpen ? 1 : 0.97
        transformOrigin: Item.TopRight
        focus: true
        Keys.onEscapePressed: Ui.airdropOpen = false
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            id: content
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            // Kopf
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Star {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 10
                        color: Theme.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "airdrop"
                        color: Theme.cream
                        font.family: Theme.serif
                        font.italic: true
                        font.weight: Font.Medium
                        font.pixelSize: 18
                        font.letterSpacing: 1
                    }
                }

                Text {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "󰅖"
                    color: closeMouse.containsMouse ? Theme.accent : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 14
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.airdropOpen = false
                    }
                }
            }

            // an/aus
            Rectangle {
                id: tile
                readonly property bool on: Airdrop.receiving
                width: parent.width
                height: 58
                radius: 12
                color: on ? Theme.accentA(tileMouse.containsMouse ? 0.22 : 0.15)
                          : Qt.rgba(1, 1, 1, tileMouse.containsMouse ? 0.08 : 0.05)
                border.width: 1
                border.color: on ? Theme.accentA(0.45) : Theme.hairline
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                    id: tileIcon
                    anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter }
                    text: "󰀃"
                    color: tile.on ? Theme.accent : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 19
                }

                Column {
                    anchors { left: tileIcon.right; leftMargin: 11; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: Airdrop.switching ? (tile.on ? "schaltet aus …" : "startet den funk …")
                            : !tile.on ? "aus"
                            : Airdrop.discoverable ? "sichtbar für alle" : "startet den funk …"
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Airdrop.radioMissing ? "funk-treiber fehlt (paket omdrop-owl)"
                            : Airdrop.error !== "" ? Airdrop.error
                            : tile.on ? "als „" + Airdrop.name + "“" + (Airdrop.remaining > 0 ? "  ·  noch " + root.clock(Airdrop.remaining) : "")
                            : "10 min einschalten  ·  wlan ist solange getrennt"
                        color: Airdrop.radioMissing || Airdrop.error !== "" ? Theme.red : tile.on ? Theme.accentSoft : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Airdrop.switching ? Qt.BusyCursor : Qt.PointingHandCursor
                    onClicked: Airdrop.toggle()
                }
            }

            // Ablagefläche
            Rectangle {
                id: dropZone
                readonly property bool hot: dropArea.containsDrag || zoneMouse.containsMouse
                readonly property int count: Airdrop.staged.length
                width: parent.width
                height: 92
                radius: 12
                color: dropArea.containsDrag ? Theme.accentA(0.18) : Qt.rgba(1, 1, 1, hot ? 0.07 : 0.04)
                border.width: 1
                border.color: dropArea.containsDrag ? Theme.accentA(0.8) : count > 0 ? Theme.accentA(0.45) : Theme.hairline
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 5
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dropZone.count > 0 ? "󰈙" : "󰁅"
                        color: dropZone.hot || dropZone.count > 0 ? Theme.accent : Theme.muted
                        font.family: Theme.icons
                        font.pixelSize: 24
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: dropZone.count === 0 ? "dateien hierher ziehen"
                            : dropZone.count === 1 ? Airdrop.staged[0].replace(/^.*\//, "")
                            : dropZone.count + " dateien bereit"
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: dropZone.count === 0 ? "oder klicken zum auswählen" : "gerät anklicken zum senden"
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: zoneMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!chooser.running) chooser.running = true
                }

                // ✕ = bereitliegende Dateien verwerfen
                Text {
                    visible: dropZone.count > 0
                    anchors { right: parent.right; top: parent.top; margins: 9 }
                    text: "󰅖"
                    color: clearMouse.containsMouse ? Theme.accent : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 13
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Airdrop.staged = []
                    }
                }

                // immer als Kopie annehmen: bei „verschieben“ würde Nautilus die Quelldatei löschen
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onEntered: drag => drag.accept(Qt.CopyAction)
                    onDropped: drop => {
                        const list = Airdrop.paths(drop.urls)
                        if (list.length) Airdrop.staged = list
                        drop.accept(Qt.CopyAction)
                    }
                }
            }

            // Geräte
            Text {
                leftPadding: 2
                text: "geräte in der nähe"
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 1
            }

            Column {
                width: parent.width
                spacing: 6

                Repeater {
                    model: Airdrop.discoverable ? Airdrop.peers : []

                    delegate: Rectangle {
                        id: peer
                        required property var modelData
                        readonly property string mac: modelData?.mac ?? ""
                        readonly property string name: Airdrop.names[mac] ?? ""
                        readonly property bool target: Airdrop.sendTo === mac && Airdrop.sendStatus !== ""
                        readonly property bool hot: peerDrop.containsDrag || (peerMouse.containsMouse && Airdrop.staged.length > 0)

                        width: parent.width
                        height: 46
                        radius: 11
                        color: hot ? Theme.accentA(0.18) : Qt.rgba(1, 1, 1, peerMouse.containsMouse ? 0.08 : 0.05)
                        border.width: 1
                        border.color: hot || target ? Theme.accentA(0.7) : Theme.hairline
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            id: peerIcon
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: root.deviceIcon(peer.name)
                            color: Theme.accent
                            font.family: Theme.icons
                            font.pixelSize: 18
                        }

                        Column {
                            anchors { left: peerIcon.right; leftMargin: 11; right: peerSignal.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                width: parent.width
                                text: peer.name !== "" ? peer.name : "gerät in der nähe"
                                color: peer.name !== "" ? Theme.cream : Theme.muted
                                font.family: Theme.mono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: peer.target ? Airdrop.sendStatus
                                    : Airdrop.staged.length > 0 ? "klicken = senden"
                                    : peer.name === "" ? "name wird abgefragt …" : ""
                                color: peer.target && Airdrop.sendFailed ? Theme.red
                                     : peer.target && !Airdrop.sending ? Theme.green
                                     : peer.target ? Theme.accentSoft : Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: peerSignal
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: peer.target && Airdrop.sending ? "󰅖" : root.signalIcon(peer.modelData?.rssi)
                            color: peer.target && Airdrop.sending ? Theme.muted : Theme.faint
                            font.family: Theme.icons
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: peerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (peer.target && Airdrop.sending) Airdrop.cancelSend()
                                else if (Airdrop.staged.length > 0) Airdrop.send(peer.mac, Airdrop.staged)
                                else if (!chooser.running) chooser.running = true
                            }
                        }

                        DropArea {
                            id: peerDrop
                            anchors.fill: parent
                            onEntered: drag => drag.accept(Qt.CopyAction)
                            onDropped: drop => {
                                const list = Airdrop.paths(drop.urls)
                                drop.accept(Qt.CopyAction)
                                if (list.length) {
                                    Airdrop.staged = list
                                    Airdrop.send(peer.mac, list)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !Airdrop.discoverable || Airdrop.peers.length === 0
                    width: parent.width
                    leftPadding: 2
                    wrapMode: Text.WordWrap
                    text: !Airdrop.receiving ? "airdrop einschalten, dann erscheinen hier iphones und macs"
                        : !Airdrop.discoverable ? "funk startet …"
                        : "suche … – auf dem iphone airdrop öffnen oder auf „für alle“ stellen"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }

            // Hinweise + Ordner
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            Column {
                width: parent.width
                spacing: 4
                Text {
                    width: parent.width
                    leftPadding: 2
                    text: "iphone → laptop: teilen › airdrop › „" + (Airdrop.name || "8155-Laptop") + "“"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    leftPadding: 2
                    text: "laptop → iphone: dort airdrop „für alle (10 min)“"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: 10
                color: Qt.rgba(1, 1, 1, folderMouse.containsMouse ? 0.08 : 0.04)
                border.width: 1
                border.color: folderMouse.containsMouse ? Theme.accentA(0.45) : Theme.hairline

                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 9
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰉍"
                        color: Theme.accent
                        font.family: Theme.icons
                        font.pixelSize: 15
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "empfangen  ·  " + (Airdrop.dir || Theme.home + "/airdrop").replace(Theme.home, "~")
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: folderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.airdropOpen = false
                        Quickshell.execDetached(["xdg-open", Airdrop.dir || Theme.home + "/airdrop"])
                    }
                }
            }
        }
    }
}
