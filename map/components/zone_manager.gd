## ZoneManager
## Lädt Zonen-Daten und verwaltet ZoneRenderer-Instanzen.

class_name ZoneManager
extends Node

const DEFAULT_DATA_PATH := "res://data/solar_system/zone_data.json"

var _zone_layer: Node2D          = null
var _map_transform: MapTransform = null
var _model: SolarSystemModel     = null
var _renderers: Array            = []  # Array[ZoneRenderer]
var _zone_defs: Array            = []  # Array[ZoneDef]


func setup(zone_layer: Node2D, map_transform: MapTransform, model: SolarSystemModel,
		data_path: String = DEFAULT_DATA_PATH) -> void:
	_zone_layer    = zone_layer
	_map_transform = map_transform
	_model         = model
	_zone_defs     = _load_zone_defs(data_path)

	for def in _zone_defs:
		var renderer := ZoneRenderer.new()
		_zone_layer.add_child(renderer)
		renderer.setup(def, _map_transform)
		_renderers.append(renderer)


func update_zones() -> void:
	for i in _renderers.size():
		var def: ZoneDef = _zone_defs[i]
		var renderer     = _renderers[i]

		if def.parent_id != "" and _model != null:
			var parent_pos_km: Vector2 = _model.get_body_position(def.parent_id)
			renderer.position = _map_transform.km_to_px(parent_pos_km)
		else:
			renderer.position = Vector2.ZERO

		# kein queue_redraw() — MeshInstance2D rendert automatisch


func update_zoom(km_per_px: float) -> void:
	for renderer in _renderers:
		renderer.notify_zoom_changed(km_per_px)


func get_renderers() -> Array:
	return _renderers


func get_zone_defs() -> Array:
	return _zone_defs


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _load_zone_defs(path: String) -> Array:
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
		push_warning("ZoneManager: parse error in '%s'" % path)
		return result

	var raw: Variant = json.data
	if typeof(raw) != TYPE_DICTIONARY:
		return result

	var entries: Variant = raw.get("zones", [])
	if typeof(entries) != TYPE_ARRAY:
		return result

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def := _build_zone_def(entry)
		if def != null:
			result.append(def)

	return result


func _build_zone_def(data: Dictionary) -> ZoneDef:
	if data.is_empty():
		return null
	var def := ZoneDef.new()
	def.id               = String(data.get("id", ""))
	def.name             = String(data.get("name", ""))
	def.parent_id        = String(data.get("parent_id", ""))
	def.zone_type        = String(data.get("zone_type", ""))
	def.geometry         = String(data.get("geometry", "circle"))
	def.radius_km        = float(data.get("radius_km", 0.0))
	def.inner_radius_km  = float(data.get("inner_radius_km", 0.0))
	def.outer_radius_km  = float(data.get("outer_radius_km", 0.0))
	def.color_rgba       = _parse_color(data.get("color_rgba", [0.5, 0.5, 1.0, 0.1]))
	def.border_color_rgba = _parse_color(data.get("border_color_rgba", [0.5, 0.5, 1.0, 0.4]))
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
