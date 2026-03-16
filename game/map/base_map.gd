# base_map.gd
class_name BaseMap
extends Node2D

const BODY_MARKER_SCENE = preload("res://game/map/body_marker/BodyMarker.tscn")

@onready var _body_layer: Node2D = $BodyLayer
@onready var _orbits_layer: Node2D = $OrbitsLayer

# ------------------------------------------------------------------------------------------------------------------
# Skalierungssystem
# ------------------------------------------------------------------------------------------------------------------

# Aktueller Skalierungsexponent. km_per_px = 10 ^ scale_exp
var _scale_exp: float = 5.0
# Daraus abgeleitete Werte, werden bei Änderung von _scale_exp neu berechnet
var _km_per_px: float = 0.0
var _px_per_km: float = 0.0

# ------------------------------------------------------------------------------------------------------------------
# Marker-Größenmatrix (Typ × Zoom-Stufe) — Export-Variablen zum Tweaken im Editor
# ------------------------------------------------------------------------------------------------------------------

## Stufenschwellen: scale_exp-Werte, an denen die Zoom-Stufe wechselt
@export var zoom_stage_threshold_1_2: float = 6.0
@export var zoom_stage_threshold_2_3: float = 8.0

## Marker-Größen in Pixeln: [Stufe 1, Stufe 2, Stufe 3]
@export var marker_size_star: Vector3i = Vector3i(64, 96, 128)
@export var marker_size_planet: Vector3i = Vector3i(16, 24, 32)
@export var marker_size_dwarf: Vector3i = Vector3i(12, 20, 24)
@export var marker_size_moon: Vector3i = Vector3i(10, 16, 20)
@export var marker_size_struct: Vector3i = Vector3i(8, 12, 16)

# ------------------------------------------------------------------------------------------------------------------
# Marker- und Orbit-Verwaltung
# ------------------------------------------------------------------------------------------------------------------

# Lookup: body_id → BodyMarker-Node
var _markers_by_id: Dictionary = {}
# Lookup: body_id → OrbitRenderer-Node
var _orbit_renderers_by_id: Dictionary = {}
# Lookup: group_name → Array[BodyMarker]. Gruppen: type:<type>, subtype:<subtype>, tag:<map_tag>
var _marker_groups: Dictionary = {}

# ------------------------------------------------------------------------------------------------------------------
# Initialisierung
# ------------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	_recalculate_scale()
	_build_markers()
	SolarSystem.simulation_updated.connect(_on_simulation_updated)

# ------------------------------------------------------------------------------------------------------------------
# Frame
# ------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_process_map_input(delta)

# ------------------------------------------------------------------------------------------------------------------
# Skalierung
# ------------------------------------------------------------------------------------------------------------------

## Setzt den Skalierungsexponenten und berechnet die abgeleiteten Werte neu.
func set_scale_exp(value: float) -> void:
	_scale_exp = clamp(value, _get_min_scale_exp(), _get_max_scale_exp())
	_recalculate_scale()
	_on_scale_changed()

## Gibt den aktuellen Skalierungsexponenten zurück.
func get_scale_exp() -> float:
	return _scale_exp

## Gibt den aktuellen px_per_km-Faktor zurück.
func get_px_per_km() -> float:
	return _px_per_km

## Gibt den aktuellen km_per_px-Faktor zurück.
func get_km_per_px() -> float:
	return _km_per_px

## Berechnet _km_per_px und _px_per_km aus dem aktuellen _scale_exp.
func _recalculate_scale() -> void:
	_km_per_px = pow(10.0, _scale_exp)
	_px_per_km = 1.0 / _km_per_px

# ------------------------------------------------------------------------------------------------------------------
# Marker-Größe
# ------------------------------------------------------------------------------------------------------------------

## Gibt die aktuelle Zoom-Stufe (1, 2 oder 3) basierend auf dem aktuellen scale_exp zurück.
func get_current_zoom_stage() -> int:
	if _scale_exp < zoom_stage_threshold_1_2:
		return 1
	elif _scale_exp < zoom_stage_threshold_2_3:
		return 2
	return 3

## Gibt die Marker-Größe in Pixeln für den gegebenen Typ und die aktuelle Zoom-Stufe zurück.
func get_marker_size_for_type(type: String) -> int:
	var stage := get_current_zoom_stage()
	var sizes: Vector3i
	match type:
		"star":   sizes = marker_size_star
		"planet": sizes = marker_size_planet
		"dwarf":  sizes = marker_size_dwarf
		"moon":   sizes = marker_size_moon
		"struct": sizes = marker_size_struct
		_:        return 8
	match stage:
		1: return sizes.x
		2: return sizes.y
		_: return sizes.z

# ------------------------------------------------------------------------------------------------------------------
# Marker-Verwaltung
# ------------------------------------------------------------------------------------------------------------------

## Instanziiert alle Body-Marker und Orbit-Renderer aus dem SolarSystem.
func _build_markers() -> void:
	for body_id in SolarSystem.get_all_body_ids():
		var body: BodyDef = SolarSystem.get_body(body_id)
		_create_marker(body)
		if body.parent_id != "":
			_create_orbit_renderer(body)

## Instanziiert einen einzelnen Body-Marker für den gegebenen BodyDef.
func _create_marker(body: BodyDef) -> void:
	var marker: BodyMarker = BODY_MARKER_SCENE.instantiate()
	_body_layer.add_child(marker)
	marker.setup(body)
	marker.set_marker_size(get_marker_size_for_type(body.type))
	marker.marker_clicked.connect(_on_marker_clicked)
	marker.marker_double_clicked.connect(_on_marker_double_clicked)
	_markers_by_id[body.id] = marker
	_register_marker_in_groups(marker, body)

