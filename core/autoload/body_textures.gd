## BodyTextures
## Zentrales Lookup für Planeten- und Mond-Texturen.
## Verwendung: BodyTextures.get_entry("europa") → { "surface": "...", "cloud": "..." }

extends Node

const PLANETS_BASE := "res://assets/textures/planets/raw/"
const DWARVES_BASE := "res://assets/textures/dwarves/raw/"
const MOONS_BASE   := "res://assets/textures/moons/raw/"

const _TEXTURES: Dictionary = {
	# Sonne
	"sun":      { "base": "planets", "surface": "2k_sun.jpg" },
	# Planeten
	"mercury":  { "base": "planets", "surface": "2k_mercury.jpg" },
	"venus":    { "base": "planets", "surface": "2k_venus.jpg",  "cloud": "2k_venus_clouds.jpg" },
	"terra":    { "base": "planets", "surface": "2k_earth.jpg",  "cloud": "2k_earth_clouds.jpg" },
	"mars":     { "base": "planets", "surface": "2k_mars.jpg" },
	"jupiter":  { "base": "planets", "surface": "2k_jupiter.jpg" },
	"saturn":   { "base": "planets", "surface": "2k_saturn.jpg" },
	"uranus":   { "base": "planets", "surface": "2k_uranus.jpg" },
	"neptune":  { "base": "planets", "surface": "2k_neptune.jpg" },
	"planet_nine": { "base": "planets", "surface": "2k_planet_9.png" },
	# Zwergplaneten
	"ceres":    { "base": "dwarves", "surface": "2k_ceres.jpg" },
	"pluto":    { "base": "dwarves", "surface": "2k_pluto.png" },
	"haumea":   { "base": "dwarves", "surface": "2k_haumea.jpg" },
	"makemake": { "base": "dwarves", "surface": "2k_makemake.jpg" },
	"eris":     { "base": "dwarves", "surface": "2k_eris.jpg" },
	# Monde
	"moon":     { "base": "moons", "surface": "2k_moon.jpg" },
	"io":       { "base": "moons", "surface": "2k_io.png" },
	"europa":   { "base": "moons", "surface": "2k_europa.png" },
	"ganymede": { "base": "moons", "surface": "2k_ganymede.png" },
	"callisto": { "base": "moons", "surface": "2k_callisto.png" },
	"enceladus": { "base": "moons", "surface": "2k_enceladus.png" },
	"tethys":   { "base": "moons", "surface": "2k_tethys.png" },
	"dione":    { "base": "moons", "surface": "dione_2k.png" },
	"rhea":     { "base": "moons", "surface": "rhea_2k.jpg" },
	"titan":    { "base": "moons", "surface": "titan_2k.jpg" },
	"hyperion": { "base": "moons", "surface": "hyperion_2k.png" },
	"iapetus":  { "base": "moons", "surface": "2k_iapetus.png" },
	"mimas":    { "base": "moons", "surface": "mimas_2k.png" },
	"oberon":   { "base": "moons", "surface": "oberon_2k.jpg" },
	"gonggong": { "base": "moons", "surface": "gonggong_2k.png" },
	"orcus":    { "base": "moons", "surface": "orcus_2k.png" },
	"quaoar":   { "base": "moons", "surface": "quaoar_2k.png" },
	"sedna":    { "base": "moons", "surface": "sedna_2k.png" },
}


func _base_path(entry: Dictionary) -> String:
	match entry.get("base", ""):
		"planets": return PLANETS_BASE
		"dwarves": return DWARVES_BASE
		"moons":   return MOONS_BASE
	return ""


func get_entry(body_id: String) -> Dictionary:
	return _TEXTURES.get(body_id, {})


func has_texture(body_id: String) -> bool:
	var entry := get_entry(body_id)
	if entry.is_empty():
		return false
	var path: String = _base_path(entry) + entry.get("surface", "")
	return ResourceLoader.exists(path)


func get_surface_path(body_id: String) -> String:
	var entry := get_entry(body_id)
	if entry.is_empty():
		return ""
	return _base_path(entry) + entry.get("surface", "")


func get_cloud_path(body_id: String) -> String:
	var entry := get_entry(body_id)
	if not entry.has("cloud"):
		return ""
	return _base_path(entry) + entry["cloud"]


func load_surface(body_id: String) -> Texture2D:
	var path := get_surface_path(body_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func load_cloud(body_id: String) -> Texture2D:
	var path := get_cloud_path(body_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
