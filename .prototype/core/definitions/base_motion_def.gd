# base_motion_def.gd
class_name BaseMotionDef
extends RefCounted

# Interner Name des Bewegungsmodells, z. B. "fixed", "circular" oder "kepler2d".
var _model: String = ""

var model: String : get = get_model, set = _set_model

func get_model() -> String:
	return _model

func _set_model(_value: String) -> void: pass