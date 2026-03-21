# ZoneRenderer — Halbtransparente Farbfläche für Zonen (Strahlung, Magnetosphären etc.).
# Unterstützt zwei Geometrien: "circle" (gefüllter Kreis) und "ring" (Hohlring).
# Position wird von der View gesetzt (renderer.position = parent_marker.position).
# Keine eigene Animationslogik — rein statische Darstellung.
class_name ZoneRenderer

extends Node2D

@export var border_width: float = 1.5
@export var circle_segments: int = 64
@export var show_border: bool = false

var _zone: ZoneDef = null
var _px_per_km: float = 1.0


func setup(zone: ZoneDef) -> void:
	_zone = zone
	queue_redraw()


func set_px_per_km(px_per_km: float) -> void:
	_px_per_km = px_per_km
	queue_redraw()


func _draw() -> void:
	if _zone == null:
		return
	match _zone.geometry:
		"circle":
			_draw_circle_zone()
		"ring":
			_draw_ring_zone()


func _draw_circle_zone() -> void:
	var r: float = _zone.radius_km * _px_per_km
	draw_circle(Vector2.ZERO, r, _zone.color_rgba)
	if show_border:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, circle_segments, _zone.border_color_rgba, border_width, true)


func _draw_ring_zone() -> void:
	var r_outer: float = _zone.outer_radius_km * _px_per_km
	var r_inner: float = _zone.inner_radius_km * _px_per_km

	# Ring als Folge von Quads — ein Quad pro Segment, zuverlässig und winding-unabhängig.
	var quad := PackedVector2Array()
	quad.resize(4)
	for i in circle_segments:
		var angle_a: float = TAU * i / float(circle_segments)
		var angle_b: float = TAU * (i + 1) / float(circle_segments)
		quad[0] = Vector2(cos(angle_a), sin(angle_a)) * r_outer
		quad[1] = Vector2(cos(angle_a), sin(angle_a)) * r_inner
		quad[2] = Vector2(cos(angle_b), sin(angle_b)) * r_inner
		quad[3] = Vector2(cos(angle_b), sin(angle_b)) * r_outer
		draw_colored_polygon(quad, _zone.color_rgba)

	if show_border:
		draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, circle_segments, _zone.border_color_rgba, border_width, true)
		draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, circle_segments, _zone.border_color_rgba, border_width, true)
