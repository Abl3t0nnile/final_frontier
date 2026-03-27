# res://game/map/renderer/belt_renderer.gd
# Zeichnet eine prozedurale Punktwolke für einen Gürtel (BeltDef).
# Eine Instanz pro BeltDef. Punkte werden deterministisch aus dem rng_seed
# generiert und bei LOD-Wechsel neu berechnet.
# Position (Node2D.position) = Parent-Body-Position in px — gesetzt vom MapController.
# Rotation (Node2D.rotation) = Referenzkörper-Winkel — nur für Trojaner (apply_rotation=false).
# Konfiguration (zoom_near etc.) wird vom MapController gesetzt.

class_name BeltRenderer
extends Node2D

var belt_def: BeltDef      = null
var belt_id:  String       = ""

var _map_transform: MapTransform   = null
var _points_km: PackedVector2Array = []
var _point_weights: PackedFloat32Array = []  # 0.0 = Rand, 1.0 = Mitte
var _current_lod: int              = -1

# Zoom-Grenzen für LOD- und Punkt-Größen-Interpolation
var zoom_near: float       = 10_000.0
var zoom_mid: float        = 2_236_000.0   # 10^6.35 — geometrische Mitte near/far
var zoom_far: float        = 500_000_000.0
var point_size_near: float = 3.0
var point_size_mid: float  = 2.0
var point_size_far: float  = 1.0

# Retro-future color overrides
var enable_color_overrides: bool = false
var color_override: bool = false
var color_default: Color = Color(0.88, 0.36, 0.27, 1.0)     # #E05C44 - muted red-orange
var color_core: Color = Color(1.0, 0.7, 0.0, 1.0)         # #E0B300 - muted yellow-orange
var alpha_multiplier: float = 1.0

# Vollständiger Ring wenn Winkelbereich >= 95 % von TAU
const _FULL_RING_THRESHOLD: float = TAU * 0.95
# Mindest-Punktzahl-Änderung die einen Rebuild auslöst (verhindert Rebuild bei jedem Zoom-Schritt)
const _LOD_HYSTERESIS: int = 50


func setup(def: BeltDef, map_transform: MapTransform) -> void:
	belt_def       = def
	belt_id        = def.id
	_map_transform = map_transform
	notify_zoom_changed(_map_transform.km_per_px)


# Vom MapController bei jedem Zoom-Schritt aufgerufen.
func notify_zoom_changed(km_per_px: float) -> void:
	var count: int = _calc_lod(km_per_px)
	if _current_lod == -1 or abs(count - _current_lod) >= _LOD_HYSTERESIS:
		_current_lod = count
		_rebuild_points(count)
	queue_redraw()


# ---------------------------------------------------------------------------
# Zeichnen
# ---------------------------------------------------------------------------

func _draw() -> void:
	if belt_def == null or _map_transform == null or _points_km.size() == 0:
		return

	var km_px: float   = _map_transform.km_per_px
	var pt_max: float  = _point_size_at(km_px)
	var col: Color
	
	# Use color overrides if enabled, otherwise use belt color
	if enable_color_overrides and color_override:
		col = color_default
	else:
		col = belt_def.color_rgba

	# Sichtbaren Bereich in lokalen Draw-Koordinaten berechnen.
	# km_to_px() liefert WorldRoot-px, draw() arbeitet in Node-Local-Space
	# (= WorldRoot-px minus node.position). Kamera-Position ist cam_pos_px im WorldRoot.
	var vp_half := get_viewport_rect().size * 0.5
	var cam_local := _map_transform.cam_pos_px - position
	var margin := pt_max + 1.0
	# Moderater Puffer für Culling, um Kanten beim Panning zu vermeiden
	var cull_buffer := vp_half * 0.75  # 75% zusätzliche Pufferung
	var vis_min := cam_local - vp_half - cull_buffer - Vector2(margin, margin)
	var vis_max := cam_local + vp_half + cull_buffer + Vector2(margin, margin)

	for i in _points_km.size():
		var px := _map_transform.km_to_px(_points_km[i])
		if px.x < vis_min.x or px.x > vis_max.x or px.y < vis_min.y or px.y > vis_max.y:
			continue
		var w: float     = _point_weights[i]
		var size: float  = lerpf(pt_max * 0.25, pt_max, w)
		var alpha: float = col.a * lerpf(0.08, 1.0, w) * alpha_multiplier
		
		# Blend between default and core color based on weight
		var draw_col: Color
		if enable_color_overrides and color_override:
			draw_col = col.lerp(color_core, w * 0.5)
		else:
			draw_col = col
		
		draw_col.a = alpha
		draw_circle(px, size, draw_col)


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _calc_lod(km_per_px: float) -> int:
	var t: float = _zoom_t(km_per_px)
	return int(lerpf(float(belt_def.max_points), float(belt_def.min_points), t))


func _point_size_at(km_per_px: float) -> float:
	if km_per_px <= zoom_mid:
		var t := _zoom_t_range(km_per_px, zoom_near, zoom_mid)
		return lerpf(point_size_near, point_size_mid, t)
	else:
		var t := _zoom_t_range(km_per_px, zoom_mid, zoom_far)
		return lerpf(point_size_mid, point_size_far, t)


func _zoom_t_range(km_per_px: float, from: float, to: float) -> float:
	var clamped: float = clamp(km_per_px, from, to)
	return (log(clamped) - log(from)) / (log(to) - log(from))


func _zoom_t(km_per_px: float) -> float:
	var clamped: float = clamp(km_per_px, zoom_near, zoom_far)
	return (log(clamped) - log(zoom_near)) / (log(zoom_far) - log(zoom_near))


func _rebuild_points(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = belt_def.rng_seed

	_points_km.resize(count)
	_point_weights.resize(count)

	var is_cloud: bool    = belt_def.angular_spread_rad < _FULL_RING_THRESHOLD
	var mid_radius: float = (belt_def.inner_radius_km + belt_def.outer_radius_km) * 0.5
	var radial_half: float = (belt_def.outer_radius_km - belt_def.inner_radius_km) * 0.5
	# Sigma so dass ~95 % der Punkte innerhalb des Gürtels liegen
	var radial_sigma: float = radial_half * 0.5

	var mid_angle: float    = belt_def.angular_offset_rad + belt_def.angular_spread_rad * 0.5
	var angular_half: float = belt_def.angular_spread_rad * 0.5
	var angular_sigma: float = angular_half * 0.4

	for i in count:
		# Radius: Gauss um Gürtelmitte, geclampt auf [inner, outer]
		var radius: float = clamp(
			rng.randfn(mid_radius, radial_sigma),
			belt_def.inner_radius_km, belt_def.outer_radius_km
		)
		var radial_t: float = abs(radius - mid_radius) / radial_half  # 0=Mitte, 1=Rand

		# Winkel
		var angle: float
		var angular_t: float
		if is_cloud:
			angle = clamp(
				rng.randfn(mid_angle, angular_sigma),
				belt_def.angular_offset_rad,
				belt_def.angular_offset_rad + belt_def.angular_spread_rad
			)
			angular_t = abs(angle - mid_angle) / angular_half  # 0=Mitte, 1=Rand
		else:
			angle     = rng.randf() * TAU
			angular_t = 0.0

		_points_km[i]     = Vector2(cos(angle) * radius, sin(angle) * radius)
		# Gewicht: 1 im Zentrum, 0 am Rand — kombiniert radial & angular
		_point_weights[i] = (1.0 - clamp(radial_t, 0.0, 1.0)) * (1.0 - clamp(angular_t, 0.0, 1.0))
