## SolarMapController
## Konfiguriert MapController für die Sonnensystem-Ansicht.
## Alle Features (Orbits, Grid, Belts, Zones) sind aktiviert.
## Definiert spezifisches Kamera- und Follow-Verhalten.

class_name SolarMapController
extends MapController


func _init() -> void:
	# Solar-spezifische Defaults
	has_orbits = true
	has_grid   = true
	has_belts  = true
	has_zones  = true
	has_rings  = true


## Setup (Solar-spezifisch)

func setup(model: SolarSystemModel, clock: SimClock, config: MapConfig) -> void:
	super.setup(model, clock, config)
	# Follow bei Selektion starten/stoppen
	_interaction_manager.body_selected.connect(_follow_manager.start_following)
	_interaction_manager.body_deselected.connect(_follow_manager.stop_following)
	# Nach Unpin/Deselect: Positionen und Culling neu berechnen
	_interaction_manager.body_unpinned.connect(_refresh_culling)
	_interaction_manager.body_deselected.connect(_refresh_culling)


## Signal-Handler (Solar-spezifisch)

func _on_clock_tick(_time: float) -> void:
	_entity_manager.update_all_positions()
	_follow_manager.update_camera_position()
	_update_features()


func _on_camera_moved(cam_pos: Vector2) -> void:
	_world_root.position = -cam_pos + get_viewport_rect().size * 0.5
	if has_grid and _grid != null:
		_grid.queue_redraw()


func _on_zoom_changed(km_per_px: float) -> void:
	_entity_manager.update_all_positions()
	_follow_manager.update_camera_position()  # Marker zentriert halten während Zoom
	_culling_manager.update_marker_sizes(_map_transform.zoom_exp)
	_culling_manager.apply_culling(
		_interaction_manager.get_selected_entity(),
		_interaction_manager.get_pinned_entities()
	)
	_update_features_zoom(km_per_px)


func _on_panned() -> void:
	_follow_manager.stop_following()
	_interaction_manager.deselect_current()


func _refresh_culling(_id: String = "") -> void:
	_entity_manager.update_all_positions()
	_culling_manager.apply_culling(
		_interaction_manager.get_selected_entity(),
		_interaction_manager.get_pinned_entities()
	)
