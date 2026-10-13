pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fenstermodus „geordnet“ (Tiling) / „frei“ (schwebend wie bei Windows) – hier nur zum Anzeigen.
// Umgeschaltet wird in hyprland.lua (SUPER+O → golden.toggle_window_mode), das den Zustand nach
// ~/.local/state/8155/fenstermodus.json schreibt; diese Datei wird hier beobachtet.
Singleton {
    id: mode

    readonly property bool free: store.free

    function toggle() {
        Quickshell.execDetached(["hyprctl", "eval", "golden.toggle_window_mode()"])
    }

    FileView {
        path: Theme.home + "/.local/state/8155/fenstermodus.json"
        watchChanges: true
        printErrors: false          // Hyprland schreibt die Datei in einem Rutsch neu → kurz leer ist normal
        onFileChanged: reload()

        JsonAdapter {
            id: store
            property bool free: false
        }
    }
}
