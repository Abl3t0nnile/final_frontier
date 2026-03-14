shader_type canvas_item;
render_mode unshaded;

// Bildschirmauflösung aus dem Control/ColorRect ziehen
uniform vec2 resolution = vec2(1920.0, 1080.0);

// Sternendichte: kleiner = mehr Sterne
uniform float cell_size : hint_range(20.0, 300.0) = 120.0;

// Wahrscheinlichkeit, dass in einer Zelle überhaupt ein Stern entsteht
uniform float star_probability : hint_range(0.0, 1.0) = 0.10;

// Grundhelligkeit des Hintergrunds
uniform float background_level : hint_range(0.0, 0.1) = 0.01;

// Helligkeit der Sterne
uniform float star_brightness : hint_range(0.0, 2.0) = 0.85;

// Minimale / maximale Sterngröße in Pixeln
uniform float min_star_radius : hint_range(0.2, 3.0) = 0.5;
uniform float max_star_radius : hint_range(0.2, 4.0) = 1.4;

// Sehr leichtes Twinkling
uniform float twinkle_strength : hint_range(0.0, 0.5) = 0.08;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 0.6;

// Seed, damit du verschiedene Sternenfelder erzeugen kannst
uniform float seed = 1.0;


// Einfache Hash-Funktion
float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32 + seed);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash12(p);
	float m = hash12(p + 17.23);
	return vec2(n, m);
}

void fragment() {
	vec2 uv = UV;
	vec2 pixel_pos = uv * resolution;

	// Hintergrund fast schwarz
	float brightness = background_level;

	// Zellenraster für seltene Sterne
	vec2 cell = floor(pixel_pos / cell_size);
	vec2 local = fract(pixel_pos / cell_size);

	// Prüfen, ob diese Zelle einen Stern bekommt
	float star_roll = hash12(cell + 3.17);
	if (star_roll < star_probability) {
		// Zufällige Position des Sterns innerhalb der Zelle
		vec2 star_pos = hash22(cell + 8.91);

		// Zufällige Größe
		float radius_rand = hash12(cell + 14.73);
		float star_radius_px = mix(min_star_radius, max_star_radius, radius_rand);

		// Umrechnung in lokalen Zellenraum
		float cell_px = cell_size;
		float star_radius = star_radius_px / cell_px;

		// Distanz zum Stern
		float d = distance(local, star_pos);

		// Scharfer, kleiner Stern ohne fetten Glow
		float star = smoothstep(star_radius, star_radius * 0.35, d);

		// Kleine Helligkeitsvariation
		float intensity = mix(0.55, 1.0, hash12(cell + 27.41));

		// Sehr dezentes Twinkling
		float twinkle_phase = hash12(cell + 91.7) * 6.2831853;
		float twinkle = 1.0 + sin(TIME * twinkle_speed + twinkle_phase) * twinkle_strength;

		brightness += star * intensity * twinkle * star_brightness;
	}

	// Monochrom / neutral weißlich
	COLOR = vec4(vec3(brightness), 1.0);
}