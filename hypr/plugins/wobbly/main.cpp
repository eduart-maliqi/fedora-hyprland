// ╭──────────────────────────────────────────────────────────────╮
// │  ★ 8155  ·  wobbly – Wackelfenster für Hyprland 0.56  │
// ╰──────────────────────────────────────────────────────────────╯
// Fenster verformen sich beim Verschieben wie Wackelpudding und schwingen danach nach.
//
// So funktioniert es:
//   - Vor jedem Bild (Ereignis render.pre) wird geprüft, ob sich ein Fenster bewegt hat.
//     Über jedem Fenster liegt ein Gitter (GRID × GRID Felder). Bewegt sich das Fenster, bleiben die
//     Gitterpunkte zurück – je weiter weg vom Griffpunkt (Maus beim Ziehen, sonst Fenstermitte), desto mehr.
//   - Jeder Gitterpunkt hängt an einer gedämpften Feder und schwingt zu seinem Platz zurück.
//   - Solange ein Fenster wackelt, hängt ein IWindowTransformer daran: Hyprland zeichnet das Fenster dann in
//     einen eigenen Puffer, transform() zeichnet diesen Puffer als verformtes Gitter neu. Ruht das Fenster,
//     wird der Transformer wieder entfernt → im Leerlauf kein Mehraufwand, keine zusätzlichen Bilder.
//
// Einstellungen (hyprland.lua: hl.config({ plugin = { wobbly = { … } } })):
//   enabled   – an/aus (Super+G schaltet um, siehe golden.toggle_wobbly)
//   stiffness – Federhärte: höher = schneller zurück, schnellere Schwingung
//   damping   – Dämpfung: höher = weniger Nachschwingen
//   strength  – wie stark das Fenster beim Ziehen zurückbleibt (0 … 2)
//
// Bauen: ./build.sh (holt passende Header, muss nach jedem Hyprland-Update neu laufen).

#define WLR_USE_UNSTABLE

#include <hyprland/src/includes.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/helpers/time/Time.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/output/MonitorResources.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/Shader.hpp>
#include <hyprland/src/render/transformer/Transformer.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <optional>
#include <unordered_map>

inline HANDLE PHANDLE = nullptr;

// Nicht ändern – Hyprland prüft damit, ob das Plugin zur laufenden Version passt.
APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

namespace {

    constexpr int    GRID    = 12;                          // Felder pro Seite
    constexpr int    ROW     = GRID + 1;                    // Punkte pro Zeile
    constexpr int    VERTS   = ROW * ROW;
    constexpr double SUBSTEP = 1.0 / 240.0;                 // Physik-Takt (s)
    constexpr double MAX_DT  = 1.0 / 30.0;                  // längere Pausen zählen nicht als Zeit
    constexpr double JUMP    = 600.0;                       // Sprung > 600 px pro Bild = Teleport, nicht wackeln
    constexpr double GRAB_R  = 0.30;                        // Reichweite des Griffs (Anteil der Fenstergröße)
    constexpr double ANIM    = 0.5;                         // Stärke bei Bewegungen ohne Maus (Tiling-Animationen)

    struct {
        SP<Config::Values::CBoolValue>  enabled;
        SP<Config::Values::CFloatValue> stiffness;
        SP<Config::Values::CFloatValue> damping;
        SP<Config::Values::CFloatValue> strength;
    } cfg;

    struct SWobble {
        PHLWINDOWREF                window;
        Vector2D                    lastPos;
        bool                        known  = false;
        bool                        active = false;    // Transformer hängt am Fenster
        std::array<Vector2D, VERTS> off{};             // Abweichung jedes Gitterpunkts (logische Pixel)
        std::array<Vector2D, VERTS> vel{};
        std::array<double, VERTS>   pull{};            // 1 = am Griff, 0 = weit weg (aus der letzten Bewegung)
        std::optional<Vector2D>     grab;              // Griffpunkt beim Ziehen (0…1 in der Fensterbox)
        CBox                        lastDamage;        // zuletzt neu gezeichneter Bereich (global)
    };

    std::unordered_map<const void*, SWobble> g_wobbles;
    Time::steady_tp                          g_lastUpdate = Time::steadyNow();

    Hyprutils::Signal::CHyprSignalListener   g_onRenderPre, g_onDestroy, g_onReload;

    // ── GL: eigener Shader + Gitter-Puffer ────────────────────────
    struct {
        SP<CShader> shader;
        GLuint      vao = 0, vbo = 0, ebo = 0;
        GLsizei     indexCount = 0;
        bool        failed     = false;
    } g_gl;

