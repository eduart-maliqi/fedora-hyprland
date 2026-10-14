-- ╭────────────────────────────────────────────────────────────╮
-- │  ★ 8155  ·  Hyprland 0.56 (Lua-Config)              │
-- │  Shell (Leiste, Uhr, Lyrics, Wallpaper): ~/.config/quickshell│
-- │  Wiki: https://wiki.hypr.land/Configuring/Start/           │
-- ╰────────────────────────────────────────────────────────────╯

------------------
---- PALETTE -----
------------------

-- Farbthemen wie in Quickshell (Theme.qml: golden, mond, glut, kohle, purpur, silber). Welches gilt, zeigt der Symlink themen/aktiv; umgeschaltet wird mit
-- scripts/thema.sh <name> (beim Wallpaper-Wechsel automatisch) → golden.apply_theme weiter unten.
local palettes = {
    golden = { accent = "e3a142", accent_soft = "f2c57c", ink = "12181e" },
    mond   = { accent = "8cc0e4", accent_soft = "cfe3f1", ink = "0b1219" },
    glut   = { accent = "ef5a50", accent_soft = "fdb59a", ink = "0d0b10" },
    kohle  = { accent = "e8a21c", accent_soft = "f5c867", ink = "121212" },
    purpur = { accent = "f2508a", accent_soft = "f3b0d6", ink = "12071a" },
    silber = { accent = "cfd6df", accent_soft = "eef1f5", ink = "0c0d0f" },
}

------------------
---- MONITORE ----
------------------

-- Anordnung, Auflösung und Skalierung stehen in monitors.lua – die schreibt die App „Bildschirme“
-- (nwg-displays) beim Übernehmen neu. Dock-Monitore dort per desc:, weil DVI-I-1/-2 tauschen können.
-- package.loaded leeren, damit die Datei bei jedem Neuladen wirklich neu gelesen wird;
-- pcall, damit ein Fehler darin nicht den Rest dieser Konfiguration (Tastenkürzel …) abbricht.
package.loaded["monitors"] = nil
local monitors_ok, monitors_err = pcall(require, "monitors")
if not monitors_ok then
    hl.notification.create({ text = "monitors.lua: " .. tostring(monitors_err), timeout = 15000 })
end

-- Alles andere (unbekannte Monitore): automatisch
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- PROGRAMME ------
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"
local browser     = "brave-browser"
local menu        = "rofi -show drun"
local scripts     = "~/.config/hypr/scripts"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- GDM meldet automatisch an → das Passwort verlangt erst dieser Sperrbildschirm.
    -- Als Erstes, damit der Desktop nach dem Booten nie offen zu sehen ist.
    hl.exec_cmd("hyprlock")
    -- Umgebung für Programme, die über D-Bus/systemd starten (z. B. Nautilus → „Öffnen mit …“).
    -- Ohne ELECTRON_OZONE_PLATFORM_HINT/XDG_SESSION_TYPE hängen Electron-Apps (VS Code) von dort ohne Fenster.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE ELECTRON_OZONE_PLATFORM_HINT QT_QPA_PLATFORM")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("qs")          -- Quickshell: Wallpaper, Leiste, Uhr-Widget, Lyrics, Musik-Karte
    hl.exec_cmd("hypridle")
    hl.exec_cmd("mako")
    hl.exec_cmd("blueman-applet")  -- Bluetooth-Kopplungsdienst (Agent); unter GNOME macht das GNOME selbst
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(scripts .. "/explorer-modus.py")  -- Nautilus: Windows-/Linux-Lesezeichen je nach aktivem Tab
    -- HyprWindowShade (Shader pro Fenster): lädt nur, wenn für genau dieses Hyprland gebaut – sonst Hinweis statt Absturz
    hl.exec_cmd(scripts .. "/windowshade.sh load")
end)

-------------------------------
---- UMGEBUNGSVARIABLEN -------
-------------------------------

hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-----------------------
---- LOOK & FEEL ------
-----------------------

hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = { top = 6, right = 22, bottom = 22, left = 22 },

        border_size = 1,

        col = {
            -- active_border (dünner Rand in der Akzentfarbe, der nach unten ausblendet): golden.apply_theme
            inactive_border = "rgba(ffffff14)",
        },

        resize_on_border = true,
        extend_border_grab_area = 25,   -- Greifbereich außerhalb des Rands zum Größe-Ändern (Standard 15 px)
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2.4,

        active_opacity   = 1.0,
        inactive_opacity = 0.94,

        shadow = {
            enabled      = true,
            range        = 28,
            render_power = 3,
            offset       = { 0, 6 },
            color          = "rgba(0a0e1266)",
            color_inactive = "rgba(0a0e1233)",
        },

        -- ganz dezentes Glühen in der Akzentfarbe um das aktive Fenster (color: golden.apply_theme)
        glow = {
            enabled        = true,
            range          = 14,
            render_power   = 3,
            color_inactive = "rgba(00000000)",
        },

        blur = {
            enabled           = true,
            size              = 9,
            passes            = 3,
            noise             = 0.018,
            contrast          = 0.95,
            brightness        = 0.82,
            vibrancy          = 0.22,
            vibrancy_darkness = 0.4,
            popups            = true,
            special           = true,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Kurven: weich, „warm“ – nichts springt
hl.curve("glide",        { type = "bezier", points = { {0.22, 1},    {0.36, 1} } })
hl.curve("softInOut",    { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("drift",        { type = "spring", mass = 1, stiffness = 180, dampening = 22 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "glide" })
hl.animation({ leaf = "windows",       enabled = true, speed = 5,   spring = "drift" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.5, spring = "drift",  style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.6, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 2.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.6, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "glide" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.8, bezier = "glide" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "glide",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "softInOut", style = "slidefade 12%" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,   bezier = "glide" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        font_family             = "JetBrainsMono Nerd Font",
        focus_on_activate       = true,
        enable_swallow          = true,
        swallow_regex           = "^(kitty)$",
    },
    cursor = {
        sync_gsettings_theme = true,
        inactive_timeout     = 6,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "ch",          -- Schweizerdeutsch, wie unter GNOME
        kb_variant = "",
        kb_options = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            scroll_factor        = 0.6,
        },
    },
})

-- nur die Mäuse langsamer (Touchpad bleibt beim Standard aus input.sensitivity)
hl.device({
    name        = "logitech-usb-laser-mouse",
    sensitivity = -0.3,
})

-- Logitech MX Vertical (Arbeit, am Dock)
hl.device({
    name        = "logitech-mx-vertical-advanced-ergonomic-mouse",
    sensitivity = -0.55,
})

-- 3 Finger wischen → Workspace wechseln
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

----------------------
---- TASTENKÜRZEL ----
----------------------

local mod = "SUPER"

-- Phantom (SUPER+P, Plugin Phantomat – Abschnitt „Phantom“ weiter unten): auf der unendlichen Fläche würden
-- Tiling- und Workspace-Tasten alles durcheinanderbringen (Workspace wechseln = Bildschirm plötzlich leer).
-- phantom_or(aktion, normal): Fläche offen → Phantom-Aktion ("noop" = nichts tun), sonst das normale Kürzel.
-- _dispatch läuft immer sofort (die öffentlichen Funktionen nur innerhalb eines Tastenkürzels) – so geht es
-- auch über `hyprctl eval`.
local function phantom_dispatch(name, arg)
    return pcall(function() return hl.plugin.spatialoverview._dispatch(name, arg) end)
end
local function phantom_open()
    return (phantom_dispatch("canvas", "noop"))   -- klappt nur, solange eine Fläche offen ist
end
local function phantom_or(action, normal)
    return function()
        if phantom_open() then
            if action ~= "noop" then phantom_dispatch("canvas", action) end
        else
            hl.dispatch(normal)
        end
    end
end

-- Apps
hl.bind(mod .. " + Return",      hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + Space",       hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + D",           hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + E",           hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + B",           hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + V",   hl.dsp.exec_cmd(scripts .. "/clipboard.sh"))
hl.bind(mod .. " + Escape",      hl.dsp.exec_cmd(scripts .. "/powermenu.sh"))
hl.bind(mod .. " + L",           hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + N",           hl.dsp.exec_cmd("makoctl dismiss --all"))
hl.bind(mod .. " + SHIFT + D",   hl.dsp.exec_cmd(scripts .. "/noa-start.sh"))   -- NOA-Entwicklungsumgebung hochfahren
hl.bind(mod .. " + SHIFT + A",   hl.dsp.exec_cmd(scripts .. "/iphone.sh toggle"))   -- iPhone-Spiegelung (UxPlay) an/aus
hl.bind(mod .. " + ALT + A",     hl.dsp.exec_cmd(scripts .. "/iphone.sh steuern"))  -- iPhone per Bluetooth mit Maus/Tastatur steuern

-- 8155 Shell (Quickshell IPC)
hl.bind(mod .. " + W",           hl.dsp.global("quickshell:galleryToggle"))   -- Wallpaper-Galerie (WallpaperGallery.qml)
hl.bind(mod .. " + SHIFT + W",   hl.dsp.exec_cmd("qs ipc call wallpaper animate"))   -- lebendiges Wallpaper an/aus
-- Super+M: Musik-Panel auf dem Bildschirm unter der Maus (nicht dem mit dem Tastatur-Fokus)
hl.bind(mod .. " + M", function()
    local m = hl.get_monitor_at_cursor() or hl.get_active_monitor()
    hl.exec_cmd("qs ipc call music toggleOn '" .. (m and m.name or "") .. "'")
end)
hl.bind(mod .. " + SHIFT + L",   hl.dsp.exec_cmd("qs ipc call lyrics toggle"))
hl.bind(mod .. " + SHIFT + C",   hl.dsp.exec_cmd("qs ipc call clock toggle"))
-- Super+I: Übersicht aller Tastenkürzel oben rechts (Anzeige: ~/.config/quickshell/KeysHelp.qml –
-- die Liste dort ist von Hand gepflegt, neue Kürzel also auch dort eintragen)
hl.bind(mod .. " + I",           hl.dsp.global("quickshell:keysToggle"))

-- Screenshots (landen in ~/bildschirmfotos + Zwischenablage)
hl.bind("Print",                 hl.dsp.exec_cmd("hyprshot -m region -o ~/bildschirmfotos"))
hl.bind("SHIFT + Print",         hl.dsp.exec_cmd("hyprshot -m output -o ~/bildschirmfotos"))hl.bind(mod .. " + SHIFT + S",   hl.dsp.exec_cmd("hyprshot -m region -o ~/bildschirmfotos"))

-- Fenster
hl.bind(mod .. " + Q",           hl.dsp.window.close())
-- Super+F: Fenster füllt den Bildschirm, dem Programm wird aber „kein Vollbild“ gemeldet (client = 0)
-- → Browser behalten Tabs + Adressleiste. Echtes Vollbild der App: F11 bzw. Video-Vollbild.
hl.bind(mod .. " + F",           hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
hl.bind(mod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ mode = "maximized" }))
-- Schweben/Pseudo/Teilung sind Tiling – auf der Phantom-Fläche schwebt ohnehin alles → dort nichts tun
hl.bind(mod .. " + V",           phantom_or("noop", hl.dsp.window.float({ action = "toggle" })))
hl.bind(mod .. " + C",           hl.dsp.window.center())
hl.bind(mod .. " + SHIFT + P",   phantom_or("noop", hl.dsp.window.pseudo()))   -- war SUPER+P (jetzt Phantom)
hl.bind(mod .. " + J",           phantom_or("noop", hl.dsp.layout("togglesplit")))
-- mit Strg abgesichert: liegt sonst direkt neben Super+M (Musik), ein Vertipper würde die Sitzung beenden
hl.bind(mod .. " + CTRL + SHIFT + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Fokus / Verschieben mit Pfeiltasten
-- (auf der Phantom-Fläche: nächstes Fenster in der Richtung, Kamera fährt mit / Fenster einen Rasterschritt schieben)
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, function()
        if phantom_open() then phantom_dispatch("navigate", dir) else hl.dispatch(hl.dsp.focus({ direction = dir })) end
    end)
    hl.bind(mod .. " + SHIFT + " .. dir,     phantom_or("nudge " .. dir, hl.dsp.window.move({ direction = dir })))
    hl.bind(mod .. " + CTRL + " .. dir,      hl.dsp.window.resize({
        x = (dir == "left" and -40) or (dir == "right" and 40) or 0,
        y = (dir == "up" and -40) or (dir == "down" and 40) or 0,
        relative = true,
    }), { repeating = true })
end

-- Workspaces 1–10 (die Sterne in der Leiste) – auf der Phantom-Fläche gibt es keine Workspaces → nichts tun
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         phantom_or("noop", hl.dsp.focus({ workspace = i })))
    hl.bind(mod .. " + SHIFT + " .. key, phantom_or("noop", hl.dsp.window.move({ workspace = i })))
end

-- Super+Tab: Aufgabenansicht wie unter Windows (Anzeige: ~/.config/quickshell/TaskView.qml)
hl.bind(mod .. " + Tab",           hl.dsp.global("quickshell:taskviewToggle"))
hl.bind(mod .. " + SHIFT + Tab",   phantom_or("noop", hl.dsp.focus({ workspace = "e-1" })))
hl.bind(mod .. " + mouse_down",    phantom_or("noop", hl.dsp.focus({ workspace = "e+1" })))
hl.bind(mod .. " + mouse_up",      phantom_or("noop", hl.dsp.focus({ workspace = "e-1" })))

golden = {}

-- Farbthema (siehe palettes oben): Fensterrand, Glühen und Hintergrund. scripts/thema.sh ruft das per hyprctl eval auf;
-- beim Start / Neuladen gilt das Thema, auf das themen/aktiv zeigt.
function golden.apply_theme(name)
    local c = palettes[name] or palettes.golden
    hl.config({
        general    = { col = { active_border = { colors = { "rgba(" .. c.accent_soft .. "cc)", "rgba(" .. c.accent .. "33)" }, angle = 90 } } },
        decoration = { glow = { color = "rgba(" .. c.accent .. "1c)" } },
        misc       = { background_color = "rgb(" .. c.ink .. ")" },
    })
end

do
    local p = io.popen("readlink '" .. os.getenv("HOME") .. "/.config/hypr/themen/aktiv' 2>/dev/null")
    local name = p and p:read("l") or ""
    if p then p:close() end
    golden.apply_theme(name:match("([^/]+)/?$") or "golden")
end

-- Versteckte Fenster („minimieren“)
--   Klick aufs Wallpaper     → aktives Fenster wird versteckt (Quickshell ruft golden.desktop_click())
--   SUPER+S                  → versteckte Fenster zeigen / ausgewähltes Fenster zurückholen
--   SUPER+ALT+S              → aktives Fenster per Taste verstecken
local HIDDEN = "minimized"

local function hidden_open()
    local m = hl.get_active_monitor()
    local sp = m and m.active_special_workspace
    return sp ~= nil and sp.name == "special:" .. HIDDEN
end

-- Special-Workspaces dimmen und verwischen den Rest – bei der Versteckt-Ansicht gewollt, beim Dropdown-Terminal nicht.
-- Gilt für alle Special-Workspaces gleichzeitig, deshalb wird nur umgeschaltet, solange das Dropdown offen ist.
local function special_look(plain)
    hl.config({ decoration = { dim_special = plain and 0 or 0.2, blur = { special = not plain } } })
end

function golden.desktop_click()
    if hidden_open() then
        -- Ansicht offen → Klick daneben schließt sie wieder
        hl.dispatch(hl.dsp.workspace.toggle_special(HIDDEN))
        return
    end
    local w = hl.get_active_window()
    local ws = hl.get_active_workspace()
    if w and ws and w.workspace and w.workspace.id == ws.id then
        hl.dispatch(hl.dsp.window.move({ workspace = "special:" .. HIDDEN, follow = false }))
    end
end

function golden.toggle_hidden()
    special_look(false)   -- ersetzt ein offenes Dropdown-Terminal
    local w = hl.get_active_window()
    if hidden_open() and w and w.workspace and w.workspace.special then
        -- ausgewähltes verstecktes Fenster zurück auf den aktuellen Workspace
        local ws = hl.get_active_workspace()
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = true }))
        if hidden_open() then hl.dispatch(hl.dsp.workspace.toggle_special(HIDDEN)) end
    else
        hl.dispatch(hl.dsp.workspace.toggle_special(HIDDEN))
    end
