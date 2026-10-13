pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Wählt den „aktiven“ Player (Spotify, Browser, mpv …) über MPRIS
Singleton {
    id: media

    property MprisPlayer active: null
    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property real length: active?.length ?? 0
    readonly property real position: active?.position ?? 0

    function pick() {
        const ps = Mpris.players.values
        const nowPlaying = ps.find(p => p.isPlaying)
        if (nowPlaying) {
            active = nowPlaying
        } else if (!active || ps.indexOf(active) < 0) {
            active = ps.length > 0 ? ps[0] : null
        }
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Component.onCompleted: pick()

    Connections {
        target: Mpris.players
        function onValuesChanged() { media.pick() }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: media.pick()
    }

    // MPRIS meldet die Position nicht von selbst – während der Wiedergabe regelmäßig anstoßen
    Timer {
        interval: 120
        running: media.playing
        repeat: true
        onTriggered: media.active.positionChanged()
    }
}
