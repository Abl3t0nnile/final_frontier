extends Node

@export var start_time: float = 0.0:		set = _set_start_time
@export var sim_running: bool = false:		set = _set_sim_running
@export var sim_speed: float = 86400.0:		set = _set_sim_speed
@export var map_scale: float = 5.6:			set = _set_map_scale
@export var log_scale: bool = false:		set = _set_log_scale


func _ready() -> void:
	print("Main Scene instanziert.")
	SimClock.set_sst_s(start_time)


func _set_start_time(value: float) -> void:
	start_time = value
	if is_inside_tree():
		SimClock.set_sst_s(value)

func _set_sim_running(value: bool) -> void:
	sim_running = value
	if is_inside_tree():
		if value:
			SimClock.start()
		else:
			SimClock.stop()

func _set_sim_speed(value: float) -> void:
	sim_speed = value
	if is_inside_tree():
		SimClock.set_time_scale(value)

func _set_map_scale(value: float) -> void:
	map_scale = value
	if is_inside_tree():
		($NavMap as NavMap).set_scale_exp(value)

func _set_log_scale(value: bool) -> void:
	log_scale = value
	if is_inside_tree():
		var nav_map := $NavMap as NavMap
		if nav_map.is_log_scale_active() != value:
			nav_map.toggle_log_scale()
