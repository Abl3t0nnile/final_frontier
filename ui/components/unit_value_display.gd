## UnitValueDisplay
## Zeigt einen beschrifteten Messwert mit Einheit an.

class_name UnitValueDisplay
extends VBoxContainer

@onready var _caption: Label = $Caption
@onready var _value:   Label = $Panel/HBox/Value
@onready var _unit:    Label = $Panel/HBox/Unit


func setup(caption: String, value: String, unit: String) -> void:
	_caption.text = caption
	_value.text   = value
	_unit.text    = unit


func set_value(value: String) -> void:
	_value.text = value
