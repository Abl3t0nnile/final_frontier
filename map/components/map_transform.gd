## MapTransform
## Koordinatentransformation und Kamera-Steuerung
## Erweitert: Node

class_name MapTransform
extends Node

## Public Properties
var km_per_px: float : get = get_km_per_px, set = set_km_per_px
var zoom_exp: float : get = get_zoom_exp, set = set_zoom_exp
var cam_pos_px: Vector2 : get = get_cam_pos_px

## Constants
const BASE_ZOOM: float = 1000.0  # 1px = 1000km bei zoom_exp = 0
const ZOOM_STEP: float = 0.1     # Jeder Schritt = 10^0.1 ≈ 1.26x

## Logarithmic Scaling Parameters
var log_base: float = 10.0 : get = get_log_base, set = set_log_base
var log_scale_factor: float = 1.0 : get = get_log_scale, set = set_log_scale
var log_offset: float = 0.0 : get = get_log_offset, set = set_log_offset

## Signals
signal zoom_changed(km_per_px: float)
signal camera_moved(cam_pos_px: Vector2)

## Private
var _km_per_px: float = 1000.0  # 1px = 1000km
var _zoom_exp: float = 0.0
var _cam_pos_px: Vector2 = Vector2.ZERO
var _log_base: float = 10.0
var _log_scale_factor: float = 1.0
var _log_offset: float = 0.0

## Public Methods
func km_to_px(pos_km: Vector2) -> Vector2:
	"""Konvertiert km zu Pixel-Koordinaten"""
	return SpaceMath.km_to_px(pos_km, _km_per_px)

func px_to_km(pos_px: Vector2) -> Vector2:
	"""Konvertiert Pixel zu km-Koordinaten"""
	return SpaceMath.px_to_km(pos_px, _km_per_px)

func km_to_px_batch(positions: Dictionary) -> Dictionary:
	"""Batch-Konvertierung für Performance"""
	var result: Dictionary = {}
	for id in positions:
		result[id] = km_to_px(positions[id])
	return result

func zoom_in(steps: float = 1.0) -> void:
	"""Zoomt rein (negative km_per_px)"""
	set_zoom_exp(_zoom_exp - steps * ZOOM_STEP)

func zoom_out(steps: float = 1.0) -> void:
	"""Zoomt raus (positive km_per_px)"""
	set_zoom_exp(_zoom_exp + steps * ZOOM_STEP)

func set_zoom_level(level: float) -> void:
	"""Setzt Zoom-Exponent direkt"""
	set_zoom_exp(level)

func get_zoom_level() -> float:
	"""Holt aktuellen Zoom-Exponent"""
	return _zoom_exp

## Logarithmic Scaling Functions
func log_scale(value: float) -> float:
	"""Logarithmische Skalierung mit anpassbaren Parametern"""
	if value <= 0:
		return 0.0
	return _log_scale_factor * log(value) / log(_log_base) + _log_offset

func log_unscale(scaled_value: float) -> float:
	"""Inverse logarithmische Skalierung"""
	return pow(_log_base, (scaled_value - _log_offset) / _log_scale_factor)

func apply_log_to_zoom() -> void:
	"""Wendet logarithmische Skalierung auf aktuellen Zoom an"""
	var log_zoom = log_scale(_zoom_exp)
	set_zoom_exp(log_zoom)

func set_log_params(base: float, scale: float, offset: float) -> void:
	"""Setzt alle logarithmischen Parameter auf einmal"""
	_log_base = base
	_log_scale_factor = scale
	_log_offset = offset

func get_log_params() -> Dictionary:
	"""Holt aktuelle logarithmische Parameter"""
	return {
		"base": _log_base,
		"scale": _log_scale_factor,
		"offset": _log_offset
	}

func focus_on(pos_px: Vector2) -> void:
	"""Fokussiert sofort auf Position"""
	_cam_pos_px = pos_px
	camera_moved.emit(_cam_pos_px)

func focus_on_smooth(pos_px: Vector2) -> void:
	"""Fokussiert mit Animation"""
	# TODO: Implement smooth camera movement
	focus_on(pos_px)

## Getters/Setters
func get_km_per_px() -> float:
	return _km_per_px

func set_km_per_px(value: float) -> void:
	_km_per_px = value
	zoom_changed.emit(_km_per_px)

func get_zoom_exp() -> float:
	return _zoom_exp

func set_zoom_exp(value: float) -> void:
	"""Setzt Zoom-Exponent und berechnet km_per_px"""
	_zoom_exp = value
	_km_per_px = BASE_ZOOM * pow(10.0, _zoom_exp)
	zoom_changed.emit(_km_per_px)

func get_cam_pos_px() -> Vector2:
	return _cam_pos_px

## Logarithmic Parameter Getters/Setters
func get_log_base() -> float:
	return _log_base

func set_log_base(value: float) -> void:
	_log_base = max(1.1, value)  # Base muss > 1 sein

func get_log_scale() -> float:
	return _log_scale_factor

func set_log_scale(value: float) -> void:
	_log_scale_factor = value

func get_log_offset() -> float:
	return _log_offset

func set_log_offset(value: float) -> void:
	_log_offset = value