    constexpr const char* FRAGSRC = R"glsl(#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;
void main() {
    fragColor = texture(tex, v_texcoord);
}
)glsl";

    bool initGL() {
        if (g_gl.shader)
            return true;
        if (g_gl.failed)
            return false;

        auto shader = makeShared<CShader>();
        // dynamic = true → bei Fehler false statt Absturz
        if (!shader->createProgram(Render::GL::g_pHyprOpenGL->m_shaders->TEXVERTSRC, FRAGSRC, true)) {
            g_gl.failed = true;
            HyprlandAPI::addNotification(PHANDLE, "[wobbly] Shader ließ sich nicht bauen – Wackeln aus", CHyprColor{1.0, 0.4, 0.3, 1.0}, 6000);
            return false;
        }

        const GLint POS = shader->getUniformLocation(SHADER_POS_ATTRIB);
        const GLint TEX = shader->getUniformLocation(SHADER_TEX_ATTRIB);
        if (POS < 0 || TEX < 0) {
            g_gl.failed = true;
            return false;
        }

        std::vector<GLushort> indices;
        indices.reserve(GRID * GRID * 6);
        for (int y = 0; y < GRID; ++y) {
            for (int x = 0; x < GRID; ++x) {
                const GLushort TL = y * ROW + x, TR = TL + 1, BL = TL + ROW, BR = BL + 1;
                indices.insert(indices.end(), {TL, BL, TR, TR, BL, BR});
            }
        }

        glGenVertexArrays(1, &g_gl.vao);
        glGenBuffers(1, &g_gl.vbo);
        glGenBuffers(1, &g_gl.ebo);

        glBindVertexArray(g_gl.vao);
        glBindBuffer(GL_ARRAY_BUFFER, g_gl.vbo);
        glBufferData(GL_ARRAY_BUFFER, VERTS * 4 * sizeof(float), nullptr, GL_STREAM_DRAW);
        glEnableVertexAttribArray(POS);
        glVertexAttribPointer(POS, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(TEX);
        glVertexAttribPointer(TEX, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_gl.ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLushort), indices.data(), GL_STATIC_DRAW);
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

        g_gl.indexCount = indices.size();
        g_gl.shader     = shader;
        return true;
    }

    void deinitGL() {
        if (!g_gl.shader)
            return;
        Render::GL::g_pHyprOpenGL->makeEGLCurrent();
        glDeleteVertexArrays(1, &g_gl.vao);
        glDeleteBuffers(1, &g_gl.vbo);
        glDeleteBuffers(1, &g_gl.ebo);
        g_gl.shader.reset();
    }

    // ── Transformer: zeichnet das Fenster als verformtes Gitter ────
    class CWobblyTransformer : public Render::IWindowTransformer {
      public:
        explicit CWobblyTransformer(PHLWINDOWREF w) : m_window(w) {}

        void preWindowRender(CSurfacePassElement::SRenderData* pRenderData) override {
            m_haveBox = false;
        }

        // nur bei normalem Zeichnen aufgerufen – bei Screenshots/Vorschauen (standalone) bleibt das Fenster gerade
        void amendTransformedRenderData(const CBox& currentBox, SMotionBlurData* pMotionBlurData) override {
            m_box     = currentBox;
            m_haveBox = true;
        }

        SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override;

      private:
        PHLWINDOWREF m_window;
        CBox         m_box; // ganze Fensterbox (mit Rahmen + Schatten), bildschirm-lokal, logisch
        bool         m_haveBox = false;
    };

    SP<Render::IFramebuffer> CWobblyTransformer::transform(SP<Render::IFramebuffer> in) {
        const auto PWINDOW  = m_window.lock();
        const auto PMONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();

        if (!PWINDOW || !PMONITOR || !m_haveBox || !in || !in->getTexture() || PMONITOR->m_transform != WL_OUTPUT_TRANSFORM_NORMAL)
            return in;

        const auto IT = g_wobbles.find(PWINDOW.get());
        if (IT == g_wobbles.end() || !IT->second.active || !initGL())
            return in;

        // WP auf ein UP → nicht lock()en (Assertion), nur prüfen und direkt benutzen
        const auto& RESOURCES = PMONITOR->resources();
        if (!RESOURCES)
            return in;

        const auto OUT = RESOURCES->getUnusedWorkBuffer();
        if (!OUT)
            return in;

        const auto& s     = IT->second;
        const auto  MONPX = PMONITOR->m_transformedSize;
        const auto  SCALE = PMONITOR->m_scale;
        const CBox  PX    = m_box.copy().scale(SCALE);

        // Punkte: Position = Ruheplatz + Abweichung, Texturkoordinate = Ruheplatz (beides 0…1 über den Bildschirm)
        std::array<float, VERTS * 4> data;
        for (int y = 0; y < ROW; ++y) {
            for (int x = 0; x < ROW; ++x) {
                const int      i    = y * ROW + x;
                const Vector2D REST = {PX.x + PX.w * x / GRID, PX.y + PX.h * y / GRID};
                const Vector2D POS  = REST + s.off[i] * SCALE;
                data[i * 4 + 0]     = POS.x / MONPX.x;
                data[i * 4 + 1]     = POS.y / MONPX.y;
                data[i * 4 + 2]     = REST.x / MONPX.x;
                data[i * 4 + 3]     = REST.y / MONPX.y;
            }
        }

        {
            auto guard = g_pHyprRenderer->bindTempFB(OUT);

            Render::GL::g_pHyprOpenGL->scissor(nullptr);
            glClearColor(0.F, 0.F, 0.F, 0.F);
            glClear(GL_COLOR_BUFFER_BIT);

            const CBox MONBOX = {0, 0, MONPX.x, MONPX.y};
            const auto MATRIX = g_pHyprRenderer->projectBoxToTarget(MONBOX);

            Render::GL::g_pHyprOpenGL->blend(false);
            auto shader = Render::GL::g_pHyprOpenGL->useShader(g_gl.shader);
            shader->setUniformMatrix3fv(SHADER_PROJ, 1, GL_TRUE, MATRIX.getMatrix());
            shader->setUniformInt(SHADER_TEX, 0);

            glActiveTexture(GL_TEXTURE0);
            in->getTexture()->bind();

            glBindVertexArray(g_gl.vao);
            glBindBuffer(GL_ARRAY_BUFFER, g_gl.vbo);
            glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(data), data.data());
            glDrawElements(GL_TRIANGLES, g_gl.indexCount, GL_UNSIGNED_SHORT, nullptr);
            glBindVertexArray(0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);

            in->getTexture()->unbind();
            Render::GL::g_pHyprOpenGL->blend(true);
        }

        return OUT;
    }

    // ── Fenster an/abmelden ───────────────────────────────────────
    bool hasTransformer(const PHLWINDOW& w) {
        return std::ranges::any_of(w->m_transformers, [](const auto& t) { return dynamic_cast<CWobblyTransformer*>(t.get()) != nullptr; });
    }

    void attach(const PHLWINDOW& w) {
        if (!hasTransformer(w))
            w->m_transformers.emplace_back(makeUnique<CWobblyTransformer>(w));
    }

    void detach(const PHLWINDOW& w) {
        std::erase_if(w->m_transformers, [](const auto& t) { return dynamic_cast<CWobblyTransformer*>(t.get()) != nullptr; });
    }

    // ganze Fensterbox so, wie sie gerade gezeichnet wird (global, logisch)
    CBox renderBox(const PHLWINDOW& w) {
        CBox box = w->getFullWindowBoundingBox();
        if (!w->m_pinned && w->m_workspace)
            box.translate(w->m_workspace->m_renderOffset->value());
        box.translate(w->m_floatingOffset);
        return box;
    }

    // Bereich, den das verformte Fenster bedeckt
    CBox wobbleBox(const SWobble& s, const CBox& box) {
        double x1 = box.x, y1 = box.y, x2 = box.x + box.w, y2 = box.y + box.h;
        for (int y = 0; y < ROW; ++y) {
            for (int x = 0; x < ROW; ++x) {
                const auto&    O = s.off[y * ROW + x];
                const Vector2D P = {box.x + box.w * x / GRID + O.x, box.y + box.h * y / GRID + O.y};
                x1               = std::min(x1, P.x);
                y1               = std::min(y1, P.y);
                x2               = std::max(x2, P.x);
                y2               = std::max(y2, P.y);
            }
        }
        return CBox{x1, y1, x2 - x1, y2 - y1}.expand(4);
    }

    void damage(SWobble& s, const CBox& now) {
        if (!s.lastDamage.empty())
            g_pHyprRenderer->damageBox(s.lastDamage);
        if (!now.empty())
            g_pHyprRenderer->damageBox(now);
        s.lastDamage = now;
    }

    void settle(SWobble& s, const PHLWINDOW& w) {
        s.off.fill({});
        s.vel.fill({});
        s.grab.reset();
        if (s.active) {
            if (w)
                detach(w);
            damage(s, {});
            s.active = false;
        }
    }

    void clearAll() {
        for (auto& [key, s] : g_wobbles) {
            settle(s, s.window.lock());
        }
        g_wobbles.clear();
    }

    bool eligible(const PHLWINDOW& w) {
        if (!Desktop::View::validMapped(w) || w->isHidden() || !w->m_workspace || !w->m_monitor)
            return false;
        if (Fullscreen::controller()->isFullscreen(w))
            return false;
        // Fenster mit Regel no_anim (z. B. das Clawd-Pet) wackeln nicht
        return !w->m_ruleApplicator->noAnim().valueOrDefault();
    }

    // Bewegung um DELTA: Gitterpunkte bleiben zurück, nahe am Griff weniger
    void applyMove(SWobble& s, const Vector2D& delta, const CBox& box) {
        const bool     GRABBED  = s.grab.has_value();
        const Vector2D G        = s.grab.value_or(Vector2D{0.5, 0.5});
        const double   STRENGTH = cfg.strength->value() * (GRABBED ? 1.0 : ANIM);
        const double   NORM     = std::max({box.w, box.h, 1.0});

        for (int y = 0; y < ROW; ++y) {
            for (int x = 0; x < ROW; ++x) {
                const Vector2D P    = {box.w * x / GRID, box.h * y / GRID};
                const double   D    = P.distance(Vector2D{G.x * box.w, G.y * box.h}) / NORM;
                const double   PULL = 1.0 / (1.0 + (D / GRAB_R) * (D / GRAB_R)); // 1 am Griff, fällt nach außen ab
                s.pull[y * ROW + x] = PULL;
                s.off[y * ROW + x] -= delta * ((1.0 - PULL) * STRENGTH);
            }
        }
    }

    // Federn weiterrechnen; true = alles in Ruhe
    bool step(SWobble& s, double dt, const CBox& box) {
        const double K     = cfg.stiffness->value();
        const double C     = cfg.damping->value();
        const double LIMIT = std::clamp(std::min(box.w, box.h) * 0.3, 20.0, 240.0);
        const int    STEPS = std::max(1, (int)std::ceil(dt / SUBSTEP));
        const double H     = dt / STEPS;

        // weiter weg vom Griff hängen die Punkte weicher → schwingen etwas langsamer und versetzt nach (Wackelpudding)
        std::array<double, VERTS> k, c;
        for (int i = 0; i < VERTS; ++i) {
            const double SOFT = 1.0 - 0.4 * (1.0 - s.pull[i]);
            k[i]              = K * SOFT;
            c[i]              = C * std::sqrt(SOFT);
        }

        for (int n = 0; n < STEPS; ++n) {
            for (int i = 0; i < VERTS; ++i) {
                s.vel[i] += (s.off[i] * -k[i] - s.vel[i] * c[i]) * H;
                s.off[i] += s.vel[i] * H;
            }
        }

        double maxOff = 0, maxVel = 0;
        for (int i = 0; i < VERTS; ++i) {
            maxOff = std::max(maxOff, s.off[i].size());
            maxVel = std::max(maxVel, s.vel[i].size());
        }

        // nicht beliebig weit auseinanderziehen – das ganze Gitter gleichmäßig stauchen,
        // einzelne Punkte zu kürzen brächte sie außer Takt (gewellte Ränder)
        if (maxOff > LIMIT) {
            const double F = LIMIT / maxOff;
            for (int i = 0; i < VERTS; ++i) {
                s.off[i] = s.off[i] * F;
                s.vel[i] = s.vel[i] * F;
            }
            maxOff = LIMIT;
            maxVel *= F;
        }

        return maxOff < 0.3 && maxVel < 4.0;
    }

    // ── pro Bild: Bewegungen erkennen, Physik rechnen, neu zeichnen lassen ──
    void update() {
        const auto NOW = Time::steadyNow();
        double     dt  = std::chrono::duration<double>(NOW - g_lastUpdate).count();
        if (dt < 0.002) // mehrere Bildschirme im selben Takt → nur einmal rechnen
            return;
        g_lastUpdate = NOW;
        dt           = std::min(dt, MAX_DT);

        if (!cfg.enabled->value()) {
            if (!g_wobbles.empty())
                clearAll();
            return;
        }

        PHLWINDOW dragged, resized;
        if (g_layoutManager && g_layoutManager->dragController()) {
            const auto& DRAG = g_layoutManager->dragController();
            if (const auto TARGET = DRAG->target(); TARGET) {
                if (DRAG->mode() == MBIND_MOVE)
                    dragged = TARGET->window();
                else if (DRAG->mode() != MBIND_INVALID)
                    resized = TARGET->window();
            }
        }

        const Vector2D MOUSE = g_pInputManager ? g_pInputManager->getMouseCoordsInternal() : Vector2D{};

        for (const auto& w : Desktop::windowState()->windows()) {
            const void* KEY = w.get();

            if (!eligible(w)) {
                if (const auto IT = g_wobbles.find(KEY); IT != g_wobbles.end()) {
                    settle(IT->second, w);
                    g_wobbles.erase(IT);
                }
                continue;
            }

            auto& s = g_wobbles[KEY];
            if (s.window.lock() != w) {
                s        = SWobble{};
                s.window = w;
            }

            const Vector2D POS = w->positionAnimation()->value();
            if (!s.known) {
                s.lastPos = POS;
                s.known   = true;
                continue;
            }

            const Vector2D DELTA = POS - s.lastPos;
            s.lastPos            = POS;
            const CBox BOX       = renderBox(w);

            if (w == dragged) {
                if (!s.grab && BOX.w > 0 && BOX.h > 0)
                    s.grab = Vector2D{std::clamp((MOUSE.x - BOX.x) / BOX.w, 0.0, 1.0), std::clamp((MOUSE.y - BOX.y) / BOX.h, 0.0, 1.0)};
            } else
                s.grab.reset();

            const double DIST = DELTA.size();
            if (DIST > JUMP) { // Teleport (z. B. auf anderen Bildschirm geschoben): nicht wackeln
                settle(s, w);
                continue;
            }

            if (DIST > 0.01 && w != resized) {
                applyMove(s, DELTA, BOX);
                if (!s.active) {
                    attach(w);
                    s.active = true;
                }
            }

            if (!s.active)
                continue;

            const bool CALM = step(s, dt, BOX);
            if (CALM && DIST <= 0.01 && !s.grab) {
                settle(s, w);
                continue;
            }

            damage(s, wobbleBox(s, BOX)); // plant auch das nächste Bild ein → Schwingung läuft weiter
        }

        // Einträge zu verschwundenen Fenstern aufräumen
        std::erase_if(g_wobbles, [](const auto& e) { return e.second.window.expired(); });
    }
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();

    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[wobbly] Passt nicht zur laufenden Hyprland-Version – ~/.config/hypr/plugins/wobbly/build.sh ausführen",
                                     CHyprColor{1.0, 0.4, 0.3, 1.0}, 10000);
        throw std::runtime_error("[wobbly] Version mismatch");
    }

    cfg.enabled   = makeShared<Config::Values::CBoolValue>("plugin:wobbly:enabled", "Wackelfenster an/aus", true);
    cfg.stiffness = makeShared<Config::Values::CFloatValue>("plugin:wobbly:stiffness", "Federhärte", 180.F, Config::Values::SFloatValueOptions{.min = 20.F, .max = 2000.F});
    cfg.damping   = makeShared<Config::Values::CFloatValue>("plugin:wobbly:damping", "Dämpfung", 7.F, Config::Values::SFloatValueOptions{.min = 0.5F, .max = 100.F});
    cfg.strength  = makeShared<Config::Values::CFloatValue>("plugin:wobbly:strength", "Stärke beim Ziehen", 1.F, Config::Values::SFloatValueOptions{.min = 0.F, .max = 2.F});

    HyprlandAPI::addConfigValueV2(PHANDLE, cfg.enabled);
    HyprlandAPI::addConfigValueV2(PHANDLE, cfg.stiffness);
    HyprlandAPI::addConfigValueV2(PHANDLE, cfg.damping);
    HyprlandAPI::addConfigValueV2(PHANDLE, cfg.strength);

    g_onRenderPre = Event::bus()->m_events.render.pre.listen([](PHLMONITOR) { update(); });
    g_onDestroy   = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF w) { g_wobbles.erase(w.get()); });
    // nach dem Neuladen der Konfiguration (z. B. „aus“ per Super+G) sofort aufräumen, nicht erst beim nächsten Bild
    g_onReload = Event::bus()->m_events.config.reloaded.listen([] {
        if (!cfg.enabled->value())
            clearAll();
    });

    return {"wobbly", "Wackelfenster (8155)", "8155", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_onRenderPre.reset();
    g_onDestroy.reset();
    g_onReload.reset();

    // Transformer müssen weg, bevor der Code dieser Bibliothek entladen wird
    for (const auto& w : Desktop::windowState()->windows()) {
        detach(w);
    }
    for (auto& [key, s] : g_wobbles) {
        if (!s.lastDamage.empty())
            g_pHyprRenderer->damageBox(s.lastDamage);
    }
    g_wobbles.clear();

    deinitGL();
}
