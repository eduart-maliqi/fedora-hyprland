#version 440
// ★ 8155 – lebendiges Wallpaper (benutzt von WallpaperScene.qml)
//   Bewegt Teile eines Standbilds anhand einer Maske (~/.config/hypr/wallpapers/masken/<name>.png):
//     R = Himmel → Wolken ziehen langsam mit dem Wind und quellen leicht
//     G = Wind   → Gras, Bäume, Stoff wiegen sich in Böen (Wert = Stärke; Baumkrone oben stärker als am Stamm)
//     B = Wasser → feines Kräuseln + Glitzern
//   Direkt an Bergkanten bleibt der Himmel stehen (würde er dort verschoben, käme Berg in den Himmel).
//   Zusätzlich ziehen schwache Wolkenschatten über das Land.
//   Nach Änderungen neu kompilieren:
//     /usr/lib64/qt6/bin/qsb --qt6 -o wallpaper.frag.qsb wallpaper.frag
//   Die Zeit läuft von 0 bis 2000 s und springt dann auf 0 zurück (Wallpaper.qml). Damit das nahtlos ist,
//   muss jeder Zeit-Faktor × 2000 eine ganze Zahl ergeben (0.075 → 150, Zyklus 16 s → 125, sin mit 2π·0.27 → 540).
//   Achtung: Namen wie imageSize, noise, texture … sind in GLSL reserviert → qsb benennt sie um
//   (_imageSize) und Qt findet sie dann nicht mehr (bleiben 0). Prüfen: qsb -d wallpaper.frag.qsb

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // Sekunden, 0 … 2000
    float strength;    // 0 = Standbild, 1 = normal
    float windDir;     // 1 = Wind nach rechts, -1 = nach links
    vec2 texSize;      // Bildgröße in Pixeln
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;
layout(binding = 3) uniform sampler2D noiseTex;   // kachelbar (der Shader kachelt per fract)

vec3 rausch(vec2 p) { return texture(noiseTex, fract(p)).rgb; }

// Himmel, um d verschoben – aber nur, wo auch die Quelle sicher Himmel ist; sonst bleibt er stehen
vec3 himmelVerschoben(vec2 uv, vec2 d, vec3 still) {
    float k = smoothstep(0.75, 1.0, texture(mask, uv - d).r);
    return mix(still, texture(source, uv - d).rgb, k);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = max(texSize, vec2(1.0));
    vec2 px = 1.0 / size;
    vec2 q = uv * vec2(size.x / size.y, 1.0);   // gleichmäßige Koordinaten (Bildhöhe = 1)
    float t = time;
    float s = strength;
    float wd = windDir;
    vec4 m = texture(mask, uv);

    vec2 off = vec2(0.0);   // Verschiebung in Bildpixeln (Inhalt wandert um +off)
    float licht = 0.0;

    // ---- Wind: Böen laufen in Windrichtung übers Gras ----
    if (m.g > 0.003) {
        float boe      = rausch(q * vec2(0.9, 0.55) - vec2(wd * t * 0.075, 0.0)).r;
        float boeKlein = rausch(q * vec2(2.4, 1.6) - vec2(wd * t * 0.16, t * 0.012)).g;
        float g = smoothstep(0.3, 0.9, boe) * 0.7 + boeKlein * 0.3;
        float wiegen   = sin(6.2831853 * 0.27 * t - wd * q.x * 9.0 - q.y * 4.0 + boeKlein * 5.0);
        float flattern = rausch(q * vec2(7.0, 18.0) + vec2(wd * t * 0.21, -t * 0.04)).b - 0.5;
        float dx = g * 6.0 + wiegen * (1.2 + g * 2.0) + flattern * 3.0;
        off += m.g * s * vec2(wd * dx, abs(dx) * 0.2);
        licht += m.g * s * (g - 0.45) * 0.10;   // Böe = Halme kippen ins Licht
    }

    // ---- Wasser: kräuseln ----
    if (m.b > 0.003) {
        vec2 w1 = rausch(q * vec2(3.0, 14.0) + vec2(t * 0.05, t * 0.01)).rg - 0.5;
        vec2 w2 = rausch(q * vec2(7.0, 32.0) - vec2(t * 0.08, 0.0)).gb - 0.5;
        off += m.b * s * vec2(w1.x * 3.0 + w2.x * 1.5, (w1.y + w2.y) * 1.4);
    }

    vec3 col = texture(source, uv - off * px).rgb;
    col *= 1.0 + licht;

    // ---- Wasser: Glitzern ----
    if (m.b > 0.003) {
        float funk = rausch(q * vec2(16.0, 52.0) + vec2(t * 0.12, 0.0)).b
                   * rausch(q * vec2(11.0, 38.0) - vec2(t * 0.09, t * 0.02)).r;
        funk = smoothstep(0.7, 0.92, funk);
        float hell = dot(col, vec3(0.3, 0.59, 0.11));
        col += vec3(1.0, 0.86, 0.62) * funk * m.b * s * (0.015 + hell * 0.3);
    }

    // ---- Wolkenschatten ziehen übers Land ----
    float land = 1.0 - m.r;
    if (land > 0.01) {
        float sh = rausch(q * vec2(0.5, 0.8) - vec2(wd * t * 0.006, 0.0)).g;
        col *= 1.0 - land * s * 0.07 * smoothstep(0.5, 0.85, sh);
    }

    // ---- Himmel: Wolken ziehen (zwei versetzte Phasen, weich überblendet) ----
    if (m.r > 0.003) {
        const float zyklus = 16.0;                                   // Sekunden pro Phase
        float tiefe = mix(1.0, 0.45, smoothstep(0.1, 0.65, uv.y));   // am Horizont langsamer
        float phase = rausch(q * 0.35).b;                            // nicht überall gleichzeitig
        float p0 = fract(t / zyklus + phase);
        float p1 = fract(t / zyklus + phase + 0.5);
        float w0 = 1.0 - abs(2.0 * p0 - 1.0);
        vec2 zug = vec2(wd * 30.0, 0.0) * tiefe;                     // Pixel pro Phase
        vec2 quell = (rausch(q * vec2(0.8, 1.4) + vec2(t * 0.006, t * 0.002)).rg - 0.5) * vec2(14.0, 6.0);
        vec2 a = (zug * (p0 - 0.5) + quell) * s * px;
        vec2 b = (zug * (p1 - 0.5) + quell) * s * px;
        vec3 still = texture(source, uv).rgb;
        vec3 h = himmelVerschoben(uv, a, still) * w0 + himmelVerschoben(uv, b, still) * (1.0 - w0);
        col = mix(col, h, m.r);
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
