# body_marker.gd
class_name BodyMarker
extends Area2D

# ------------------------------------------------------------------------------------------------------------------
# Icon-Texturen
# ------------------------------------------------------------------------------------------------------------------

const _ICON_TEXTURES: Dictionary = {
	"star":   preload("res://assets/icons_new/Sun_256.png"),
	"planet": preload("res://assets/icons_new/Planet_128.png"),
	"dwarf":  preload("res://assets/icons_new/Dwarf_128.png"),
	"moon":   preload("res://assets/icons_new/Moon_128.png"),
	"struct": preload("res://assets/icons_new/Struct_128.png"),
}
const _ICON_BASE_SIZE: float = 256.0

# ------------------------------------------------------------------------------------------------------------------
# Signale
# ------------------------------------------------------------------------------------------------------------------

## Wird emittiert wenn der Marker angeklickt wird. Leitet das Event an die Map weiter.
signal marker_clicked(body_id: String)

## Wird emittiert bei Doppelklick auf den Marker.
signal marker_double_clicked(body_id: String)

# ------------------------------------------------------------------------------------------------------------------
# Zustand
# ------------------------------------------------------------------------------------------------------------------

# ID des zugehörigen Körpers
var _body_id: String = ""
# Typ des Körpers (für Größenbestimmung)
var _body_type: String = ""
# Anzeigename
var _body_name: String = ""
# Icon-Schlüssel
var _map_icon: String = ""
# Darstellungsfarbe
var _color: Color = Color.WHITE
# Aktuelle Größe in Pixeln
var _current_size_px: int = 8
# Ob der Marker aktiv ist (sichtbar + interaktiv)
var _active: bool = true

# ------------------------------------------------------------------------------------------------------------------
# Initialisierung
# ------------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	input_event.connect(_on_input_event)

## Initialisiert den Marker mit den Daten eines BodyDef.
func setup(body: BodyDef) -> void:
	_body_id   = body.id
	_body_type = body.type
	_body_name = body.name
	_map_icon  = body.map_icon
	_color     = body.color_rgba
	$Icon.modulate = body.color_rgba
	$Icon.texture  = _ICON_TEXTURES.get(body.type, null)
	$Label.text    = body.name
	$Label.visible = true

# ------------------------------------------------------------------------------------------------------------------
# Aktivierung
# ------------------------------------------------------------------------------------------------------------------

## Aktiviert den Marker: sichtbar und interaktiv.
func activate() -> void:
	_active = true
	visible = true
	($MouseArea as CollisionShape2D).disabled = false

## Deaktiviert den Marker: unsichtbar und keine Input-Events.
func deactivate() -> void:
	_active = false
	visible = false
	($MouseArea as CollisionShape2D).disabled = true

## Gibt zurück, ob der Marker aktiv ist.
func is_active() -> bool:
	return _active

# ------------------------------------------------------------------------------------------------------------------
# Darstellung
# ------------------------------------------------------------------------------------------------------------------

## Setzt die Marker-Größe in Pixeln. Wird von BaseMap bei Zoom-Stufenwechsel aufgerufen.
func set_marker_size(size_px: int) -> void:
	_current_size_px = size_px
	var s := size_px / _ICON_BASE_SIZE
	$Icon.scale = Vector2(s, s)
	($MouseArea.shape as CircleShape2D).radius = _ICON_BASE_SIZE * 0.5 * s
	var half := size_px * 0.25
	$Label.position = Vector2(half, half)

## Gibt die aktuelle Marker-Größe in Pixeln zurück.
func get_marker_size() -> int:
	return _current_size_px

## Setzt die Sichtbarkeit des Labels (Name des Körpers).
func set_label_visible(label_visible: bool) -> void:
	$Label.visible = label_visible

# ------------------------------------------------------------------------------------------------------------------
# Zugriff
# ------------------------------------------------------------------------------------------------------------------

## Gibt die ID des zugehörigen Körpers zurück.
func get_body_id() -> String:
	return _body_id

## Gibt den Typ des zugehörigen Körpers zurück.
func get_body_type() -> String:
	return _body_type

# ------------------------------------------------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------------------------------------------------

## Verarbeitet Input-Events auf der Klick-Area.
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.double_click:
		marker_double_clicked.emit(_body_id)
	else:
		marker_clicked.emit(_body_id)
