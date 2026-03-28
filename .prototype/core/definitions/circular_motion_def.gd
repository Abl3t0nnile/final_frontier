# circular_motion_def.gd
class_name CircularMotionDef
extends BaseMotionDef

# Abstand zum Zentrum der Kreisbahn in Kilometern.
var _orbital_radius_km: float = 0.0
# Startwinkel auf der Bahn in Radiant.
var _phase_rad: float = 0.0
# Umlaufdauer in Sekunden.
var _period_s: float = 0.0
# Drehrichtung der Bahn; true = im Uhrzeigersinn.
var _clockwise: bool = false

var orbital_radius_km: float : get = get_orbital_radius_km, set = _set_orbital_radius_km
var phase_rad: float : get = get_phase_rad, set = _set_phase_rad
var period_s: float : get = get_period_s, set = _set_period_s
var clockwise: bool : get = is_clockwise, set = _set_clockwise

func _init() -> void:
	_model = "circular"

func get_orbital_radius_km() -> float:
	return _orbital_radius_km

func _set_orbital_radius_km(_value: float) -> void: pass

func get_phase_rad() -> float:
	return _phase_rad

func _set_phase_rad(_value: float) -> void: pass

func get_period_s() -> float:
	return _period_s

func _set_period_s(_value: float) -> void: pass

func is_clockwise() -> bool:
	return _clockwise

func _set_clockwise(_value: bool) -> void: pass