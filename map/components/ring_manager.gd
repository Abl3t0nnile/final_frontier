## RingManager
## Lädt Planeten-Ring-Daten und verwaltet BeltRenderer-Instanzen.
## Unabhängig vom BeltManager – Ringe werden nicht durch Belt-Toggle beeinflusst.

class_name RingManager
extends Node

const DEFAULT_DATA_PATH := "res://data/ring_data.json"

# Config (setzt BeltRenderer-Parameter)
var zoom_near: float       = 10_000.0
var zoom_mid: float        = 2_236_000.0
var zoom_far: float        = 500_000_000.0
var point_size_near: float = 3.0
var point_size_mid: float  = 2.0
var point_size_far: float  = 1.0

var _ring_layer: Node2D          = null
var _map_transform: MapTransform = null
var _model: SolarSystemModel     = null
var _renderers: Array            = []  # Array[BeltRenderer]
var _ring_defs: Array            = []  # Array[BeltDef]


func setup(ring_layer: Node2D, map_transform: MapTransform, model: SolarSystemModel,
		data_path: String = DEFAULT_DATA_PATH) -> void:
	_ring_layer    = ring_layer
	_map_transform = map_transform
	_model         = model
	_ring_defs     = _load_ring_defs(data_path)

	for def in _ring_defs:
		var renderer := BeltRenderer.new()
		_ring_layer.add_child(renderer)
		_apply_config(renderer)
		renderer.setup(def, _map_transform)
		_renderers.append(renderer)


func _apply_config(renderer: BeltRenderer) -> void:
	renderer.zoom_near       = zoom_near
	renderer.zoom_mid        = zoom_mid
	renderer.zoom_far        = zoom_far
	renderer.point_size_near = point_size_near
	renderer.point_size_mid  = point_size_mid
	renderer.point_size_far  = point_size_far


func update_rings() -> void:
	for i in _renderers.size():
		var def: BeltDef = _ring_defs[i]
		var renderer     = _renderers[i]

		if def.parent_id != "" and _model != null:
			var parent_pos_km: Vector2 = _model.get_body_position(def.parent_id)
			renderer.position = _map_transform.km_to_px(parent_pos_km)
		else:
			renderer.position = Vector2.ZERO


func update_zoom(km_per_px: float) -> void:
	for renderer in _renderers:
		renderer.notify_zoom_changed(km_per_px)


func get_renderers() -> Array:
	return _renderers


func get_ring_defs() -> Array:
	return _ring_defs


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _load_ring_defs(path: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(path):
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("RingManager: parse error in '%s'" % path)
		return result

	var raw: Variant = json.data
	if typeof(raw) != TYPE_DICTIONARY:
		return result

	var entries: Variant = raw.get("rings", [])
	if typeof(entries) != TYPE_ARRAY:
		return result

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def := _build_ring_def(entry)
		if def != null:
			result.append(def)

	return result


func _build_ring_def(data: Dictionary) -> BeltDef:
	if data.is_empty():
		return null
	var def := BeltDef.new()
	def.id                 = String(data.get("id", ""))
	def.name               = String(data.get("name", ""))
	def.parent_id          = String(data.get("parent_id", ""))
	def.reference_body_id  = String(data.get("reference_body_id", ""))
	def.inner_radius_km    = float(data.get("inner_radius_km", 0.0))
	def.outer_radius_km    = float(data.get("outer_radius_km", 0.0))
	def.angular_offset_rad = float(data.get("angular_offset_rad", 0.0))
	def.angular_spread_rad = float(data.get("angular_spread_rad", TAU))
	def.min_points         = int(data.get("min_points", 200))
	def.max_points         = int(data.get("max_points", 1000))
	def.rng_seed           = int(data.get("seed", 0))
	def.color_rgba         = _parse_color(data.get("color_rgba", [1.0, 1.0, 1.0, 1.0]))
	def.apply_rotation     = bool(data.get("apply_rotation", true))
	return def


func _parse_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 4:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		if arr.size() == 3:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
	return Color.WHITE
