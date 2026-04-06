## DataLoader
## Hybrid-Laden von JSON und .tres Dateien
## Erweitert: RefCounted

class_name DataLoader
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/solar_system_data.json"


## Public Methods
func load_core_data(path: String = DEFAULT_DATA_PATH) -> Array[BodyDef]:
	"""Lädt BodyDef Daten aus JSON"""
	var result: Array[BodyDef] = []
	var raw_data: Variant = _load_json_file(path)

	if typeof(raw_data) != TYPE_DICTIONARY:
		push_warning("DataLoader: root json is not a dictionary")
		return result

	var root: Dictionary = raw_data
	var raw_bodies: Variant = root.get("bodies", [])

	if typeof(raw_bodies) != TYPE_ARRAY:
		push_warning("DataLoader: 'bodies' is not an array")
		return result

	for entry in raw_bodies:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var body_def := _build_body_def(entry)
		if body_def != null:
			result.append(body_def)

	return result


func load_component(path: String) -> GameDataComponent:
	"""Lädt GameDataComponent aus .tres Datei"""
	if not ResourceLoader.exists(path):
		push_warning("DataLoader: resource not found '%s'" % path)
		return null
	return load(path) as GameDataComponent


func load_all_components(directory: String) -> Array[GameDataComponent]:
	"""Lädt alle Components aus Ordner"""
	var result: Array[GameDataComponent] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		push_warning("DataLoader: directory not found '%s'" % directory)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var comp := load_component(directory.path_join(file_name))
			if comp != null:
				result.append(comp)
		file_name = dir.get_next()

	return result


func save_component(component: GameDataComponent, path: String) -> void:
	"""Speichert GameDataComponent als .tres"""
	var error := ResourceSaver.save(component, path)
	if error != OK:
		push_error("DataLoader: failed to save component to '%s'" % path)


## Private Methods
func _load_json_file(data_path: String) -> Variant:
	if not FileAccess.file_exists(data_path):
		push_warning("DataLoader: file not found '%s'" % data_path)
		return {}

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_warning("DataLoader: failed to open '%s'" % data_path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error: Error = json.parse(json_text)

	if parse_error != OK:
		push_warning(
			"DataLoader: json parse error in '%s' at line %d: %s"
			% [data_path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	return json.data


func _build_body_def(body_data: Dictionary) -> BodyDef:
	if body_data.is_empty():
		return null

	var body_def := BodyDef.new()

	body_def._id = String(body_data.get("id", ""))
	body_def._name = String(body_data.get("name", ""))
	body_def._type = String(body_data.get("type", ""))
	body_def._subtype = String(body_data.get("subtype", ""))
	body_def._parent_id = String(body_data.get("parent_id", ""))
	body_def._body_radius_km = float(body_data.get("body_radius_km", 0.0))
	body_def._grav_param_km3_s2 = float(body_data.get("grav_param_km3_s2", 0.0))
	body_def._map_icon = String(body_data.get("map_icon", ""))
	body_def._color_rgba = _parse_color(body_data.get("color_rgba", [1.0, 1.0, 1.0, 1.0]))
	body_def._map_tags = _to_string_array(body_data.get("map_tags", []))
	body_def._motion = _build_motion_def(body_data.get("motion", {}))

	return body_def


func _build_motion_def(motion_data: Dictionary) -> BaseMotionDef:
	if motion_data.is_empty():
		return null

	var model: String = String(motion_data.get("model", ""))
	var params: Variant = motion_data.get("params", {})

	if typeof(params) != TYPE_DICTIONARY:
		push_warning("DataLoader: motion params are not a dictionary for model '%s'" % model)
		return null

	match model:
		"fixed":
			return _build_fixed_motion_def(params)
		"circular":
			return _build_circular_motion_def(params)
		"kepler2d":
			return _build_kepler2d_motion_def(params)
		"lagrange":
			return _build_lagrange_motion_def(params)
		_:
			push_warning("DataLoader: unknown motion model '%s'" % model)
			return null


func _build_fixed_motion_def(params: Dictionary) -> FixedMotionDef:
	var def := FixedMotionDef.new()
	def._x_km = float(params.get("x_km", 0.0))
	def._y_km = float(params.get("y_km", 0.0))
	return def


func _build_circular_motion_def(params: Dictionary) -> CircularMotionDef:
	var def := CircularMotionDef.new()
	def._orbital_radius_km = float(params.get("orbital_radius_km", 0.0))
	def._initial_phase_rad = float(params.get("initial_phase_rad", 0.0))
	def._orbital_period_s = float(params.get("orbital_period_s", 0.0))
	def._orbit_direction = int(params.get("orbit_direction", 1))
	return def


func _build_kepler2d_motion_def(params: Dictionary) -> Kepler2DMotionDef:
	var def := Kepler2DMotionDef.new()
	def._semi_major_axis_km = float(params.get("semi_major_axis_km", 0.0))
	def._eccentricity = float(params.get("eccentricity", 0.0))
	def._argument_of_periapsis_rad = float(params.get("argument_of_periapsis_rad", 0.0))
	def._mean_anomaly_epoch_rad = float(params.get("mean_anomaly_epoch_rad", 0.0))
	def._epoch_time_s = float(params.get("epoch_time_s", 0.0))
	def._orbit_direction = int(params.get("orbit_direction", 1))
	return def


func _build_lagrange_motion_def(params: Dictionary) -> LagrangeMotionDef:
	var def := LagrangeMotionDef.new()
	def._primary_id = String(params.get("primary_id", ""))
	def._secondary_id = String(params.get("secondary_id", ""))
	def._point = int(params.get("point", 1))
	return def


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(String(entry))
	return result


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
