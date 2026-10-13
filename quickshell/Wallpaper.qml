import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Hintergrundbild mit weicher Überblendung beim Wechsel (SUPER+W)
// „Lebendig“ (Wolken ziehen, Gras/Bäume im Wind, Wasser glitzert – siehe WallpaperScene.qml),
// solange Ui.wallpaperAnimated an ist (SUPER+SHIFT+W). Die Bewegung pausiert, während auf
// diesem Bildschirm ein Vollbild-Fenster offen ist.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "golden-wallpaper"
    color: Theme.ink

    property string source: Ui.wallpaper

    // Bewegung: Stärke blendet beim Ein-/Ausschalten weich über, die Zeit läuft mit 30 Bildern/s
    // von 0 bis 2000 s und beginnt dann nahtlos von vorn (der Shader ist darauf abgestimmt).
    property real strength: Ui.wallpaperAnimated ? 1 : 0
    Behavior on strength { NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }
    property real time: 0
    readonly property bool covered: Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false

    Timer {
        interval: 33
        repeat: true
        running: root.strength > 0 && !root.covered && (front.canAnimate || back.canAnimate)
        property double last: 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            root.time = (root.time + Math.min(0.1, (now - last) / 1000)) % 2000
            last = now
        }
    }

    onSourceChanged: {
        back.source = front.source
        back.visible = true
        front.opacity = 0
        front.source = source
    }

    WallpaperScene {
        id: back
        anchors.fill: parent
        time: root.time
        strength: root.strength
    }

    WallpaperScene {
        id: front
        anchors.fill: parent
        source: root.source
        time: root.time
        strength: root.strength
        onStatusChanged: if (status === Image.Ready) fadeIn.restart()
    }

    // Klick aufs Wallpaper → offene Panels schließen, sonst aktives Fenster verstecken
    // (Logik in hyprland.lua: golden.desktop_click)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            // offene Panels zuerst schließen, erst danach Fenster verstecken
            if (Ui.controlOpen || Ui.musicOpen || Ui.keysOpen) {
                Ui.controlOpen = false
                Ui.musicOpen = false
                Ui.keysOpen = false
            } else {
                Quickshell.execDetached(["hyprctl", "eval", "golden.desktop_click()"])
            }
        }
    }

    NumberAnimation {
        id: fadeIn
        target: front
        property: "opacity"
        to: 1
        duration: 1100
        easing.type: Easing.InOutQuad
        onFinished: back.visible = false      // altes Bild nicht weiter mitrechnen
    }
}