## Instanziiert einen Orbit-Renderer für den gegebenen Körper (flat unter OrbitsLayer).
func _create_orbit_renderer(child_body: BodyDef) -> void:
	var renderer := OrbitRenderer.new()
	_orbits_layer.add_child(renderer)
	renderer.setup(child_body.id, child_body.color_rgba)
	renderer.update_scale(_px_per_km)
	_orbit_renderers_by_id[child_body.id] = renderer

# ------------------------------------------------------------------------------------------------------------------
# Marker-Gruppen
# ------------------------------------------------------------------------------------------------------------------

## Registriert einen Marker in allen zutreffenden Gruppen (type, subtype, map_tags).
func _register_marker_in_groups(marker: BodyMarker, body: BodyDef) -> void:
	_add_marker_to_group("type:" + body.type, marker)
	_add_marker_to_group("subtype:" + body.subtype, marker)
	for tag in body.map_tags:
		_add_marker_to_group("tag:" + tag, marker)

func _add_marker_to_group(group_name: String, marker: BodyMarker) -> void:
	if not _marker_groups.has(group_name):
		_marker_groups[group_name] = [] as Array[BodyMarker]
	_marker_groups[group_name].append(marker)

## Gibt alle Marker einer bestimmten Gruppe zurück. Leeres Array wenn Gruppe nicht existiert.
func get_markers_in_group(group_name: String) -> Array[BodyMarker]:
	return _marker_groups.get(group_name, [] as Array[BodyMarker])

## Gibt alle registrierten Gruppennamen zurück.
func get_all_group_names() -> Array[String]:
	return _marker_groups.keys()

## Prüft, ob eine Gruppe mit dem gegebenen Namen existiert.
func has_group(group_name: String) -> bool:
	return _marker_groups.has(group_name)

## Aktiviert oder deaktiviert alle Marker einer Gruppe (Sichtbarkeit + Input).
func set_group_active(group_name: String, active: bool) -> void:
	for marker in get_markers_in_group(group_name):
		if active:
			marker.activate()
		else:
			marker.deactivate()

# ------------------------------------------------------------------------------------------------------------------
# Positions-Update
# ------------------------------------------------------------------------------------------------------------------

## Wird auf SolarSystem.simulation_updated aufgerufen. Aktualisiert alle Marker-Positionen.
func _on_simulation_updated() -> void:
	for body_id in _markers_by_id:
		var world_pos := SolarSystem.get_body_position(body_id)
		_markers_by_id[body_id].position = calculate_screen_position(world_pos)
	for body_id in _orbit_renderers_by_id:
		var parent_id := SolarSystem.get_body(body_id).parent_id
		var parent_pos := SolarSystem.get_body_position(parent_id)
		_orbit_renderers_by_id[body_id].position = calculate_screen_position(parent_pos)
	_post_position_update()

## Berechnet die Screen-Position für eine Welt-Position in km. Kann von Subklassen überschrieben werden.
func calculate_screen_position(world_pos_km: Vector2) -> Vector2:
	return world_pos_km * _px_per_km

# ------------------------------------------------------------------------------------------------------------------
# Zoom
# ------------------------------------------------------------------------------------------------------------------

## Ändert den scale_exp um den gegebenen Delta-Wert (positiv = rauszoomen, negativ = reinzoomen).
func zoom(delta: float) -> void:
	set_scale_exp(_scale_exp + delta)

## Wird nach jedem Zoom-Schritt aufgerufen. Aktualisiert Marker-Größen und Orbit-Renderer.
func _on_scale_changed() -> void:
	for body_id in _markers_by_id:
		var body := SolarSystem.get_body(body_id)
		_markers_by_id[body_id].set_marker_size(get_marker_size_for_type(body.type))
	for body_id in _orbit_renderers_by_id:
		if _orbit_renderers_by_id[body_id].visible:
			_orbit_renderers_by_id[body_id].update_scale(_px_per_km)
	_on_simulation_updated()

# ------------------------------------------------------------------------------------------------------------------
# Subklassen-Hooks (müssen von NavMap / LocalMap implementiert werden)
# ------------------------------------------------------------------------------------------------------------------

## Gibt den minimal erlaubten scale_exp für diese Map zurück.
func _get_min_scale_exp() -> float:
	return 0.0

## Gibt den maximal erlaubten scale_exp für diese Map zurück.
func _get_max_scale_exp() -> float:
	return 12.0

## Entscheidet, ob der gegebene Körper bei aktuellem Zustand sichtbar sein soll.
func _is_body_visible(_body: BodyDef) -> bool:
	return true

## Entscheidet, ob der Orbit des gegebenen Körpers bei aktuellem Zustand gezeichnet werden soll.
func _is_orbit_visible(_body: BodyDef) -> bool:
	return true

## Wird pro Frame aufgerufen. Subklasse kann Input verarbeiten und Kamera steuern.
func _process_map_input(_delta: float) -> void:
	pass

## Wird nach jedem Positions-Update aufgerufen. Subklasse überschreibt für Culling.
func _post_position_update() -> void:
	pass

## Wird von BaseMap emittiert wenn ein Marker angeklickt wird. Subklassen überschreiben.
func _on_marker_clicked(_body_id: String) -> void:
	pass

## Wird von BaseMap emittiert wenn ein Marker doppelt angeklickt wird. Subklassen überschreiben.
func _on_marker_double_clicked(_body_id: String) -> void:
	pass
