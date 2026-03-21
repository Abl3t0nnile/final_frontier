# MapDataLoader — Lädt Belt- und Zone-Definitionen aus JSON-Dateien.
# Folgt dem gleichen Muster wie CoreDataLoader.
class_name MapDataLoader

extends RefCounted

const BELT_DATA_PATH := "res://data/belt_data.json"
const ZONE_DATA_PATH := "res://data/zone_data.json"


func load_all_belt_defs(data_path: String = BELT_DATA_PATH) -> Array[BeltDef]:
	var result: Array[BeltDef] = []
	var raw_data: Variant = _load_json_file(data_path)

	if typeof(raw_data) != TYPE_DICTIONARY:
		push_warning("MapDataLoader: root json is not a dictionary in '%s'" % data_path)
		return result

	var raw_belts: Variant = raw_data.get("belts", [])
	if typeof(raw_belts) != TYPE_ARRAY:
		push_warning("MapDataLoader: 'belts' is not an array in '%s'" % data_path)
		return result

	for entry in raw_belts:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def := _build_belt_def(entry)
		if def != null:
			result.append(def)

	return result


func load_all_zone_defs(data_path: String = ZONE_DATA_PATH) -> Array[ZoneDef]:
	var result: Array[ZoneDef] = []
	var raw_data: Variant = _load_json_file(data_path)

	if typeof(raw_data) != TYPE_DICTIONARY:
		push_warning("MapDataLoader: root json is not a dictionary in '%s'" % data_path)
		return result

	var raw_zones: Variant = raw_data.get("zones", [])
	if typeof(raw_zones) != TYPE_ARRAY:
		push_warning("MapDataLoader: 'zones' is not an array in '%s'" % data_path)
		return result

	for entry in raw_zones:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def := _build_zone_def(entry)
		if def != null:
			result.append(def)

	return result


func _build_belt_def(d: Dictionary) -> BeltDef:
	if d.is_empty():
		return null

	var def := BeltDef.new()
	def.id                 = String(d.get("id", ""))
	def.name               = String(d.get("name", ""))
	def.parent_id          = String(d.get("parent_id", ""))
	def.reference_body_id  = String(d.get("reference_body_id", ""))
	def.inner_radius_km    = float(d.get("inner_radius_km", 0.0))
	def.outer_radius_km    = float(d.get("outer_radius_km", 0.0))
	def.angular_offset_rad = float(d.get("angular_offset_rad", 0.0))
	def.angular_spread_rad = float(d.get("angular_spread_rad", TAU))
	def.min_points         = int(d.get("min_points", 100))
	def.max_points         = int(d.get("max_points", 500))
	def.seed               = int(d.get("seed", 0))
	def.color_rgba         = _parse_color(d.get("color_rgba", [1.0, 1.0, 1.0, 1.0]))
	def.apply_rotation     = bool(d.get("apply_rotation", true))
	return def


func _build_zone_def(d: Dictionary) -> ZoneDef:
	if d.is_empty():
		return null

	var def := ZoneDef.new()
	def.id               = String(d.get("id", ""))
	def.name             = String(d.get("name", ""))
	def.parent_id        = String(d.get("parent_id", ""))
	def.zone_type        = String(d.get("zone_type", ""))
	def.geometry         = String(d.get("geometry", "circle"))
	def.radius_km        = float(d.get("radius_km", 0.0))
	def.inner_radius_km  = float(d.get("inner_radius_km", 0.0))
	def.outer_radius_km  = float(d.get("outer_radius_km", 0.0))
	def.color_rgba       = _parse_color(d.get("color_rgba", [1.0, 1.0, 1.0, 0.1]))
	def.border_color_rgba = _parse_color(d.get("border_color_rgba", [1.0, 1.0, 1.0, 0.4]))
	return def


func _load_json_file(data_path: String) -> Variant:
	if not FileAccess.file_exists(data_path):
		push_warning("MapDataLoader: file not found '%s'" % data_path)
		return {}

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_warning("MapDataLoader: failed to open '%s'" % data_path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_warning("MapDataLoader: json parse error in '%s' at line %d: %s"
				% [data_path, json.get_error_line(), json.get_error_message()])
		return {}

	return json.data


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
