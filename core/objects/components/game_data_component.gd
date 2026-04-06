## GameDataComponent
## Basisklasse für Gameplay-Komponenten
## Erweitert: Resource

class_name GameDataComponent
extends Resource

## Public Properties
var component_id: String
var is_loaded: bool : get = get_is_loaded

## Private
var _is_loaded: bool = false

## Public Methods
func load_data() -> void:
	"""Lädt Komponenten-Daten"""
	# TODO: Implement data loading
	_is_loaded = true

func save_data() -> void:
	"""Speichert Komponenten-Daten"""
	# TODO: Implement data saving
	pass

## Getters
func get_is_loaded() -> bool:
	return _is_loaded
