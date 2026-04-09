shader_type canvas_item;

uniform sampler2D surface_texture : filter_nearest, repeat_enable;
uniform sampler2D cloud_texture   : filter_nearest, repeat_enable;
uniform bool  cloud_enabled           = false;
uniform float cloud_rotation_offset   : hint_range(-3.14159, 3.14159) = 0.0;
uniform float cloud_transparency      : hint_range(0.0, 1.0) = 1.0;
uniform float rotation_y              : hint_range(-3.14159, 3.14159) = 0.0;
uniform float rotation_x              : hint_range(-1.5, 1.5) = 0.0;
uniform int   bayer_scale             : hint_range(1, 16) = 4;
uniform float black_floor             : hint_range(0.0, 0.5) = 0.15;
uniform vec3  light_dir               = vec3(0.5, -0.3, 0.8);
uniform float outline_width           : hint_range(0.0, 0.1) = 0.02;
uniform bool  outline_enabled         = true;
uniform vec3  shadow_color            = vec3(0.0, 0.0, 0.0);
uniform float color_saturation        : hint_range(0.0, 2.0) = 1.0;
// Anzahl der Quantisierungsstufen pro Farbkanal.
// 2 = 8 mögliche Farben (sehr aggressiv), 4 = 64 Farben (empfohlen), 8 = 512 Farben (fein)
uniform int   color_levels            : hint_range(2, 16) = 4;

const mat4 BAYER_ROW_0_3 = mat4(
	vec4( 0.0, 48.0, 12.0, 60.0),
	vec4(32.0, 16.0, 44.0, 28.0),
	vec4( 8.0, 56.0,  4.0, 52.0),
	vec4(40.0, 24.0, 36.0, 20.0)
);
const mat4 BAYER_ROW_4_7 = mat4(
	vec4( 2.0, 50.0, 14.0, 62.0),
	vec4(34.0, 18.0, 46.0, 30.0),
	vec4(10.0, 58.0,  6.0, 54.0),
	vec4(42.0, 26.0, 38.0, 22.0)
);

float bayer_threshold(ivec2 pixel) {
	int x = (pixel.x / bayer_scale) % 8;
	int y = (pixel.y / bayer_scale) % 8;
	float val;
	if (x < 4) {
		if (y < 4) { val = BAYER_ROW_0_3[y][x]; }
		else        { val = BAYER_ROW_4_7[y - 4][x]; }
	} else {
		if (y < 4) { val = BAYER_ROW_0_3[y][x - 4]; }
		else        { val = BAYER_ROW_4_7[y - 4][x - 4]; }
	}
	return val / 64.0;
}

// Quantisiert einen Wert auf n Stufen mit Bayer-Dithering.
// Alle drei Kanäle nutzen denselben Threshold → Hue bleibt erhalten.
vec3 dither_quantize(vec3 color, float threshold, int levels) {
	float n = float(levels) - 1.0;
	vec3 scaled     = clamp(color, 0.0, 1.0) * n;
	vec3 lower      = floor(scaled) / n;
	vec3 upper      = min(ceil(scaled) / n, vec3(1.0));
	vec3 frac_part  = fract(scaled);
	// step(threshold, frac) → 1 wenn frac >= threshold (aufrunden), sonst 0 (abrunden)
	return mix(lower, upper, step(vec3(threshold), frac_part));
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist_sq = dot(centered, centered);

	float outline_inner = 1.0 - outline_width * 2.0;
	if (dist_sq > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else if (outline_enabled && dist_sq > outline_inner) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	} else {
		float z = sqrt(1.0 - dist_sq);
		vec3 pos = vec3(centered.x, -centered.y, z);
		vec3 normal = pos;

		// Undo pitch
		float cx = cos(-rotation_x);
		float sx = sin(-rotation_x);
		pos = vec3(pos.x, pos.y * cx - pos.z * sx, pos.y * sx + pos.z * cx);

		// Undo yaw
		float cy = cos(-rotation_y);
		float sy = sin(-rotation_y);
		pos = vec3(pos.x * cy + pos.z * sy, pos.y, -pos.x * sy + pos.z * cy);

		// Texture lookup
		float lat   = asin(clamp(pos.y, -1.0, 1.0));
		float lon   = atan(pos.x, pos.z);
		vec2 tex_uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
		vec4 tex_color = texture(surface_texture, tex_uv);

		// Cloud layer (optional)
		if (cloud_enabled) {
			vec2 cloud_uv  = vec2(tex_uv.x + cloud_rotation_offset / (2.0 * PI), tex_uv.y);
			vec4 cloud_col = texture(cloud_texture, cloud_uv);
			float cloud_lum = max(max(cloud_col.r, cloud_col.g), cloud_col.b);
			tex_color.rgb  = mix(tex_color.rgb, max(tex_color.rgb, cloud_col.rgb), cloud_transparency * cloud_lum);
		}

		// Saturation
		float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		tex_color.rgb = mix(vec3(lum), tex_color.rgb, color_saturation);

		// Lighting
		vec3  light_n = normalize(light_dir);
		float lighting = max(0.0, dot(normal, light_n));

		float threshold = bayer_threshold(ivec2(FRAGCOORD.xy));
		vec3 final_color;
		if (lighting <= black_floor) {
			// Schattenseite → direkt shadow_color
			final_color = shadow_color;
		} else {
			// Licht auf Texturfarbe anwenden und quantisieren
			vec3 lit_color = tex_color.rgb * lighting;
			final_color = dither_quantize(lit_color, threshold, color_levels);
		}

		COLOR = vec4(final_color, 1.0);
	}
}
