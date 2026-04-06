## ClockControl
## Footer-Komponente der StarChart-Szene.
## Wird an den ClockControl-HBoxContainer angehängt.
## Initialisierung via setup(solar_map) durch den StartChartController.

extends HBoxContainer

@onready var _mode_label:      Label  = $ModeLabel
@onready var _map_time_label:  Label  = $TimeDisplay/Grid/MapTimeLabel
@onready var _sst_label:       Label  = $TimeDisplay/Grid/SSTLabel

@onready var _day_label:    Label  = $DateDisplay/HBox/DayLabel
@onready var _month_label:  Label  = $DateDisplay/HBox/MonthLabel
@onready var _year_label:   Label  = $DateDisplay/HBox/YearLabel
@onready var _hour_label:   Label  = $DateDisplay/HBox/HourLabel
@onready var _minute_label: Label  = $DateDisplay/HBox/MinuteLabel
@onready var _second_label: Label  = $DateDisplay/HBox/SecondLabel

@onready var _jump_btn:    Button  = $JumpBtn
@onready var _rewind_btn:  Button  = $RewindBtn
@onready var _pause_btn:   Button  = $PauseBtn
@onready var _play_btn:    Button  = $PlayBtn
@onready var _forward_btn: Button  = $ForwardBtn

@onready var _sec_btn:    Button   = $TimeScaleBtns/SecBtn
@onready var _min_btn:    Button   = $TimeScaleBtns/MinBtn
@onready var _hour_btn:   Button   = $TimeScaleBtns/HourBtn
@onready var _day_btn:    Button   = $TimeScaleBtns/DayBtn
@onready var _week_btn:   Button   = $TimeScaleBtns/WeekBtn
@onready var _month_btn:  Button   = $TimeScaleBtns/MonthBtn
@onready var _month6_btn: Button   = $TimeScaleBtns/Month6Btn
@onready var _year_btn:   Button   = $TimeScaleBtns/YearBtn

var _solar_map: Node        = null
var _is_live_mode: bool     = true
var _map_is_playing: bool   = false  # MapClock läuft (play oder reverse)
var _dot_label: Label       = null
var _pulse_tween: Tween     = null
var _updating_buttons: bool = false  # Guard gegen Toggle-Feedback beim programmatischen Setzen


func _ready() -> void:
	_dot_label = Label.new()
	_dot_label.text = "●"
	_dot_label.add_theme_font_size_override("font_size", 24)
	_dot_label.add_theme_color_override("font_color", Color(0.078431375, 0.078431375, 0.078431375, 1))
	_dot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dot_label.modulate.a = 0.0
	add_child(_dot_label)
	move_child(_dot_label, 0)


## Wird von StartChartController nach receive_solar_map() aufgerufen
func setup(solar_map: Node) -> void:
	_solar_map = solar_map
	_is_live_mode = _solar_map.is_live_mode()

	# JumpBtn ist kein Toggle — immer nur Richtung Map → Live
	_jump_btn.toggle_mode = false
	_jump_btn.pressed.connect(_on_jump_pressed)
	_rewind_btn.pressed.connect(_on_rewind_pressed)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_play_btn.pressed.connect(_on_play_pressed)
	_forward_btn.pressed.connect(_on_forward_pressed)

	_sec_btn.toggled.connect(_on_time_scale_toggled.bind(1.0))
	_min_btn.toggled.connect(_on_time_scale_toggled.bind(60.0))
	_hour_btn.toggled.connect(_on_time_scale_toggled.bind(3600.0))
	_day_btn.toggled.connect(_on_time_scale_toggled.bind(86400.0))
	_week_btn.toggled.connect(_on_time_scale_toggled.bind(518400.0))
	_month_btn.toggled.connect(_on_time_scale_toggled.bind(2592000.0))
	_month6_btn.toggled.connect(_on_time_scale_toggled.bind(15552000.0))
	_year_btn.toggled.connect(_on_time_scale_toggled.bind(31536000.0))

	if _solar_map.has_signal("clock_mode_changed"):
		_solar_map.clock_mode_changed.connect(_on_clock_mode_changed)

	_apply_live_mode_state(_is_live_mode)
	var map_clock: MapClock = _solar_map.get_map_clock()
	_update_time_scale_buttons(map_clock.get_time_scale() if map_clock else 86400.0)


func _process(_delta: float) -> void:
	if _solar_map == null:
		return
	_update_clock_display()


# ── Display ───────────────────────────────────────────────────────────────────

