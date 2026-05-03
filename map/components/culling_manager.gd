## CullingManager
## Manages visibility and size of MapMarkers based on zoom and proximity.

class_name CullingManager
extends Node

## Priorities for proximity culling (lower number = higher priority)
const TYPE_PRIORITY := {
	"star":   0,
	"planet": 1,
	"dwarf":  2,
	"moon":   3,
	"struct": 4,
	"comet":  5,
}

var min_parent_dist_px: float = 32.0
var marker_thresholds: Vector2    = Vector2(5.0, 7.0)
var marker_sizes_star:   Vector3i = Vector3i(40, 28, 18)
var marker_sizes_planet: Vector3i = Vector3i(28, 20, 14)
var marker_sizes_moon:   Vector3i = Vector3i(18, 12, 8)
var marker_sizes_struct: Vector3i = Vector3i(14, 10, 6)
var marker_sizes_comet:  Vector3i = Vector3i(14, 10, 6)

var _entity_manager: EntityManager   = null
var _model: SolarSystemModel         = null
var _map_transform: MapTransform     = null
var _game_object_registry: GameObjectRegistry = null
var _orbit_manager: OrbitManager     = null
var _belt_manager: PointCloudManager = null  # Updated from BeltManager
var _ring_manager: PointCloudManager = null  # Updated from RingManager
var _zone_manager: ZoneManager       = null

# Sichtbarkeitsfilter (key vorhanden = ausgeblendet)
var _hidden_types:    Dictionary = {}
var _hidden_subtypes: Dictionary = {}


func setup(entity_manager: EntityManager, model: SolarSystemModel, map_transform: MapTransform, registry: GameObjectRegistry = null) -> void:
	_entity_manager = entity_manager
	_model          = model
	_map_transform  = map_transform
	_game_object_registry = registry


func set_orbits(orbit_manager: OrbitManager) -> void:
	_orbit_manager = orbit_manager


func set_belt_manager(belt_manager: PointCloudManager) -> void:
	_belt_manager = belt_manager


func set_ring_manager(ring_manager: PointCloudManager) -> void:
	_ring_manager = ring_manager


func set_zone_manager(zone_manager: ZoneManager) -> void:
	_zone_manager = zone_manager


func set_type_visible(type: String, visible: bool) -> void:
	if visible:
		_hidden_types.erase(type)
	else:
		_hidden_types[type] = false


func set_subtype_visible(subtype: String, visible: bool) -> void:
	if visible:
		_hidden_subtypes.erase(subtype)
	else:
		_hidden_subtypes[subtype] = false


func apply_culling(selected_id: String, pinned_ids: Array[String]) -> void:
	var markers := _entity_manager.get_markers()

	# Pass 1: Zustände initialisieren
	for id in markers:
		var marker := markers[id] as MapMarker
		if id in pinned_ids:
			marker.set_state(MapMarker.MarkerState.PINNED)
		elif id == selected_id:
			marker.set_state(MapMarker.MarkerState.SELECTED)
		else:
			marker.set_state(MapMarker.MarkerState.DEFAULT)

	# Pass 2: Structs ausblenden, außer wenn ihr Parent selected ist
	for id in markers:
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		if def.type == "struct" and id not in pinned_ids and id != selected_id:
			if selected_id == "" or def.parent_id != selected_id:
				markers[id].set_state(MapMarker.MarkerState.INACTIVE)

	# Pass 3: Pairwise Proximity-Culling aller sichtbaren Marker
	# (behandelt Geschwister wie Venus/Erde; fokussierter Marker gewinnt immer,
	#  d.h. der Parent wird ausgeblendet wenn das fokussierte Kind zu nah kommt)
	var visible_ids: Array[String] = []
	for id in markers:
		if markers[id].current_state != MapMarker.MarkerState.INACTIVE:
			visible_ids.append(id)

	for i in range(visible_ids.size()):
		var id_a := visible_ids[i]
		var marker_a := markers[id_a] as MapMarker
		if marker_a.current_state == MapMarker.MarkerState.INACTIVE:
			continue
		var focused_a: bool = (id_a in pinned_ids or id_a == selected_id)

		for j in range(i + 1, visible_ids.size()):
			var id_b := visible_ids[j]
			var marker_b := markers[id_b] as MapMarker
			if marker_b.current_state == MapMarker.MarkerState.INACTIVE:
				continue

			var dist: float = (marker_a.global_position - marker_b.global_position).length()
			if dist >= min_parent_dist_px:
				continue

			var focused_b: bool = (id_b in pinned_ids or id_b == selected_id)

			# Beide fokussiert → keiner wird ausgeblendet
			if focused_a and focused_b:
				continue

			# Fokussierter Marker gewinnt immer
			if focused_a:
				marker_b.set_state(MapMarker.MarkerState.INACTIVE)
				continue
			if focused_b:
				marker_a.set_state(MapMarker.MarkerState.INACTIVE)
				continue

			# Sonst: höhere Priorität (niedrigere Zahl) gewinnt
			var def_a: BodyDef = _model.get_body(id_a)
			var def_b: BodyDef = _model.get_body(id_b)
			var prio_a: int = int(TYPE_PRIORITY.get(def_a.type if def_a != null else "struct", 4))
			var prio_b: int = int(TYPE_PRIORITY.get(def_b.type if def_b != null else "struct", 4))

			if prio_a < prio_b:
				marker_b.set_state(MapMarker.MarkerState.INACTIVE)
			elif prio_b < prio_a:
				marker_a.set_state(MapMarker.MarkerState.INACTIVE)
			else:
				# Gleiche Priorität: stabiler Tiebreak per id (lexikographisch)
				if id_a < id_b:
					marker_b.set_state(MapMarker.MarkerState.INACTIVE)
				else:
					marker_a.set_state(MapMarker.MarkerState.INACTIVE)

	# Pass 4: Sichtbarkeitsfilter — gefilterte Typen/Subtypen ausblenden
	if not _hidden_types.is_empty() or not _hidden_subtypes.is_empty():
		for id in markers:
			if markers[id].current_state == MapMarker.MarkerState.INACTIVE:
				continue
			var def: BodyDef = _model.get_body(id)
			if def == null:
				continue
			if _hidden_types.has(def.type) or _hidden_subtypes.has(def.subtype):
				markers[id].set_state(MapMarker.MarkerState.INACTIVE)

	# Orbits synchronisieren
	if _orbit_manager:
		var orbits = _orbit_manager.get_orbits()
		for id in orbits:
			var marker := _entity_manager.get_marker(id)
			if marker != null:
				_orbit_manager.set_visibility(id, marker.current_state != MapMarker.MarkerState.INACTIVE)

	# Belts, Rings und Zones synchronisieren
	_apply_belt_culling()
	_apply_ring_culling()
	_apply_zone_culling()


