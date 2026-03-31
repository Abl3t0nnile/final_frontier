## MarkerIcon
## Rendert das Icon eines Himmelskörpers als Sprite2D.
## Icon-Auswahl: res://assets/map_icons/{subtype}.png, Fallback: default.png

class_name MarkerIcon
extends Sprite2D

const ICON_BASE_PATH := "res://assets/map_icons/"
const FALLBACK_ICON  := "res://assets/map_icons/default.png"

var size_px: int = 24


func setup(def: BodyDef) -> void:
	texture = _load_icon(def)
	_apply_scale()


func set_size(px: int) -> void:
	size_px = px
	_apply_scale()


func _load_icon(def: BodyDef) -> Texture2D:
	if def != null and not def.subtype.is_empty():
		var path := ICON_BASE_PATH + def.subtype + ".png"
		if ResourceLoader.exists(path):
			return load(path)
	return load(FALLBACK_ICON)


func _apply_scale() -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		scale = Vector2.ONE * (float(size_px) / tex_size.x)
