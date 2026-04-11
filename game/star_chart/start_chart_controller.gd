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
@onready var _clock_control       = $"UILayer/MainDisplay/VFrame/ClockPanel/ClockControl"
@onready var _nav_panel           = $"UILayer/MainDisplay/VFrame/BodyPanel/NavPanel"
@onready var _info_panel: InfoPanel = $"UILayer/MainDisplay/VFrame/BodyPanel/InfoPanel"
@onready var _map_overlay         = $"UILayer/MainDisplay/VFrame/BodyPanel/MapView/SubViewportContainer/MapOverlay"
@onready var _planet_view_overlay = $"UILayer/MainDisplay/VFrame/BodyPanel/BodyView/SubViewportContainer/PlanetViewOverlay"
@onready var _almanach_panel: Almanac = $"UILayer/MainDisplay/VFrame/BodyPanel/Almanac"

var _solar_map:       Node   = null
var _planet_view:     Node   = null
var _current_body_id: String = ""

enum ViewMode { MAP, PLANET_VIEW }
var _view_mode: ViewMode = ViewMode.MAP



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
	_planet_view_overlay.close_requested.connect(_on_close_planet_view)
	_planet_view_overlay.info_requested.connect(_on_planet_view_info_requested)


## Von GameController aufgerufen wenn PlanetView bereit ist.
func receive_planet_view(planet_view: Node) -> void:
	_planet_view = planet_view
	_body_subviewport.add_child(_planet_view)
	_planet_view_overlay.move_to_front()
	_body_view.visible = false


# ── Panel-Regeln ───────────────────────────────────────────────────────────────

func _set_view(mode: ViewMode) -> void:
	_view_mode = mode
	_map_view.visible            = (mode == ViewMode.MAP)
	_body_view.visible           = (mode == ViewMode.PLANET_VIEW)
	_planet_view_overlay.visible = (mode == ViewMode.PLANET_VIEW)
	if mode == ViewMode.PLANET_VIEW:
		_nav_panel.visible = false  # Regel: Nav nie in Planet View


func _set_info_panel_visible(show: bool) -> void:
	if show and _almanach_panel and _almanach_panel.visible:
		return  # Regel: Info und Almanac exklusiv
	_info_panel.visible = show


func _set_almanac_visible(show: bool) -> void:
	if _almanach_panel == null:
		return
	_almanach_panel.visible = show
	if show:
		_info_panel.visible = false  # Regel: Info und Almanac exklusiv
		_nav_panel.visible  = false  # Regel: Nav nie mit Almanac


# ── Öffentliches Interface (auch für künftigen InputHandler) ───────────────────

func toggle_nav_panel() -> void:
	if _view_mode == ViewMode.PLANET_VIEW:
		return
	if _almanach_panel and _almanach_panel.visible:
		return
	_nav_panel.visible = not _nav_panel.visible


func toggle_info_panel() -> void:
	if _almanach_panel and _almanach_panel.visible:
		_set_almanac_visible(false)
		if not _current_body_id.is_empty():
			_set_info_panel_visible(true)
	else:
		_set_info_panel_visible(not _info_panel.visible)


func toggle_almanac() -> void:
	if _almanach_panel == null:
		return
	if _almanach_panel.visible:
		_set_almanac_visible(false)
	else:
		if not _almanach_panel.has_history():
			_almanach_panel.open_home()
		_set_almanac_visible(true)


func close_overlay() -> void:
	_set_almanac_visible(false)
	if _view_mode == ViewMode.PLANET_VIEW:
		_set_view(ViewMode.MAP)
		if not _current_body_id.is_empty():
			_set_info_panel_visible(true)
	elif _view_mode == ViewMode.MAP:
		# Im MapView: Panel schließen und Marker deselectieren
		_set_info_panel_visible(false)
		if not _current_body_id.is_empty():
			_solar_map.deselect_body()
			_current_body_id = ""


func toggle_planet_view() -> void:
	if _view_mode == ViewMode.PLANET_VIEW:
		_on_close_planet_view()
	elif not _current_body_id.is_empty() and _planet_view != null:
		_on_zoom_requested(_current_body_id)


func toggle_time() -> void:
	_clock_control.toggle_time()


# ── Body-Selektion ─────────────────────────────────────────────────────────────

func _on_nav_body_focused(id: String) -> void:
	_current_body_id = id
	_info_panel.load_body(id)
	_info_panel.set_pinned(_solar_map.is_body_pinned(id))
	if _almanach_panel:
		_almanach_panel.open_body(id)
	if not (_almanach_panel and _almanach_panel.visible):
		_set_info_panel_visible(true)
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
		_set_info_panel_visible(true)


func _on_body_deselected() -> void:
	_current_body_id = ""
	_info_panel.clear()
	_set_info_panel_visible(false)


# ── Panel-Übergänge ────────────────────────────────────────────────────────────

func _on_almanach_requested(id: String) -> void:
	if _almanach_panel:
		_almanach_panel.open_body(id)
		_set_almanac_visible(true)


func _on_zoom_requested(id: String) -> void:
	if _planet_view == null:
		return
	_planet_view.call("load_body", id)
	_planet_view_overlay.load_body(id)
	if _almanach_panel:
		_almanach_panel.open_body(id)
	_set_almanac_visible(true)
	_set_view(ViewMode.PLANET_VIEW)


func _on_planet_view_info_requested(id: String) -> void:
	if _almanach_panel:
		_almanach_panel.open_body(id)
		_set_almanac_visible(not _almanach_panel.visible)


func _on_close_planet_view() -> void:
	_set_view(ViewMode.MAP)
	if not _current_body_id.is_empty() and not (_almanach_panel and _almanach_panel.visible):
		_set_info_panel_visible(true)


# ── Resize ─────────────────────────────────────────────────────────────────────

func _on_viewport_resized() -> void:
	await get_tree().process_frame
	if _solar_map:
		var map_transform: MapTransform = _solar_map.get_map_controller().get_map_transform()
		if map_transform:
			map_transform.camera_moved.emit(map_transform.cam_pos_px)


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action_pressed("ui_close_overlay"):
		close_overlay()
	elif event.is_action_pressed("ui_toggle_nav"):
		toggle_nav_panel()
	elif event.is_action_pressed("ui_toggle_info") and _view_mode == ViewMode.MAP:
		toggle_info_panel()
	elif event.is_action_pressed("ui_toggle_almanac"):
		toggle_almanac()
	elif event.is_action_pressed("ui_toggle_planet_view"):
		toggle_planet_view()
	elif event.is_action_pressed("time_jump_live"):
		_clock_control.jump_to_live()
	elif event.is_action_pressed("time_play_pause"):
		toggle_time()
	elif event.is_action_pressed("time_forward"):
		_clock_control.play_forward()
	elif event.is_action_pressed("time_backward"):
		_clock_control.play_backward()
	elif event.is_action_pressed("time_scale_up"):
		_clock_control.time_scale_up()
	elif event.is_action_pressed("time_scale_down"):
		_clock_control.time_scale_down()
	else:
		for i in range(5):
			if event.is_action_pressed("time_scale_%d" % (i + 1)):
				_clock_control.time_scale_set(i)
				return
