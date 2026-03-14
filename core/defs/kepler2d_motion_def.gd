# kepler2d_motion_def.gd
class_name Kepler2DMotionDef
extends BaseMotionDef

# Große Halbachse der Ellipse in Kilometern.
var _a_km: float = 0.0
# Exzentrizität der Bahnform; 0 = Kreis, > 0 = Ellipse.
var _e: float = 0.0
# Argument des Periapsis in Radiant.
var _arg_pe_rad: float = 0.0
# Mittlere Anomalie zum Epochenzeitpunkt in Radiant.
var _mean_anomaly_epoch_rad: float = 0.0
# Epochenzeitpunkt der Bahndefinition in TT-Sekunden.
var _epoch_tt_s: float = 0.0
# Drehrichtung der Bahn; true = im Uhrzeigersinn.
var _clockwise: bool = false

var a_km: float : get = get_a_km, set = _set_a_km
var e: float : get = get_e, set = _set_e
var arg_pe_rad: float : get = get_arg_pe_rad, set = _set_arg_pe_rad
var mean_anomaly_epoch_rad: float : get = get_mean_anomaly_epoch_rad, set = _set_mean_anomaly_epoch_rad
var epoch_tt_s: float : get = get_epoch_tt_s, set = _set_epoch_tt_s
var clockwise: bool : get = is_clockwise, set = _set_clockwise

func _init() -> void:
	_model = "kepler2d"

func get_a_km() -> float:
	return _a_km

func _set_a_km(_value: float) -> void: pass

func get_e() -> float:
	return _e

func _set_e(_value: float) -> void: pass

func get_arg_pe_rad() -> float:
	return _arg_pe_rad

func _set_arg_pe_rad(_value: float) -> void: pass

func get_mean_anomaly_epoch_rad() -> float:
	return _mean_anomaly_epoch_rad

func _set_mean_anomaly_epoch_rad(_value: float) -> void: pass

func get_epoch_tt_s() -> float:
	return _epoch_tt_s

func _set_epoch_tt_s(_value: float) -> void: pass

func is_clockwise() -> bool:
	return _clockwise

func _set_clockwise(_value: bool) -> void: pass