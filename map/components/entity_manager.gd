## EntityManager
## Verwaltung aller visuellen Entitäten
## Erweitert: Node

class_name EntityManager
extends Node

## Public Properties
var markers: Dictionary : get = get_markers

## Signals
signal entity_hovered(id: String)
signal entity_selected(id: String)

## Private
var _markers: Dictionary = {}  # id -> MapMarker
var _game_object_registry: GameObjectRegistry

## Public Methods
func create_marker(game_object: GameObject) -> MapMarker:
	"""Erstellt neuen Marker für GameObject"""
	var marker = MapMarker.new()
	add_child(marker)
	
	# TODO: Setup marker with game_object
	marker.setup(game_object, null)  # TODO: Get label_settings
	
	_markers[game_object.id] = marker
	return marker

func update_all_positions() -> void:
	"""Aktualisiert alle Marker-Positionen"""
	for id in _markers:
		var marker = _markers[id]
		var game_object = _game_object_registry.get_game_object(id)
		if game_object:
			marker.update_position(game_object.position)

func get_marker(id: String) -> MapMarker:
	"""Holt Marker per ID"""
	return _markers.get(id, null)

func get_markers_in_group(group: String) -> Array[MapMarker]:
	"""Holt alle Marker einer Gruppe"""
	var result: Array[MapMarker] = []
	# TODO: Filter by group
	return result

## Getters
func get_markers() -> Dictionary:
	return _markers
