# res://game/map/map_controller.gd
# Zentraler Koordinator des MapViewer.
# Alle visuellen Parameter der Karte werden hier als Exports konfiguriert
# und beim Setup an die jeweiligen Komponenten weitergegeben.

class_name MapController
extends Node2D

signal marker_double_clicked(body_id: String)
signal marker_hovered(body_id: String)
signal marker_unhovered(body_id: String)
signal body_selected(body_id: String)
signal body_deselected()


# ---------------------------------------------------------------------------
# Exports — Zoom
# ---------------------------------------------------------------------------

@export_group("Zoom")
@export var zoom_exp_min: float     = 3.0    # 10^3  = 1.000 km/px
@export var zoom_exp_max: float     = 10.0   # 10^10 km/px
@export var zoom_exp_step: float    = 0.1    # Exponent-Delta pro Mausrad-Schritt
@export var zoom_exp_initial: float = 6.5  # TODO: BUG - Belt culling doesn't work on first frame. Reduced from 6.7 to hide asteroid belt initially
@export var scale_presets: Array[float] = [3.7, 5.7, 6.5, 7.7, 8.7]  # TODO: BUG - Changed middle preset from 6.7 to 6.5

@export_subgroup("Rubber-Band")
@export var zoom_overshoot: float         = 0.15
@export var zoom_overshoot_damping: float = 0.25
@export var zoom_spring: float            = 12.0
@export var zoom_hold_interval: float     = 0.07

# ---------------------------------------------------------------------------
# Exports — Pan
# ---------------------------------------------------------------------------

@export_group("Pan")
@export var move_speed_px_s: float = 500.0
@export var move_accel: float      = 14.0
@export var move_decel: float      = 18.0

# ---------------------------------------------------------------------------
# Exports — Culling
# ---------------------------------------------------------------------------

@export_group("Culling")
@export var min_parent_dist_px: float = 32.0

# ---------------------------------------------------------------------------
# Exports — Marker-Größen
# ---------------------------------------------------------------------------

@export_group("Marker-Größen")
# x/y = Exponent-Schwelle (km_per_px = 10^x)  →  drei Zonen: exp < x, exp < y, sonst
@export var marker_thresholds: Vector2   = Vector2(5.0, 7.0)
# x=Zone1-px, y=Zone2-px, z=Zone3-px  —  direkte Pixelgröße des Icons
@export var marker_sizes_star:   Vector3i = Vector3i(40, 28, 18)
@export var marker_sizes_planet: Vector3i = Vector3i(28, 20, 14)
@export var marker_sizes_moon:   Vector3i = Vector3i(18, 12, 8)
@export var marker_sizes_struct: Vector3i = Vector3i(14, 10, 6)
@export var marker_label_settings: LabelSettings = null

# ---------------------------------------------------------------------------
# Exports — Retro-Future Color Overrides
# ---------------------------------------------------------------------------

@export_group("Retro-Future Colors")
@export var enable_color_overrides: bool = false
@export var color_preset: MapColorPreset = null

# Component overrides
@export var markers_override: bool = true
@export var orbits_override: bool = true
@export var belts_override: bool = true

# ---------------------------------------------------------------------------
# Exports — Gürtel
# ---------------------------------------------------------------------------

@export_group("Gürtel")
@export var belt_zoom_exp_near: float   = 4.0   # 10^4 = 10.000 km/px
@export var belt_zoom_exp_mid: float    = 6.35  # 10^6.35 ≈ 2.236.000 km/px
@export var belt_zoom_exp_far: float    = 8.7   # 10^8.7 ≈ 500.000.000 km/px
@export var belt_point_size_near: float = 3.0
@export var belt_point_size_mid: float  = 2.0
@export var belt_point_size_far: float  = 1.0

# ---------------------------------------------------------------------------
# Exports — Orbits
# ---------------------------------------------------------------------------

@export_group("Orbits")
@export var orbit_base_width: float      = 1.0
@export var orbit_highlight_width: float = 2.0
@export var orbit_dimmed_width: float    = 0.5
@export var orbit_alpha_default: float   = 0.2
@export var orbit_alpha_highlight: float = 0.6
@export var orbit_alpha_dimmed: float    = 0.08

# ---------------------------------------------------------------------------
# Exports — Grid
# ---------------------------------------------------------------------------