end

hl.bind(mod .. " + S",       golden.toggle_hidden)
hl.bind(mod .. " + H",       hl.dsp.window.move({ workspace = "special:" .. HIDDEN, follow = false }))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:" .. HIDDEN, follow = false }))

-- Dropdown-Terminal (SUPER+SHIFT+Return): kitty mit Klasse „dropterm“ liegt auf dem Special-Workspace „dropterm“
-- (Fensterregel unten) und wird nur ein-/ausgeblendet – Shell und Verlauf bleiben erhalten.
function golden.dropdown_terminal()
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "dropterm" then
            -- Hyprland gibt dem Fenster beim Einblenden nicht von selbst den Tastaturfokus
            local m = hl.get_active_monitor()
            local sp = m and m.active_special_workspace
            local shown = sp ~= nil and sp.name == "special:dropterm"
            special_look(not shown)
            hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
            if not shown then hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address })) end
            return
        end
    end
    special_look(true)
    hl.exec_cmd("kitty --class dropterm")
end

hl.bind(mod .. " + SHIFT + Return", golden.dropdown_terminal)

-- Versteckt-Ansicht schließen, sobald ein anderer Bildschirm den Fokus bekommt – sonst bleibt sie dort offen
-- und jedes neu versteckte Fenster erscheint auf jenem Bildschirm
-- (das Ereignis kommt, bevor der Fokus umgestellt ist → hidden_open()/toggle_special meinen noch den alten Bildschirm)
hl.on("monitor.focused", function()
    if hidden_open() then hl.dispatch(hl.dsp.workspace.toggle_special(HIDDEN)) end
end)

