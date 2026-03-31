## ClockControl
## Steuert die Zeit-UI in der StartChart-Szene

extends Node

@onready var _mode_label: Label = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/ModeLabel
@onready var _time_label: Label = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeLabel
@onready var _date_label: Label = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/DateLabel
@onready var _jump_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/JumpBtn
@onready var _rewind_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/RewindBtn
@onready var _pause_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/PauseBtn
@onready var _play_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/PlayBtn
@onready var _forward_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/ForwardBtn

# Time Scale Buttons
@onready var _sec_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/SecBtn
@onready var _min_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/MinBtn
@onready var _hour_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/HourBtn
@onready var _day_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/DayBtn
@onready var _week_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/WeekBtn
@onready var _month_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/MonthBtn
@onready var _month6_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/Month6Btn
@onready var _year_btn: Button = $UILayer/MainDisplay/VFrame/FooterPanel/ClockControl/TimeScaleBtns/YearBtn

var _solar_map: Node = null
var _blink_timer: Timer = null
var _is_live_mode: bool = true

func _ready() -> void:
	# Blink-Timer für Live Mode
	_blink_timer = Timer.new()
	_blink_timer.wait_time = 0.5
	_blink_timer.timeout.connect(_on_blink_timer)
	add_child(_blink_timer)
	
	print("ClockControl _ready() gestartet")
	
	# Buttons mit Funktionen verbinden
	if _jump_btn:
		_jump_btn.pressed.connect(_on_jump_pressed)
		print("JumpBtn verbunden")
	else:
		print("FEHLER: JumpBtn nicht gefunden!")
		
	if _rewind_btn:
		_rewind_btn.pressed.connect(_on_rewind_pressed)
		print("RewindBtn verbunden")
	else:
		print("FEHLER: RewindBtn nicht gefunden!")
		
	if _pause_btn:
		_pause_btn.pressed.connect(_on_pause_pressed)
		print("PauseBtn verbunden")
	else:
		print("FEHLER: PauseBtn nicht gefunden!")
		
	if _play_btn:
		_play_btn.pressed.connect(_on_play_pressed)
		print("PlayBtn verbunden")
	else:
		print("FEHLER: PlayBtn nicht gefunden!")
		
	if _forward_btn:
		_forward_btn.pressed.connect(_on_forward_pressed)
		print("ForwardBtn verbunden")
	else:
		print("FEHLER: ForwardBtn nicht gefunden!")
	
	# Time Scale Buttons verbinden
	if _sec_btn:
		_sec_btn.toggled.connect(_on_time_scale_toggled.bind(1.0))  # 1 Sekunde
		print("SecBtn verbunden")
	else:
		print("FEHLER: SecBtn nicht gefunden!")
		
	if _min_btn:
		_min_btn.toggled.connect(_on_time_scale_toggled.bind(60.0))  # 1 Minute
		print("MinBtn verbunden")
	else:
		print("FEHLER: MinBtn nicht gefunden!")
		
	if _hour_btn:
		_hour_btn.toggled.connect(_on_time_scale_toggled.bind(3600.0))  # 1 Stunde
		print("HourBtn verbunden")
	else:
		print("FEHLER: HourBtn nicht gefunden!")
		
	if _day_btn:
		_day_btn.toggled.connect(_on_time_scale_toggled.bind(86400.0))  # 1 Tag
		print("DayBtn verbunden")
	else:
		print("FEHLER: DayBtn nicht gefunden!")
		
	if _week_btn:
		_week_btn.toggled.connect(_on_time_scale_toggled.bind(518400.0))  # 1 Woche (6 Tage)
		print("WeekBtn verbunden")
	else:
		print("FEHLER: WeekBtn nicht gefunden!")
		
	if _month_btn:
		_month_btn.toggled.connect(_on_time_scale_toggled.bind(2592000.0))  # 1 Monat (30 Tage)
		print("MonthBtn verbunden")
	else:
		print("FEHLER: MonthBtn nicht gefunden!")
		
	if _month6_btn:
		_month6_btn.toggled.connect(_on_time_scale_toggled.bind(15552000.0))  # 6 Monate
		print("Month6Btn verbunden")
	else:
		print("FEHLER: Month6Btn nicht gefunden!")
		
	if _year_btn:
		_year_btn.toggled.connect(_on_time_scale_toggled.bind(31536000.0))  # 1 Jahr
		print("YearBtn verbunden")
	else:
		print("FEHLER: YearBtn nicht gefunden!")
	
	# SolarMap finden
	_solar_map = _find_solar_map()
	if _solar_map:
		print("SolarMap gefunden!")
		_connect_signals()
		
		# Initialen Zustand setzen
		_is_live_mode = _solar_map.is_live_mode()
		if _is_live_mode:
			if _mode_label:
				_mode_label.text = "Live Mode"
			_blink_timer.start()
			if _jump_btn:
				_jump_btn.button_pressed = false
		else:
			if _mode_label:
				_mode_label.text = "Map Clock"
			if _jump_btn:
				_jump_btn.button_pressed = true
		
		# Play/Pause Button Zustand
		var clock = _solar_map.get_clock()
		if clock and clock.is_running:
			if _pause_btn:
				_pause_btn.visible = true
			if _play_btn:
				_play_btn.visible = false
		else:
			if _pause_btn:
				_pause_btn.visible = false
			if _play_btn:
				_play_btn.visible = true
		
		# Rewind/Forward Buttons initial deaktivieren im Live Mode
		if _rewind_btn:
			_rewind_btn.disabled = _is_live_mode
		if _forward_btn:
			_forward_btn.disabled = _is_live_mode
		
		# Aktuelle Time Scale setzen und entsprechenden Button aktivieren
		_update_time_scale_buttons(_solar_map.get_time_scale())
	else:
		print("FEHLER: SolarMap nicht gefunden!")