@export_group("Grid")
@export var grid_ring_color: Color    = Color(0.29, 1.0, 0.54, 0.06)
@export var grid_ring_width: float    = 0.5
@export var grid_major_interval: int  = 3
@export var grid_major_color: Color   = Color(0.29, 1.0, 0.54, 0.12)
@export var grid_major_width: float   = 1.5
@export var grid_axis_color: Color    = Color(0.29, 1.0, 0.54, 0.22)
@export var grid_axis_width: float    = 1.5
@export var grid_label_color: Color   = Color(0.29, 1.0, 0.54, 0.35)
@export var grid_show_labels: bool    = true

# ---------------------------------------------------------------------------
# Interne Referenzen
# ---------------------------------------------------------------------------

@onready var _map_clock: MapClock         = $MapClock
@onready var _map_transform: MapTransform = $MapTransform
@onready var _world_root: Node2D          = $WorldRoot
@onready var _grid: GridRenderer          = $WorldRoot/GridLayer
@onready var _orbit_layer: Node2D         = $WorldRoot/OrbitLayer
@onready var _belt_layer: Node2D          = $WorldRoot/BeltLayer
@onready var _zone_layer: Node2D          = $WorldRoot/ZoneLayer

var _model: SolarSystemModel = null
var _markers: Dictionary = {}   # body_id -> MapMarker
var _orbits: Dictionary  = {}   # body_id -> OrbitRenderer
var _belts: Dictionary   = {}   # belt_id -> BeltRenderer
var _zones: Dictionary   = {}   # zone_id -> {renderer: Node2D, def: ZoneDef}

var _follow_body_id: String = ""
var _selected_body_id: String = ""
var _last_selected_parent_id: String = ""  # Parent des zuletzt ausgewählten Bodies
var _marker_scene: PackedScene = null
const _ORBIT_SCRIPT = preload("res://game/scenes/map/renderer/orbit_renderer.gd")
const _BELT_SCRIPT  = preload("res://game/scenes/map/renderer/belt_renderer.gd")
const _ZONE_SCRIPT  = preload("res://game/scenes/map/renderer/zone_renderer.gd")

# Niedrigerer Wert = höhere Priorität (wird nicht von niedrig-prio Körpern verdeckt)
const _TYPE_PRIORITY: Dictionary = {
	"star": 0, "planet": 1, "dwarf": 2, "moon": 3, "struct": 4
}


func setup(model: SolarSystemModel, clock: SimulationClock) -> void:
	_model = model
	_marker_scene = load("res://game/scenes/map/map_marker.tscn")
	get_viewport().physics_object_picking = true

	_apply_config()

	_map_clock.setup(clock)
	_map_clock.map_time_changed.connect(_on_map_time_changed)

	_map_transform.zoom_changed.connect(_on_zoom_changed)
	_map_transform.camera_moved.connect(_on_camera_moved)
	_map_transform.panned.connect(_on_panned)

	_grid.setup(_map_transform)
	_setup_zones()
	_setup_markers()
	_setup_orbits()
	_setup_belts()
	_update_markers()
	_update_orbits()
	_update_belts()
	_update_zones()
	_update_marker_sizes()
	_apply_culling()

	# WorldRoot initial positionieren — deferred, damit get_viewport_rect()
	# den echten Viewport zurückgibt (nicht (0,0) vor dem ersten Frame)
	call_deferred("_on_camera_moved", _map_transform.cam_pos_px)
	# Belt-Positionen müssen ebenfalls aktualisiert werden
	call_deferred("_update_belts")

	print("MapController: Setup — %d markers, %d orbits, %d belts" % [
		_markers.size(), _orbits.size(), _belts.size()
	])


# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

