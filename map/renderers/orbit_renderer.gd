## OrbitRenderer
## CPU-basiertes Zeichnen von Kreisbahnen und Keplerellipsen via draw_arc.
## Kreisbahnen: draw_arc auf _radius_km
## Ellipsen:    draw_arc + draw_set_transform (Y-Skalierung b/a, Offset -c)

class_name OrbitRenderer
extends Node2D

enum OrbitState { INACTIVE = 0, DEFAULT, HIGHLIGHT, DIMMED }

var body_def: BodyDef     = null
var parent_id: String     = ""
var current_state: OrbitState = OrbitState.DEFAULT

var color: Color           = Color.WHITE

var base_width: float      = 1.0
var highlight_width: float = 2.0
var dimmed_width: float    = 0.5
var alpha_default: float   = 0.2
var alpha_highlight: float = 0.6
var alpha_dimmed: float    = 0.08

var _map_transform: MapTransform = null

enum _DrawMode { CIRCLE, ELLIPSE, NONE }
var _draw_mode: _DrawMode = _DrawMode.NONE

## CIRCLE
var _radius_km: float = 0.0

## ELLIPSE
var _a_km: float       = 0.0
var _b_km: float       = 0.0
var _c_km: float       = 0.0
var _arg_pe_rad: float = 0.0


func setup(body: BodyDef, transform: MapTransform) -> void:
	body_def       = body
	parent_id      = body.parent_id
	color          = body.color_rgba
	_map_transform = transform
	_detect_draw_mode()
	queue_redraw()


func set_state(state: OrbitState) -> void:
	if current_state == state:
		return
	current_state = state
	visible = (state != OrbitState.INACTIVE)
	queue_redraw()


func notify_zoom_changed(_km_per_px: float) -> void:
	queue_redraw()


## Erkennt Zeichen-Modus anhand der Motion-Definition
func _detect_draw_mode() -> void:
	if body_def == null or body_def.motion == null:
		_draw_mode = _DrawMode.NONE
		return

	match body_def.motion.model:
		"circular":
			var m := body_def.motion as CircularMotionDef
			if m == null:
				_draw_mode = _DrawMode.NONE
				return
			_radius_km = m.orbital_radius_km
			_draw_mode  = _DrawMode.CIRCLE

		"kepler2d":
			var m := body_def.motion as Kepler2DMotionDef
			if m == null:
				_draw_mode = _DrawMode.NONE
				return
			_a_km       = m.semi_major_axis_km
			_b_km       = _a_km * sqrt(1.0 - m.eccentricity * m.eccentricity)
			_c_km       = _a_km * m.eccentricity
			_arg_pe_rad = m.argument_of_periapsis_rad
			_draw_mode  = _DrawMode.ELLIPSE

		_:
			_draw_mode = _DrawMode.NONE


func _get_draw_params() -> Array:
	var col: Color = color
	var width: float
	var alpha: float
	match current_state:
		OrbitState.HIGHLIGHT:
			width = highlight_width
			alpha = alpha_highlight
		OrbitState.DIMMED:
			width = dimmed_width
			alpha = alpha_dimmed
		_:
			width = base_width
			alpha = alpha_default
	col.a = alpha
	return [col, width]


func _draw() -> void:
	if _map_transform == null or _draw_mode == _DrawMode.NONE:
		return

	var params := _get_draw_params()
	var col: Color   = params[0]
	var width: float = params[1]

	match _draw_mode:
		_DrawMode.CIRCLE:
			var r_px: float = _map_transform.km_distance_to_px(_radius_km)
			if r_px < 0.5:
				return
			var pts := int(clamp(r_px * 0.3, 64, 4096))
			draw_arc(Vector2.ZERO, r_px, 0.0, TAU, pts, col, width, true)

		_DrawMode.ELLIPSE:
			var a_px: float = _map_transform.km_distance_to_px(_a_km)
			if a_px < 1.0:
				return
			var b_px: float = _map_transform.km_distance_to_px(_b_km)
			var c_px: float = _map_transform.km_distance_to_px(_c_km)
			var pts := int(clamp(a_px * 0.3, 64, 4096))
			# Ellipse via Kreis + nicht-uniformer Skalierung:
			# Fokus liegt im Ursprung, Ellipsenmittelpunkt bei (-c, 0) (unrotiert).
			# draw_set_transform(offset, angle, scale) erzeugt:
			#   world = offset + rotate(angle, scale * local)
			# Mit offset = rotate(arg_pe, (-c,0)), angle = arg_pe, scale = (1, b/a)
			# ergibt sich: world = rotate(arg_pe, (a*cos(t) - c, b*sin(t))) ✓
			draw_set_transform(
				Vector2(-c_px, 0.0).rotated(_arg_pe_rad),
				_arg_pe_rad,
				Vector2(1.0, b_px / a_px)
			)
			draw_arc(Vector2.ZERO, a_px, 0.0, TAU, pts, col, width, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
