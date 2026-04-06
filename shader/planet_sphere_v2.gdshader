shader_type canvas_item;

uniform sampler2D surface_texture : filter_linear, repeat_enable;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform bool cloud_enabled = false;
uniform float cloud_rotation_offset : hint_range(-3.14159, 3.14159) = 0.0;
uniform float cloud_transparency : hint_range(0.0, 1.0) = 0.5;
uniform float rotation_y : hint_range(-3.14159, 3.14159) = 0.0;
uniform float rotation_x : hint_range(-1.5, 1.5) = 0.0;
uniform float resolution : hint_range(64.0, 4096.0) = 1024.0;
uniform int color_levels : hint_range(2, 32) = 8;
uniform vec3 light_dir = vec3(0.5, -0.3, 0.8);
uniform float ambient : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec2 pixel_uv = floor(UV * resolution) / resolution;
	vec2 centered = pixel_uv * 2.0 - 1.0;
	float dist_sq = dot(centered, centered);

	if (dist_sq > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
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
		vec4 surface_col = texture(surface_texture, tex_uv);

		// Cloud layer (optional)
		vec4 final_col = surface_col;
		if (cloud_enabled) {
			vec2 cloud_uv = vec2(tex_uv.x + cloud_rotation_offset / (2.0 * PI), tex_uv.y);
			vec4 cloud_col = texture(cloud_texture, cloud_uv);
			final_col = mix(surface_col, cloud_col, cloud_col.a * cloud_transparency);
		}

		// Lighting
		vec3 light_n = normalize(light_dir);
		float lighting = max(ambient, dot(normal, light_n));
		final_col.rgb *= lighting;

		// Quantize to color levels (posterize)
		float levels = float(color_levels - 1);
		final_col.rgb = floor(final_col.rgb * levels + 0.5) / levels;

		COLOR = final_col;
	}
}
