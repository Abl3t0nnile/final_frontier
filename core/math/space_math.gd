## SpaceMath
## Zentrale Math-Bibliothek für präzise Berechnungen
## Erweitert: RefCounted

class_name SpaceMath
extends RefCounted

const KEPLER_MAX_ITERATIONS := 12
const KEPLER_TOLERANCE := 0.000001

const AU_KM: float        = 149_597_870.7   ## 1 Astronomische Einheit in km
const G_KM3_KG_S2: float  = 6.674e-20       ## Gravitationskonstante in km³/(kg·s²)


## AU-Konvertierungen (skalare Distanzen)
static func km_to_au(km: float) -> float:
	return km / AU_KM


static func au_to_km(au: float) -> float:
	return au * AU_KM


## AU-Konvertierungen (Vektoren)
static func km_to_au_vec(pos_km: Vector2) -> Vector2:
	return pos_km / AU_KM


static func au_to_km_vec(pos_au: Vector2) -> Vector2:
	return pos_au * AU_KM


## px ↔ AU (kombiniert km_to_px und km_to_au)
static func px_to_au(pos_px: Vector2, km_per_px: float) -> Vector2:
	return km_to_au_vec(px_to_km(pos_px, km_per_px))


static func au_to_px(pos_au: Vector2, km_per_px: float) -> Vector2:
	return km_to_px(au_to_km_vec(pos_au), km_per_px)


## Formatiert einen km-Wert als wissenschaftliche Notation: "2.375 e 9 km"
static func format_km_scientific(km: float) -> String:
	if is_zero_approx(km):
		return "0 km"
	var magnitude := floori(log(absf(km)) / log(10.0))
	var mantissa := km / pow(10.0, float(magnitude))
	return "%.3f e %d km" % [mantissa, magnitude]


## Koordinatentransformation
static func km_to_px(pos_km: Vector2, km_per_px: float) -> Vector2:
	"""Konvertiert km zu Pixel-Koordinaten"""
	return Vector2(pos_km.x / km_per_px, pos_km.y / km_per_px)


static func px_to_km(pos_px: Vector2, km_per_px: float) -> Vector2:
	"""Konvertiert Pixel zu km-Koordinaten"""
	return Vector2(pos_px.x * km_per_px, pos_px.y * km_per_px)


static func km_to_px_precise(pos_km: Vector2, km_per_px: float) -> Vector2:
	"""Präzise Konvertierung für Wobble-Fix"""
	return km_to_px(pos_km, km_per_px)


static func px_to_km_precise(pos_px: Vector2, km_per_px: float) -> Vector2:
	"""Präzise Konvertierung für Wobble-Fix"""
	return px_to_km(pos_px, km_per_px)


## Kepler-Berechnungen
static func solve_kepler(eccentricity: float, mean_anomaly: float, max_iterations: int = KEPLER_MAX_ITERATIONS) -> float:
	"""Löst Keplersche Gleichung: E - e*sin(E) = M
	   Returns: Exzentrische Anomalie E"""
	var M := wrap_angle(mean_anomaly)
	var e := clampf(eccentricity, 0.0, 0.999999)

	# Startwert für Newton-Raphson
	var E := M
	if e > 0.8:
		E = PI

	# Newton-Raphson Iteration
	for i in max_iterations:
		var f := E - e * sin(E) - M
		var fp := 1.0 - e * cos(E)

		if absf(fp) < KEPLER_TOLERANCE:
			break

		var delta := f / fp
		E -= delta

		if absf(delta) < KEPLER_TOLERANCE:
			break

	return E


static func kepler_to_cartesian(semi_major_axis: float, eccentricity: float, eccentric_anomaly: float, argument_of_periapsis: float) -> Vector2:
	"""Konvertiert Orbit-Elemente zu kartesischen Koordinaten relativ zum Fokus"""
	var a := semi_major_axis
	var e := clampf(eccentricity, 0.0, 0.999999)
	var E := eccentric_anomaly
	var w := argument_of_periapsis

	# Berechne Position im Orbit-Frame
	var b := a * sqrt(1.0 - e * e)  # Semi-minor axis
	var x_orbit := a * (cos(E) - e)
	var y_orbit := b * sin(E)

	# Rotiere um Argument des Periapsis
	var cos_w := cos(w)
	var sin_w := sin(w)
	var x_rot := x_orbit * cos_w - y_orbit * sin_w
	var y_rot := x_orbit * sin_w + y_orbit * cos_w

	return Vector2(x_rot, y_rot)


static func get_kepler_period(semi_major_axis_km: float, parent_mu_km3_s2: float) -> float:
	"""Berechnet Umlaufzeit aus Kepler's 3. Gesetz"""
	if semi_major_axis_km <= 0.0 or parent_mu_km3_s2 <= 0.0:
		return 0.0
	return TAU * sqrt(pow(semi_major_axis_km, 3.0) / parent_mu_km3_s2)


