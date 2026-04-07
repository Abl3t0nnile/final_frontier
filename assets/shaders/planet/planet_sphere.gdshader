shader_type canvas_item;

uniform sampler2D surface_texture : filter_nearest, repeat_enable;
uniform sampler2D cloud_texture : filter_nearest, repeat_enable;
uniform bool cloud_enabled = false;
uniform float cloud_rotation_offset : hint_range(-3.14159, 3.14159) = 0.0;
uniform float cloud_transparency : hint_range(0.0, 1.0) = 1.0;
uniform float rotation_y : hint_range(-3.14159, 3.14159) = 0.0;
uniform float rotation_x : hint_range(-1.5, 1.5) = 0.0;
uniform int bayer_scale : hint_range(1, 16) = 4;
uniform float black_floor : hint_range(0.0, 0.5) = 0.15;
uniform float white_ceil : hint_range(0.5, 1.0) = 0.8;
uniform vec3 light_dir = vec3(0.5, -0.3, 0.8);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform bool outline_enabled = true;

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
		float lat = asin(clamp(pos.y, -1.0, 1.0));
		float lon = atan(pos.x, pos.z);
		vec2 tex_uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
		float tex_val = texture(surface_texture, tex_uv).r;

		// Cloud layer (optional)
		if (cloud_enabled) {
			vec2 cloud_uv = vec2(tex_uv.x + cloud_rotation_offset / (2.0 * PI), tex_uv.y);
			float cloud_val = texture(cloud_texture, cloud_uv).r;
			tex_val = mix(tex_val, max(tex_val, cloud_val), cloud_transparency);
		}

		// Lighting (against screen-space normal, light is fixed in view space)
		vec3 light_n = normalize(light_dir);
		float lighting = max(0.03, dot(normal, light_n));

		// Combine
		float combined = tex_val * lighting;

		// Clamp to solid black/white, dither the middle band
		float pixel_out;
		if (combined <= black_floor) {
			pixel_out = 0.0;
		} else if (combined >= white_ceil) {
			pixel_out = 1.0;
		} else {
			float remapped = (combined - black_floor) / (white_ceil - black_floor);
			float threshold = bayer_threshold(ivec2(FRAGCOORD.xy));
			pixel_out = step(threshold, remapped);
		}

		COLOR = vec4(vec3(pixel_out), 1.0);
	}
}