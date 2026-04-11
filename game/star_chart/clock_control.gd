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

@onready var _time_scale_selector: OptionButton = $TimeStepSelector

var _solar_map: Node      = null
var _is_live_mode: bool   = true
var _map_is_playing: bool = false  # MapClock läuft (play oder reverse)
var _dot_label: Label     = null
var _pulse_tween: Tween   = null


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

	# Transport-Buttons: kein Keyboard-Fokus — Pfeiltasten/Space sollen nicht geschluckt werden
	for btn in [_jump_btn, _rewind_btn, _pause_btn, _play_btn, _forward_btn]:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE
	_time_scale_selector.focus_mode = Control.FOCUS_NONE

	# JumpBtn ist kein Toggle — immer nur Richtung Map → Live
	_jump_btn.toggle_mode = false
	_jump_btn.pressed.connect(_on_jump_pressed)
	_rewind_btn.pressed.connect(_on_rewind_pressed)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_play_btn.pressed.connect(_on_play_pressed)
	_forward_btn.pressed.connect(_on_forward_pressed)

	# TimeStepSelector mit MapClock-Presets befüllen
	_time_scale_selector.clear()
	for ts in MapClock.TIME_SCALE_PRESETS:
		_time_scale_selector.add_item(_scale_label(ts))
	_time_scale_selector.item_selected.connect(_on_time_scale_selected)

	if _solar_map.has_signal("clock_mode_changed"):
		_solar_map.clock_mode_changed.connect(_on_clock_mode_changed)

	_apply_live_mode_state(_is_live_mode)
	var map_clock: MapClock = _solar_map.get_map_clock()
	_update_time_scale_selector(map_clock.get_time_scale() if map_clock else 86400.0)


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
		_dot_label.modulate.a = 0.35  # sichtbar aber gedimmt — Uhr steht


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


func _on_time_scale_selected(index: int) -> void:
	var map_clock: MapClock = _solar_map.get_map_clock()
	if map_clock:
		map_clock.set_time_scale_index(index)


# ── Clock Signal Handlers ─────────────────────────────────────────────────────

func _on_time_scale_changed(_new_scale: float) -> void:
	pass  # GameClock-Scale ändert sich nie über die UI


func _on_clock_mode_changed(is_live: bool) -> void:
	_is_live_mode = is_live
	_map_is_playing = false
	_apply_live_mode_state(is_live)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _apply_live_mode_state(is_live: bool) -> void:
	if _jump_btn:
		_jump_btn.disabled = is_live
	if is_live and _solar_map:
		_solar_map.set_time_scale(1.0)  # Live ist immer 1:1
	_update_play_pause_buttons()


func _update_play_pause_buttons() -> void:
	# PauseBtn sichtbar wenn: Live-Mode ODER MapClock läuft
	# PlayBtn sichtbar wenn: Map-Mode UND MapClock steht
	var show_pause: bool = _is_live_mode or _map_is_playing
	if _pause_btn: _pause_btn.visible = show_pause
	if _play_btn:  _play_btn.visible  = not show_pause
	_update_dot()
	_update_mode_label()


func _update_dot() -> void:
	if _is_live_mode or _map_is_playing:
		_start_pulse()
	else:
		_stop_pulse()


func _update_mode_label() -> void:
	if not _mode_label:
		return
	if _is_live_mode:
		_mode_label.text = "Live Mode"
	elif _map_is_playing:
		_mode_label.text = "Map Clock"
	else:
		_mode_label.text = "Map Paused"


func _update_time_scale_selector(current_scale: float) -> void:
	if not _time_scale_selector:
		return
	for i in MapClock.TIME_SCALE_PRESETS.size():
		if abs(MapClock.TIME_SCALE_PRESETS[i] - current_scale) < 0.1:
			_time_scale_selector.selected = i
			return


static func _scale_label(ts: float) -> String:
	if ts < 60.0:        return "%d s"   % int(ts)
	elif ts < 3600.0:    return "%d min" % int(ts / 60.0)
	elif ts < 86400.0:   return "%d h"   % int(ts / 3600.0)
	else:                return "%d d"   % int(ts / 86400.0)


# ── Öffentliches Interface (für Keyboard-Handler) ─────────────────────────────

## Gleiche Logik wie Jump-Button — wechselt aus Map-Mode zurück in Live-Mode.
func jump_to_live() -> void:
	if _solar_map == null or _is_live_mode:
		return
	_on_jump_pressed()


## Gleiche Logik wie Pause/Play-Button — wechselt ggf. in Map-Mode.
func toggle_time() -> void:
	if _solar_map == null:
		return
	if _is_live_mode or _map_is_playing:
		_on_pause_pressed()
	else:
		_on_play_pressed()


## Gleiche Logik wie Forward-Button — wechselt in Map-Mode, startet Vorwärtslauf.
func play_forward() -> void:
	if _solar_map == null:
		return
	_on_forward_pressed()


## Gleiche Logik wie Rewind-Button — wechselt in Map-Mode, startet Rückwärtslauf.
func play_backward() -> void:
	if _solar_map == null:
		return
	_on_rewind_pressed()


## Schaltet zur nächst schnelleren Zeit-Skala und aktualisiert die Buttons.
func time_scale_up() -> void:
	if _solar_map == null:
		return
	var clock: MapClock = _solar_map.get_map_clock()
	if clock:
		clock.step_time_scale_up()
		_update_time_scale_selector(clock.get_time_scale())


## Schaltet zur nächst langsameren Zeit-Skala und aktualisiert die Buttons.
func time_scale_down() -> void:
	if _solar_map == null:
		return
	var clock: MapClock = _solar_map.get_map_clock()
	if clock:
		clock.step_time_scale_down()
		_update_time_scale_selector(clock.get_time_scale())


## Setzt Zeit-Skala per Preset-Index und aktualisiert die Buttons.
func time_scale_set(preset_index: int) -> void:
	if _solar_map == null:
		return
	var clock: MapClock = _solar_map.get_map_clock()
	if clock:
		clock.set_time_scale_index(preset_index)
		_update_time_scale_selector(clock.get_time_scale())
