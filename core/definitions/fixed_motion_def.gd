## FixedMotionDef
## Stationäre Position relativ zum Elternkörper
## Erweitert: BaseMotionDef

class_name FixedMotionDef
extends BaseMotionDef

## Public Properties
var x_km: float : get = get_x_km
var y_km: float : get = get_y_km

## Private
var _x_km: float = 0.0
var _y_km: float = 0.0

## Constructor
func _init() -> void:
	_model = "fixed"

## Getters
func get_x_km() -> float:
	return _x_km

func get_y_km() -> float:
	return _y_km
