#version 320 es
precision highp float;
// ★ 8155 – Goldstaub beim Öffnen (HyprWindowShade, Tag +shader_open:)
// Das Fenster setzt sich aus feinen Körnern zusammen, von unten nach oben, jedes Korn glüht beim
// Erscheinen kurz amber auf und kühlt dann zur echten Farbe ab. Läuft nur während der Animation.
// @duration 0.55

in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;     // 0 → 1 über die Animation
uniform float seed;         // pro Fenster anders → jedes Fenster zerfällt anders
uniform vec4  window_rect;  // wo das Fenster in der Textur liegt
uniform vec2  surface_size; // Grösse der Textur (logische Pixel)

const float KORN      = 4.0;   // Korngrösse in Pixeln
const float KANTE     = 0.12;  // wie lange ein Korn braucht (Anteil der Animation)
const float VON_UNTEN = 0.45;  // 0 = alle Körner zufällig, 1 = streng von unten nach oben
const float GLUT      = 0.85;  // wie stark ein Korn beim Erscheinen amber glüht
const vec3  AMBER      = vec3(0.89, 0.63, 0.26);   // #e3a142
const vec3  AMBER_HELL = vec3(0.95, 0.77, 0.49);   // #f2c57c

float zufall(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;   // 0..1 über das Fenster
    vec2 px    = local * surface_size * window_rect.zw;
    vec2 zelle = floor(px / KORN) + seed * 917.0;

    // Zeitpunkt, zu dem dieses Korn erscheint (unten früher, oben später)
    float h = mix(zufall(zelle), 1.0 - local.y, VON_UNTEN);
    float p = mix(-KANTE, 1.0 + 2.0 * KANTE, progress);

    float da   = smoothstep(h - KANTE, h, p);                         // Korn sichtbar
    float glut = (1.0 - smoothstep(h - KANTE, h + 2.0 * KANTE, p)) * GLUT;
    vec3  farbe = mix(AMBER, AMBER_HELL, step(0.93, zufall(zelle + 7.0)));  // ein paar Körner funkeln heller

    vec4 src = texture(tex, v_texcoord);                              // vormultipliziert
    vec4 col = vec4(mix(src.rgb, farbe, glut), mix(src.a, 1.0, glut));
    fragColor = col * da;
}
