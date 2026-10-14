pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// AirDrop mit iPhone/Mac über omdrop (CLI ~/.local/opt/omdrop-plugin, Funk-Teil omdrop-owl in /usr/lib/omdrop)
//   Zustand kommt von `omdrop status --json` → stimmt auch, wenn im Terminal `omdrop on/off` läuft.
//   Geräte in der Nähe nur, solange das Panel offen und AirDrop an ist (die Namensabfrage sendet).
//   Senden: send(mac, pfade) → `omdrop send --to MAC -- PFADE…`, eine Sendung gleichzeitig.
//   Empfangen: landet in ~/airdrop, Meldung kommt von omdrop selbst (hypr/scripts/airdrop-meldung.sh).
//   qs ipc call airdrop toggle | open | close | on | off
Singleton {
    id: root

    readonly property string cli: Theme.home + "/.local/opt/omdrop-plugin/bin/omdrop"

    property bool receiving: false
    property bool discoverable: false
    property bool radioMissing: false    // omdrop-owl (Funk-Teil, /usr/lib/omdrop) nicht installiert
    property int remaining: -1           // Sekunden bis das Fenster zugeht, -1 = unbekannt / kein Ende
    property string name: ""
    property string dir: ""
    property bool switching: false       // on/off läuft gerade (dauert ein paar Sekunden)
    property string error: ""

    property var peers: []               // [{ mac, rssi }] aus dem passiven Peer-Table
    property var names: ({})             // mac → Name (aus der Namensabfrage)
    property var staged: []              // abgelegte Pfade, die auf ein Gerät warten

    property string sendTo: ""
    property string sendStatus: ""
    property bool sendFailed: false
    readonly property bool sending: sendProc.running

    readonly property bool scanning: Ui.airdropOpen && discoverable

    function refresh() { if (!statusProc.running) statusProc.running = true }

    function setOn(on) {
        if (switching) return
        switching = true
        error = ""
        switchProc.command = on ? [cli, "on", "10m"] : [cli, "off"]
        switchProc.running = true
    }
    function toggle() { setOn(!receiving) }

    // Drop-URLs (file:///…, auch http/https-Links) → Pfade bzw. Links für omdrop
    function paths(urls) {
        const out = []
        for (const u of urls) {
            const s = u.toString()
            if (s.startsWith("file://")) out.push(decodeURIComponent(s.slice(7)))
            else if (/^https?:\/\//.test(s)) out.push(s)
        }
        return out
    }

    function send(mac, list) {
        if (sending || list.length === 0) return
        sendTo = mac
        sendFailed = false
        sendStatus = "verbindet …"
        sendProc.command = [cli, "send", "--to", mac, "--"].concat(list)
        sendProc.running = true
    }
    function cancelSend() { if (sending) sendProc.signal(15) }

    function peerName(mac) { return names[mac] ?? "" }

    // omdrops englische Sätze (narrate_send) kurz auf Deutsch, Unbekanntes bleibt wie es ist
    function translate(line) {
        if (/^Asking them/.test(line)) return "wartet, bis es angenommen wird …"
        if (/^They accepted/.test(line)) return "angenommen · sendet …"
        if (/^They declined/.test(line)) return "abgelehnt"
        if (/^They never answered/.test(line)) return "keine antwort – auf dem gerät airdrop „für alle“ einstellen"
        if (/^The transfer failed/.test(line)) return "übertragung fehlgeschlagen"
        if (/^Sent /.test(line)) return "gesendet"
        if (/^waiting up to \d+s/.test(line)) return "weckt das gerät …"
        if (/^sending .* at /.test(line)) return "sendet …"
        return line
    }

    Process {
        id: statusProc
        command: [root.cli, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text)
                    root.receiving = s.receiving
                    root.discoverable = s.visible === true
                    root.radioMissing = s.visible === null
                    root.remaining = s.remaining ?? -1
                    root.name = s.name ?? ""
                    root.dir = s.dir ?? ""
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: Ui.airdropOpen || root.receiving ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // zwischen zwei Abfragen weiterzählen, damit die Restzeit flüssig läuft
    Timer {
        interval: 1000
        running: root.remaining > 0
        repeat: true
        onTriggered: root.remaining = Math.max(0, root.remaining - 1)
    }

    Process {
        id: switchProc
        stderr: StdioCollector { id: switchErr }
        onExited: code => {
            if (code !== 0) root.error = switchErr.text.trim().split("\n").pop()
            root.switching = false
            root.refresh()
        }
    }

    // ── Geräte: Peer-Table passiv alle 2 s, Namen per Abfrage (Datenstrom, je Gerät eine JSON-Zeile)
    Process {
        id: peersProc
        command: [root.cli, "peers", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.peers = JSON.parse(text) } catch (e) {}
            }
        }
    }
    Timer {
        interval: 2000
        running: root.scanning
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!peersProc.running) peersProc.running = true
    }

    Process {
        id: namesProc
        command: [root.cli, "peers", "--json", "-n", "--stream"]
        property real startedAt: 0
        onStarted: startedAt = Date.now()
        stdout: SplitParser {
            onRead: line => {
                try {
                    const p = JSON.parse(line)
                    if (!p.name) return
                    const n = Object.assign({}, root.names)
                    n[p.mac] = p.name
                    root.names = n
                } catch (e) {}
            }
        }
        // schnell gescheitert (Funk gerade erst hoch) → nicht im Takt neu starten
        onExited: namesAgain.interval = Date.now() - startedAt < 5000 ? 10000 : 500
    }
    Timer {
        id: namesAgain
        interval: 500
        running: root.scanning && !namesProc.running && !root.sending
        onTriggered: namesProc.running = true
    }
    // Panel zu → nicht weiter über Bluetooth ankündigen
    onScanningChanged: {
        if (scanning) namesAgain.restart()
        else if (namesProc.running) namesProc.signal(15)
    }

    Process {
        id: sendProc
        stdout: SplitParser { onRead: line => { if (line.trim()) root.sendStatus = root.translate(line.trim()) } }
        stderr: SplitParser { onRead: line => { if (line.trim()) root.sendStatus = root.translate(line.trim()) } }
        onExited: code => {
            root.sendFailed = code !== 0
            if (code === 0) {
                root.sendStatus = "gesendet"
                root.staged = []
            } else if (code === 143) {
                root.sendStatus = "abgebrochen"
            }
            sendClear.restart()
        }
    }
    Timer {
        id: sendClear
        interval: 8000
        onTriggered: if (!root.sending) { root.sendTo = ""; root.sendStatus = "" }
    }

    IpcHandler {
        target: "airdrop"
        function toggle(): void { Ui.airdropOpen = !Ui.airdropOpen }
        function open(): void { Ui.airdropOpen = true }
        function close(): void { Ui.airdropOpen = false }
        function on(): void { root.setOn(true) }
        function off(): void { root.setOn(false) }
    }
}
