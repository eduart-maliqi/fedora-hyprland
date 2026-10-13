#version 320 es
precision highp float;
// ★ 8155 – Goldstaub beim Schliessen (HyprWindowShade, Tag +shader_close:)
// Das Fenster verglüht von unten nach oben in feine Körner: jedes Korn wird erst amber, dann dunkler
// und verschwindet; der Inhalt steigt dabei leicht nach oben wie warme Luft.
// Muss bei progress = 1 ganz durchsichtig sein (sonst bleibt der Schnappschuss stehen).
// @duration 0.6

in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;
uniform vec4  window_rect;  // beim Schliessen: Lage des Fensters im bildschirmgrossen Schnappschuss
uniform vec2  surface_size;

const float KORN      = 4.0;    // Korngrösse in Pixeln
const float KANTE     = 0.14;   // wie lange ein Korn glüht
const float VON_UNTEN = 0.45;
const float STEIGEN   = 0.035;  // wie weit der Inhalt nach oben treibt (Anteil der Fensterhöhe)
const float WABERN    = 0.004;  // seitliches Flimmern
const vec3  AMBER_HELL = vec3(0.95, 0.77, 0.49);   // #f2c57c
const vec3  AMBER_TIEF = vec3(0.72, 0.47, 0.17);   // #b8792b

float zufall(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    float t = progress;
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;

    // Inhalt steigt auf: von weiter unten lesen
    vec2 versatz = vec2(sin(local.y * 40.0 + seed * 6.2832 + t * 9.0) * WABERN * t, STEIGEN * t * t);
    vec2 quelle  = local + versatz;
    vec2 uv      = window_rect.xy + quelle * window_rect.zw;

    vec2  px    = quelle * surface_size * window_rect.zw;
    vec2  zelle = floor(px / KORN) + seed * 917.0;
    float h = mix(zufall(zelle), 1.0 - quelle.y, VON_UNTEN);
    float p = mix(-2.0 * KANTE, 1.0, t);

    float glut = smoothstep(h - 2.0 * KANTE, h - KANTE, p);   // Korn wird heiss
    float weg  = smoothstep(h - KANTE, h, p);                 // Korn verschwindet
    vec3  farbe = mix(AMBER_HELL, AMBER_TIEF, weg);

    vec4 src = texture(tex, uv);
    float innen = step(0.0, quelle.y) * step(quelle.y, 1.0);   // nichts von ausserhalb des Fensters holen
    vec4 col = vec4(mix(src.rgb, farbe, glut * 0.9), mix(src.a, 1.0, glut * 0.9)) * innen;
    fragColor = col * (1.0 - weg) * (1.0 - smoothstep(0.94, 1.0, t));
}
