# res://game/map/renderer/grid_renderer.gd
# Zeichnet das Orientierungsgitter auf die Karte.
# Radiales Grid: konzentrische Kreise in AU, zwei Hauptachsen,
# konfigurierbare Haupt-/Nebenringe und Achsenlinien.

class_name GridRenderer
extends Node2D

enum GridMode { RADIAL, OFF }

const AU_KM: float = 149_597_870.7

# Alle möglichen Ringe in AU — sichtbare Teilmenge hängt vom Zoom ab
const RING_AU: Array[float] = [
	0.1, 0.2, 0.5,
	1.0, 2.0, 3.0, 5.0, 7.0,
	10.0, 20.0, 30.0, 50.0,
	100.0, 200.0, 500.0
]

var grid_mode: GridMode = GridMode.RADIAL

# Nebenringe (alle Ringe)
var ring_color: Color      = Color(0.29, 1.0, 0.54, 0.06)
var ring_width: float      = 0.5

# Hauptringe (jeder N-te Ring)
var major_interval: int    = 3      # jeder 3. sichtbare Ring ist ein Hauptring
var major_color: Color     = Color(0.29, 1.0, 0.54, 0.12)
var major_width: float     = 1.5

# Hauptachsen
var axis_color: Color      = Color(0.29, 1.0, 0.54, 0.22)
var axis_width: float      = 1.5

# Labels
var label_color: Color     = Color(0.29, 1.0, 0.54, 0.35)
var show_labels: bool      = true

var _map_transform: MapTransform = null


func setup(map_transform: MapTransform) -> void:
	_map_transform = map_transform
	queue_redraw()


func notify_zoom_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if _map_transform == null or grid_mode == GridMode.OFF:
		return
	_draw_axes()
	_draw_radial_grid()


# ---------------------------------------------------------------------------
# Achsen
# ---------------------------------------------------------------------------

func _draw_axes() -> void:
	# Extent muss Kamera-Distanz zum Ursprung + halbe Viewport-Diagonale abdecken
	var cam_dist: float = _map_transform.cam_pos_px.length()
	var extent: float   = cam_dist + get_viewport_rect().size.length() + 64.0
	draw_line(Vector2(-extent, 0.0), Vector2(extent, 0.0), axis_color, axis_width, true)
	draw_line(Vector2(0.0, -extent), Vector2(0.0, extent), axis_color, axis_width, true)


# ---------------------------------------------------------------------------
# Konzentrische Ringe
# ---------------------------------------------------------------------------

func _draw_radial_grid() -> void:
	var vp            := get_viewport_rect()
	var max_radius_px := vp.size.length() * 0.5 + 64.0
	var min_radius_px := 3.0

	var visible_index: int = 0   # zählt nur tatsächlich gezeichnete Ringe

	for au: float in RING_AU:
		var radius_px: float = _map_transform.km_distance_to_px(au * AU_KM)

		if radius_px < min_radius_px:
			continue
		if radius_px > max_radius_px * 2.0:
			break

		var is_major: bool = (visible_index % major_interval == 0)
		var col: Color     = major_color if is_major else ring_color
		var w: float       = major_width if is_major else ring_width
		var segs: int      = clampi(int(radius_px * 0.2), 48, 512)

		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, segs, col, w, true)

		if show_labels and radius_px > 16.0:
			_draw_ring_label(radius_px, au, is_major)

		visible_index += 1


func _draw_ring_label(radius_px: float, au: float, is_major: bool) -> void:
	var font: Font = ThemeDB.fallback_font
	var label: String
	if au < 1.0:
		label = "%.1f AU" % au
	elif au < 10.0:
		label = "%.0f AU" % au
	else:
		label = "%g AU" % au

	var font_size: int = 12 if is_major else 10
	var col: Color     = label_color if is_major else Color(label_color, label_color.a * 0.6)
	# Leicht rechts der 12-Uhr-Position
	var pos := Vector2(6.0, -radius_px + float(font_size))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
