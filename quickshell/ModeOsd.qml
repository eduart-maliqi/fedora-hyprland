import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Kurzer Hinweis unten in der Mitte, wenn der Fenstermodus wechselt (SUPER+O, siehe WindowMode.qml),
// das lebendige Wallpaper an-/ausgeht (SUPER+SHIFT+W, siehe Wallpaper.qml)
// oder die Wackelfenster an-/ausgehen (SUPER+G, Plugin wobbly – hyprland.lua schreibt den Zustand nach
// ~/.local/state/8155/wackelfenster.json, die Datei wird hier beobachtet)
PanelWindow {
    id: osd
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors { bottom: true }
    margins { bottom: 64 }
    implicitWidth: row.implicitWidth + 44
    implicitHeight: 52
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: card.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "golden-osd"

    readonly property bool free: WindowMode.free
    readonly property bool animated: Ui.wallpaperAnimated
    readonly property bool wobbly: wobblyStore.enabled
    property string kind: "mode"        // was zuletzt gewechselt hat: "mode", "wallpaper" oder "wobbly"
    property bool showing: false
    property bool armed: false          // beim Start nicht aufpoppen

    onFreeChanged: pop("mode")
    onAnimatedChanged: pop("wallpaper")
    onWobblyChanged: pop("wobbly")

    function pop(k) {
        if (!armed) return
        kind = k
        showing = true
        hide.restart()
    }

    FileView {
        path: Theme.home + "/.local/state/8155/wackelfenster.json"
        watchChanges: true
        printErrors: false          // Hyprland schreibt die Datei in einem Rutsch neu → kurz leer ist normal
        onFileChanged: reload()

        JsonAdapter {
            id: wobblyStore
            property bool enabled: true
        }
    }

    Timer { interval: 1500; running: true; onTriggered: osd.armed = true }
    Timer { id: hide; interval: 1900; onTriggered: osd.showing = false }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.hairline
        opacity: osd.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: osd.kind === "wobbly" ? "󰞍"
                    : osd.kind === "wallpaper" ? (osd.animated ? "󰖝" : "󰋩")
                                               : (osd.free ? "󰖲" : "󰕮")
                color: osd.kind === "wobbly" && !osd.wobbly ? Theme.faint : Theme.accent
                font.family: Theme.icons
                font.pixelSize: 18
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: osd.kind === "wobbly" ? (osd.wobbly ? "wackelfenster: an" : "wackelfenster: aus")
                        : osd.kind === "wallpaper" ? (osd.animated ? "wallpaper: lebendig" : "wallpaper: still")
                                                   : (osd.free ? "fenster: frei" : "fenster: geordnet")
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
                Text {
                    text: osd.kind === "wobbly"
                          ? (osd.wobbly ? "fenster wackeln beim verschieben wie wackelpudding"
                                        : "fenster bleiben ruhig  ·  super + g schaltet wieder ein")
                          : osd.kind === "wallpaper"
                          ? (osd.animated ? "wolken ziehen, gras und bäume wiegen sich im wind"
                                          : "spart akku  ·  super + shift + w schaltet wieder ein")
                          : (osd.free ? "verschieben: super + maus  ·  größe: am rand ziehen"
                                      : "neue fenster ordnen sich automatisch an")
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }
        }
    }
}
