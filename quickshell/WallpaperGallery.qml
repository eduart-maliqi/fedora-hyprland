import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// Super+W: Wallpaper-Galerie – alle Bilder als Waben (Sechsecke), das zuletzt genutzte vorne
//   Wählen: Pfeile / Tab / Mausrad / Maus · übernehmen: Enter, Leertaste oder Klick (scripts/wallpaper.sh,
//   das Farbthema wechselt mit) · schließen: Esc, Super+W nochmal oder Klick daneben
//   Strg+Entf: gewähltes Bild in den Papierkorb (wallpaper.sh weg; war es aktiv, kommt vorher das zuletzt davor genutzte)
//   Reihenfolge: aktives Bild, dann ~/.local/state/8155/wallpaper-verlauf (schreibt wallpaper.sh, neuestes oben),
//   nie benutzte Bilder hinten nach Name. Der Rand der gewählten Wabe zeigt die Akzentfarbe ihres Themas.
//   Super+W fängt Hyprland ab (hyprland.lua) und meldet es als quickshell:galleryToggle.
PanelWindow {
    id: root

    property bool shown: false
    property var targetScreen: null
    screen: targetScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || content.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "golden-gallery"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var items: []              // { path, label, theme }
    property int sel: 0
    property string activePath: ""

    function toggle() {
        if (shown) shown = false
        else scan.running = true
    }
    function move(d) {
        if (items.length) sel = (sel + d + items.length) % items.length
    }
    function moveRow(d) {
        const t = sel + d * layout.k
        if (t >= 0 && t < items.length) sel = t
    }
    function apply(i) {
        const it = items[i]
        if (it && it.path !== activePath)
            Quickshell.execDetached([Theme.home + "/.config/hypr/scripts/wallpaper.sh", it.path])
        shown = false
    }

    // nach dem Löschen neu einlesen, aber offen und ungefähr an derselben Stelle bleiben
    property bool keepSel: false
    function remove(i) {
        const it = items[i]
        if (!it || del.running) return
        del.command = [Theme.home + "/.config/hypr/scripts/wallpaper.sh", "weg", it.path]
        del.running = true
    }
    Process {
        id: del
        onExited: { root.keepSel = true; scan.running = true }
    }

    function build(text) {
        const sec = [[], [], []]
        let k = 0
        for (const l of text.split("\n")) {
            if (l === "--") k++
            else if (l) sec[Math.min(k, 2)].push(l)
        }
        const files = sec[2]
        const list = []
        for (const p of [...sec[0], ...sec[1]])
            if (files.includes(p) && !list.includes(p)) list.push(p)
        for (const p of files)
            if (!list.includes(p)) list.push(p)

        items = list.map(p => {
            const n = p.split("/").pop().replace(/\.[^.]+$/, "")
            const i = n.indexOf("-")
            const t = i > 0 ? n.slice(0, i) : ""
            return { path: p, label: i > 0 ? n.slice(i + 1) : n, theme: Theme.palettes[t] ? t : "golden" }
        })
        activePath = sec[0][0] ?? ""
        if (keepSel) {
            keepSel = false
            sel = Math.min(sel, items.length - 1)
            return
        }
        sel = 0
        targetScreen = Quickshell.screens.find(s => Hyprland.monitorFor(s)?.focused) ?? Quickshell.screens[0]
        Ui.controlOpen = false
        Ui.keysOpen = false
        shown = true
    }

    GlobalShortcut { name: "galleryToggle"; description: "Super+W: Wallpaper-Galerie"; onPressed: root.toggle() }

    // qs ipc call gallery toggle | open | close
    IpcHandler {
        target: "gallery"
        function toggle(): void { root.toggle() }
        function open(): void { if (!root.shown) scan.running = true }
        function close(): void { root.shown = false }
    }

    // aktives Bild, Verlauf und alle Bilder in einem Rutsch (Abschnitte durch „--“ getrennt)
    Process {
        id: scan
        command: ["bash", "-c",
            "d=\"$HOME/.config/hypr/wallpapers\"; readlink -f \"$d/current\"; echo --; "
            + "cat \"$HOME/.local/state/8155/wallpaper-verlauf\" 2>/dev/null; echo --; "
            + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector { onStreamFinished: root.build(text) }
    }

    // Waben-Band: Bild i sitzt abwechselnd oben/unten (Zickzack), ist das Band voll, beginnt darunter das nächste –
    // zusammen ergibt das ein lückenloses Wabenmuster. Wabengröße so, dass alles auf den Bildschirm passt.
    readonly property var layout: {
        const n = Math.max(1, items.length), W = width - 160, H = height - 330, g = 14
        let w = 300, k = 1, strips = 1
        for (; w > 90; w -= 10) {
            k = Math.max(1, Math.floor((W - w) / ((w + g) / 2)) + 1)
            strips = Math.ceil(n / k)
            if ((2 * strips - 1) * (w + g) * 0.866 + w * 1.1547 <= H) break
        }
        const sx = (w + g) / 2, sy = (w + g) * 0.866, cols = Math.min(n, k)
        const pos = []
        for (let i = 0; i < n; i++) {
            const s = Math.floor(i / k)
            const slot = i % k + Math.floor((cols - Math.min(k, n - s * k)) / 2)   // letztes Band mittig
            pos.push({ x: slot * sx, y: (2 * s + slot % 2) * sy })
        }
        return { w: w, h: w * 1.1547, k: k, pos: pos,
                 width: w + (cols - 1) * sx, height: (2 * strips - (cols > 1 ? 1 : 2)) * sy + w * 1.1547 }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Keys.onPressed: e => {
            switch (e.key) {
            case Qt.Key_Escape:    root.shown = false; break
            case Qt.Key_Left:      root.move(-1); break
            case Qt.Key_Right:     root.move(1); break
            case Qt.Key_Up:        root.moveRow(-1); break
            case Qt.Key_Down:      root.moveRow(1); break
            case Qt.Key_Tab:       root.move(1); break
            case Qt.Key_Backtab:   root.move(-1); break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:     root.apply(root.sel); break
            case Qt.Key_Delete:
                if (!(e.modifiers & Qt.ControlModifier)) return
                root.remove(root.sel); break
            default: return
            }
            e.accepted = true
        }

        // abgedunkelter Hintergrund (Blur kommt von Hyprland über layer_rule), Klick daneben schließt
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.ink, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
                onWheel: w => root.move(w.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Item {
            anchors.fill: parent
            scale: root.shown ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                anchors { bottom: honeycomb.top; bottomMargin: 46; horizontalCenter: parent.horizontalCenter }
                spacing: 10
                Star { anchors.verticalCenter: parent.verticalCenter; size: 11; color: Theme.accent }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "wallpaper"
                    color: Theme.cream
                    font.family: Theme.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: 26
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·  zuletzt genutzt zuerst"
                    color: Theme.faint
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: 18
                }
            }

            Item {
                id: honeycomb
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -20
                width: root.layout.width
                height: root.layout.height

                Repeater {
                    model: root.items

                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.sel
                        readonly property bool active: modelData.path === root.activePath
                        readonly property color tint: Theme.palettes[modelData.theme].accent
                        readonly property var hex: {
                            const w = width, h = height
                            return [Qt.point(w / 2, 0), Qt.point(w, h / 4), Qt.point(w, h * 3 / 4),
                                    Qt.point(w / 2, h), Qt.point(0, h * 3 / 4), Qt.point(0, h / 4), Qt.point(w / 2, 0)]
                        }

                        x: root.layout.pos[index]?.x ?? 0
                        y: root.layout.pos[index]?.y ?? 0
                        width: root.layout.w
                        height: root.layout.h
                        z: selected ? 2 : 1
                        scale: selected ? 1.07 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Image {
                            id: img
                            anchors.fill: parent
                            visible: false
                            source: "file://" + tile.modelData.path
                            sourceSize.height: tile.height * 2       // Vorschau statt 2880×1800 dekodieren
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Item {
                            id: hexMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeWidth: -1
                                    fillColor: "white"
                                    PathPolyline { path: tile.hex }
                                }
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: img
                            maskEnabled: true
                            maskSource: hexMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                            // nicht gewählte Waben etwas zurücknehmen
                            brightness: tile.selected ? 0 : -0.1
                            Behavior on brightness { NumberAnimation { duration: 160 } }
                        }

                        Shape {
                            id: outline
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            containsMode: Shape.FillContains
                            ShapePath {
                                strokeWidth: tile.selected ? 2.5 : 1
                                strokeColor: tile.selected ? tile.tint : Theme.hairline
                                fillColor: "transparent"
                                joinStyle: ShapePath.MiterJoin
                                PathPolyline { path: tile.hex }
                            }
                        }

                        // aktives Bild: Stern an der oberen Spitze
                        Star {
                            visible: tile.active
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.1 }
                            size: 14
                            color: tile.tint
                        }

                        MouseArea {
                            anchors.fill: parent
                            containmentMask: outline       // nur die Wabe, nicht das Rechteck (Nachbarn überlappen)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.sel = tile.index
                            onClicked: root.apply(tile.index)
                        }
                    }
                }
            }

            Column {
                anchors { top: honeycomb.bottom; topMargin: 40; horizontalCenter: parent.horizontalCenter }
                spacing: 8

                readonly property var cur: root.items[root.sel] ?? null

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.cur?.label ?? ""
                    color: Theme.cream
                    font.family: Theme.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: 30
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 4.5
                        color: Theme.palettes[parent.parent.cur?.theme ?? "golden"].accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "thema " + (parent.parent.cur?.theme ?? "")
                              + (parent.parent.cur?.path === root.activePath ? "  ·  aktiv" : "")
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 10
                    text: "← → wählen  ·  enter übernehmen  ·  strg+entf löschen  ·  esc schließen"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
        }
    }
}
