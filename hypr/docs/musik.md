# Musik & Songtexte

> Teil der 8155-Doku. Kern (Regeln, Tastenkürzel, Dateistruktur): `~/.config/hypr/AGENTS.md`.
Fenster/Ebenen und `Ui.qml`-Zustand: `docs/quickshell.md`.

- `Media.qml` wählt den spielenden MPRIS-Player (sonst den ersten) und stößt die Position alle 120 ms an.
- **Musik-Panel** (`MusicPanel.qml` = Inhalt, `MusicWindow.qml` = Fenster), oben links 800×470, Glas mit nur 36 % Tönung + Blur:
  - Kopf: „playlists / <auswahl>“, Suchfeld (Spotify-Suche, max. 10 Treffer), ✕
  - links: lieblingssongs, zuletzt gehört, alle Playlists (󰲸 eigene, 󰐑 gefolgte); Mitte: Lieder (Klick = abspielen,
    laufendes Lied amber hinterlegt, beim Runterscrollen lädt die nächste Seite); rechts: Cover, Titel, Interpret, Album,
    „♡ speichern / ♥ gespeichert“, Lyrics-Status („♪ suche lyrics …“ / „♪ lade audio …“ / „♪ ki hört zu …“ /
    „♪ lyrics“ bzw. „♪ lyrics · ki“; Spalte nur 206 px breit → Texte kurz halten), ggf. Knopf „spotify öffnen“
  - Fuß: Fortschritt als feine Linie (Klick spult), Status, ⏮ ⏯ ⏭, Zeit, Titel · Interpret (oder kurz eine Meldung),
    Zufall, Wiederholen (aus → Playlist → Lied), Lautstärke des Spotify-Geräts, Gerätename, Player-Zähler (Klick wechselt)
  - **Sichtbarkeit** (`Ui.qml`, alles **pro Bildschirm**): `musicAuto` wird `true`, sobald Musik läuft (`Media.playing`), und erst
    90 s nach dem Pausieren wieder `false` → Bottom-Fenster auf dem Desktop **jedes Bildschirms ohne Fenster** (`screenEmpty`:
    sichtbarer Workspace hat keine Fenster; Fenster mit `Ui.skipWindow` wie das Clawd-Pet zählen nicht). Geht ein Fenster auf,
    blendet das Panel dort aus, wird der Bildschirm wieder leer, kommt es zurück (Songtext rutscht jeweils mit).
    `musicOpen` + `musicScreen` (Super+M → Bildschirm unter der Maus; Klick auf den Titel → Bildschirm dieser Leiste;
    IPC `music open` → Bildschirm mit Fokus) → Top-Fenster nur dort; Esc / Klick aufs Wallpaper / nochmal Super+M dort →
    zurück auf den Desktop. ✕ (`closeMusic()`) → `musicDismissed` (auf allen Bildschirmen), bleibt zu, bis die Musik nach > 5 s
    Pause wieder startet. **Zwei Fenster pro Bildschirm**, weil Quickshell `WlrLayershell.layer` nach dem Erzeugen nicht mehr
    ändert. Inhalt (`MusicPanel`) per `Loader` nur geladen, solange das Fenster sichtbar ist (+ 320 ms fürs Ausblenden) –
    mehrere Panels gleichzeitig zeigen dasselbe (Daten in `Spotify.qml`, Suchtext über `Spotify.query` abgeglichen);
    Scroll-Position der Liederliste geht beim Ausblenden verloren.
  - Steuerung: Play/Pause/vor/zurück/Spulen über **MPRIS** (sofort, geht auch für YouTube & Co.); läuft lokal kein Player,
    aber Spotify auf einem anderen Gerät (Handy …), über die Web API. Cover: von Spotify (640 px), wenn MPRIS-Titel = Spotify-Titel.
