## MapClock
## User-controlled time navigation for the map display
## Supports bidirectional time control and live mode tracking

class_name MapClock
extends Node

# Internal state
var _current_time: float = 0.0
var _time_scale: float = 86400.0   # sim-seconds per real-second
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

# Internal processing
func _physics_process(delta: float) -> void:
	if _live and _sim_clock != null:
		_current_time = _sim_clock.get_current_time()
		tick.emit(_current_time)
	elif _running:
		var direction = -1.0 if _reversed else 1.0
		_current_time += delta * _time_scale * direction
		tick.emit(_current_time)
