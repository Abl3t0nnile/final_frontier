## MapController
## Modularer Basis-Controller für alle Karten-Typen
## Erweitert: Node2D

class_name MapController
extends Node2D

## Public Properties
var map_transform: MapTransform : get = get_map_transform
var entity_manager: EntityManager : get = get_entity_manager
var culling_manager: CullingManager : get = get_culling_manager
var interaction_manager: InteractionManager : get = get_interaction_manager

## Signals
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)
signal body_pinned(id: String)
signal body_unpinned(id: String)

## Private
var _map_transform: MapTransform
var _entity_manager: EntityManager
var _culling_manager: CullingManager
var _interaction_manager: InteractionManager
var _pinned_bodies: Array[String] = []
var _selected_body: String = ""

## Public Methods
func setup(model: SolarSystemModel, clock: SimClock, config: MapConfig) -> void:
	"""Initialisiert Map-Controller"""
	# TODO: Setup all managers and connections
	pass

func select_body(id: String) -> void:
	"""Selektiert einen Körper"""
	_selected_body = id
	# TODO: Update marker state
	body_selected.emit(id)

func deselect_body() -> void:
	"""Deselektiert aktuellen Körper"""
	_selected_body = ""
	# TODO: Update marker state
	body_deselected.emit()

func focus_body(id: String) -> void:
	"""Fokussiert auf bestimmten Körper"""
	# TODO: Implement camera focus
	pass

func pin_body(id: String) -> void:
	"""Pinned einen Körper (immer sichtbar)"""
	if id not in _pinned_bodies:
		_pinned_bodies.append(id)
		# TODO: Update marker state to PINNED
		# TODO: Ensure marker is always visible
		body_pinned.emit(id)

func unpin_body(id: String) -> void:
	"""Entpinned einen Körper"""
	_pinned_bodies.erase(id)
	# TODO: Update marker state from PINNED
	# TODO: Apply normal visibility rules
	body_unpinned.emit(id)

func is_body_pinned(id: String) -> bool:
	"""Prüft ob Körper gepinned ist"""
	return id in _pinned_bodies

func get_pinned_bodies() -> Array[String]:
	"""Holt alle gepinnten Körper"""
	return _pinned_bodies.duplicate()

func get_selected_body() -> String:
	"""Holt ID des selektierten Körpers"""
	return _selected_body

## Getters
func get_map_transform() -> MapTransform:
	return _map_transform

func get_entity_manager() -> EntityManager:
	return _entity_manager

func get_culling_manager() -> CullingManager:
	return _culling_manager

func get_interaction_manager() -> InteractionManager:
	return _interaction_manager
