# res://game/map/views/star_chart.gd
# Screen-Controller für die Sternenkarte.
# Bettet den MapViewer über einen SubViewport ein und delegiert
# das Setup nach unten.

extends Control

@export var ui_color: Color = Color(0.706, 0.706, 0.706, 1):
	set(v):
		ui_color = v
		if is_node_ready():
			_apply_ui_color()

@export var text_color: Color = Color(0, 0, 0, 1):
	set(v):
		text_color = v
		if is_node_ready():
			_apply_text_color()

@onready var _map_viewer  := $Components/Body/MapPanel/ViewportContainer/MapViewport/MapViewer
@onready var _info_panel  := $Components/Body/InfoPanel

@onready var _header   := $Components/Header
@onready var _footer   := $Components/Footer
@onready var _map_panel := $Components/Body/MapPanel

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

var _panel_style: StyleBoxFlat
var _border_style: StyleBoxFlat
var _btn_pressed_style: StyleBoxFlat
var _btn_hover_style: StyleBoxFlat

const TIME_SCALES: Array[float] = [
	3600.0,       # 1 h
	86400.0,      # 1 d
	518400.0,     # 6 d
	2592000.0,    # 30 d
	31104000.0,   # 1 y  (360 d)
]

var _clock: SimulationClock = null


func _ready() -> void:
	_panel_style = (_header.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_border_style = (_map_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_btn_pressed_style = (_grid_toggle_btn.get_theme_stylebox("pressed") as StyleBoxFlat).duplicate()
	_btn_hover_style = (_grid_toggle_btn.get_theme_stylebox("hover") as StyleBoxFlat).duplicate()
	_apply_ui_color()
	_apply_text_color()


func _apply_ui_color() -> void:
	_panel_style.bg_color = ui_color
	_header.add_theme_stylebox_override("panel", _panel_style)
	_footer.add_theme_stylebox_override("panel", _panel_style)

	_border_style.border_color = ui_color
	_map_panel.add_theme_stylebox_override("panel", _border_style)

	_btn_pressed_style.border_color = ui_color
	_btn_hover_style.bg_color = ui_color
	var all_btns: Array = [_grid_toggle_btn, _clock_pause_btn, _clock_play_btn]
	all_btns.append_array(_time_scale_btns)
	for btn: Button in all_btns:
		btn.add_theme_stylebox_override("pressed", _btn_pressed_style)
		btn.add_theme_stylebox_override("hover", _btn_hover_style)

	_info_panel.set_text_color(ui_color)


func _apply_text_color() -> void:
	for label: Label in _collect_labels(_header):
		label.add_theme_color_override("font_color", text_color)
	for label: Label in _collect_labels(_footer):
		label.add_theme_color_override("font_color", text_color)

	var all_btns: Array = [_grid_toggle_btn, _clock_pause_btn, _clock_play_btn]
	all_btns.append_array(_time_scale_btns)
	for btn: Button in all_btns:
		btn.add_theme_color_override("font_color", text_color)
		btn.add_theme_color_override("font_pressed_color", text_color)


func _collect_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			result.append(child)
		result.append_array(_collect_labels(child))
	return result


func setup(model: SolarSystemModel, clock: SimulationClock) -> void:
	_clock = clock
	_map_viewer.setup(model, clock)
	_info_panel.setup(model)
	_info_panel.hide()
	_wire_header()
	_wire_footer()
	_wire_info_panel()


func _wire_info_panel() -> void:
	_map_viewer.body_selected.connect(func(id: String):
		_info_panel.load_body(id)
		_info_panel.show()
	)
	_map_viewer.body_deselected.connect(func(): _info_panel.hide())


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
