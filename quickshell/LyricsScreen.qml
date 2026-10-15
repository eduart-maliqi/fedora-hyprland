import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Songtext-Bildschirm (Stil Apple Music): füllt einen ganzen Bildschirm – links Cover, Titel, Fortschritt,
// rechts der Songtext groß, die aktuelle Zeile hell und leuchtend, darunter die nächsten Zeilen blasser.
// Hintergrund: das Wallpaper stark verschwommen, langsam drehend, dazu wandernde Farbflecken in den
// Farben des Themas → passt sich dem Wallpaper an.
// Öffnen/Schließen: SUPER+SHIFT+M (Bildschirm unter der Maus), Esc schließt. IPC: `qs ipc call lyrics screenOn <bildschirm>`.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool shown: Ui.lyricsScreen !== "" && Ui.lyricsScreen === (modelData?.name ?? "")

    property bool lingering: false
    onShownChanged: if (!shown) { lingering = true; linger.restart() }
    Timer { id: linger; interval: 450; onTriggered: win.lingering = false }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || lingering
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "golden-lyricsscreen"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property real fs: Math.round(height * 0.05)       // Schriftgröße Songtext (1200 px → 60)

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.lyricsScreen = ""

        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Rectangle { anchors.fill: parent; color: Theme.ink }

        // Hintergrund auf 1/10 Größe malen, verwischen und hochskalieren – ein Blur in voller Größe
        // wäre bei jedem Bild teuer, so kostet die Animation fast nichts.
        Item {
            id: bg
            readonly property real k: 10
            x: -parent.width * 0.1
            y: -parent.height * 0.1
            width: parent.width * 1.2 / k
            height: parent.height * 1.2 / k
            scale: k
            transformOrigin: Item.TopLeft
            clip: true

            property real t: 0
            NumberAnimation on t {
                from: 0; to: Math.PI * 2; duration: 40000
                loops: Animation.Infinite; running: win.visible
            }

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 24
                autoPaddingEnabled: false
                saturation: 0.6                 // kräftigere Farben als Wallpaper und Thema von sich aus haben
                contrast: 0.15
            }

            Image {
                anchors.centerIn: parent
                width: Math.max(parent.width, parent.height) * 1.5
                height: width
                source: Ui.wallpaper
                sourceSize.width: 256
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                rotation: bg.t * 360 / Math.PI
                opacity: 0.7
            }

            // ganzzahlige Frequenzen (fx, fy) → nach einer Runde von t steht alles wieder am Anfang, kein Sprung
            Repeater {
                model: [
                    { c: Theme.accent,     cx: 0.25, cy: 0.30, fx: 1, fy: 2, ph: 0.0, s: 0.75, o: 0.95 },
                    { c: Theme.accentDeep, cx: 0.75, cy: 0.70, fx: 2, fy: 1, ph: 2.1, s: 0.90, o: 0.95 },
                    { c: Theme.accentSoft, cx: 0.65, cy: 0.25, fx: 1, fy: 3, ph: 4.2, s: 0.50, o: 0.80 },
                    { c: Theme.accentDeep, cx: 0.20, cy: 0.80, fx: 3, fy: 1, ph: 1.0, s: 0.70, o: 0.90 },
                    { c: Theme.accent,     cx: 0.55, cy: 0.55, fx: 2, fy: 3, ph: 3.3, s: 0.55, o: 0.85 },
                ]
                Rectangle {
                    required property var modelData
                    readonly property var m: modelData
                    width: bg.width * m.s * (1 + 0.3 * Math.sin(bg.t * (m.fx + m.fy) + m.ph))
                    height: width
                    radius: width / 2
                    color: m.c
                    opacity: m.o
                    x: bg.width * (m.cx + 0.32 * Math.sin(bg.t * m.fx + m.ph)) - width / 2
                    y: bg.height * (m.cy + 0.32 * Math.cos(bg.t * m.fy + m.ph)) - height / 2
                }
            }
        }

        // abdunkeln, damit weißer Text auch auf hellen Wallpapern lesbar bleibt
        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.ink, 0.22) }

        // links: Cover, Titel, Interpret, Fortschritt
        Column {
            id: info
            readonly property real coverSize: Math.min(win.width * 0.28, win.height * 0.48)
            x: win.width * 0.08
            anchors.verticalCenter: parent.verticalCenter
            width: coverSize
            spacing: 14

            Rectangle {
                width: info.coverSize
                height: width
                radius: 14
                color: Theme.glassA(0.5)
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.55
                    shadowBlur: 1
                    blurMax: 48
                    shadowVerticalOffset: 12
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: Theme.icons
                    font.pixelSize: info.coverSize * 0.3
                    color: Theme.alpha(Theme.cream, 0.4)
                    visible: cover.status !== Image.Ready
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    // Brave liefert übers MPRIS nur 150 px → wenn möglich das 640-px-Cover von Spotify
                    source: Media.title === "" ? ""
                          : Spotify.item?.name === Media.title && Spotify.itemImage !== "" ? Spotify.itemImage
                          : Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Item { width: 1; height: 10 }

            Text {
                width: parent.width
                text: Media.title || "keine musik"
                color: Theme.cream
                font.family: "SF Pro Display"
                font.weight: Font.Bold
                font.pixelSize: 22
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Media.artist
                color: Theme.alpha(Theme.cream, 0.65)
                font.family: "SF Pro Display"
                font.pixelSize: 18
                elide: Text.ElideRight
                visible: text !== ""
            }

            Item { width: 1; height: 6 }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Theme.alpha(Theme.cream, 0.22)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Media.length > 0 ? Media.position / Media.length : 0))
                    height: parent.height
                    radius: 2
                    color: Theme.cream
                }
            }
            Item {
                width: parent.width
                height: 18
                Text {
                    text: Media.fmt(Media.position)
                    color: Theme.alpha(Theme.cream, 0.55)
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                }
                Text {
                    anchors.right: parent.right
                    text: "-" + Media.fmt(Media.length - Media.position)
                    color: Theme.alpha(Theme.cream, 0.55)
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                }
            }
        }

        // rechts: Songtext
        Item {
            id: lyricsArea
            x: info.x + info.width + win.width * 0.07
            width: win.width - x - win.width * 0.07
            height: parent.height
            readonly property bool hasLyrics: LyricsService.status === "ok"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: !lyricsArea.hasLyrics
                text: !Media.hasPlayer ? "keine musik"
                    : LyricsService.status === "loading"
                        ? (LyricsService.stage === "ki" ? "ki hört zu …" : LyricsService.stage === "audio" ? "lade audio …" : "suche songtext …")
                    : "kein songtext gefunden"
                color: Theme.alpha(Theme.cream, 0.5)
                font.family: "SF Pro Display"
                font.weight: Font.Bold
                font.pixelSize: win.fs
            }

            Item {
                anchors.fill: parent
                visible: lyricsArea.hasLyrics

                // weiches Leuchten (wirkt nur auf deckende Zeilen richtig – die aktuelle)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.accentSoft
                    shadowOpacity: 0.55
                    shadowBlur: 0.7
                    blurMax: 32
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                Column {
                    id: lines
                    width: parent.width
                    // aktuelle Zeile steht bei gut einem Drittel der Höhe
                    y: {
                        const i = Math.max(0, LyricsService.index)
                        const it = rep.count > i ? rep.itemAt(i) : null
                        return win.height * 0.36 - (it ? it.y : 0)
                    }
                    Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

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
                            height: blank ? win.fs * 0.6 : label.implicitHeight + win.fs * 0.55

                            Text {
                                id: label
                                width: parent.width
                                text: row.modelData?.text ?? ""
                                wrapMode: Text.WordWrap
                                color: Theme.cream
                                font.family: "SF Pro Display"
                                font.weight: Font.Bold
                                font.pixelSize: win.fs
                                lineHeight: 1.04
                                transformOrigin: Item.Left

                                opacity: row.dist === 0 ? 1
                                       : row.dist > 0 ? Math.max(0, 0.42 - 0.08 * (row.dist - 1))
                                       : Math.max(0, 0.2 + 0.05 * row.dist)
                                scale: row.dist === 0 ? 1 : 0.96
                                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }
    }
}
