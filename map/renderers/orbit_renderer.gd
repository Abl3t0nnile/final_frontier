## OrbitRenderer
## Orbit-Visualisierung (CPU-basiert, integriert in MapMarker)
## Erweitert: Node2D

class_name OrbitRenderer
extends Node2D

## States
enum OrbitState {
	INACTIVE,
	DEFAULT,
	HIGHLIGHT,
	DIMMED,
	PINNED
}

## Public Properties
var body_def: BodyDef : get = get_body_def
var current_state: OrbitState : get = get_state, set = set_state

## Private
var _body_def: BodyDef
var _state: OrbitState = OrbitState.DEFAULT
var _map_transform: MapTransform
var _color: Color = Color.WHITE

## Public Methods
func setup(body: BodyDef, transform: MapTransform) -> void:
	"""Initialisiert Orbit-Renderer"""
	_body_def = body
	_map_transform = transform
	
	# Setup for custom drawing
	queue_redraw()

func set_state(state: OrbitState) -> void:
	"""Setzt Orbit-Zustand"""
	_state = state
	# TODO: Update color based on state
	match state:
		OrbitState.INACTIVE:
			visible = false
		OrbitState.DEFAULT:
			_color = Color.WHITE
			visible = true
		OrbitState.HIGHLIGHT:
			_color = Color.YELLOW
			visible = true
		OrbitState.DIMMED:
			_color = Color.GRAY
			visible = true
	queue_redraw()

func update_position(parent_position: Vector2) -> void:
	"""Aktualisiert Position (wird von MapMarker aufgerufen)"""
	global_position = parent_position

func snap_to_precise_position() -> void:
	"""Wobble-Fix bei hohem Zoom"""
	if _map_transform and _map_transform.km_per_px < 0.1:  # Threshold
		# TODO: Use SpaceMath.precise for exact position
		pass

## Drawing
func _draw() -> void:
	if not visible or not _body_def or not _body_def.has_motion():
		return
		
	# TODO: Draw orbit based on body_def.motion
	# This would draw circles, ellipses, or polylines
	pass

## Getters
func get_body_def() -> BodyDef:
	return _body_def

func get_state() -> OrbitState:
	return _state
