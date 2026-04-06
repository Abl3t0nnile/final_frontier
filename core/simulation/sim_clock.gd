## Clock
## Zeit-Management für Simulation und Map
## Erweitert: Node

class_name SimClock
extends Node

## Kalender-Konstanten
const MONTH_NAMES: Array[String] = [
	"Helar", "Selen", "Meron", "Venar", "Terran", "Aresan",
	"Jovan", "Satyr", "Uranor", "Nevaris", "Pluton", "Ceron"
]

const SEC_PER_MIN: float     = 60.0
const SEC_PER_HOUR: float    = 3600.0
const SEC_PER_DAY: float     = 86400.0
const DAYS_PER_MONTH: int    = 30
const MONTHS_PER_YEAR: int   = 12
const DAYS_PER_YEAR: int     = 360

## Public Properties
var current_time: float : get = get_current_time
var time_scale: float : get = get_time_scale, set = set_time_scale
var is_running: bool : get = get_is_running
var allow_rewind: bool : get = get_allow_rewind  ## false = nur vorwärts (Simulation), true = auch rückwärts (Map)

## Signals
signal tick(time: float)  ## Normaler Zeitfortschritt (absolute Zeit)
signal time_changed(time: float)  ## Harter Zeit-Sprung (Rewind, Jump)
signal time_scale_changed(scale: float)  ## Zeit-Skalierung geändert

signal started()
signal paused()

## Private
var _current_time: float = 0.0
var _time_scale: float = 1.0
var _is_running: bool = false
var _allow_rewind: bool = false
var _min_time: float = 0.0
var _max_time: float = 1e12

## Constructor
func init(rewind_allowed: bool) -> SimClock:
	_allow_rewind = rewind_allowed
	return self

## Public Methods
func setup(start_time: float) -> void:
	"""Initialisiert die Uhr mit Startzeit"""
	_current_time = start_time

func start() -> void:
	"""Startet die Uhr"""
	_is_running = true
	started.emit()

func stop() -> void:
	"""Stoppt die Uhr"""
	_is_running = false
	paused.emit()

func set_time_scale(scale: float) -> void:
	"""Setzt die Zeit-Skalierung"""
	if not _allow_rewind:
		scale = max(0.0, scale)  # Keine negativen Werte ohne Rewind
	_time_scale = scale
	time_scale_changed.emit(_time_scale)

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

## Zeit-Formatierung

static func get_time_stamp_array(sst_s: float) -> Array[int]:
	"""Zerlegt Zeit in [Jahre, Tage, Stunden, Minuten, Sekunden]"""
	var years: int = int(floor(sst_s / (SEC_PER_DAY * DAYS_PER_YEAR)))
	var remainder: float = fmod(sst_s, SEC_PER_DAY * DAYS_PER_YEAR)
	
	var days: int = int(floor(remainder / SEC_PER_DAY))
	remainder = fmod(remainder, SEC_PER_DAY)
	
	var hours: int = int(floor(remainder / SEC_PER_HOUR))
	remainder = fmod(remainder, SEC_PER_HOUR)
	
	var minutes: int = int(floor(remainder / SEC_PER_MIN))
	remainder = fmod(remainder, SEC_PER_MIN)
	
	var seconds: int = int(floor(remainder))
	
	return [years, days, hours, minutes, seconds]


func get_time_stamp_array_now() -> Array[int]:
	return get_time_stamp_array(_current_time)


static func get_date_from_stamp(time_stamp: Array[int]) -> Array[int]:
	"""Konvertiert [Jahre, Tage, ...] zu [Jahr, Monat, Tag]"""
	if time_stamp.size() < 2:
		return [0, 1, 1]
	
	var year: int = time_stamp[0]
	var day_of_year: int = time_stamp[1]
	
	@warning_ignore("integer_division")
	year += day_of_year / DAYS_PER_YEAR
	day_of_year = day_of_year % DAYS_PER_YEAR
	@warning_ignore("integer_division")
	var month: int = (day_of_year / DAYS_PER_MONTH) + 1
	var day: int = (day_of_year % DAYS_PER_MONTH) + 1
	
	return [year, month, day]


static func get_clock_string(time_stamp: Array[int]) -> String:
	"""Formatiert Uhrzeit als HH:MM:SS"""
	if time_stamp.size() < 5:
		return "00:00:00"
	return "%02d:%02d:%02d" % [time_stamp[2], time_stamp[3], time_stamp[4]]


static func get_date_string(time_stamp: Array[int]) -> String:
	"""Formatiert Datum als 'Tag Monat Jahr'"""
	var date := get_date_from_stamp(time_stamp)
	var year: int = date[0]
	var month: int = date[1]
	var day: int = date[2]
	
	var month_name := "Unbekannt"
	if month >= 1 and month <= MONTH_NAMES.size():
		month_name = MONTH_NAMES[month - 1]
	
	return "%d %s %d" % [day, month_name, year]


func format_time(time: float) -> String:
	"""Formatiert Zeit in lesbares Format (legacy)"""
	var stamp := get_time_stamp_array(time)
	return get_date_string(stamp) + " " + get_clock_string(stamp)


## Getters
func get_current_time() -> float:
	return _current_time

func get_time_scale() -> float:
	return _time_scale

func get_is_running() -> bool:
	return _is_running

func get_allow_rewind() -> bool:
	return _allow_rewind
