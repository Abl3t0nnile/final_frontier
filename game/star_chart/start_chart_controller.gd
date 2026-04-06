## StartChartController
## UI-Layer für die StarChart-Szene.
## Empfängt die fertige SolarMap von GameController via receive_solar_map().
## Delegiert Overlay, Clock und Nav an eigene Komponenten-Scripts.

extends Node

## SubViewport — SolarMap wird hier eingehängt
@onready var _subviewport: SubViewport = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport

## Komponenten
@onready var _clock_control = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl
@onready var _nav_panel     = $UILayer/MainDisplay/VFrame/BodyPanel/NavPanel
@onready var _info_panel    = $UILayer/MainDisplay/VFrame/BodyPanel/InfoPanel
@onready var _map_overlay   = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/MapOverlay

var _solar_map: Node = null


## Wird von GameController aufgerufen sobald SolarMap bereit ist.
func receive_solar_map(map: Node) -> void:
	_solar_map = map
	_subviewport.add_child(map)
	map.setup()
	_clock_control.setup(map)
	_nav_panel.setup(map)
	_map_overlay.setup(map)
	_subviewport.size_changed.connect(_on_viewport_resized)
	if map.has_signal("body_selected"):
		map.body_selected.connect(_on_body_selected)
	if map.has_signal("body_deselected"):
		map.body_deselected.connect(_on_body_deselected)


func _on_body_selected(id: String) -> void:
	_info_panel.load_body(id)
	_info_panel.visible = true


func _on_body_deselected() -> void:
	_info_panel.clear()
	_info_panel.visible = false


func _on_viewport_resized() -> void:
	# Einen weiteren Frame warten bis der Viewport die finale Größe hat
	await get_tree().process_frame
	if _solar_map:
		var map_transform: MapTransform = _solar_map.get_map_controller().get_map_transform()
		if map_transform:
			map_transform.camera_moved.emit(map_transform.cam_pos_px)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_nav_panel.visible = not _nav_panel.visible
		if event.keycode == KEY_I:
			_info_panel.visible = not _info_panel.visible
