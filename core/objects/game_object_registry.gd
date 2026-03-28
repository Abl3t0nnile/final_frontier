## GameObjectRegistry
## Zentraler Cache und API für alle GameObjects
## Erweitert: Node

class_name GameObjectRegistry
extends Node

## Public Properties
var game_objects: Dictionary : get = get_game_objects

## Signals
signal game_object_loaded(id: String)
signal game_data_loaded(id: String)

## Private
var _game_objects: Dictionary = {}
var _data_loader: DataLoader

## Public Methods
func register_game_object(obj: GameObject) -> void:
	"""Registriert ein GameObject"""
	_game_objects[obj.id] = obj

func get_game_object(id: String) -> GameObject:
	"""Holt GameObject per ID"""
	return _game_objects.get(id, null)

func get_all_objects() -> Array[GameObject]:
	"""Holt alle GameObjects"""
	return _game_objects.values()

func get_objects_in_group(group: String) -> Array[GameObject]:
	"""Holt alle Objekte einer Gruppe"""
	var result: Array[GameObject] = []
	for obj in _game_objects.values():
		# TODO: Check group membership
		pass
	return result

func clear_cache() -> void:
	"""Leert den Cache"""
	_game_objects.clear()

## Getters
func get_game_objects() -> Dictionary:
	return _game_objects
