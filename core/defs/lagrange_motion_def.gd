# lagrange_motion_def.gd
class_name LagrangeMotionDef
extends BaseMotionDef

# ID des Primärkörpers (z.B. Stern)
var _primary_id: String = ""
# ID des Sekundärkörpers (z.B. Planet)
var _secondary_id: String = ""
# Lagrange-Punkt: 1, 2, 3, 4 oder 5
var _point: int = 1

var primary_id: String : get = get_primary_id, set = _set_primary_id
var secondary_id: String : get = get_secondary_id, set = _set_secondary_id
var point: int : get = get_point, set = _set_point

func _init() -> void:
    _model = "lagrange"

func get_primary_id() -> String:
    return _primary_id
func _set_primary_id(_value: String) -> void: pass

func get_secondary_id() -> String:
    return _secondary_id
func _set_secondary_id(_value: String) -> void: pass

func get_point() -> int:
    return _point
func _set_point(_value: int) -> void: pass