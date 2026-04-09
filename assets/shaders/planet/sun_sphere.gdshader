shader_type canvas_item;

uniform sampler2D surface_texture : filter_nearest, repeat_enable;
uniform float rotation_y       : hint_range(-3.14159, 3.14159) = 0.0;
uniform float rotation_x       : hint_range(-1.5, 1.5) = 0.0;
uniform int   bayer_scale      : hint_range(1, 16) = 4;
uniform float black_floor      : hint_range(0.0, 0.5) = 0.1;
uniform float color_saturation : hint_range(0.0, 2.0) = 1.0;
uniform int   color_levels     : hint_range(2, 16) = 4;
// Anteil des Rects den die Kugel einnimmt — Rest ist Halo-Bereich
uniform float sphere_scale     : hint_range(0.5, 1.0) = 0.8;
// Verstärkt die Helligkeit → lässt den Engine-Glow stärker anspringen
uniform float glow_intensity   : hint_range(1.0, 4.0) = 1.5;
// Wie weit der Halo über die Kugel hinausreicht (relativ zur Kugel)
uniform float halo_width       : hint_range(0.0, 0.5) = 0.12;

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

vec3 dither_quantize(vec3 color, float threshold, int levels) {
	float n = float(levels) - 1.0;
	vec3 scaled    = clamp(color, 0.0, 1.0) * n;
	vec3 lower     = floor(scaled) / n;
	vec3 upper     = min(ceil(scaled) / n, vec3(1.0));
	vec3 frac_part = fract(scaled);
	return mix(lower, upper, step(vec3(threshold), frac_part));
}

// Rotiert einen Richtungsvektor und liefert die Textur-UV am Kugelrand (z=0)
vec2 rim_uv(vec2 dir) {
	vec3 pos = vec3(dir.x, -dir.y, 0.0);
	float cx = cos(-rotation_x); float sx = sin(-rotation_x);
	pos = vec3(pos.x, pos.y * cx - pos.z * sx, pos.y * sx + pos.z * cx);
	float cy = cos(-rotation_y); float sy = sin(-rotation_y);
	pos = vec3(pos.x * cy + pos.z * sy, pos.y, -pos.x * sy + pos.z * cy);
	float lat = asin(clamp(pos.y, -1.0, 1.0));
	float lon = atan(pos.x, pos.z);
	return vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
}

void fragment() {
	// Koordinaten skaliert, sodass Kugel nur sphere_scale des Rects belegt
	vec2 centered = (UV * 2.0 - 1.0) / sphere_scale;
	float dist = length(centered);

	float halo_outer = 1.0 + halo_width;

	if (dist > halo_outer) {
		COLOR = vec4(0.0);

	} else if (dist > 1.0) {
		// Halo-Zone: Farbe vom Kugelrand in dieser Richtung samplen
		vec2 dir = normalize(centered);
		vec2 uv  = rim_uv(dir);
		vec3 rim_color = texture(surface_texture, uv).rgb;

		// Saturation auf Randfarbe anwenden
		float lum = dot(rim_color, vec3(0.299, 0.587, 0.114));
		rim_color = mix(vec3(lum), rim_color, color_saturation);

		// Weicher quadratischer Abfall
		float t       = (dist - 1.0) / halo_width;
		float falloff = (1.0 - t) * (1.0 - t);

		COLOR = vec4(rim_color * glow_intensity, falloff);

	} else {
		// Sphere-Oberfläche
		float dist_sq = dist * dist;
		float z = sqrt(max(0.0, 1.0 - dist_sq));
		vec3 pos = vec3(centered.x, -centered.y, z);

		float cx = cos(-rotation_x); float sx = sin(-rotation_x);
		pos = vec3(pos.x, pos.y * cx - pos.z * sx, pos.y * sx + pos.z * cx);
		float cy = cos(-rotation_y); float sy = sin(-rotation_y);
		pos = vec3(pos.x * cy + pos.z * sy, pos.y, -pos.x * sy + pos.z * cy);

		float lat   = asin(clamp(pos.y, -1.0, 1.0));
		float lon   = atan(pos.x, pos.z);
		vec2 tex_uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
		vec4 tex_color = texture(surface_texture, tex_uv);

		float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		tex_color.rgb = mix(vec3(lum), tex_color.rgb, color_saturation);

		float threshold = bayer_threshold(ivec2(FRAGCOORD.xy));
		vec3 final_color;
		if (lum <= black_floor) {
			final_color = vec3(0.0);
		} else {
			final_color = dither_quantize(tex_color.rgb, threshold, color_levels);
		}

		COLOR = vec4(final_color * glow_intensity, 1.0);
	}
}
