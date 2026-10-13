-- ★ 8155 · Phantom – Einstellungen fürs Plugin Phantomat (unendliche Arbeitsfläche)
--
--   SUPER + P          Phantom: rauszoomen / zurück (der erste Druck macht den Desktop zur Arbeitsfläche)
--   SUPER + CTRL + P   Phantom ganz aus → Fenster zurück auf ihre Workspaces (gekachelt)
--   rausgezoomt:       tippen = Fenster suchen, Enter = hin, Esc = zurück, Strg+, = Aussehen live einstellen,
--                      F1 = alle Tasten (Anzeige englisch)
--   auf der Fläche:    Mittelklick ziehen = verschieben, Strg + Mausrad = zoomen
--
-- Quelltext: ~/.local/opt/phantomat (github.com/kaolti/phantomat), bauen: ~/.config/hypr/scripts/phantomat.sh build
-- Geladen von hyprland.lua (Abschnitt „Phantom“). Intern heisst das Plugin noch „spatialoverview“
-- (Einstellungen plugin.spatialoverview, Lua hl.plugin.spatialoverview.*, `hyprctl spatialoverview`).
-- Live-Einstellungen (Strg+, in der rausgezoomten Ansicht) landen in phantomat-tuning.lua und gelten vor diesen hier.

local loaded = false
for _, p in ipairs(hl.get_loaded_plugins()) do
    if p.name == "spatialoverview" then loaded = true break end
end
-- Hyprland lädt Plugins erst nach dem ersten Einlesen und liest die Konfiguration dann nochmal –
-- vorher (oder ohne gebaute .so) gibt es die Einstellungen noch nicht.
if not loaded then return end

hl.config({
    plugin = {
        spatialoverview = {
            -- Bewegung der Kamera
            animation = { enabled = true, speed = 8.0, bezier = "phantomKamera" },

            -- gewölbte Linse beim Rauszoomen
            distortion = {
                enabled = true,
                strength = 0.14,
                edge_scale = 1.08,
                feather = 0.025,
                transition_power = 1.0,
                edge_blur = 0.0,
                edge_blur_start = 0.45,
                vignette = 0.25,
                chromatic = 0.0,
            },

            canvas = {
                enabled = true,
                desktop_mode = true,      -- eine gemeinsame, unendliche Fläche statt Workspaces
                persistent = true,        -- auch bei 100 % bleibt es die Fläche (erst SUPER+CTRL+P beendet sie)
                linked_screens = true,    -- Bildschirme liegen nebeneinander wie auf dem Tisch und wandern zusammen
                initial_zoom = 0.72,
                min_zoom = 0.05,
                max_zoom = 2.5,
                zoom_step = 0.12,
                auto_float = true,        -- alle Fenster schweben (beim Beenden kommt die alte Anordnung zurück)
                auto_place = true,        -- neue Fenster dort, wo man gerade hinschaut
                placement_gap = 40,
                space_pan = false,        -- Leertaste bleibt bei den Programmen
                direct_input = true,
                hover_focus = true,
                minimap_enabled = true,
                minimap_width = 240,
                minimap_height = 150,
                minimap_margin = 24,
                minimap_opacity = 0.72,
                grid_enabled = true,
                grid_size = 80,
                grid_width = 1,
                grid_opacity = 0.16,
                grid_style = 1,           -- 0 Linien, 1 Punkte
                grid_dot_size = 3.2,
                background_dim = 0.35,
                float_on_drag = true,
                allow_window_overflow = true,
                snap_viewport_on_pan = true,
                commit_viewport_on_close = true,
                snap_enabled = true,
                remember_layout = true,   -- Fenster behalten ihren Platz über Neustarts
            },

            -- Suche in der rausgezoomten Ansicht (Farben/Schrift wie 8155)
            navigator = {
                enabled = true,
                labels = true,
                dim_unmatched = 0.7,
                pointer = true,
                accent = "#e3a142",       -- amber
                mono_font = "JetBrainsMono Nerd Font",
                panel_opacity = 0.88,
                tuning_file = os.getenv("HOME") .. "/.config/hypr/phantomat-tuning.lua",
            },

            -- Wallpaper als ferne Ebene: zieht beim Verschieben langsamer mit
            parallax = { enabled = true, strength = 0.06, depth = 0.12, desktop = false },

            -- obere Leiste (Quickshell) gleitet beim Rauszoomen weg; ein Dock gibt es nicht
            chrome_animation = {
                enabled = true,
                top_namespace = "golden-bar",
                bottom_namespace = "",
                top_travel = 1.35,
                top_scale = 0.82,
                opacity = 0.0,
            },

            wallpaper = 0,
            blur = false,
            blur_strength = 0.7,
        },
    },
})

hl.curve("phantomKamera", { type = "bezier", points = { { 0.22, 1.0 }, { 0.36, 1.0 } } })

-- Werte aus dem Live-Einsteller (Strg+,) gewinnen – Zeile dort löschen = wieder der Wert von oben
do
    local ok, tuned = pcall(dofile, hl.plugin.spatialoverview.tuning_file())
    if ok and type(tuned) == "table" then
        local tree = {}
        for key, value in pairs(tuned) do
            local node, parts = tree, {}
            for part in string.gmatch(key, "[^:]+") do parts[#parts + 1] = part end
            for i = 1, #parts - 1 do
                node[parts[i]] = node[parts[i]] or {}
                node = node[parts[i]]
            end
            node[parts[#parts]] = value
        end
        hl.config({ plugin = { spatialoverview = tree } })
    end
end
