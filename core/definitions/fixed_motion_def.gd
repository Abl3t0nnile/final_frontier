# fixed_motion_def.gd
class_name FixedMotionDef
extends BaseMotionDef

# Feste X-Position relativ zum Bezugssystem in Kilometern.
var _x_km: float = 0.0
# Feste Y-Position relativ zum Bezugssystem in Kilometern.
var _y_km: float = 0.0

var x_km: float : get = get_x_km, set = _set_x_km
var y_km: float : get = get_y_km, set = _set_y_km

func _init() -> void:
	_model = "fixed"

func get_x_km() -> float:
	return _x_km

func _set_x_km(_value: float) -> void: pass

func get_y_km() -> float:
	return _y_km

func _set_y_km(_value: float) -> void: pass