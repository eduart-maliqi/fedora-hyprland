import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// Super+I: Spickzettel oben rechts – alle Tastenkürzel mit kurzer Erklärung
//   Schließen: Super+I nochmal, 󰅖, Esc (nach Klick hinein) oder Klick aufs Wallpaper
//   Super+I fängt Hyprland ab (hyprland.lua) und meldet es als quickshell:keysToggle.
// Die Liste ist von Hand gepflegt → neues Tastenkürzel in hyprland.lua? Hier auch eintragen!
//   Schreibweise: Tasten mit " + " verbinden, Alternativen mit " / " trennen ("super + leer / d").
PanelWindow {
    id: root

    property var targetScreen: null
    screen: targetScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    anchors { top: true; right: true }
    margins { top: 6; right: 10 }
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    visible: Ui.keysOpen || card.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay          // auch über Vollbild-Fenstern sichtbar
    WlrLayershell.namespace: "golden-keys"
    // OnDemand: Tastatur erst nach einem Klick hinein (für Esc) – die App darunter behält sonst den Fokus
    WlrLayershell.keyboardFocus: Ui.keysOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function toggle() {
        if (!Ui.keysOpen)
            targetScreen = Quickshell.screens.find(s => Hyprland.monitorFor(s)?.focused) ?? Quickshell.screens[0]
        Ui.keysOpen = !Ui.keysOpen
    }

    GlobalShortcut { name: "keysToggle"; description: "Super+I: Tastenkürzel-Übersicht"; onPressed: root.toggle() }

    // qs ipc call keys toggle | open | close
    IpcHandler {
        target: "keys"
        function toggle(): void { root.toggle() }
        function open(): void { if (!Ui.keysOpen) root.toggle() }
        function close(): void { Ui.keysOpen = false }
    }

    // [linke Spalte, rechte Spalte] → Abschnitte → [Tasten, Erklärung]
    readonly property var columns: [
        [
            { title: "apps & menüs", keys: [
                ["super + enter",          "terminal (kitty)"],
                ["super + shift + enter",  "dropdown-terminal"],
                ["super + shift + d",      "noa hochfahren"],
                ["super + leer / d",       "apps starten"],
                ["super + e",              "dateimanager"],
                ["super + b",              "browser"],
                ["super + shift + v",      "zwischenablage-verlauf"],
                ["super + n",              "mitteilungen schließen"],
                ["super + l",              "bildschirm sperren"],
                ["super + esc",            "power-menü"],
                ["super + strg + shift + m", "abmelden"],
                ["super + i",              "diese übersicht"],
            ] },
            { title: "desktop", keys: [
                ["super + w",              "wallpaper-galerie"],
                ["super + shift + w",      "lebendiges wallpaper"],
                ["super + g",              "wackelfenster an/aus"],
                ["super + p",              "phantom: fläche / zoom"],
                ["super + strg + p",       "phantom aus"],
                ["super + m",              "musik-panel"],
                ["strg + shift + leer",    "musik pause / weiter"],
                ["strg + shift + ← →",     "lied zurück / weiter"],
                ["super + alt + ← →",      "musik 5 s zurück / vor"],
                ["super + shift + l",      "songtexte an/aus"],
                ["super + shift + c",      "desktop-uhr an/aus"],
            ] },
            { title: "workspaces", keys: [
                ["super + 1…0",            "zu workspace 1–10"],
                ["super + shift + 1…0",    "fenster dorthin schieben"],
                ["super + tab",            "aufgabenansicht"],
                ["super + shift + tab",    "vorheriger workspace"],
                ["alt + tab",              "fenster wechseln"],
            ] },
        ],
        [
            { title: "fenster", keys: [
                ["super + q",              "schließen"],
                ["super + f",              "vollbild (tabs bleiben)"],
                ["super + shift + f",      "maximieren"],
                ["super + v",              "schweben an/aus"],
                ["super + c",              "zentrieren"],
                ["super + shift + p",      "pseudo-tiling"],
                ["super + j",              "teilung drehen"],
                ["super + o",              "modus geordnet ↔ frei"],
                ["super + h / alt + s",    "verstecken (minimieren)"],
                ["super + s",              "versteckte zeigen/holen"],
                ["super + ← ↑ ↓ →",        "fokus wechseln"],
                ["super + shift + ← ↑ ↓ →", "verschieben"],
                ["super + strg + ← ↑ ↓ →",  "größe ändern"],
            ] },
            { title: "maus & gesten", keys: [
                ["super + linke maus",     "fenster ziehen"],
                ["super + rechte maus",    "größe ziehen"],
                ["super + mausrad",        "workspaces blättern"],
                ["3 finger wischen",       "workspace wechseln"],
                ["klick aufs wallpaper",   "panels zu / verstecken"],
            ] },
            { title: "bildschirmfoto", keys: [
                ["druck / super + shift + s", "bereich aufnehmen"],
                ["shift + druck",          "ganzer bildschirm"],            ] },
        ],
    ]

    readonly property int keyW: 160          // Breite der Tasten-Spalte (Erklärungen fluchten)
    readonly property int infoW: 172

    // ── Bausteine ─────────────────────────────────────────────

    // eine Taste als kleine Kappe
    component Cap: Rectangle {
        id: cap
        property string label: ""
        width: capText.implicitWidth + 10
        height: 18
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Theme.accentA(0.30)

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            color: Theme.accentSoft
            font.family: Theme.mono
            font.pixelSize: 10
        }
    }

    // eine Zeile: [super] [shift] [w]   lebendiges wallpaper
    component Entry: Item {
        id: entry
        property string combo: ""
        property string info: ""
        width: root.keyW + 12 + root.infoW
        height: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Repeater {
                model: entry.combo.split(" / ")
                delegate: Row {
                    id: alt
                    required property string modelData
                    required property int index
                    spacing: 3
                    Text {
                        visible: alt.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 2
                        text: "/"
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                    Repeater {
                        model: alt.modelData.split(" + ")
                        delegate: Cap {
                            required property string modelData
                            label: modelData
                        }
                    }
                }
            }
        }

        Text {
            x: root.keyW + 12
            width: root.infoW
            anchors.verticalCenter: parent.verticalCenter
            text: entry.info
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // ── Karte ─────────────────────────────────────────────────

    Rectangle {
        id: card
        implicitWidth: content.implicitWidth + 36
        implicitHeight: content.implicitHeight + 30
        width: implicitWidth
        height: implicitHeight
        radius: 14
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.hairline
        opacity: Ui.keysOpen ? 1 : 0
        scale: Ui.keysOpen ? 1 : 0.97
        transformOrigin: Item.TopRight
        focus: true
        Keys.onEscapePressed: Ui.keysOpen = false
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            id: content
            x: 18
            y: 15
            spacing: 12

            // Kopf
            Item {
                width: cols.implicitWidth
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
                        text: "tastenkürzel"
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
                        onClicked: Ui.keysOpen = false
                    }
                }
            }

            // zwei Spalten mit Abschnitten
            Row {
                id: cols
                spacing: 30

                Repeater {
                    model: root.columns
                    delegate: Column {
                        id: col
                        required property var modelData
                        spacing: 12

                        Repeater {
                            model: col.modelData
                            delegate: Column {
                                id: sec
                                required property var modelData
                                spacing: 0

                                Row {
                                    spacing: 7
                                    bottomPadding: 3
                                    Star {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 7
                                        color: Theme.accentSoft
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sec.modelData.title
                                        color: Theme.accent
                                        font.family: Theme.serif
                                        font.italic: true
                                        font.weight: Font.Medium
                                        font.pixelSize: 15
                                        font.letterSpacing: 0.5
                                    }
                                }

                                Repeater {
                                    model: sec.modelData.keys
                                    delegate: Entry {
                                        required property var modelData
                                        combo: modelData[0]
                                        info: modelData[1]
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Fuß
            Rectangle {
                width: cols.implicitWidth
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.accentA(0.40) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Item {
                width: cols.implicitWidth
                height: 14

                Text {
                    anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                    text: "laptop-tasten: lautstärke · helligkeit · medien – auch gesperrt"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
                Text {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "esc / super + i schließt"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }
        }
    }
}
