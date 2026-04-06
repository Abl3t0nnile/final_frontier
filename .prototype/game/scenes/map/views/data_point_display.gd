@tool
extends VBoxContainer

@export var caption: String = "Caption" : set = set_caption
@export var value: String = "Value" : set = set_value

@export_group("Styling")
@export var caption_label_settings: LabelSettings = null : set = set_caption_label_settings
@export var value_label_settings: LabelSettings = null : set = set_value_label_settings
@export var line_style: StyleBoxLine = null : set = set_line_style

@onready var _caption_label: Label = $Labels/CaptionLabel
@onready var _value_label: Label = $Labels/ValueLabel
@onready var _underline: HSeparator = $Underline

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_caption_label.text = caption
	_value_label.text = value
	if caption_label_settings:
		_caption_label.label_settings = caption_label_settings
	if value_label_settings:
		_value_label.label_settings = value_label_settings
	if line_style:
		_underline.add_theme_stylebox_override("separator", line_style)

func set_caption(txt: String) -> void:
	caption = txt
	if _caption_label:
		_caption_label.text = txt

func set_value(txt: String) -> void:
	value = txt
	if _value_label:
		_value_label.text = txt

func set_caption_label_settings(setting: LabelSettings) -> void:
	caption_label_settings = setting
	if _caption_label:
		_caption_label.label_settings = setting

func set_value_label_settings(setting: LabelSettings) -> void:
	value_label_settings = setting
	if _value_label:
		_value_label.label_settings = setting

func set_line_style(style_box: StyleBoxLine) -> void:
	line_style = style_box
	if _underline:
		_underline.add_theme_stylebox_override("separator", line_style)
