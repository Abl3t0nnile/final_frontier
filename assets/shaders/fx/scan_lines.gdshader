// Scanline background. Liegt hinter allem — UI etc. wird darüber gerendert.
// ColorRect full-screen in CanvasLayer mit niedrigem Layer-Wert (z.B. -1).
shader_type canvas_item;
render_mode unshaded;

// --- Scanlines ---
uniform float line_width   : hint_range(1.0, 16.0, 0.5) = 2.0;
uniform vec4  color_bright : source_color = vec4(0.07, 0.08, 0.05, 1.0);
uniform vec4  color_dark   : source_color = vec4(0.03, 0.03, 0.02, 1.0);

// --- Glow (Phosphor-Leuchten auf den hellen Zeilen) ---
uniform float glow_strength : hint_range(0.0, 1.0, 0.01) = 0.25;

// --- Vignette (randbasiert, nicht radial) ---
uniform float vignette_strength : hint_range(0.0, 2.0, 0.05) = 0.85;
uniform float vignette_softness : hint_range(0.01, 0.5, 0.01) = 0.2;

void fragment() {
    // --- Scanlines --------------------------------------------------------
    float row         = floor(FRAGCOORD.y / line_width);
    float phase       = mod(row, 2.0);

    float pos_in_band = fract(FRAGCOORD.y / line_width);
    float soft        = 0.2 / max(line_width, 1.0);
    float t           = smoothstep(0.5 - soft, 0.5 + soft, pos_in_band);
    float blend       = mix(phase, 1.0 - phase, t);

    vec3 col = mix(color_bright, color_dark, blend).rgb;

    // --- Glow -------------------------------------------------------------
    // Gauss-Falloff vom Zentrum jeder hellen Zeile nach außen
    // pos_in_band 0.5 = Mitte der hellen Zeile (blend == 0)
    float line_center = abs(pos_in_band - 0.5) * 2.0; // 0 = Mitte, 1 = Rand
    float glow = exp(-line_center * line_center * 6.0) * (1.0 - blend) * glow_strength;
    col += color_bright.rgb * glow;

    // --- Vignette (vier Ränder, nicht kreisförmig) -------------------------
    // Jede Achse einzeln abdunkeln → rechteckige Wirkung
    float vx = smoothstep(0.0, vignette_softness, UV.x)
             * smoothstep(0.0, vignette_softness, 1.0 - UV.x);
    float vy = smoothstep(0.0, vignette_softness, UV.y)
             * smoothstep(0.0, vignette_softness, 1.0 - UV.y);
    float vig = vx * vy;
    vig = mix(1.0, vig, vignette_strength);

    COLOR = vec4(col * vig, 1.0);
}