func update_marker_sizes(zoom_exp: float) -> void:
	var markers := _entity_manager.get_markers()
	for id in markers:
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		var size := _calc_size_px(def, zoom_exp)
		markers[id].set_size_px(size)


func _apply_belt_culling() -> void:
	if _belt_manager == null:
		return
	_apply_renderer_culling(_belt_manager.get_renderers(), _belt_manager.get_defs())


func _apply_ring_culling() -> void:
	if _ring_manager == null:
		return
	_apply_renderer_culling(_ring_manager.get_renderers(), _ring_manager.get_defs())


func _apply_renderer_culling(renderers: Array, defs: Array) -> void:
	var km_per_px: float = _map_transform.km_per_px
	
	for i in renderers.size():
		var renderer: BeltRenderer = renderers[i]
		var def: BeltDef = defs[i]
		
		# Proximity-Culling: Belt/Ring ausblenden wenn Parent-Marker zu nah an anderen ist
		if def.parent_id != "":
			var marker := _entity_manager.get_marker(def.parent_id)
			if marker != null:
				# Wenn Parent-Marker durch Proximity-Culling ausgeblendet wurde
				if marker.current_state == MapMarker.MarkerState.INACTIVE:
					renderer.visible = false
					continue
				
				# Pixel-Radius des Belts/Rings prüfen — nur ausblenden wenn zu klein
				var outer_radius_px: float = def.outer_radius_km / km_per_px
				if outer_radius_px < min_parent_dist_px:
					renderer.visible = false
					continue
		
		renderer.visible = true


func _apply_zone_culling() -> void:
	if _zone_manager == null:
		return
	var km_per_px: float = _map_transform.km_per_px
	var renderers := _zone_manager.get_renderers()
	var zone_defs := _zone_manager.get_zone_defs()
	
	for i in renderers.size():
		var renderer: ZoneRenderer = renderers[i]
		var def: ZoneDef = zone_defs[i]
		
		# Parent-Culling: ausblenden wenn Parent nicht sichtbar
		if def.parent_id != "":
			var marker := _entity_manager.get_marker(def.parent_id)
			if marker != null and marker.current_state == MapMarker.MarkerState.INACTIVE:
				renderer.visible = false
				continue
		
		# Pixel-Größen-Culling: zu klein (< 0.5px)
		var r_outer: float
		match def.geometry:
			"ring":
				r_outer = def.outer_radius_km / km_per_px
			_:
				r_outer = def.radius_km / km_per_px
		
		if r_outer < 0.5:
			renderer.visible = false
			continue
		
		renderer.visible = true


func _calc_size_px(def: BodyDef, zoom_exp_val: float) -> int:
	var sizes: Vector3i
	match def.type:
		"star":   sizes = marker_sizes_star
		"planet": sizes = marker_sizes_planet
		"moon":   sizes = marker_sizes_moon
		"struct": sizes = marker_sizes_struct
		"comet":  sizes = marker_sizes_comet
		_:        sizes = marker_sizes_moon

	if zoom_exp_val <= marker_thresholds.x:
		return sizes.x
	elif zoom_exp_val >= marker_thresholds.y:
		return sizes.z
	else:
		var t := (zoom_exp_val - marker_thresholds.x) / (marker_thresholds.y - marker_thresholds.x)
		return int(lerpf(float(sizes.x), float(sizes.z), t))
