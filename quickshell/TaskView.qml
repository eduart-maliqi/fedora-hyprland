import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

// Aufgabenansicht wie unter Windows – alle offenen Fenster als Live-Vorschau.
// Zwei Arten, sie zu öffnen:
//
// Super+Tab (bleibt offen, Bedienung mit Maus/Tastatur):
//   Klick / Enter                → zum Fenster wechseln (versteckte werden zurückgeholt)
//   󰅖 / Entf / Mittelklick        → Fenster schließen
//   Pfeiltasten, Tab             → auswählen
//   Esc, Super+Tab, Klick daneben → Ansicht schließen
//
// Alt+Tab (Fensterwechsler, gleiche Ansicht):
//   Alt halten + Tab     → weiter (Shift+Tab zurück), startet beim zuletzt benutzten Fenster
//   Alt loslassen        → zum markierten Fenster wechseln
//   Alt+Esc              → abbrechen
//   Klick auf eine Karte → sofort wechseln
//
// Die Tasten fängt Hyprland ab (hyprland.lua) und meldet sie über globale Kürzel:
// quickshell:taskviewToggle bzw. quickshell:switcherNext/Prev/Commit/Cancel.
//
// Tempo (gemessen, Quickshell blockiert jeweils so lange): Fenster neu anlegen ~80–100 ms, Karten anlegen
// ~25 ms, Live-Vorschauen starten ~60 ms. Darum:
//  - pro Bildschirm dauerhaft ein Fenster, in Ruhe 1×1 px, durchsichtig, klick-durchlässig; beim Öffnen
//    wird das auf dem Bildschirm mit Fokus nur groß gezogen (~20–40 ms)
//  - die Karten gibt es immer (unsichtbar), sie müssen beim Öffnen nur gezeigt werden
//  - die Vorschauen starten erst, wenn die Ansicht schon zu sehen ist (bis dahin: App-Symbol)
//  - keine Ein-/Ausblend-Animation
Scope {
    id: tv

    property bool open: false       // Ansicht bzw. Alt+Tab-Durchgang aktiv (Fenster groß, noch durchsichtig)
    property bool shown: false      // tatsächlich zu sehen (erst nach kurzer Verzögerung, siehe showTimer)
    property bool altTab: false     // per Alt+Tab geöffnet → Alt loslassen wechselt
    property int sel: 0
    property var targetScreen: null

    // normale Workspaces + versteckte, zuletzt benutzt zuerst
    function wsName(t) {
        return t.workspace?.name ?? t.lastIpcObject?.workspace?.name ?? ""
    }
    function isHidden(t) {
        return wsName(t) === "special:minimized"
    }
    // immer aktuell (auch bei geschlossener Ansicht), damit schon ein kurzes Alt+Tab das richtige Fenster trifft
    readonly property var list: Hyprland.toplevels.values
        .filter(t => {
            const ws = tv.wsName(t)
            return ws !== "" && (!ws.startsWith("special:") || ws === "special:minimized") && !Ui.skipWindow(t)
        })
        .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999))
    // Karten immer vorhalten (Vorschauen laufen trotzdem nur bei offener Ansicht, siehe win.capturing)
    ScriptModel {
        id: windows
        values: tv.list
    }
    readonly property int count: list.length
    readonly property int current: count > 0 ? Math.max(0, Math.min(sel, count - 1)) : -1

    // ── Anordnung wie bei Windows 11: alle Vorschauen gleich hoch, Breite nach Fensterform,
    //    zeilenweise gefüllt und zentriert; Höhe so groß, wie der Bildschirm hergibt ──
    readonly property int gap: 22
    readonly property int pad: 8
    readonly property int headerH: 30
    readonly property int minCardW: 230
    readonly property int maxThumbH: 380
    readonly property var layout: {
        const aw = (targetScreen?.width ?? 1728) - 160
        const ah = (targetScreen?.height ?? 1080) - 220
        const ars = windows.values.map(t => {
            const s = t.lastIpcObject?.size
            const a = s && s[1] > 0 ? s[0] / s[1] : 1.6
            return Math.max(0.55, Math.min(2.4, a))
        })

        function pack(h) {
            const rows = []
            let row = [], rw = 0
            for (let i = 0; i < ars.length; i++) {
                const cw = Math.max(minCardW, ars[i] * h + 2 * pad)
                if (row.length > 0 && rw + gap + cw > aw) {
                    rows.push({ items: row, w: rw })
                    row = []; rw = 0
                }
                rw += (row.length > 0 ? gap : 0) + cw
                row.push({ i: i, w: cw })
            }
            if (row.length > 0) rows.push({ items: row, w: rw })
            const ch = h + 2 * pad + headerH
            const th = rows.length * ch + (rows.length - 1) * gap
            return { rows: rows, ch: ch, th: th, fits: th <= ah && rows.every(r => r.w <= aw) }
        }

        let h = Math.min(maxThumbH, ah - 2 * pad - headerH)
        let p = pack(h)
        while (!p.fits && h > 70) { h -= 6; p = pack(h) }

        const gw = Math.max(0, ...p.rows.map(r => r.w))
        const pos = []
        let y = 0
        p.rows.forEach((r, ri) => {
            let x = (gw - r.w) / 2
            for (const it of r.items) {
                pos[it.i] = { x: x, y: y, w: it.w, row: ri }
                x += it.w + gap
            }
            y += p.ch + gap
        })
        return { pos: pos, rows: p.rows, w: gw, h: Math.max(0, p.th), cardH: p.ch, thumbH: h }
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(e?.icon ?? cls, "application-x-executable")
    }

    function focusedScreen() {
        return Quickshell.screens.find(s => Hyprland.monitorFor(s)?.focused) ?? Quickshell.screens[0]
    }

    function show() {
        Hyprland.refreshToplevels()
        safety.stop()
        targetScreen = focusedScreen()
        altTab = false
        sel = 0
        openedAt = Date.now()
        showTimer.restart()
        open = true
    }
    function hide() {
        open = false
        shown = false
        showTimer.stop()
        safety.stop()
    }
    function toggle() { open ? hide() : show() }

    // ── Alt+Tab ──
    property double lastStep: 0

    function step(d) {
        // Hyprland kann ein Alt+Tab doppelt melden → Doppler innerhalb weniger ms ignorieren
        const now = Date.now()
        if (now - lastStep < 15) return
        lastStep = now

        if (!open) {
            if (count === 0) return
            Hyprland.refreshToplevels()
            targetScreen = focusedScreen()
            altTab = true
            sel = 0
            openedAt = Date.now()
            showTimer.restart()
            open = true
        }
        if (count > 0) sel = ((current + d) % count + count) % count
        if (altTab) safety.restart()
    }

    function commit() {
        if (!open || !altTab) return
        const t = current >= 0 ? list[current] : null
        hide()
        activate(t)
    }

    function cancel() {
        if (altTab) hide()
    }

    // kurzes Antippen von Alt+Tab soll nicht aufblitzen → erst nach showDelay zeigen.
    // Gemessen wird mit der echten Uhrzeit: QML-Timer laufen auf Qts Animationsuhr, und die zählt Zeit,
    // in der Quickshell blockiert (z. B. beim Anlegen der Vorschauen), nicht mit.
    readonly property int showDelay: 50
    property double openedAt: 0
    Timer {
        id: showTimer
        interval: 10
        repeat: true
        onTriggered: if (Date.now() - tv.openedAt >= tv.showDelay) { stop(); tv.shown = tv.open }
    }

    // Notbremse: falls das Loslassen von Alt einmal verloren geht
    Timer {
        id: safety
        interval: 10000
        onTriggered: if (tv.altTab) tv.hide()
    }

    // Fensterdaten frisch halten, damit schon das erste Alt+Tab stimmt
    Timer {
        id: refresh
        interval: 80
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindowv2", "openwindow", "closewindow", "movewindowv2", "windowtitlev2"].includes(event.name))
                refresh.restart()
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    function addr(t) {
        const a = t.lastIpcObject?.address ?? t.address
        return a.startsWith("0x") ? a : "0x" + a
    }

    function activate(t) {
        if (!t) return
        hide()
        Quickshell.execDetached(["hyprctl", "eval", "golden.focus_window('" + addr(t) + "')"])
    }

    function closeWindow(t) {
        if (!t) return
        if (t.wayland) t.wayland.close()
        else Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.window.close({ window = 'address:" + addr(t) + "' }))"])
    }

    function move(dx, dy) {
        if (count === 0) return
        if (dy === 0) {
            sel = ((current + dx) % count + count) % count
            return
        }
        // hoch/runter: in der Nachbarzeile die Karte, die am nächsten darüber/darunter liegt
        const p = layout.pos[current]
        const r = layout.rows[p.row + dy]
        if (!r) return
        const cx = p.x + p.w / 2
        let best = r.items[0].i
        for (const it of r.items) {
            const q = layout.pos[it.i]
            if (Math.abs(q.x + q.w / 2 - cx) < Math.abs(layout.pos[best].x + layout.pos[best].w / 2 - cx)) best = it.i
        }
        sel = best
    }

    GlobalShortcut { name: "taskviewToggle"; description: "Super+Tab: Aufgabenansicht"; onPressed: tv.toggle() }

    GlobalShortcut { name: "switcherNext";   description: "Alt+Tab: nächstes Fenster";   onPressed: tv.step(1) }
    GlobalShortcut { name: "switcherPrev";   description: "Alt+Tab: vorheriges Fenster"; onPressed: tv.step(-1) }
    // Release-Binds in Hyprland melden sich als „released“ → beide Signale annehmen
    GlobalShortcut { name: "switcherCommit"; description: "Alt+Tab: wechseln";           onPressed: tv.commit(); onReleased: tv.commit() }
    GlobalShortcut { name: "switcherCancel"; description: "Alt+Tab: abbrechen";          onPressed: tv.cancel(); onReleased: tv.cancel() }

    // qs ipc call taskview toggle | open | close
    IpcHandler {
        target: "taskview"
        function toggle(): void { tv.toggle() }
        function open(): void { tv.show() }
        function close(): void { tv.hide() }
    }

    // Zum Testen/Debuggen: qs ipc call switcher state | items
    IpcHandler {
        target: "switcher"
        function state(): string {
            return JSON.stringify({ open: tv.open, shown: tv.shown, altTab: tv.altTab, sel: tv.sel, current: tv.current, items: tv.count,
                                    screen: tv.targetScreen?.name ?? null })
        }
        function items(): string {
            return JSON.stringify(tv.list.map(t => ({
                title: t.title,
                ws: tv.wsName(t),
                hist: t.lastIpcObject?.focusHistoryID ?? null
            })))
        }
    }

    // ── ein Fenster pro Bildschirm, dauerhaft da ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            // dieser Bildschirm zeigt gerade die Ansicht
            readonly property bool active: tv.open && tv.targetScreen === modelData

            screen: modelData
            // in Ruhe 1×1 px oben links, offen: ganzer Bildschirm
            anchors { top: true; left: true; bottom: win.active; right: win.active }
            implicitWidth: 1
            implicitHeight: 1
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // solange nichts zu sehen ist, gehen Maus-Klicks durch (leere Region), danach nimmt es alle an
            mask: win.active && tv.shown ? null : noInput
            Region { id: noInput }

            // Vorschauen erst starten, wenn das erste Bild mit sichtbarer Ansicht draußen ist – ihr Start
            // blockiert Quickshell ~60 ms und würde sonst das Erscheinen aufhalten
            property bool capturing: false
            onActiveChanged: if (!active) capturing = false
            Connections {
                target: content.Window.window
                function onFrameSwapped() { if (content.visible && !win.capturing) win.capturing = true }
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "golden-taskview"
            // bei Alt+Tab keine Tastatur: die Tasten kommen über Hyprland, das Fenster darunter behält den Fokus
            WlrLayershell.keyboardFocus: win.active && !tv.altTab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: content
                anchors.fill: parent
                focus: true
                // ohne Animation: einfach da (Wunsch: schnell)
                visible: win.active && tv.shown

                Keys.onPressed: e => {
                    const t = tv.current >= 0 ? windows.values[tv.current] : null
                    switch (e.key) {
                    case Qt.Key_Escape:    tv.hide(); break
                    case Qt.Key_Left:      tv.move(-1, 0); break
                    case Qt.Key_Right:     tv.move(1, 0); break
                    case Qt.Key_Up:        tv.move(0, -1); break
                    case Qt.Key_Down:      tv.move(0, 1); break
                    case Qt.Key_Tab:       tv.move(1, 0); break
                    case Qt.Key_Backtab:   tv.move(-1, 0); break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:     tv.activate(t); break
                    case Qt.Key_Delete:    tv.closeWindow(t); break
                    default: return
                    }
                    e.accepted = true
                }

                // abgedunkelter Hintergrund (Blur kommt von Hyprland über layer_rule), Klick daneben schließt
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.04, 0.05, 0.07, 0.55)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tv.hide()
                    }
                }

                Row {
                    anchors { top: parent.top; topMargin: 56; horizontalCenter: parent.horizontalCenter }
                    spacing: 10
                    Star { anchors.verticalCenter: parent.verticalCenter; size: 11; color: Theme.accent }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tv.count === 1 ? "1 offenes Fenster" : tv.count + " offene Fenster"
                        color: Theme.cream
                        font.family: Theme.serif
                        font.italic: true
                        font.weight: Font.Medium
                        font.pixelSize: 26
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: tv.count === 0
                    text: "keine offenen Fenster"
                    color: Theme.muted
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: 22
                }

                Item {
                    id: grid
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    width: tv.layout.w
                    height: tv.layout.h

                    Repeater {
                        // auf jedem Bildschirm vorbereitet (unsichtbar, solange zu)
                        model: windows

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property var tl: modelData
                            readonly property bool hidden: tv.isHidden(tl)
                            readonly property bool selected: index === tv.current
                            readonly property string cls: tl.lastIpcObject?.class || tl.lastIpcObject?.initialClass || tl.wayland?.appId || ""

                            readonly property var pos: tv.layout.pos[index] ?? { x: 0, y: 0, w: tv.minCardW }

                            x: pos.x
                            y: pos.y
                            width: pos.w
                            height: tv.layout.cardH
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            radius: 14
                            color: selected ? Theme.accentA(0.14)
                                 : cardMouse.containsMouse ? Qt.tint(Theme.glassStrong, Qt.rgba(1, 1, 1, 0.05))
                                 : Theme.glassStrong
                            border.width: 1
                            border.color: selected ? Theme.accentA(0.8) : Theme.hairline

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                // bei Alt+Tab wählt nur die Tastatur aus – sonst springt die Auswahl auf die Karte,
                                // die zufällig unter der Maus aufgeht
                                onEntered: if (!tv.altTab) tv.sel = card.index
                                onClicked: m => {
                                    if (m.button === Qt.MiddleButton) tv.closeWindow(card.tl)
                                    else tv.activate(card.tl)
                                }
                            }

                            // Kopfzeile: Symbol · Titel · Workspace · Schließen
                            Item {
                                id: header
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: tv.pad }
                                height: tv.headerH

                                IconImage {
                                    id: appIcon
                                    anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                                    implicitSize: 18
                                    source: tv.iconFor(card.cls)
                                }

                                Text {
                                    anchors { left: appIcon.right; leftMargin: 8; right: wsTag.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: card.tl.title || card.cls
                                    color: card.selected ? Theme.cream : Theme.muted
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Row {
                                    id: wsTag
                                    anchors { right: closeBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    spacing: 5
                                    Star {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 7
                                        color: card.hidden ? Theme.faint : Theme.accent
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: card.hidden ? "versteckt" : tv.wsName(card.tl)
                                        color: card.hidden ? Theme.faint : Theme.accentSoft
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                    }
                                }

                                Rectangle {
                                    id: closeBtn
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: closeMouse.containsMouse ? Theme.alpha(Theme.red, 0.85) : Qt.rgba(1, 1, 1, 0.06)
                                    opacity: card.selected || closeMouse.containsMouse ? 1 : 0.55

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: closeMouse.containsMouse ? Theme.ink : Theme.cream
                                        font.family: Theme.icons
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: if (!tv.altTab) tv.sel = card.index
                                        onClicked: tv.closeWindow(card.tl)
                                    }
                                }
                            }

                            // Live-Vorschau des Fensters
                            ClippingRectangle {
                                id: thumbBox
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: tv.pad }
                                height: tv.layout.thumbH
                                radius: 9
                                color: Qt.rgba(0, 0, 0, 0.25)

                                ScreencopyView {
                                    id: shot
                                    anchors.centerIn: parent
                                    captureSource: win.capturing ? (card.tl.wayland ?? null) : null
                                    live: true
                                    constraintSize: Qt.size(thumbBox.width, thumbBox.height)
                                    width: hasContent ? implicitWidth : 0
                                    height: hasContent ? implicitHeight : 0
                                    opacity: card.hidden ? 0.6 : 1
                                }

                                // ohne Vorschau (z. B. noch nicht gerendert): großes App-Symbol
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: !shot.hasContent
                                    implicitSize: Math.min(72, thumbBox.height * 0.45)
                                    source: tv.iconFor(card.cls)
                                    opacity: 0.8
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors { bottom: parent.bottom; bottomMargin: 44; horizontalCenter: parent.horizontalCenter }
                    text: tv.altTab
                        ? "Tab weiter  ·  Shift+Tab zurück  ·  Alt loslassen wechseln  ·  Esc abbrechen"
                        : "Enter wechseln  ·  Entf / Mittelklick schließen  ·  Esc zurück"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
        }
    }
}
