// Phosphor Monitor Overlay
// Liegt auf CanvasLayer über dem ui_tint_overlay.
// Fügt atmosphärische CRT-Effekte hinzu ohne feine Schrift zu beeinträchtigen.
//
// Lesbarkeits-Prinzipien:
//   · Kein Blur / keine Pixelierung — Textränder bleiben scharf
//   · Glow ist rein additiv — hellt auf, verschiebt keine Pixel
//   · Scanlines: sehr dünne Schattenlinie alle 2px, nie ganze Zeilen blockieren
//   · Chromatische Aberration: nur horizontal, max 1–2px, default minimal
//   · Keine Bildkrümmung / kein Barrel-Distort
//
// Setup: CanvasLayer (Layer 128, über ui_tint_overlay) > ColorRect FullRect
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

// --- Phosphor Glow ---
// Additives Leuchten um helle Bereiche. Bewahrt Schärfe, da Samples nicht
// in direkten Nachbarpixeln landen (erst ab glow_spread px Abstand).
uniform float glow_strength : hint_range(0.0, 1.0,  0.01) = 0.22;
uniform float glow_spread   : hint_range(1.0, 8.0,  0.5)  = 3.0;

// --- Scanlines ---
// Dünne Schattenlinie (nicht volle Zeile!) zwischen je 2 Bildschirmpixeln.
// scanline_sharpness: höher = schmalere Linie = besser für Text.
uniform float scanline_strength  : hint_range(0.0, 0.5,  0.01) = 0.14;
uniform float scanline_sharpness : hint_range(2.0, 16.0, 0.5)  = 8.0;

// --- Chromatische Aberration ---
// Nur horizontal. Bei 0 deaktiviert. > 1.5px ist sichtbar auf kleinem Text.
uniform float chromatic_px : hint_range(0.0, 3.0, 0.1) = 0.6;

// --- Flicker ---
// Sehr subtiles globales Helligkeitsrauschen. Werte > 0.04 wirken nervös.
uniform float flicker_strength : hint_range(0.0, 0.08, 0.005) = 0.018;

// --- Helligkeit ---
uniform float brightness : hint_range(0.7, 1.5, 0.01) = 1.04;

// --- Vignette ---
uniform float vignette_strength : hint_range(0.0, 2.0,  0.05) = 0.65;
uniform float vignette_softness : hint_range(0.02, 0.5, 0.01) = 0.28;


void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	// ── Chromatische Aberration ──────────────────────────────────────────────
	// Horizontaler RGB-Versatz. filter_linear sorgt für weichen Übergang,
	// kein harter Farbrand auf weißen Buchstaben.
	float ca = chromatic_px * px.x;
	float r = texture(SCREEN_TEXTURE, uv + vec2( ca, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv             ).g;
	float b = texture(SCREEN_TEXTURE, uv + vec2(-ca, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// ── Phosphor Glow (additiv, 8-Sample Ring) ───────────────────────────────
	// Kreuz + Diagonalen im Abstand glow_spread px.
	// Sampling auf Distanz (nicht 1px-Nachbarn) → kein Weichzeichnen der Ränder.
	vec3 glow = vec3(0.0);
	float s = glow_spread;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2( s,  0.0)).rgb;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2(-s,  0.0)).rgb;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2( 0.0,  s)).rgb;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2( 0.0, -s)).rgb;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2( s,  s) * 0.707).rgb * 0.5;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2(-s,  s) * 0.707).rgb * 0.5;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2( s, -s) * 0.707).rgb * 0.5;
	glow += texture(SCREEN_TEXTURE, uv + px * vec2(-s, -s) * 0.707).rgb * 0.5;
	glow /= 6.0;  // Normierung: 4×1.0 + 4×0.5 = 6.0

	// Luma des Basispixels als Gate: nur bereits helle Pixel bekommen Glow.
	// Verhindert, dass dunkle Flächen (Space, Schatten) aufhellen.
	float base_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col += glow * base_luma * glow_strength;

	// ── Scanlines ────────────────────────────────────────────────────────────
	// Periode 2 Bildschirmpixel. Dunkle Linie sitzt genau zwischen den Zeilen,
	// nie auf dem Pixel selbst. Bei sharpness >= 8 ist die Linie < 0.5px breit.
	float line_phase = fract(FRAGCOORD.y * 0.5);              // 0..1 pro 2px
	float band = abs(line_phase * 2.0 - 1.0);                 // 0 = Mitte, 1 = Rand
	float scanline_shadow = pow(1.0 - band, scanline_sharpness);
	col *= 1.0 - scanline_strength * scanline_shadow;

	// ── Flicker ──────────────────────────────────────────────────────────────
	// Zwei überlagerte Frequenzen für organisches Rauschen.
	float flicker = sin(TIME * 53.7) * 0.6 + sin(TIME * 17.3) * 0.4;
	flicker = 1.0 - flicker_strength * (flicker * 0.5 + 0.5);
	col *= flicker;

	// ── Helligkeit ───────────────────────────────────────────────────────────
	col *= brightness;

	// ── Vignette (vier Ränder, rechteckig) ───────────────────────────────────
	float vx = smoothstep(0.0, vignette_softness, uv.x)
	         * smoothstep(0.0, vignette_softness, 1.0 - uv.x);
	float vy = smoothstep(0.0, vignette_softness, uv.y)
	         * smoothstep(0.0, vignette_softness, 1.0 - uv.y);
	col *= mix(1.0, vx * vy, vignette_strength);

	COLOR = vec4(col, 1.0);
}
