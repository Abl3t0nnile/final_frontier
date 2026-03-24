extends PanelContainer

@onready var _data_panel: Control = $MarginContainer/Body/Data
@onready var _info_panel: Control = $MarginContainer/Body/Info
@onready var _satelites_panel: Control = $MarginContainer/Body/Satelites

@onready var _data_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/DataBtn
@onready var _info_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/InfoBtn
@onready var _satelites_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/SatelitesBtn

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	_data_panel_btn.toggled.connect(_on_data_panel_btn_toggled)
	_info_panel_btn.toggled.connect(_on_info_panel_btn_toggled)
	_satelites_panel_btn.toggled.connect(_on_satelites_panel_btn_toggled)


func _on_data_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_data_panel.show()
	else:
		_data_panel.hide()

func _on_info_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_info_panel.show()
	else:
		_info_panel.hide()

func _on_satelites_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_satelites_panel.show()
	else:
		_satelites_panel.hide()
