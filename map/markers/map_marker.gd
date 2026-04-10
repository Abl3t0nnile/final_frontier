## MapMarker
## Visueller Marker für einen Himmelskörper auf der Navigationskarte.
## Wird als Szene (map_marker.tscn) instanziiert – keine programmatische Kindknoten-Erstellung.

class_name MapMarker
extends Area2D

signal clicked(marker: MapMarker)
signal right_clicked(marker: MapMarker)
signal hovered(marker: MapMarker)
signal unhovered(marker: MapMarker)

enum MarkerState { INACTIVE = 0, DEFAULT, SELECTED, PINNED, DIMMED }

const LABEL_MIN_PX: int = 24

# Shared Collision Shapes pro Typ (eine Instanz pro Typ, von allen Markern geteilt)
static var _shape_star: CircleShape2D   = null
static var _shape_planet: CircleShape2D = null
static var _shape_moon: CircleShape2D   = null
static var _shape_dwarf: CircleShape2D  = null
static var _shape_struct: CircleShape2D = null

# Collision Padding pro Typ (wird zur Marker-Größe addiert)
var collision_padding_star: float   = 12.0
var collision_padding_planet: float = 6.0
var collision_padding_moon: float   = 4.0
var collision_padding_dwarf: float  = 3.0
var collision_padding_struct: float = 2.0

# Styling (wird via apply_config() gesetzt)
var selection_color: Color  = Color(1.0, 1.0, 1.0, 0.9)
var selection_width: float  = 2.0
var pinned_color: Color     = Color(1.0, 1.0, 1.0, 0.35)
var pinned_width: float     = 1.5
var label_offset: Vector2   = Vector2(4.0, -8.0)

@export var label_settings: LabelSettings:
	set(value):
		label_settings = value
		if _label != null:
			_label.label_settings = value

var body_def: BodyDef = null
var body_id: String = ""
var groups: Array[String] = []
var current_state: MarkerState = MarkerState.DEFAULT
var current_size_px: int = 24

@onready var _icon: MarkerIcon       = $MarkerIcon
@onready var _label: Label           = $Label
@onready var _collision: CollisionShape2D = $CollisionShape2D


func setup(game_object: GameObject, _label_settings) -> void:
	body_def = game_object.body_def
	body_id  = game_object.id

	_icon.setup(body_def)
	_label.text = body_def.name
	if label_settings != null:
		_label.label_settings = label_settings

	# Shared Shape pro Typ zuweisen
	_collision.shape = _get_or_create_shape()

	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))
	input_event.connect(_on_input_event)

	set_size_px(current_size_px)


func set_state(state: MarkerState) -> void:
	if current_state == state:
		return
	current_state = state
	visible = state != MarkerState.INACTIVE
	_label.visible = (state != MarkerState.DIMMED and state != MarkerState.INACTIVE)
	queue_redraw()


func set_icon_color(color: Color) -> void:
	_icon.self_modulate = color


func set_size_px(px: int) -> void:
	current_size_px = px
	_icon.set_size(px)
	_label.position = Vector2(float(px) * 0.5 + label_offset.x, label_offset.y)
	# Collision Shape skaliert mit Marker-Größe + typ-basiertes Padding
	var shape := _collision.shape as CircleShape2D
	if shape != null:
		shape.radius = float(px) * 0.5 + _get_collision_padding()
	queue_redraw()


func _get_collision_padding() -> float:
	if body_def == null:
		return collision_padding_planet
	match body_def.type:
		"star":
			return collision_padding_star
		"planet":
			return collision_padding_planet
		"moon":
			return collision_padding_moon
		"dwarf":
			return collision_padding_dwarf
		"struct", "station", "asteroid", "comet":
			return collision_padding_struct
		_:
			return collision_padding_planet


func _get_or_create_shape() -> CircleShape2D:
	var body_type := body_def.type if body_def != null else "planet"
	match body_type:
		"star":
			if _shape_star == null:
				_shape_star = CircleShape2D.new()
			return _shape_star
		"planet":
			if _shape_planet == null:
				_shape_planet = CircleShape2D.new()
			return _shape_planet
		"moon":
			if _shape_moon == null:
				_shape_moon = CircleShape2D.new()
			return _shape_moon
		"dwarf":
			if _shape_dwarf == null:
				_shape_dwarf = CircleShape2D.new()
			return _shape_dwarf
		"struct", "station", "asteroid", "comet":
			if _shape_struct == null:
				_shape_struct = CircleShape2D.new()
			return _shape_struct
		_:
			if _shape_planet == null:
				_shape_planet = CircleShape2D.new()
			return _shape_planet


func update_position(pos: Vector2) -> void:
	position = pos


func _draw() -> void:
	if current_state == MarkerState.SELECTED:
		var r := float(current_size_px) * 0.5 + 5.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, selection_color, selection_width, true)
	elif current_state == MarkerState.PINNED:
		var r := float(current_size_px) * 0.5 + 5.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, pinned_color, pinned_width, true)


func _on_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				clicked.emit(self)
				viewport.set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				right_clicked.emit(self)
				viewport.set_input_as_handled()
