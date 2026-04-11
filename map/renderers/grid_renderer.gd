## GridRenderer
## CPU-based navigation grid with concentric rings

class_name GridRenderer
extends Node2D

const AU_KM: float = 149_597_870.7

const RING_AU: Array[float] = [
	0.1, 0.2, 0.5,
	1.0, 2.0, 3.0, 5.0, 7.0,
	10.0, 20.0, 30.0, 50.0, 70.0,
	100.0, 200.0, 300.0, 500.0, 700.0, 1000.0,
	2000.0, 3000.0, 5000.0, 7000.0, 10000.0
]

var ring_color: Color   = Color(0.29, 1.0, 0.54, 0.06)
var ring_width: float   = 0.5
var major_interval: int = 3
var major_color: Color  = Color(0.29, 1.0, 0.54, 0.12)
var major_width: float  = 1.5
var axis_color: Color   = Color(0.29, 1.0, 0.54, 0.22)
var axis_width: float   = 1.5
var label_color: Color  = Color(0.29, 1.0, 0.54, 0.35)
var show_labels: bool   = true

var _map_transform: MapTransform = null

func setup(map_transform: MapTransform) -> void:
	_map_transform = map_transform
	queue_redraw()

func notify_zoom_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if _map_transform == null:
		return

	var vp_size := get_viewport_rect().size

	# Position des Weltzentrums (Sonne) in Screen-Koordinaten
	# WorldRoot verschiebt alles um (-cam_pos + vp_size * 0.5)
	# GridRenderer ist Kind von WorldRoot, daher ist Welt-Ursprung bei (0,0) in unseren lokalen Koordinaten
	# aber wir zeichnen relativ zur aktuellen Kamera-Ansicht

	var cam_pos := _map_transform.cam_pos_px
	var vp_diag := vp_size.length()

	# Abstand der Kamera zum Ursprung
	var cam_dist := cam_pos.length()

	# Extent für Achsen
	var extent_px := cam_dist + vp_diag + 64.0

	# Achsen zeichnen (durch den Welt-Ursprung, also (0,0) in lokalen Koordinaten)
	draw_line(Vector2(-extent_px, 0.0), Vector2(extent_px, 0.0), axis_color, axis_width, true)
	draw_line(Vector2(0.0, -extent_px), Vector2(0.0, extent_px), axis_color, axis_width, true)

	# Konzentrische Ringe
	var font = ThemeDB.fallback_font
	var font_size := 11

	var visible_ring_index := 0
	for i in range(RING_AU.size()):
		var au := RING_AU[i]
		var radius_km := au * AU_KM
		var radius_px := _map_transform.km_distance_to_px(radius_km)

		# Ringe die zu klein oder zu groß sind überspringen
		if radius_px < 8.0:
			continue
		if radius_px > extent_px + 32.0:
			break

		var is_major := (visible_ring_index % major_interval == 0)
		visible_ring_index += 1

		var col   := major_color if is_major else ring_color
		var w     := major_width if is_major else ring_width

		var segments := int(clamp(radius_px * 0.2, 48, 512))
		var pts := PackedVector2Array()
		pts.resize(segments + 1)
		for s in range(segments + 1):
			var angle := TAU * float(s) / float(segments)
			pts[s] = Vector2(cos(angle) * radius_px, sin(angle) * radius_px)
		draw_polyline(pts, col, w, true)

		# Label
		if show_labels and font != null and radius_px > 20.0:
			var label_text: String
			if au < 1.0:
				label_text = "%.1f AU" % au
			else:
				label_text = "%.0f AU" % au

			# Label oben am Ring platzieren (y = -radius_px)
			var label_pos := Vector2(4.0, -radius_px - 2.0)
			draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
