# ConcentricGridRenderer — Konzentrische Ringe mit Hauptachsen als Navigationsgrid.
# Zentriert am Node-Ursprung — Caller positioniert den Node am gewünschten Mittelpunkt
# (z.B. Stern-Marker-Position). Keine eigene Logik für Sichtbarkeit oder Zoom.
# Caller ruft set_px_per_km() bei jedem Zoom-Update auf.
class_name ConcentricGridRenderer

extends Node2D

@export var ring_color:  Color = Color(1.0, 1.0, 1.0, 0.12)
@export var axis_color:  Color = Color(1.0, 1.0, 1.0, 0.28)
@export var line_width:  float = 1.0
@export var axis_width:  float = 1.0
@export var ring_segments: int = 96
@export var antialiased: bool  = true

var _ring_spacing_km: float = 1.0
var _ring_count:      int   = 5
var _px_per_km:       float = 1.0


func setup(ring_spacing_km: float, ring_count: int) -> void:
	_ring_spacing_km = ring_spacing_km
	_ring_count      = ring_count
	queue_redraw()


func set_px_per_km(px_per_km: float) -> void:
	_px_per_km = px_per_km
	queue_redraw()


func get_ring_spacing_km() -> float:
	return _ring_spacing_km


func get_ring_count() -> int:
	return _ring_count


func _draw() -> void:
	var outer_radius_px: float = _ring_spacing_km * float(_ring_count) * _px_per_km

	# Konzentrische Ringe
	for i in range(1, _ring_count + 1):
		var r: float = _ring_spacing_km * float(i) * _px_per_km
		draw_arc(Vector2.ZERO, r, 0.0, TAU, ring_segments, ring_color, line_width, antialiased)

	# Hauptachsen (horizontal + vertikal)
	draw_line(Vector2(-outer_radius_px, 0.0), Vector2(outer_radius_px, 0.0),
			axis_color, axis_width, antialiased)
	draw_line(Vector2(0.0, -outer_radius_px), Vector2(0.0, outer_radius_px),
			axis_color, axis_width, antialiased)
