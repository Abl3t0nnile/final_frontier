## MapMarker
## Visuelle Repräsentation mit integriertem Orbit
## Erweitert: Area2D

class_name MapMarker
extends Area2D

## States
enum MarkerState {
	INACTIVE=0,
	DEFAULT,
	SELECTED,
	PINNED,
	DIMMED
}

## Public Properties
var body_def: BodyDef : get = get_body_def
var current_state: MarkerState : get = get_state, set = set_state
var orbit_renderer: OrbitRenderer : get = get_orbit_renderer

## Signals
signal clicked(marker: MapMarker)
signal double_clicked(marker: MapMarker)
signal hovered(marker: MapMarker)

## Private
var _body_def: BodyDef
var _state: MarkerState = MarkerState.DEFAULT
var _orbit_renderer: OrbitRenderer
var _sprite: Sprite2D
var _label: Label

## Public Methods
func setup(game_object: GameObject, label_settings: LabelSettings) -> void:
	"""Initialisiert Marker"""
	_body_def = game_object.body_def
	
	# Setup sprite
	_sprite = Sprite2D.new()
	add_child(_sprite)
	
	# Setup label
	_label = Label.new()
	add_child(_label)
	
	# Setup orbit if body has motion
	if _body_def.has_motion():
		_orbit_renderer = OrbitRenderer.new()
		add_child(_orbit_renderer)
		_orbit_renderer.setup(_body_def, null)  # TODO: Get map_transform

func set_state(state: MarkerState) -> void:
	"""Setzt Marker-Zustand"""
	_state = state
	# TODO: Update visual appearance based on state
	visible = state != MarkerState.INACTIVE
	
	if _orbit_renderer:
		_orbit_renderer.set_state(state)

func set_size_px(px: int) -> void:
	"""Setzt Marker-Größe"""
	# TODO: Update sprite size
	pass

func update_position(position: Vector2) -> void:
	"""Aktualisiert Position"""
	global_position = position

## Getters
func get_body_def() -> BodyDef:
	return _body_def

func get_state() -> MarkerState:
	return _state

func get_orbit_renderer() -> OrbitRenderer:
	return _orbit_renderer
