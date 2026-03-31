## StartChartController
## Zentraler Controller für die StartChart-Szene
## Steuert nur das Map-Overlay

extends Node

# Map Overlay UI
@onready var _scale_value: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/ScaleValue
@onready var _km_px_value: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/KmPxValue
@onready var _focus_box: VBoxContainer = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopRightPanel/Focus
@onready var _focus_name: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopRightPanel/Focus/FocusDisplay/BodyNameLabel
@onready var _pins_box: VBoxContainer = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopRightPanel/Pins
@onready var _pins_name: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/TopRightPanel/Pins/PinnedDisplay/BodyNameLabel
@onready var _pos_x: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosXValue
@onready var _pos_y: Label = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap/UiOverlay/MapOverlay/MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosYValue

var _solar_map: Node = null
var _km_per_px: float = 1_000_000.0

func _ready() -> void:
	# SolarMap finden
	_solar_map = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap
	if _solar_map:
		_setup_map_overlay()

func _setup_map_overlay() -> void:
	# Prüfen, ob SolarMap schon ready ist
	if _solar_map.is_inside_tree():
		_setup_map_overlay_signals()
	else:
		# Auf SolarMap ready warten
		_solar_map.ready.connect(_setup_map_overlay_signals, CONNECT_ONE_SHOT)

func _setup_map_overlay_signals() -> void:
	_km_per_px = _solar_map.get_zoom_level()
	
	# Signale verbinden
	if _solar_map.has_signal("zoom_changed"):
		_solar_map.zoom_changed.connect(_on_zoom_changed)
		
	if _solar_map.has_signal("body_selected"):
		_solar_map.body_selected.connect(_on_body_selected)
		
	if _solar_map.has_signal("body_deselected"):
		_solar_map.body_deselected.connect(_on_body_deselected)
		
	if _solar_map.has_signal("body_pinned"):
		_solar_map.body_pinned.connect(_on_body_pinned)
		
	if _solar_map.has_signal("body_unpinned"):
		_solar_map.body_unpinned.connect(_on_body_unpinned)
	
	_update_scale_display()

func _process(_delta: float) -> void:
	if _solar_map == null:
		return
	
	# Cursor-Position aktualisieren
	_update_cursor_position()

# Map Overlay Funktionen
func _on_zoom_changed(km_per_px: float) -> void:
	_km_per_px = km_per_px
	_update_scale_display()

func _update_scale_display() -> void:
	if not _scale_value or not _km_px_value:
		return
		
	var zoom_exp := log(_km_per_px) / log(10.0)
	_scale_value.text = "%.1f" % zoom_exp
	_km_px_value.text = SpaceMath.format_km_scientific(_km_per_px)

func _update_cursor_position() -> void:
	if not _pos_x or not _pos_y:
		return
		
	var map_transform: MapTransform = _solar_map.get_map_controller().get_map_transform()
	if map_transform == null:
		return
	
	var vp := get_viewport()
	if vp == null:
		return
	
	var mouse_pos := vp.get_mouse_position()
	var vp_center := vp.get_visible_rect().size * 0.5
	var offset_px := mouse_pos - vp_center
	var world_pos_km := (map_transform.cam_pos_px + offset_px) * _km_per_px
	var world_pos_au := SpaceMath.km_to_au_vec(world_pos_km)
	
	_pos_x.text = "%.3f AU" % world_pos_au.x
	_pos_y.text = "%.3f AU" % world_pos_au.y

func _on_body_selected(id: String) -> void:
	if not _focus_name or not _focus_box:
		return
		
	var def: BodyDef = _solar_map.get_body_data(id)
	_focus_name.text = def.name if def else id
	_focus_box.visible = true

func _on_body_deselected() -> void:
	if _focus_box:
		_focus_box.visible = false

func _on_body_pinned(_id: String) -> void:
	_refresh_pins()

func _on_body_unpinned(_id: String) -> void:
	_refresh_pins()

func _refresh_pins() -> void:
	if not _pins_box or not _pins_name:
		return
		
	var ids: Array = _solar_map.get_map_controller().get_interaction_manager().get_pinned_entities()
	if ids.is_empty():
		_pins_box.visible = false
		return
	
	var names: Array[String] = []
	for id in ids:
		var def: BodyDef = _solar_map.get_body_data(id)
		names.append(def.name if def else id)
	
	_pins_name.text = "\n".join(names)
	_pins_box.visible = true
