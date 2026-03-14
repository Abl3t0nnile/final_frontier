# res://core/clock/autoload_sim_clock.gd

# Simulation Clock
# ----------------
# This autoload singleton is the central time keeper of the simulation. It's singular resoponsibility is to update the 
# simulation via it's sim_clock_tick singal. The time by which the clock advances every tick is set by the time_scale
# factor. This way the user can directly controll the simulation speed.
# The clock runs inside Godots _physics_process, to keep tick intervals at a fixed, rather than a fps dependent rate.

# TODO Implent time offset to given date. This may be used to calculate different starting dates for the simulation.

class_name SimulationClock
extends Node

# Main signal, used to advance the simulation state and to update UI elemnts concerned by time
signal sim_clock_tick(sst_s: float)

signal sim_clock_time_scale_changed(time_scale: float)

signal sim_stopped
signal sim_started

const MONTH_NAMES := [
	"Helar",
	"Selen",
	"Meron",
	"Venar",
	"Terran",
	"Aresan",
	"Jovan",
	"Satyr",
	"Uranor",
	"Nevaris",
	"Pluton",
	"Ceron"
]

const SEC_PER_MIN: 	   float = 60.0
const SEC_PER_HOUR:    float = 3600.0
const SEC_PER_DAY: 	   float = 86400.0

const DAYS_PER_WEEK:   int = 6
const WEEKS_PER_YEAR:  int = 60
const DAYS_PER_YEAR:   int = 360
const MONTHS_PER_YEAR: int = 12
const DAYS_PER_MONTH:  int = 30

# Central time value in seconds since t_0
# Central time for simulation in solar standard time sst
var _sst_s: float = 0.0
# Factor by which advancing time is scaled in physics_process
var _time_scale = 1.0
# State variable for clock status
var _running: bool = false

# ----------------------------------------------------------------------------------------------------------------------
# Initialization
# ----------------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	print("Sim Timer initialised")


func _physics_process(delta: float) -> void:
	# Break if sim is inactive
	if !_running:
		return
	# Advance SST by delta scaled by time scaling for different sim speeds
	_sst_s += delta * _time_scale
	sim_clock_tick.emit(_sst_s)

########################################################################################################################
# PUBLIC - API
########################################################################################################################

# ----------------------------------------------------------------------------------------------------------------------
# Clock Control
# ----------------------------------------------------------------------------------------------------------------------

# Starts the clock
func start() -> void:
	if _running:
		return
	else:
		_running = true
	sim_started.emit()
	print("Sim Clock started.")

# Stops the clock
func stop() -> void:
	if !_running:
		return
	else:
		_running = false
	sim_stopped.emit()
	print("Sim Clock stopped.")

# Toggles current clock state. Shorthand funtion for UI
func toggle() -> void:
	if _running:
		stop()
	else:
		start()

# Sets the clock time to a given value in sst_s. Emits a tick afterward, so all connected objects can react to the
# hard change in time. Use with caution. Is intended for initializing sim state at new game or load game.
func set_sst_s(sst_s: float) -> void:
	var new_sst_s = max(0.0, sst_s)
	if is_equal_approx(_sst_s, new_sst_s):
		return
	_sst_s = new_sst_s
	sim_clock_tick.emit(_sst_s)

# Sets the time scaling to given factor. Factor cannot be smaller than 1.0
func set_time_scale(to: float) -> void:
	var new_time_scale = max(1.0, to)
	if is_equal_approx(_time_scale, new_time_scale):
		return
	_time_scale = new_time_scale
	sim_clock_time_scale_changed.emit(_time_scale)
	print("Sim Clock time_scale changed to 1:%s" % _time_scale)

# ----------------------------------------------------------------------------------------------------------------------
# Lookup Functions
# ----------------------------------------------------------------------------------------------------------------------

# Returns if the simulation is currently running or not
func is_running() -> bool:
	return _running

# Returns the current solar standard time in seconds
func get_sst_s_now() -> float:
	return _sst_s

# Returns the current time scaling factor
func get_time_scale() -> float:
	return _time_scale

# Returns the given sst_s as an array, containing years, days, hours, minutes, seconds and hundreth seconds

static func get_time_stamp_array(sst_s: float) -> Array:

	var years: int = int(floor(sst_s / (SEC_PER_DAY * DAYS_PER_YEAR)))
	var remainder: float = fmod(sst_s, SEC_PER_DAY * DAYS_PER_YEAR)

	var days: int = int(floor(remainder / SEC_PER_DAY))
	remainder = fmod(remainder, SEC_PER_DAY)

	var hours: int = int(floor(remainder / SEC_PER_HOUR))
	remainder = fmod(remainder, SEC_PER_HOUR)

	var minutes: int = int(floor(remainder / SEC_PER_MIN))
	remainder = fmod(remainder, SEC_PER_MIN)

	var seconds: int = int(floor(remainder))
	var hundredths: int = int(round((remainder - seconds) * 100.0))

	if hundredths == 100:
		hundredths = 0
		seconds += 1

	if seconds == 60:
		seconds = 0
		minutes += 1

	if minutes == 60:
		minutes = 0
		hours += 1

	if hours == 24:
		hours = 0
		days += 1

	if days == 360:
		days = 0
		years += 1

	return [years, days, hours, minutes, seconds, hundredths]

# Shorthand function for direct access to time stamp for current time
func get_time_stamp_array_now() -> Array:
	return get_time_stamp_array(_sst_s)

# Returns the given sst_s as an formated string time stamp
func get_time_stamp_string(sst_s: float) -> String:
	var time_array: Array = get_time_stamp_array(sst_s)
	return "[%04d:%03d:%02d:%02d:%02d:%02d]" % [
		time_array[0],
		time_array[1],
		time_array[2],
		time_array[3],
		time_array[4],
		time_array[5]
	]

# Shorthand function for direct access to time stamp for current time
func get_time_stamp_string_now() -> String:
	return get_time_stamp_string(_sst_s)


func get_date(time_stamp: Array[int]) -> Array[int]:
	# Erwartetes Format:
	# [jahre, tage, stunden, minuten, sekunden, hundertstel]
	#
	# Rückgabe:
	# [jahr, monat, tag]
	# Monat und Tag sind 1-basiert

	if time_stamp.size() < 2:
		push_error("get_date(): time_stamp muss mindestens [jahre, tage] enthalten.")
		return [0, 1, 1]

	var year: int = time_stamp[0]
	var day_of_year: int = time_stamp[1]

	# Falls Tage über 359 hinausgehen, sauber in Jahre umrechnen
	year += day_of_year / DAYS_PER_YEAR
	day_of_year = day_of_year % DAYS_PER_YEAR

	# Monat und Tag berechnen
	var month: int = (day_of_year / DAYS_PER_MONTH) + 1
	var day: int = (day_of_year % DAYS_PER_MONTH) + 1

	return [year, month, day]


func get_date_string(time_stamp: Array[int]) -> String:
	var date := get_date(time_stamp)

	var year: int = date[0]
	var month: int = date[1]
	var day: int = date[2]

	var month_name := "Unbekannt"
	if month >= 1 and month <= MONTH_NAMES.size():
		month_name = MONTH_NAMES[month - 1]

	return "%d %s %d" % [day, month_name, year]