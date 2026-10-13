import QtQuick

// Kleine Glas-Kapsel für die Leiste: [icon  text]
Rectangle {
    id: pill
    property string icon: ""
    property string text: ""
    property color iconColor: Theme.accent
    property color textColor: Theme.cream
    property bool serifText: false
    property alias hovered: mouse.containsMouse
    signal clicked(var mouse)

    implicitHeight: 30
    implicitWidth: row.implicitWidth + 27
    radius: height / 2
    color: mouse.containsMouse ? Theme.glassHover : Theme.glass
    border.width: 1
    border.color: mouse.containsMouse ? Theme.accentA(0.45) : Theme.hairline

    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9

        Text {
            visible: pill.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.icon
            color: pill.iconColor
            font.family: Theme.icons
            font.pixelSize: 16
        }

        Text {
            visible: pill.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            color: pill.textColor
            font.family: pill.serifText ? Theme.serif : Theme.mono
            font.italic: pill.serifText
            font.pixelSize: pill.serifText ? 20 : 16
            font.weight: pill.serifText ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 390)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => pill.clicked(m)
    }
}
