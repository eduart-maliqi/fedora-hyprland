import QtQuick
import Quickshell
import Quickshell.Io

// Ein Wallpaper-Bild – „lebendig“, wenn es dazu eine Maske gibt (Wolken ziehen, Wind im Gras, Wasser glitzert)
//   Zu <ordner>/<name>.jpg gehören (optional) in <ordner>/masken/:
//     <name>.png          R = Himmel, G = Wind (Stärke), B = Wasser
//     <name>.json         Einstellungen, z. B. {"wind": -1} = Wind von rechts nach links (Standard 1)
//   Ohne Maske wird das Bild ganz normal (still) gezeigt.
//   Der Shader steckt in shaders/wallpaper.frag (kompiliert: wallpaper.frag.qsb).
//   Benutzt von Wallpaper.qml (zwei Stück, für die Überblendung).
Item {
    id: scene
    clip: true

    property string source              // file://…, darf ein Symlink sein (wallpapers/current)
    property real time: 0               // Sekunden, kommt von Wallpaper.qml
    property real strength: 1           // 0 = still, 1 = normal bewegt
    readonly property alias status: img.status
    readonly property bool canAnimate: maskImg.status === Image.Ready && noiseImg.status === Image.Ready
    readonly property bool animating: effect.visible

    // Masken liegen neben dem echten Bild → Symlink erst auflösen
    property string realPath: ""
    property bool hasMask: false        // Maske nur laden, wenn es sie gibt – sonst warnt Qt bei jedem Bildwechsel
    readonly property string maskBase: {
        if (!realPath) return ""
        const i = realPath.lastIndexOf("/")
        return realPath.slice(0, i) + "/masken/" + realPath.slice(i + 1).replace(/\.[^.]+$/, "")
    }

    onSourceChanged: resolvePath()
    Component.onCompleted: resolvePath()

    // Befehl hier setzen statt per Binding: sonst startet der Prozess manchmal noch mit dem alten Pfad
    // (Handler läuft vor dem Binding) → das neue Bild bekam die Maske des vorigen (Doppelbild beim Wechsel nach valley)
    function resolvePath() {
        realPath = ""
        hasMask = false
        resolve.running = false
        if (!source) return
        // 1. Zeile: echter Pfad, 2. Zeile „mask“, falls masken/<name>.png existiert
        resolve.command = ["sh", "-c",
            'p=$(readlink -f "$1"); echo "$p"; d=${p%/*}; n=${p##*/}; [ -f "$d/masken/${n%.*}.png" ] && echo mask',
            "sh", source.replace(/^file:\/\//, "")]
        resolve.running = true
    }

    Process {
        id: resolve
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                scene.realPath = lines[0]
                scene.hasMask = lines[1] === "mask"
            }
        }
    }

    // Einstellungen pro Bild (fehlt die Datei → Standardwerte)
    FileView {
        id: settingsFile
        property bool ok: false
        path: scene.maskBase ? scene.maskBase + ".json" : ""
        watchChanges: true
        printErrors: false                // fehlende Datei ist normal
        onPathChanged: ok = false
        onLoaded: ok = true
        onLoadFailed: ok = false
        onFileChanged: reload()

        JsonAdapter {
            id: settings
            property real wind: 1
        }
    }

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        source: scene.source
        visible: !effect.visible
    }

    Image {
        id: maskImg
        visible: false
        asynchronous: true
        cache: false
        source: scene.hasMask ? "file://" + scene.maskBase + ".png" : ""
    }

    // weiches, kachelbares Rauschen für Böen und Wellen (der Shader kachelt es selbst per fract)
    Image {
        id: noiseImg
        visible: false
        source: Qt.resolvedUrl("shaders/rauschen.png")
    }

    // wie PreserveAspectCrop: Fläche im Seitenverhältnis des Bildes, mittig, Überstand wird abgeschnitten
    ShaderEffect {
        id: effect
        readonly property real ratio: img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 1.6
        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height * ratio)
        height: Math.max(scene.height, scene.width / ratio)
        visible: scene.strength > 0 && img.status === Image.Ready && scene.canAnimate

        property var source: img
        property var mask: maskImg
        property var noiseTex: noiseImg
        property real time: scene.time
        property real strength: scene.strength
        property real windDir: settingsFile.ok ? settings.wind : 1
        property vector2d texSize: Qt.vector2d(img.implicitWidth, img.implicitHeight)   // nicht „imageSize“: in GLSL reserviert

        fragmentShader: Qt.resolvedUrl("shaders/wallpaper.frag.qsb")
    }
}
