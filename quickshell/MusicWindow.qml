import QtQuick
import Quickshell
import Quickshell.Wayland

// Fenster fürs Musik-Panel (Inhalt: MusicPanel.qml), oben links. Pro Bildschirm zwei davon (shell.qml),
// weil Quickshell die Ebene eines Fensters nachträglich nicht mehr ändert:
//   onTop: false – Bottom-Ebene, auf dem Desktop unter den Fenstern: geht von selbst auf, solange Musik läuft
//                  und auf diesem Bildschirm kein Fenster offen ist (Ui.musicDesktopOn)
//   onTop: true  – Top-Ebene, über den Fenstern: nur auf dem Bildschirm, auf dem man es geholt hat
//                  (SUPER+M → Bildschirm unter der Maus, Klick auf den Titel → diese Leiste; Ui.musicTopOn)
// Der Inhalt wird nur geladen, solange das Fenster zu sehen ist (+ kurz fürs Ausblenden) – sonst lägen
// bei drei Bildschirmen sechs komplette Panels im Speicher. Daten (Playlists, Lieder, Suche) hält Spotify.qml.
PanelWindow {
    id: win
    required property var modelData
    required property bool onTop
    readonly property bool shown: onTop ? Ui.musicTopOn(modelData) : Ui.musicDesktopOn(modelData)

    // nach dem Zumachen noch so lange da, bis die Ausblend-Animation (220/260 ms) durch ist
    property bool lingering: false
    onShownChanged: if (!shown) { lingering = true; linger.restart() }
    Timer { id: linger; interval: 320; onTriggered: win.lingering = false }

    screen: modelData
    anchors { top: true; left: true }
    margins { top: 64; left: 48 }
    implicitWidth: 800
    implicitHeight: 470
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || lingering
    WlrLayershell.layer: onTop ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "golden-music"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Loader {
        anchors.fill: parent
        active: win.visible
        sourceComponent: MusicPanel { shown: win.shown }
    }
}