static func sample_kepler2d_position(motion: Kepler2DMotionDef, parent_mu_km3_s2: float, time_s: float) -> Vector2:
	"""Berechnet lokale Position eines Körpers auf Kepler-Orbit zur Zeit t"""
	if motion == null:
		return Vector2.ZERO

	var a_km := motion.semi_major_axis_km
	if a_km <= 0.0 or parent_mu_km3_s2 <= 0.0:
		return Vector2.ZERO

	var e := clampf(motion.eccentricity, 0.0, 0.999999)
	var period_s := get_kepler_period(a_km, parent_mu_km3_s2)
	if period_s <= 0.0:
		return Vector2.ZERO

	# Zeit seit Epoche
	var dt := time_s - motion.epoch_time_s
	var mean_motion := TAU / period_s
	var direction := float(motion.orbit_direction)

	# Mean Anomaly zur Zeit t
	var mean_anomaly := motion.mean_anomaly_epoch_rad + direction * mean_motion * dt

	# Löse Kepler-Gleichung
	var eccentric_anomaly := solve_kepler(e, mean_anomaly)

	# Konvertiere zu kartesischen Koordinaten
	return kepler_to_cartesian(a_km, e, eccentric_anomaly, motion.argument_of_periapsis_rad)


static func sample_circular_position(motion: CircularMotionDef, time_s: float) -> Vector2:
	"""Berechnet lokale Position eines Körpers auf Kreis-Orbit zur Zeit t"""
	if motion == null:
		return Vector2.ZERO

	var period_s := motion.orbital_period_s
	if period_s <= 0.0:
		return Vector2.ZERO

	var direction := float(motion.orbit_direction)
	var omega := TAU / period_s
	var theta := motion.initial_phase_rad + direction * omega * time_s

	var x := cos(theta) * motion.orbital_radius_km
	var y := sin(theta) * motion.orbital_radius_km

	return Vector2(x, y)


## Hilfsfunktionen
static func wrap_angle(angle: float) -> float:
	"""Normalisiert Winkel auf [0, 2π)"""
	return fposmod(angle, TAU)


## Kurslinien-Berechnungen
static func hohmann_transfer(r1: float, r2: float, mu: float) -> Dictionary:
	"""Berechnet Hohmann-Transfer zwischen zwei kreisförmigen Orbits
	   Returns: {dv1, dv2, transfer_time, a_transfer}"""
	if r1 <= 0.0 or r2 <= 0.0 or mu <= 0.0:
		return {}

	var a_transfer := (r1 + r2) / 2.0
	var v1_circular := sqrt(mu / r1)
	var v2_circular := sqrt(mu / r2)
	var v1_transfer := sqrt(mu * (2.0 / r1 - 1.0 / a_transfer))
	var v2_transfer := sqrt(mu * (2.0 / r2 - 1.0 / a_transfer))

	return {
		"dv1": abs(v1_transfer - v1_circular),
		"dv2": abs(v2_circular - v2_transfer),
		"transfer_time": PI * sqrt(pow(a_transfer, 3.0) / mu),
		"a_transfer": a_transfer
	}


static func calculate_delta_v(_initial_orbit: Dictionary, _final_orbit: Dictionary) -> float:
	"""Berechnet Delta-V für Orbit-Wechsel"""
	# TODO: Implement general delta-v calculation
	return 0.0


## Physikalische Körperberechnungen

static func body_mass_kg(mu_km3_s2: float) -> float:
	## M = µ / G
	if mu_km3_s2 <= 0.0: return 0.0
	return mu_km3_s2 / G_KM3_KG_S2


static func body_volume_km3(radius_km: float) -> float:
	## V = (4/3)π r³
	if radius_km <= 0.0: return 0.0
	return (4.0 / 3.0) * PI * pow(radius_km, 3.0)


static func body_density_g_cm3(mu_km3_s2: float, radius_km: float) -> float:
	## ρ = M / V, umgerechnet kg/km³ → g/cm³  (×1e-12)
	var vol_km3 := body_volume_km3(radius_km)
	if vol_km3 <= 0.0: return 0.0
	return (body_mass_kg(mu_km3_s2) / vol_km3) * 1.0e-12


static func surface_gravity_ms2(mu_km3_s2: float, radius_km: float) -> float:
	## g = µ / r²,  km/s² → m/s²  (×1000)
	if radius_km <= 0.0: return 0.0
	return (mu_km3_s2 / pow(radius_km, 2.0)) * 1000.0


static func escape_velocity_km_s(mu_km3_s2: float, radius_km: float) -> float:
	## v_e = √(2µ / r)
	if radius_km <= 0.0 or mu_km3_s2 <= 0.0: return 0.0
	return sqrt(2.0 * mu_km3_s2 / radius_km)


## Orbitale Hilfsberechnungen

static func orbit_periapsis_km(semi_major_axis_km: float, eccentricity: float) -> float:
	return semi_major_axis_km * (1.0 - eccentricity)


static func orbit_apoapsis_km(semi_major_axis_km: float, eccentricity: float) -> float:
	return semi_major_axis_km * (1.0 + eccentricity)


static func mean_orbital_velocity_km_s(semi_major_axis_km: float, period_s: float) -> float:
	if period_s <= 0.0: return 0.0
	return TAU * semi_major_axis_km / period_s


## Skalierungen
static func smooth_step(edge0: float, edge1: float, x: float) -> float:
	"""Smooth step Interpolation"""
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func lerp_zoom(zoom_exp: float, target: float, weight: float) -> float:
	"""Interpoliert Zoom-Level"""
	return lerpf(zoom_exp, target, weight)
