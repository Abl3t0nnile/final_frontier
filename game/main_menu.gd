extends CanvasLayer

@onready var _resume_btn:     Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/MenuButtons/ResumeButton
@onready var _quit_btn:       Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/MenuButtons/QuitButton
@onready var _crt_effect_btn: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/CrtEffectButton

var _crt_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_btn.pressed.connect(_hide_menu)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_crt_effect_btn.pressed.connect(_toggle_crt_effect)
	# CRT-Layer ist Geschwister-Node in Main.tscn
	_crt_layer = get_parent().get_node_or_null("CRTLayer")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_toggle_menu"):
		_toggle_menu()
		get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	visible = not visible
	get_tree().paused = visible


func _hide_menu() -> void:
	visible = false
	get_tree().paused = false


func _toggle_crt_effect() -> void:
	if _crt_layer:
		_crt_layer.visible = not _crt_layer.visible
