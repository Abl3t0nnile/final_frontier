## MiniMapController
## Reduced map for overview
## Extends: MapController

class_name MiniMapController
extends MapController

## Public Methods
func set_readonly_mode() -> void:
	"""Set mode to read-only"""
	# TODO: Disable interaction
	pass

func set_aggressive_culling() -> void:
	"""Activate aggressive culling for performance"""
	# TODO: Setup aggressive culling
	pass

func sync_with_main_camera(main_transform: MapTransform) -> void:
	"""Synchronize with main camera"""
	# TODO: Sync camera position and zoom
	pass
