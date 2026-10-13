#version 320 es
precision highp float;
// ★ 8155 – Glanz beim Fokus (HyprWindowShade, Tag +shader_focus:)
// Bekommt ein Fenster den Fokus, zieht ein schmaler warmer Lichtstreifen schräg darüber
// (wie Abendsonne auf Glas). Kehrt am Ende genau zum normalen Bild zurück.
// @duration 0.45

in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform vec4  window_rect;

const float BREITE   = 0.07;   // Breite des Streifens (Anteil der Diagonale)
const float STAERKE  = 0.30;   // Helligkeit des Streifens
const float WAERME   = 0.05;   // leichtes Aufwärmen des ganzen Fensters
const vec3  AMBER_HELL = vec3(0.95, 0.77, 0.49);

void main() {
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;
    float d = (local.x + local.y) * 0.5;                     // 0 oben links … 1 unten rechts
    float mitte = mix(-0.15, 1.15, progress);
    float streifen = exp(-pow((d - mitte) / BREITE, 2.0));
    float bogen = sin(progress * 3.14159265);                 // steigt und fällt → kein Sprung am Ende

    vec4 c = texture(tex, v_texcoord);
    float k = clamp(streifen * STAERKE + bogen * WAERME, 0.0, 1.0) * bogen;
    c.rgb = mix(c.rgb, AMBER_HELL * c.a, k);
    fragColor = c;
}
