## PlanetViewOverlay
## HUD-Overlay für die PlanetView — zeigt Body-Infos, InfoBtn und CloseBtn.
## Position wird aus der Marker-Position der SolarMap gelesen (px → km → AU).

class_name PlanetViewOverlay
extends MarginContainer

signal close_requested
signal info_requested(body_id: String)

@onready var _body_name_label: Label  = $Grid/TopLeftPanel/PanelContainer/BodyNameLabel
@onready var _type_value:      Label  = $Grid/TopLeftPanel/MarginContainer/HBoxContainer/TypeValue
@onready var _subtype_value:   Label  = $Grid/TopLeftPanel/MarginContainer/HBoxContainer/SubTypeValue
@onready var _info_btn:        Button = $Grid/TopRightPanel/InfoBtn
@onready var _close_btn:       Button = $Grid/TopRightPanel/CloseBtn
@onready var _pos_x_value:     Label  = $Grid/BottomLeftPanel/MarginContainer/HBoxContainer/PosXValue
@onready var _pos_y_value:     Label  = $Grid/BottomLeftPanel/MarginContainer/HBoxContainer/PosYValue

var _current_id:      String = ""
var _solar_map:       Node   = null


func _ready() -> void:
	_info_btn.pressed.connect(func() -> void: info_requested.emit(_current_id))
	_close_btn.pressed.connect(func() -> void: close_requested.emit())
	var p := get_parent() as Control
	if p:
		p.resized.connect(_fit_to_parent)
		call_deferred("_fit_to_parent")


func _fit_to_parent() -> void:
	var p := get_parent() as Control
	if p:
		position = Vector2.ZERO
		size = p.size


func setup(solar_map: Node) -> void:
	_solar_map = solar_map


func load_body(id: String) -> void:
	_current_id = id
	var def: BodyDef = SolarSystem.get_body(id)
	if def == null:
		_body_name_label.text = id
		_type_value.text      = ""
		_subtype_value.text   = ""
		return
	_body_name_label.text = def.name
	_type_value.text      = def.type
	_subtype_value.text   = def.subtype


func _process(_delta: float) -> void:
	if not visible or _current_id.is_empty() or _solar_map == null:
		return
	_update_position()


func _update_position() -> void:
	var map_ctrl  = _solar_map.get_map_controller()
	var entity_mgr = map_ctrl.get_entity_manager()
	var km_per_px: float = map_ctrl.get_map_transform().km_per_px

	var marker: MapMarker = entity_mgr.get_marker(_current_id)
	if marker == null:
		return

	var def: BodyDef = SolarSystem.get_body(_current_id)
	var pos_px := marker.position

	if def and not def.parent_id.is_empty():
		var parent_marker: MapMarker = entity_mgr.get_marker(def.parent_id)
		if parent_marker:
			pos_px -= parent_marker.position

	var pos_km := pos_px * km_per_px
	_pos_x_value.text = "%.4f AU" % SpaceMath.km_to_au(pos_km.x)
	_pos_y_value.text = "%.4f AU" % SpaceMath.km_to_au(pos_km.y)
