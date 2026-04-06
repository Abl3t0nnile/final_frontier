## StartChartController
## UI-Layer für die StarChart-Szene.
## Empfängt SolarMap und PlanetView von GameController.
## Delegiert Overlay, Clock und Nav an eigene Komponenten-Scripts.

extends Node

const _BASE := "UILayer/MainDisplay/VFrame/BodyPanel"

## Viewports
@onready var _map_subviewport:  SubViewport = $"UILayer/MainDisplay/VFrame/BodyPanel/MapView/SubViewportContainer/SubViewport"
@onready var _body_subviewport: SubViewport = $"UILayer/MainDisplay/VFrame/BodyPanel/BodyView/SubViewportContainer/SubViewport"

## Panels
@onready var _map_view:  Control = $"UILayer/MainDisplay/VFrame/BodyPanel/MapView"
@onready var _body_view: Control = $"UILayer/MainDisplay/VFrame/BodyPanel/BodyView"

## Komponenten
@onready var _clock_control       = $"UILayer/MainDisplay/VFrame/FooterPanel/ClockControl"
@onready var _nav_panel           = $"UILayer/MainDisplay/VFrame/BodyPanel/NavPanel"
@onready var _info_panel: InfoPanel = $"UILayer/MainDisplay/VFrame/BodyPanel/InfoPanel"
@onready var _map_overlay         = $"UILayer/MainDisplay/VFrame/BodyPanel/MapView/SubViewportContainer/SubViewport/MapOverlay"
@onready var _planet_view_overlay = $"UILayer/MainDisplay/VFrame/BodyPanel/BodyView/SubViewportContainer/PlanetViewOverlay"
@onready var _almanach_panel      = $"UILayer/MainDisplay/VFrame/BodyPanel/AlmanachPanel"

var _solar_map:        Node   = null
var _planet_view:      Node   = null
var _current_body_id:  String = ""


## Von GameController aufgerufen sobald SolarMap bereit ist.
func receive_solar_map(map: Node) -> void:
	_solar_map = map
	_map_subviewport.add_child(map)
	map.setup()
	_clock_control.setup(map)
	_nav_panel.setup(map)
	_nav_panel.body_focused.connect(_on_nav_body_focused)
	_map_overlay.setup(map)
	_map_subviewport.size_changed.connect(_on_viewport_resized)
	if map.has_signal("body_selected"):
		map.body_selected.connect(_on_body_selected)
	if map.has_signal("body_deselected"):
		map.body_deselected.connect(_on_body_deselected)
	_info_panel.almanach_requested.connect(_on_almanach_requested)
	_info_panel.zoom_requested.connect(_on_zoom_requested)
	_almanach_panel.zoom_requested.connect(_on_zoom_requested)
	_info_panel.pin_requested.connect(func(id: String) -> void:
		_solar_map.pin_body(id))
	_info_panel.unpin_requested.connect(func(id: String) -> void:
		_solar_map.unpin_body(id))
	map.body_pinned.connect(func(id: String) -> void:
		if id == _current_body_id:
			_info_panel.set_pinned(true))
	map.body_unpinned.connect(func(id: String) -> void:
		if id == _current_body_id:
			_info_panel.set_pinned(false))
	_planet_view_overlay.setup(map)
	_planet_view_overlay.close_requested.connect(_close_zoom)
	_planet_view_overlay.info_requested.connect(_on_planet_view_info_requested)


## Von GameController aufgerufen wenn PlanetView bereit ist.
func receive_planet_view(planet_view: Node) -> void:
	_planet_view = planet_view
	_body_subviewport.add_child(_planet_view)
	_planet_view_overlay.move_to_front()
	_body_view.visible = false


# ── Body-Selektion ─────────────────────────────────────────────────────────────

func _on_nav_body_focused(id: String) -> void:
	_current_body_id = id
	_info_panel.load_body(id)
	_info_panel.set_pinned(_solar_map.is_body_pinned(id))
	if _almanach_panel:
		_almanach_panel.open_body(id)
	if not (_almanach_panel and _almanach_panel.visible):
		_info_panel.visible = true
	if _body_view.visible and _planet_view != null:
		_planet_view.call("load_body", id)
		_planet_view_overlay.load_body(id)


func _on_body_selected(id: String) -> void:
	_current_body_id = id
	_info_panel.load_body(id)
	_info_panel.set_pinned(_solar_map.is_body_pinned(id))
	if _almanach_panel:
		_almanach_panel.open_body(id)
	if not (_almanach_panel and _almanach_panel.visible):
		_info_panel.visible = true


func _on_body_deselected() -> void:
	_current_body_id = ""
	_info_panel.clear()
	_info_panel.visible = false


# ── Panel-Übergänge ────────────────────────────────────────────────────────────

func _on_almanach_requested(id: String) -> void:
	_info_panel.visible = false
	if _almanach_panel:
		_almanach_panel.open_body(id)
		_almanach_panel.visible = true


func _on_zoom_requested(id: String) -> void:
	if _planet_view == null:
		return
	_planet_view.call("load_body", id)
	_planet_view_overlay.load_body(id)
	_body_view.visible = true
	_map_view.visible = false
	_planet_view_overlay.visible = true
	_info_panel.visible = false
	if _almanach_panel:
		_almanach_panel.open_body(id)
		_almanach_panel.visible = true


func _on_planet_view_info_requested(id: String) -> void:
	if _almanach_panel:
		_almanach_panel.open_body(id)
		_almanach_panel.visible = not _almanach_panel.visible
		if _almanach_panel.visible:
			_info_panel.visible = false


func _close_zoom(hide_almanach: bool = false) -> void:
	if not _body_view.visible:
		return
	_body_view.visible = false
	_planet_view_overlay.visible = false
	_map_view.visible = true
	if hide_almanach and _almanach_panel:
		_almanach_panel.visible = false
	if not _current_body_id.is_empty() and not (_almanach_panel and _almanach_panel.visible):
		_info_panel.visible = true


# ── Resize ─────────────────────────────────────────────────────────────────────

func _on_viewport_resized() -> void:
	await get_tree().process_frame
	if _solar_map:
		var map_transform: MapTransform = _solar_map.get_map_controller().get_map_transform()
		if map_transform:
			map_transform.camera_moved.emit(map_transform.cam_pos_px)


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close_zoom(true)
		if event.keycode == KEY_N:
			_nav_panel.visible = not _nav_panel.visible
		if event.keycode == KEY_I and _map_view.visible:
			if _almanach_panel and _almanach_panel.visible:
				_almanach_panel.visible = false
				if not _current_body_id.is_empty():
					_info_panel.visible = true
			else:
				_info_panel.visible = not _info_panel.visible
		if event.keycode == KEY_L and _almanach_panel:
			_almanach_panel.visible = not _almanach_panel.visible
			if _almanach_panel.visible:
				_info_panel.visible = false
				if not _almanach_panel.has_history():
					_almanach_panel.open_home()
