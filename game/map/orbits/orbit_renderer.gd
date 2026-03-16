# orbit_renderer.gd
class_name OrbitRenderer
extends Node2D

# ------------------------------------------------------------------------------------------------------------------
# Zustand
# ------------------------------------------------------------------------------------------------------------------

# ID des Kindes, dessen Orbit gezeichnet wird
var _child_body_id: String = ""
# Farbe der Orbitlinie (abgeleitet von BodyDef.color_rgba des Kindes, gedimmt)
var _orbit_color: Color = Color.WHITE
# Linienbreite in Pixeln (konstant, skaliert nicht mit Zoom)
var _orbit_width: float = 3.0
# Aktueller px_per_km-Faktor, wird von der Map gesetzt
var _px_per_km: float = 0.0
# Orbit-Pfad in km — einmalig in setup gecacht, Orbits sind feste Ellipsen
var _path_km: PackedVector2Array = PackedVector2Array()

# ------------------------------------------------------------------------------------------------------------------
# Initialisierung
# ------------------------------------------------------------------------------------------------------------------

## Initialisiert den Renderer mit der Kind-ID und der Farbe.
func setup(child_body_id: String, child_color: Color) -> void:
	_child_body_id = child_body_id
	_orbit_color   = Color(child_color.r, child_color.g, child_color.b, 0.35)

# ------------------------------------------------------------------------------------------------------------------
# Skalierung
# ------------------------------------------------------------------------------------------------------------------

## Gibt den px_per_km-Wert zurück, mit dem die Draw-Daten zuletzt berechnet wurden.
func get_draw_px_per_km() -> float:
	return _px_per_km

## Setzt den aktuellen px_per_km-Faktor und löst Neuzeichnung aus.
func update_scale(px_per_km: float) -> void:
	_px_per_km = px_per_km
	queue_redraw()

# ------------------------------------------------------------------------------------------------------------------
# Zeichnung
# ------------------------------------------------------------------------------------------------------------------

## Zeichnet den Orbit-Pfad. Wird nur bei Skalenänderung neu aufgerufen.
func _draw() -> void:
	if _px_per_km <= 0.0:
		return
	# Lazy-Init: Pfad beim ersten Draw cachen, nicht in setup() — Simulation muss erst laufen
	if _path_km.is_empty():
		var points: Array[Vector2] = SolarSystem.get_local_orbit_path(_child_body_id)
		if points.is_empty():
			return
		_path_km.resize(points.size())
		for i in points.size():
			_path_km[i] = points[i]
	var scaled := PackedVector2Array()
	scaled.resize(_path_km.size())
	for i in _path_km.size():
		scaled[i] = _path_km[i] * _px_per_km
	draw_polyline(scaled, _orbit_color, _orbit_width, true)
