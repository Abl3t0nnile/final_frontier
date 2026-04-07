## MarkerIcon
## Rendert das Icon eines Himmelskörpers als Sprite2D.
## Icon-Auswahl: res://assets/icons/map/{subtype}.png, Fallback: default.png

class_name MarkerIcon
extends Sprite2D

const ICON_BASE_PATH := "res://assets/icons/map/"
const FALLBACK_ICON  := "res://assets/icons/map/default.png"

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
	if ResourceLoader.exists(FALLBACK_ICON):
		return load(FALLBACK_ICON)
	return _create_fallback_texture()


func _create_fallback_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.8, 0.7))
	return ImageTexture.create_from_image(img)


func _apply_scale() -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		scale = Vector2.ONE * (float(size_px) / tex_size.x)
