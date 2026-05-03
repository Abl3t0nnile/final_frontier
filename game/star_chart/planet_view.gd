## PlanetView
## Vollbild-Ansicht eines Himmelskörpers für die StarChart-Szene.

class_name PlanetView
extends Control



@onready var _planet_viewer:  PlanetViewer = $PlanetViewer
@onready var _missing_label:  Label        = $MissingLabel
@onready var _starfield:      ColorRect    = $CanvasLayer/ColorRect

func _ready() -> void:
	# CanvasLayer funktioniert außerhalb eines SubViewports nicht wie erwartet.
	# ColorRect direkt unter den Control-Root verschieben und als Hintergrund nutzen.
	_starfield.reparent(self)
	_starfield.move_to_front()
	_planet_viewer.move_to_front()
	$CanvasLayer.queue_free()
	resized.connect(_update_layout)
	call_deferred("_update_layout")


func _update_layout() -> void:
	var s := size
	_starfield.position = Vector2.ZERO
	_starfield.size     = s
	var sphere := float(_planet_viewer.sphere_size)
	_planet_viewer.position = (s - Vector2(sphere, sphere)) * 0.5


func load_body(id: String) -> void:
	var found := _planet_viewer.load_body(id)
	_planet_viewer.visible = found
	if _missing_label:
		_missing_label.visible = not found
