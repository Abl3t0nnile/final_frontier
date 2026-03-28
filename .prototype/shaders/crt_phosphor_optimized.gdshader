shader_type canvas_item;

// ColorRect auf CanvasLayer layer=100, anchors=full rect, mouse_filter=ignore
// ColorRect color muss weiß sein (1,1,1,1)

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

uniform float phosphor_scale    : hint_range(2.0, 12.0) = 8.0;  // Höher = bessere Lesbarkeit
uniform float phosphor_gap      : hint_range(0.0, 0.49) = 0.15; // Geringer = bessere Lesbarkeit
uniform float scanline_strength : hint_range(0.0, 1.0)  = 0.3;  // Reduziert für Lesbarkeit
uniform float brightness        : hint_range(0.5, 2.0)  = 1.1;
uniform vec4  tint_color        : source_color           = vec4(0.2, 1.0, 0.3, 1.0);
uniform float tint_strength     : hint_range(0.0, 1.0)  = 0.2;  // Reduziert
uniform float bloom_strength    : hint_range(0.0, 1.0)  = 0.3;
uniform float desaturation      : hint_range(0.0, 1.0)  = 0.1;

void fragment() {
	vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	
	// --- Bloom für Phosphor-Leuchten ---
	if (bloom_strength > 0.0) {
		vec2 pixel_size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec3 bloom = vec3(0.0);
		
		// Weiches Sampling für Bloom
		for(float x = -1.0; x <= 1.0; x += 0.5) {
			for(float y = -1.0; y <= 1.0; y += 0.5) {
				if(x == 0.0 && y == 0.0) continue;
				vec2 offset = vec2(x, y) * pixel_size * 2.0;
				bloom += texture(SCREEN_TEXTURE, SCREEN_UV + offset).rgb;
			}
		}
		bloom /= 24.0; // Normalisieren
		col = mix(col, col + bloom * bloom_strength, bloom_strength);
	}
	
	// --- Phosphor RGB-Triad (optimiert für Lesbarkeit) ---
	vec2 cell  = fract(FRAGCOORD.xy / phosphor_scale);
	float gap  = phosphor_gap * 0.5;
	float r_on = step(gap,       cell.x) * (1.0 - step(0.333 - gap, cell.x));
	float g_on = step(0.333+gap, cell.x) * (1.0 - step(0.666 - gap, cell.x));
	float b_on = step(0.666+gap, cell.x) * (1.0 - step(1.0   - gap, cell.x));
	float v_on = step(gap, cell.y) * (1.0 - step(1.0 - gap, cell.y));
	
	// Maske weicher machen für bessere Lesbarkeit
	vec3 mask = vec3(r_on, g_on, b_on) * v_on;
	mask = mix(mask, vec3(1.0), 0.3); // Immer 30% durchscheinen lassen
	
	// In Lücken gedämpft, in aktiven Subpixeln betont
	col = mix(col * 0.7, col * mask, 0.7);
	
	// --- Scanlines (horizontal, nur in dunklen Bereichen) ---
	float line = fract(FRAGCOORD.x / phosphor_scale); // x statt y für horizontale Linien
	float brightness_factor = dot(col, vec3(0.299, 0.587, 0.114));
	float scanline_mask = 1.0 - smoothstep(0.2, 0.6, brightness_factor);
	float scanline_effect = scanline_strength * scanline_mask * pow(abs(cos(line * 3.14159)), 3.0);
	col *= 1.0 - scanline_effect;
	
	// --- Leichte Desaturierung für authentisches CRT ---
	if (desaturation > 0.0) {
		float gray = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(gray), desaturation);
	}
	
	// --- Helligkeit & Tönung ---
	col *= brightness;
	col = mix(col, col * tint_color.rgb, tint_strength);
	
	// --- Subtiles Rauschen ---
	float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (noise - 0.5) * 0.003;
	
	COLOR = vec4(col, 1.0);
}