-- Fenstermodus (SUPER+O): „geordnet“ ↔ „frei“
--   geordnet → Tiling wie gewohnt, neue Fenster werden automatisch angeordnet
--   frei     → wie bei Windows: alle Fenster schweben; verschieben mit SUPER+linke Maus, Größe am Rand ziehen;
--              neue Fenster öffnen mittig (60 % × 70 %); Tastatur-Fokus erst per Klick (follow_mouse = 2)
-- Beim Umschalten bleibt jedes Fenster, wo es ist. Was der freie Modus schwebend gemacht hat, trägt den Tag
-- „freed“ – nur diese Fenster werden beim Zurückschalten wieder eingereiht (Bild-im-Bild, kleine Tools, Clawd
-- usw. bleiben schwebend). Der Modus steht in ~/.local/state/8155/fenstermodus.json (übersteht Neustarts);
-- Quickshell liest die Datei für das Symbol in der Leiste und den kurzen Hinweis (WindowMode.qml, ModeOsd.qml).
local MODE_DIR  = os.getenv("HOME") .. "/.local/state/8155"
local MODE_FILE = MODE_DIR .. "/fenstermodus.json"

local function read_free_mode()
    local f = io.open(MODE_FILE, "r")
    if not f then return false end
    local s = f:read("a")
    f:close()
    return s:find('"free"%s*:%s*true') ~= nil
