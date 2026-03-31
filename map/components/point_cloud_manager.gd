## PointCloudManager
## Unified manager for belt and ring point cloud data
## Replaces both BeltManager and RingManager

class_name PointCloudManager
extends Node

# Config (sets BeltRenderer parameters)
var zoom_near: float       = 10_000.0
var zoom_mid: float        = 2_236_000.0
var zoom_far: float        = 500_000_000.0
var point_size_near: float = 3.0
var point_size_mid: float  = 2.0
var point_size_far: float  = 1.0

var _layer: Node2D              = null
var _map_transform: MapTransform = null
var _model: SolarSystemModel     = null
var _renderers: Array            = []  # Array[BeltRenderer]
var _defs: Array                 = []  # Array[BeltDef]
var _data_path: String           = ""
var _json_root_key: String       = ""


func setup(layer: Node2D, map_transform: MapTransform, model: SolarSystemModel,
		data_path: String, json_root_key: String) -> void:
	_layer = layer
	_map_transform = map_transform
	_model = model
	_data_path = data_path
	_json_root_key = json_root_key
	_defs = _load_defs(data_path, json_root_key)
	
	for def in _defs:
		var renderer := BeltRenderer.new()
		_layer.add_child(renderer)
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


func update_positions() -> void:
	for i in _renderers.size():
		var def: BeltDef   = _defs[i]
		var renderer: BeltRenderer = _renderers[i]
		var parent_pos: Vector2 = _model.get_body_position(def.parent_id)
		renderer.set_global_position(parent_pos)


func update_zoom(_km_per_px: float) -> void:
	for renderer in _renderers:
		renderer.notify_zoom_changed()


func get_renderers() -> Array:
	return _renderers


func get_defs() -> Array:
	return _defs


# Load data based on the path and root key
func _load_defs(data_path: String, json_root_key: String) -> Array:
	var defs: Array = []
	
	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open point cloud data: " + data_path)
		return defs
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse JSON in: " + data_path)
		return defs
	
	var data = json.data
	if not data or not data.has(json_root_key):
		push_error("Invalid JSON structure - missing key '" + json_root_key + "' in: " + data_path)
		return defs
	
	var raw_defs = data[json_root_key]
	for raw_def in raw_defs:
		var def := BeltDef.new()
		def.parse_json_dict(raw_def)
		defs.append(def)
	
	return defs
