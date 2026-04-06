// zone_ring.gdshader
// Zeichnet einen gefüllten Kreis oder Hohlring mit Anti-Aliasing.
// Wird von ZoneRenderer und (mit fill_color.a=0) von OrbitRenderer für kreisförmige Orbits verwendet.
//
// Koordinatensystem:
//   UV 0..1 über den QuadMesh. Mittelpunkt bei UV=(0.5, 0.5).
//   half_size_px gibt die halbe Quad-Breite in px an, sodass UV 0..1 → -half_size..+half_size px.
//
// Für Kreis:  r_inner_px = 0
// Für Ring:   r_inner_px > 0

shader_type canvas_item;

uniform float r_outer_px   : hint_range(0.0, 1000000.0) = 100.0;
uniform float r_inner_px   : hint_range(0.0, 1000000.0) = 0.0;
uniform float half_size_px                               = 102.0;
uniform vec4  fill_color   : source_color                = vec4(0.5, 0.5, 1.0, 0.1);
uniform vec4  border_color : source_color                = vec4(0.5, 0.5, 1.0, 0.4);
uniform float border_px                                  = 1.0;

void fragment() {
	// Lokale Pixel-Koordinaten, zentriert
	vec2  local = (UV - 0.5) * half_size_px * 2.0;
	float d     = length(local);
	float aa    = 1.5;

	// Füllfläche
	float outer = smoothstep(r_outer_px + aa, r_outer_px - aa, d);
	float inner = (r_inner_px > 0.5)
		? smoothstep(r_inner_px - aa, r_inner_px + aa, d)
		: 1.0;
	float fill = outer * inner;

	// Ränder (außen + innen)
	float bo = outer * (1.0 - smoothstep(
		r_outer_px - border_px - aa,
		r_outer_px - border_px + aa, d));
	float bi = (r_inner_px > 0.5)
		? smoothstep(r_inner_px + border_px + aa,
		             r_inner_px + border_px - aa, d) * inner
		: 0.0;
	float border = clamp(max(bo, bi), 0.0, 1.0);

	float fill_a   = fill   * fill_color.a;
	float border_a = border * border_color.a;
	float total_a  = max(fill_a, border_a);

	vec3 col = mix(fill_color.rgb, border_color.rgb,
	               border_a / max(total_a, 0.001));
	COLOR = vec4(col, total_a);
}
