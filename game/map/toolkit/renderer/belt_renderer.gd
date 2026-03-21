# BeltRenderer — Prozedurale Punktwolke für Gürtel, Trojaner und Planetenringe.
# Generiert bei setup() deterministisch alle Punkte via Seed.
# LOD über set_density(): zeigt die ersten N Punkte (Shuffle-Priorität).
# Zwei unabhängige Rotations-Layer mit leicht unterschiedlichen Geschwindigkeiten
# erzeugen einen lebendigen, aber ruhigen Bewegungseffekt.
# Trojaner: set_reference_angle() rotiert die gesamte Wolke mit dem Referenzkörper.
# Position wird von der View gesetzt (renderer.position = parent_marker.position).
#
# Performance: Partikel werden als ArrayMesh vorcompiliert (in setup/set_px_per_km/
# set_density). Pro Frame nur draw_set_transform() + draw_mesh() — 2 Calls statt N.
# Basis-Winkel (_angles_rad) werden ohne Layer-Rotation gebacken; _ref_angle und
# _angle_0/_angle_1 werden als Transform zur Laufzeit angewendet.
class_name BeltRenderer

extends Node2D

const SIZE_MIN_PX:      float = 1.2
const SIZE_MAX_PX:      float = 3.0
const COLOR_OFFSET_MAX: float = 0.15

# Rotationsgeschwindigkeiten in rad/s. Kleiner Versatz zwischen den Layern
# erzeugt den lebendigen Effekt ohne Hektik.
@export var rotation_speed_0: float = 0.001
@export var rotation_speed_1: float = 0.005
# Bei Trojanern deaktivieren: Position wird über set_reference_angle() gesteuert,
# die Layer-Rotation würde die Wolke sonst aus der L4/L5-Position driften lassen.
@export var apply_rotation: bool = true

var _radii_km:      PackedFloat32Array = PackedFloat32Array()
var _angles_rad:    PackedFloat32Array = PackedFloat32Array()
var _sizes_px:      PackedFloat32Array = PackedFloat32Array()
var _color_offsets: PackedFloat32Array = PackedFloat32Array()
var _layer_flags:   PackedByteArray    = PackedByteArray()    # 0 oder 1 pro Punkt

var _base_color:    Color = Color.WHITE
var _visible_count: int   = 0
var _px_per_km:     float = 1.0
var _size_scale:    float = 1.0
var _ref_angle:     float = 0.0
var _angle_0:       float = 0.0
var _angle_1:       float = 0.0

var _mesh_layer0: ArrayMesh = null
var _mesh_layer1: ArrayMesh = null
var _mesh_dirty:  bool      = true


func setup(belt: BeltDef) -> void:
	_base_color    = belt.color_rgba
	_visible_count = belt.min_points
	apply_rotation = belt.apply_rotation

	var rng := RandomNumberGenerator.new()
	rng.seed = belt.seed

	var count: int = belt.max_points
	_radii_km.resize(count)
	_angles_rad.resize(count)
	_sizes_px.resize(count)
	_color_offsets.resize(count)
	_layer_flags.resize(count)

	var is_cloud: bool = belt.angular_spread_rad < TAU * 0.9
	var center_r: float = (belt.inner_radius_km + belt.outer_radius_km) / 2.0
	var sigma_r:  float = (belt.outer_radius_km - belt.inner_radius_km) / 4.0
	var center_a: float = belt.angular_offset_rad + belt.angular_spread_rad / 2.0
	var sigma_a:  float = belt.angular_spread_rad / 4.0

	for i in count:
		if is_cloud:
			_radii_km[i]   = rng.randfn(center_r, sigma_r)
			_angles_rad[i] = rng.randfn(center_a, sigma_a)
		else:
			_radii_km[i]   = rng.randf_range(belt.inner_radius_km, belt.outer_radius_km)
			_angles_rad[i] = rng.randf_range(belt.angular_offset_rad,
					belt.angular_offset_rad + belt.angular_spread_rad)
		_sizes_px[i]      = rng.randf_range(SIZE_MIN_PX, SIZE_MAX_PX)
		_color_offsets[i] = rng.randf_range(-COLOR_OFFSET_MAX, COLOR_OFFSET_MAX)
		_layer_flags[i]   = rng.randi() % 2

	_shuffle(rng)
	_mesh_layer0 = ArrayMesh.new()
	_mesh_layer1 = ArrayMesh.new()
	_mesh_dirty  = true
	queue_redraw()


