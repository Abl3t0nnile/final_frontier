# base_map.gd
# Abstrakte Basisklasse für alle Kartenansichten (NavMap, LocalMap).
# Instanziiert und verwaltet Marker, Orbit-Renderer und Skalierung.
# Alle Entscheidungen über Sichtbarkeit, Kamera und Interaktion treffen die Subklassen über Hooks.
#
# Orbit-Vorbereitung:
# Bei Zoom-Übergängen können Orbit-Renderer über mehrere Frames vorberechnet werden,
# statt alle gleichzeitig neu zu zeichnen. BaseMap stellt dafür das Batch-System bereit;
# die Subklasse (NavMap) steuert wann Vorbereitung startet und wann der Tween beginnt.
class_name BaseMap
extends Node2D

const BODY_MARKER_SCENE = preload("res://game/map/body_marker/BodyMarker.tscn")

@onready var _body_layer: Node2D = $BodyLayer
@onready var _orbits_layer: Node2D = $OrbitsLayer

# ==================================================================================================================
# Skalierungssystem
# ==================================================================================================================

# Aktueller Skalierungsexponent. km_per_px = 10 ^ scale_exp
var _scale_exp: float = 5.0
# Daraus abgeleitete Werte — werden bei Änderung von _scale_exp neu berechnet
var _km_per_px: float = 0.0
var _px_per_km: float = 0.0

# ==================================================================================================================
# Marker-Größenmatrix (Typ × Zoom-Stufe) — Export-Variablen zum Tweaken im Editor
# ==================================================================================================================

## Stufenschwellen: scale_exp-Werte, an denen die Zoom-Stufe wechselt
@export var zoom_stage_threshold_1_2: float = 6.0
@export var zoom_stage_threshold_2_3: float = 8.0

## Marker-Größen in Pixeln: [Stufe 1 (nah), Stufe 2 (mittel), Stufe 3 (fern)]
@export var marker_size_star: Vector3i = Vector3i(64, 96, 128)
@export var marker_size_planet: Vector3i = Vector3i(16, 24, 32)
@export var marker_size_dwarf: Vector3i = Vector3i(12, 20, 24)
@export var marker_size_moon: Vector3i = Vector3i(10, 16, 20)
@export var marker_size_struct: Vector3i = Vector3i(8, 12, 16)

# Aktuelle Zoom-Stufe (1, 2 oder 3). Marker-Größen werden nur bei Stufenwechsel aktualisiert.
var _current_zoom_stage: int = -1

# ==================================================================================================================
# Laufzeit-Caches (einmalig beim Build befüllt, danach unveränderlich)
# ==================================================================================================================

# body_id → BodyDef — eliminiert alle SolarSystem.get_body()-Aufrufe zur Laufzeit.
var _body_defs: Dictionary = {}

# child_body_id → parent_id — für den Orbit-Positions-Loop.
var _orbit_parent_ids: Dictionary = {}

# ==================================================================================================================
# Marker- und Orbit-Verwaltung
# ==================================================================================================================

# Lookup: body_id → BodyMarker-Node
var _markers_by_id: Dictionary = {}
# Lookup: body_id → OrbitRenderer-Node
var _orbit_renderers_by_id: Dictionary = {}
# Lookup: group_name → Array[BodyMarker]. Gruppen: type:<type>, subtype:<subtype>, tag:<map_tag>
var _marker_groups: Dictionary = {}

# ==================================================================================================================
# Orbit-Vorbereitung (Batch-System für Zoom-Übergänge)
# ==================================================================================================================

## Anzahl der Orbit-Renderer, die pro Frame vorberechnet werden.
@export var orbit_preparation_batch_size: int = 10

# Wenn true, überspringt _on_scale_changed() und _update_visibility() die sofortige
# Orbit-Skalierung. Die Subklasse ist dafür verantwortlich, die Orbits am Ende
# des Zoom-Übergangs via apply_prepared_orbits() anzuwenden.
var _defer_orbit_updates: bool = false

# Interner Zustand: Vorbereitung (prepare_scale pro Renderer)
var _orbit_prep_active: bool = false
var _orbit_prep_queue: Array[String] = []
var _orbit_prep_target_px_per_km: float = 0.0

# Interner Zustand: Anwendung (apply_prepared pro Renderer)
var _orbit_apply_active: bool = false
var _orbit_apply_queue: Array[String] = []

## Wird emittiert wenn alle Orbit-Renderer fertig vorberechnet sind.
signal orbit_preparation_completed
## Wird emittiert wenn alle vorberechneten Orbits angewandt wurden.
signal orbit_apply_completed

# ==================================================================================================================
# Initialisierung
# ==================================================================================================================

