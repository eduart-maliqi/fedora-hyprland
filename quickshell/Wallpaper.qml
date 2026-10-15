import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Hintergrundbild mit weicher Überblendung beim Wechsel (SUPER+W)
// Ist ein Bild aus wallpapers/seide/ gesetzt (Ui.wallpaperSeide), liegt darüber die bewegte Seide
// (Shader shaders/seide.frag in den Farben des Themas, immer in Bewegung außer unter Vollbild-Fenstern).
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
        running: !root.covered && ((root.strength > 0 && (front.canAnimate || back.canAnimate)) || seide.visible)
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

    // bewegte Seide – in halber Größe gerechnet (weich genug), Uhr = root.time mit 30 Bildern/s statt jedem
    // Bildschirmbild: die DisplayLink-Monitore müssen jedes neue Bild über USB schicken
    Item {
        id: seide
        anchors.fill: parent
        opacity: Ui.wallpaperSeide ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
        layer.enabled: visible
        layer.smooth: true
        layer.textureSize: Qt.size(width / 2, height / 2)

        ShaderEffect {
            anchors.fill: parent
            // Runde 50 s – 2000 s (Ende der Uhr) ist ein Vielfaches davon, der Sprung dort bleibt unsichtbar
            property real phase: (root.time % 50) / 50 * Math.PI * 2
            property real aspect: width / Math.max(1, height)
            property color deep: Theme.accentDeep
            property color mid: Theme.accent
            property color soft: Theme.accentSoft
            fragmentShader: Qt.resolvedUrl("shaders/seide.frag.qsb")
        }
    }

    // Klick aufs Wallpaper → offene Panels schließen, sonst aktives Fenster verstecken
    // (Logik in hyprland.lua: golden.desktop_click)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            // offene Panels zuerst schließen, erst danach Fenster verstecken
            if (Ui.controlOpen || Ui.musicOpen || Ui.keysOpen || Ui.airdropOpen) {
                Ui.controlOpen = false
                Ui.musicOpen = false
                Ui.keysOpen = false
                Ui.airdropOpen = false
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
