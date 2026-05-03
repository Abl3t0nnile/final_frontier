extends CanvasLayer

signal start_requested
signal boot_complete

const MONO_FONT    := preload("res://assets/fonts/SUSEMono-Bold.ttf")
const DELAY_HEADER := 1.0
const DELAY_INFO   := 1.0
const DELAY_ITEM   := 0.1

const COLOR_HEADER  := Color(1.00, 0.69, 0.00, 1.0)   # amber bright
const COLOR_INFO    := Color(0.85, 0.72, 0.45, 1.0)   # amber mid
const COLOR_ITEM    := Color(0.55, 0.46, 0.28, 1.0)   # amber dim
const COLOR_SUCCESS := Color(0.27, 1.00, 0.53, 1.0)   # green
const COLOR_ERROR   := Color(1.00, 0.30, 0.30, 1.0)   # red

const BLINK_SPEED  := 0.55  # Sekunden pro Blink-Halbzyklus

@onready var _start_menu:    VBoxContainer   = $MarginContainer/StartMenu
@onready var _panel:         PanelContainer  = $MarginContainer/PanelContainer
@onready var _scroll:        ScrollContainer = $MarginContainer/PanelContainer/MarginContainer/ScrollAnimation
@onready var _log_container: VBoxContainer   = $MarginContainer/PanelContainer/MarginContainer/ScrollAnimation/VBoxContainer

var _waiting_for_click := false
var _blink_label: Label = null
var _blink_timer  := 0.0
var _blink_state  := true


func _ready() -> void:
	$MarginContainer/StartMenu/StartButton.pressed.connect(_on_start_pressed)
	$MarginContainer/StartMenu/QuitButton.pressed.connect(_on_quit_pressed)
	_panel.hide()
	_log_container.size_flags_vertical = Control.SIZE_FILL


func _process(delta: float) -> void:
	if not _waiting_for_click or _blink_label == null:
		return
	_blink_timer += delta
	if _blink_timer >= BLINK_SPEED:
		_blink_timer = 0.0
		_blink_state = not _blink_state
		_blink_label.modulate.a = 1.0 if _blink_state else 0.0


func _input(event: InputEvent) -> void:
	if not _waiting_for_click:
		return
	if event is InputEventMouseButton and event.pressed:
		_finish_boot()
	elif event is InputEventKey and event.pressed and not event.echo:
		_finish_boot()


func _on_start_pressed() -> void:
	_start_menu.hide()
	start_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()


## Startet die animierte Boot-Sequenz. Die letzte "success"-Zeile blinkt
## und wartet auf einen Klick/Tastendruck bevor boot_complete emittiert wird.
func play_boot_sequence(messages: Array) -> void:
	_panel.show()
	_animate_lines(messages)


func _animate_lines(messages: Array) -> void:
	for msg in messages:
		var text: String = msg.get("text", "")
		var type: String = msg.get("type", "info")
		_add_line(text, type)
		await get_tree().process_frame
		_scroll.scroll_vertical = 999999
		await get_tree().create_timer(_delay_for(type)).timeout

	# Letzte Zeile: blinken + auf Klick warten
	await get_tree().create_timer(0.4).timeout
	_blink_label = _add_line("[ KLICK ZUM FORTFAHREN ]", "success")
	await get_tree().process_frame
	_scroll.scroll_vertical = 999999
	_waiting_for_click = true


func _finish_boot() -> void:
	_waiting_for_click = false
	if _blink_label:
		_blink_label.modulate.a = 1.0
	boot_complete.emit()


func _add_line(text: String, type: String) -> Label:
	var label := Label.new()
	label.text          = text if not text.is_empty() else " "
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", MONO_FONT)
	label.add_theme_font_size_override("font_size", 22 if type == "header" else 17)
	label.add_theme_color_override("font_color", _color_for(type))
	_log_container.add_child(label)
	return label


func _delay_for(type: String) -> float:
	match type:
		"header":           return DELAY_HEADER
		"item":             return DELAY_ITEM
		"success", "error": return DELAY_INFO * 1.5
		_:                  return DELAY_INFO


func _color_for(type: String) -> Color:
	match type:
		"header":  return COLOR_HEADER
		"success": return COLOR_SUCCESS
		"error":   return COLOR_ERROR
		"item":    return COLOR_ITEM
		_:         return COLOR_INFO
