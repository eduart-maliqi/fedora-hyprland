pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Gemeinsamer UI-Zustand (per `qs ipc call …` steuerbar, siehe shell.qml)
Singleton {
    id: ui

    property string wallpaper: "file://" + Theme.home + "/.config/hypr/wallpapers/current"
    // Musik-Panel (MusicPanel.qml), pro Bildschirm zwei Fenster (MusicWindow.qml):
    //   musicOpen      – von Hand geholt (SUPER+M, Klick auf den Titel in der Leiste) → liegt über den Fenstern,
    //                    und zwar nur auf musicScreen (Bildschirm unter der Maus bzw. der angeklickten Leiste)
    //   musicAuto      – Musik läuft (bzw. lief vor < 90 s) → Panel liegt auf dem Desktop jedes leeren Bildschirms
    //   musicDismissed – mit ✕ weggeklickt → bleibt zu, bis die Musik nach einer Pause wieder startet
    property bool musicOpen: false
    property string musicScreen: ""
    property bool musicAuto: false
    property bool musicDismissed: false
    readonly property bool musicShown: musicOpen || (musicAuto && !musicDismissed)   // irgendwo zu sehen → Spotify aktiv
    readonly property bool musicPlaying: Media.playing
    property real musicPausedAt: 0
    onMusicPlayingChanged: {
        if (musicPlaying) {
            musicAutoOff.stop()
            if (Date.now() - musicPausedAt > 5000) musicDismissed = false   // kurze Lücke beim Titelwechsel zählt nicht
            musicAuto = true
        } else {
            musicPausedAt = Date.now()
            musicAutoOff.restart()
        }
    }
    onMusicOpenChanged: if (musicOpen) musicDismissed = false   // auch Desktop-Panels wieder erlauben

    Timer {
        id: musicAutoOff
        interval: 90000
        onTriggered: {
            ui.musicAuto = false
            ui.musicDismissed = false
        }
    }

    // SUPER+M / Klick auf den Titel: auf Bildschirm `name` über die Fenster holen; dort nochmal → zurück auf
    // den Desktop; liegt es auf einem anderen Bildschirm oben → dorthin wechseln.
    // Liegt es auf diesem Bildschirm schon frei sichtbar auf dem Desktop → ausblenden (wie ✕).
    // Ohne Namen: Bildschirm mit dem Fokus.
    function toggleMusic(name) {
        const target = name || Hyprland.focusedMonitor?.name || ""
        if (musicOpen && musicScreen === target) { musicOpen = false; return }
        const scr = Quickshell.screens.find(s => s.name === target)
        if (!musicOpen && scr && musicDesktopOn(scr)) { closeMusic(); return }
        openMusic(target)
    }
    function openMusic(name) {
        musicScreen = name || Hyprland.focusedMonitor?.name || ""
        musicOpen = true
    }
    function closeMusic() {
        musicOpen = false
        musicDismissed = musicAuto
    }
    // Panel über den Fenstern auf diesem Bildschirm?
    function musicTopOn(screen) {
        return musicOpen && (screen?.name ?? "") === musicScreen
    }
    // Panel auf dem Desktop dieses Bildschirms: Musik läuft, nicht weggeklickt, kein Fenster auf dem Bildschirm
    function musicDesktopOn(screen) {
        return musicAuto && !musicDismissed && !musicTopOn(screen) && screenEmpty(screen)
    }
    // irgendein Musik-Panel auf diesem Bildschirm (Lyrics rutschen dann darunter)
    function musicOn(screen) {
        return musicTopOn(screen) || musicDesktopOn(screen)
    }
    // kein Fenster auf dem sichtbaren Workspace des Bildschirms (Clawd & Co. zählen nicht, siehe skipWindow)
    function screenEmpty(screen) {
        const ws = screen ? Hyprland.monitorFor(screen)?.activeWorkspace : null
        if (!ws) return false
        return (ws.toplevels?.values ?? []).every(t => skipWindow(t))
    }

    property bool controlOpen: false
    property string controlSection: ""      // aufgeklappt im Kontrollzentrum: "", "wifi", "bluetooth", "power" oder "night"
    property var controlScreen: null         // Bildschirm, auf dem das Kontrollzentrum aufgeht
    property bool keysOpen: false            // Tastenkürzel-Übersicht (SUPER+I, KeysHelp.qml)
    property bool airdropOpen: false         // AirDrop-Fenster (AirdropPanel.qml), Bildschirm wie controlScreen
    property bool lyricsEnabled: true
    // Songtext-Bildschirm (LyricsScreen.qml): Name des Bildschirms, auf dem er offen ist, sonst ""
    property string lyricsScreen: ""
    // SUPER+SHIFT+M: auf Bildschirm `name` öffnen; dort nochmal → zu; offen woanders → dorthin wechseln
    function toggleLyricsScreen(name) {
        const target = name || Hyprland.focusedMonitor?.name || ""
        lyricsScreen = lyricsScreen === target ? "" : target
    }

    // Kontrollzentrum, Tastenkürzel-Übersicht und AirDrop liegen alle oben rechts → immer nur eins offen
    onControlOpenChanged: if (controlOpen) { keysOpen = false; airdropOpen = false }
    onKeysOpenChanged: if (keysOpen) { controlOpen = false; airdropOpen = false }
    onAirdropOpenChanged: if (airdropOpen) { controlOpen = false; keysOpen = false }
    property bool clockEnabled: true

    // Lebendiges Wallpaper (Wolken, Wind, Wasser) an/aus – SUPER+SHIFT+W, siehe Wallpaper.qml.
    // Gespeichert in ~/.local/state/8155/wallpaper.json – „an“ aber erst nach 60 s Laufzeit:
    // stürzt die Grafik gleich nach dem Einschalten ab, startet die Sitzung danach wieder mit stillem Bild.
    property bool wallpaperAnimated: false
    onWallpaperAnimatedChanged: {
        if (wallpaperAnimated) {
            saveAnimated.restart()
        } else {
            saveAnimated.stop()
            wallpaperStore.animated = false
        }
    }

    Timer {
        id: saveAnimated
        interval: 60000
        onTriggered: wallpaperStore.animated = ui.wallpaperAnimated
    }

    FileView {
        path: Theme.home + "/.local/state/8155/wallpaper.json"
        printErrors: false                  // fehlt beim ersten Start → still
        onAdapterUpdated: writeAdapter()
        onLoaded: ui.wallpaperAnimated = wallpaperStore.animated

        JsonAdapter {
            id: wallpaperStore
            property bool animated: false
        }
    }

    // Fenster, die nicht in Taskleiste, Alt+Tab und Aufgabenansicht gehören:
    // Clawd on Desk (Desktop-Pet) – Pet, Blasen und HUD sind schwebend; Einstellungen,
    // Dashboard und Willkommen sind gekachelt und bleiben sichtbar.
    // Ohne IPC-Daten (die ersten ~80 ms eines neuen Fensters) lieber ausblenden als aufblitzen.
    function skipWindow(t) {
        const o = t?.lastIpcObject
        const cls = o?.class || o?.initialClass || t?.wayland?.appId || ""
        return cls === "clawd-on-desk" && (o?.floating ?? true)
    }
}
