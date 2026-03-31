## GameObjectRegistry
## Central cache and API for all GameObjects
## Extends: Node

class_name GameObjectRegistry
extends Node

## Public Properties
var game_objects: Dictionary : get = get_game_objects

## Signals (for future lazy loading implementation)
# signal game_object_loaded(id: String)
# signal game_data_loaded(id: String)

## Private
var _game_objects: Dictionary = {}
# var _data_loader: DataLoader  # Reserved for future lazy loading

## Public Methods
func register_game_object(obj: GameObject) -> void:
	"""Register a GameObject"""
	_game_objects[obj.id] = obj

func get_game_object(id: String) -> GameObject:
	"""Get GameObject by ID"""
	return _game_objects.get(id, null)

func get_all_objects() -> Array[GameObject]:
	"""Get all GameObjects"""
	return _game_objects.values() as Array[GameObject]

func get_objects_in_group(_group: String) -> Array[GameObject]:
	"""Get all objects in a group (TODO: implement group membership)"""
	var result: Array[GameObject] = []
	for obj in _game_objects.values():
		# TODO: Check group membership
		pass
	return result

func get_all_body_defs() -> Array[BodyDef]:
	"""Get BodyDef from all registered GameObjects"""
	var body_defs: Array[BodyDef] = []
	for obj in _game_objects.values():
		if obj and obj.body_def:
			body_defs.append(obj.body_def)
	return body_defs

func clear_cache() -> void:
	"""Clear the cache"""
	_game_objects.clear()

## Getters
func get_game_objects() -> Dictionary:
	return _game_objects