func _update_clock_display() -> void:
	# MapClock-Zeit (immer aktuell, auch im Live-Mode via enter_live_mode)
	var map_clock: MapClock = _solar_map.get_map_clock()
	var map_time: float = map_clock.get_current_time() if map_clock else 0.0

	# SST = GameClock
	var sst_clock: SimClock = _solar_map.get_clock()
	var sst_time: float = sst_clock.get_current_time() if sst_clock else 0.0

	# MapTimeLabel und DateDisplay zeigen Map-Zeit
	var map_ts := SimClock.get_time_stamp_array(map_time)
	if _map_time_label:
		_map_time_label.text = "%04d:%03d:%02d:%02d:%02d" % [map_ts[0], map_ts[1], map_ts[2], map_ts[3], map_ts[4]]

	var date := SimClock.get_date_from_stamp(map_ts)
	var month_name := SimClock.MONTH_NAMES[date[1] - 1] \
		if date[1] >= 1 and date[1] <= SimClock.MONTH_NAMES.size() else "?"

	if _day_label:    _day_label.text    = str(date[2])
	if _month_label:  _month_label.text  = month_name
	if _year_label:   _year_label.text   = str(date[0])
	if _hour_label:   _hour_label.text   = "%02d" % map_ts[2]
	if _minute_label: _minute_label.text = "%02d" % map_ts[3]
	if _second_label: _second_label.text = "%02d" % map_ts[4]

	# SSTLabel zeigt GameClock-Zeit
	var sst_ts := SimClock.get_time_stamp_array(sst_time)
	if _sst_label:
		_sst_label.text = "%04d:%03d:%02d:%02d:%02d" % [sst_ts[0], sst_ts[1], sst_ts[2], sst_ts[3], sst_ts[4]]


func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	if not _dot_label:
		return
	_dot_label.modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_dot_label, "modulate:a", 0.1, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_dot_label, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _dot_label:
		_dot_label.modulate.a = 0.0  # unsichtbar aber Layout bleibt stabil


# ── Button Callbacks ──────────────────────────────────────────────────────────

## Map → Live. Im Live-Mode deaktiviert.
func _on_jump_pressed() -> void:
	_solar_map.set_live_mode()


## Live → Map (paused). Im Map-Mode: pausiert MapClock.
func _on_pause_pressed() -> void:
	if _is_live_mode:
		_solar_map.set_scrub_mode()
		# MapClock ist nach exit_live_mode bereits gestoppt
	else:
		_solar_map.get_map_clock().pause()
		_map_is_playing = false
		_update_play_pause_buttons()


## Map-Mode: MapClock läuft vorwärts weiter.
func _on_play_pressed() -> void:
	var map_clock: MapClock = _solar_map.get_map_clock()
	if map_clock:
		map_clock.play()
	_map_is_playing = true
	_update_play_pause_buttons()


## Aktiviert Map-Mode (falls Live) und spult rückwärts mit eingestellter Geschwindigkeit.
func _on_rewind_pressed() -> void:
	if _is_live_mode:
		_solar_map.set_scrub_mode()
	var map_clock: MapClock = _solar_map.get_map_clock()
	if map_clock:
		map_clock.reverse()
	_map_is_playing = true
	_update_play_pause_buttons()


## Aktiviert Map-Mode (falls Live) und spult vorwärts mit eingestellter Geschwindigkeit.
func _on_forward_pressed() -> void:
	if _is_live_mode:
		_solar_map.set_scrub_mode()
	var map_clock: MapClock = _solar_map.get_map_clock()
	if map_clock:
		map_clock.play()
	_map_is_playing = true
	_update_play_pause_buttons()


func _on_time_scale_toggled(pressed: bool, time_scale: float) -> void:
	if _updating_buttons or not pressed:
		return
	# Time-Scale-Buttons steuern nur die MapClock — Live-Mode läuft immer 1:1
	var map_clock: MapClock = _solar_map.get_map_clock()
	if map_clock:
		map_clock.set_time_scale(time_scale)
	_update_time_scale_buttons(time_scale)


# ── Clock Signal Handlers ─────────────────────────────────────────────────────

func _on_time_scale_changed(_new_scale: float) -> void:
	pass  # GameClock-Scale ändert sich nie über die UI


func _on_clock_mode_changed(is_live: bool) -> void:
	_is_live_mode = is_live
	_map_is_playing = false
	_apply_live_mode_state(is_live)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _apply_live_mode_state(is_live: bool) -> void:
	if _mode_label:
		_mode_label.text = "Live Mode" if is_live else "Map Clock"
	if _jump_btn:
		_jump_btn.disabled = is_live
	if is_live:
		if _solar_map:
			_solar_map.set_time_scale(1.0)  # Live ist immer 1:1
		_start_pulse()
	else:
		_stop_pulse()
	_update_play_pause_buttons()


func _update_play_pause_buttons() -> void:
	# PauseBtn sichtbar wenn: Live-Mode ODER MapClock läuft
	# PlayBtn sichtbar wenn: Map-Mode UND MapClock steht
	var show_pause: bool = _is_live_mode or _map_is_playing
	if _pause_btn: _pause_btn.visible = show_pause
	if _play_btn:  _play_btn.visible  = not show_pause


func _update_time_scale_buttons(current_scale: float) -> void:
	_updating_buttons = true
	var btns   := [_sec_btn, _min_btn, _hour_btn, _day_btn, _week_btn, _month_btn, _month6_btn, _year_btn]
	var scales := [1.0, 60.0, 3600.0, 86400.0, 518400.0, 2592000.0, 15552000.0, 31536000.0]
	for i in btns.size():
		if btns[i]:
			btns[i].button_pressed = abs(current_scale - scales[i]) < 0.1
	_updating_buttons = false