func _ready() -> void:
	_recalculate_scale()
	_current_zoom_stage = _calculate_zoom_stage()
	_build_markers()
	_update_all_positions()
	_update_visibility()
	SolarSystem.simulation_updated.connect(_on_simulation_updated)

# ==================================================================================================================
# Frame
# ==================================================================================================================

func _process(delta: float) -> void:
	if _orbit_prep_active:
		_process_orbit_preparation()
	if _orbit_apply_active:
		_process_orbit_apply()
	_process_map_input(delta)

# ==================================================================================================================
# Skalierung
# ==================================================================================================================

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

# ==================================================================================================================
# Zoom-Stufe & Marker-Größe
# ==================================================================================================================

## Berechnet die Zoom-Stufe (1, 2 oder 3) aus dem aktuellen scale_exp.
func _calculate_zoom_stage() -> int:
	if _scale_exp < zoom_stage_threshold_1_2:
		return 1
	elif _scale_exp < zoom_stage_threshold_2_3:
		return 2
	return 3

## Gibt die aktuelle Zoom-Stufe zurück (gecachter Wert).
func get_current_zoom_stage() -> int:
	return _current_zoom_stage

## Gibt die Marker-Größe in Pixeln für den gegebenen Typ bei aktueller Zoom-Stufe zurück.
func get_marker_size_for_type(type: String) -> int:
	var sizes: Vector3i
	match type:
		"star":   sizes = marker_size_star
		"planet": sizes = marker_size_planet
		"dwarf":  sizes = marker_size_dwarf
		"moon":   sizes = marker_size_moon
		"struct": sizes = marker_size_struct
		_:        return 8
	match _current_zoom_stage:
		1: return sizes.x
		2: return sizes.y
		_: return sizes.z

## Setzt die Marker-Größe für alle Marker basierend auf der aktuellen Zoom-Stufe.
func _apply_marker_sizes() -> void:
	for body_id in _markers_by_id:
		var marker: BodyMarker = _markers_by_id[body_id]
		marker.set_marker_size(get_marker_size_for_type(marker.get_body_type()))

# ==================================================================================================================
# Marker-Aufbau
# ==================================================================================================================

## Instanziiert alle Body-Marker und Orbit-Renderer aus dem SolarSystem.
func _build_markers() -> void:
	for body_id in SolarSystem.get_all_body_ids():
		var body: BodyDef = SolarSystem.get_body(body_id)
		_body_defs[body_id] = body
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
	_orbit_parent_ids[child_body.id] = child_body.parent_id

# ==================================================================================================================
# Marker-Gruppen
# ==================================================================================================================

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

## Gibt alle Marker einer bestimmten Gruppe zurück.
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

# ==================================================================================================================
# Positions-Update (pro Simulation-Tick)
# ==================================================================================================================

## Wird auf SolarSystem.simulation_updated aufgerufen.
func _on_simulation_updated() -> void:
	_update_all_positions()
	_update_visibility()
	_post_update()

## Setzt die Screen-Position aller Marker und Orbit-Renderer.
func _update_all_positions() -> void:
	for body_id in _markers_by_id:
		var world_pos := SolarSystem.get_body_position(body_id)
		_markers_by_id[body_id].position = calculate_screen_position(world_pos)
	for body_id in _orbit_renderers_by_id:
		var parent_id: String = _orbit_parent_ids[body_id]
		var parent_pos := SolarSystem.get_body_position(parent_id)
		_orbit_renderers_by_id[body_id].position = calculate_screen_position(parent_pos)

## Berechnet die Screen-Position für eine Welt-Position in km.
func calculate_screen_position(world_pos_km: Vector2) -> Vector2:
	return world_pos_km * _px_per_km

# ==================================================================================================================
# Sichtbarkeit
# ==================================================================================================================

## Aktualisiert die Sichtbarkeit aller Marker und Orbit-Renderer über die Subklassen-Hooks.
## Bei aufgeschobenen Orbit-Updates wird kein update_scale() bei Sichtbarkeitswechsel aufgerufen.
func _update_visibility() -> void:
	for body_id in _markers_by_id:
		var body: BodyDef = _body_defs[body_id]
		_markers_by_id[body_id].visible = _is_body_visible(body)
	for body_id in _orbit_renderers_by_id:
		var body: BodyDef = _body_defs[body_id]
		var should_show := _is_orbit_visible(body)
		var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
		if should_show and not renderer.visible and not _defer_orbit_updates:
			renderer.update_scale(_px_per_km)
		renderer.visible = should_show

# ==================================================================================================================
# Zoom / Skalenänderung
# ==================================================================================================================

## Ändert den scale_exp um den gegebenen Delta-Wert.
func zoom(delta: float) -> void:
	set_scale_exp(_scale_exp + delta)

