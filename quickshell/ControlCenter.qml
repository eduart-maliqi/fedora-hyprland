import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Kontrollzentrum (Klick auf die Status-Kapsel rechts in der Leiste)
//   WLAN / Bluetooth    Kachel anklicken → an/aus,  󰅀 → Liste aufklappen
//   Stromsparen         Kachel → Energieprofil Stromsparen an/aus,  󰅀 → alle Profile (tuned-ppd)
//   Nachtmodus          Kachel → Blaulichtfilter an/aus,  󰅀 → Wärme einstellen (NightLight.qml / hyprsunset)
//   iPhone spiegeln     Kachel → AirPlay-Empfänger an/aus (Iphone.qml / UxPlay)
//   Lautstärke / Hell.  Schieberegler (auch Mausrad), Lautsprecher-Symbol → stumm
//   Kalender            heute + 1 Monat mit Terminen (CalendarView.qml), Tag anklicken → seine Termine
//   unten               Akku-Details, sperren, Power-Menü
//   Schließen: 󰅖, Esc, nochmal auf die Kapsel oder Klick aufs Wallpaper
PanelWindow {
    id: root
    screen: Ui.controlScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    anchors { top: true; right: true }
    margins { top: 6; right: 10 }
    implicitWidth: 360
    implicitHeight: card.implicitHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    visible: Ui.controlOpen || card.opacity > 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "golden-control"
    // OnDemand: Tastatur erst nach einem Klick hinein (fürs WLAN-Passwort und Esc)
    WlrLayershell.keyboardFocus: Ui.controlOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: if (!visible) Ui.controlSection = ""

    // ── Netzwerk
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev ? (wifiDev.networks.values.find(n => n.connected) ?? null) : null
    readonly property var wiredDev: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property string wifiIcon: {
        if (!Networking.wifiEnabled) return "󰤮"
        if (!wifiNet) return "󰤯"
        const s = wifiNet.signalStrength
        return s > 0.8 ? "󰤨" : s > 0.6 ? "󰤥" : s > 0.4 ? "󰤢" : s > 0.2 ? "󰤟" : "󰤯"
    }

    // ── Bluetooth
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt?.enabled ?? false
    readonly property var btDevice: Bluetooth.devices.values.find(d => d.connected) ?? null

    // ── Ton
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    PwObjectTracker { objects: [root.sink] }

    // ── Helligkeit (brightnessctl; Laptop-Tasten ändern sie auch → solange offen jede Sekunde nachlesen)
    property real brightness: 0
    Process {
        id: brightRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                if (f.length >= 5 && Number(f[4]) > 0) root.brightness = Number(f[2]) / Number(f[4])
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: Ui.controlOpen
        onTriggered: if (!brightSlider.pressed) brightRead.running = true
    }
    function setBrightness(v) {
        brightness = v
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(v * 100)) + "%"])
    }

    // ── Akku
    readonly property var battery: UPower.displayDevice
    readonly property real batteryPct: {
        const p = battery?.percentage ?? 0
        return p <= 1.0 ? p * 100 : p
    }
    function duration(s) {
        const h = Math.floor(s / 3600)
        const m = Math.round((s % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }
    readonly property string batteryText: {
        const st = battery?.state
        let t = Math.round(batteryPct) + " %"
        if (st === UPowerDeviceState.FullyCharged) return t + "  ·  voll"
        if (st === UPowerDeviceState.Charging)
            return t + "  ·  lädt" + ((battery?.timeToFull ?? 0) > 0 ? ", voll in " + duration(battery.timeToFull) : "")
        if ((battery?.timeToEmpty ?? 0) > 0) return t + "  ·  noch " + duration(battery.timeToEmpty)
        return t
    }

    function profileName(p) {
        return p === PowerProfile.PowerSaver ? "stromsparen" : p === PowerProfile.Performance ? "leistung" : "ausgewogen"
    }

    function run(cmd) {
        Ui.controlOpen = false
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // ── Bausteine ─────────────────────────────────────────────

    // Große Schnellkachel: linker Teil schaltet an/aus, rechts 󰅀 klappt die Liste auf
    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property bool expanded: false
        property bool expandable: true
        property color iconColor: Theme.accent
        signal toggled()
        signal expand()

        height: 58
        radius: 12
        color: on ? Theme.accentA(mainMouse.containsMouse ? 0.22 : 0.15)
                  : Qt.rgba(1, 1, 1, mainMouse.containsMouse ? 0.08 : 0.05)
        border.width: 1
        border.color: expanded ? Theme.accentA(0.8)
                    : (on ? Theme.accentA(0.45) : Theme.hairline)
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Text {
            id: tIcon
            anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter }
            text: tile.icon
            color: tile.on ? tile.iconColor : Theme.faint
            font.family: Theme.icons
            font.pixelSize: 19
        }

        Column {
            anchors { left: tIcon.right; leftMargin: 11; right: tile.expandable ? sep.left : parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                text: tile.label
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: tile.sub
                color: tile.on ? Theme.accentSoft : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mainMouse
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: tile.expandable ? sep.left : parent.right }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        Rectangle {
            id: sep
            visible: tile.expandable
            anchors { right: parent.right; rightMargin: 34; verticalCenter: parent.verticalCenter }
            width: 1
            height: parent.height * 0.5
            color: Theme.hairline
        }

        Rectangle {
            visible: tile.expandable
            anchors { left: sep.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 4 }
            radius: 9
            color: chevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Text {
                anchors.centerIn: parent
                text: "󰅀"
                rotation: tile.expanded ? 180 : 0
                color: tile.expanded || chevMouse.containsMouse ? Theme.accent : Theme.muted
                font.family: Theme.icons
                font.pixelSize: 15
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: chevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expand()
            }
        }
    }

    // Schieberegler mit Symbol links und Prozent rechts
    component GSlider: Item {
        id: sl
        property real value: 0
        property string icon: ""
        property bool dimmed: false
        property string valueText: Math.round(value * 100) + "%"
        readonly property bool pressed: drag.pressed
        signal moved(real v)
        signal iconClicked()

        height: 30

        Rectangle {
            id: icBox
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 28
            height: 28
            radius: 8
            color: icMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Text {
                anchors.centerIn: parent
                text: sl.icon
                color: sl.dimmed ? Theme.faint : Theme.accent
                font.family: Theme.icons
                font.pixelSize: 16
            }
            MouseArea {
                id: icMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sl.iconClicked()
            }
        }

        Item {
            id: track
            anchors { left: icBox.right; leftMargin: 10; right: pct.left; rightMargin: 10; top: parent.top; bottom: parent.bottom }
            readonly property real v: Math.max(0, Math.min(1, sl.value))

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.1)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * track.v
                height: 6
                radius: 3
                color: sl.dimmed ? Theme.faint : Theme.accent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * track.v - width / 2
                width: drag.pressed || drag.containsMouse ? 16 : 13
                height: width
                radius: width / 2
                color: Theme.cream
                border.width: 2
                border.color: sl.dimmed ? Theme.faint : Theme.accent
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.leftMargin: -6
                anchors.rightMargin: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function set(x) { sl.moved(Math.max(0, Math.min(1, x / track.width))) }
                onPressed: m => set(m.x - 6)
                onPositionChanged: m => { if (pressed) set(m.x - 6) }
            }
            WheelHandler {
                onWheel: e => sl.moved(Math.max(0, Math.min(1, track.v + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }

        Text {
            id: pct
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 48
            horizontalAlignment: Text.AlignRight
            text: sl.valueText
            color: sl.dimmed ? Theme.faint : Theme.cream
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    // Auswahl-Knopf (Energieprofile): Symbol über Beschriftung, gewählt = Akzentfarbe
    component Choice: Rectangle {
        id: ch
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked()
        height: 52
        radius: 10
        color: selected ? Theme.accentA(0.18) : (chMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
        border.width: 1
        border.color: selected ? Theme.accentA(0.7) : Theme.hairline
        Behavior on color { ColorAnimation { duration: 140 } }
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ch.icon
                color: ch.selected ? Theme.accent : Theme.muted
                font.family: Theme.icons
                font.pixelSize: 16
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ch.label
                color: ch.selected ? Theme.cream : Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
            }
        }
        MouseArea {
            id: chMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.clicked()
        }
    }

    // Kleiner runder Knopf unten rechts
    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        property color hoverColor: Theme.accent
        signal clicked()
        width: 30
        height: 30
        radius: 15
        color: rbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: rbMouse.containsMouse ? Theme.accentA(0.45) : Theme.hairline
        Text {
            anchors.centerIn: parent
            text: rb.icon
            color: rbMouse.containsMouse ? rb.hoverColor : Theme.cream
            font.family: Theme.icons
            font.pixelSize: 14
        }
        MouseArea {
            id: rbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    // ── Karte ─────────────────────────────────────────────────
    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 28
        radius: 14
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.hairline
        opacity: Ui.controlOpen ? 1 : 0
        scale: Ui.controlOpen ? 1 : 0.97
        transformOrigin: Item.TopRight
        focus: true
        Keys.onEscapePressed: Ui.controlOpen = false
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
                        text: "steuerung"
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
                        onClicked: Ui.controlOpen = false
                    }
                }
            }

            // Schnellkacheln
            Row {
                width: parent.width
                spacing: 8

                Tile {
                    width: root.bt !== null ? (parent.width - parent.spacing) / 2 : parent.width
                    icon: root.wifiIcon
                    label: "wlan"
                    sub: root.wifiNet ? root.wifiNet.name
                       : (!Networking.wifiEnabled ? "aus" : (root.wiredDev ? "kabel verbunden" : "nicht verbunden"))
                    on: Networking.wifiEnabled
                    iconColor: root.wifiNet ? Theme.green : Theme.accent
                    expanded: Ui.controlSection === "wifi"
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    onExpand: Ui.controlSection = Ui.controlSection === "wifi" ? "" : "wifi"
                }

                Tile {
                    visible: root.bt !== null
                    width: (parent.width - parent.spacing) / 2
                    icon: !root.btOn ? "󰂲" : (root.btDevice ? "󰂱" : "󰂯")
                    label: "bluetooth"
                    sub: !root.btOn ? "aus" : (root.btDevice ? (root.btDevice.name || root.btDevice.deviceName) : "an")
                    on: root.btOn
                    iconColor: root.btDevice ? Theme.green : Theme.accent
                    expanded: Ui.controlSection === "bluetooth"
                    onToggled: root.bt.enabled = !root.bt.enabled
                    onExpand: Ui.controlSection = Ui.controlSection === "bluetooth" ? "" : "bluetooth"
                }
            }

            // aufgeklappte Liste
            WifiList {
                width: parent.width
                visible: Ui.controlSection === "wifi"
            }
            BluetoothList {
                width: parent.width
                visible: Ui.controlSection === "bluetooth"
            }

            // Stromsparen & Nachtmodus
            Row {
                width: parent.width
                spacing: 8

                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "󰌪"
                    label: "stromsparen"
                    sub: on ? "an" : "aus · " + root.profileName(PowerProfiles.profile)
                    on: PowerProfiles.profile === PowerProfile.PowerSaver
                    iconColor: Theme.green
                    expanded: Ui.controlSection === "power"
                    onToggled: PowerProfiles.profile = on ? PowerProfile.Balanced : PowerProfile.PowerSaver
                    onExpand: Ui.controlSection = Ui.controlSection === "power" ? "" : "power"
                }

                Tile {
                    width: (parent.width - parent.spacing) / 2
                    icon: "󰖔"
                    label: "nachtmodus"
                    sub: NightLight.on ? "an · " + NightLight.temperature + " K" : "aus"
                    on: NightLight.on
                    expanded: Ui.controlSection === "night"
                    onToggled: NightLight.toggle()
                    onExpand: Ui.controlSection = Ui.controlSection === "night" ? "" : "night"
                }
            }

            Tile {
                width: parent.width
                expandable: false
                icon: "󰄜"
                label: "iphone spiegeln"
                sub: Iphone.on ? "an · 8155-Laptop" : "aus"
                on: Iphone.on
                onToggled: Iphone.toggle()
            }

            // Energieprofile
            Row {
                visible: Ui.controlSection === "power"
                width: parent.width
                spacing: 6
                readonly property int n: PowerProfiles.hasPerformanceProfile ? 3 : 2

                Choice {
                    width: (parent.width - (parent.n - 1) * parent.spacing) / parent.n
                    icon: "󰌪"
                    label: "stromsparen"
                    selected: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                }
                Choice {
                    width: (parent.width - (parent.n - 1) * parent.spacing) / parent.n
                    icon: "󰗑"
                    label: "ausgewogen"
                    selected: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                }
                Choice {
                    visible: PowerProfiles.hasPerformanceProfile
                    width: (parent.width - (parent.n - 1) * parent.spacing) / parent.n
                    icon: "󱐋"
                    label: "leistung"
                    selected: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                }
            }

            // Wärme des Nachtmodus (Ziehen schaltet ihn ein, Mond-Symbol schaltet an/aus)
            GSlider {
                visible: Ui.controlSection === "night"
                width: parent.width
                icon: "󰖔"
                value: NightLight.strength
                valueText: NightLight.temperature + " K"
                dimmed: !NightLight.on
                onMoved: v => {
                    NightLight.setStrength(v)
                    if (!NightLight.on) NightLight.setOn(true)
                }
                onIconClicked: NightLight.toggle()
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            // Lautstärke & Helligkeit
            GSlider {
                width: parent.width
                visible: root.sink !== null
                icon: root.muted ? "󰝟" : (root.sink?.audio?.volume ?? 0) < 0.34 ? "󰕿" : (root.sink?.audio?.volume ?? 0) < 0.67 ? "󰖀" : "󰕾"
                value: root.sink?.audio?.volume ?? 0
                dimmed: root.muted
                onMoved: v => {
                    root.sink.audio.muted = false
                    root.sink.audio.volume = v
                }
                onIconClicked: root.sink.audio.muted = !root.sink.audio.muted
            }
            GSlider {
                id: brightSlider
                width: parent.width
                icon: "󰃠"
                value: root.brightness
                onMoved: v => root.setBrightness(Math.max(0.01, v))
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            // Kalender: heute + 1 Monat, Termine aus dem Google-Kalender
            CalendarView { width: parent.width }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            // Fuß: Akku + Sperren + Power-Menü
            Item {
                width: parent.width
                height: 30

                Row {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    visible: root.battery?.isPresent ?? false
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.battery?.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"
                        color: root.batteryPct < 15 ? Theme.red : Theme.accent
                        font.family: Theme.icons
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryText
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 11
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    RoundButton {
                        icon: "󰌾"
                        onClicked: root.run("loginctl lock-session")
                    }
                    RoundButton {
                        icon: "󰐥"
                        hoverColor: Theme.red
                        onClicked: root.run("~/.config/hypr/scripts/powermenu.sh")
                    }
                }
            }
        }
    }
}
