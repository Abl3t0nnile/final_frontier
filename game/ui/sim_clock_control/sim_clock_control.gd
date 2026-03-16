# res://game/ui/sim_clock_control/sim_clock_control.gd
#
# SimClock Control Panel
# ----------------------
# Self-contained UI panel for controlling the SimClock autoload.
# Connects directly to SimClock signals — no wiring from main.gd required.

extends PanelContainer

const SPEED_PRESETS: Array = [
	["Echtzeit    (1s/s)",           1.0],
	["1 Min/s    (60s/s)",           60.0],
	["1 Std/s    (3.600s/s)",        3600.0],
	["1 Tag/s    (86.400s/s)",       86400.0],
	["1 Woche/s  (518.400s/s)",      518400.0],
	["1 Monat/s  (2.592.000s/s)",    2592000.0],
	["1 Jahr/s   (31.104.000s/s)",   31104000.0],
]

@onready var _label_sst:    Label        = $MarginContainer/VBoxContainer/LabelSST
@onready var _label_date:   Label        = $MarginContainer/VBoxContainer/LabelDate
@onready var _btn_toggle:   Button       = $MarginContainer/VBoxContainer/BtnToggle
@onready var _option_speed: OptionButton = $MarginContainer/VBoxContainer/OptionSpeed


func _ready() -> void:
	_build_speed_options()
	_sync_initial_state()
	_connect_signals()


func _build_speed_options() -> void:
	for preset in SPEED_PRESETS:
		_option_speed.add_item(preset[0] as String)


func _sync_initial_state() -> void:
	_update_toggle_button(SimClock.is_running())
	_sync_speed_selection(SimClock.get_time_scale())
	_update_time_display()


func _connect_signals() -> void:
	SimClock.sim_started.connect(_on_sim_started)
	SimClock.sim_stopped.connect(_on_sim_stopped)
	SimClock.sim_clock_tick.connect(_on_sim_clock_tick)
	SimClock.sim_clock_time_scale_changed.connect(_on_time_scale_changed)
	_btn_toggle.pressed.connect(_on_btn_toggle_pressed)
	_option_speed.item_selected.connect(_on_speed_selected)


# ----------------------------------------------------------------------------------------------------------------------
# SimClock Signal Handlers
# ----------------------------------------------------------------------------------------------------------------------

func _on_sim_started() -> void:
	_update_toggle_button(true)


func _on_sim_stopped() -> void:
	_update_toggle_button(false)


func _on_sim_clock_tick(_sst_s: float) -> void:
	_update_time_display()


func _on_time_scale_changed(time_scale: float) -> void:
	_sync_speed_selection(time_scale)


# ----------------------------------------------------------------------------------------------------------------------
# UI Signal Handlers
# ----------------------------------------------------------------------------------------------------------------------

func _on_btn_toggle_pressed() -> void:
	SimClock.toggle()


func _on_speed_selected(index: int) -> void:
	if index < 0 or index >= SPEED_PRESETS.size():
		return
	SimClock.set_time_scale(SPEED_PRESETS[index][1] as float)


# ----------------------------------------------------------------------------------------------------------------------
# Display Helpers
# ----------------------------------------------------------------------------------------------------------------------

func _update_toggle_button(running: bool) -> void:
	_btn_toggle.text = "Stop" if running else "Start"


func _update_time_display() -> void:
	_label_sst.text = SimClock.get_time_stamp_string_now()
	var ts: Array[int] = []
	ts.assign(SimClock.get_time_stamp_array_now())
	_label_date.text = SimClock.get_date_string(ts)


func _sync_speed_selection(time_scale: float) -> void:
	for i in SPEED_PRESETS.size():
		if is_equal_approx(SPEED_PRESETS[i][1] as float, time_scale):
			_option_speed.select(i)
			return
	_option_speed.select(-1)
