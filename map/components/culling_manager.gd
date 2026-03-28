## CullingManager
## Performance-Optimierung durch Culling
## Erweitert: Node

class_name CullingManager
extends Node

## Culling modes
enum CullingMode {
	NONE,
	VIEWPORT,
	PROXIMITY,
	HYBRID
}

## Public Properties
var culling_mode: CullingMode : get = get_mode, set = set_mode

## Private
var _mode: CullingMode = CullingMode.HYBRID
var _viewport_size: Vector2
var _camera_pos: Vector2
var _zoom: float
var _culling_distance: float = 10000.0  # km

## Public Methods
func update_culling(camera_pos: Vector2, viewport_size_px: Vector2, zoom: float) -> void:
	"""Aktualisiert Culling basierend auf Kamera-Zustand"""
	_camera_pos = camera_pos
	_viewport_size = viewport_size_px
	_zoom = zoom
	
	# TODO: Update visibility of entities based on culling mode

func is_entity_visible(id: String) -> bool:
	"""Prüft ob Entität sichtbar ist"""
	match _mode:
		CullingMode.NONE:
			return true
		CullingMode.VIEWPORT:
			return _is_in_viewport(id)
		CullingMode.PROXIMITY:
			return _is_in_proximity(id)
		CullingMode.HYBRID:
			return _is_in_viewport(id) or _is_in_proximity(id)
	return true

func set_culling_mode(mode: CullingMode) -> void:
	"""Setzt Culling-Modus"""
	_mode = mode

## Private Methods
func _is_in_viewport(id: String) -> bool:
	"""Prüft ob Entität im Viewport ist"""
	# TODO: Check if entity is within viewport bounds
	return true

func _is_in_proximity(id: String) -> bool:
	"""Prüft ob Entität in der Nähe ist"""
	# TODO: Check distance to camera
	return true

## Getters
func get_mode() -> CullingMode:
	return _mode