- **`Spotify.qml`** (Web API, nur aktiv solange das Panel sichtbar ist): Token holt es über `scripts/spotify-auth.py token`
  (Process), Anfragen per `XMLHttpRequest`; `GET /me/player` alle 4 s; 401 → Token **erzwungen** erneuern (`spotify-auth.py token --refresh` – Spotify verwirft
  Tokens manchmal vor Ablauf, ohne `--refresh` käme dasselbe tote Token zurück; lehnt Spotify auch das frische ab →
  „neu anmelden“), 429 → Pause laut `Retry-After`;
  kein Gerät aktiv → erstes aus `/me/player/devices` per `?device_id=`; keins da → Knopf „spotify öffnen“ (Web-Player in Brave).
  Abspielen: Playlist → `context_uri` + `offset.uri`; Lieblingssongs/zuletzt/Suche → Liste als `uris` (max. 150) + `offset.position`.
  **Spotify-Regeln seit Feb. 2026 (Development Mode):** braucht Premium beim App-Besitzer; Suche `limit` ≤ 10;
  `GET /playlists/{id}/items` (nicht mehr `/tracks`, Lied steht unter `item`) nur für **eigene/gemeinsame** Playlists –
  bei fremden 403 → Panel bietet „playlist abspielen“ (ganzer Kontext); ♥ über `PUT/DELETE /me/library?uris=…` und
  `GET /me/library/contains` (die alten `/me/tracks`-Schreib-Endpunkte gibt es nicht mehr).
- **Spotify einrichten** (einmalig): auf https://developer.spotify.com/dashboard eine App anlegen, Redirect-URI genau
  `http://127.0.0.1:8898/callback`, API „Web API“; dann `~/.config/hypr/scripts/spotify-auth.py login <client-id>` →
  Browser öffnet sich, zustimmen. Tokens in `~/.local/state/8155/spotify.json` (600).
  Im Formular ist „Web API“ ausgegraut, bis die Redirect-URI eingetragen ist; die rote Warnung „not secure“ bei
  `http://127.0.0.1:…` ist harmlos (Loopback ist laut Spotify erlaubt, `localhost` nicht). **Eingerichtet am 2026-10-06**
  (App im Spotify-Dashboard, heisst dort noch „golden hour“ – umbenennen nur dort möglich; Konto des Benutzers; Brave meldet sich als Gerät „Web Player (Chrome)“). Abgelaufen → Panel zeigt
  „neu anmelden“ (startet `login` mit der gespeicherten Client-ID). Scopes stehen in `spotify-auth.py` (`SCOPES`) –
  neue Scopes brauchen ein neues `login`.
