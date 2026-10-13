import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Obere Leiste: [★ Titel · Interpret] ───✦── offene Apps ──✦─── [wlan bt ton 󰅀] [akku] [uhr]
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 45
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "golden-bar"

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // ── Netzwerk
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev ? (wifiDev.networks.values.find(n => n.connected) ?? null) : null
    readonly property var wiredDev: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    readonly property string netIcon: {
        if (wifiNet) {
            const s = wifiNet.signalStrength
            return s > 0.8 ? "󰤨" : s > 0.6 ? "󰤥" : s > 0.4 ? "󰤢" : s > 0.2 ? "󰤟" : "󰤯"
        }
        if (wiredDev) return "󰈀"
        return "󰤮"
    }

    // ── Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevice: Bluetooth.devices.values.find(d => d.connected) ?? null
    readonly property string btIcon: !(btAdapter?.enabled ?? false) ? "󰂲" : (btDevice ? "󰂱" : "󰂯")

    // ── Ton
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property string volIcon: (sink?.audio?.muted ?? false) ? "󰝟" : volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾"
    PwObjectTracker { objects: [bar.sink] }

    // ── Akku
    readonly property var battery: UPower.displayDevice
    readonly property real batteryPct: {
        const p = battery?.percentage ?? 0
        return p <= 1.0 ? p * 100 : p
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
                                     || battery?.state === UPowerDeviceState.FullyCharged
                                     || battery?.state === UPowerDeviceState.PendingCharge
    readonly property string batteryIcon: {
        if (charging) return "󰂄"
        const icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        return icons[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))]
    }

    // ── links: Now Playing
    Rectangle {
        id: nowPlaying
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 20
        width: npRow.implicitWidth + 20
        radius: height / 2
        color: npMouse.containsMouse || Ui.musicTopOn(bar.screen) ? Theme.glassHover : Theme.glass
        border.width: 1
        border.color: npMouse.containsMouse || Ui.musicTopOn(bar.screen) ? Theme.accentA(0.45) : Theme.hairline
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Row {
            id: npRow
            anchors.centerIn: parent
            spacing: 6

            Star {
                anchors.verticalCenter: parent.verticalCenter
                size: 10
                color: Theme.accent
                opacity: Media.playing ? 1 : 0.7
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.hasPlayer && Media.title !== "" ? Media.title : Theme.title
                color: Theme.cream
                font.family: Theme.serif
                font.italic: true
                font.weight: Font.Medium
                font.pixelSize: 13
                font.features: ({ "lnum": 1 })      // gleich hohe Ziffern (für „8155“ ohne Musik)
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220)
            }
            Text {
                visible: Media.hasPlayer && Media.artist !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                color: Theme.faint
                font.pixelSize: 12
            }
            Text {
                visible: Media.hasPlayer && Media.artist !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: Media.artist
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 13
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 160)
            }
        }

        MouseArea {
            id: npMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.MiddleButton) Media.active?.togglePlaying()
                else if (m.button === Qt.RightButton) Media.active?.next()
                else Ui.toggleMusic(bar.screen?.name ?? "")   // auf dem Bildschirm dieser Leiste
            }
        }
    }

    // ── Mitte: Sternenlinie mit den offenen Apps
    StarLine {
        anchors.fill: parent
        z: -1
        monitor: bar.hyprMonitor
        lineLeft: nowPlaying.x + nowPlaying.width + 14
        lineRight: rightRow.x - 14
    }

    // ── rechts: Status-Kapseln
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        // Kontrollzentrum: WLAN · Bluetooth · Ton (+ Blatt = Stromsparen, Mond = Nachtmodus, Fenster = freier Fenstermodus) – Klick klappt alles auf (ControlCenter.qml)
        Rectangle {
            id: control
            readonly property bool lit: controlMouse.containsMouse || Ui.controlOpen
            implicitHeight: 30
            width: controlRow.implicitWidth + 30
            radius: height / 2
            color: lit ? Theme.glassHover : Theme.glass
            border.width: 1
            border.color: lit ? Theme.accentA(0.45) : Theme.hairline
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            Row {
                id: controlRow
                anchors.centerIn: parent
                spacing: 13

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.netIcon
                    color: bar.wifiNet || bar.wiredDev ? Theme.accent : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                Text {
                    visible: bar.btAdapter !== null
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.btIcon
                    color: bar.btDevice ? Theme.green : ((bar.btAdapter?.enabled ?? false) ? Theme.accent : Theme.faint)
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                Text {
                    visible: bar.sink !== null
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.volIcon
                    color: (bar.sink?.audio?.muted ?? false) ? Theme.faint : Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                // nur sichtbar, solange eingeschaltet
                Text {
                    visible: PowerProfiles.profile === PowerProfile.PowerSaver
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌪"
                    color: Theme.green
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                Text {
                    visible: WindowMode.free
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰖲"
                    color: Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                Text {
                    visible: NightLight.on
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰖔"
                    color: Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 16
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅀"
                    rotation: Ui.controlOpen ? 180 : 0
                    color: control.lit ? Theme.accent : Theme.muted
                    font.family: Theme.icons
                    font.pixelSize: 16
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                id: controlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Ui.controlScreen = bar.screen
                    Ui.controlOpen = !Ui.controlOpen
                }
            }
        }

        // Claude-Code-Sitzung fertig und noch nicht angesehen: Klick springt hin, Rechtsklick = gesehen (ClaudeSessions.qml)
        Pill {
            visible: ClaudeSessions.waiting.length > 0
            icon: "󰚩"
            text: ClaudeSessions.waiting.length === 1 ? ClaudeSessions.waiting[0].dir : ClaudeSessions.waiting.length + " fertig"
            onClicked: m => m.button === Qt.RightButton ? ClaudeSessions.clear() : ClaudeSessions.focusFirst()
        }

        Pill {
            visible: bar.battery?.isPresent ?? false
            icon: bar.batteryIcon
            iconColor: bar.batteryPct < 15 && !bar.charging ? Theme.red : Theme.accent
            text: Math.round(bar.batteryPct) + "%"
            onClicked: {
                Ui.controlScreen = bar.screen
                Ui.controlOpen = !Ui.controlOpen
            }
        }

        Pill {
            icon: "󰥔"
            text: Qt.formatDateTime(clock.date, "HH:mm") + "  " + Qt.locale().dayName(clock.date.getDay(), Locale.ShortFormat).replace(".", "")
            onClicked: Ui.clockEnabled = !Ui.clockEnabled
        }
    }
}
