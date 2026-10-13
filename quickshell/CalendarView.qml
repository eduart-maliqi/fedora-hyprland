import QtQuick

// Kalender im Kontrollzentrum: rollende Ansicht ab dieser Woche bis heute + 1 Monat (keine feste Monatsseite).
//   Punkte unter der Zahl = Termine (bis zu 3), gefüllter Kreis = heute, Monatsname am 1. des Monats
//   Tag anklicken → seine Termine, nochmal anklicken → wieder „nächste termine“
// Daten kommen aus CalendarService.qml.
Column {
    id: view
    spacing: 8

    property var today: new Date()
    property int selected: -1           // Tages-Schlüssel (JJJJMMTT) oder -1

    readonly property var dayNames: ["so", "mo", "di", "mi", "do", "fr", "sa"]
    readonly property var monthNames: ["jan", "feb", "mär", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "dez"]

    function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }

    readonly property var midnight: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int todayKey: CalendarService.key(midnight)
    // Montag der aktuellen Woche; so steht heute immer in der ersten Zeile
    readonly property int offset: (midnight.getDay() + 6) % 7
    readonly property var gridStart: addDays(midnight, -offset)
    // gleicher Tag im nächsten Monat; den 31. Januar gibt es im Februar nicht → letzter Tag des Monats
    readonly property var rangeEnd: {
        const next = new Date(midnight.getFullYear(), midnight.getMonth() + 1, midnight.getDate())
        return next.getDate() === midnight.getDate() ? next
             : new Date(midnight.getFullYear(), midnight.getMonth() + 2, 0)
    }
    readonly property int span: Math.round((rangeEnd.getTime() - midnight.getTime()) / 86400000)
    readonly property int rows: Math.ceil((offset + span + 1) / 7)

    function dayLabel(d) {
        const k = CalendarService.key(d)
        if (k === todayKey) return "heute"
        if (k === CalendarService.key(addDays(midnight, 1))) return "morgen"
        return dayNames[d.getDay()] + " " + d.getDate() + ". " + monthNames[d.getMonth()]
    }
    function timeLabel(e) {
        return e.allDay ? "ganztag" : Qt.formatTime(e.start, "HH:mm")
    }

    // Liste unter dem Raster: Auswahl = Termine des Tages, sonst die nächsten bis heute + 1 Monat
    readonly property var agenda: {
        if (selected > 0) return CalendarService.byDay[selected] ?? []
        const now = Date.now()
        const limit = addDays(rangeEnd, 1).getTime()
        return CalendarService.events.filter(e => e.endMs > now && e.startMs < limit).slice(0, 6)
    }

    Connections {
        target: Ui
        function onControlOpenChanged() {
            if (!Ui.controlOpen) return
            view.today = new Date()
            CalendarService.refresh(false)
        }
    }

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
                text: "kalender"
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
            text: view.midnight.getDate() + ". " + view.monthNames[view.midnight.getMonth()]
                + " – " + view.rangeEnd.getDate() + ". " + view.monthNames[view.rangeEnd.getMonth()]
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
        }
    }

    // Wochentage
    Row {
        width: parent.width
        Repeater {
            model: ["mo", "di", "mi", "do", "fr", "sa", "so"]
            Text {
                required property string modelData
                width: view.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
            }
        }
    }

    // Raster
    Grid {
        id: grid
        width: parent.width
        columns: 7

        Repeater {
            model: view.rows * 7

            Item {
                id: cell
                readonly property var d: view.addDays(view.gridStart, index)
                readonly property int k: CalendarService.key(d)
                readonly property bool isToday: k === view.todayKey
                readonly property bool past: d.getTime() < view.midnight.getTime()
                readonly property var evs: CalendarService.byDay[k] ?? []

                width: grid.width / 7
                height: 36

                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: 9
                    color: cell.isToday ? Theme.accent
                         : (cellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.width: view.selected === cell.k ? 1 : 0
                    border.color: Theme.accentA(0.8)
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cell.d.getDate() === 1 || index === 0
                            ? cell.d.getDate() + " " + view.monthNames[cell.d.getMonth()]
                            : cell.d.getDate()
                        color: cell.isToday ? Theme.ink : (cell.past ? Theme.faint : Theme.cream)
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.bold: cell.isToday
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        height: 4
                        Repeater {
                            model: Math.min(3, cell.evs.length)
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: cell.isToday ? Theme.ink : Theme.accentSoft
                            }
                        }
                    }
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.selected = view.selected === cell.k ? -1 : cell.k
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.hairline }

    // Liste
    Text {
        text: view.selected > 0
            ? view.dayLabel(new Date(Math.floor(view.selected / 10000), Math.floor(view.selected / 100) % 100 - 1, view.selected % 100))
            : "nächste termine"
        color: Theme.muted
        font.family: Theme.mono
        font.pixelSize: 10
        leftPadding: 2
    }

    Text {
        visible: view.agenda.length === 0
        width: parent.width
        leftPadding: 2
        text: CalendarService.error !== "" ? "kalender nicht erreichbar"
            : (!CalendarService.loaded ? "lade …" : "nichts geplant")
        color: CalendarService.error !== "" ? Theme.red : Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Repeater {
        model: view.agenda

        Item {
            required property var modelData
            width: view.width
            height: 22

            Row {
                anchors { fill: parent; leftMargin: 2 }
                spacing: 8

                Text {
                    visible: view.selected <= 0
                    width: 66
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.dayLabel(modelData.start.getTime() < view.midnight.getTime() ? view.midnight : modelData.start)
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    width: 50
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.timeLabel(modelData)
                    color: Theme.accentSoft
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
                Text {
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
}
