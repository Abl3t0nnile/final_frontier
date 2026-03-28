## Clock
## Zeit-Management für Simulation und Map
## Erweitert: Node

class_name SimClock
extends Node

## Public Properties
var current_time: float : get = get_current_time
var time_scale: float : get = get_time_scale, set = set_time_scale
var is_running: bool : get = get_is_running
var allow_rewind: bool : get = get_allow_rewind  ## false = nur vorwärts (Simulation), true = auch rückwärts (Map)

## Signals
signal tick(time: float)  ## Normaler Zeitfortschritt (absolute Zeit)
signal time_changed(time: float)  ## Harter Zeit-Sprung (Rewind, Jump)

## Private
var _current_time: float = 0.0
var _time_scale: float = 1.0
var _is_running: bool = false
var _allow_rewind: bool = false
var _min_time: float = 0.0
var _max_time: float = 1e12

## Constructor
func init(rewind_allowed: bool) -> Clock:
	_allow_rewind = rewind_allowed
	return self

## Public Methods
func setup(start_time: float) -> void:
	"""Initialisiert die Uhr mit Startzeit"""
	_current_time = start_time

func start() -> void:
	"""Startet die Uhr"""
	_is_running = true

func stop() -> void:
	"""Stoppt die Uhr"""
	_is_running = false

func set_time_scale(scale: float) -> void:
	"""Setzt die Zeit-Skalierung"""
	if not _allow_rewind:
		scale = max(0.0, scale)  # Keine negativen Werte ohne Rewind
	_time_scale = scale

func set_time(time: float) -> void:
	"""Setzt absolute Zeit (nur mit allow_rewind)"""
	if not _allow_rewind and time < _current_time:
		return
	_current_time = clamp(time, _min_time, _max_time)
	time_changed.emit(_current_time)

func set_time_range(min_t: float, max_t: float) -> void:
	"""Setzt erlaubten Zeitbereich"""
	_min_time = min_t
	_max_time = max_t

func advance_time(delta: float) -> void:
	"""Normaler Zeitfortschritt - emittiert tick"""
	var new_time = _current_time + delta * _time_scale
	new_time = clamp(new_time, _min_time, _max_time)
	if new_time != _current_time:
		_current_time = new_time
		tick.emit(_current_time)

func format_time(time: float) -> String:
	"""Formatiert Zeit in lesbares Format"""
	var days = int(time / 86400.0)
	var hours = int(fmod(time, 86400.0) / 3600.0)
	var minutes = int(fmod(time, 3600.0) / 60.0)
	return "%dd %02d:%02d" % [days, hours, minutes]

## Getters
func get_current_time() -> float:
	return _current_time

func get_time_scale() -> float:
	return _time_scale

func get_is_running() -> bool:
	return _is_running

func get_allow_rewind() -> bool:
	return _allow_rewind
