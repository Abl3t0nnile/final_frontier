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
		# Convert to map transform coordinates
		var map_pos := _map_transform.km_to_px(parent_pos)
		renderer.position = map_pos
		# Trojaner/Lagrange: Wolke mit Referenzkörper mitrotieren
		if def.reference_body_id != "" and not def.apply_rotation:
			var ref_pos := _model.get_body_position(def.reference_body_id)
			renderer.rotation = atan2(ref_pos.y, ref_pos.x)


func update_zoom(km_per_px: float) -> void:
	for renderer in _renderers:
		renderer.notify_zoom_changed(km_per_px)


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
		# Set properties directly from JSON
		if raw_def.has("id"): def.id = raw_def.id
		if raw_def.has("name"): def.name = raw_def.name
		if raw_def.has("parent_id"): def.parent_id = raw_def.parent_id
		if raw_def.has("reference_body_id"): def.reference_body_id = raw_def.reference_body_id
		if raw_def.has("inner_radius_km"): def.inner_radius_km = raw_def.inner_radius_km
		if raw_def.has("outer_radius_km"): def.outer_radius_km = raw_def.outer_radius_km
		if raw_def.has("angular_offset_rad"): def.angular_offset_rad = raw_def.angular_offset_rad
		if raw_def.has("angular_spread_rad"): def.angular_spread_rad = raw_def.angular_spread_rad
		if raw_def.has("min_points"): def.min_points = raw_def.min_points
		if raw_def.has("max_points"): def.max_points = raw_def.max_points
		if raw_def.has("rng_seed"): def.rng_seed = raw_def.rng_seed
		if raw_def.has("color_rgba"): 
			if raw_def.color_rgba is Array:
				def.color_rgba = Color(raw_def.color_rgba[0], raw_def.color_rgba[1], raw_def.color_rgba[2], raw_def.color_rgba[3])
			else:
				def.color_rgba = raw_def.color_rgba
		if raw_def.has("apply_rotation"): def.apply_rotation = raw_def.apply_rotation
		defs.append(def)
	
	return defs