- **Songtexte kommen nicht von Spotify** (die Spotify-Lyrics gibt es über keine offizielle API), sondern von
  `hypr/scripts/lyrics.py` (nur Python-Standardbibliothek). `LyricsService.qml` startet pro neuem Lied einen eigenen
  Prozess `lyrics.py find <artist> <titel> <album> <sekunden>` und liest dessen JSON-Zeilen (`SplitParser`):
  `{"stage": "suche"|"audio"|"ki"}` = Zwischenstand (→ `LyricsService.stage`, im Panel angezeigt), zuletzt
  `{"source": "lrclib"|"netease"|"ki"|"", "lrc": "…"}` (→ `LyricsService.source`, bei Fehlern zusätzlich `"error"`,
  steht im `qs log`). Wechselt das Lied, läuft der Prozess weiter und landet im Cache. Im Speicher von Quickshell
  werden nur Treffer gemerkt; „nichts gefunden“ merkt sich das Skript.
  **Reihenfolge der Quellen:**
  1. Cache `~/.cache/8155/lyrics/<sha1>.json` (Schlüssel = bereinigter Interpret + Titel). Treffer für immer;
     „nichts“ ohne KI 1 Tag (oder bis ein Key da ist), „nichts“ nach KI-Versuch 30 Tage. Netzfehler werden nie gespeichert.
     Pro Lied eine `.lock`-Datei (`flock`), damit dasselbe Lied nicht doppelt gesucht/bezahlt wird.
  2. **lrclib.net** – erst `api/get` exakt, dann `api/search` (Titel ähnlich, Länge < 8 s daneben). Bei Überlastung
     (503 kam am 2026-10-06 vor) bis zu 2 Wiederholungen. `instrumental` → keine KI. Nur unsynchronisierter Text da →
     dient der KI als Hinweis (`prompt`).
  3. **NetEase** (`music.163.com/api/cloudsearch/pc` + `api/song/lyric`) – Länge ±3 s, Titel + Interpret müssen passen;
     chinesische Mitwirkenden-Zeilen am Anfang (作词/作曲 …) werden entfernt. Die alte Such-URL `api/search/pc`
     verlangt inzwischen ein Konto (Fehler -462).
  4. **KI** (nur mit OpenAI-Key + yt-dlp): passendes YouTube-Video suchen (`yt-dlp ytsearch8:`, Titel-Wörter müssen
     vorkommen, Länge ±3 s, „… - Topic“-Kanäle bevorzugt) → Audio laden (m4a, > 24 MB oder anderes Format → ffmpeg mp3) →
     OpenAI **`whisper-1`** (`verbose_json`, Wort- + Segment-Zeitstempel; die neueren `gpt-*-transcribe` können keine
     Zeitstempel) → Zeilen: kurze Segmente ganz, lange an Wortpausen geteilt (≈ 35 Zeichen), Halluzinationen/Stille
     gefiltert (auch Füllzeilen wie „Music“), Pausen > 3,5 s als leere LRC-Zeile. Weniger als 5 verschiedene Zeilen =
     nichts erkannt. Hinweistext (`prompt`) ist nur der unsynchronisierte lrclib-Text (falls da) – **nie** „Interpret – Titel“:
     Whisper hat den nur wiederholt bzw. das Lied deshalb für russisch gehalten („Игорь Слуцкий – Небеса“). Kommt mit
     Hinweis nichts heraus, einmal ohne. Erkannte Sprache steht im Cache (`language`). Vor dem Laden und vor dem Hochladen prüft `playerctl -a metadata`,
     ob das Lied noch läuft – sonst Abbruch ohne Kosten. Ab dem Hochladen wird SIGTERM ignoriert. Kosten: ca. 0.006 $
     pro Minute, einmal pro Lied (`lyrics.py info` schätzt die bisherige Summe). Dauer beim ersten Abspielen ≈ 20–40 s.
  - Musixmatch (Quelle der Spotify-Lyrics) liefert ohne echtes Konto nur Fake-Texte (Token aus Nullen, „Drake – NOKIA“
    mit Kauderwelsch) – darum nicht eingebaut. Bei albanischen Liedern haben lrclib/NetEase meist nichts → dort hilft nur die KI.
  - **Befehle:** `lyrics.py key` (Key verdeckt eingeben, muss mit `sk-` beginnen, wird bei OpenAI geprüft, `key --remove` löscht ihn),
    `lyrics.py forget "<Interpret>" "<Titel>"` (falschen Text verwerfen → beim nächsten Abspielen neu),
    `lyrics.py info` (Key/yt-dlp vorhanden?, Anzahl Texte je Quelle, KI-Kosten). Key alternativ per `OPENAI_API_KEY`.
  - **Lied dauerhaft ohne Songtext** (z. B. Whisper hält ein albanisches Lied für russisch/hebräisch → Kauderwelsch): die Cache-JSON
    des Lieds (`~/.cache/8155/lyrics/<sha1>.json`) auf `"lrc": ""`, `"ai_tried": true` und `"time"` weit in die Zukunft setzen –
    sonst sucht die KI nach 30 Tagen neu. Danach Quickshell neu laden (Speicher-Cache), z. B. `touch LyricsService.qml`.
    Stand 2026-10-13 so gesetzt für „Irini Qirjako – Cu mbush mali plot me rrush“.
  - Bereinigung (im Skript): YouTube-Titel „Interpret - Titel“ zerlegen, „(Official Video)“ usw. weg; für Suchen
    zusätzlich „- Remastered 2011“, „(feat. …)“ weg.
- `Lyrics.qml`: Stil wie die Instagram-Songtexte, oben links (Rand links 48, oben 92 px, 520 px breit):
  vorherige Zeile grau, aktuelle Zeile weiß und fett, nächste Zeile grau – alle `SF Pro Display` Bold 36 px,
  mittig gesetzt, lange Zeilen brechen um. Alle Zeilen stehen in einer `Column`, die bei jeder neuen Zeile weich
  nach oben rutscht (oben steht immer die vorherige Zeile, fehlt sie: die aktuelle). Leere LRC-Zeilen (Pausen)
  haben Höhe 0; während einer Pause blendet der Text aus. Liegt auf **diesem** Bildschirm ein Musik-Panel (`Ui.musicOn(screen)`),
  rutscht der Text 476 px nach unten unter das Panel (Fenster dafür 940 px hoch).
