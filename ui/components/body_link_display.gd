## BodyLinkDisplay
## Zeigt einen verlinkten Körper (z.B. den Orbit-Parent) als klickbaren Button an.
## Klick emittiert body_link_pressed(id).

class_name BodyLinkDisplay
extends VBoxContainer

signal body_link_pressed(id: String)

@onready var _caption: Label  = $Caption
@onready var _btn:     Button = $BodyBtn

var _body_id: String = ""


func _ready() -> void:
	_btn.pressed.connect(func() -> void:
		if not _body_id.is_empty():
			body_link_pressed.emit(_body_id))


func setup(caption: String, body_id: String, display_name: String) -> void:
	_body_id         = body_id
	_caption.text    = caption
	_caption.visible = not caption.is_empty()
	_btn.text        = display_name
	visible          = not body_id.is_empty()


func clear() -> void:
	_body_id  = ""
	_btn.text = ""
	visible   = false
