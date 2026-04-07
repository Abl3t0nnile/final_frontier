// UI Tint Overlay — liegt als oberste CanvasLayer über dem gesamten Screen.
// Erkennt weiße / fast-weiße Pixel (hoch hell + niedrig saturiert) und färbt
// nur diese ein. Farbige Elemente (Orbits, Planeten) bleiben unverändert.
//
// Setup: CanvasLayer (Layer 127) > ColorRect (FullRect, Anchor=Full) > dieses ShaderMaterial
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

// Farbe, die weißen Bereichen zugewiesen wird
uniform vec4 tint_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);

// Ab welchem "Weißwert" (0–1) beginnt der Tint
// 0.70 = leichte Grautöne werden schon erfasst
// 0.85 = nur fast-weiße Pixel
uniform float whiteness_threshold : hint_range(0.0, 1.0, 0.01) = 0.78;

// Übergangsbreite des smoothstep (schärfer = kleiner Wert)
uniform float edge_softness : hint_range(0.01, 0.3, 0.01) = 0.12;

// Gesamtstärke des Tints (0 = kein Effekt, 1 = voller Tint)
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.72;

// Schützt farbige Pixel: je höher, desto stärker werden saturierte Farben
// vom Tint ausgenommen (0 = kein Schutz, 1 = voller Schutz)
uniform float color_protection : hint_range(0.0, 1.0, 0.01) = 0.90;

void fragment() {
	vec4 src = texture(SCREEN_TEXTURE, SCREEN_UV);
	float r = src.r;
	float g = src.g;
	float b = src.b;

	// --- Weißwert-Berechnung (HSV-Saturation + Brightness) ---
	float cmax = max(r, max(g, b));
	float cmin = min(r, min(g, b));
	float delta = cmax - cmin;

	// HSV-Saturation: 0 = grau/weiß, 1 = volles Chroma
	float saturation = (cmax > 0.001) ? (delta / cmax) : 0.0;

	// Weißwert: hell UND entsättigt
	float whiteness = cmax * (1.0 - saturation);

	// --- Schutz farbiger Pixel ---
	// Saturierte Pixel (Orbits etc.) bekommen einen Gegengewicht-Faktor
	float color_mask = 1.0 - saturation * color_protection;

	// --- Tint-Faktor (smoothstep für weichen Übergang) ---
	float tint_factor = smoothstep(
		whiteness_threshold - edge_softness,
		whiteness_threshold + edge_softness * 0.3,
		whiteness
	) * tint_strength * color_mask;

	// --- Tint anwenden: Multiplikation erhält Helligkeit, ändert Farbton ---
	// weiß × tint_color = tint_color (physikalisch korrekt für helle Flächen)
	vec3 tinted = src.rgb * tint_color.rgb;

	// Mix zwischen Original und getintetem Pixel
	vec3 result = mix(src.rgb, tinted, tint_factor);

	// Alpha 1.0: der Overlay ersetzt den Pixel komplett
	COLOR = vec4(result, 1.0);
}
