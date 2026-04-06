## PlanetView
## Vollbild-Ansicht eines Himmelskörpers für die StarChart-Szene.

class_name PlanetView
extends Control


const _TEXTURE_BASE := "res://assets/textures/planets_16_levels/"
const _BODY_TEXTURES: Dictionary = {
	"sun":      { "surface": "2k_sun.png" },
	"mercury":  { "surface": "2k_mercury.png" },
	"venus":    { "surface": "black_surface.png", "cloud": "2k_venus_atmosphere.png" },
	"terra":    { "surface": "2k_earth_daymap.png", "cloud": "2k_earth_clouds.png" },
	"mars":     { "surface": "2k_mars.png" },
	"jupiter":  { "surface": "black_surface.png", "cloud": "2k_jupiter.png" },
	"saturn":   { "surface": "black_surface.png", "cloud": "2k_saturn.png" },
	"uranus":   { "surface": "black_surface.png", "cloud": "2k_uranus.png" },
	"neptune":  { "surface": "black_surface.png", "cloud": "2k_neptune.png" },
	"moon":     { "surface": "2k_moon.png" },
	"ceres":    { "surface": "2k_ceres.png" },
	"eris":     { "surface": "2k_eris.png" },
	"haumea":   { "surface": "2k_haumea.png" },
	"makemake": { "surface": "2k_makemake.png" },
}

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
	var entry: Dictionary = _BODY_TEXTURES.get(id, {})
	_planet_viewer.use_sun_shader = (id == "sun")
	if entry.is_empty():
		_planet_viewer.visible = false
		if _missing_label:
			_missing_label.visible = true
		_planet_viewer.surface_texture = null
		_planet_viewer.cloud_enabled   = false
		return
	_planet_viewer.visible = true
	if _missing_label:
		_missing_label.visible = false
	_planet_viewer.surface_texture = load(_TEXTURE_BASE + entry.get("surface", "black_surface.png")) as Texture2D
	if entry.has("cloud"):
		_planet_viewer.cloud_texture = load(_TEXTURE_BASE + entry["cloud"]) as Texture2D
		_planet_viewer.cloud_enabled = true
	else:
		_planet_viewer.cloud_texture = null
		_planet_viewer.cloud_enabled = false
