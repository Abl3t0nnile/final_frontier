## UnitValueDisplay
## Zeigt einen beschrifteten Messwert mit Einheit an.
@tool
class_name UnitValueDisplay
extends VBoxContainer

@export var caption: String = "caption"
@export var value: String = "0"
@export var unit: String = "unit"

@onready var _caption: Label = $Caption
@onready var _value:   Label = $Panel/HBox/Value
@onready var _unit:    Label = $Panel/HBox/Unit

func _ready() -> void:
	setup(caption, value, unit)


func setup(new_caption: String, new_value: String, new_unit: String) -> void:
	
	caption = new_caption
	value = new_value
	unit = new_unit
	
	_caption.text = caption
	_value.text   = value
	_unit.text    = unit


func set_value(new_value: String) -> void:
	_value.text = new_value