# Überträgt alle Export-Werte auf die Komponenten.
# Wird einmal in setup() gerufen; kann zur Laufzeit erneut aufgerufen werden,
# um geänderte Werte anzuwenden (z.B. nach Inspector-Änderung im Editor).
func _apply_config() -> void:
	# MapTransform
	_map_transform.zoom_exp_min         = zoom_exp_min
	_map_transform.zoom_exp_max         = zoom_exp_max
	_map_transform.zoom_exp_step        = zoom_exp_step
	_map_transform.zoom_overshoot       = zoom_overshoot
	_map_transform.zoom_overshoot_damping = zoom_overshoot_damping
	_map_transform.zoom_spring          = zoom_spring
	_map_transform.zoom_hold_interval   = zoom_hold_interval
	_map_transform.scale_presets        = scale_presets
	_map_transform.zoom_exp             = zoom_exp_initial
	_map_transform.km_per_px            = pow(10.0, zoom_exp_initial)
	_map_transform.move_speed_px_s      = move_speed_px_s
	_map_transform.move_accel           = move_accel
	_map_transform.move_decel           = move_decel

	# Grid
	_grid.ring_color      = grid_ring_color
	_grid.ring_width      = grid_ring_width
	_grid.major_interval  = grid_major_interval
	_grid.major_color     = grid_major_color
	_grid.major_width     = grid_major_width
	_grid.axis_color      = grid_axis_color
	_grid.axis_width      = grid_axis_width
	_grid.label_color     = grid_label_color
	_grid.show_labels     = grid_show_labels

	# Bestehende Belts und Orbits aktualisieren (falls _apply_config nach setup nochmal gerufen)
	for belt: BeltRenderer in _belts.values():
		_apply_belt_config(belt)
	for orbit: OrbitRenderer in _orbits.values():
		_apply_orbit_config(orbit)
	for marker: MapMarker in _markers.values():
		_apply_marker_config(marker)


# Helper function to get color by body type
func _get_color_for_type(body_type: String) -> Color:
	if not enable_color_overrides or color_preset == null:
		return Color.WHITE
	match body_type:
		"star":
			return color_preset.color_star
		"planet":
			return color_preset.color_planet
		"moon":
			return color_preset.color_moon
		"dwarf":
			return color_preset.color_dwarf
		_:
			return color_preset.color_struct


func _apply_belt_config(belt: BeltRenderer) -> void:
	belt.zoom_near       = pow(10.0, belt_zoom_exp_near)
	belt.zoom_mid        = pow(10.0, belt_zoom_exp_mid)
	belt.zoom_far        = pow(10.0, belt_zoom_exp_far)
	belt.point_size_near = belt_point_size_near
	belt.point_size_mid  = belt_point_size_mid
	belt.point_size_far  = belt_point_size_far
	
	belt.enable_color_overrides = enable_color_overrides
	belt.color_override = enable_color_overrides and belts_override
	if color_preset != null:
		belt.color_default = color_preset.belt_color  # Use the preset belt color
		belt.color_core = color_preset.belt_color.lightened(0.3)  # Lighter version for core
	belt.alpha_multiplier = 1.0


func _apply_orbit_config(orbit: OrbitRenderer) -> void:
	orbit.base_width      = orbit_base_width
	orbit.highlight_width = orbit_highlight_width
	orbit.dimmed_width    = orbit_dimmed_width
	orbit.alpha_default   = orbit_alpha_default
	orbit.alpha_highlight = orbit_alpha_highlight
	orbit.alpha_dimmed    = orbit_alpha_dimmed
	
	# Apply retro-future color overrides
	orbit.enable_color_overrides = enable_color_overrides
	orbit.color_override = enable_color_overrides and orbits_override
	# Use the orbiting body's type for orbit color (not the parent)
	if orbit.body_def != null:
		orbit.color_default = _get_color_for_type(orbit.body_def.type)
	if color_preset != null:
		orbit.alpha_offset = color_preset.orbit_alpha_offset
	# Force redraw to apply color
	orbit.queue_redraw()


func _apply_marker_config(marker: MapMarker) -> void:
	# Apply retro-future color overrides
	marker.enable_color_overrides = enable_color_overrides
	marker.color_override = enable_color_overrides and markers_override
	if marker.body_def != null:
		marker.color_default = _get_color_for_type(marker.body_def.type)
		marker.color_highlight = _get_color_for_type(marker.body_def.type)
		marker.color_selected = _get_color_for_type(marker.body_def.type)
	# Force immediate update
	marker.force_color_update()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _setup_markers() -> void:
	for id in _model.get_all_body_ids():
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		var marker: MapMarker = _marker_scene.instantiate()
		_world_root.add_child(marker)
		marker.setup(def, marker_label_settings)
		
		# Apply retro-future color overrides
		marker.enable_color_overrides = enable_color_overrides
		marker.color_override = enable_color_overrides and markers_override
		marker.color_default = _get_color_for_type(def.type)
		marker.color_highlight = _get_color_for_type(def.type)
		marker.color_selected = _get_color_for_type(def.type)
		# Force immediate color update
		marker.force_color_update()
		
		_markers[id] = marker
		marker.clicked.connect(func(m: MapMarker): select_body(m.body_id))
		marker.double_clicked.connect(func(m: MapMarker): marker_double_clicked.emit(m.body_id))
		marker.hovered.connect(func(m: MapMarker):
			marker_hovered.emit(m.body_id)
			_set_orbit_highlight(m.body_id, true)
		)
		marker.unhovered.connect(func(m: MapMarker):
			marker_unhovered.emit(m.body_id)
			_set_orbit_highlight(m.body_id, false)
		)


