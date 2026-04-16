extends CanvasLayer

const THEME_DEFAULT := preload("res://ui/resources/themes/ui_default_theme.tres")
const THEME_AMBER   := preload("res://ui/resources/themes/ui_amber_theme.tres")
const THEME_TEAL    := preload("res://ui/resources/themes/ui_teal_theme.tres")
const THEME_GREEN   := preload("res://ui/resources/themes/ui_green_theme.tres")

@onready var _resume_btn:      Button     = $MenuPanel/PanelContainer/MarginContainer/Menu/MenuButtons/ResumeButton
@onready var _quit_btn:        Button     = $MenuPanel/PanelContainer/MarginContainer/Menu/MenuButtons/QuitButton
@onready var _crt_effect_btn:  Button     = $MenuPanel/PanelContainer/MarginContainer/Menu/CrtEffectButton
@onready var _ui_color_btn:    MenuButton = $MenuPanel/PanelContainer/MarginContainer/Menu/UIColorButton

var _crt_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_btn.pressed.connect(_hide_menu)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_crt_effect_btn.pressed.connect(_toggle_crt_effect)
	# CRT-Layer ist Geschwister-Node in Main.tscn
	_crt_layer = get_parent().get_node_or_null("CRTLayer")
	# Theme-Wechsel
	_ui_color_btn.get_popup().id_pressed.connect(_on_ui_color_selected)
	_apply_theme(THEME_DEFAULT)


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


func _apply_theme(theme: Theme) -> void:
	_update_themed_controls(get_tree().root, theme)
	var primary := theme.get_color("font_color", "Label")
	for node in get_tree().get_nodes_in_group("map_grid"):
		(node as GridRenderer).set_base_color(primary)


func _update_themed_controls(node: Node, theme: Theme) -> void:
	if node is Control and (node as Control).theme != null:
		(node as Control).theme = theme
	for child in node.get_children():
		_update_themed_controls(child, theme)


func _on_ui_color_selected(id: int) -> void:
	var theme: Theme = [THEME_DEFAULT, THEME_AMBER, THEME_TEAL, THEME_GREEN][id]
	_apply_theme(theme)
	var popup := _ui_color_btn.get_popup()
	for i in popup.item_count:
		popup.set_item_checked(i, popup.get_item_id(i) == id)
