shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;
uniform float lod : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec2 blur_offset = pixel_size * blur_amount;

	// 9-tap Gaussian blur
	vec4 color = vec4(0.0);

	// Center
	color += textureLod(screen_texture, SCREEN_UV, lod) * 0.147761;

	// Cardinal directions
	color += textureLod(screen_texture, SCREEN_UV + vec2(blur_offset.x, 0.0), lod) * 0.118318;
	color += textureLod(screen_texture, SCREEN_UV + vec2(-blur_offset.x, 0.0), lod) * 0.118318;
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, blur_offset.y), lod) * 0.118318;
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, -blur_offset.y), lod) * 0.118318;

	// Diagonals
	color += textureLod(screen_texture, SCREEN_UV + vec2(blur_offset.x, blur_offset.y), lod) * 0.094742;
	color += textureLod(screen_texture, SCREEN_UV + vec2(-blur_offset.x, blur_offset.y), lod) * 0.094742;
	color += textureLod(screen_texture, SCREEN_UV + vec2(blur_offset.x, -blur_offset.y), lod) * 0.094742;
	color += textureLod(screen_texture, SCREEN_UV + vec2(-blur_offset.x, -blur_offset.y), lod) * 0.094742;

	COLOR = color;
}
