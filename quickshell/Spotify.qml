pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Spotify Web API fürs Musik-Panel (MusicPanel.qml): Bibliothek, Suche, Abspielen, ♥, Wiedergabe-Status.
// Token kommt von ~/.config/hypr/scripts/spotify-auth.py (einmal `… login <client-id>`).
// Läuft nur, solange das Panel offen ist (Ui.musicShown) – sonst keine Anfragen.
// Seit Feb. 2026 (Development Mode): Suche max. 10 Treffer, Inhalt nur von eigenen Playlists,
// Bibliothek über /me/library.
Singleton {
    id: sp

    readonly property string authScript: Theme.home + "/.config/hypr/scripts/spotify-auth.py"
    readonly property string api: "https://api.spotify.com/v1"

    // ── Anmeldung ──
    property string token: ""
    property real tokenExpires: 0            // ms
    property string authState: "unknown"     // unknown | ok | none (nicht eingerichtet) | invalid (neu anmelden) | offline
    readonly property bool ready: authState === "ok"
    property var waiting: []                 // Anfragen, die auf ein Token warten
    // Spotify verwirft Tokens manchmal vor Ablauf – dann würde `token` dasselbe tote Token wieder liefern
    property bool forceRefresh: false
    property real backoffUntil: 0            // nach „429 zu viele Anfragen“

    // ── Bibliothek / Liste in der Mitte ──
    property string userId: ""
    property var playlists: []               // [{ id, uri, name, owned }]
    property string source: "liked"          // liked | recent | playlist:<id> | search
    property string sourceName: "lieblingssongs"
    property string lastSource: "liked"      // wohin die Suche zurückkehrt
    property string contextUri: ""           // Playlist-URI zum Abspielen
    property var tracks: []                  // [{ uri, name, artist, album, ms }]
    property string listState: "idle"        // idle | loading | ok | empty | locked | error
    property string nextUrl: ""              // nächste Seite (Playlists/Lieblingssongs)
    property bool loadingMore: false
    property int gen: 0                      // verwirft Antworten auf veraltete Anfragen
    property string query: ""
    property bool started: false

    // ── Wiedergabe (GET /me/player) ──
    property var playback: null
    property real fetchedAt: 0
    property real clock: Date.now()
    readonly property var item: playback?.item ?? null
    readonly property string currentUri: item?.uri ?? ""
    readonly property bool isPlaying: playback?.is_playing ?? false
    readonly property bool shuffle: playback?.shuffle_state ?? false
    readonly property string repeat: playback?.repeat_state ?? "off"      // off | context | track
    readonly property bool canVolume: playback?.device?.supports_volume ?? false
    readonly property int volume: playback?.device?.volume_percent ?? 0
    readonly property string deviceName: playback?.device?.name ?? ""
    readonly property string itemArtist: (item?.artists ?? []).map(a => a.name).join(", ")
    readonly property string itemAlbum: item?.album?.name ?? ""
    readonly property string itemImage: (item?.album?.images ?? item?.images ?? [])[0]?.url ?? ""
    readonly property real position: {
        if (!playback) return 0
        const ms = (playback.progress_ms ?? 0) + (isPlaying ? clock - fetchedAt : 0)
        return Math.min(ms, item?.duration_ms ?? ms) / 1000
    }
    property bool liked: false
    property bool noDevice: false            // kein Spotify offen → Knopf „spotify öffnen“
    property string message: ""

    readonly property bool active: Ui.musicShown || Ui.lyricsScreen !== ""   // Songtext-Bildschirm braucht das große Cover
    onActiveChanged: if (active) start()
    onCurrentUriChanged: checkLiked()

    // ─────────────────────────── Token ───────────────────────────

    Process {
        id: tokenProc
        property bool refresh: false
        command: ["python3", sp.authScript, "token"].concat(refresh ? ["--refresh"] : [])
        stdout: StdioCollector { onStreamFinished: sp.gotToken(text) }
    }

    Process {
        id: loginProc
        command: ["python3", sp.authScript, "login"]
        onExited: {
            sp.token = ""
            sp.started = false
            sp.start()
        }
    }

    function gotToken(text) {
        let d = null
        try { d = JSON.parse(text) } catch (e) {}
        const q = waiting
        waiting = []
        if (d && d.access_token) {
            token = d.access_token
            tokenExpires = d.expires_at * 1000
            authState = "ok"
            for (const f of q) f()
        } else {
            token = ""
            authState = d?.error === "not_logged_in" ? "none" : d?.error === "invalid_grant" ? "invalid" : "offline"
        }
    }

    function withToken(f) {
        if (token !== "" && Date.now() < tokenExpires - 60000) return f()
        waiting = waiting.concat([f])
        if (!tokenProc.running) {
            tokenProc.refresh = forceRefresh
            forceRefresh = false
            tokenProc.running = true
        }
    }

    // neu anmelden (öffnet den Browser; Client-ID ist gespeichert)
    function relogin() {
        if (!loginProc.running) loginProc.running = true
    }

    function retry() {
        started = false
        start()
    }

    // nicht verbunden → alle 10 s still nachsehen (z. B. nach `spotify-auth.py login` im Terminal)
    Timer {
        interval: 10000
        repeat: true
        running: sp.active && !sp.ready && sp.authState !== "unknown" && !loginProc.running
        onTriggered: sp.retry()
    }

    // ─────────────────────────── Anfragen ───────────────────────────

    // cb(status, json)
    function call(method, path, body, cb, retried) {
        if (Date.now() < backoffUntil) { if (cb) cb(429, null); return }
        withToken(() => {
            const xhr = new XMLHttpRequest()
            const used = sp.token
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 401 && !retried) {
                    if (used === sp.token) {
                        sp.token = ""
                        sp.forceRefresh = true
                    }
                    return sp.call(method, path, body, cb, true)
                }
                if (xhr.status === 401) {               // auch das frische Token abgelehnt
                    sp.token = ""
                    sp.authState = "invalid"
                }
                if (xhr.status === 429) {
                    const wait = parseInt(xhr.getResponseHeader("Retry-After") || "5")
                    sp.backoffUntil = Date.now() + Math.max(2, wait) * 1000
                    sp.say("spotify bremst – kurz warten")
                }
                let data = null
                if (xhr.responseText) { try { data = JSON.parse(xhr.responseText) } catch (e) {} }
                if (cb) cb(xhr.status, data)
            }
            xhr.open(method, path.startsWith("http") ? path : sp.api + path)
            xhr.setRequestHeader("Authorization", "Bearer " + sp.token)
            if (body) {
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.send(JSON.stringify(body))
            } else {
                xhr.send(method === "GET" ? null : "")
            }
        })
    }

    function say(text) {
        message = text
        messageClear.restart()
    }

    Timer {
        id: messageClear
        interval: 4500
        onTriggered: sp.message = ""
    }

    // ─────────────────────────── Bibliothek ───────────────────────────

    function start() {
        if (started && ready) { refresh(); return }
        withToken(() => { if (!sp.started) sp.init() })
    }

    function init() {
        started = true
        call("GET", "/me", null, (st, d) => {
            if (st !== 200) return
            sp.userId = d?.id ?? ""
            sp.loadPlaylists()
        })
        if (source === "search" && query !== "") search(query)
        else open(source)
        refresh()
    }

    function loadPlaylists(url, acc) {
        call("GET", url || "/me/playlists?limit=50", null, (st, d) => {
            if (st !== 200) return
            const list = (acc || []).concat((d?.items ?? []).filter(p => p).map(p => ({
                id: p.id,
                uri: p.uri,
                name: p.name || "–",
                owned: p.owner?.id === sp.userId || p.collaborative === true
            })))
            if (d?.next && list.length < 300) sp.loadPlaylists(d.next, list)
            else sp.playlists = list
        })
    }

    function toTrack(t) {
        if (!t || !t.uri || t.is_local) return null
        return {
            uri: t.uri,
            name: t.name ?? "",
            artist: (t.artists ?? (t.show ? [t.show] : [])).map(a => a.name).join(", "),
            album: t.album?.name ?? "",
            ms: t.duration_ms ?? 0
        }
    }

    // source: liked | recent | playlist:<id>
    function open(src) {
        source = src
        lastSource = src
        query = ""
        tracks = []
        nextUrl = ""
        contextUri = ""
        listState = "loading"
        const g = ++gen
        let url = ""
        if (src === "liked") {
            sourceName = "lieblingssongs"
            url = "/me/tracks?limit=50"
        } else if (src === "recent") {
            sourceName = "zuletzt gehört"
            url = "/me/player/recently-played?limit=50"
        } else {
            const id = src.slice(9)
            const p = playlists.find(x => x.id === id)
            sourceName = p?.name ?? "playlist"
            contextUri = "spotify:playlist:" + id
            url = "/playlists/" + id + "/items?limit=50&additional_types=track,episode"
        }
        fetchPage(url, g)
    }

    function fetchPage(url, g) {
        call("GET", url, null, (st, d) => {
            if (g !== sp.gen) return
            sp.loadingMore = false
            if (st === 429 && sp.tracks.length > 0) return
            if (st === 403 && sp.source.startsWith("playlist:")) { sp.listState = "locked"; return }
            if (st !== 200) { sp.listState = "error"; return }
            let items = (d?.items ?? []).map(it => sp.toTrack(it.item ?? it.track)).filter(t => t)
            if (sp.source === "recent") {            // „zuletzt gehört“ ohne Doppelte
                const seen = new Set(sp.tracks.map(t => t.uri))
                items = items.filter(t => !seen.has(t.uri) && seen.add(t.uri))
            }
            sp.tracks = sp.tracks.concat(items)
            sp.nextUrl = sp.source === "recent" ? "" : (d?.next ?? "")
            sp.listState = sp.tracks.length > 0 ? "ok" : "empty"
        })
    }

    function loadMore() {
        if (nextUrl === "" || loadingMore || listState !== "ok") return
        loadingMore = true
        fetchPage(nextUrl, gen)
    }

    // Suche (verzögert beim Tippen); leer → zurück zur letzten Liste
    function search(text) {
        query = text.trim()
        searchDelay.restart()
    }

    Timer {
        id: searchDelay
        interval: 350
        onTriggered: {
            if (sp.query === "") { if (sp.source === "search") sp.open(sp.lastSource); return }
            sp.source = "search"
            sp.sourceName = "suche: " + sp.query
            sp.contextUri = ""
            sp.nextUrl = ""
            sp.listState = "loading"
            const g = ++sp.gen
            sp.call("GET", "/search?type=track&limit=10&q=" + encodeURIComponent(sp.query), null, (st, d) => {
                if (g !== sp.gen) return
                if (st !== 200) { sp.listState = "error"; return }
                sp.tracks = (d?.tracks?.items ?? []).map(t => sp.toTrack(t)).filter(t => t)
                sp.listState = sp.tracks.length > 0 ? "ok" : "empty"
            })
        }
    }

    // ─────────────────────────── Abspielen ───────────────────────────

    // Lied aus der Liste: Playlist → im Playlist-Kontext, sonst die Liste ab diesem Lied
    function playAt(index) {
        const t = tracks[index]
        if (!t) return
        if (contextUri !== "") return play({ context_uri: contextUri, offset: { uri: t.uri } })
        const from = Math.max(0, index - 50)
        play({ uris: tracks.slice(from, from + 150).map(x => x.uri), offset: { position: index - from } })
    }

    function playContext() {
        if (contextUri !== "") play({ context_uri: contextUri })
    }

    function play(body, deviceId) {
        const q = deviceId ? "?device_id=" + deviceId : ""
        call("PUT", "/me/player/play" + q, body, (st, d) => {
            if (st === 404 && !deviceId) return sp.wakeDevice(id => sp.play(body, id))
            sp.handle(st, d)
        })
    }

    // kein aktives Gerät → erstes verfügbares nehmen (z. B. offener Web-Player)
    function wakeDevice(then) {
        call("GET", "/me/player/devices", null, (st, d) => {
            const ds = d?.devices ?? []
            const dev = ds.find(x => x.is_active) ?? ds.find(x => !x.is_restricted)
            if (!dev) {
                sp.noDevice = true
                sp.say("kein spotify offen – erst öffnen")
                return
            }
            sp.noDevice = false
            then(dev.id)
        })
    }

    function handle(st, d) {
        if (st >= 200 && st < 300) {
            noDevice = false
            refreshSoon()
        } else if (st === 403) {
            say(d?.error?.reason === "PREMIUM_REQUIRED" ? "dafür braucht spotify premium" : "spotify: nicht erlaubt")
        } else if (st === 404) {
            noDevice = true
            say("kein spotify offen – erst öffnen")
        } else if (st !== 429) {
            say("spotify: fehler " + st)
        }
    }

    // Steuerung über die Web API (wenn kein MPRIS-Player da ist, z. B. Wiedergabe auf dem Handy)
    function command(what) {
        if (what === "next") call("POST", "/me/player/next", null, handle)
        else if (what === "previous") call("POST", "/me/player/previous", null, handle)
        else if (what === "pause") call("PUT", "/me/player/pause", null, handle)
        else if (what === "play") call("PUT", "/me/player/play", null, handle)
    }

    function seek(sec) {
        call("PUT", "/me/player/seek?position_ms=" + Math.round(sec * 1000), null, handle)
    }

    function toggleShuffle() {
        call("PUT", "/me/player/shuffle?state=" + !shuffle, null, handle)
    }

    function cycleRepeat() {
        const next = repeat === "off" ? "context" : repeat === "context" ? "track" : "off"
        call("PUT", "/me/player/repeat?state=" + next, null, handle)
    }

    // Lautstärke: beim Ziehen nur merken, nach kurzer Pause senden
    property int wantedVolume: -1
    function setVolume(pct) {
        wantedVolume = Math.round(Math.max(0, Math.min(100, pct)))
        volumeDelay.restart()
    }

    Timer {
        id: volumeDelay
        interval: 180
        onTriggered: sp.call("PUT", "/me/player/volume?volume_percent=" + sp.wantedVolume, null, (st, d) => {
            sp.handle(st, d)
            sp.wantedVolume = -1
        })
    }

    // ─────────────────────────── ♥ ───────────────────────────

    function checkLiked() {
        liked = false
        const uri = currentUri
        if (uri === "" || !ready) return
        call("GET", "/me/library/contains?uris=" + encodeURIComponent(uri), null, (st, d) => {
            if (st === 200 && uri === sp.currentUri) sp.liked = Array.isArray(d) && d[0] === true
        })
    }

    function toggleLike() {
        const uri = currentUri
        if (uri === "") return
        const want = !liked
        call(want ? "PUT" : "DELETE", "/me/library?uris=" + encodeURIComponent(uri), null, (st, d) => {
            if (st >= 200 && st < 300) {
                if (uri === sp.currentUri) sp.liked = want
                sp.say(want ? "♥ zu lieblingssongs hinzugefügt" : "aus lieblingssongs entfernt")
            } else {
                sp.handle(st, d)
            }
        })
    }

    // ─────────────────────────── Status ───────────────────────────

    function refresh() {
        call("GET", "/me/player?additional_types=track,episode", null, (st, d) => {
            if (st === 200) {
                sp.playback = d
                sp.fetchedAt = Date.now()
                sp.clock = sp.fetchedAt
            } else if (st === 204) {
                sp.playback = null
            }
        })
    }

    function refreshSoon() { soon.restart() }

    Timer {
        id: soon
        interval: 600
        onTriggered: sp.refresh()
    }

    // alle 4 s nachfragen, solange das Panel offen ist
    Timer {
        interval: 4000
        repeat: true
        running: sp.active && sp.ready
        onTriggered: sp.refresh()
    }

    // Uhr für die Position (nur bei Wiedergabe auf einem anderen Gerät gebraucht)
    Timer {
        interval: 500
        repeat: true
        running: sp.active && sp.isPlaying
        onTriggered: sp.clock = Date.now()
    }

    // Titelwechsel im Player → Status gleich nachladen
    readonly property string mediaTitle: Media.title
    onMediaTitleChanged: if (active && ready) refreshSoon()
}
