#version 440
// ★ 8155 – Hintergrund „seide“ des Songtext-Bildschirms (LyricsScreen.qml)
//   Glänzende Seide/Flüssigkeit in 3D: eine Höhenlandschaft aus mehrfach verzerrten Sinuswellen, beleuchtet
//   wie Stoff (Normale aus der Steigung → Licht + Glanzpunkt). Helligkeit → Farbverlauf
//   fast schwarz → accentDeep → accent → accentSoft → fast weiß.
//   Nach Änderungen neu kompilieren UND Quickshell neu starten (die alte .qsb bleibt sonst im Zwischenspeicher):
//     /usr/lib64/qt6/bin/qsb --qt6 -o seide.frag.qsb seide.frag
//   phase läuft 0 … 2π und springt dann zurück – nur ganzzahlige Vielfache von phase → nahtlos.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float aspect;      // Breite / Höhe
    vec4 deep;
    vec4 mid;
    vec4 soft;
};

const float K1[5] = float[](1.0, 2.0, 1.0, 3.0, 2.0);
const float K2[5] = float[](2.0, 1.0, 3.0, 1.0, 2.0);

float hoehe(vec2 p) {
    for (int i = 0; i < 5; i++) {
        float fi = float(i + 1);
        p = vec2(p.x + 0.95 / fi * sin(fi * 0.9 * p.y + phase * K1[i] + 0.7 * fi),
                 p.y + 0.95 / fi * cos(fi * 0.8 * p.x + phase * K2[i] + 1.3 * fi));
    }
    return sin(p.x * 1.1 + 0.4) * cos(p.y * 0.9 - 0.3);
}

vec3 verlauf(float s) {
    vec3 c0 = deep.rgb * 0.04, c1 = deep.rgb * 0.55, c4 = mix(soft.rgb, vec3(1.0), 0.4);
    if (s < 0.3)  return mix(c0, c1, s / 0.3);
    if (s < 0.55) return mix(c1, mid.rgb, (s - 0.3) / 0.25);
    if (s < 0.8)  return mix(mid.rgb, soft.rgb, (s - 0.55) / 0.25);
    return mix(soft.rgb, c4, (s - 0.8) / 0.2);
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0) * 1.7;
    const float e = 0.004;
    float h = hoehe(p);
    float hx = (hoehe(p + vec2(e, 0.0)) - h) / e;
    float hy = (hoehe(p + vec2(0.0, e)) - h) / e;
    vec3 n = normalize(vec3(-hx * 0.9, -hy * 0.9, 1.0));
    vec3 L = normalize(vec3(-0.45, -0.55, 0.7));
    float diff = max(dot(n, L), 0.0);
    float spec = pow(max(reflect(-L, n).z, 0.0), 30.0);

    float s = clamp(pow(diff, 1.3) * 1.05 + 0.15 * h, 0.0, 1.0);
    vec3 col = verlauf(s);
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    // Glanz und Helligkeit gedeckelt – der Songtext darüber ist weiß und muss lesbar bleiben
    col = clamp(mix(vec3(l), col, 1.5) + spec * 0.3, 0.0, 1.0) * 0.82;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
