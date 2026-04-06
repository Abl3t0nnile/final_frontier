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
var _point_phases: PackedFloat32Array  = []  # per-instance random phase for asteroid shape
var _rotation_speed: float = 0.3  # Degrees per second

var zoom_exp_near: float   = 5.5
var zoom_exp_mid: float    = 6.5
var zoom_exp_far: float    = 7.5
var point_size_near: float = 8.0
var point_size_mid: float  = 4.0
var point_size_far: float  = 2.0

enum PointShape { SQUARE, CIRCLE, DIAMOND, CROSS, ASTEROID }
var point_shape: int = PointShape.SQUARE

const _FULL_RING_THRESHOLD: float = TAU * 0.95


func setup(def: BeltDef, map_transform: MapTransform) -> void:
	belt_def       = def
	belt_id        = def.id
	_map_transform = map_transform

	_parse_shape(def.point_shape)
	_auto_adjust_zoom_thresholds()

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors       = true
	_multimesh.use_custom_data  = (point_shape == PointShape.ASTEROID)
	_multimesh.mesh             = quad
	# instance_count einmalig auf max_points setzen — wird nie mehr geändert.
	# Änderungen an instance_count resetten in Godot alle Instanzdaten (→ Flackern).
	_multimesh.instance_count   = belt_def.max_points

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _multimesh
	add_child(_mmi)
	_apply_shape_material()

	_generate_points(belt_def.max_points)
	notify_zoom_changed(map_transform.km_per_px)


func _auto_adjust_zoom_thresholds() -> void:
	var outer_km := belt_def.outer_radius_km
	# near: Belt-Ring füllt den Screen (~1000px Radius)
	# mid:  Belt-Ring ist ein deutlicher Ring (~100px Radius)
	# far:  Belt-Ring wird klein (~10px Radius)
	zoom_exp_near = log(outer_km / 1000.0) / log(10.0)
	zoom_exp_mid  = log(outer_km / 100.0)  / log(10.0)
	zoom_exp_far  = log(outer_km / 10.0)   / log(10.0)


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
		if point_shape == PointShape.ASTEROID:
			_multimesh.set_instance_custom_data(i, Color(_point_phases[i], 0.0, 0.0, 0.0))

	# Transforms erst setzen, dann visible_instance_count anpassen —
	# so wird kein Frame mit ungültigen/alten Daten gerendert.
	_multimesh.visible_instance_count = lod_count


func _calc_lod(km_per_px: float) -> int:
	var t := _zoom_t(km_per_px)
	return int(lerpf(float(belt_def.max_points), float(belt_def.min_points), t))


func _point_size_at(km_per_px: float) -> float:
	var e := log(km_per_px) / log(10.0)
	if e <= zoom_exp_near:
		return point_size_near
	elif e < zoom_exp_mid:
		var t := (e - zoom_exp_near) / (zoom_exp_mid - zoom_exp_near)
		return lerpf(point_size_near, point_size_mid, t)
	else:
		var t := (e - zoom_exp_mid) / (zoom_exp_far - zoom_exp_mid)
		return lerpf(point_size_mid, point_size_far, clamp(t, 0.0, 1.0))


func _zoom_t(km_per_px: float) -> float:
	var e := log(km_per_px) / log(10.0)
	return (clamp(e, zoom_exp_near, zoom_exp_far) - zoom_exp_near) / (zoom_exp_far - zoom_exp_near)


func _generate_points(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = belt_def.rng_seed

	_points_km.resize(count)
	_point_weights.resize(count)
	_point_phases.resize(count)

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
		_point_phases[i]  = rng.randf()


func set_rotation_enabled(enabled: bool) -> void:
	if belt_def:
		belt_def.apply_rotation = enabled


func set_rotation_speed(speed: float) -> void:
	_rotation_speed = speed


func _parse_shape(s: String) -> void:
	match s:
		"circle":   point_shape = PointShape.CIRCLE
		"diamond":  point_shape = PointShape.DIAMOND
		"cross":    point_shape = PointShape.CROSS
		"asteroid": point_shape = PointShape.ASTEROID
		_:          point_shape = PointShape.SQUARE


func _apply_shape_material() -> void:
	if point_shape == PointShape.SQUARE:
		_mmi.material = null
		return
	var shader := Shader.new()
	if point_shape == PointShape.ASTEROID:
		# Unregelmäßiges Hexagon: 6 Eckpunkte mit per-Instanz Radius-Variation und Rotation.
		# Kreuzprodukt-Test (konvexes Polygon, CCW-Reihenfolge).
		shader.code = (
			"shader_type canvas_item;\n"
			+ "varying float seed;\n"
			+ "void vertex() { seed = INSTANCE_CUSTOM.r; }\n"
			+ "void fragment() {\n"
			+ "  vec2 p = UV * 2.0 - 1.0;\n"
			+ "  float rot = seed * 1.0472;\n"
			+ "  float s = seed * 17.3;\n"
			+ "  bool inside = true;\n"
			+ "  for (int i = 0; i < 6; i++) {\n"
			+ "    float a0 = rot + float(i) * 1.0472;\n"
			+ "    float a1 = rot + float(i + 1) * 1.0472;\n"
			+ "    float r0 = 0.43 + 0.08 * sin(s + float(i) * 1.618);\n"
			+ "    float r1 = 0.43 + 0.08 * sin(s + float(i + 1) * 1.618);\n"
			+ "    vec2 v0 = vec2(cos(a0), sin(a0)) * r0;\n"
			+ "    vec2 v1 = vec2(cos(a1), sin(a1)) * r1;\n"
			+ "    vec2 edge = v1 - v0;\n"
			+ "    vec2 to_p = p - v0;\n"
			+ "    if (edge.x * to_p.y - edge.y * to_p.x < 0.0) { inside = false; break; }\n"
			+ "  }\n"
			+ "  if (!inside) discard;\n"
			+ "}"
		)
	else:
		shader.code = (
			"shader_type canvas_item;\n"
			+ "uniform int shape_type = 1;\n"
			+ "void fragment() {\n"
			+ "  vec2 uv = UV - vec2(0.5);\n"
			+ "  bool ok = false;\n"
			+ "  if (shape_type == 1) { ok = length(uv) <= 0.5; }\n"
			+ "  else if (shape_type == 2) { ok = (abs(uv.x) + abs(uv.y)) <= 0.5; }\n"
			+ "  else if (shape_type == 3) { ok = abs(uv.x) <= 0.15 || abs(uv.y) <= 0.15; }\n"
			+ "  if (!ok) discard;\n"
			+ "}"
		)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if point_shape != PointShape.ASTEROID:
		mat.set_shader_parameter("shape_type", int(point_shape))
	_mmi.material = mat
