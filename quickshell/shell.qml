//@ pragma IconTheme WhiteSur-dark
// ★ 8155 – Quickshell
// Neu laden passiert automatisch beim Speichern. Logs: `qs log`

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component { Wallpaper {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { Bar {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { ClockWidget {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { Lyrics {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { LyricsScreen {} }
    }

    // Musik-Panel pro Bildschirm: auf dem Desktop (geht von selbst auf, wenn der Bildschirm leer ist)
    // und über den Fenstern (SUPER+M → Bildschirm unter der Maus)
    Variants {
        model: Quickshell.screens
        delegate: Component { MusicWindow { onTop: false } }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component { MusicWindow { onTop: true } }
    }

    ControlCenter {}

    AirdropPanel {}

    VolumeOsd {}

    ModeOsd {}

    BatteryWarning {}

    TaskView {}

    KeysHelp {}

    WallpaperGallery {}

    // qs ipc call wallpaper set /pfad/zum/bild.jpg | animate (lebendiges Wallpaper an/aus)
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Ui.wallpaper = "file://" + path }
        function animate(): void { Ui.wallpaperAnimated = !Ui.wallpaperAnimated }
    }

    // qs ipc call theme set golden|mond (Farbthema; ruft hypr/scripts/thema.sh beim Wallpaper-Wechsel auf) | get
    IpcHandler {
        target: "theme"
        function set(name: string): void { if (Theme.palettes[name]) Theme.name = name }
        function get(): string { return Theme.name }
    }

    // qs ipc call music toggle | toggleOn <bildschirm> | open | close
    // (Musik-Panel holen/wegräumen – ohne Namen auf dem Bildschirm mit Fokus –, über die Fenster holen, ausblenden).
    // SUPER+M ruft toggleOn mit dem Bildschirm unter der Maus auf (hyprland.lua).
    IpcHandler {
        target: "music"
        function toggle(): void { Ui.toggleMusic("") }
        function toggleOn(screen: string): void { Ui.toggleMusic(screen) }
        function open(): void { Ui.openMusic("") }
        function close(): void { Ui.closeMusic() }
    }

    // qs ipc call lyrics toggle | screenOn <bildschirm> | screenClose | style seide|fluss|flecken
    // (Songtext auf dem Desktop an/aus; Songtext-Bildschirm auf/zu – SUPER+SHIFT+M, Bildschirm unter der Maus)
    IpcHandler {
        target: "lyrics"
        function toggle(): void { Ui.lyricsEnabled = !Ui.lyricsEnabled }
        function screenOn(screen: string): void { Ui.toggleLyricsScreen(screen) }
        function screenClose(): void { Ui.lyricsScreen = "" }
        function style(name: string): void { Ui.lyricsScreenStyle = name }
    }

    // qs ipc call control toggle | close | open <bereich>   (bereich: wifi, bluetooth, power, night oder "")
    IpcHandler {
        target: "control"
        function toggle(): void { Ui.controlOpen = !Ui.controlOpen }
        function close(): void { Ui.controlOpen = false }
        function open(section: string): void {
            Ui.controlSection = section
            Ui.controlOpen = true
        }
    }

    // qs ipc call wifi toggle | close  (Kontrollzentrum mit aufgeklappter WLAN-Liste)
    IpcHandler {
        target: "wifi"
        function toggle(): void {
            const show = !(Ui.controlOpen && Ui.controlSection === "wifi")
            Ui.controlSection = show ? "wifi" : ""
            Ui.controlOpen = show
        }
        function close(): void { Ui.controlOpen = false }
    }

    // qs ipc call bluetooth toggle | close  (Kontrollzentrum mit aufgeklappter Bluetooth-Liste)
    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            const show = !(Ui.controlOpen && Ui.controlSection === "bluetooth")
            Ui.controlSection = show ? "bluetooth" : ""
            Ui.controlOpen = show
        }
        function close(): void { Ui.controlOpen = false }
    }

    // qs ipc call clock toggle
    IpcHandler {
        target: "clock"
        function toggle(): void { Ui.clockEnabled = !Ui.clockEnabled }
    }
}
