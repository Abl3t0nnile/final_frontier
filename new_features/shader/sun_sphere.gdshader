shader_type canvas_item;

uniform sampler2D surface_texture : filter_nearest, repeat_enable;
uniform float rotation_y : hint_range(-3.14159, 3.14159) = 0.0;
uniform float rotation_x : hint_range(-1.5, 1.5) = 0.0;
uniform int bayer_scale : hint_range(1, 16) = 4;
uniform float black_floor : hint_range(0.0, 0.5) = 0.1;
uniform float white_ceil : hint_range(0.5, 1.0) = 0.6;
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform bool outline_enabled = true;

// Corona settings - sphere_scale defines how much of the rect the sun uses (rest is for corona)
// e.g. sphere_scale = 0.8 means sun takes 80% of rect, leaving 20% for corona
uniform float sphere_scale : hint_range(0.5, 1.0) = 0.8;
uniform float corona_width : hint_range(0.0, 0.5) = 0.15;
uniform float corona_density : hint_range(0.0, 1.0) = 0.5;
uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform float flicker_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;

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

// Simple noise for corona variation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Scale UV so sphere fits within the rect with room for corona
	vec2 centered = (UV * 2.0 - 1.0) / sphere_scale;
	float dist_sq = dot(centered, centered);
	float dist = sqrt(dist_sq);

	float outline_inner = 1.0 - outline_width * 2.0;
	float corona_outer = 1.0 + corona_width;

	// Corona region (outside the sun sphere)
	if (dist > 1.0 && dist < corona_outer) {
		float corona_falloff = 1.0 - (dist - 1.0) / corona_width;
		corona_falloff = corona_falloff * corona_falloff;

		// Add noise-based variation for organic corona look
		float angle = atan(centered.y, centered.x);
		float corona_noise = noise(vec2(angle * 3.0, time * 0.5)) * 0.5 + 0.5;
		corona_falloff *= mix(0.5, 1.0, corona_noise);

		// Dither the corona
		float threshold = bayer_threshold(ivec2(FRAGCOORD.xy));
		float corona_value = corona_falloff * corona_density;

		// Flicker effect
		float flicker = sin(time * flicker_speed) * flicker_intensity;
		corona_value += flicker;

		if (corona_value > threshold) {
			COLOR = vec4(1.0, 1.0, 1.0, 1.0);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
	// Outside corona
	else if (dist >= corona_outer) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
	// Outline
	else if (outline_enabled && dist_sq > outline_inner && dist <= 1.0) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	}
	// Sun surface (always lit, no external lighting)
	else {
		float z = sqrt(1.0 - dist_sq);
		vec3 pos = vec3(centered.x, -centered.y, z);

		// Undo pitch
		float cx = cos(-rotation_x);
		float sx = sin(-rotation_x);
		pos = vec3(pos.x, pos.y * cx - pos.z * sx, pos.y * sx + pos.z * cx);

		// Undo yaw
		float cy = cos(-rotation_y);
		float sy = sin(-rotation_y);
		pos = vec3(pos.x * cy + pos.z * sy, pos.y, -pos.x * sy + pos.z * cy);

		// Texture lookup
		float lat = asin(clamp(pos.y, -1.0, 1.0));
		float lon = atan(pos.x, pos.z);
		vec2 tex_uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
		float tex_val = texture(surface_texture, tex_uv).r;

		// Add subtle flicker to surface brightness
		float surface_flicker = sin(time * flicker_speed * 1.3 + 1.0) * flicker_intensity * 0.5;
		tex_val += surface_flicker;

		// Slight limb brightening (inverse of darkening - sun glows more at edges)
		float limb = 1.0 - z;
		tex_val = mix(tex_val, tex_val + 0.15, limb * limb);

		// Clamp to solid black/white, dither the middle band
		float pixel_out;
		if (tex_val <= black_floor) {
			pixel_out = 0.0;
		} else if (tex_val >= white_ceil) {
			pixel_out = 1.0;
		} else {
			float remapped = (tex_val - black_floor) / (white_ceil - black_floor);
			float threshold = bayer_threshold(ivec2(FRAGCOORD.xy));
			pixel_out = step(threshold, remapped);
		}

		COLOR = vec4(vec3(pixel_out), 1.0);
	}
}