end

local function write_free_mode(free)
    os.execute("mkdir -p '" .. MODE_DIR .. "'")
    local f = io.open(MODE_FILE, "w")
    if f then
        f:write('{"free": ' .. tostring(free) .. '}\n')
        f:close()
    end
end

-- betroffene Fenster: normale Workspaces + versteckte, kein Vollbild
local function mode_window(w)
    local ws = w.workspace
    return ws ~= nil and (not ws.special or ws.name == "special:" .. HIDDEN) and w.fullscreen == 0
end

local function xy(v) return v.x or v[1], v.y or v[2] end

local function set_free_mode(free)
    golden.free_mode = free
    hl.config({ input = { follow_mouse = free and 2 or 1 } })
    if free then
        -- erst alle Maße merken (sobald eines schwebt, rücken die anderen nach), dann an Ort und Stelle schweben lassen
        local todo = {}
        for _, w in ipairs(hl.get_windows()) do
            if mode_window(w) and not w.floating then
                local x, y = xy(w.at)
                local sw, sh = xy(w.size)
                todo[#todo + 1] = { sel = "address:" .. w.address, x = x, y = y, w = sw, h = sh }
            end
        end
        for _, t in ipairs(todo) do
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = t.sel }))
            hl.dispatch(hl.dsp.window.resize({ x = t.w, y = t.h, window = t.sel }))
            hl.dispatch(hl.dsp.window.move({ x = t.x, y = t.y, window = t.sel }))
            hl.dispatch(hl.dsp.window.tag({ tag = "+freed", window = t.sel }))
        end
    else
        for _, w in ipairs(hl.get_windows({ tag = "freed" })) do
            local sel = "address:" .. w.address
            hl.dispatch(hl.dsp.window.tag({ tag = "-freed", window = sel }))
            if w.floating then hl.dispatch(hl.dsp.window.float({ action = "disable", window = sel })) end
        end
    end
end

-- neue Fenster im freien Modus: schwebend, mittig, angenehm groß (Dialoge schweben ohnehin und bleiben unberührt)
hl.on("window.open", function(w)
    if not golden.free_mode or w.floating or not mode_window(w) then return end
    local sel = "address:" .. w.address
    local m = w.monitor or hl.get_active_monitor()
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel }))
    if m then
        hl.dispatch(hl.dsp.window.resize({ x = math.floor(m.width / m.scale * 0.6), y = math.floor(m.height / m.scale * 0.7), window = sel }))
    end
    hl.dispatch(hl.dsp.window.center({ window = sel }))
    hl.dispatch(hl.dsp.window.tag({ tag = "+freed", window = sel }))
end)

function golden.toggle_window_mode()
    set_free_mode(not golden.free_mode)
    write_free_mode(golden.free_mode)
end

