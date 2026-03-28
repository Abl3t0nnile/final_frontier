## SolarMapController
## Spezialisiert für Solar System Karte
## Erweitert: MapController

class_name SolarMapController
extends MapController

## Public Properties
var belt_manager: BeltManager : get = get_belt_manager
var zone_manager: ZoneManager : get = get_zone_manager
var follow_manager: FollowManager : get = get_follow_manager

## Private
var _belt_manager: BeltManager
var _zone_manager: ZoneManager
var _follow_manager: FollowManager

## Public Methods
func enable_time_travel() -> void:
	"""Aktiviert Zeitreise-Funktion"""
	# TODO: Enable time travel UI and logic
	pass

func set_time_display_mode(mode: TimeDisplayMode) -> void:
	"""Setzt Zeit-Anzeige-Modus"""
	# TODO: Set time display mode
	pass

## Getters
func get_belt_manager() -> BeltManager:
	return _belt_manager

func get_zone_manager() -> ZoneManager:
	return _zone_manager

func get_follow_manager() -> FollowManager:
	return _follow_manager
