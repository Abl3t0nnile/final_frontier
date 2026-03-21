# MapScale — Skalierungsmathe für das Map-System.
# Kapselt die Umrechnung zwischen Weltkoordinaten (km) und Bildschirmkoordinaten (px).
# Das Zoom-Level wird als Exponent gespeichert (scale_exp), sodass km_per_px = 10^scale_exp.
# Ein variabler Weltorigin verhindert Floating-Point-Drift bei weit entfernten Objekten.
# Reine Mathe — kein Clamping, keine Darstellungslogik.
class_name MapScale

extends RefCounted

var _scale_exp: float = 5.0
var _px_per_km: float = 1.0 / pow(10.0, 5.0)
var _km_per_px: float = pow(10.0, 5.0)
var _origin_km: Vector2 = Vector2.ZERO


func set_scale_exp(exponent: float) -> void:
	_scale_exp = exponent
	_km_per_px = pow(10.0, exponent)
	_px_per_km = 1.0 / _km_per_px

func get_scale_exp() -> float:
	return _scale_exp

func get_px_per_km() -> float:
	return _px_per_km

func get_km_per_px() -> float:
	return _km_per_px


func set_origin(world_km: Vector2) -> void:
	_origin_km = world_km

func get_origin() -> Vector2:
	return _origin_km


func world_to_screen(world_km: Vector2) -> Vector2:
	return (world_km - _origin_km) * _px_per_km

func screen_to_world(screen_px: Vector2) -> Vector2:
	return screen_px * _km_per_px + _origin_km

func km_to_px(km: float) -> float:
	return km * _px_per_km

func px_to_km(px: float) -> float:
	return px * _km_per_px