- **`LyricsScreen.qml` – Songtext-Bildschirm** (Super+Shift+M, Vorbild Apple Music): Overlay-Fenster über einen ganzen Bildschirm
  (der unter der Maus; Zustand `Ui.lyricsScreen` = Bildschirmname, `Ui.toggleLyricsScreen()`; nochmal drücken → zu, anderer
  Bildschirm → wechselt dorthin; Esc schließt nach Klick hinein, Tastatur `OnDemand`). Links Cover (640 px von Spotify, wenn `Spotify.item` = MPRIS-Titel – Brave liefert per MPRIS nur 150 px; sonst `Media.artUrl`; `Spotify.qml` ist dafür auch bei offenem Songtext-Bildschirm aktiv), Titel, Interpret, Fortschritt + Zeiten; rechts der
  Songtext linksbündig, `SF Pro Display` Bold (5 % der Bildschirmhöhe), aktuelle Zeile bei 36 % der Höhe, voll deckend mit
  Leuchten in `Theme.accentSoft`, nächste Zeilen 42 % → blasser, vorherige 15 % → weg. Ohne Text: „suche songtext …“ usw.
  **Hintergrund** (passt sich dem Wallpaper an), drei Varianten, Wahl in `Ui.lyricsScreenStyle` (Vorgabe `seide`), umschalten mit
  `qs ipc call lyrics style seide|fluss|flecken` (nicht gespeichert – dauerhaft: Vorgabe in `Ui.qml` ändern):
  - **seide** (Standard, nach einem Beispielvideo des Benutzers): Shader `shaders/seide.frag(.qsb)` – glänzende 3D-Seide. Höhe =
    5× verzerrte Sinuswellen, Normale aus der Steigung, Licht von oben links + Glanzpunkt; Helligkeit → Verlauf fast schwarz →
    `accentDeep` → `accent` → `accentSoft` → fast weiß, Sättigung ×1.5, alles ×0.82 und Glanz gedämpft (sonst verschluckt Weiß den
    Songtext). In ½ Größe gerechnet, Runde 60 s. Ausprobiert wurde das Aussehen vorab mit einem numpy-Nachbau auf der CPU.
  - **fluss**: Shader `shaders/fluss.frag(.qsb)` – Domain Warping (Rauschen verzerrt Rauschen), Farben
    fließen wie Flüssigkeit: dunkles `accentDeep` → `accentDeep` → `accent` → `accentSoft`, dazu 20 % Wallpaper (nur 48 px breit
    geladen → nur Farbflächen), mitverzerrt; Sättigung ×1.6 im Shader. Gerechnet in ¼ Größe (`layer.textureSize`), hochskaliert.
    Runde 36 s (`phase` 0…2π, nur ganzzahlige Vielfache → nahtlos). **Nach Änderung am Shader: qsb + Quickshell neu starten**
    – das automatische Neuladen nimmt die alte `.qsb` aus dem Zwischenspeicher.
  - **flecken** (erste Version): `Ui.wallpaper` + 5 Kreise in `accent`/`accentDeep`/`accentSoft`, auf 1/10 der Größe gemalt, mit
    `MultiEffect` verwischt (+ Sättigung 0.6, Kontrast 0.15) und 10× hochskaliert; Bild dreht sich in 20 s einmal, Kreise wandern
    auf Sinusbahnen (±32 %, Runde 40 s) und pulsieren ±30 %.
  Über beiden `Theme.ink` 22 % für Kontrast. Animation läuft nur, solange sichtbar.

## yt-dlp 2026.08.19

Holt für die KI-Songtexte das Audio von YouTube (`lyrics.py`). Offizielles Release-Zipapp (braucht nur python3) in `~/.local/opt/yt-dlp/yt-dlp` (Prüfsumme gegen `SHA2-256SUMS` geprüft), Symlink `~/.local/bin/yt-dlp`. YouTube braucht eine JS-Laufzeit → `lyrics.py` ruft es mit `--js-runtimes node` auf (Node 22 aus Fedora). **Update:** `yt-dlp -U` (wenn YouTube-Suche/Download plötzlich scheitert, zuerst das). ffmpeg ist installiert.