func _find_solar_map() -> Node:
	# SolarMap ist ein direktes Kind von StartChart
	var solar_map = $UILayer/MainDisplay/VFrame/BodyPanel/ViewPanel/SubViewportContainer/SubViewport/SolarMap
	if solar_map:
		print("SolarMap gefunden!")
		return solar_map
	
	print("SolarMap nicht gefunden!")
	return null

func _connect_signals() -> void:
	if not _solar_map:
		return
	
	_solar_map.time_changed.connect(_on_time_changed)
	_solar_map.time_scale_changed.connect(_on_time_scale_changed)
	_solar_map.clock_started.connect(_on_clock_started)
	_solar_map.clock_paused.connect(_on_clock_paused)
	_solar_map.clock_mode_changed.connect(_on_clock_mode_changed)

func _process(_delta: float) -> void:
	if not _solar_map or not _time_label or not _date_label:
		return
	
	# Zeit-Labels aktualisieren
	var current_time: float
	if _is_live_mode:
		# Im Live Mode die SimClock Zeit verwenden
		var sim_clock = _solar_map.get_clock()
		if sim_clock:
			current_time = sim_clock.get_current_time()
	else:
		# Im Scrub Mode die MapClock Zeit verwenden
		var map_clock = _solar_map.get_map_clock()
		if map_clock:
			current_time = map_clock.get_current_time()
	
	_update_time_display(current_time)

func _update_time_display(time: float) -> void:
	if not _time_label or not _date_label:
		return
		
	var time_stamp = SimClock.get_time_stamp_array(time)
	
	# TimeLabel - formatiert als JJJJ:TTT:SS:MM:SS
	_time_label.text = "%04d:%03d:%02d:%02d:%02d" % [
		time_stamp[0],  # Jahre
		time_stamp[1],  # Tage
		time_stamp[2],  # Stunden
		time_stamp[3],  # Minuten
		time_stamp[4]   # Sekunden
	]
	
	# DateLabel - formatiert als "Tag Monat Jahr - HH:MM:SS"
	var date_str = SimClock.get_date_string(time_stamp)
	var clock_str = SimClock.get_clock_string(time_stamp)
	_date_label.text = "%s - %s" % [date_str, clock_str]

