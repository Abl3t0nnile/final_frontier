# res://game/map/renderer/zone_renderer.gd
# Zeichnet eine halbtransparente Fläche für eine Zone (ZoneDef).
# Geometrie "circle" = gefüllter Kreis; "ring" = Hohlring (Annulus).
# Position (Node2D.position) = Parent-Body-Position in px — gesetzt vom MapController.

class_name ZoneRenderer
extends Node2D

var zone_def: ZoneDef    = null
var zone_id:  String     = ""

var _map_transform: MapTransform = null

const _SEGMENTS:     int   = 96
const _BORDER_WIDTH: float = 1.0


func setup(def: ZoneDef, map_transform: MapTransform) -> void:
	zone_def       = def
	zone_id        = def.id
	_map_transform = map_transform
	queue_redraw()


func notify_zoom_changed(_km_per_px: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------------------
# Zeichnen
# ---------------------------------------------------------------------------

func _draw() -> void:
	if zone_def == null or _map_transform == null:
		return
	match zone_def.geometry:
		"circle":
			_draw_circle_zone()
		"ring":
			_draw_ring_zone()


func _draw_circle_zone() -> void:
	var r_px: float = zone_def.radius_km / _map_transform.km_per_px
	if r_px < 0.5:
		return
	draw_circle(Vector2.ZERO, r_px, zone_def.color_rgba)
	draw_arc(Vector2.ZERO, r_px, 0.0, TAU, _SEGMENTS, zone_def.border_color_rgba, _BORDER_WIDTH, true)


func _draw_ring_zone() -> void:
	var r_inner: float = zone_def.inner_radius_km / _map_transform.km_per_px
	var r_outer: float = zone_def.outer_radius_km / _map_transform.km_per_px
	if r_outer < 0.5:
		return

	# Annulus-Polygon: Außenring CCW, Innenring CW — erzeugt korrekte Lochfüllung.
	var pts := PackedVector2Array()
	for i in _SEGMENTS:
		var a: float = float(i) * TAU / float(_SEGMENTS)
		pts.append(Vector2(cos(a) * r_outer, sin(a) * r_outer))
	for i in range(_SEGMENTS - 1, -1, -1):
		var a: float = float(i) * TAU / float(_SEGMENTS)
		pts.append(Vector2(cos(a) * r_inner, sin(a) * r_inner))
	draw_polygon(pts, PackedColorArray([zone_def.color_rgba]))

	# Ränder
	draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, _SEGMENTS, zone_def.border_color_rgba, _BORDER_WIDTH, true)
	if r_inner > 0.5:
		draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, _SEGMENTS, zone_def.border_color_rgba, _BORDER_WIDTH, true)