-- auf der Phantom-Fläche nichts tun: dort schwebt alles, und „geordnet“ würde Fenster der Fläche einreihen
hl.bind(mod .. " + O", function()
    if not phantom_open() then golden.toggle_window_mode() end
end)

-- beim Start / Neuladen der Konfiguration: gespeicherten Modus übernehmen (Fenster schweben dann schon);
-- fehlt die Datei, anlegen – Quickshell kann nur eine vorhandene Datei beobachten
golden.free_mode = read_free_mode()
if golden.free_mode then hl.config({ input = { follow_mouse = 2 } }) end
do
    local f = io.open(MODE_FILE, "r")
    if f then f:close() else write_free_mode(false) end
end

-- Wackelfenster (SUPER+G an/aus): Fenster verformen sich beim Verschieben wie Wackelpudding und schwingen nach.
--   Eigenes Plugin ~/.config/hypr/plugins/wobbly (Quelltext main.cpp). Nach jedem Hyprland-Update neu bauen:
--   ~/.config/hypr/plugins/wobbly/build.sh – passt die .so nicht zur Version, lädt Hyprland sie nicht (Hinweis oben rechts).
--   Feinschliff: hl.config({ plugin = { wobbly = { stiffness = 180, damping = 7, strength = 1 } } })
--   Zustand in ~/.local/state/8155/wackelfenster.json (übersteht Neustarts); Quickshell zeigt beim
--   Umschalten einen kurzen Hinweis (ModeOsd.qml).
local WOBBLY_SO   = os.getenv("HOME") .. "/.config/hypr/plugins/wobbly/wobbly.so"
local WOBBLY_FILE = MODE_DIR .. "/wackelfenster.json"

local function read_wobbly()
    local f = io.open(WOBBLY_FILE, "r")
    if not f then return true end   -- Standard: an
    local s = f:read("a")
    f:close()
    return s:find('"enabled"%s*:%s*false') == nil
end

local function write_wobbly(on)
    os.execute("mkdir -p '" .. MODE_DIR .. "'")
    local f = io.open(WOBBLY_FILE, "w")
    if f then
        f:write('{"enabled": ' .. tostring(on) .. '}\n')
        f:close()
    end
end

local function wobbly_loaded()
    for _, p in ipairs(hl.get_loaded_plugins()) do
        if p.name == "wobbly" then return true end
    end
    return false
end

-- die Einstellung plugin:wobbly:enabled gibt es erst, wenn das Plugin geladen ist. Hyprland lädt Plugins nach dem
-- ersten Einlesen und liest die Konfiguration danach noch einmal – beim zweiten Mal greift das hier.
local function apply_wobbly()
    if wobbly_loaded() then
        hl.config({ plugin = { wobbly = { enabled = golden.wobbly } } })
    end
end

function golden.toggle_wobbly()
    if not wobbly_loaded() then
        hl.notification.create({ text = "Wackelfenster: Plugin nicht geladen – ~/.config/hypr/plugins/wobbly/build.sh ausführen", timeout = 8000 })
        return
    end
    golden.wobbly = not golden.wobbly
    apply_wobbly()
    write_wobbly(golden.wobbly)
end

do
    local f = io.open(WOBBLY_SO, "r")
    if f then
        f:close()
        hl.plugin.load(WOBBLY_SO)
    end
end

golden.wobbly = read_wobbly()
apply_wobbly()
do
    local f = io.open(WOBBLY_FILE, "r")
    if f then f:close() else write_wobbly(golden.wobbly) end
end

hl.bind(mod .. " + G", golden.toggle_wobbly)

-- Phantom (SUPER+P): unendliche Arbeitsfläche statt Workspaces – Plugin Phantomat (github.com/kaolti/phantomat).
--   SUPER+P        erster Druck: alle Fenster kommen auf eine gemeinsame Fläche und es wird rausgezoomt
--                  (tippen = Fenster suchen, Enter = hin, Esc = zurück); danach: rauszoomen ↔ zurück auf 100 %
--   SUPER+CTRL+P   Phantom ganz aus → Fenster zurück auf ihre Workspaces (gekachelt; die Reihenfolge kann sich ändern)
--   Auf der Fläche: Mittelklick ziehen = verschieben, Strg + Mausrad = zoomen, SUPER+Pfeile = Fenster in der Richtung.
--   Einstellungen: ~/.config/hypr/phantomat.lua · Bauen nach jedem Hyprland-Update: scripts/phantomat.sh build
--   Ein- und Ausschalten läuft über scripts/phantomat.sh an|aus: HyprWindowShade (Fenster-Shader) hängt an derselben
--   Zeichenfunktion wie Phantomat und wird solange entladen – auf der Fläche also kein Goldstaub/Abdunkeln.
local PHANTOM_SO = os.getenv("HOME") .. "/.local/share/hyprland/plugins/phantomat.so"

