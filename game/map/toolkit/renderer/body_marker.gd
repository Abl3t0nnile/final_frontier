# BodyMarker — Symbolische Darstellung eines Himmelskörpers auf der Karte.
# Node2D-Szene mit Icon (Sprite2D) und Label.
# Feste Pixelgröße — skaliert nicht mit dem Zoom, nur bei Scope-Wechsel.
# Empfängt fertige Daten von der View — keine eigene Logik über Sichtbarkeit oder Position.
# Click-Detection via Area2D — emittiert clicked(body_id) bei Linksklick.
class_name BodyMarker

extends Node2D

signal clicked(body_id: String)

const ICON_FALLBACK: String = "res://assets/map_icons/Cross.png"

const ICON_PATHS: Dictionary = {
	# Haupttypen (Fallback)
	"star":   "res://assets/map_icons/Sun.png",
	"planet": "res://assets/map_icons/Planet.png",
	"dwarf":  "res://assets/map_icons/Dwarf.png",
	"moon":   "res://assets/map_icons/Moon.png",
	"struct": "res://assets/map_icons/Struct.png",
	# Planet-Subtypen
	"planet_terrestrial": "res://assets/map_icons/TerrestrialPlanet.png",
	"planet_gas_giant":   "res://assets/map_icons/GasPlanet.png",
	"planet_ice_giant":   "res://assets/map_icons/IcePlanet.png",
	# Moon-Subtypen
	"moon_major_moon":   "res://assets/map_icons/MajorMoon.png",
	"moon_minor_moon":   "res://assets/map_icons/MinorMoon.png",
	# Struct-Subtypen
	"struct_relay":            "res://assets/map_icons/Relay.png",
	"struct_shipyard":         "res://assets/map_icons/Shipyard.png",
	"struct_outpost":          "res://assets/map_icons/Outpost.png",
	"struct_navigation_point": "res://assets/map_icons/Navpoint.png",
}

var _body_id:   String = ""
var _body_type: String = ""

@export var click_padding_px: int = 6

@onready var _icon:  Sprite2D         = $Icon
@onready var _label: Label            = $Label
@onready var _area:  Area2D           = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	_area.input_event.connect(_on_area_input_event)


func setup(body: BodyDef, size_px: int) -> void:
	_body_id   = body.id
	_body_type = body.type
	_label.text = body.name
	_icon.modulate = body.color_rgba

	var icon_key: String = body.type + "_" + body.subtype if not body.subtype.is_empty() else body.type
	var icon_path: String = ICON_PATHS.get(icon_key, ICON_PATHS.get(body.type, ICON_FALLBACK))
	_icon.texture = load(icon_path)

	set_size(size_px)


func set_size(size_px: int) -> void:
	var radius := size_px / 2.0 + float(click_padding_px)
	(_shape.shape as CircleShape2D).radius = radius

	if _icon.texture != null:
		var tex_size: Vector2 = _icon.texture.get_size()
		var longest_side: float = max(tex_size.x, tex_size.y)
		if longest_side > 0.0:
			var s: float = float(size_px) / longest_side
			_icon.scale = Vector2(s, s)


func get_body_id() -> String:
	return _body_id


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(_body_id)
