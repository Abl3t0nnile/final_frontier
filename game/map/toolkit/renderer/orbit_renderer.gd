# OrbitRenderer — Zeichnet die Bahnkurve eines Himmelskörpers.
# Dumme Komponente: empfängt fertige Screen-Punkte von der View, zeichnet sie.
# Position wird von der View gesetzt (renderer.position = parent_marker.position).
# Neuberechnung der draw_points nur bei Zoom-Änderung, nicht bei Parent-Bewegung.
class_name OrbitRenderer

extends Node2D

enum LineStyle { SOLID, DASHED, DOTTED }

const DASH_LENGTH_PX: float = 8.0
const GAP_LENGTH_PX:  float = 6.0
const DOT_RADIUS_PX:  float = 1.2
const DOT_SPACING_PX: float = 6.0

var _child_id: String = ""
var _parent_id: String = ""
var _color: Color = Color.WHITE
var _path_points_km: Array[Vector2] = []
var _draw_points: PackedVector2Array = PackedVector2Array()
var _line_style: int = LineStyle.SOLID

@export var line_width: float = 1.5
@export var antialiased: bool = true


func setup(child_id: String, parent_id: String, color: Color, path_points_km: Array[Vector2]) -> void:
	_child_id = child_id
	_parent_id = parent_id
	_color = color
	_path_points_km = path_points_km


func set_draw_points(screen_points: PackedVector2Array) -> void:
	_draw_points = screen_points
	queue_redraw()


func set_line_style(style: int) -> void:
	_line_style = style
	queue_redraw()


func get_path_points_km() -> Array[Vector2]:
	return _path_points_km


func _draw() -> void:
	if _draw_points.size() < 2:
		return
	match _line_style:
		LineStyle.SOLID:
			draw_polyline(_draw_points, _color, line_width, antialiased)
		LineStyle.DASHED:
			_draw_dashed(_draw_points)
		LineStyle.DOTTED:
			_draw_dotted(_draw_points)


# Geht den Pfad entlang und wechselt zwischen Strich und Lücke.
func _draw_dashed(points: PackedVector2Array) -> void:
	var remaining: float = 0.0
	var drawing: bool = true

	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len == 0.0:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var walked: float = 0.0

		while walked < seg_len:
			var budget: float = (DASH_LENGTH_PX if drawing else GAP_LENGTH_PX) - remaining
			var step: float = minf(budget, seg_len - walked)
			var from: Vector2 = a + dir * walked
			var to: Vector2 = a + dir * (walked + step)

			if drawing:
				draw_line(from, to, _color, line_width, antialiased)

			walked += step
			remaining += step

			if remaining >= (DASH_LENGTH_PX if drawing else GAP_LENGTH_PX):
				remaining = 0.0
				drawing = !drawing


# Zeichnet Punkte in gleichmäßigem Abstand entlang des Pfades.
func _draw_dotted(points: PackedVector2Array) -> void:
	var accumulated: float = 0.0

	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len == 0.0:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var walked: float = 0.0

		while walked < seg_len:
			var next_dot: float = DOT_SPACING_PX - accumulated
			if walked + next_dot > seg_len:
				accumulated += seg_len - walked
				break
			walked += next_dot
			accumulated = 0.0
			draw_circle(a + dir * walked, DOT_RADIUS_PX, _color)
