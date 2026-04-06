## GameObject
## Vereinigt BodyDef mit optionalen Gameplay-Daten
## Erweitert: RefCounted

class_name GameObject
extends RefCounted

## Public Properties
var id: String : get = get_id
var body_def: BodyDef : get = get_body_def
var children: Array[String] : get = get_children
var parent: String : get = get_parent

## Private
var _id: String
var _body_def: BodyDef
var _components: Dictionary = {}  # String -> GameDataComponent
var _children: Array[String] = []
var _parent: String = ""

## Constructor
func init(body: BodyDef) -> GameObject:
	_id = body.id
	_body_def = body
	return self

## Public Methods
func has_component(type: String) -> bool:
	"""Prüft ob Komponente vorhanden"""
	return _components.has(type)

func get_component(type: String) -> GameDataComponent:
	"""Holt spezifische Komponente"""
	return _components.get(type, null)

func add_component(type: String, component: GameDataComponent) -> void:
	"""Fügt Komponente hinzu"""
	_components[type] = component

func remove_component(type: String) -> void:
	"""Entfernt Komponente"""
	_components.erase(type)

func get_all_components() -> Array[GameDataComponent]:
	"""Gibt alle Komponenten zurück"""
	var result: Array[GameDataComponent] = []
	for comp in _components.values():
		result.append(comp)
	return result

## Getters
func get_id() -> String:
	return _id

func get_body_def() -> BodyDef:
	return _body_def

func get_children() -> Array[String]:
	return _children

func get_parent() -> String:
	return _parent
