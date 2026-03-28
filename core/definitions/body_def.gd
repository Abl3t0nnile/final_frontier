## BodyDef
## Pure Datenstruktur für physikalische Eigenschaften von Himmelskörpern
## Erweitert: RefCounted

class_name BodyDef
extends RefCounted

## Public Properties
var id: String : get = get_id
var name: String : get = get_name
var type: String : get = get_type
var subtype: String : get = get_subtype
var parent_id: String : get = get_parent_id
var body_radius_km: float : get = get_body_radius_km
var grav_param_km3_s2: float : get = get_grav_param_km3_s2
var map_icon: String : get = get_map_icon
var color_rgba: Color : get = get_color_rgba
var motion: BaseMotionDef : get = get_motion
var map_tags: Array[String] : get = get_map_tags

## Private
var _id: String = ""
var _name: String = ""
var _type: String = ""
var _subtype: String = ""
var _parent_id: String = ""
var _body_radius_km: float = 0.0
var _grav_param_km3_s2: float = 0.0
var _map_icon: String = ""
var _color_rgba: Color = Color.WHITE
var _motion: BaseMotionDef = null
var _map_tags: Array[String] = []

## Public Methods
func is_root() -> bool:
	"""Prüft ob dies ein Wurzelobjekt ist (kein Parent)"""
	return _parent_id.is_empty()

func has_motion() -> bool:
	"""Prüft ob Bewegungsdefinition vorhanden"""
	return _motion != null

## Getters
func get_id() -> String:
	return _id

func get_name() -> String:
	return _name

func get_type() -> String:
	return _type

func get_subtype() -> String:
	return _subtype

func get_parent_id() -> String:
	return _parent_id

func get_body_radius_km() -> float:
	return _body_radius_km

func get_grav_param_km3_s2() -> float:
	return _grav_param_km3_s2

func get_map_icon() -> String:
	return _map_icon

func get_color_rgba() -> Color:
	return _color_rgba

func get_motion() -> BaseMotionDef:
	return _motion

func get_map_tags() -> Array[String]:
	return _map_tags.duplicate()
