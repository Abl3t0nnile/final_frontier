## InteractionManager
## Verwaltet Selektion, Pinning und Hover-Zustand von Map-Entitäten.

class_name InteractionManager
extends Node

signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)
signal marker_unhovered(id: String)
signal body_pinned(id: String)
signal body_unpinned(id: String)

var _selected_id: String       = ""
var _hovered_id: String        = ""
var _pinned_ids: Array[String] = []

var _entity_manager: EntityManager = null
var _culling_manager: CullingManager = null


func setup(entity_manager: EntityManager, culling_manager: CullingManager) -> void:
	_entity_manager  = entity_manager
	_culling_manager = culling_manager


func select_entity(id: String) -> void:
	if _selected_id == id:
		return

	# Alten Marker zurücksetzen
	if _selected_id != "":
		var old_marker := _entity_manager.get_marker(_selected_id)
		if old_marker != null:
			old_marker.set_state(MapMarker.MarkerState.DEFAULT)

	_selected_id = id

	var marker := _entity_manager.get_marker(id)
	if marker != null:
		marker.set_state(MapMarker.MarkerState.SELECTED)

	_culling_manager.apply_culling(_selected_id, _pinned_ids)
	body_selected.emit(id)


func deselect_current() -> void:
	if _selected_id == "":
		return
	var marker := _entity_manager.get_marker(_selected_id)
	if marker != null:
		marker.set_state(MapMarker.MarkerState.DEFAULT)
	_selected_id = ""
	_culling_manager.apply_culling("", _pinned_ids)
	body_deselected.emit()


func pin_entity(id: String) -> void:
	if id in _pinned_ids:
		return
	_pinned_ids.append(id)
	_culling_manager.apply_culling(_selected_id, _pinned_ids)
	body_pinned.emit(id)


func unpin_entity(id: String) -> void:
	_pinned_ids.erase(id)
	var marker := _entity_manager.get_marker(id)
	if marker != null:
		marker.set_state(MapMarker.MarkerState.DEFAULT)
	_culling_manager.apply_culling(_selected_id, _pinned_ids)
	body_unpinned.emit(id)


func clear_all_pins() -> void:
	if _pinned_ids.is_empty():
		return
	var ids := _pinned_ids.duplicate()
	_pinned_ids.clear()
	_culling_manager.apply_culling(_selected_id, _pinned_ids)
	for id in ids:
		var marker := _entity_manager.get_marker(id)
		if marker != null:
			marker.set_state(MapMarker.MarkerState.DEFAULT)
		body_unpinned.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).keycode != KEY_P:
		return
	if _selected_id != "":
		if is_pinned(_selected_id):
			unpin_entity(_selected_id)
		else:
			pin_entity(_selected_id)
	else:
		clear_all_pins()
	get_viewport().set_input_as_handled()


func on_marker_hovered(id: String) -> void:
	_hovered_id = id
	marker_hovered.emit(id)


func on_marker_unhovered(_id: String) -> void:
	if _hovered_id == _id:
		_hovered_id = ""
		marker_unhovered.emit(_id)


func get_selected_entity() -> String:
	return _selected_id


func get_hovered_entity() -> String:
	return _hovered_id


func get_pinned_entities() -> Array[String]:
	return _pinned_ids.duplicate()


func is_pinned(id: String) -> bool:
	return id in _pinned_ids
