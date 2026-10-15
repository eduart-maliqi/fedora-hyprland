#version 440
// ★ 8155 – Hintergrund „fluss“ des Songtext-Bildschirms (LyricsScreen.qml)
//   Farben fließen wie Flüssigkeit ineinander (Domain Warping: Rauschen verzerrt Rauschen),
//   das Wallpaper wird mitverzerrt hineingemischt. Farben c1…c4 kommen aus dem Farbthema.
//   Nach Änderungen neu kompilieren:
//     /usr/lib64/qt6/bin/qsb --qt6 -o fluss.frag.qsb fluss.frag
//   phase läuft 0 … 2π und springt dann zurück – alle Bewegungen hängen nur über circ(k) mit ganzzahligem k
//   davon ab, darum ist der Sprung unsichtbar.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float aspect;      // Breite / Höhe
    vec4 c1;           // dunkel
    vec4 c2;
    vec4 c3;
    vec4 c4;           // hell
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float wert(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * wert(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

vec2 circ(float k) { return vec2(cos(phase * k), sin(phase * k)); }

void main() {
    vec2 p = qt_TexCoord0 * vec2(aspect, 1.0) * 1.4;
    vec2 q = vec2(fbm(p + 0.9 * circ(1.0)),
                  fbm(p + vec2(5.2, 1.3) + 0.9 * circ(2.0)));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + 0.7 * circ(3.0)),
                  fbm(p + 3.0 * q + vec2(8.3, 2.8) - 0.7 * circ(2.0)));
    float f = fbm(p + 3.0 * r);

    vec3 col = mix(c1.rgb, c2.rgb, smoothstep(0.25, 0.75, f));
    col = mix(col, c3.rgb, smoothstep(0.25, 0.85, length(q)) * 0.9);
    col = mix(col, c4.rgb, smoothstep(0.5, 0.75, r.x) * 0.8);

    vec3 wp = texture(source, clamp(qt_TexCoord0 + (r - 0.5) * 0.4, 0.0, 1.0)).rgb;
    col = mix(col, wp, 0.2);
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(l), col, 1.6), 0.0, 1.0);   // satter als Thema und Wallpaper von sich aus sind

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
