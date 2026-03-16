# local_map.gd
class_name LocalMap
extends BaseMap

# ------------------------------------------------------------------------------------------------------------------
# LocalMap-spezifische Konfiguration
# ------------------------------------------------------------------------------------------------------------------

## Minimaler scale_exp (maximaler Zoom-In)
@export var min_scale_exp: float = 3.0
## Maximaler scale_exp (maximaler Zoom-Out)
@export var max_scale_exp: float = 8.0
## Maximaler Abstand der Kamera vom Schiff in km
@export var max_camera_distance_km: float = 1000.0

# ------------------------------------------------------------------------------------------------------------------
# Kamera
# ------------------------------------------------------------------------------------------------------------------

# Referenz auf die LocalMap-Kamera
var _camera: Camera2D = null

# ------------------------------------------------------------------------------------------------------------------
# Schiffs-Anbindung
# ------------------------------------------------------------------------------------------------------------------

# Aktuelle Position des Spielerschiffs in Welt-km
var _ship_position_km: Vector2 = Vector2.ZERO
# Sensorreichweite des Schiffs in km
var _sensor_range_km: float = 0.0

# ------------------------------------------------------------------------------------------------------------------
# Signalverzögerung
# ------------------------------------------------------------------------------------------------------------------

# Signalgeschwindigkeit in km/s
var _signal_speed_km_s: float = 0.0

# ------------------------------------------------------------------------------------------------------------------
# Initialisierung
# ------------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	pass

# ------------------------------------------------------------------------------------------------------------------
# Subklassen-Hooks (Override von BaseMap)
# ------------------------------------------------------------------------------------------------------------------

## Gibt den minimal erlaubten scale_exp zurück.
func _get_min_scale_exp() -> float:
	return min_scale_exp

## Gibt den maximal erlaubten scale_exp zurück.
func _get_max_scale_exp() -> float:
	return max_scale_exp

## Sichtbarkeit: basierend auf Sensorreichweite, nicht auf Zoom/LOD.
func _is_body_visible(body: BodyDef) -> bool:
	return true

## Orbit-Sichtbarkeit: nur innerhalb der Sensorreichweite.
func _is_orbit_visible(body: BodyDef) -> bool:
	return true

## Positions-Transformation: linear, keine Log-Option.
func calculate_screen_position(world_pos_km: Vector2) -> Vector2:
	return Vector2.ZERO

## Input-Verarbeitung pro Frame.
func _process_map_input(delta: float) -> void:
	pass

# ------------------------------------------------------------------------------------------------------------------
# Schiffs-Anbindung
# ------------------------------------------------------------------------------------------------------------------

## Setzt die aktuelle Position des Spielerschiffs.
func set_ship_position(position_km: Vector2) -> void:
	pass

## Setzt die Sensorreichweite des Schiffs.
func set_sensor_range(range_km: float) -> void:
	pass

## Gibt die aktuelle Schiffsposition zurück.
func get_ship_position() -> Vector2:
	return _ship_position_km

# ------------------------------------------------------------------------------------------------------------------
# Kamera-Steuerung
# ------------------------------------------------------------------------------------------------------------------

## Bewegt die Kamera, begrenzt auf den maximalen Abstand vom Schiff.
func _pan_camera(offset: Vector2) -> void:
	pass

## Begrenzt die Kameraposition auf den erlaubten Radius um das Schiff.
func _clamp_camera_to_ship() -> void:
	pass

# ------------------------------------------------------------------------------------------------------------------
# Sensorik
# ------------------------------------------------------------------------------------------------------------------

## Prüft, ob ein Objekt innerhalb der Sensorreichweite liegt.
func _is_in_sensor_range(position_km: Vector2) -> bool:
	return true

## Berechnet die Signalverzögerung für ein Objekt in gegebener Entfernung.
func _calculate_signal_delay(distance_km: float) -> float:
	return 0.0

## Gibt die verzögerte Position eines nicht-deterministischen Objekts zurück.
func _get_delayed_position(body_id: String, current_sst_s: float) -> Vector2:
	return Vector2.ZERO

# ------------------------------------------------------------------------------------------------------------------
# Sichtbarkeitslogik
# ------------------------------------------------------------------------------------------------------------------

## Aktualisiert die Sichtbarkeit aller Körper basierend auf Sensorreichweite.
func _update_visibility() -> void:
	pass
