# res://game/map/map_data_loader.gd
# Lädt visuelle Map-Daten (Belts, Zones) — unabhängig von der Simulation.
# Belts und Zones sind reine Visualisierungen, keine Simulationsobjekte.

class_name MapDataLoader
extends RefCounted

const DEFAULT_BELTS_PATH := "res://data/belt_data.json"
const DEFAULT_ZONES_PATH := "res://data/zone_data.json"


func load_all_belt_defs(data_path: String = DEFAULT_BELTS_PATH) -> Array[BeltDef]:
	var result: Array[BeltDef] = []
	var raw_data: Variant = _load_json(data_path)

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


func load_all_zone_defs(data_path: String = DEFAULT_ZONES_PATH) -> Array[ZoneDef]:
	var result: Array[ZoneDef] = []
	var raw_data: Variant = _load_json(data_path)

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


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

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


func _build_belt_def(data: Dictionary) -> BeltDef:
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


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("MapDataLoader: file not found '%s'" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("MapDataLoader: failed to open '%s'" % path)
		return {}
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("MapDataLoader: parse error in '%s' line %d: %s"
			% [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data
