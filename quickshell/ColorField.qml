import QtQuick

// Farbfeld fürs Wallpaper-Studio: [Kreis  name  #rrggbb] – Klick auf den Kreis klappt den Wähler auf
// (Fläche = Sättigung/Helligkeit, Leiste = Farbton), Hex-Feld nimmt #rrggbb an (Enter oder Fokus weg).
Column {
    id: field
    property string label: ""
    property string value: "#000000"
    property bool open: false
    signal edited(string hex)

    spacing: 6
    width: parent ? parent.width : 300

    function hex(c) { return c.toString().slice(0, 7) }
    function pick(h, s, v) { field.edited(hex(Qt.hsva(h, s, v, 1))) }

    // eigener Farbton, damit er bei Grau/Schwarz (Farbton −1) nicht auf Rot springt
    property real hue: 0
    onValueChanged: {
        input.text = value                     // Tippen löst die Bindung von input.text
        const c = Qt.color(value)
        if (c.hsvHue >= 0) hue = c.hsvHue
    }

    Row {
        spacing: 10
        width: parent.width

        Rectangle {
            width: 24; height: 24; radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: field.value
            border.width: 1
            border.color: swatchMouse.containsMouse || field.open ? Theme.accentA(0.8) : Theme.hairline
            MouseArea {
                id: swatchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: field.open = !field.open
            }
        }
        Text {
            width: parent.width - 24 - 96 - 20
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Rectangle {
            width: 96; height: 26; radius: 7
            color: Theme.glassA(0.5)
            border.width: 1
            border.color: input.activeFocus ? Theme.accentA(0.6) : Theme.hairline
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                text: field.value
                color: Theme.cream
                selectionColor: Theme.accentDeep
                font.family: Theme.mono
                font.pixelSize: 13
                maximumLength: 7
                function take() {
                    const t = text.trim().toLowerCase()
                    if (/^#[0-9a-f]{6}$/.test(t)) field.edited(t)
                    else text = field.value
                }
                onAccepted: take()
                onActiveFocusChanged: if (!activeFocus) take()
            }
        }
    }

    Row {
        visible: field.open
        spacing: 10

        Rectangle {
            id: sv
            width: 200; height: 120; radius: 6
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "white" }
                GradientStop { position: 1; color: Qt.hsva(field.hue, 1, 1, 1) }
            }
            Rectangle {
                anchors.fill: parent
                radius: 6
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "black" }
                }
            }
            Rectangle {
                readonly property color c: Qt.color(field.value)
                x: c.hsvSaturation * sv.width - 6
                y: (1 - c.hsvValue) * sv.height - 6
                width: 12; height: 12; radius: 6
                color: "transparent"
                border.width: 2
                border.color: c.hsvValue > 0.5 ? "black" : "white"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                function set(m) {
                    field.pick(field.hue, Math.max(0, Math.min(1, m.x / width)), Math.max(0, Math.min(1, 1 - m.y / height)))
                }
                onPressed: m => set(m)
                onPositionChanged: m => set(m)
            }
        }

        Rectangle {
            id: hueBar
            width: 18; height: 120; radius: 6
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.5; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.0; color: "#ff0000" }
            }
            Rectangle {
                y: field.hue * hueBar.height - 2
                width: parent.width; height: 4; radius: 2
                color: "white"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function set(m) {
                    const c = Qt.color(field.value)
                    field.hue = Math.max(0, Math.min(0.999, m.y / height))
                    // Grau/Schwarz hat keine Sättigung – sonst ändert der Farbton nichts Sichtbares
                    field.pick(field.hue, Math.max(c.hsvSaturation, 0.6), Math.max(c.hsvValue, 0.5))
                }
                onPressed: m => set(m)
                onPositionChanged: m => set(m)
            }
        }
    }
}