local function phantom_loaded()
    for _, p in ipairs(hl.get_loaded_plugins()) do
        if p.name == "spatialoverview" then return true end
    end
    return false
end

function golden.phantom()
    if not phantom_loaded() then
        hl.notification.create({ text = "Phantom: Plugin nicht geladen – ~/.config/hypr/scripts/phantomat.sh build ausführen", timeout = 8000 })
        return
    end
    if phantom_open() then
        phantom_dispatch("overview", "toggle all")      -- rauszoomen ↔ zurück
    else
        hl.exec_cmd(scripts .. "/phantomat.sh an")       -- Shader-Plugin weg, dann Fläche öffnen
    end
end

function golden.phantom_off()
    if phantom_open() then hl.exec_cmd(scripts .. "/phantomat.sh aus") end
end

do
    local f = io.open(PHANTOM_SO, "r")
    if f then
        f:close()
        hl.plugin.load(PHANTOM_SO)
    end
end
-- Einstellungen (greifen erst, wenn das Plugin geladen ist – Hyprland liest die Konfiguration danach nochmal);
-- pcall, damit ein Fehler darin nicht die Tastenkürzel weiter unten abbricht
do
    local ok, err = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/phantomat.lua")
    if not ok then hl.notification.create({ text = "Phantom: Fehler in phantomat.lua – " .. tostring(err), timeout = 10000 }) end
end

hl.bind(mod .. " + P",        golden.phantom)
hl.bind(mod .. " + CTRL + P", golden.phantom_off)

-- Alt+Tab: Fensterwechsler (Anzeige: Aufgabenansicht mit Live-Vorschau, ~/.config/quickshell/TaskView.qml)
--   Alt halten + Tab → weiter, Shift+Tab → zurück, Alt loslassen → wechseln, Alt+Esc → abbrechen
--   Versteckte Fenster werden beim Auswählen auf den aktuellen Workspace zurückgeholt.
function golden.focus_window(addr)
    local sel = "address:" .. addr
    local w = hl.get_window(sel)
    if not w then return end
    if hidden_open() then
        hl.dispatch(hl.dsp.workspace.toggle_special(HIDDEN))
    end
    if w.workspace and w.workspace.special then
        local ws = hl.get_active_workspace()
        hl.dispatch(hl.dsp.window.move({ window = sel, workspace = ws.id, follow = true }))
    end
    hl.dispatch(hl.dsp.focus({ window = sel }))
    hl.dispatch(hl.dsp.window.alter_zorder({ window = sel, mode = "top" }))
end

local function switcher(action)
    return hl.dsp.global("quickshell:switcher" .. action)
end

-- kein eigener Tastenmodus: Hyprland löst „beim Loslassen“-Binds nur im selben Modus aus,
-- in dem die Taste gedrückt wurde – deshalb alles im normalen Modus
hl.bind("ALT + Tab",         switcher("Next"), { repeating = true })
hl.bind("ALT + SHIFT + Tab", switcher("Prev"), { repeating = true })
hl.bind("ALT + Escape",      switcher("Cancel"))
-- Alt loslassen → wechseln (tut nichts, wenn der Wechsler zu ist; Apps bekommen das Loslassen trotzdem).
-- „transparent“ ist nötig, sonst überdeckt der Alt+Tab-Bind das Loslassen.
hl.bind("ALT + Alt_L",       switcher("Commit"), { release = true, non_consuming = true, transparent = true })
hl.bind("Alt_L",             switcher("Commit"), { release = true, non_consuming = true, transparent = true })

