class_name CoreDataLoader
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/solar_system_sim_data.json"


func load_all_body_defs(data_path: String = DEFAULT_DATA_PATH) -> Array[BodyDef]:
	var result: Array[BodyDef] = []
	var raw_data: Variant = _load_json_file(data_path)

	if typeof(raw_data) != TYPE_DICTIONARY:
		push_warning("SolarSystemDataLoader: root json is not a dictionary")
		return result

	var root: Dictionary = raw_data
	var raw_bodies: Variant = root.get("bodies", [])

	if typeof(raw_bodies) != TYPE_ARRAY:
		push_warning("SolarSystemDataLoader: 'bodies' is not an array")
		return result

	for entry in raw_bodies:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var body_def := _build_body_def(entry)
		if body_def != null:
			result.append(body_def)

	return result


func load_body_def(body_id: String, data_path: String = DEFAULT_DATA_PATH) -> BodyDef:
	var all_bodies: Array[BodyDef] = load_all_body_defs(data_path)

	for body in all_bodies:
		if body != null and body.id == body_id:
			return body

	push_warning("SolarSystemDataLoader: unknown body id '%s'" % body_id)
	return null


func _load_json_file(data_path: String) -> Variant:
	if not FileAccess.file_exists(data_path):
		push_warning("SolarSystemDataLoader: file not found '%s'" % data_path)
		return {}

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_warning("SolarSystemDataLoader: failed to open '%s'" % data_path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error: Error = json.parse(json_text)

	if parse_error != OK:
		push_warning(
			"SolarSystemDataLoader: json parse error in '%s' at line %d: %s"
			% [data_path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	return json.data


func _build_body_def(body_data: Dictionary) -> BodyDef:
	if body_data.is_empty():
		return null

	var body_def := BodyDef.new()

	body_def.id = String(body_data.get("id", ""))
	body_def.name = String(body_data.get("name", ""))

	body_def.type = String(body_data.get("type", ""))
	body_def.subtype = String(body_data.get("subtype", ""))

	body_def.parent_id = String(body_data.get("parent_id", ""))

	body_def.radius_km = float(body_data.get("radius_km", 0.0))
	body_def.mu_km3_s2 = float(body_data.get("mu_km3_s2", 0.0))

	body_def.map_icon = String(body_data.get("map_icon", ""))
	body_def.color_rgba = _parse_color(body_data.get("color_rgba", [1.0, 1.0, 1.0, 1.0]))

	body_def.map_tags = _to_string_array(body_data.get("map_tags", []))
	body_def.gameplay_tags = _to_string_array(body_data.get("gameplay_tags", []))

	body_def.motion = _build_motion_def(body_data.get("motion", {}))

	return body_def


func _build_motion_def(motion_data: Dictionary) -> BaseMotionDef:
	if motion_data.is_empty():
		push_warning("SolarSystemDataLoader: missing motion data")
		return null

	var model: String = String(motion_data.get("model", ""))
	var params: Dictionary = motion_data.get("params", {})

	match model:
		"fixed":
			return _build_fixed_motion_def(params)

		"circular":
			return _build_circular_motion_def(params)

		"kepler2d":
			return _build_kepler2d_motion_def(params)

		_:
			push_warning("SolarSystemDataLoader: unknown motion model '%s'" % model)
			return null


func _build_fixed_motion_def(params: Dictionary) -> FixedMotionDef:
	var def := FixedMotionDef.new()

	def.x_km = float(params.get("x_km", 0.0))
	def.y_km = float(params.get("y_km", 0.0))

	return def


func _build_circular_motion_def(params: Dictionary) -> CircularMotionDef:
	var def := CircularMotionDef.new()

	def.orbital_radius_km = float(params.get("orbital_radius_km", 0.0))
	def.phase_rad = float(params.get("phase_rad", 0.0))
	def.period_s = float(params.get("period_s", 0.0))
	def.clockwise = bool(params.get("clockwise", false))

	return def


func _build_kepler2d_motion_def(params: Dictionary) -> Kepler2DMotionDef:
	var def := Kepler2DMotionDef.new()

	def.a_km = float(params.get("a_km", 0.0))
	def.e = float(params.get("e", 0.0))
	def.arg_pe_rad = float(params.get("arg_pe_rad", 0.0))
	def.mean_anomaly_epoch_rad = float(params.get("mean_anomaly_epoch_rad", 0.0))
	def.epoch_tt_s = float(params.get("epoch_tt_s", 0.0))
	def.clockwise = bool(params.get("clockwise", false))

	return def


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []

	if typeof(value) != TYPE_ARRAY:
		return result

	for entry in value:
		result.append(String(entry))

	return result


func _parse_color(value) -> Color:
	if value is Color:
		return value

	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value

		if arr.size() >= 4:
			return Color(
				float(arr[0]),
				float(arr[1]),
				float(arr[2]),
				float(arr[3])
			)

		if arr.size() == 3:
			return Color(
				float(arr[0]),
				float(arr[1]),
				float(arr[2]),
				1.0
			)

	return Color.WHITE