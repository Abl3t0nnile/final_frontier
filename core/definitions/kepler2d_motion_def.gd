## Kepler2DMotionDef
## Physikalisch korrekte Ellipsenbahn in der Ebene
## Erweitert: BaseMotionDef

class_name Kepler2DMotionDef
extends BaseMotionDef

## Public Properties
var semi_major_axis_km: float : get = get_semi_major_axis_km
var eccentricity: float : get = get_eccentricity
var argument_of_periapsis_rad: float : get = get_argument_of_periapsis_rad
var mean_anomaly_epoch_rad: float : get = get_mean_anomaly_epoch_rad
var epoch_time_s: float : get = get_epoch_time_s
var orbit_direction: int : get = get_orbit_direction  # +1 prograd, -1 retrograd

## Private
var _semi_major_axis_km: float = 0.0
var _eccentricity: float = 0.0
var _argument_of_periapsis_rad: float = 0.0
var _mean_anomaly_epoch_rad: float = 0.0
var _epoch_time_s: float = 0.0
var _orbit_direction: int = 1

## Constructor
func _init() -> void:
	_model = "kepler2d"

## Getters
func get_semi_major_axis_km() -> float:
	return _semi_major_axis_km

func get_eccentricity() -> float:
	return _eccentricity

func get_argument_of_periapsis_rad() -> float:
	return _argument_of_periapsis_rad

func get_mean_anomaly_epoch_rad() -> float:
	return _mean_anomaly_epoch_rad

func get_epoch_time_s() -> float:
	return _epoch_time_s

func get_orbit_direction() -> int:
	return _orbit_direction