-- Maus: ziehen / Größe ändern
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop-Tasten
-- Lauter/Leiser heben auch „stumm“ auf (wie unter GNOME)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- Musik pausieren/weiter von jeder Tastatur aus (wie die Medientaste Play/Pause)
hl.bind("CTRL + SHIFT + Space",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("CTRL + SHIFT + Right",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("CTRL + SHIFT + Left",   hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- 5 Sekunden pro Druck (ohne repeating: Tastenwiederholung würde ~25× pro Sekunde auslösen)
hl.bind(mod .. " + ALT + Right", hl.dsp.exec_cmd("playerctl position 5+"), { locked = true })
hl.bind(mod .. " + ALT + Left",  hl.dsp.exec_cmd("playerctl position 5-"), { locked = true })

----------------------------------
---- FENSTER- & LAYER-REGELN -----
----------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- iPhone-Spiegelung (UxPlay/waylandsink): schwebend, Hochformat wie das Telefon
hl.window_rule({
    name  = "iphone-spiegel",
    match = { class = "^uxplay$" },
    float = true,
    center = true,
    size  = { 420, 910 },
})

hl.window_rule({
    name  = "iphone-steuern",
    match = { class = "^iphone-steuern$" },
    float = true,
    center = true,
})

-- Kleine Tools schwebend und mittig
hl.window_rule({
    name  = "float-small-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|qt6ct|nwg-look|org.gnome.Calculator|floating-tui)$" },
    float = true,
    center = true,
    size  = { "monitor_w*0.5", "monitor_h*0.6" },
})

-- App „Bildschirme“ (nwg-displays): schwebend und mittig, eigene Fenstergröße
hl.window_rule({
    name   = "float-nwg-displays",
    match  = { class = "^(nwg-displays)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Bild-im-Bild)$" },
    float = true,
    pin   = true,
    size  = { "monitor_w*0.28", "monitor_h*0.28" },
    move  = { "monitor_w*0.70", "monitor_h*0.68" },
})

-- Dropdown-Terminal: oben, 80 % breit, 45 % hoch (golden.dropdown_terminal)
hl.window_rule({
    name      = "dropdown-terminal",
    match     = { class = "^dropterm$" },
    workspace = "special:dropterm",
    float     = true,
    size      = { "monitor_w*0.8", "monitor_h*0.45" },
    move      = { "monitor_w*0.1", "monitor_h*0.06" },
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Clawd on Desk: Desktop-Pet ohne Deko, auf allen Workspaces sichtbar
hl.window_rule({
    name        = "clawd-on-desk-pet",
    match       = { class = "^clawd-on-desk$", float = true },
    pin         = true,
    decorate    = false,
    no_shadow   = true,
    no_blur     = true,
    border_size = 0,
    rounding    = 0,
    no_anim     = true,
})

-- Fenster-Shader (Plugin HyprWindowShade, geladen im Autostart über scripts/windowshade.sh):
-- Goldstaub beim Öffnen, inaktive Fenster warm abgedunkelt, Glanz beim Fokus, Puls bei „Aufmerksamkeit“.
-- Beim Schliessen bewusst kein Shader (Wunsch) – goldstaub-schliessen.glsl liegt bereit: close = "goldstaub-schliessen.glsl".
-- Die Tags sind normale Hyprland-Tags – ohne Plugin tun sie nichts. Shader in ~/.config/hypr/shaders/,
-- Änderungen an einer .glsl lädt das Plugin beim Speichern selbst. Ausgenommen: Clawd-Pet und Bild-im-Bild.
local shaderDir = os.getenv("HOME") .. "/.config/hypr/shaders/"
for name, shader in pairs({
    open     = "goldstaub-oeffnen.glsl",
    inactive = "dim-inaktiv.glsl",
    focus    = "fokus-glanz.glsl",
    urgent   = "alarm-puls.glsl",
}) do
    hl.window_rule({
        name  = "shader-" .. name,
        match = { class = "negative:^(clawd-on-desk)$", title = "negative:^(Picture-in-Picture|Bild-im-Bild)$" },
        tag   = "+shader_" .. name .. ":" .. shaderDir .. shader,
    })
end

-- Blur hinter Quickshell-Flächen, rofi und Benachrichtigungen
-- (golden-clock bewusst ohne Blur: die Desktop-Uhr ist eine klare Glasscheibe, das Wallpaper soll durchscheinen)
hl.layer_rule({ match = { namespace = "^golden-(bar|music|taskview|control|osd|keys|gallery|airdrop)$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "^rofi$" },                     blur = true, ignore_alpha = 0.1, dim_around = false })
hl.layer_rule({ match = { namespace = "^notifications$" },            blur = true, ignore_alpha = 0.1 })
-- Aufgabenansicht / Alt+Tab (TaskView.qml) soll sofort da sein: kein Einblenden (fadeLayersIn, 200 ms) und kein
-- animiertes Großziehen – die Fenster dafür liegen dauerhaft als 1×1 px bereit und werden beim Öffnen nur groß gezogen
hl.layer_rule({ match = { namespace = "^golden-taskview$" },          no_anim = true })
hl.layer_rule({ match = { namespace = "^golden-gallery$" },           no_anim = true })   -- blendet selbst ein (QML)
