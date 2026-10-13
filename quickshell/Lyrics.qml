import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Songtext oben links auf dem Desktop (Stil wie die Instagram-Songtexte):
//   vorherige Zeile – grau
//   aktuelle Zeile  – fett, weiss, etwas grösser
//   nächste Zeile   – grau
// Lange Zeilen brechen um und sind mittig gesetzt. Bei jeder neuen Zeile rutscht der Text
// weich nach oben. Ist auf diesem Bildschirm das Musik-Panel zu sehen, steht der Text darunter.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { top: true; left: true }
    margins { left: 48; top: 92 }
    implicitWidth: 520
    implicitHeight: 940
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}                      // komplett klick-durchlässig
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "golden-lyrics"

    readonly property bool active: Ui.lyricsEnabled && LyricsService.status === "ok" && LyricsService.current !== ""
    visible: Ui.lyricsEnabled && LyricsService.status === "ok"

    readonly property int gap: 16        // Abstand zwischen zwei Songzeilen
    // oberste sichtbare Zeile: die vorherige – fehlt sie (Anfang, nach einer Pause), die aktuelle
    readonly property int topIndex: {
        const i = LyricsService.index
        const ls = LyricsService.lines
        if (i > 0 && (ls[i - 1]?.text ?? "") !== "") return i - 1
        return Math.max(0, i)
    }

    Item {
        id: content
        width: parent.width
        height: 460
        // unter dem Musik-Panel (oben links, endet bei y = 534) – nur wenn es auf diesem Bildschirm liegt
        y: Ui.musicOn(root.modelData) ? 476 : 0
        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        // weicher dunkler Schatten → lesbar auch über hellen Stellen im Bild
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.75
            shadowBlur: 0.6
            blurMax: 24
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }

        // alle Zeilen untereinander; verschoben, sodass topIndex oben steht
        Column {
            id: lines
            width: parent.width
            y: {
                const it = rep.count > root.topIndex ? rep.itemAt(root.topIndex) : null
                return it ? -it.y : 0
            }
            Behavior on y {
                enabled: root.active
                NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
            }

            Repeater {
                id: rep
                model: LyricsService.lines

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property int dist: index - LyricsService.index
                    readonly property bool blank: (modelData?.text ?? "") === ""

                    width: lines.width
                    height: blank ? 0 : label.implicitHeight + root.gap

                    Text {
                        id: label
                        width: parent.width
                        text: row.modelData?.text ?? ""
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: "#ffffff"
                        font.family: "SF Pro Display"
                        font.weight: Font.Bold
                        font.pixelSize: 36
                        lineHeight: 1.06

                        // nur vorherige, aktuelle und nächste Zeile sind zu sehen
                        opacity: row.dist === 0 ? 1 : Math.abs(row.dist) === 1 ? 0.45 : 0
                        scale: row.dist === 0 ? 1 : 0.93
                        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
