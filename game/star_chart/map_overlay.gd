## MapOverlay
## Steuert alle HUD-Elemente des ViewPanel-Overlays:
## Zoom/Scale-Anzeige, Cursor-Position, Focus-Body, Pinned Bodies.
## Initialisierung via setup(solar_map) durch den StartChartController.

extends MarginContainer

@onready var _title:       Label       = $MapOverlay/TopLeftPanel/PanelContainer/Title
@onready var _scale_value: Label       = $MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/ScaleValue
@onready var _km_px_value: Label       = $MapOverlay/TopLeftPanel/MarginContainer/HBoxContainer/KmPxValue
@onready var _focus_box:   VBoxContainer = $MapOverlay/FocusList/Focus
@onready var _focus_name:  Label       = $MapOverlay/FocusList/Focus/FocusDisplay/BodyNameLabel
@onready var _pins_box:    VBoxContainer = $MapOverlay/FocusList/Pins
@onready var _pins_name:   Label       = $MapOverlay/FocusList/Pins/PinnedDisplay/BodyNameLabel
@onready var _pos_x:        Label      = $MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosXValue
@onready var _pos_y:        Label      = $MapOverlay/BottomLeftPanel/MarginContainer/HBoxContainer/PosYValue
@onready var _filter_btn:   MenuButton = $MapOverlay/MenuButtons/FilterButton
@onready var _grid_btn:     Button     = $MapOverlay/MenuButtons/GridButton

var _solar_map: Node  = null
var _km_per_px: float = 1_000_000.0


func _ready() -> void:
	_set_mouse_ignore(self)
	var popup := _filter_btn.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.hide_on_item_selection           = false
	popup.index_pressed.connect(_on_filter_index_pressed)
	var p := get_parent() as Control
	if p:
		p.resized.connect(_fit_to_parent)
		call_deferred("_fit_to_parent")


func _set_mouse_ignore(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child)


func _fit_to_parent() -> void:
	var p := get_parent() as Control
	if p:
		position = Vector2.ZERO
		size = p.size


func setup(solar_map: Node) -> void:
	_solar_map = solar_map
	_km_per_px = _solar_map.get_zoom_level()
	_connect_signals()
	_update_scale_display()
	_grid_btn.toggled.connect(func(on: bool) -> void:
		_solar_map.get_map_controller().set_grid_visible(on))
	_grid_btn.button_pressed = false
	if _focus_box: _focus_box.visible = false
	if _pins_box:  _pins_box.visible  = false


func _process(_delta: float) -> void:
	if _solar_map == null:
		return
	_update_cursor_position()


# ── Signals ───────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
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


func _on_zoom_changed(km_per_px: float) -> void:
	_km_per_px = km_per_px
	_update_scale_display()


func _on_body_selected(id: String) -> void:
	if not _focus_name or not _focus_box:
		return
	var def: BodyDef = SolarSystem.get_body(id)
	_focus_name.text   = def.name if def else id
	_focus_box.visible = true
	if _title:
		_title.text = _system_title(def)


func _on_body_deselected() -> void:
	if _focus_box:
		_focus_box.visible = false
	if _title:
		_title.text = "Solar System"


func _on_body_pinned(_id: String) -> void:
	_refresh_pins()


func _on_body_unpinned(_id: String) -> void:
	_refresh_pins()


# ── Display ───────────────────────────────────────────────────────────────────

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
	var mouse_pos    := vp.get_mouse_position()
	var vp_center    := vp.get_visible_rect().size * 0.5
	var offset_px    := mouse_pos - vp_center
	var world_pos_km := (map_transform.cam_pos_px + offset_px) * _km_per_px
	var world_pos_au := SpaceMath.km_to_au_vec(world_pos_km)
	_pos_x.text = "%.3f AU" % world_pos_au.x
	_pos_y.text = "%.3f AU" % world_pos_au.y


func _system_title(def: BodyDef) -> String:
	if def == null:
		return "Solar System"
	for tag: String in def.map_tags:
		if tag.ends_with("_system") and not tag.begins_with("inner") and not tag.begins_with("outer"):
			return tag.replace("_", " ").capitalize()
	return "Solar System"


func _refresh_pins() -> void:
	if not _pins_box or not _pins_name:
		return
	var ids: Array = _solar_map.get_map_controller().get_interaction_manager().get_pinned_entities()
	if ids.is_empty():
		_pins_box.visible = false
		return
	var names: Array[String] = []
	for id in ids:
		var def: BodyDef = SolarSystem.get_body(id)
		names.append(def.name if def else id)
	_pins_name.text   = "\n".join(names)
	_pins_box.visible = true


func _on_filter_index_pressed(index: int) -> void:
	var popup := _filter_btn.get_popup()
	if popup.is_item_separator(index):
		return
	var new_state := not popup.is_item_checked(index)
	popup.set_item_checked(index, new_state)
	if _solar_map:
		_solar_map.get_map_controller().set_filter(popup.get_item_id(index), new_state)
