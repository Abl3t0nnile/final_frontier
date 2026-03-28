## LagrangeMotionDef
## Position an Lagrange-Punkten zweier Referenzkörper
## Erweitert: BaseMotionDef

class_name LagrangeMotionDef
extends BaseMotionDef

## Public Properties
var primary_id: String : get = get_primary_id
var secondary_id: String : get = get_secondary_id
var point: int : get = get_point  # 1-5

## Private
var _primary_id: String = ""
var _secondary_id: String = ""
var _point: int = 1

## Constructor
func _init() -> void:
	_model = "lagrange"

## Getters
func get_primary_id() -> String:
	return _primary_id

func get_secondary_id() -> String:
	return _secondary_id

func get_point() -> int:
	return _point