func _on_blink_timer() -> void:
	if _is_live_mode and _mode_label:
		# Toggle visibility für blinkenden Effekt
		_mode_label.visible = not _mode_label.visible

func _on_jump_pressed() -> void:
	if _solar_map:
		if _is_live_mode:
			_solar_map.set_scrub_mode()
		else:
			_solar_map.set_live_mode()

func _on_rewind_pressed() -> void:
	if _solar_map and not _is_live_mode:
		var time_scale = _solar_map.get_time_scale()
		_solar_map.scrub_backward(time_scale)

func _on_pause_pressed() -> void:
	if _solar_map:
		_solar_map.pause()

func _on_play_pressed() -> void:
	if _solar_map:
		_solar_map.play()

func _on_forward_pressed() -> void:
	if _solar_map and not _is_live_mode:
		var time_scale = _solar_map.get_time_scale()
		_solar_map.scrub_forward(time_scale)

func _on_time_scale_toggled(pressed: bool, time_scale: float) -> void:
	if pressed and _solar_map:
		_solar_map.set_time_scale(time_scale)

func _update_time_scale_buttons(current_scale: float) -> void:
	# Alle Buttons deaktivieren
	if _sec_btn:
		_sec_btn.button_pressed = false
	if _min_btn:
		_min_btn.button_pressed = false
	if _hour_btn:
		_hour_btn.button_pressed = false
	if _day_btn:
		_day_btn.button_pressed = false
	if _week_btn:
		_week_btn.button_pressed = false
	if _month_btn:
		_month_btn.button_pressed = false
	if _month6_btn:
		_month6_btn.button_pressed = false
	if _year_btn:
		_year_btn.button_pressed = false
	
	# Den passenden Button aktivieren
	if abs(current_scale - 1.0) < 0.1:
		if _sec_btn:
			_sec_btn.button_pressed = true
	elif abs(current_scale - 60.0) < 0.1:
		if _min_btn:
			_min_btn.button_pressed = true
	elif abs(current_scale - 3600.0) < 0.1:
		if _hour_btn:
			_hour_btn.button_pressed = true
	elif abs(current_scale - 86400.0) < 0.1:
		if _day_btn:
			_day_btn.button_pressed = true
	elif abs(current_scale - 518400.0) < 0.1:
		if _week_btn:
			_week_btn.button_pressed = true
	elif abs(current_scale - 2592000.0) < 0.1:
		if _month_btn:
			_month_btn.button_pressed = true
	elif abs(current_scale - 15552000.0) < 0.1:
		if _month6_btn:
			_month6_btn.button_pressed = true
	elif abs(current_scale - 31536000.0) < 0.1:
		if _year_btn:
			_year_btn.button_pressed = true

func _on_time_changed(_time: float) -> void:
	# Zeit wird in _process aktualisiert
	pass

func _on_time_scale_changed(scale: float) -> void:
	# Time Scale Buttons aktualisieren
	_update_time_scale_buttons(scale)

func _on_clock_started() -> void:
	if _pause_btn:
		_pause_btn.visible = true
	if _play_btn:
		_play_btn.visible = false

func _on_clock_paused() -> void:
	if _pause_btn:
		_pause_btn.visible = false
	if _play_btn:
		_play_btn.visible = true

func _on_clock_mode_changed(is_live: bool) -> void:
	_is_live_mode = is_live
	
	if is_live:
		if _mode_label:
			_mode_label.text = "Live Mode"
		_blink_timer.start()
		if _jump_btn:
			_jump_btn.button_pressed = false
	else:
		if _mode_label:
			_mode_label.text = "Map Clock"
			_mode_label.visible = true
		_blink_timer.stop()
		if _jump_btn:
			_jump_btn.button_pressed = true
	
	# Rewind/Forward Buttons nur im Scrub Mode aktivieren
	if _rewind_btn:
		_rewind_btn.disabled = is_live
	if _forward_btn:
		_forward_btn.disabled = is_live
