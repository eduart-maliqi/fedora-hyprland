import QtQuick

// Mini-Desktop fürs Wallpaper-Studio: Bild + Leiste + Desktop-Uhr + Panel + Terminal + Meldung in einer Palette,
// die NICHT aus Theme kommt (pal = Objekt wie themen/<name>/farben.json) → zeigt live, was gerade bearbeitet wird.
// Maße sind am logischen Laptop-Bildschirm (1728×1080) ausgerichtet und werden mit s verkleinert.
Item {
    id: root
    property var pal: ({})
    property string image: ""

    readonly property real s: width / 1728
    implicitHeight: width * 1080 / 1728

    function c(k, fb) { return pal[k] ?? fb ?? pal.ink ?? "#000000" }
    function a(k, al) { const q = Qt.color(c(k, "#000000")); return Qt.rgba(q.r, q.g, q.b, al) }
    function glass(al) { const b = pal.base ?? [0, 0, 0]; return Qt.rgba(b[0], b[1], b[2], al) }
    readonly property color hair: { const h = pal.hair ?? [1, 1, 1, 0.08]; return Qt.rgba(h[0], h[1], h[2], h[3]) }

    clip: true

    Rectangle { anchors.fill: parent; color: root.c("ink", "#000000") }

    Image {
        anchors.fill: parent
        source: root.image
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1152, 720)
        asynchronous: true
    }

    // Leiste
    Rectangle {
        x: 10 * root.s; y: 8 * root.s
        width: parent.width - 20 * root.s; height: 40 * root.s
        radius: height / 2
        color: root.glass(0.5)
        border.width: 1; border.color: root.hair

        Text {
            x: 22 * root.s; anchors.verticalCenter: parent.verticalCenter
            text: "8155"
            color: root.c("accent")
            font.family: Theme.serif; font.italic: true; font.pixelSize: 24 * root.s; font.weight: Font.Medium
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.42; height: Math.max(1, 1.5 * root.s)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: root.c("accent") }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Star { anchors.centerIn: parent; size: 14 * root.s; color: root.c("accentSoft") }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Repeater {
                model: ["󰤨", "󰂯", "󰕾  62"]
                Rectangle {
                    required property string modelData
                    height: 26 * root.s; width: t.implicitWidth + 22 * root.s; radius: height / 2
                    color: root.glass(0.5); border.width: 1; border.color: root.hair
                    Text {
                        id: t; anchors.centerIn: parent
                        text: parent.modelData; color: root.c("accent")
                        font.family: Theme.icons; font.pixelSize: 14 * root.s
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "14:32"; color: root.c("cream")
                font.family: Theme.mono; font.pixelSize: 15 * root.s
            }
        }
    }

    // Desktop-Uhr oben rechts
    Column {
        anchors.right: parent.right; anchors.rightMargin: 60 * root.s
        y: 90 * root.s
        spacing: 2 * root.s
        Text {
            anchors.right: parent.right
            text: "8155"; color: root.c("accent")
            font.family: Theme.serif; font.italic: true; font.pixelSize: 30 * root.s
        }
        Text {
            anchors.right: parent.right
            text: "14:32"; color: root.c("cream")
            font.family: "SF Pro Display"; font.weight: Font.Light; font.pixelSize: 110 * root.s
        }
        Rectangle { anchors.right: parent.right; width: 220 * root.s; height: Math.max(1, 1.5 * root.s); color: root.c("accent") }
        Text {
            anchors.right: parent.right
            text: "dienstag, 21. oktober"; color: root.c("clockDate", root.c("muted"))
            font.family: Theme.serif; font.italic: true; font.pixelSize: 24 * root.s
        }
    }

    // Panel (wie das Musik-Panel) oben links
    Rectangle {
        x: 24 * root.s; y: 70 * root.s
        width: 380 * root.s; height: 330 * root.s
        radius: 14 * root.s
        color: root.glass(0.68)
        border.width: 1; border.color: root.hair

        Column {
            anchors.fill: parent; anchors.margins: 18 * root.s
            spacing: 8 * root.s
            Text {
                text: "musik"; color: root.c("cream")
                font.family: Theme.serif; font.italic: true; font.pixelSize: 28 * root.s
            }
            Repeater {
                model: [["sternenstaub", "luna", true], ["morgenrot", "aurora", false], ["seide", "8155", false], ["nachtflug", "orbit", false]]
                Rectangle {
                    required property var modelData
                    width: parent.width; height: 52 * root.s; radius: 10 * root.s
                    color: modelData[2] ? root.c("accent") : "transparent"
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; x: 12 * root.s
                        Text {
                            text: parent.parent.modelData[0]
                            color: parent.parent.modelData[2] ? root.c("ink") : root.c("cream")
                            font.family: Theme.mono; font.pixelSize: 15 * root.s
                        }
                        Text {
                            text: parent.parent.modelData[1]
                            color: parent.parent.modelData[2] ? root.c("onAccentMuted") : root.c("muted")
                            font.family: Theme.mono; font.pixelSize: 12 * root.s
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 5 * root.s; radius: height / 2
                color: root.a("cream", 0.12)
                Rectangle { width: parent.width * 0.4; height: parent.height; radius: parent.radius; color: root.c("accent") }
            }
            Text {
                text: "warnung · akku 9 %"; color: root.c("red")
                font.family: Theme.mono; font.pixelSize: 12 * root.s
            }
        }
    }

    // Terminal-Fenster mit Rand in der Akzentfarbe (wie hyprland.lua: accentSoft → accent)
    Rectangle {
        x: parent.width * 0.33; y: parent.height * 0.5
        width: 640 * root.s; height: 330 * root.s
        radius: 12 * root.s
        gradient: Gradient {
            GradientStop { position: 0; color: root.a("accentSoft", 0.8) }
            GradientStop { position: 1; color: root.a("accent", 0.2) }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: Math.max(1, 2 * root.s)
            radius: parent.radius - 1
            color: root.a("term", 0.74)
            Column {
                anchors.fill: parent; anchors.margins: 16 * root.s
                spacing: 4 * root.s
                Row {
                    spacing: 4 * root.s
                    Rectangle {
                        width: tab.implicitWidth + 20 * root.s; height: 24 * root.s; color: root.c("accent")
                        Text { id: tab; anchors.centerIn: parent; text: "1 · zsh"; color: root.c("termInk"); font.family: Theme.mono; font.pixelSize: 12 * root.s }
                    }
                    Rectangle {
                        width: tab2.implicitWidth + 20 * root.s; height: 24 * root.s; color: root.c("termTab")
                        Text { id: tab2; anchors.centerIn: parent; text: "2 · nvim"; color: root.c("muted"); font.family: Theme.mono; font.pixelSize: 12 * root.s }
                    }
                }
                Item { width: 1; height: 6 * root.s }
                Text { text: "~ ❯ thema.sh"; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 15 * root.s }
                Text { text: "golden"; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 15 * root.s }
                Row {
                    Text { text: "~ ❯ "; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 15 * root.s }
                    Rectangle {
                        width: sel.implicitWidth; height: sel.implicitHeight; color: root.c("accent")
                        Text { id: sel; text: "markierter text"; color: root.c("termInk"); font.family: Theme.mono; font.pixelSize: 15 * root.s }
                    }
                }
                Text { text: "https://8155.local"; color: root.c("accentSoft"); font.family: Theme.mono; font.pixelSize: 15 * root.s; font.underline: true }
                Row {
                    Text { text: "~ ❯ "; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 15 * root.s }
                    Rectangle { width: 9 * root.s; height: 18 * root.s; color: root.c("accentSoft") }
                }
            }
        }
    }

    // Meldung (mako) oben rechts unter der Uhr
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 24 * root.s
        y: 330 * root.s
        width: 360 * root.s; height: 74 * root.s
        radius: 10 * root.s
        color: root.a("panel", 0.84)
        border.width: Math.max(1, 1.5 * root.s); border.color: root.a("accent", 0.4)
        Column {
            anchors.verticalCenter: parent.verticalCenter; x: 16 * root.s
            spacing: 3 * root.s
            Text { text: "wallpaper"; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 14 * root.s; font.bold: true }
            Text { text: "neues farbthema gespeichert"; color: root.c("cream"); font.family: Theme.mono; font.pixelSize: 13 * root.s }
        }
    }
}