func _setup_belts() -> void:
	var loader := MapDataLoader.new()
	for def: BeltDef in loader.load_all_belt_defs():
		var belt: BeltRenderer = _BELT_SCRIPT.new()
		_apply_belt_config(belt)
		_belt_layer.add_child(belt)
		belt.setup(def, _map_transform)
		_belts[def.id] = belt


func _setup_zones() -> void:
	var loader := MapDataLoader.new()
	for def: ZoneDef in loader.load_all_zone_defs():
		var zone := _ZONE_SCRIPT.new()
		_zone_layer.add_child(zone)
		zone.setup(def, _map_transform)
		_zones[def.id] = { "renderer": zone, "def": def }


func _setup_orbits() -> void:
	for id in _model.get_all_body_ids():
		var def: BodyDef = _model.get_body(id)
		if def == null or def.motion == null:
			continue
		if def.motion.model not in ["circular", "kepler2d"]:
			continue
		var orbit: OrbitRenderer = _ORBIT_SCRIPT.new()
		_orbit_layer.add_child(orbit)
		orbit.setup(def, _map_transform)
		_orbits[id] = orbit
		# Apply config after setup so body_def is available
		_apply_orbit_config(orbit)


# ---------------------------------------------------------------------------
# Update-Zyklus
# ---------------------------------------------------------------------------

func _on_map_time_changed(_sst_s: float) -> void:
	if _model == null:
		return
	_update_markers()
	_update_orbits()
	_update_belts()
	_update_zones()
	_update_follow()


func _update_markers() -> void:
	for id: String in _markers:
		_markers[id].position = _map_transform.km_to_px(_model.get_body_position(id))


func _update_orbits() -> void:
	for id: String in _orbits:
		var orbit: OrbitRenderer = _orbits[id]
		orbit.position = _map_transform.km_to_px(_model.get_body_position(orbit.parent_id))


func _update_zones() -> void:
	for id: String in _zones:
		var entry: Dictionary = _zones[id]
		var zone: Node2D      = entry["renderer"]
		var def: ZoneDef      = entry["def"]
		zone.position = _map_transform.km_to_px(_model.get_body_position(def.parent_id))


func _update_belts() -> void:
	for id: String in _belts:
		var belt: BeltRenderer = _belts[id]
		belt.position = _map_transform.km_to_px(_model.get_body_position(belt.belt_def.parent_id))
		if not belt.belt_def.apply_rotation and not belt.belt_def.reference_body_id.is_empty():
			var ref_pos: Vector2 = _model.get_body_position(belt.belt_def.reference_body_id)
			belt.rotation = atan2(ref_pos.y, ref_pos.x)


func _on_zoom_changed(km_per_px: float) -> void:
	_grid.notify_zoom_changed()
	_update_marker_sizes()
	_update_markers()
	_update_orbits()
	_update_belts()
	_update_follow()
	_apply_culling()
	for id: String in _orbits:
		_orbits[id].queue_redraw()
	for id: String in _belts:
		_belts[id].notify_zoom_changed(km_per_px)
	_update_zones()
	for id: String in _zones:
		_zones[id]["renderer"].notify_zoom_changed(km_per_px)


func _on_marker_hover(_id: String) -> void:
	var prev_marker: MapMarker = _markers.get(_follow_body_id, null)
	if prev_marker:
		prev_marker.set_state(MapMarker.MarkerState.DEFAULT)
	var prev_orbit: OrbitRenderer = _orbits.get(_follow_body_id, null)
	if prev_orbit:
		prev_orbit.set_state(OrbitRenderer.OrbitState.DEFAULT)


func _deselect_current_follow() -> void:
	if _follow_body_id.is_empty():
		return
	var prev_marker: MapMarker = _markers.get(_follow_body_id, null)
	if prev_marker:
		prev_marker.set_state(MapMarker.MarkerState.DEFAULT)
	var prev_orbit: OrbitRenderer = _orbits.get(_follow_body_id, null)
	if prev_orbit:
		prev_orbit.set_state(OrbitRenderer.OrbitState.DEFAULT)


