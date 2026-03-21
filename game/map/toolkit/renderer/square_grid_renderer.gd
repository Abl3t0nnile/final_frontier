# SquareGridRenderer — Quadratisches Koordinatengrid mit optionalen Hauptlinien.
# Node-Ursprung liegt am Weltkoordinaten-Ursprung (0,0 in Screen-Coords).
# Zeichnet nur Linien die im übergebenen draw_rect sichtbar sind — effizient bei großen Grids.
# Caller positioniert den Node am Screen-Ursprung und ruft bei Kamera-/Zoom-Änderung
# set_px_per_km() und set_draw_rect() auf.
class_name SquareGridRenderer

extends Node2D

@export var line_color:      Color = Color(1.0, 1.0, 1.0, 0.08)
@export var major_color:     Color = Color(1.0, 1.0, 1.0, 0.22)
@export var line_width:      float = 1.0
@export var major_interval:  int   = 5     # jede N-te Linie ist eine Hauptlinie
@export var antialiased:     bool  = true

var _cell_size_km: float = 1.0
var _px_per_km:    float = 1.0
var _draw_rect:    Rect2 = Rect2()   # sichtbarer Bereich in Screen-Coords (relativ zum Node)


func setup(cell_size_km: float) -> void:
	_cell_size_km = cell_size_km
	queue_redraw()


func set_px_per_km(px_per_km: float) -> void:
	_px_per_km = px_per_km
	queue_redraw()


# rect_screen: sichtbarer Bereich in Screen-Koordinaten relativ zum Node-Ursprung.
# Typischerweise: Rect2(cam_pos - origin_screen, viewport_size) mit kleinem Margin.
func set_draw_rect(rect_screen: Rect2) -> void:
	_draw_rect = rect_screen
	queue_redraw()


func get_cell_size_km() -> float:
	return _cell_size_km


func _draw() -> void:
	var cell_px: float = _cell_size_km * _px_per_km
	if cell_px < 1.0:
		return

	var x_start: int = int(floor(_draw_rect.position.x / cell_px))
	var x_end:   int = int(ceil((_draw_rect.position.x + _draw_rect.size.x) / cell_px))
	var y_start: int = int(floor(_draw_rect.position.y / cell_px))
	var y_end:   int = int(ceil((_draw_rect.position.y + _draw_rect.size.y) / cell_px))

	var top:    float = _draw_rect.position.y
	var bottom: float = _draw_rect.position.y + _draw_rect.size.y
	var left:   float = _draw_rect.position.x
	var right:  float = _draw_rect.position.x + _draw_rect.size.x

	# Vertikale Linien
	for xi in range(x_start, x_end + 1):
		var x: float = float(xi) * cell_px
		var col: Color = major_color if xi % major_interval == 0 else line_color
		draw_line(Vector2(x, top), Vector2(x, bottom), col, line_width, antialiased)

	# Horizontale Linien
	for yi in range(y_start, y_end + 1):
		var y: float = float(yi) * cell_px
		var col: Color = major_color if yi % major_interval == 0 else line_color
		draw_line(Vector2(left, y), Vector2(right, y), col, line_width, antialiased)
