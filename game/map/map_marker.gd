# res://game/map/map_marker.gd
# Zeichnet einen einzelnen Himmelskörper auf die Karte.
# Icon aus assets/map/icons/{type}/{subtype}.png — Fallback: default.png.
# _draw() nur noch für Auswahl-/Pinned-Ringe.

class_name MapMarker
extends Area2D

signal clicked(marker: MapMarker)
signal double_clicked(marker: MapMarker)
signal hovered(marker: MapMarker)
signal unhovered(marker: MapMarker)

enum MarkerState { INACTIVE = 0, DEFAULT, SELECTED, PINNED, DIMMED }
const ICON_BASE := "res://assets/map/icons/"
const ICON_DEFAULT := "res://assets/map/icons/default.png"

# Ab dieser Pixelgröße wird das Label im DEFAULT-Zustand angezeigt
const LABEL_MIN_PX: int = 24

var body_def: BodyDef = null
var body_id: String = ""
var groups: Array[String] = []
var current_state: MarkerState = MarkerState.DEFAULT
var current_size_px: int = 24

const COLLISION_PADDING_PX: float = 6.0

@onready var _sprite:    Sprite2D         = $Sprite2D
@onready var _label:     Label            = $Label
@onready var _collision: CollisionShape2D = $CollisionShape2D


func setup(def: BodyDef, label_settings: LabelSettings = null) -> void:
	body_def = def
	body_id  = def.id
	_label.text = def.name
	if label_settings != null:
		_label.label_settings = label_settings
	_collision.shape = _collision.shape.duplicate()
	_build_groups()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_load_icon()
	_update_sprite_scale()
	_update_sprite_modulate()
	_update_label()
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))
	input_event.connect(_on_input_event)


func set_state(state: MarkerState) -> void:
	if current_state == state:
		return
	current_state = state
	visible = state != MarkerState.INACTIVE
	_update_sprite_modulate()
	queue_redraw()
	_update_label()


func set_size_px(px: int) -> void:
	if current_size_px == px:
		return
	current_size_px = px
	_update_sprite_scale()
	queue_redraw()
	_update_label()


# ---------------------------------------------------------------------------
# Zeichnen — nur Ringe für SELECTED / PINNED
# ---------------------------------------------------------------------------

func _draw() -> void:
	if body_def == null:
		return
	# TODO: Icon-Rendering komplett auf _draw() umstellen (Sprite2D + Textur entfernen).
	# Pro Typ ein eigenes Shape mit draw_circle / draw_arc / draw_polygon:
	#   star   → gefüllter Kreis + kurze Strahlen
	#   planet → gefüllter Kreis
	#   moon   → kleiner Kreis, leicht transparent
	#   dwarf  → Diamant (Polygon4)
	#   struct → Kreuz oder Quadrat
	# Farbe kommt aus body_def.color_rgba, Größe aus current_size_px.
	# Vorteil: kein Textur-Sampling, keine Mipmap-Probleme, immer scharf.
	var r: float  = _sprite.texture.get_width() * _sprite.scale.x * 0.5
	var col: Color = body_def.color_rgba
	match current_state:
		MarkerState.SELECTED:
			draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
		MarkerState.PINNED:
			draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.7), 1.5, true)


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _load_icon() -> void:
	# TODO: entfernen sobald Icons auf _draw() umgestellt sind
	var tex: Texture2D = _resolve_texture()
	_sprite.texture = tex


func _resolve_texture() -> Texture2D:
	if body_def == null:
		return load(ICON_DEFAULT)
	# 1. type/subtype.png
	if not body_def.subtype.is_empty():
		var path := ICON_BASE + body_def.type + "/" + body_def.subtype + ".png"
		if ResourceLoader.exists(path):
			return load(path)
	# 2. type/type.png (kein Fallback in der Ordnerstruktur vorhanden)
	# 3. default.png
	return load(ICON_DEFAULT)


func _update_sprite_scale() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tex_w: int = _sprite.texture.get_width()
	if tex_w == 0:
		return
	var s: float = float(current_size_px) / float(tex_w)
	_sprite.scale = Vector2(s, s)
	# Collision-Radius mit Padding
	var shape := _collision.shape as CircleShape2D
	if shape != null:
		shape.radius = current_size_px * 0.5 + COLLISION_PADDING_PX
	# Label-Offset: rechts neben dem Sprite, vertikal zentriert
	var font_size: float = 10.0
	if _label != null and _label.label_settings != null:
		font_size = float(_label.label_settings.font_size)
	_label.position = Vector2(current_size_px * 0.5 + 4.0, -font_size * 0.5)


func _update_sprite_modulate() -> void:
	if _sprite == null or body_def == null:
		return
	var col: Color = body_def.color_rgba
	match current_state:
		MarkerState.DIMMED:
			_sprite.modulate = Color(col.r, col.g, col.b, 0.25)
		_:
			_sprite.modulate = col


func _update_label() -> void:
	if _label == null:
		return
	match current_state:
		MarkerState.SELECTED, MarkerState.PINNED:
			_label.visible = true
		MarkerState.DEFAULT:
			_label.visible = current_size_px >= LABEL_MIN_PX
		_:
			_label.visible = false


func _build_groups() -> void:
	groups.clear()
	groups.append("type:" + body_def.type)
	if not body_def.subtype.is_empty():
		groups.append("subtype:" + body_def.subtype)
	for tag: String in body_def.map_tags:
		groups.append(tag)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.double_click:
		double_clicked.emit(self)
	else:
		clicked.emit(self)
