## MapOverlayHud
## Verbindet das Map-Overlay mit der SolarMap.
## Attached an den UiOverlay-CanvasLayer (direktes Kind von SolarMap).

extends CanvasLayer

@onready var _scale_value: Label = $MapOverlay/MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/ScaleValue
@onready var _km_px_value: Label = $MapOverlay/MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/KmPxValue

@onready var _focus_box: VBoxContainer = $MapOverlay/MapOverlay/TopRightPanel/Focus
@onready var _focus_name: Label        = $MapOverlay/MapOverlay/TopRightPanel/Focus/FocusDisplay/BodyNameLabel

@onready var _pins_box: VBoxContainer  = $MapOverlay/MapOverlay/TopRightPanel/Pins
@onready var _pins_name: Label         = $MapOverlay/MapOverlay/TopRightPanel/Pins/PinnedDisplay/BodyNameLabel

@onready var _pos_x: Label = $MapOverlay/MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosXValue
@onready var _pos_y: Label = $MapOverlay/MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosYValue

var _solar_map: Node  = null
var _km_per_px: float = 1_000_000.0


func _ready() -> void:
	_solar_map = get_parent()
	# SolarMap._ready() läuft nach dem der Kinder – via ready-Signal warten
	_solar_map.ready.connect(_setup, CONNECT_ONE_SHOT)


func _setup() -> void:
	_km_per_px = _solar_map.get_zoom_level()
	_solar_map.zoom_changed.connect(_on_zoom_changed)
	_solar_map.body_selected.connect(_on_body_selected)
	_solar_map.body_deselected.connect(_on_body_deselected)
	_solar_map.body_pinned.connect(_on_body_pinned)
	_solar_map.body_unpinned.connect(_on_body_unpinned)
	_update_scale_display()


func _process(_delta: float) -> void:
	if _solar_map == null:
		return
	_update_cursor_position()


## Zoom-Update

func _on_zoom_changed(km_per_px: float) -> void:
	_km_per_px = km_per_px
	_update_scale_display()


func _update_scale_display() -> void:
	var zoom_exp := log(_km_per_px) / log(10.0)
	_scale_value.text = "%.1f" % zoom_exp
	_km_px_value.text = SpaceMath.format_km_scientific(_km_per_px)



## Cursor-Position (BottomLeft)

func _update_cursor_position() -> void:
	var map_transform: MapTransform = _solar_map.get_map_controller().get_map_transform()
	if map_transform == null:
		return
	var vp := get_viewport()
	if vp == null:
		return

	var mouse_pos   := vp.get_mouse_position()
	var vp_center   := vp.get_visible_rect().size * 0.5
	var offset_px   := mouse_pos - vp_center
	var world_pos_km := (map_transform.cam_pos_px + offset_px) * _km_per_px
	var world_pos_au := SpaceMath.km_to_au_vec(world_pos_km)

	_pos_x.text = "%.3f AU" % world_pos_au.x
	_pos_y.text = "%.3f AU" % world_pos_au.y


## Fokus / Pins (TopRight)

func _on_body_selected(id: String) -> void:
	var def: BodyDef = _solar_map.get_body_data(id)
	_focus_name.text = def.name if def else id
	_focus_box.visible = true


func _on_body_deselected() -> void:
	_focus_box.visible = false


func _on_body_pinned(_id: String) -> void:
	_refresh_pins()


func _on_body_unpinned(_id: String) -> void:
	_refresh_pins()


func _refresh_pins() -> void:
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
