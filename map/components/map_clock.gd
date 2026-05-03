## MapClock
## User-controlled time navigation for the map display
## Supports bidirectional time control and live mode tracking

class_name MapClock
extends Node

# Zeit-Skala Presets — zentrale Quelle für alle Systeme
const TIME_SCALE_PRESETS: Array[float] = [
	1.0,          # 1 Sek
	3600.0,       # 1 Stunde
	86400.0,      # 1 Tag
	518400.0,     # 6 Tage
	2592000.0,    # 30 Tage
	7776000.0,    # 90 Tage
	15552000.0,   # 180 Tage
	31104000.0,   # 360 Tage
	155520000.0,  # 1800 Tage
	311040000.0,  # 3600 Tage
]

# Internal state
var _current_time: float = 0.0
var _time_scale: float = 86400.0   # sim-seconds per real-second (default: 1 Tag)
var _time_scale_index: int = 2     # Index in TIME_SCALE_PRESETS (default: 1 Tag)
var _running: bool = false
var _reversed: bool = false
var _live: bool = false
var _sim_clock: SimClock = null     # only set when in live mode

# Signals
signal tick(sst_s: float)            # Fired each _physics_process while running
signal time_changed(sst_s: float)    # Fired on manual set_time() / scrub / live-mode snap
signal live_mode_changed(is_live: bool)

# Time control (user-facing)
func play() -> void:
	"""Start ticking forward at current speed"""
	if _live:
		exit_live_mode()
	_running = true
	_reversed = false

func pause() -> void:
	"""Stop ticking"""
	if _live:
		exit_live_mode()
	_running = false

func reverse() -> void:
	"""Start ticking backward at current speed"""
	if _live:
		exit_live_mode()
	_running = true
	_reversed = true

func set_time(sst_s: float) -> void:
	"""Jump to specific time (for scrubbing)"""
	if _live:
		exit_live_mode()
	_current_time = sst_s
	time_changed.emit(_current_time)

func get_time_scale() -> float:
	return _time_scale

func set_time_scale(scale: float) -> void:
	"""Set speed (always positive, direction via play/reverse)"""
	if _live:
		exit_live_mode()
	_time_scale = scale

func set_time_scale_index(index: int) -> void:
	"""Setzt Zeit-Skala anhand des Preset-Index"""
	_time_scale_index = clampi(index, 0, TIME_SCALE_PRESETS.size() - 1)
	set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])

func step_time_scale_up() -> void:
	"""Schaltet zur nächst schnelleren Zeit-Skala"""
	set_time_scale_index(_time_scale_index + 1)

func step_time_scale_down() -> void:
	"""Schaltet zur nächst langsameren Zeit-Skala"""
	set_time_scale_index(_time_scale_index - 1)

func get_current_time() -> float:
	"""Current displayed time"""
	return _current_time

# Live mode
func enter_live_mode(sim_clock: SimClock) -> void:
	"""Start tracking sim clock"""
	_sim_clock = sim_clock
	_live = true
	_running = false  # Let _physics_process handle updates
	_reversed = false
	live_mode_changed.emit(true)

func exit_live_mode() -> void:
	"""Return to free mode"""
	_live = false
	_sim_clock = null
	live_mode_changed.emit(false)

func is_live() -> bool:
	"""Query current mode"""
	return _live

func is_running() -> bool:
	"""Gibt true zurück wenn der Clock aktiv tickt (play oder reverse)"""
	return _running

# Internal processing
func _physics_process(delta: float) -> void:
	if _live and _sim_clock != null:
		_current_time = _sim_clock.get_current_time()
		tick.emit(_current_time)
	elif _running:
		var direction = -1.0 if _reversed else 1.0
		_current_time += delta * _time_scale * direction
		tick.emit(_current_time)
