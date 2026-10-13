#version 320 es
precision highp float;
// ★ 8155 – Puls, wenn ein Fenster Aufmerksamkeit will (HyprWindowShade, Tag +shader_urgent:)
// Zweimal leuchtet ein amber Schein vom Rand her nach innen auf. Endet genau beim normalen Bild.
// @duration 1.2

in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform vec4  window_rect;
uniform vec2  surface_size;

const float RAND    = 36.0;   // wie weit der Schein nach innen reicht (Pixel)
const float STAERKE = 0.75;
const float TOENUNG = 0.10;   // leichtes Amber über das ganze Fenster
const float PULSE   = 2.0;
const vec3  AMBER = vec3(0.89, 0.63, 0.26);

void main() {
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;
    vec2 groesse = surface_size * window_rect.zw;
    vec2 px = local * groesse;
    float abstand = min(min(px.x, groesse.x - px.x), min(px.y, groesse.y - px.y));
    float rand = 1.0 - smoothstep(0.0, RAND, abstand);
    float puls = abs(sin(progress * 3.14159265 * PULSE));     // 0 am Anfang und Ende

    vec4 c = texture(tex, v_texcoord);
    float k = clamp(rand * STAERKE + TOENUNG, 0.0, 1.0) * puls;
    fragColor = vec4(mix(c.rgb, AMBER, k), mix(c.a, 1.0, k));
}
