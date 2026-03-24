# res://game/map/map_clock.gd
# Eigene Uhr der Karte. Leitet SimClock-Ticks weiter und ermöglicht
# Time Scrubbing über einen Offset zur Simulationszeit.

class_name MapClock
extends Node

signal map_time_changed(sst_s: float)
signal scrub_mode_changed(is_scrubbing: bool)

var _sim_clock: SimulationClock = null
var _offset_s: float = 0.0


func setup(sim_clock: SimulationClock) -> void:
	_sim_clock = sim_clock
	_sim_clock.sim_clock_tick.connect(_on_sim_clock_tick)


func _on_sim_clock_tick(sst_s: float) -> void:
	map_time_changed.emit(sst_s + _offset_s)


func set_offset(offset_s: float) -> void:
	var was_scrubbing := is_scrubbing()
	_offset_s = offset_s
	if is_scrubbing() != was_scrubbing:
		scrub_mode_changed.emit(is_scrubbing())


func add_offset(delta_s: float) -> void:
	set_offset(_offset_s + delta_s)


func reset_offset() -> void:
	set_offset(0.0)


func get_map_time() -> float:
	if _sim_clock == null:
		return _offset_s
	return _sim_clock.get_sst_s_now() + _offset_s


func get_offset() -> float:
	return _offset_s


func is_scrubbing() -> bool:
	return not is_zero_approx(_offset_s)
