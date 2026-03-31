## EntityManager
## Erstellt und verwaltet MapMarker für alle GameObjects

class_name EntityManager
extends Node

const MARKER_SCENE := preload("res://map/markers/map_marker.tscn")

signal entity_hovered(id: String)
signal entity_selected(id: String)

var markers: Dictionary : get = get_markers

var _markers: Dictionary = {}  # id -> MapMarker
var _model: SolarSystemModel = null
var _map_transform: MapTransform = null
var _world_root: Node2D = null

func setup(model: SolarSystemModel, map_transform: MapTransform, world_root: Node2D) -> void:
	_model        = model
	_map_transform = map_transform
	_world_root   = world_root

func create_marker(game_object: GameObject) -> MapMarker:
	var marker := MARKER_SCENE.instantiate() as MapMarker
	_world_root.add_child(marker)
	marker.setup(game_object, null)
	_markers[game_object.id] = marker
	return marker

func update_all_positions() -> void:
	for id in _markers:
		var pos_km: Vector2 = _model.get_body_position(id)
		var pos_px: Vector2 = _map_transform.km_to_px(pos_km)
		_markers[id].update_position(pos_px)

func get_marker(id: String) -> MapMarker:
	return _markers.get(id, null)

func get_markers() -> Dictionary:
	return _markers
