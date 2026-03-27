# body_def.gd
class_name BodyDef
extends RefCounted

# Eindeutige technische ID des Himmelskörpers.
var _id: String = ""
# Anzeigename des Himmelskörpers.
var _name: String = ""
# Haupttyp, z. B. star, planet, moon, station.
var _type: String = ""
# Optionaler Untertyp zur feineren Kategorisierung.
var _subtype: String = ""
# ID des übergeordneten Körpers; leer bei einem Wurzelobjekt.
var _parent_id: String = ""
# Physischer Radius des Körpers in Kilometern.
var _radius_km: float = 0.0
# Standard-Gravitationsparameter μ in km^3 / s^2.
var _mu_km3_s2: float = 0.0
# Symbolname für die Kartendarstellung.
var _map_icon: String = ""
# Kartenfarbe des Körpers inklusive Alpha-Kanal.
var _color_rgba: Color = Color.WHITE
# Bewegungsdefinition des Körpers.
var _motion: BaseMotionDef = null
# Tags für Filterung, Darstellung und Kartengruppierung.
var _map_tags: Array[String] = []
# Tags für Gameplay-Logik und Systemeinordnung.
var _gameplay_tags: Array[String] = []


var id: String : get = get_id, set = _set_id
var name: String : get = get_name, set = _set_name
var type: String : get = get_type, set = _set_type
var subtype: String : get = get_subtype, set = _set_subtype
var parent_id: String : get = get_parent_id, set = _set_parent_id
var radius_km: float : get = get_radius_km, set = _set_radius_km
var mu_km3_s2: float : get = get_mu_km3_s2, set = _set_mu_km3_s2
var map_icon: String : get = get_map_icon, set = _set_map_icon
var color_rgba: Color : get = get_color_rgba, set = _set_color_rgba
var motion: BaseMotionDef : get = get_motion, set = _set_motion
var map_tags: Array[String] : get = get_map_tags, set = _set_map_tags
var gameplay_tags: Array[String] : get = get_gameplay_tags, set = _set_gameplay_tags

func get_id() -> String:
	return _id

func _set_id(_value: String) -> void: pass

func get_name() -> String:
	return _name

func _set_name(_value: String) -> void: pass

func get_type() -> String:
	return _type

func _set_type(_value: String) -> void: pass

func get_subtype() -> String:
	return _subtype

func _set_subtype(_value: String) -> void: pass

func get_parent_id() -> String:
	return _parent_id

func _set_parent_id(_value: String) -> void: pass

func get_radius_km() -> float:
	return _radius_km

func _set_radius_km(_value: float) -> void: pass

func get_mu_km3_s2() -> float:
	return _mu_km3_s2

func _set_mu_km3_s2(_value: float) -> void: pass

func get_map_icon() -> String:
	return _map_icon

func _set_map_icon(_value: String) -> void: pass

func get_color_rgba() -> Color:
	return _color_rgba

func _set_color_rgba(_value: Color) -> void: pass

func get_motion() -> BaseMotionDef:
	return _motion

func _set_motion(_value: BaseMotionDef) -> void: pass

func get_map_tags() -> Array[String]:
	return _map_tags.duplicate()

func _set_map_tags(_value: Array[String]) -> void: pass

func get_gameplay_tags() -> Array[String]:
	return _gameplay_tags.duplicate()

func _set_gameplay_tags(_value: Array[String]) -> void: pass

func is_root() -> bool:
	return _parent_id.is_empty()

func has_motion() -> bool:
	return _motion != null