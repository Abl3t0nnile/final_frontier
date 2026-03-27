extends PanelContainer

signal select_body(body_id: String)

const ICON_BASE := "res://assets/map/icons/"

@onready var _icon: TextureRect = $HBoxContainer/Icon
@onready var _name_label: Label = $HBoxContainer/NameLabel
@onready var _orbit_label: Label = $HBoxContainer/OrbitSemMajAxLabel

var body_id: String = ""
var body_def: BodyDef = null
var _pending_setup: BodyDef = null
var hide_sma: bool = false


func _ready() -> void:
	# Nodes manuell zuweisen
	_icon = $HBoxContainer/Icon
	_name_label = $HBoxContainer/NameLabel
	_orbit_label = $HBoxContainer/OrbitSemMajAxLabel
	
	gui_input.connect(_on_gui_input)
	
	# Wenn setup() schon vor _ready() aufgerufen wurde
	if _pending_setup != null:
		_apply_setup(_pending_setup)
		_pending_setup = null


func setup(body: BodyDef) -> void:
	if _name_label == null:
		# _ready() wurde noch nicht aufgerufen
		_pending_setup = body
		return
	
	_apply_setup(body)


func _apply_setup(body: BodyDef) -> void:
	body_def = body
	body_id = body.id
	
	# Name setzen
	_name_label.text = body.name
	
	# Icon laden - gleiche Logik wie MapController
	var icon_path = ICON_BASE + body.type + "/" + body.subtype + ".png"
	if ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	else:
		# Fallback-Icon
		icon_path = ICON_BASE + "default.png"
		if ResourceLoader.exists(icon_path):
			_icon.texture = load(icon_path)
	
	# Orbit-Daten anzeigen (semi-major axis)
	if hide_sma:
		_orbit_label.text = ""
	elif body.has_motion():
		match body.motion.model:
			"circular":
				var motion = body.motion as CircularMotionDef
				_orbit_label.text = "%.1f km" % motion.orbital_radius_km
			"kepler2d":
				var motion = body.motion as Kepler2DMotionDef
				_orbit_label.text = "%.1f km" % motion.a_km
			_:
				_orbit_label.text = "N/A"
	else:
		_orbit_label.text = "N/A"


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_body.emit(body_id)
