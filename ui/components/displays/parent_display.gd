extends VBoxContainer

signal select_body(body_id: String)

const ICON_BASE := "res://assets/map/icons/"

@onready var _parent_label: Label = $HBox/ParentPanel/ParentLabel
@onready var _icon: TextureRect = $HBox/IconPanel/Icon
@onready var _parent_panel: PanelContainer = $HBox/ParentPanel

var body_id: String = ""
var body_def: BodyDef = null


func _ready() -> void:
	# Parent-Panel klickbar machen
	_parent_panel.gui_input.connect(_on_parent_clicked)


func setup(parent_body: BodyDef) -> void:
	body_def = parent_body
	body_id = parent_body.id
	
	# Parent-Namen setzen
	_parent_label.text = parent_body.name
	
	# Icon laden
	var icon_path = ICON_BASE + parent_body.type + "/" + parent_body.subtype + ".png"
	if ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	else:
		# Fallback-Icon
		icon_path = ICON_BASE + "default.png"
		if ResourceLoader.exists(icon_path):
			_icon.texture = load(icon_path)


func _on_parent_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_body.emit(body_id)
