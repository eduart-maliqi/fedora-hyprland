import QtQuick
import Quickshell
import Quickshell.Io

// App „Wallpaper“ (Super+Leertaste → „wallpaper“, oder `qs ipc call studio open|close|toggle`): normales Fenster mit
//   links  „bilder“     – alle Wallpaper; hinzufügen (Dateiauswahl oder Bilder ins Fenster ziehen → 2880×1800 zugeschnitten),
//                         setzen, anderem Farbthema zuordnen (= umbenennen), löschen (Papierkorb)
//   mitte  „vorschau“   – Mini-Desktop (ThemePreview.qml) mit gewähltem Bild + der Palette, die gerade bearbeitet wird;
//                         der echte Desktop ändert sich erst mit „setzen“ / „speichern“
//   rechts „farbthemen“ – Thema wählen, neu anlegen, löschen; Farben bearbeiten: „vorschlag“ (Akzent, Tinte, Glas –
//                         der Rest wird abgeleitet; oder „aus bild“) bzw. „alle farben“ einzeln
// Gespeichert wird in hypr/themen/<name>/farben.json, die Programm-Dateien erzeugt hypr/scripts/thema-bauen.py.
FloatingWindow {
    id: root

    title: "wallpaper · 8155"
    visible: false
    implicitWidth: 1420
    implicitHeight: 880
    color: "transparent"

    readonly property string hypr: Theme.home + "/.config/hypr"
    readonly property string wallSh: hypr + "/scripts/wallpaper.sh"
    readonly property string bauen: hypr + "/scripts/thema-bauen.py"

    property var walls: []              // { path, label, theme }
    property string activePath: ""
    property string selPath: ""
    readonly property var selWall: walls.find(w => w.path === selPath) ?? null

    property string selTheme: Theme.name
    property bool isNew: false
    property var draft: Theme.palettes[selTheme] ?? Theme.p
    property string mode: "vorschlag"
    property string status: ""
    property string confirm: ""         // "bild" | "thema" – zweiter Klick löscht wirklich
    readonly property bool dirty: isNew || norm(draft) !== norm(Theme.palettes[selTheme])
    property string pendingSave: ""
    function norm(o) { return JSON.stringify(Object.keys(o ?? {}).filter(k => k !== "name").sort().map(k => [k, o[k]])) }

    function open() {
        if (visible) return
        visible = true
        selTheme = Theme.name
        isNew = false
        draft = Theme.palettes[selTheme]
        scan()
    }

    onSelThemeChanged: confirm = ""
    onSelPathChanged: confirm = ""

    // ── Befehle ──────────────────────────────────────────────────────────────
    // Alles läuft über einen Prozess: Ausgabe (inkl. Fehler) + Rückgabewert in der letzten Zeile „::<code>“,
    // damit Ausgabe und Ende nicht in zwei Signalen unbestimmter Reihenfolge ankommen.
    Process {
        id: job
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.replace(/\n$/, "").split("\n")
                const last = lines.pop() ?? ""
                const code = last.startsWith("::") ? parseInt(last.slice(2)) : 1
                const out = lines.join("\n")
                const cb = job.done
                job.done = null
                if (code !== 0) root.status = (out.trim().split("\n").pop() || "fehler") + ""
                if (cb) cb(code, out)
            }
        }
    }
    function run(script, args, cb) {
        if (job.running) { status = "moment …"; return }
        job.done = cb ?? null
        job.command = ["sh", "-c", "{ " + script + "\n} 2>&1; echo \"::$?\"", "sh", ...args]
        job.running = true
    }

    function scan() {
        run("readlink -f \"$1/current\"; echo ---; find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg'"
            + " -o -iname '*.png' -o -iname '*.webp' \\) | sort", [hypr + "/wallpapers"], (code, out) => {
            const [cur, list] = out.split("---\n")
            activePath = (cur ?? "").trim()
            walls = (list ?? "").split("\n").filter(p => p).map(p => {
                const n = p.split("/").pop().replace(/\.[^.]+$/, "")
                const i = n.indexOf("-")
                const t = i > 0 ? n.slice(0, i) : ""
                return { path: p, label: i > 0 ? n.slice(i + 1) : n, theme: Theme.palettes[t] ? t : "golden" }
            })
            if (!walls.find(w => w.path === selPath))
                selPath = walls.find(w => w.path === activePath)?.path ?? walls[0]?.path ?? ""
        })
    }

    function addFiles(paths) {
        const t = isNew ? "golden" : selTheme
        run("w=\"$1\"; t=\"$2\"; shift 2; for f in \"$@\"; do \"$w\" neu \"$f\" \"$t\"; done", [wallSh, t, ...paths], (code, out) => {
            const added = out.split("\n").filter(l => l.startsWith("/"))
            if (added.length) { selPath = added[added.length - 1]; status = added.length + " bild(er) hinzugefügt" }
            scan()
        })
    }
    function pickFiles() {
        const t = isNew ? "golden" : selTheme
        run("zenity --file-selection --multiple --separator='\n' --title='wallpaper hinzufügen'"
            + " --file-filter='bilder | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP'"
            + " | while IFS= read -r f; do \"$1\" neu \"$f\" \"$2\"; done", [wallSh, t], (code, out) => {
            const added = out.split("\n").filter(l => l.startsWith("/"))
            if (added.length) { selPath = added[added.length - 1]; status = added.length + " bild(er) hinzugefügt" }
            scan()
        })
    }

    function setWall() {
        if (!selWall) return
        run("\"$1\" \"$2\"", [wallSh, selWall.path], code => { if (code === 0) status = "wallpaper gesetzt"; scan() })
    }
    function assignTheme() {
        if (!selWall || isNew) return
        run("\"$1\" thema \"$2\" \"$3\"", [wallSh, selWall.path, selTheme], (code, out) => {
            const p = out.split("\n").filter(l => l.startsWith("/")).pop()
            if (code === 0 && p) { selPath = p; status = "thema " + selTheme + " zugeordnet" }
            scan()
        })
    }
    function deleteWall() {
        if (!selWall) return
        if (confirm !== "bild") { confirm = "bild"; return }
        confirm = ""
        run("\"$1\" weg \"$2\"", [wallSh, selWall.path], code => {
            if (code === 0) { status = "bild im papierkorb"; selPath = "" }
            scan()
        })
    }

    // ── Farbthemen ───────────────────────────────────────────────────────────
    function hex(c) {
        const q = Qt.color(c)
        const f = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
        return "#" + f(q.r) + f(q.g) + f(q.b)
    }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b)
        return hex(Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1))
    }
    function arrHex(a) { return hex(Qt.rgba(a[0], a[1], a[2], 1)) }
    function hexArr(h) { const q = Qt.color(h); return [q.r, q.g, q.b].map(v => Math.round(v * 1000) / 1000) }

    // Vorschlag: aus Akzent, Tinte und Glas den Rest ableiten (Verhältnisse wie bei den eingebauten Themen)
    function derive(accent, ink, glass) {
        const h = Qt.color(accent).hslHue
        const reddish = h >= 0 && (h < 0.07 || h > 0.88)
        const base = hexArr(glass)
        return {
            accent: accent, accentSoft: mix(accent, "#ffffff", 0.45), accentDeep: mix(accent, "#000000", 0.3),
            cream: mix("#eeeeee", accent, 0.06), muted: mix("#aaaaaa", accent, 0.08), dim: mix("#979797", accent, 0.08),
            faint: mix("#777777", accent, 0.08), ink: ink, onAccentMuted: mix(accent, "#000000", 0.7),
            red: reddish ? "#ffb054" : "#e0714f",       // Akzent schon rot → Warnungen orange
            base: base, hover: base.map(v => Math.round(Math.min(1, v + 0.06) * 1000) / 1000), hair: [1, 1, 1, 0.08],
            panel: mix(glass, "#ffffff", 0.02), term: mix(glass, "#ffffff", 0.02), termInk: ink,
            termTab: mix(glass, "#ffffff", 0.06), rofiHair: "#ffffff17", lockBrightness: draft.lockBrightness ?? 0.8
        }
    }
    function setColor(key, value) {
        if (mode === "vorschlag") {
            const a = key === "accent" ? value : draft.accent
            const i = key === "ink" ? value : draft.ink
            const g = key === "base" ? value : arrHex(draft.base)
            draft = derive(a, i, g)
        } else {
            const d = Object.assign({}, draft)
            if (key === "base" || key === "hover") d[key] = hexArr(value)
            else d[key] = value
            draft = d
        }
    }
    function suggest() {
        if (!selWall) return
        run("python3 \"$1\" vorschlag \"$2\"", [bauen, selWall.path], (code, out) => {
            if (code !== 0) return
            try {
                const j = JSON.parse(out.trim().split("\n").pop())
                draft = derive(j.accent, j.ink, arrHex(j.base))
                status = "farben aus dem bild vorgeschlagen"
            } catch (e) { status = "vorschlag fehlgeschlagen" }
        })
    }
    function selectTheme(n) {
        selTheme = n
        isNew = false
        draft = Theme.palettes[n]
    }
    function newTheme(n) {
        if (!/^[a-z]{2,16}$/.test(n)) { status = "name: nur a–z, 2–16 zeichen"; return }
        if (Theme.palettes[n]) { status = "„" + n + "“ gibt es schon"; return }
        const d = Object.assign({}, draft)
        delete d.clockDate                       // gehört zur Vorlage (purpur), nicht zum neuen Thema
        selTheme = n
        isNew = true
        draft = d
        status = "neues thema – farben anpassen, dann speichern"
    }
    function saveTheme() {
        const n = selTheme
        const d = Object.assign({}, draft)
        delete d.name
        run("printf '%s' \"$1\" | python3 \"$2\" speichern \"$3\" && if [ \"$3\" = \"$4\" ]; then \"$5\" \"$3\"; else qs ipc call theme reload; fi",
            [JSON.stringify(d), bauen, n, Theme.name, hypr + "/scripts/thema.sh"], code => {
            if (code !== 0) return
            isNew = false
            pendingSave = n
            status = "„" + n + "“ gespeichert"
        })
    }
    function deleteTheme() {
        if (isNew) { selectTheme(Theme.name); return }
        if (confirm !== "thema") { confirm = "thema"; return }
        confirm = ""
        const n = selTheme
        run("python3 \"$1\" loeschen \"$2\" && qs ipc call theme reload", [bauen, n], code => {
            if (code !== 0) return
            status = "„" + n + "“ im papierkorb"
            selectTheme(Theme.name)
            scan()
        })
    }
    // nach theme reload: nicht gespeicherte Änderungen behalten, sonst die frisch gelesene Palette zeigen
    Connections {
        target: Theme
        function onPalettesChanged() {
            if (root.pendingSave && Theme.palettes[root.pendingSave]) {
                if (root.pendingSave === root.selTheme) root.draft = Theme.palettes[root.selTheme]
                root.pendingSave = ""
            }
            if (!root.isNew && !Theme.palettes[root.selTheme]) root.selectTheme(Theme.name)
        }
    }

    readonly property var allFields: [
        ["accent", "akzent"], ["accentSoft", "akzent hell · sterne, cursor"], ["accentDeep", "akzent dunkel · auswahl"],
        ["cream", "text"], ["muted", "nebentext"], ["dim", "nebentext dunkler"], ["faint", "hinweise, inaktiv"],
        ["ink", "tinte · hintergrund"], ["onAccentMuted", "nebentext auf akzent"], ["red", "warnung"],
        ["base", "glas"], ["hover", "glas unter der maus"], ["panel", "meldungen, rofi"],
        ["term", "terminal"], ["termInk", "terminal · text auf akzent"], ["termTab", "terminal · tab inaktiv"]
    ]
    readonly property var fewFields: [["accent", "akzent"], ["ink", "tinte · hintergrund"], ["base", "glas"]]

    // ── Bausteine ────────────────────────────────────────────────────────────
    component Btn: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        implicitHeight: 32
        implicitWidth: row.implicitWidth + 26
        radius: 9
        opacity: enabled ? 1 : 0.4
        color: primary ? (m.containsMouse ? Theme.accentSoft : Theme.accent)
                       : (m.containsMouse ? Theme.accentA(0.18) : Theme.glassA(0.5))
        border.width: 1
        border.color: danger ? Theme.alpha(Theme.red, m.containsMouse ? 0.9 : 0.5)
                             : (m.containsMouse ? Theme.accentA(0.6) : Theme.hairline)
        Behavior on color { ColorAnimation { duration: 140 } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Text {
                visible: btn.icon !== ""
                text: btn.icon
                color: btn.primary ? Theme.ink : (btn.danger ? Theme.red : Theme.accent)
                font.family: Theme.icons; font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: btn.text
                color: btn.primary ? Theme.ink : (btn.danger ? Theme.red : Theme.cream)
                font.family: Theme.mono; font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Heading: Text {
        color: Theme.cream
        font.family: Theme.serif; font.italic: true; font.pixelSize: 24; font.weight: Font.Medium
    }

    // ── Fenster ──────────────────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.glassA(0.86)
        radius: 14
        border.width: 1
        border.color: Theme.hairline
        focus: true
        Keys.onEscapePressed: root.visible = false

        DropArea {
            id: drop
            anchors.fill: parent
            onEntered: d => d.accept(Qt.CopyAction)
            onDropped: d => {
                const list = (d.urls ?? []).map(u => u.toString()).filter(u => u.startsWith("file://"))
                    .map(u => decodeURIComponent(u.slice(7)))
                d.accept(Qt.CopyAction)
                if (list.length) root.addFiles(list)
            }
        }
        Rectangle {
            anchors.fill: parent; radius: 14
            visible: drop.containsDrag
            color: Theme.accentA(0.12)
            border.width: 2; border.color: Theme.accentA(0.8)
            z: 10
            Text {
                anchors.centerIn: parent
                text: "loslassen = als wallpaper hinzufügen (thema " + (root.isNew ? "golden" : root.selTheme) + ")"
                color: Theme.cream; font.family: Theme.mono; font.pixelSize: 18
            }
        }

        // Kopf
        Row {
            id: head
            x: 22; y: 16
            spacing: 12
            Star { size: 16; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "wallpaper"
                color: Theme.accent
                font.family: Theme.serif; font.italic: true; font.pixelSize: 30; font.weight: Font.Medium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.status
                color: Theme.muted
                font.family: Theme.mono; font.pixelSize: 13
            }
        }
        Btn {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 18
            icon: "󰅖"; text: "schliessen"
            onClicked: root.visible = false
        }

        // links: bilder
        Column {
            id: left
            x: 22; y: 72
            width: 316
            height: parent.height - y - 22
            spacing: 10

            Heading { text: "bilder · " + root.walls.length }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - 34 - 10 - 32 - 10 - 40 - 10
                clip: true
                cellWidth: width / 2
                cellHeight: cellWidth * 10 / 16 + 8
                model: root.walls
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    readonly property bool sel: modelData.path === root.selPath
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4
                        radius: 9
                        color: Theme.glassA(0.5)
                        border.width: cell.sel ? 2 : 1
                        border.color: cell.sel ? (Theme.palettes[cell.modelData.theme]?.accent ?? Theme.accent)
                                               : (cm.containsMouse ? Theme.accentA(0.5) : Theme.hairline)
                        Image {
                            anchors.fill: parent; anchors.margins: 3
                            source: "file://" + cell.modelData.path
                            sourceSize: Qt.size(288, 180)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        Star {
                            visible: cell.modelData.path === root.activePath
                            x: 8; y: 8; size: 14
                            color: Theme.palettes[cell.modelData.theme]?.accentSoft ?? Theme.accentSoft
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                            width: 12; height: 12; radius: 6
                            color: Theme.palettes[cell.modelData.theme]?.accent ?? Theme.accent
                            border.width: 1; border.color: Theme.alpha(Theme.ink, 0.6)
                        }
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selPath = cell.modelData.path
                            if (!root.dirty) root.selectTheme(cell.modelData.theme)
                        }
                        onDoubleClicked: { root.selPath = cell.modelData.path; root.setWall() }
                    }
                }
            }

            Btn {
                width: parent.width
                icon: "󰐕"; text: "hinzufügen …"
                onClicked: root.pickFiles()
            }
            Text {
                width: parent.width
                text: "oder bilder ins fenster ziehen · neue bilder bekommen das thema rechts · doppelklick = setzen"
                wrapMode: Text.WordWrap
                color: Theme.faint
                font.family: Theme.mono; font.pixelSize: 11
            }
        }

        // rechts: farbthemen
        Item {
            id: right
            anchors.right: parent.right; anchors.rightMargin: 22
            y: 72
            width: 356
            height: parent.height - y - 22

            Column {
                id: rightTop
                width: parent.width
                spacing: 10

                Heading { text: "farbthemen" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: root.isNew ? [...Theme.names, root.selTheme] : Theme.names
                        Rectangle {
                            id: chip
                            required property string modelData
                            readonly property var pal: (root.isNew && modelData === root.selTheme) ? root.draft : Theme.palettes[modelData]
                            readonly property bool sel: modelData === root.selTheme
                            height: 30; radius: 15
                            width: chipRow.implicitWidth + 22
                            color: sel ? Theme.accentA(0.2) : (chm.containsMouse ? Theme.glassHover : Theme.glassA(0.5))
                            border.width: 1
                            border.color: sel ? Theme.accentA(0.8) : Theme.hairline
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle { width: 11; height: 11; radius: 6; color: chip.pal?.accent ?? "black"; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: 11; height: 11; radius: 6; color: chip.pal?.ink ?? "black"; border.width: 1; border.color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: " " + chip.modelData + (chip.modelData === Theme.name ? "  ★" : "")
                                    color: Theme.cream; font.family: Theme.mono; font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: chm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!(root.isNew && chip.sel)) root.selectTheme(chip.modelData)
                            }
                        }
                    }
                }

                Row {
                    spacing: 8
                    Rectangle {
                        width: 150; height: 32; radius: 9
                        color: Theme.glassA(0.5)
                        border.width: 1
                        border.color: nameIn.activeFocus ? Theme.accentA(0.6) : Theme.hairline
                        TextInput {
                            id: nameIn
                            anchors.fill: parent; anchors.leftMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.cream; selectionColor: Theme.accentDeep
                            font.family: Theme.mono; font.pixelSize: 13
                            maximumLength: 16
                            validator: RegularExpressionValidator { regularExpression: /[a-z]*/ }
                            onAccepted: { root.newTheme(text); text = "" }
                            Text {
                                visible: !parent.text && !parent.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "name (a–z)"
                                color: Theme.faint; font: parent.font
                            }
                        }
                    }
                    Btn { icon: "󰐕"; text: "neu"; onClicked: { root.newTheme(nameIn.text); nameIn.text = "" } }
                    Btn {
                        icon: "󰆴"; danger: true
                        text: root.confirm === "thema" ? "wirklich?" : "löschen"
                        enabled: root.isNew || (root.selTheme !== "golden" && root.selTheme !== Theme.name)
                        onClicked: root.deleteTheme()
                    }
                }

                // Modus
                Row {
                    spacing: 0
                    Repeater {
                        model: [["vorschlag", "vorschlag"], ["alle", "alle farben"]]
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: 120; height: 30
                            radius: 8
                            color: root.mode === modelData[0] ? Theme.accent : Theme.glassA(0.5)
                            border.width: 1; border.color: Theme.hairline
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData[1]
                                color: root.mode === parent.modelData[0] ? Theme.ink : Theme.cream
                                font.family: Theme.mono; font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.mode = parent.modelData[0]
                            }
                        }
                    }
                }
            }

            Flickable {
                id: fl
                anchors.top: rightTop.bottom; anchors.topMargin: 12
                anchors.bottom: rightBottom.top; anchors.bottomMargin: 12
                width: parent.width
                clip: true
                contentHeight: fields.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: fields
                    width: fl.width - 8
                    spacing: 10

                    Text {
                        visible: root.mode === "vorschlag"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "drei grundfarben wählen – hell/dunkel-varianten, text- und terminalfarben werden passend abgeleitet."
                        color: Theme.faint; font.family: Theme.mono; font.pixelSize: 11
                    }
                    Btn {
                        visible: root.mode === "vorschlag"
                        icon: "󰸉"; text: "aus bild vorschlagen"
                        enabled: root.selWall !== null
                        onClicked: root.suggest()
                    }
                    Repeater {
                        model: root.mode === "vorschlag" ? root.fewFields : root.allFields
                        ColorField {
                            required property var modelData
                            width: fields.width
                            label: modelData[1]
                            value: {
                                const v = root.draft?.[modelData[0]]
                                return Array.isArray(v) ? root.arrHex(v) : (v ?? "#000000")
                            }
                            onEdited: h => root.setColor(modelData[0], h)
                        }
                    }
                }
            }

            Column {
                id: rightBottom
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8
                Text {
                    text: root.dirty ? "nicht gespeichert" + (root.selTheme === Theme.name ? " · aktives thema – speichern färbt den desktop um" : "")
                                     : (root.selTheme === Theme.name ? "aktives thema" : "gespeichert")
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: root.dirty ? Theme.accentSoft : Theme.faint
                    font.family: Theme.mono; font.pixelSize: 11
                }
                Row {
                    spacing: 8
                    Btn { primary: true; icon: "󰆓"; text: "speichern"; enabled: root.dirty; onClicked: root.saveTheme() }
                    Btn {
                        icon: "󰑓"; text: "zurücksetzen"; enabled: root.dirty
                        onClicked: root.isNew ? root.selectTheme(Theme.name) : root.selectTheme(root.selTheme)
                    }
                }
            }
        }

        // mitte: vorschau
        Column {
            anchors.left: left.right; anchors.leftMargin: 24
            anchors.right: right.left; anchors.rightMargin: 24
            y: 72
            spacing: 12

            Heading { text: "vorschau · " + root.selTheme + (root.selWall ? "  ·  " + root.selWall.label : "") }

            Rectangle {
                width: parent.width
                height: preview.height + 2
                radius: 12
                color: "transparent"
                border.width: 1; border.color: Theme.hairline
                ThemePreview {
                    id: preview
                    x: 1; y: 1
                    width: parent.width - 2
                    height: implicitHeight
                    pal: root.draft ?? {}
                    image: root.selWall ? "file://" + root.selWall.path : ""
                }
            }

            Text {
                visible: root.selWall !== null
                text: root.selWall ? ("bild: " + root.selWall.path.split("/").pop() + "  ·  thema " + root.selWall.theme
                                     + (root.selWall.path === root.activePath ? "  ·  aktiv" : "")) : ""
                color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12
            }

            Flow {
                width: parent.width
                spacing: 8
                Btn {
                    primary: true; icon: "󰸉"; text: "als wallpaper setzen"
                    enabled: root.selWall !== null && root.selWall.path !== root.activePath
                    onClicked: root.setWall()
                }
                Btn {
                    icon: "󰏘"; text: "thema „" + root.selTheme + "“ zuordnen"
                    enabled: root.selWall !== null && !root.isNew && root.selWall.theme !== root.selTheme
                    onClicked: root.assignTheme()
                }
                Btn {
                    icon: "󰆴"; danger: true
                    text: root.confirm === "bild" ? "wirklich in den papierkorb?" : "bild löschen"
                    enabled: root.selWall !== null && root.walls.length > 1
                    onClicked: root.deleteWall()
                }
            }
        }
    }

    IpcHandler {
        target: "studio"
        function open(): void { root.open() }
        function close(): void { root.visible = false }
        function toggle(): void { if (root.visible) root.visible = false; else root.open() }
    }
}
