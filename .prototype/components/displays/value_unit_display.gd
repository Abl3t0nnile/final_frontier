@tool
class_name ValueUnitDisplay

extends VBoxContainer


@export var caption: String = "Caption" : set = set_caption
@export var value: String = "Value" : set = set_value
@export var unit: String = "Unit" : set = set_unit

@onready var _caption_label: Label = $CaptionLabel
@onready var _value_label: Label = $TextLabels/ValuePanel/ValueLabel
@onready var _unit_label: Label = $TextLabels/UnitPanel/UnitLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_caption_label.text = caption
	_value_label.text = value

func set_caption(txt: String) -> void:
	caption = txt
	if _caption_label:
		_caption_label.text = txt

func set_value(txt: String) -> void:
	value = txt
	if _value_label:
		_value_label.text = txt

func set_unit(txt: String) -> void:
	unit = txt
	if _unit_label:
		_unit_label.text = txt
