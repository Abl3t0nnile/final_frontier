## SolarSystemModel
## Zentrale Berechnung aller Objekt-Positionen und Zustands-Management
## Erweitert: Node

class_name SolarSystemModel
extends Node

## Public Properties
var clock: SimClock : get = get_clock
var game_objects: Array[GameObject] : get = get_game_objects

## Signals
signal simulation_updated()
signal object_position_changed(id: String, position: Vector2)

## Private
var _clock: SimClock
var _game_objects: Array[GameObject] = []

## Public Methods
func setup(clck: SimClock, objs: Array[GameObject]) -> void:
	"""Initialisiert Model mit Uhr und Objekten"""
	_clock = clck
	_game_objects = objs
	
	# Mit Uhr verbinden
	if _clock:
		_clock.tick.connect(_on_clock_tick)

func update_positions(delta: float) -> void:
	"""Aktualisiert alle Positionen basierend auf delta"""
	for obj in _game_objects:
		if obj.body_def.has_motion():
			# TODO: Calculate new position using SpaceMath
			var new_pos = Vector2.ZERO  # Placeholder
			obj.position = new_pos
			object_position_changed.emit(obj.id, new_pos)
	
	simulation_updated.emit()

func get_object_position_at_time(id: String, time: float) -> Vector2:
	"""Berechnet Position zu bestimmter Zeit (für Zeitreisen)"""
	# TODO: Implement time-based position calculation
	return Vector2.ZERO

func get_object_position(id: String) -> Vector2:
	"""Holt aktuelle Position eines Objekts"""
	for obj in _game_objects:
		if obj.id == id:
			return get_object_position_at_time(id, _clock.current_time)
	return Vector2.ZERO

func get_children_of(parent_id: String) -> Array[String]:
	"""Holt alle Kinder eines Objekts"""
	var children: Array[String] = []
	for obj in _game_objects:
		if obj.parent == parent_id:
			children.append(obj.id)
	return children

## Private Methods
func _on_clock_tick(delta: float) -> void:
	update_positions(delta)

## Getters
func get_clock() -> SimClock:
	return _clock

func get_game_objects() -> Array[GameObject]:
	return _game_objects
