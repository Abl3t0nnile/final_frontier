## BeltRenderer
## GPU-Renderer für Gürtel-Punktwolken via MultiMeshInstance2D.
## Eine Instanz pro BeltDef. Punkte deterministisch aus rng_seed generiert.
## Position (Node2D.position) = Parent-Body in px — gesetzt vom BeltManager.
## instance_count bleibt konstant auf max_points; LOD via visible_instance_count.

class_name BeltRenderer
extends Node2D

var belt_def: BeltDef      = null
var belt_id:  String       = ""

var _map_transform: MapTransform = null
var _mmi: MultiMeshInstance2D    = null
var _multimesh: MultiMesh        = null

var _points_km: PackedVector2Array     = []
var _point_weights: PackedFloat32Array = []
var _rotation_speed: float = 0.3  # Degrees per second

var zoom_near: float       = 10_000.0
var zoom_mid: float        = 2_236_000.0
var zoom_far: float        = 500_000_000.0
var point_size_near: float = 3.0
var point_size_mid: float  = 2.0
var point_size_far: float  = 1.0

const _FULL_RING_THRESHOLD: float = TAU * 0.95


func setup(def: BeltDef, map_transform: MapTransform) -> void:
	belt_def       = def
	belt_id        = def.id
	_map_transform = map_transform

	_auto_adjust_zoom_thresholds()

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors       = true
	_multimesh.use_custom_data  = false
	_multimesh.mesh             = quad
	# instance_count einmalig auf max_points setzen — wird nie mehr geändert.
	# Änderungen an instance_count resetten in Godot alle Instanzdaten (→ Flackern).
	_multimesh.instance_count   = belt_def.max_points

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _multimesh
	add_child(_mmi)

	_generate_points(belt_def.max_points)
	notify_zoom_changed(map_transform.km_per_px)


func _auto_adjust_zoom_thresholds() -> void:
	var outer_km := belt_def.outer_radius_km
	zoom_near = outer_km / 100.0
	zoom_mid  = outer_km / 20.0
	zoom_far  = outer_km / 2.0


func notify_zoom_changed(km_per_px: float) -> void:
	_update_multimesh_transforms(km_per_px)

func _process(delta: float) -> void:
	if belt_def and belt_def.apply_rotation and _mmi.visible:
		# Einfache Node-Rotation
		rotation += deg_to_rad(_rotation_speed) * delta

# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _update_multimesh_transforms(km_per_px: float) -> void:
	var lod_count := _calc_lod(km_per_px)
	var pt_max    := _point_size_at(km_per_px)

	for i in lod_count:
		var pos_px: Vector2 = _points_km[i] / km_per_px
		var w: float        = _point_weights[i]
		var size: float     = lerpf(pt_max * 0.25, pt_max, w)

		var t := Transform2D()
		t.origin = pos_px
		t.x      = Vector2(size, 0.0)
		t.y      = Vector2(0.0, size)
		_multimesh.set_instance_transform_2d(i, t)

		var alpha: float = belt_def.color_rgba.a * lerpf(0.08, 1.0, w)
		_multimesh.set_instance_color(i, Color(
			belt_def.color_rgba.r,
			belt_def.color_rgba.g,
			belt_def.color_rgba.b,
			alpha))

	# Transforms erst setzen, dann visible_instance_count anpassen —
	# so wird kein Frame mit ungültigen/alten Daten gerendert.
	_multimesh.visible_instance_count = lod_count


func _calc_lod(km_per_px: float) -> int:
	var t := _zoom_t(km_per_px)
	return int(lerpf(float(belt_def.max_points), float(belt_def.min_points), t))


func _point_size_at(km_per_px: float) -> float:
	if km_per_px <= zoom_mid:
		return lerpf(point_size_near, point_size_mid, _zoom_t_range(km_per_px, zoom_near, zoom_mid))
	else:
		return lerpf(point_size_mid, point_size_far, _zoom_t_range(km_per_px, zoom_mid, zoom_far))


func _zoom_t_range(km_per_px: float, from: float, to: float) -> float:
	var clamped: float = clamp(km_per_px, from, to)
	return (log(clamped) - log(from)) / (log(to) - log(from))


func _zoom_t(km_per_px: float) -> float:
	var clamped: float = clamp(km_per_px, zoom_near, zoom_far)
	return (log(clamped) - log(zoom_near)) / (log(zoom_far) - log(zoom_near))


func _generate_points(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = belt_def.rng_seed

	_points_km.resize(count)
	_point_weights.resize(count)

	var is_cloud: bool      = belt_def.angular_spread_rad < _FULL_RING_THRESHOLD
	var mid_radius: float   = (belt_def.inner_radius_km + belt_def.outer_radius_km) * 0.5
	var radial_half: float  = (belt_def.outer_radius_km - belt_def.inner_radius_km) * 0.5
	var radial_sigma: float = radial_half * 0.5

	var mid_angle: float     = belt_def.angular_offset_rad + belt_def.angular_spread_rad * 0.5
	var angular_half: float  = belt_def.angular_spread_rad * 0.5
	var angular_sigma: float = angular_half * 0.4

	for i in count:
		var radius: float = clamp(
			rng.randfn(mid_radius, radial_sigma),
			belt_def.inner_radius_km, belt_def.outer_radius_km)
		var radial_t: float = abs(radius - mid_radius) / radial_half

		var angle: float
		var angular_t: float
		if is_cloud:
			angle = clamp(
				rng.randfn(mid_angle, angular_sigma),
				belt_def.angular_offset_rad,
				belt_def.angular_offset_rad + belt_def.angular_spread_rad)
			angular_t = abs(angle - mid_angle) / angular_half
		else:
			angle     = rng.randf() * TAU
			angular_t = 0.0

		_points_km[i]     = Vector2(cos(angle) * radius, sin(angle) * radius)
		_point_weights[i] = (1.0 - clamp(radial_t, 0.0, 1.0)) * (1.0 - clamp(angular_t, 0.0, 1.0))


func set_rotation_enabled(enabled: bool) -> void:
	if belt_def:
		belt_def.apply_rotation = enabled


func set_rotation_speed(speed: float) -> void:
	_rotation_speed = speed
