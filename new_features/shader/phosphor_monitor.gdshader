shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 phosphor_color : source_color = vec3(1.0, 0.9, 0.3);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.7;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float glow_radius : hint_range(1.0, 8.0) = 3.0;
uniform float chromatic_strength : hint_range(0.0, 10.0) = 2.0;
uniform float brightness : hint_range(0.5, 2.0) = 1.2;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_count : hint_range(100.0, 600.0) = 300.0;

void fragment() {
	vec2 uv = UV;
	vec2 px = vec2(1.0) / vec2(textureSize(screen_texture, 0));
	
	// Chromatic aberration - offset RGB channels from center
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	float dist = length(dir);
	vec2 offset = dir * dist * chromatic_strength * px * 10.0;
	
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	vec3 col = vec3(r, g, b);
	
	// Phosphor glow (blur around bright areas)
	vec3 glow = vec3(0.0);
	float samples = 0.0;
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			glow += texture(screen_texture, uv + vec2(x, y) * px * glow_radius).rgb;
			samples += 1.0;
		}
	}
	glow /= samples;
	
	// Apply phosphor tint to base color
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(col, phosphor_color * luma, tint_strength);
	
	// Add glow with phosphor color
	float glow_luma = dot(glow, vec3(0.299, 0.587, 0.114));
	tinted += phosphor_color * glow_luma * glow_strength * 0.3;
	
	// Scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	tinted *= 1.0 - scanline_strength * scanline;
	
	// Apply brightness
	tinted *= brightness;
	
	COLOR = vec4(tinted, 1.0);
}