func set_density(visible_count: int) -> void:
	_visible_count = clampi(visible_count, 0, _radii_km.size())
	_mesh_dirty = true
	queue_redraw()


func set_reference_angle(angle_rad: float) -> void:
	_ref_angle = angle_rad
	queue_redraw()


func set_px_per_km(px_per_km: float) -> void:
	_px_per_km = px_per_km
	var scale_exp: float = -log(px_per_km) / log(10.0)
	_size_scale = clampf(1.0 + (6.5 - scale_exp) * 0.5, 1.0, 4.0)
	_mesh_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	if apply_rotation:
		_angle_0 += rotation_speed_0 * delta
		_angle_1 += rotation_speed_1 * delta
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


# Baut zwei ArrayMeshes (einen pro Layer) aus den Basis-Winkeln ohne Layer-Rotation.
# Wird nur bei Änderung von px_per_km, size_scale oder visible_count aufgerufen.
func _rebuild_meshes() -> void:
	var verts0  := PackedVector2Array()
	var colors0 := PackedColorArray()
	var verts1  := PackedVector2Array()
	var colors1 := PackedColorArray()

	for i in _visible_count:
		var r:    float   = _radii_km[i] * _px_per_km
		var pos:  Vector2 = Vector2(cos(_angles_rad[i]), sin(_angles_rad[i])) * r
		var col:  Color   = _base_color.lightened(_color_offsets[i])
		var half: float   = _sizes_px[i] * _size_scale * 0.5

		var v0 := pos + Vector2(-half, -half)
		var v1 := pos + Vector2( half, -half)
		var v2 := pos + Vector2( half,  half)
		var v3 := pos + Vector2(-half,  half)

		if _layer_flags[i] == 0:
			verts0.append(v0); verts0.append(v1); verts0.append(v2)
			verts0.append(v0); verts0.append(v2); verts0.append(v3)
			for j in 6: colors0.append(col)
		else:
			verts1.append(v0); verts1.append(v1); verts1.append(v2)
			verts1.append(v0); verts1.append(v2); verts1.append(v3)
			for j in 6: colors1.append(col)

	_fill_mesh(_mesh_layer0, verts0, colors0)
	_fill_mesh(_mesh_layer1, verts1, colors1)
	_mesh_dirty = false


func _fill_mesh(mesh: ArrayMesh, verts: PackedVector2Array, colors: PackedColorArray) -> void:
	mesh.clear_surfaces()
	if verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR]  = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _draw() -> void:
	if _visible_count == 0 or _mesh_layer0 == null:
		return
	if _mesh_dirty:
		_rebuild_meshes()
	draw_set_transform(Vector2.ZERO, _ref_angle + _angle_0)
	draw_mesh(_mesh_layer0, null)
	draw_set_transform(Vector2.ZERO, _ref_angle + _angle_1)
	draw_mesh(_mesh_layer1, null)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# Fisher-Yates Shuffle auf allen fünf Arrays gleichzeitig.
func _shuffle(rng: RandomNumberGenerator) -> void:
	var n: int = _radii_km.size()
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp_r: float = _radii_km[i];      _radii_km[i]      = _radii_km[j];      _radii_km[j]      = tmp_r
		var tmp_a: float = _angles_rad[i];    _angles_rad[i]    = _angles_rad[j];    _angles_rad[j]      = tmp_a
		var tmp_s: float = _sizes_px[i];      _sizes_px[i]      = _sizes_px[j];      _sizes_px[j]      = tmp_s
		var tmp_c: float = _color_offsets[i]; _color_offsets[i] = _color_offsets[j]; _color_offsets[j] = tmp_c
		var tmp_l: int   = _layer_flags[i];   _layer_flags[i]   = _layer_flags[j];   _layer_flags[j]   = tmp_l