func _on_panned() -> void:
	_deselect_current_follow()
	_follow_body_id = ""
	# Also deselect the currently selected body
	deselect_body()
	_apply_belt_viewport_culling()
	# Beim Panning alle sichtbaren Belts neuzeichnen, um Kanten zu vermeiden
	for belt in _belts.values():
		if belt.visible:
			belt.queue_redraw()


func _update_follow() -> void:
	if _follow_body_id.is_empty() or _model == null:
		return
	var pos_px: Vector2 = _map_transform.km_to_px(_model.get_body_position(_follow_body_id))
	_map_transform.focus_on(pos_px)


func _on_camera_moved(cam_pos_px: Vector2) -> void:
	_world_root.position = -cam_pos_px + get_viewport_rect().size * 0.5
	_grid.queue_redraw()
	var old_visibility = {}
	# Speichere alte Sichtbarkeit für Vergleich
	for id in _belts:
		old_visibility[id] = _belts[id].visible
	_apply_belt_viewport_culling()
	# Nur Belts neuzeichnen, deren Sichtbarkeit sich geändert hat
	for id in _belts:
		if old_visibility[id] != _belts[id].visible:
			_belts[id].queue_redraw()


# ---------------------------------------------------------------------------
# Culling
# ---------------------------------------------------------------------------

func _apply_culling() -> void:
	_apply_proximity_culling()
	_apply_belt_viewport_culling()


func _apply_proximity_culling() -> void:
	var culled: Dictionary = {}
	for id in _markers:
		culled[id] = false
	
	# Ausgewählten Body immer sichtbar machen
	if not _selected_body_id.is_empty():
		culled[_selected_body_id] = false

	# Pass 1: Strukturen standardmäßig ausblenden, es sei denn, ihr Parent ist ausgewählt
	for id: String in _markers:
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		if def.type == "struct":
			# Struktur nur anzeigen, wenn ihr Parent-Body ausgewählt ist
			# ODER wenn die Struktur selbst ausgewählt ist
			if def.parent_id != _selected_body_id and id != _selected_body_id:
				culled[id] = true
				continue

	# Pass 2: Körper cullen die zu nah an einem Körper höherer Priorität sind.
	for id: String in _markers:
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		# Ausgewählten Body nicht cullen
		if id == _selected_body_id:
			continue
		if culled[id]:
			continue  # Bereits gecullt (z.B. als Structure)
		var my_prio: int = _TYPE_PRIORITY.get(def.type, 99)
		var my_pos: Vector2 = _markers[id].position
		for other_id: String in _markers:
			if other_id == id:
				continue
			var other_def: BodyDef = _model.get_body(other_id)
			if other_def == null:
				continue
			if _TYPE_PRIORITY.get(other_def.type, 99) >= my_prio:
				continue  # Gleiche oder niedrigere Priorität — kein Culling
			if my_pos.distance_to(_markers[other_id].position) < min_parent_dist_px:
				culled[id] = true
				break

	# Pass 3: Hierarchie-Propagation — Kinder gecullter Elternteile ebenfalls cullen.
	var changed := true
	while changed:
		changed = false
		for id: String in _markers:
			if culled[id]:
				continue
			# Ausgewählten Body nicht cullen
			if id == _selected_body_id:
				continue
			var def: BodyDef = _model.get_body(id)
			if def == null:
				continue
			var pid: String = def.parent_id
			if not pid.is_empty() and culled.get(pid, false):
				culled[id] = true
				changed = true

	# Anwenden auf Marker
	for id: String in _markers:
		var m: MapMarker = _markers[id]
		var cull: bool = culled.get(id, false)
		if cull and m.current_state != MapMarker.MarkerState.INACTIVE:
			m.set_state(MapMarker.MarkerState.INACTIVE)
		elif not cull and m.current_state == MapMarker.MarkerState.INACTIVE:
			m.set_state(MapMarker.MarkerState.DEFAULT)
			# Force color update when becoming visible
			if enable_color_overrides:
				m.force_color_update()

	# Anwenden auf Orbits
	for id: String in _orbits:
		var orbit: OrbitRenderer = _orbits[id]
		var cull: bool = culled.get(id, false)
		# Orbit sichtbar lassen wenn der Body oder sein Parent ausgewählt ist
		var body_def: BodyDef = _model.get_body(id)
		if body_def != null and body_def.type == "struct":
			if body_def.parent_id == _selected_body_id or id == _selected_body_id:
				cull = false
		
		if cull and orbit.current_state != OrbitRenderer.OrbitState.INACTIVE:
			orbit.set_state(OrbitRenderer.OrbitState.INACTIVE)
		elif not cull and orbit.current_state == OrbitRenderer.OrbitState.INACTIVE:
			orbit.set_state(OrbitRenderer.OrbitState.DEFAULT)


