## InteractionManager
## User-Interaktionen mit der Karte
## Erweitert: Node

class_name InteractionManager
extends Node

## Interaction modes
enum InteractionMode {
	SELECT,
	PAN,
	MEASURE,
	TIME_TRAVEL
}

## Public Properties
var selected_entity: String : get = get_selected_entity
var hovered_entity: String : get = get_hovered_entity

## Signals
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)

## Private
var _selected_id: String = ""
var _hovered_id: String = ""
var _mode: InteractionMode = InteractionMode.SELECT
var _entity_manager: EntityManager

## Public Methods
func handle_input(event: InputEvent) -> void:
	"""Verarbeitet User-Input"""
	# TODO: Handle mouse clicks, drags, keyboard
	pass

func select_entity(id: String) -> void:
	"""Selektiert Entität"""
	if _selected_id != "":
		deselect_current()
	
	_selected_id = id
	body_selected.emit(id)
	
	# TODO: Update visual state of marker

func deselect_current() -> void:
	"""Deselektiert aktuelle Entität"""
	if _selected_id != "":
		# TODO: Reset visual state
		_selected_id = ""
		body_deselected.emit()

func set_interaction_mode(mode: InteractionMode) -> void:
	"""Setzt Interaktions-Modus"""
	_mode = mode

## Getters
func get_selected_entity() -> String:
	return _selected_id

func get_hovered_entity() -> String:
	return _hovered_id
