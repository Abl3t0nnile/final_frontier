# res://game/map/renderer/orbit_renderer.gd
# Zeichnet die Orbitlinie eines Körpers.
# - circular  → draw_arc (immer glatt, zoom-unabhängig)
# - kepler2d  → Ellipse analytisch aus Orbitparametern, Segmente zoom-adaptiv
# - andere    → Polyline-Fallback aus local_path_cache
# Konfiguration (Breiten, Alphas) wird vom MapController gesetzt.

class_name OrbitRenderer
extends Node2D

enum OrbitState { INACTIVE = 0, DEFAULT, HIGHLIGHT, DIMMED }
enum _DrawMode  { POLYLINE, CIRCLE, ELLIPSE }

var base_width: float      = 1.0
var highlight_width: float = 2.0
var dimmed_width: float    = 0.5
var alpha_default: float   = 0.2
var alpha_highlight: float = 0.6
var alpha_dimmed: float    = 0.08

# Retro-future color overrides
var enable_color_overrides: bool = false
var color_override: bool = false
var color_default: Color = Color(0.88, 0.36, 0.27, 1.0)    # #E05C44 - muted red-orange
var alpha_offset: float = 0.0  # Additional alpha for orbits

var body_def: BodyDef     = null
var body_id: String       = ""
var parent_id: String     = ""
var groups: Array[String] = []
var current_state: OrbitState = OrbitState.DEFAULT

var _map_transform: MapTransform = null
var _draw_mode: _DrawMode        = _DrawMode.POLYLINE

# CIRCLE-Parameter
var _radius_km: float = 0.0

# ELLIPSE-Parameter
var _a_km: float       = 0.0   # Große Halbachse
var _b_km: float       = 0.0   # Kleine Halbachse (= a * sqrt(1 - e²))
var _c_km: float       = 0.0   # Brennpunktabstand (= a * e)
var _arg_pe_rad: float = 0.0   # Argument des Periapsis
var _clockwise: bool   = false


func setup(def: BodyDef, map_transform: MapTransform) -> void:
	body_def       = def
	body_id        = def.id
	parent_id      = def.parent_id
	_map_transform = map_transform
	_build_groups()
	_detect_draw_mode()


func set_state(state: OrbitState) -> void:
	if current_state == state:
		return
	current_state = state
	visible = state != OrbitState.INACTIVE
	queue_redraw()


# ---------------------------------------------------------------------------
# Draw-Modus ermitteln
# ---------------------------------------------------------------------------

func _detect_draw_mode() -> void:
	if body_def == null or body_def.motion == null:
		_draw_mode = _DrawMode.POLYLINE
		return

	match body_def.motion.model:
		"circular":
			var m := body_def.motion as CircularMotionDef
			_radius_km = m.orbital_radius_km
			_draw_mode = _DrawMode.CIRCLE

		"kepler2d":
			var m := body_def.motion as Kepler2DMotionDef
			_a_km      = m.a_km
			_b_km      = m.a_km * sqrt(1.0 - m.e * m.e)
			_c_km      = m.a_km * m.e
			_arg_pe_rad = m.arg_pe_rad
			_clockwise  = m.clockwise
			_draw_mode = _DrawMode.ELLIPSE

		_:
			_draw_mode = _DrawMode.POLYLINE


# ---------------------------------------------------------------------------
# Zeichnen
# ---------------------------------------------------------------------------

func _draw() -> void:
	if body_def == null or _map_transform == null:
		return

	var col: Color
	var width: float
	
	# Use color overrides if enabled, otherwise use body color
	if enable_color_overrides and color_override:
		col = color_default
	else:
		col = body_def.color_rgba
	
	match current_state:
		OrbitState.DEFAULT:
			col.a = alpha_default + alpha_offset
			width = base_width
		OrbitState.HIGHLIGHT:
			col.a = alpha_highlight + alpha_offset
			width = highlight_width
		OrbitState.DIMMED:
			col.a = alpha_dimmed + alpha_offset
			width = dimmed_width
		_:
			return
	
	# Clamp alpha to valid range
	col.a = clamp(col.a, 0.0, 1.0)

	match _draw_mode:
		_DrawMode.CIRCLE:  _draw_circle(col, width)
		_DrawMode.ELLIPSE: _draw_ellipse(col, width)
		_:                 pass


func _draw_circle(col: Color, width: float) -> void:
	var radius_px := _map_transform.km_distance_to_px(_radius_km)
	# ~2 px pro Segment, mindestens 32, maximal 2048
	var segs := clampi(int(radius_px * TAU * 0.5), 32, 2048)
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, segs, col, width, true)


func _draw_ellipse(col: Color, width: float) -> void:
	var a_px  := _map_transform.km_distance_to_px(_a_km)
	var b_px  := _map_transform.km_distance_to_px(_b_km)
	var c_px  := _map_transform.km_distance_to_px(_c_km)
	# Segmente proportional zur großen Halbachse, ~1 px pro Segment
	var segs  := clampi(int(a_px * PI), 32, 2048)

	var cos_w := cos(_arg_pe_rad)
	var sin_w := sin(_arg_pe_rad)
	# Mittelpunkt der Ellipse relativ zum Brennpunkt (Parent = Ursprung)
	var cx := -c_px * cos_w
	var cy := -c_px * sin_w

	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	var dir := -1.0 if _clockwise else 1.0
	for i in segs + 1:
		var theta := dir * TAU * float(i) / float(segs)
		var lx    := a_px * cos(theta)
		var ly    := b_px * sin(theta)
		pts[i] = Vector2(cx + lx * cos_w - ly * sin_w,
		                 cy + lx * sin_w + ly * cos_w)

	draw_polyline(pts, col, width, true)


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _build_groups() -> void:
	groups.clear()
	if body_def == null:
		return
	groups.append("type:" + body_def.type)
	if not body_def.subtype.is_empty():
		groups.append("subtype:" + body_def.subtype)
	for tag: String in body_def.map_tags:
		groups.append(tag)