func _apply_belt_viewport_culling() -> void:
	var vp_size: Vector2  = get_viewport_rect().size
	var cam_pos: Vector2  = _map_transform.cam_pos_px
	# Größerer Bereich für das Culling - 2x Viewport Größe
	var cull_margin: float = vp_size.length() * 1.0  # Ganze Viewport-Diagonale als Puffer
	var km_px: float      = _map_transform.km_per_px

	for id: String in _belts:
		var belt: BeltRenderer = _belts[id]
		var outer_px: float    = belt.belt_def.outer_radius_km / km_px
		# Belt ist sichtbar wenn sein Abstand zur Kamera + sein Radius kleiner als der Culling-Bereich ist
		var dist_to_cam: float = belt.position.distance_to(cam_pos)
		belt.visible = dist_to_cam < (outer_px + cull_margin)


func _update_marker_sizes() -> void:
	if _model == null:
		return
	var cur_exp: float = _map_transform.zoom_exp
	for id: String in _markers:
		_markers[id].set_size_px(_calc_size_px(_model.get_body(id), cur_exp))


func _calc_size_px(def: BodyDef, zoom_exp: float) -> int:
	var sizes: Vector3i
	match def.type:
		"star":   sizes = marker_sizes_star
		"planet": sizes = marker_sizes_planet
		"moon":   sizes = marker_sizes_moon
		_:        sizes = marker_sizes_struct

	if zoom_exp < marker_thresholds.x:
		return sizes.x
	elif zoom_exp < marker_thresholds.y:
		return sizes.y
	else:
		return sizes.z


func _set_orbit_highlight(body_id: String, on: bool) -> void:
	var orbit: OrbitRenderer = _orbits.get(body_id, null)
	if orbit == null:
		return
	# Orbit bleibt highlighted wenn der Body gerade gefolgt wird
	if not on and body_id == _follow_body_id:
		return
	orbit.set_state(
		OrbitRenderer.OrbitState.HIGHLIGHT if on else OrbitRenderer.OrbitState.DEFAULT
	)


# ---------------------------------------------------------------------------
# Cursor
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_marker(body_id: String) -> MapMarker:
	return _markers.get(body_id, null)


func get_markers_by_group(group: String) -> Array[MapMarker]:
	var result: Array[MapMarker] = []
	for id: String in _markers:
		var m: MapMarker = _markers[id]
		if group in m.groups:
			result.append(m)
	return result


func set_marker_state(body_id: String, state: MapMarker.MarkerState) -> void:
	var m: MapMarker = _markers.get(body_id, null)
	if m:
		m.set_state(state)


func set_group_state(group: String, state: MapMarker.MarkerState) -> void:
	for m in get_markers_by_group(group):
		m.set_state(state)


func set_scale_mode(mode: MapTransform.ScaleMode) -> void:
	_map_transform.scale_mode = mode


func set_exaggeration(factor: float) -> void:
	_map_transform.exaggeration_factor = factor


func set_grid_visible(show_layer: bool) -> void:
	$WorldRoot/GridLayer.visible = show_layer


func set_orbits_visible(show_layer: bool) -> void:
	$WorldRoot/OrbitLayer.visible = show_layer


func set_belts_visible(show_layer: bool) -> void:
	$WorldRoot/BeltLayer.visible = show_layer


func set_zones_visible(show_layer: bool) -> void:
	$WorldRoot/ZoneLayer.visible = show_layer


func get_map_transform() -> MapTransform:
	return _map_transform


func get_map_clock() -> MapClock:
	return _map_clock


func focus_body(body_id: String) -> void:
	if _model == null:
		return
	var pos_px: Vector2 = _map_transform.km_to_px(_model.get_body_position(body_id))
	_map_transform.focus_on_smooth(pos_px)


