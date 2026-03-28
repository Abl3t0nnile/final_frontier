## CircularMotionDef
## Gleichförmige Kreisbewegung
## Erweitert: BaseMotionDef

class_name CircularMotionDef
extends BaseMotionDef

## Public Properties
var orbital_radius_km: float : get = get_orbital_radius_km
var initial_phase_rad: float : get = get_initial_phase_rad
var orbital_period_s: float : get = get_orbital_period_s
var orbit_direction: int : get = get_orbit_direction  # +1 prograd, -1 retrograd

## Private
var _orbital_radius_km: float = 0.0
var _initial_phase_rad: float = 0.0
var _orbital_period_s: float = 0.0
var _orbit_direction: int = 1

## Constructor
func _init() -> void:
	_model = "circular"

## Getters
func get_orbital_radius_km() -> float:
	return _orbital_radius_km

func get_initial_phase_rad() -> float:
	return _initial_phase_rad

func get_orbital_period_s() -> float:
	return _orbital_period_s

func get_orbit_direction() -> int:
	return _orbit_direction
