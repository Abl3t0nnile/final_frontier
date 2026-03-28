## MiniMapController
## Reduzierte Karte für Übersicht
## Erweitert: MapController

class_name MiniMapController
extends MapController

## Public Methods
func set_readonly_mode() -> void:
	"""Setzt Modus auf nur lesen"""
	# TODO: Disable interaction
	pass

func set_aggressive_culling() -> void:
	"""Aktiviert aggressives Culling für Performance"""
	# TODO: Setup aggressive culling
	pass

func sync_with_main_camera(main_transform: MapTransform) -> void:
	"""Synchronisiert mit Hauptkamera"""
	# TODO: Sync camera position and zoom
	pass