## Wird nach jeder Änderung von scale_exp aufgerufen.
## Bei aufgeschobenen Orbit-Updates werden Orbit-Renderer nicht neu gezeichnet —
## die Subklasse skaliert sie stattdessen visuell per Node2D.scale.
func _on_scale_changed() -> void:
	var new_stage := _calculate_zoom_stage()
	if new_stage != _current_zoom_stage:
		_current_zoom_stage = new_stage
		_apply_marker_sizes()

	if not _defer_orbit_updates:
		for body_id in _orbit_renderers_by_id:
			var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
			if renderer.visible:
				renderer.update_scale(_px_per_km)

	_update_all_positions()
	_update_visibility()

# ==================================================================================================================
# Orbit-Vorbereitung (Batch-System)
# ==================================================================================================================

## Startet die Frame-verteilte Vorberechnung aller Orbit-Renderer für einen Ziel-Maßstab.
## Setzt _defer_orbit_updates = true. Bei erneutem Aufruf wird die Queue neu gefüllt.
func begin_orbit_preparation(target_px_per_km: float) -> void:
	_defer_orbit_updates = true
	_orbit_prep_target_px_per_km = target_px_per_km
	_orbit_prep_queue.clear()
	for body_id in _orbit_renderers_by_id:
		_orbit_prep_queue.append(body_id)
	_orbit_prep_active = true

## Verarbeitet einen Batch der Vorbereitungs-Queue pro Frame.
func _process_orbit_preparation() -> void:
	var count := mini(_orbit_prep_queue.size(), orbit_preparation_batch_size)
	for i in count:
		var body_id: String = _orbit_prep_queue[i]
		_orbit_renderers_by_id[body_id].prepare_scale(_orbit_prep_target_px_per_km)
	_orbit_prep_queue = _orbit_prep_queue.slice(count)
	if _orbit_prep_queue.is_empty():
		_orbit_prep_active = false
		orbit_preparation_completed.emit()

## Startet die Frame-verteilte Anwendung der vorberechneten Orbit-Punkte.
## Pro Frame werden orbit_preparation_batch_size Renderer angewandt (je ein queue_redraw).
## Renderer, die noch nicht angewandt wurden, behalten ihr Node2D.scale vom Tween —
## sie sehen also visuell korrekt aus bis sie dran sind.
func apply_prepared_orbits() -> void:
	_orbit_apply_queue.clear()
	for body_id in _orbit_renderers_by_id:
		_orbit_apply_queue.append(body_id)
	_orbit_apply_active = true

## Verarbeitet einen Batch der Apply-Queue pro Frame.
func _process_orbit_apply() -> void:
	var count := mini(_orbit_apply_queue.size(), orbit_preparation_batch_size)
	for i in count:
		var body_id: String = _orbit_apply_queue[i]
		var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
		renderer.scale = Vector2.ONE
		if renderer.has_prepared():
			renderer.apply_prepared()
	_orbit_apply_queue = _orbit_apply_queue.slice(count)
	if _orbit_apply_queue.is_empty():
		_orbit_apply_active = false
		_defer_orbit_updates = false
		orbit_apply_completed.emit()

## Bricht eine laufende Vorbereitung/Anwendung ab und verwirft alle vorbereiteten Daten.
func cancel_orbit_preparation() -> void:
	_orbit_prep_active = false
	_orbit_prep_queue.clear()
	_orbit_apply_active = false
	_orbit_apply_queue.clear()
	for body_id in _orbit_renderers_by_id:
		var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
		renderer.scale = Vector2.ONE
		renderer.discard_prepared()
	_defer_orbit_updates = false

## Gibt zurück, ob aktuell eine Orbit-Vorbereitung oder -Anwendung läuft.
func is_orbit_preparation_active() -> bool:
	return _orbit_prep_active or _orbit_apply_active

# ==================================================================================================================
# Zugriff auf gecachte BodyDefs
# ==================================================================================================================

## Gibt den gecachten BodyDef für die gegebene ID zurück.
func get_body_def(body_id: String) -> BodyDef:
	return _body_defs[body_id]

# ==================================================================================================================
# Subklassen-Hooks
# ==================================================================================================================

func _get_min_scale_exp() -> float:
	return 0.0

func _get_max_scale_exp() -> float:
	return 12.0

func _is_body_visible(_body: BodyDef) -> bool:
	return true

func _is_orbit_visible(_body: BodyDef) -> bool:
	return true

func _process_map_input(_delta: float) -> void:
	pass

func _post_update() -> void:
	pass

func _on_marker_clicked(_body_id: String) -> void:
	pass

func _on_marker_double_clicked(_body_id: String) -> void:
	pass
