## ZoneRenderer
## CPU-basiertes Zeichnen von Zonen via _draw().
## Geometrie "circle" = gefüllter Kreis; "donut"/"ring" = Hohlring; "line" = dünne Kreislinie.
## Position (Node2D.position) = Parent-Body in px — gesetzt vom ZoneManager.

class_name ZoneRenderer
extends Node2D

signal clicked(zone_id: String)
signal hovered(zone_id: String, display_name: String)
signal unhovered(zone_id: String)

var zone_def: ZoneDef    = null
var zone_id:  String     = ""

var _map_transform: MapTransform = null
var _is_hovered: bool = false

const BORDER_WIDTH_PX := 1.5
const MIN_DRAW_R_PX   := 0.5
const MIN_HIT_R_PX    := 6.0


func setup(def: ZoneDef, map_transform: MapTransform) -> void:
	zone_def       = def
	zone_id        = def.id
	_map_transform = map_transform
	queue_redraw()


func notify_zoom_changed(_km_per_px: float) -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or zone_def == null or _map_transform == null:
		if _is_hovered:
			_is_hovered = false
			unhovered.emit(zone_id)
			queue_redraw()
		return
	var over := _is_hit(to_local(get_viewport().get_mouse_position()))
	if over == _is_hovered:
		return
	_is_hovered = over
	if _is_hovered:
		hovered.emit(zone_id, zone_def.name)
	else:
		unhovered.emit(zone_id)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or zone_def == null or _map_transform == null:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var local_pos := to_local(get_viewport().get_mouse_position())
	if _is_hit(local_pos):
		clicked.emit(zone_id)


func _is_hit(p: Vector2) -> bool:
	var d   := p.length()
	var kpp := _map_transform.km_per_px
	match zone_def.geometry:
		"circle":
			return d <= zone_def.radius_km / kpp
		"donut", "ring":
			return d >= zone_def.inner_radius_km / kpp and d <= zone_def.outer_radius_km / kpp
		"line":
			var r := zone_def.radius_km / kpp
			return abs(d - r) <= max(zone_def.line_width_px * 0.5, MIN_HIT_R_PX)
	return false


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _draw() -> void:
	if zone_def == null or _map_transform == null:
		return

	var kpp    := _map_transform.km_per_px
	var fill   := zone_def.color_rgba.lightened(0.25)   if _is_hovered else zone_def.color_rgba
	var border := zone_def.border_color_rgba.lightened(0.3) if _is_hovered else zone_def.border_color_rgba

	match zone_def.geometry:
		"circle":
			var r := zone_def.radius_km / kpp
			if r < MIN_DRAW_R_PX:
				return
			var pts := _arc_pts(r)
			draw_circle(Vector2.ZERO, r, fill)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, pts, border, BORDER_WIDTH_PX, true)

		"donut", "ring":
			var r_outer := zone_def.outer_radius_km / kpp
			var r_inner := zone_def.inner_radius_km  / kpp
			if r_outer < MIN_DRAW_R_PX:
				return
			var pts   := _arc_pts(r_outer)
			var thick := r_outer - r_inner
			var mid_r := (r_outer + r_inner) * 0.5
			# Füllfläche als dicker Bogen
			draw_arc(Vector2.ZERO, mid_r, 0.0, TAU, pts, fill, thick, true)
			# Außenkante
			draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, pts, border, BORDER_WIDTH_PX, true)
			# Innenkante
			if r_inner > MIN_DRAW_R_PX:
				draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, pts, border, BORDER_WIDTH_PX, true)

		"line":
			var r := zone_def.radius_km / kpp
			if r < MIN_DRAW_R_PX:
				return
			var pts := _arc_pts(r)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, pts, border, zone_def.line_width_px, true)


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _arc_pts(r_px: float) -> int:
	return int(clamp(r_px * 0.3, 64, 4096))
