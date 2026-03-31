## SolarMapController
## Configures MapController for solar system view.
## All features (Orbits, Grid, Belts, Zones) are enabled.
## Defines specific camera and follow behavior.

class_name SolarMapController
extends MapController


func _init() -> void:
	# Solar-specific defaults
	has_orbits = true
	has_grid   = true
	has_belts  = true
	has_zones  = true
	has_rings  = true


## Setup (Solar-specific)

func setup(model: SolarSystemModel, clock: SimClock, config: MapConfig) -> void:
	super.setup(model, clock, config)
	# Follow start/stop on selection
	_interaction_manager.body_selected.connect(_follow_manager.start_following)
	_interaction_manager.body_deselected.connect(_follow_manager.stop_following)
	# Refresh positions and culling on unpin/deselect
	_interaction_manager.body_unpinned.connect(_refresh_culling)
	_interaction_manager.body_deselected.connect(_refresh_culling)


## Signal handlers (Solar-specific)

func _on_map_time_updated(time: float) -> void:
	"""Override to add solar-specific updates"""
	# Call parent for base updates
	super._on_map_time_updated(time)
	# Add solar-specific updates
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
