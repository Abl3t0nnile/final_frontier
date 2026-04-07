shader_type canvas_item;

// ── Layer 1: Ferne Sterne (viele, klein, langsamer Parallax) ─────────────────
uniform vec2  scroll_offset_far    = vec2(0.0);
uniform float density_far          : hint_range(0.0, 1.0) = 0.55;
uniform float size_min_far         : hint_range(0.2,  8.0) = 0.4;
uniform float size_max_far         : hint_range(0.5, 20.0) = 1.8;
uniform float size_bias_far        : hint_range(0.5,  4.0) = 2.5;
uniform float twinkle_speed_far    : hint_range(0.0, 10.0) = 0.8;
uniform float twinkle_amount_far   : hint_range(0.0,  1.0) = 0.20;
uniform float twinkle_variation_far: hint_range(0.0,  1.0) = 0.5;
uniform float brightness_far       : hint_range(0.0,  2.0) = 0.75;
uniform float seed_far             : hint_range(0.0, 999.0) = 0.0;

// ── Layer 2: Nahe Sterne (wenige, groß, schnellerer Parallax) ────────────────
uniform vec2  scroll_offset_near    = vec2(0.0);
uniform float density_near          : hint_range(0.0, 1.0) = 0.20;
uniform float size_min_near         : hint_range(0.2,  8.0) = 1.5;
uniform float size_max_near         : hint_range(0.5, 20.0) = 4.0;
uniform float size_bias_near        : hint_range(0.5,  4.0) = 2.0;
uniform float twinkle_speed_near    : hint_range(0.0, 10.0) = 1.8;
uniform float twinkle_amount_near   : hint_range(0.0,  1.0) = 0.45;
uniform float twinkle_variation_near: hint_range(0.0,  1.0) = 0.7;
uniform float brightness_near       : hint_range(0.0,  2.0) = 1.0;
uniform float seed_near             : hint_range(0.0, 999.0) = 42.0;

// ── Gemeinsame Parameter ─────────────────────────────────────────────────────
uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ── Hash-Hilfsfunktionen ─────────────────────────────────────────────────────

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// ── Sterne einer Ebene rendern ───────────────────────────────────────────────
// Gibt (rgb * brightness, brightness) als vec4 zurück.

vec4 render_layer(
	vec2  pixel_pos,
	float density,
	float size_min,
	float size_max,
	float size_bias,
	float twinkle_speed,
	float twinkle_amount,
	float twinkle_variation,
	float layer_brightness,
	float seed
) {
	float cell_size = mix(180.0, 28.0, density);
	vec2  cell_id   = floor(pixel_pos / cell_size);

	float best_b   = 0.0;
	vec3  best_col = star_color.rgb;

	for (int ix = -1; ix <= 1; ix++) {
		for (int iy = -1; iy <= 1; iy++) {
			vec2 ncell = cell_id + vec2(float(ix), float(iy));

			vec2  h  = hash22(ncell + seed * 13.71);
			float h1 = hash21(ncell * 1.37 + seed * 5.13);
			float h2 = hash21(ncell * 2.71 + seed * 3.37);

			vec2  star_px = (ncell + 0.1 + h * 0.8) * cell_size;
			float dist    = length(pixel_pos - star_px);

			float star_r = mix(size_min, size_max, pow(h1, size_bias));
			float glow_r = star_r * 2.5;
			if (dist > glow_r) continue;

			float base_freq = 0.5 + h2 * 2.0 * twinkle_variation + (1.0 - twinkle_variation) * 1.0;
			float phase     = h2 * TAU;
			float twinkle   = 1.0 - twinkle_amount * (0.5 + 0.5 * sin(TIME * twinkle_speed * base_freq + phase));

			float core  = 1.0 - smoothstep(0.0, star_r, dist);
			float glow  = pow(max(0.0, 1.0 - dist / glow_r), 3.0) * 0.45;
			float star_b = (core + glow) * twinkle * layer_brightness;

			if (star_b > best_b) {
				best_b = star_b;

				float ct    = hash21(ncell * 3.13 + seed * 2.31);
				vec3 cool   = vec3(0.80, 0.88, 1.00);
				vec3 warm   = vec3(1.00, 0.95, 0.82);
				vec3 tint   = mix(cool, warm, smoothstep(0.0, 1.0, ct));
				tint        = mix(tint, vec3(1.0), smoothstep(0.3, 0.7, ct));
				best_col    = star_color.rgb * tint;
			}
		}
	}

	return vec4(best_col, best_b);
}

// ── Fragment ─────────────────────────────────────────────────────────────────

void fragment() {
	vec2 screen_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 uv          = SCREEN_UV * screen_size;

	vec4 far  = render_layer(uv + scroll_offset_far,
		density_far,  size_min_far,  size_max_far,  size_bias_far,
		twinkle_speed_far,  twinkle_amount_far,  twinkle_variation_far,
		brightness_far,  seed_far);

	vec4 near = render_layer(uv + scroll_offset_near,
		density_near, size_min_near, size_max_near, size_bias_near,
		twinkle_speed_near, twinkle_amount_near, twinkle_variation_near,
		brightness_near, seed_near);

	// Additive Überlagerung: near-Sterne leuchten über far-Sternen
	vec3  rgb   = far.rgb * far.a + near.rgb * near.a;
	float alpha = clamp(far.a + near.a, 0.0, 1.0);

	COLOR = vec4(rgb, alpha * star_color.a);
}
