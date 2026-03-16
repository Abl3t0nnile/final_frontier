# orbit_renderer.gd
# Zeichnet den Orbit-Pfad eines Körpers relativ zu dessen Parent-Position.
# Unterstützt sofortige Skalierung (update_scale) und verzögerte Vorbereitung (prepare_scale / apply_prepared)
# für Frame-verteilte Zoom-Übergänge.
class_name OrbitRenderer
extends Node2D

# ==================================================================================================================
# Zustand
# ==================================================================================================================

# ID des Kindes, dessen Orbit gezeichnet wird
var _child_body_id: String = ""
# Farbe der Orbitlinie (abgeleitet von BodyDef.color_rgba des Kindes, gedimmt)
var _orbit_color: Color = Color.WHITE
# Linienbreite in Pixeln (konstant, skaliert nicht mit Zoom)
var _orbit_width: float = 3.0

# Orbit-Pfad in km — einmalig gecacht, Orbits sind feste Ellipsen
var _path_km: PackedVector2Array = PackedVector2Array()
# Aktuell gezeichnete Punkte in Screen-Koordinaten
var _scaled_points: PackedVector2Array = PackedVector2Array()
# px_per_km-Wert, mit dem _scaled_points berechnet wurden
var _drawn_px_per_km: float = 0.0

# ==================================================================================================================
# Vorbereitung (für verzögerte Zoom-Übergänge)
# ==================================================================================================================

# Vorberechnete Punkte für einen zukünftigen Maßstab — noch nicht gezeichnet
var _prepared_points: PackedVector2Array = PackedVector2Array()
# px_per_km-Wert, für den die vorbereiteten Punkte berechnet wurden
var _prepared_px_per_km: float = 0.0

# ==================================================================================================================
# Initialisierung
# ==================================================================================================================

## Initialisiert den Renderer mit der Kind-ID und der Farbe.
func setup(child_body_id: String, child_color: Color) -> void:
	_child_body_id = child_body_id
	_orbit_color = Color(child_color.r, child_color.g, child_color.b, 0.35)

# ==================================================================================================================
# Pfad-Cache
# ==================================================================================================================

## Lädt den Orbit-Pfad aus der Simulation (einmalig, lazy).
func _ensure_path_cached() -> void:
	if not _path_km.is_empty():
		return
	var points: Array[Vector2] = SolarSystem.get_local_orbit_path(_child_body_id)
	if points.is_empty():
		return
	_path_km.resize(points.size())
	for i in points.size():
		_path_km[i] = points[i]

# ==================================================================================================================
# Sofortige Skalierung (für Nicht-Zoom-Updates)
# ==================================================================================================================

## Gibt den px_per_km-Wert zurück, mit dem die aktuell gezeichneten Punkte berechnet wurden.
func get_draw_px_per_km() -> float:
	return _drawn_px_per_km

## Setzt den px_per_km-Faktor, berechnet die Punkte sofort und löst Neuzeichnung aus.
func update_scale(px_per_km: float) -> void:
	_ensure_path_cached()
	_drawn_px_per_km = px_per_km
	_compute_scaled_points(_path_km, px_per_km, _scaled_points)
	queue_redraw()

# ==================================================================================================================
# Verzögerte Skalierung (Prepare / Apply)
# ==================================================================================================================

## Berechnet die skalierten Punkte für einen zukünftigen Maßstab, ohne neu zu zeichnen.
## Wird von BaseMap in Batches über mehrere Frames aufgerufen.
func prepare_scale(px_per_km: float) -> void:
	_ensure_path_cached()
	_prepared_px_per_km = px_per_km
	_compute_scaled_points(_path_km, px_per_km, _prepared_points)

## Wendet die vorbereiteten Punkte an und löst genau eine Neuzeichnung aus.
## Verwirft die vorbereiteten Daten nach der Anwendung.
func apply_prepared() -> void:
	if _prepared_points.is_empty():
		return
	_scaled_points = _prepared_points
	_drawn_px_per_km = _prepared_px_per_km
	_prepared_points = PackedVector2Array()
	_prepared_px_per_km = 0.0
	queue_redraw()

## Gibt zurück, ob vorbereitete Punkte zum Anwenden bereitstehen.
func has_prepared() -> bool:
	return not _prepared_points.is_empty()

## Verwirft vorbereitete Daten ohne sie anzuwenden.
func discard_prepared() -> void:
	_prepared_points = PackedVector2Array()
	_prepared_px_per_km = 0.0

# ==================================================================================================================
# Zeichnung
# ==================================================================================================================

## Zeichnet die aktuell skalierten Punkte. Keine Berechnung in _draw() — nur Ausgabe.
func _draw() -> void:
	if _scaled_points.size() < 2:
		return
	draw_polyline(_scaled_points, _orbit_color, _orbit_width, true)

# ==================================================================================================================
# Hilfsfunktionen
# ==================================================================================================================

## Berechnet skalierte Screen-Punkte aus km-Punkten. Schreibt in das übergebene Array.
static func _compute_scaled_points(path_km: PackedVector2Array, px_per_km: float, out: PackedVector2Array) -> void:
	var count := path_km.size()
	out.resize(count)
	for i in count:
		out[i] = path_km[i] * px_per_km