func zoom_to_selected_body_children() -> void:
	if _selected_body_id.is_empty() or _model == null:
		return
	
	# Finde den äußersten Orbit aller Kinder
	var max_orbit_radius: float = 0.0
	var children := get_children_of(_selected_body_id)
	
	# Rekursiv alle Kinder und deren Kinder durchsuchen
	var to_check := children.duplicate()
	while not to_check.is_empty():
		var child_id: String = to_check.pop_front()
		var child_def: BodyDef = _model.get_body(child_id)
		if child_def == null or child_def.motion == null:
			continue
		
		# Orbit-Radius prüfen
		if child_def.motion.model == "circular":
			max_orbit_radius = max(max_orbit_radius, child_def.motion.orbital_radius_km)
		elif child_def.motion.model == "kepler2d":
			max_orbit_radius = max(max_orbit_radius, child_def.motion.a_km)
		
		# Kinder zur Checkliste hinzufügen
		var grandchildren := get_children_of(child_id)
		to_check.append_array(grandchildren)
	
	# Wenn keine Kinder mit Orbits gefunden, auf den Body selbst zoomen
	if max_orbit_radius == 0.0:
		focus_body(_selected_body_id)
		return
	
	# Zoom-Level berechnen, damit der äußerste Orbit passt
	var vp_size := get_viewport_rect().size
	var desired_radius_px: float = min(vp_size.x, vp_size.y) * 0.4  # 40% des Viewports
	var km_per_px: float = max_orbit_radius / desired_radius_px
	
	# Zoom anwenden
	_map_transform.set_km_per_px(km_per_px)
	
	# Und auf den Body zentrieren
	focus_body(_selected_body_id)


# ---------------------------------------------------------------------------
# Selection API
# ---------------------------------------------------------------------------

func select_body(body_id: String) -> void:
	if _selected_body_id == body_id:
		return
	
	# Alte Auswahl aufheben
	if not _selected_body_id.is_empty():
		set_marker_state(_selected_body_id, MapMarker.MarkerState.DEFAULT)
		_set_orbit_highlight(_selected_body_id, false)
	
	# Neue Auswahl setzen
	_selected_body_id = body_id
	# Parent des ausgewählten Bodies tracken
	var body_def: BodyDef = _model.get_body(body_id)
	if body_def != null and not body_def.parent_id.is_empty():
		_last_selected_parent_id = body_def.parent_id
	else:
		_last_selected_parent_id = ""
	
	set_marker_state(_selected_body_id, MapMarker.MarkerState.SELECTED)
	_set_orbit_highlight(_selected_body_id, true)
	
	# Kamera auf den Body fokussieren
	_follow_body_id = body_id
	# Weiche Bewegung zur initiale Position mit entfernungsbasierter Skalierung
	var pos_px: Vector2 = _map_transform.km_to_px(_model.get_body_position(body_id))
	_map_transform.focus_on_smooth_scaled(pos_px)
	
	# Culling aktualisieren, um Strukturen anzuzeigen/auszublenden
	_apply_culling()
	
	body_selected.emit(_selected_body_id)


func set_marker_label_settings(settings: LabelSettings) -> void:
	marker_label_settings = settings
	# Apply to existing markers without color modification
	for marker: MapMarker in _markers.values():
		if marker and marker._label:
			marker._label.label_settings = settings


func deselect_body() -> void:
	if _selected_body_id.is_empty():
		return
	
	set_marker_state(_selected_body_id, MapMarker.MarkerState.DEFAULT)
	var _previous_id = _selected_body_id
	_selected_body_id = ""
	# Parent-Tracker nur zurücksetzen, wenn wir nicht in eine Struktur klicken
	# (wird in select_body gehandhabt)
	
	# Culling aktualisieren, um alle Strukturen auszublenden
	_apply_culling()
	
	body_deselected.emit()


func get_selected_body() -> String:
	return _selected_body_id


# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

func get_body_data(body_id: String) -> BodyDef:
	if _model == null:
		return null
	return _model.get_body(body_id)


func get_children_of(parent_id: String) -> Array[String]:
	if _model == null:
		return []
	var result: Array[String] = []
	for body_id: String in _model.get_all_body_ids():
		var body: BodyDef = _model.get_body(body_id)
		if body != null and body.parent_id == parent_id:
			result.append(body_id)
	return result


func get_bodies_in_group(group: String) -> Array[String]:
	var result: Array[String] = []
	for marker: MapMarker in get_markers_by_group(group):
		result.append(marker.body_id)
	return result
