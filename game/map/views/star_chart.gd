# res://game/map/views/star_chart.gd
# Screen-Controller für die Sternenkarte.
# Bettet den MapViewer über einen SubViewport ein und delegiert
# das Setup nach unten.

extends Control

@onready var _map_viewer := $Components/Body/MapPanel/ViewportContainer/MapViewport/MapViewer

@onready var _scale_exp_label := $Components/Header/Components/ScaleDisplay/ScaleExpLabel
@onready var _km_px_label     := $Components/Header/Components/ScaleDisplay/KmPxLabel
@onready var _grid_toggle_btn := $Components/Header/Components/GridControl/GridToggleBtn

@onready var _sst_label  := $Components/Footer/Components/TimeDisplay/SSTLabel
@onready var _date_label := $Components/Footer/Components/TimeDisplay/DateLabel

@onready var _clock_pause_btn := $Components/Footer/Components/ClockToggle/ClockStartBtn
@onready var _clock_play_btn  := $Components/Footer/Components/ClockToggle/ClockStopBtn

@onready var _time_scale_btns := [
	$Components/Footer/Components/TimeStepControl/TimeScaleBtn1,
	$Components/Footer/Components/TimeStepControl/TimeScaleBtn2,
	$Components/Footer/Components/TimeStepControl/TimeScaleBtn3,
	$Components/Footer/Components/TimeStepControl/TimeScaleBtn4,
	$Components/Footer/Components/TimeStepControl/TimeScaleBtn5,
]

const TIME_SCALES: Array[float] = [
	3600.0,       # 1 h
	86400.0,      # 1 d
	518400.0,     # 6 d
	2592000.0,    # 30 d
	31104000.0,   # 1 y  (360 d)
]

var _clock: SimulationClock = null


func setup(model: SolarSystemModel, clock: SimulationClock) -> void:
	_clock = clock
	_map_viewer.setup(model, clock)
	_wire_header()
	_wire_footer()


func _wire_header() -> void:
	var map_transform: MapTransform = _map_viewer.get_map_transform()
	map_transform.zoom_changed.connect(_on_zoom_changed)

	_grid_toggle_btn.button_pressed = true
	_grid_toggle_btn.toggled.connect(func(on: bool): _map_viewer.set_grid_visible(on))

	_on_zoom_changed(map_transform.km_per_px)


func _on_zoom_changed(km_per_px: float) -> void:
	var zoom_exp: float = _map_viewer.get_map_transform().zoom_exp
	_scale_exp_label.text = "%.1f" % zoom_exp
	_km_px_label.text     = "%.2f" % (km_per_px / 1_000_000.0)


func _wire_footer() -> void:
	_clock.sim_clock_tick.connect(_on_clock_tick)
	_clock.sim_started.connect(_on_sim_started)
	_clock.sim_stopped.connect(_on_sim_stopped)

	_clock_pause_btn.pressed.connect(_clock.stop)
	_clock_play_btn.pressed.connect(_clock.start)

	for i in TIME_SCALES.size():
		var btn: Button = _time_scale_btns[i]
		var scale_value: float = TIME_SCALES[i]
		btn.pressed.connect(func(): _clock.set_time_scale(scale_value))

	_sync_clock_buttons()
	_sync_time_scale_buttons()
	_update_time_display(_clock.get_sst_s_now())


func _on_clock_tick(sst_s: float) -> void:
	_update_time_display(sst_s)


func _on_sim_started() -> void:
	_clock_pause_btn.button_pressed = false
	_clock_play_btn.button_pressed  = true


func _on_sim_stopped() -> void:
	_clock_pause_btn.button_pressed = true
	_clock_play_btn.button_pressed  = false


func _update_time_display(sst_s: float) -> void:
	_sst_label.text  = _clock.get_time_stamp_string(sst_s)
	_date_label.text = _clock.get_date_string(SimulationClock.get_time_stamp_array(sst_s))


func _sync_clock_buttons() -> void:
	if _clock.is_running():
		_clock_pause_btn.button_pressed = false
		_clock_play_btn.button_pressed  = true
	else:
		_clock_pause_btn.button_pressed = true
		_clock_play_btn.button_pressed  = false


func _sync_time_scale_buttons() -> void:
	var current_scale := _clock.get_time_scale()
	for i in TIME_SCALES.size():
		_time_scale_btns[i].button_pressed = is_equal_approx(TIME_SCALES[i], current_scale)
