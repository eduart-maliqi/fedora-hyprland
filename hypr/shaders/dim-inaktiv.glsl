#version 320 es
precision highp float;
// ★ 8155 – inaktive Fenster abdunkeln (HyprWindowShade, Tag +shader_inactive:)
// Statt Richtung Schwarz wird Richtung Tintenblau (#12181e) abgedunkelt und leicht entsättigt –
// das aktive Fenster bleibt unberührt (kostet dort nichts).

in  vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

const float STAERKE      = 0.60;   // 0 = gar nicht, 1 = ganz Tinte (2026-10-07: 0.28 → 0.45 → 0.7 → 0.5 → auf Wunsch 0.6)
const float ENTSAETTIGEN = 0.20;   // 0 = Farben bleiben, 1 = grau
const vec3  TINTE = vec3(0.071, 0.094, 0.118);

void main() {
    vec4 c = texture(tex, v_texcoord);                     // vormultipliziert
    float hell = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    c.rgb = mix(c.rgb, vec3(hell), ENTSAETTIGEN);
    c.rgb = mix(c.rgb, TINTE * c.a, STAERKE);
    fragColor = c;
}
