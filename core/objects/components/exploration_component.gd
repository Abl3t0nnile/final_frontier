## ExplorationComponent
## Erkundungs-Features für Objekte
## Erweitert: GameDataComponent

class_name ExplorationComponent
extends GameDataComponent

## Public Properties
var is_discovered: bool : get = get_is_discovered

## Private
var _is_discovered: bool = false

## Getters
func get_is_discovered() -> bool:
	return _is_discovered
