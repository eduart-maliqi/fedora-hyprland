import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Musik-Panel oben links – ein kleines Spotify auf dem Desktop:
//   links  – lieblingssongs, zuletzt gehört, Playlists
//   mitte  – Lieder der Auswahl bzw. Suchergebnisse (Klick = abspielen)
//   rechts – Cover, Titel, Interpret, Album, ♥ speichern
//   unten  – Status, ⏮ ⏯ ⏭, Zeit, Zufall, Wiederholen, Lautstärke, Gerät; Linie ganz oben im Fuß = Fortschritt (Klick spult)
// Nur der Inhalt – die Fenster dazu (pro Bildschirm: Desktop / über den Fenstern) stehen in MusicWindow.qml
// und laden diesen Inhalt nur, solange sie zu sehen sind. Mehrere Panels gleichzeitig sind normal (jeder leere
// Bildschirm hat eins) – alle zeigen dasselbe, weil Auswahl, Lieder und Suche in Spotify.qml liegen.
// Geht von selbst auf, solange Musik läuft und auf dem Bildschirm kein Fenster offen ist (liegt dann auf dem
// Desktop) und bleibt nach dem Pausieren noch 90 s offen. SUPER+M holt es auf dem Bildschirm unter der Maus über
// die Fenster, Klick auf den Titel in der Leiste auf dem Bildschirm dieser Leiste.
// ✕ blendet es aus, bis die Musik das nächste Mal startet. Esc: Suche leeren, sonst zurück auf den Desktop.
// Bibliothek, Suche, ♥ über die Spotify Web API (Spotify.qml); Play/Pause/Spulen über MPRIS (Media.qml).
Item {
    id: root
    property bool shown: false                 // gesetzt vom Fenster (MusicWindow.qml)
    // erst nach dem Laden auf „bereit“ → das Panel blendet auch beim ersten Erscheinen weich ein
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => root.ready = true)

    readonly property string sans: "SF Pro Text"
    readonly property var player: Media.active
    readonly property var players: Mpris.players.values

    // Was gerade läuft: lokal über MPRIS. Läuft lokal nichts, Spotify aber auf einem anderen Gerät
    // (Handy, Lautsprecher …) → Daten und Steuerung über die Web API.
    readonly property bool remote: !Media.hasPlayer && Spotify.item !== null
    readonly property bool sameTrack: Media.hasPlayer && Spotify.item !== null && Spotify.item.name === Media.title
    readonly property bool spotifyNow: remote || sameTrack          // ♥ gilt für diesen Titel
    readonly property string nowTitle: remote ? (Spotify.item?.name ?? "") : Media.title
    readonly property string nowArtist: remote ? Spotify.itemArtist : Media.artist
    readonly property string nowAlbum: remote ? Spotify.itemAlbum : Media.album
    // ohne Titel kein Bild (Brave meldet sonst sein Logo als Cover)
    readonly property string nowArt: !hasNow ? "" : spotifyNow && Spotify.itemImage !== "" ? Spotify.itemImage : Media.artUrl
    readonly property bool nowPlaying: remote ? Spotify.isPlaying : Media.playing
    readonly property real nowPos: remote ? Spotify.position : Media.position
    readonly property real nowLen: remote ? (Spotify.item?.duration_ms ?? 0) / 1000 : Media.length
    readonly property bool hasNow: nowTitle !== ""

    function togglePlay() {
        if (Media.hasPlayer) player.togglePlaying()
        else Spotify.command(Spotify.isPlaying ? "pause" : "play")
    }
    function next() { if (Media.hasPlayer) player.next(); else Spotify.command("next") }
    function previous() { if (Media.hasPlayer) player.previous(); else Spotify.command("previous") }
    function seek(sec) {
        if (Media.hasPlayer) { if (player.canSeek) player.position = sec }
        else Spotify.seek(sec)
    }
    function esc(s) { return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    // Hinweis statt Liste in der Mitte (Anmeldung, Laden, Fehler …) + passender Knopf
    readonly property string hint: {
        if (Spotify.authState === "unknown") return "verbinde mit spotify …"
        if (Spotify.authState === "none")
            return "spotify ist noch nicht verbunden.\n\neinmal im terminal:\nspotify-auth.py login <client-id>\n(liegt in ~/.config/hypr/scripts)"
        if (Spotify.authState === "invalid") return "die spotify-anmeldung ist abgelaufen."
        if (Spotify.authState === "offline") return "spotify ist gerade nicht erreichbar."
        switch (Spotify.listState) {
        case "loading": return "lädt …"
        case "empty": return Spotify.source === "search" ? "nichts gefunden." : "hier ist nichts drin."
        case "error": return "konnte nicht geladen werden."
        case "locked": return "spotify zeigt lieder nur von eigenen playlists –\ndiese hier kannst du als ganzes abspielen."
        }
        return ""
    }
    readonly property string hintAction: Spotify.authState === "invalid" ? "neu anmelden"
        : Spotify.authState === "offline" ? "nochmal"
        : !Spotify.ready ? ""
        : Spotify.listState === "locked" ? "󰐊  playlist abspielen"
        : Spotify.listState === "error" ? "nochmal" : ""
    function doHint() {
        if (Spotify.authState === "invalid") Spotify.relogin()
        else if (!Spotify.ready) Spotify.retry()
        else if (Spotify.listState === "locked") Spotify.playContext()
        else if (Spotify.source === "search") Spotify.search(search.text)
        else Spotify.open(Spotify.source)
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 14
        color: Theme.glassA(0.36)
        border.width: 1
        border.color: Theme.hairline
        opacity: root.shown && root.ready ? 1 : 0
        scale: root.shown && root.ready ? 1 : 0.97
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        focus: true
        Keys.onEscapePressed: Ui.musicOpen = false

        // ───────────── Kopfzeile: playlists / <auswahl>   [suche]  ✕ ─────────────
        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 42

            Text {
                anchors { left: parent.left; leftMargin: 16; right: searchBox.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: "playlists / " + (Spotify.ready ? Spotify.sourceName : "spotify")
                color: Theme.muted
                font.family: Theme.mono
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Rectangle {
                id: searchBox
                anchors { right: closeBtn.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 240
                height: 25
                radius: 7
                color: Qt.rgba(0, 0, 0, 0.22)
                border.width: 1
                border.color: search.activeFocus ? Theme.accentA(0.6) : Theme.hairline
                opacity: Spotify.ready ? 1 : 0.5

                Text {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    color: search.activeFocus ? Theme.accent : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 12
                }

                TextInput {
                    id: search
                    anchors { left: searchIcon.right; leftMargin: 7; right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter }
                    enabled: Spotify.ready
                    color: Theme.cream
                    selectionColor: Theme.accentDeep
                    font.family: Theme.mono
                    font.pixelSize: 11
                    clip: true
                    onTextEdited: Spotify.search(text)
                    onAccepted: Spotify.search(text)
                    // Suchtext mit den anderen Panels teilen (jeder leere Bildschirm hat eins)
                    Component.onCompleted: text = Spotify.query
                    Connections {
                        target: Spotify
                        function onQueryChanged() { if (!search.activeFocus) search.text = Spotify.query }
                    }
                    Keys.onEscapePressed: {
                        if (text !== "") { text = ""; Spotify.search("") }
                        else { focus = false; Ui.musicOpen = false }
                    }

                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lieder suchen …"
                        color: Theme.faint
                        font: search.font
                    }
                }
            }

            Text {
                id: closeBtn
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: "󰅖"
                color: closeMouse.containsMouse ? Theme.accent : Theme.faint
                font.family: Theme.icons
                font.pixelSize: 13
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.closeMusic()
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Theme.hairline
            }
        }

        // ───────────── links: Quellen ─────────────
        ListView {
            id: sources
            anchors { left: parent.left; leftMargin: 8; top: head.bottom; topMargin: 8; bottom: foot.top; bottomMargin: 8 }
            width: 188
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: !Spotify.ready ? [] : [
                { key: "liked", name: "lieblingssongs", icon: "󰋑" },
                { key: "recent", name: "zuletzt gehört", icon: "󰋚" }
            ].concat(Spotify.playlists.map(p => ({ key: "playlist:" + p.id, name: p.name, icon: p.owned ? "󰲸" : "󰐑" })))

            delegate: Rectangle {
                id: src
                required property var modelData
                readonly property bool sel: Spotify.source === modelData.key
                width: ListView.view.width
                height: 26
                radius: 6
                color: sel ? Theme.accentA(0.30)
                     : srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                Text {
                    id: srcIcon
                    anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                    width: 14
                    text: src.modelData.icon
                    color: src.sel ? Theme.accentSoft : Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 12
                }
                Text {
                    anchors { left: srcIcon.right; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: src.modelData.name
                    color: src.sel ? Theme.cream : Theme.alpha(Theme.cream, 0.82)
                    font.family: root.sans
                    font.weight: src.sel ? Font.DemiBold : Font.Normal
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: srcMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        search.text = ""
                        Spotify.open(src.modelData.key)
                        list.positionViewAtBeginning()
                    }
                }
            }
        }

        Rectangle {
            anchors { left: sources.right; leftMargin: 6; top: head.bottom; bottom: foot.top }
            width: 1
            color: Theme.hairline
        }

        // ───────────── Mitte: Lieder ─────────────
        Item {
            id: middle
            anchors { left: sources.right; leftMargin: 14; right: side.left; rightMargin: 16; top: head.bottom; topMargin: 8; bottom: foot.top; bottomMargin: 8 }

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                visible: Spotify.ready && Spotify.listState === "ok"
                model: Spotify.tracks
                onAtYEndChanged: if (atYEnd && count > 0) Spotify.loadMore()

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool cur: root.spotifyNow && Spotify.currentUri !== ""
                        ? modelData.uri === Spotify.currentUri
                        : root.hasNow && modelData.name === root.nowTitle
                    width: ListView.view.width
                    height: 25
                    radius: 6
                    color: cur ? Theme.accent : rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        visible: row.cur
                        text: "▶"
                        color: Theme.ink
                        font.pixelSize: 8
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 22; right: dur.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        textFormat: Text.StyledText
                        text: root.esc(row.modelData.name)
                            + "<font color='" + (row.cur ? Theme.onAccentMuted : Theme.dim) + "'>  ·  " + root.esc(row.modelData.artist) + "</font>"
                        color: row.cur ? Theme.ink : Theme.cream
                        font.family: root.sans
                        font.weight: row.cur ? Font.DemiBold : Font.Normal
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        id: dur
                        anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter }
                        text: Media.fmt(row.modelData.ms / 1000)
                        color: row.cur ? Theme.ink : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Spotify.playAt(row.index)
                    }
                }
            }

            // schmale Bildlauf-Anzeige
            Rectangle {
                visible: list.visible && list.contentHeight > list.height
                x: parent.width + 6
                y: list.visibleArea.yPosition * list.height
                width: 2
                height: Math.max(20, list.visibleArea.heightRatio * list.height)
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.18)
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 30
                spacing: 14
                visible: !list.visible

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.hint
                    color: Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 11
                    lineHeight: 1.2
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hintAction !== ""
                    width: hintText.implicitWidth + 26
                    height: 27
                    radius: 7
                    color: hintMouse.containsMouse ? Theme.accentSoft : Theme.accent
                    Text {
                        id: hintText
                        anchors.centerIn: parent
                        text: root.hintAction
                        color: Theme.ink
                        font.family: Theme.mono
                        font.weight: Font.Bold
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: hintMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doHint()
                    }
                }
            }
        }

        // ───────────── rechts: Cover + Angaben ─────────────
        Column {
            id: side
            anchors { right: parent.right; rightMargin: 16; top: head.bottom; topMargin: 14 }
            width: 206
            spacing: 5

            ClippingRectangle {
                width: 206
                height: 206
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)

                Image {
                    anchors.fill: parent
                    source: root.nowArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 412
                    sourceSize.height: 412
                }
                Star {
                    anchors.centerIn: parent
                    visible: root.nowArt === ""
                    size: 46
                    color: Theme.accent
                    opacity: 0.6
                }
            }

            Item { width: 1; height: 5 }

            Text {
                width: parent.width
                text: root.hasNow ? root.nowTitle : "nichts läuft gerade"
                color: Theme.cream
                font.family: Theme.mono
                font.weight: Font.Bold
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.nowArtist
                visible: text !== ""
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.nowAlbum
                visible: text !== ""
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Item { width: 1; height: 3 }

            Row {
                spacing: 12
                Text {
                    visible: Spotify.ready && root.spotifyNow
                    text: Spotify.liked ? "♥ gespeichert" : "♡ speichern"
                    color: Spotify.liked || likeMouse.containsMouse ? Theme.accent : Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 10
                    MouseArea {
                        id: likeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Spotify.toggleLike()
                    }
                }
                Text {
                    text: LyricsService.status === "ok" ? (LyricsService.source === "ki" ? "♪ lyrics · ki" : "♪ lyrics")
                        : LyricsService.status !== "loading" ? ""
                        : LyricsService.stage === "audio" ? "♪ lade audio …"
                        : LyricsService.stage === "ki" ? "♪ ki hört zu …" : "♪ suche lyrics …"
                    visible: text !== ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }

            // kein Spotify offen → Web-Player im Browser öffnen
            Rectangle {
                visible: Spotify.noDevice
                width: openText.implicitWidth + 22
                height: 24
                radius: 6
                color: openMouse.containsMouse ? Theme.accentSoft : Theme.accent
                Text {
                    id: openText
                    anchors.centerIn: parent
                    text: "󰓇  spotify öffnen"
                    color: Theme.ink
                    font.family: Theme.mono
                    font.weight: Font.Bold
                    font.pixelSize: 10
                }
                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["xdg-open", "https://open.spotify.com"])
                        Spotify.noDevice = false
                    }
                }
            }
        }

        // ───────────── Fußzeile ─────────────
        Rectangle {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 42
            radius: 13
            color: Qt.rgba(0, 0, 0, 0.18)

            // Fortschritt als feine Linie oben – Klick spult
            Item {
                id: prog
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14 }
                height: progMouse.containsMouse ? 3 : 2
                readonly property real frac: root.nowLen > 0 ? Math.min(1, root.nowPos / root.nowLen) : 0
                Rectangle { anchors.fill: parent; radius: 1; color: Qt.rgba(1, 1, 1, 0.10) }
                Rectangle { width: parent.width * prog.frac; height: parent.height; radius: 1; color: Theme.accent }
                MouseArea {
                    id: progMouse
                    anchors.fill: parent
                    anchors.topMargin: -4
                    anchors.bottomMargin: -6
                    hoverEnabled: true
                    enabled: root.nowLen > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => root.seek(Math.max(0, Math.min(1, m.x / width)) * root.nowLen)
                }
            }

            Row {
                id: leftRow
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 19
                    width: stateText.implicitWidth + 16
                    radius: 5
                    color: root.nowPlaying ? Theme.accent : Theme.accentA(0.25)
                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: root.nowPlaying ? "▶ LÄUFT" : root.hasNow ? "❚❚ PAUSE" : "■ STILL"
                        color: root.nowPlaying ? Theme.ink : Theme.accentSoft
                        font.family: Theme.mono
                        font.weight: Font.Bold
                        font.pixelSize: 10
                    }
                }

                Repeater {
                    model: 3
                    delegate: Text {
                        id: ctl
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === 0 ? "󰒮" : index === 2 ? "󰒭" : (root.nowPlaying ? "󰏤" : "󰐊")
                        color: ctlMouse.containsMouse ? Theme.accent : Theme.cream
                        font.family: Theme.icons
                        font.pixelSize: 15
                        MouseArea {
                            id: ctlMouse
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (ctl.index === 0) root.previous()
                                else if (ctl.index === 2) root.next()
                                else root.togglePlay()
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.nowLen > 0
                    text: Media.fmt(root.nowPos) + " / " + Media.fmt(root.nowLen)
                    color: Theme.muted
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }

            // Mitte: Titel · Interpret, oder kurz ein Hinweis von Spotify
            Text {
                anchors { left: leftRow.right; leftMargin: 14; right: rightRow.left; rightMargin: 14; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                text: Spotify.message !== "" ? Spotify.message
                    : root.hasNow ? root.nowTitle + (root.nowArtist !== "" ? "  ·  " + root.nowArtist : "") : ""
                color: Spotify.message !== "" ? Theme.accentSoft : Theme.muted
                font.family: Theme.mono
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Row {
                id: rightRow
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                spacing: 12
                readonly property bool sp: Spotify.ready && Spotify.playback !== null

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rightRow.sp
                    text: "󰒟"
                    color: Spotify.shuffle ? Theme.accent : shufMouse.containsMouse ? Theme.cream : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 14
                    MouseArea {
                        id: shufMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Spotify.toggleShuffle()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rightRow.sp
                    text: Spotify.repeat === "track" ? "󰑘" : "󰑖"
                    color: Spotify.repeat !== "off" ? Theme.accent : repMouse.containsMouse ? Theme.cream : Theme.faint
                    font.family: Theme.icons
                    font.pixelSize: 14
                    MouseArea {
                        id: repMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Spotify.cycleRepeat()
                    }
                }

                // Lautstärke des Spotify-Geräts
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rightRow.sp && Spotify.canVolume
                    spacing: 7
                    readonly property real v: (Spotify.wantedVolume >= 0 ? Spotify.wantedVolume : Spotify.volume) / 100

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.v > 0 ? "󰕾" : "󰖁"
                        color: Theme.accent
                        font.family: Theme.icons
                        font.pixelSize: 13
                    }
                    Item {
                        id: vol
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        height: 14
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.12)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * parent.parent.v
                            height: 4
                            radius: 2
                            color: Theme.accent
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * parent.parent.v - width / 2
                            width: volMouse.pressed || volMouse.containsMouse ? 12 : 10
                            height: width
                            radius: width / 2
                            color: Theme.cream
                            border.width: 2
                            border.color: Theme.accent
                        }
                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            function set(x) { Spotify.setVolume((x - 5) / vol.width * 100) }
                            onPressed: m => set(m.x)
                            onPositionChanged: m => { if (pressed) set(m.x) }
                        }
                        WheelHandler {
                            onWheel: e => Spotify.setVolume(vol.parent.v * 100 + (e.angleDelta.y > 0 ? 5 : -5))
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        text: Math.round(parent.v * 100) + "%"
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }

                // Gerät, auf dem Spotify spielt
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rightRow.sp && Spotify.deviceName !== ""
                    width: Math.min(130, devText.implicitWidth + 16)
                    height: 19
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Theme.hairline
                    Text {
                        id: devText
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: Text.AlignVCenter
                        text: "󰓃 " + Spotify.deviceName.toLowerCase()
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                // mehrere Player (Spotify + YouTube …) → durchschalten
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.players.length > 1
                    width: countText.implicitWidth + 14
                    height: 19
                    radius: 5
                    color: Theme.accent
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: (root.players.indexOf(root.player) + 1) + "/" + root.players.length
                        color: Theme.ink
                        font.family: Theme.mono
                        font.weight: Font.Bold
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const ps = root.players
                            if (ps.length > 1) Media.active = ps[(ps.indexOf(root.player) + 1) % ps.length]
                        }
                    }
                }
            }
        }
    }
}
