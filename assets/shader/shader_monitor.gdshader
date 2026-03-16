shader_type canvas_item;

// ── Pixelation ──────────────────────────────────────────────────────────────
uniform float pixel_size : hint_range(1.0, 32.0, 1.0) = 4.0;

// ── Scan Lines ──────────────────────────────────────────────────────────────
uniform bool  scanlines_enabled = true;
uniform float scanline_thickness : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_speed : hint_range(0.0, 20.0) = 3.0;
uniform float scanline_scroll_strength : hint_range(0.0, 1.0) = 0.15;

// ── Color Tint ──────────────────────────────────────────────────────────────
uniform bool  tint_enabled = false;
uniform vec4  tint_color : source_color = vec4(0.0, 1.0, 0.4, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;

// ── Vignette ────────────────────────────────────────────────────────────────
uniform bool  vignette_enabled = true;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.6;

// ── Screen Curvature ────────────────────────────────────────────────────────
uniform bool  curvature_enabled = true;
uniform float curvature_amount : hint_range(0.0, 0.2) = 0.06;

// ── Flicker ─────────────────────────────────────────────────────────────────
uniform bool  flicker_enabled = true;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.02;

// ── Chromatic Aberration ────────────────────────────────────────────────────
uniform bool  aberration_enabled = true;
uniform float aberration_amount : hint_range(0.0, 4.0) = 1.2;

// ── Screen Texture ──────────────────────────────────────────────────────────
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;


vec2 curve_uv(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	centered *= 1.0 + curvature_amount * dot(centered, centered);
	return centered * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	bool out_of_bounds = false;

	// ── Curvature ───────────────────────────────────────────────────────
	if (curvature_enabled) {
		uv = curve_uv(uv);
		out_of_bounds = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	}

	if (out_of_bounds) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// ── Pixelation ──────────────────────────────────────────────────
		vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;
		vec2 pixel_uv = floor(uv * screen_res / pixel_size) * pixel_size / screen_res;

		// ── Chromatic Aberration ────────────────────────────────────────
		vec3 col;
		if (aberration_enabled) {
			vec2 offset = vec2(aberration_amount / screen_res.x, 0.0);
			col.r = texture(screen_texture, pixel_uv + offset).r;
			col.g = texture(screen_texture, pixel_uv).g;
			col.b = texture(screen_texture, pixel_uv - offset).b;
		} else {
			col = texture(screen_texture, pixel_uv).rgb;
		}

		// ── Flicker ─────────────────────────────────────────────────────
		if (flicker_enabled) {
			float flicker = 1.0 - flicker_strength * sin(TIME * 60.0);
			col *= flicker;
		}

		// ── Scan Lines ──────────────────────────────────────────────────
		if (scanlines_enabled) {
			float line = mod(floor(uv.y * screen_res.y / pixel_size), 2.0);
			float scanline_mask = mix(1.0, 1.0 - scanline_opacity, step(scanline_thickness, 1.0 - line));

			float scroll_y = fract(uv.y - TIME * scanline_speed * 0.01);
			float scroll_band = smoothstep(0.0, 0.05, scroll_y) * smoothstep(0.15, 0.05, scroll_y);
			float scroll_effect = 1.0 + scroll_band * scanline_scroll_strength;

			col *= scanline_mask * scroll_effect;
		}

		// ── Color Tint ──────────────────────────────────────────────────
		if (tint_enabled) {
			float luminance = dot(col, vec3(0.299, 0.587, 0.114));
			vec3 tinted = luminance * tint_color.rgb;
			col = mix(col, tinted, tint_strength);
		}

		// ── Vignette ────────────────────────────────────────────────────
		if (vignette_enabled) {
			vec2 vig_uv = uv * (1.0 - uv);
			float vig = vig_uv.x * vig_uv.y * 16.0;
			vig = pow(vig, vignette_strength);
			col *= vig;
		}

		COLOR = vec4(col, 1.0);
	}
}
