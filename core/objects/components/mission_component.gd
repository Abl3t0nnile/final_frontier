## MissionComponent
## Missionen für Objekte
## Erweitert: GameDataComponent

class_name MissionComponent
extends GameDataComponent

## Public Properties
var has_missions: bool : get = get_has_missions

## Private
var _has_missions: bool = false

## Getters
func get_has_missions() -> bool:
	return _has_missions
