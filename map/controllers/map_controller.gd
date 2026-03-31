## MapController
## Base controller: wires up all managers and delegates to them.
## Not a God Object — contains no culling, selection, or follow logic.

class_name MapController
extends Node2D

## Signals (forwarded from InteractionManager)
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)
signal marker_unhovered(id: String)
signal body_pinned(id: String)
signal body_unpinned(id: String)

## Configuration (set via apply_config() from SolarMap)
var zoom_exp_min: float      = 3.0
var zoom_exp_max: float      = 10.0
var zoom_exp_step: float     = 0.1
var zoom_exp_initial: float  = 6.5
var scale_presets: Array[float] = [3.7, 5.7, 6.5, 7.7, 8.7]

var move_speed_px_s: float = 500.0
var move_accel: float      = 14.0
var move_decel: float      = 18.0

var culling_min_parent_dist_px: float  = 32.0

# Feature Flags
var has_orbits: bool = true
var has_grid: bool   = true
var has_belts: bool  = false
var has_zones: bool  = false
var has_rings: bool  = false

# Interaction
var markers_clickable: bool = true
var markers_hoverable: bool = true

# Markers
var marker_zoom_thresholds: Vector2 = Vector2(5.0, 7.0)
var marker_sizes_star:   Vector3i   = Vector3i(40, 28, 18)
var marker_sizes_planet: Vector3i   = Vector3i(28, 20, 14)
var marker_sizes_moon:   Vector3i   = Vector3i(18, 12, 8)
var marker_sizes_struct: Vector3i   = Vector3i(14, 10, 6)
var marker_selection_color: Color   = Color(1.0, 1.0, 1.0, 0.9)
var marker_selection_width: float   = 2.0
var marker_pinned_color: Color      = Color(1.0, 1.0, 1.0, 0.35)
var marker_pinned_width: float      = 1.5
var marker_label_offset: Vector2    = Vector2(4.0, -8.0)

# Orbits
var orbit_width_default: float   = 1.0
var orbit_width_highlight: float = 2.0
var orbit_width_dimmed: float    = 0.5
var orbit_alpha_default: float   = 0.2
var orbit_alpha_highlight: float = 0.6
var orbit_alpha_dimmed: float    = 0.08
var orbit_color_override_enabled: bool = false
var orbit_color_planet: Color    = Color.CYAN
var orbit_color_moon: Color      = Color.GRAY
var orbit_color_dwarf: Color     = Color.ORANGE
var orbit_color_struct: Color    = Color.YELLOW

# Belts
var belt_zoom_near: float       = 10_000.0
var belt_zoom_mid: float        = 2_236_000.0
var belt_zoom_far: float        = 500_000_000.0
var belt_point_size_near: float = 3.0
var belt_point_size_mid: float  = 2.0
var belt_point_size_far: float  = 1.0

## Private
# Note: _world_root is used by SolarMapController._on_camera_moved()
@onready var _world_root: Node2D    = $WorldRoot
@onready var _marker_layer: Node2D  = $WorldRoot/MarkerLayer
@onready var _orbit_layer: Node2D   = $WorldRoot/OrbitLayer
@onready var _grid_layer: Node2D    = $WorldRoot/GridLayer
@onready var _zone_layer: Node2D    = $WorldRoot/ZoneLayer
@onready var _belt_layer: Node2D    = $WorldRoot/BeltLayer
@onready var _ring_layer: Node2D    = $WorldRoot/RingLayer

var _map_transform: MapTransform        = null
var _entity_manager: EntityManager      = null
var _model: SolarSystemModel            = null
var _clock: SimClock                    = null  ## Reference to simulation clock
var _map_clock: MapClock                = null  ## User-controlled map clock
var _game_object_registry: GameObjectRegistry = null  ## Registry for entity metadata
var _culling_manager: CullingManager       = null
var _interaction_manager: InteractionManager = null
var _follow_manager: FollowManager         = null

var _orbits: Dictionary    = {}  # id -> OrbitRenderer
var _grid: Node2D          = null
var _belt_manager: PointCloudManager = null  # Replaces BeltManager
var _zone_manager: ZoneManager = null
var _ring_manager: PointCloudManager = null  # Replaces RingManager
var _orbit_manager: OrbitManager = null  # New orbit manager


func setup(model: SolarSystemModel, clock: SimClock, registry: GameObjectRegistry, _config: MapConfig) -> void:
	_model = model
	_clock = clock
	_game_object_registry = registry

	# Create MapClock for user-controlled time navigation
	_map_clock = MapClock.new()
	_map_clock.name = "MapClock"
	add_child(_map_clock)
	_map_clock.tick.connect(_on_map_time_updated)
	_map_clock.time_changed.connect(_on_map_time_updated)

	# MapTransform
	_map_transform = MapTransform.new()
	_map_transform.name = "MapTransform"
	add_child(_map_transform)
	_map_transform.zoom_exp_min    = zoom_exp_min
	_map_transform.zoom_exp_max    = zoom_exp_max
	_map_transform.zoom_exp_step   = zoom_exp_step
	_map_transform.scale_presets   = scale_presets
	_map_transform.move_speed_px_s = move_speed_px_s
	_map_transform.move_accel      = move_accel
	_map_transform.move_decel      = move_decel
	_map_transform.zoom_exp        = zoom_exp_initial
	_map_transform.km_per_px       = pow(10.0, zoom_exp_initial)

	# EntityManager
	_entity_manager = EntityManager.new()
	_entity_manager.name = "EntityManager"
	add_child(_entity_manager)
	_entity_manager.setup(_model, _map_transform, _marker_layer, _game_object_registry)

	# CullingManager
	_culling_manager = CullingManager.new()
	_culling_manager.name = "CullingManager"
	add_child(_culling_manager)
	_culling_manager.min_parent_dist_px  = culling_min_parent_dist_px
	_culling_manager.marker_thresholds   = marker_zoom_thresholds
	_culling_manager.marker_sizes_star   = marker_sizes_star
	_culling_manager.marker_sizes_planet = marker_sizes_planet
	_culling_manager.marker_sizes_moon   = marker_sizes_moon
	_culling_manager.marker_sizes_struct = marker_sizes_struct
	_culling_manager.setup(_entity_manager, _model, _map_transform, _game_object_registry)

	# InteractionManager
	_interaction_manager = InteractionManager.new()
	_interaction_manager.name = "InteractionManager"
	add_child(_interaction_manager)
	_interaction_manager.setup(_entity_manager, _culling_manager)

	# FollowManager
	_follow_manager = FollowManager.new()
	_follow_manager.name = "FollowManager"
	add_child(_follow_manager)
	_follow_manager.setup(_map_transform, _model)

	# Create markers and wire signals from registry
	for game_object in _game_object_registry.get_all_objects():
		if not game_object:
			continue
		var id: String = game_object.id
		var marker := _entity_manager.create_marker(game_object)
		_apply_marker_config(marker)
		marker.clicked.connect(func(_m: MapMarker): _interaction_manager.select_entity(id))
		marker.hovered.connect(func(_m: MapMarker): _interaction_manager.on_marker_hovered(id))
		marker.unhovered.connect(func(_m: MapMarker): _interaction_manager.on_marker_unhovered(id))

	# Forward InteractionManager signals (follow connection in subtypes)
	_interaction_manager.body_selected.connect(body_selected.emit)
	_interaction_manager.body_deselected.connect(body_deselected.emit)
	_interaction_manager.marker_hovered.connect(marker_hovered.emit)
	_interaction_manager.marker_unhovered.connect(marker_unhovered.emit)
	_interaction_manager.body_pinned.connect(body_pinned.emit)
	_interaction_manager.body_unpinned.connect(body_unpinned.emit)

	# MapTransform signals
	_map_transform.panned.connect(_on_panned)
	_map_transform.camera_moved.connect(_on_camera_moved)
	_map_transform.zoom_changed.connect(_on_zoom_changed)

	# Viewport Physics Picking
	get_viewport().physics_object_picking = true

	# Feature-based setup
	if has_grid:
		_setup_grid()
	if has_orbits:
		_setup_orbits()
		_culling_manager.set_orbits(_orbit_manager)
		_interaction_manager.marker_hovered.connect(_on_marker_hovered_orbit)
		_interaction_manager.marker_unhovered.connect(_on_marker_unhovered_orbit)
	if has_belts:
		_setup_belts()
		_culling_manager.set_belt_manager(_belt_manager)
	if has_zones:
		_setup_zones()
		_culling_manager.set_zone_manager(_zone_manager)
	if has_rings:
		_setup_rings()
		_culling_manager.set_ring_manager(_ring_manager)

	# Initialer State
	_entity_manager.update_all_positions()
	_culling_manager.update_marker_sizes(_map_transform.zoom_exp)
	_culling_manager.apply_culling("", [])
	if has_orbits:
		_update_orbits()
	if has_belts:
		_belt_manager.update_positions()
	if has_zones:
		_zone_manager.update_zones()
	if has_rings:
		_ring_manager.update_positions()
	call_deferred("_on_camera_moved", _map_transform.cam_pos_px)


## Public API

func _apply_marker_config(marker: MapMarker) -> void:
	marker.selection_color = marker_selection_color
	marker.selection_width = marker_selection_width
	marker.pinned_color    = marker_pinned_color
	marker.pinned_width    = marker_pinned_width
	marker.label_offset    = marker_label_offset




func apply_config(config: Dictionary) -> void:
	# Zoom
	if config.has("zoom_exp_min"):      zoom_exp_min = config.zoom_exp_min
	if config.has("zoom_exp_max"):      zoom_exp_max = config.zoom_exp_max
	if config.has("zoom_exp_step"):     zoom_exp_step = config.zoom_exp_step
	if config.has("zoom_exp_initial"):  zoom_exp_initial = config.zoom_exp_initial
	if config.has("scale_presets"):     scale_presets = config.scale_presets
	# Pan
	if config.has("move_speed_px_s"):   move_speed_px_s = config.move_speed_px_s
	if config.has("move_accel"):        move_accel = config.move_accel
	if config.has("move_decel"):        move_decel = config.move_decel
	# Culling
	if config.has("culling_min_parent_dist_px"): culling_min_parent_dist_px = config.culling_min_parent_dist_px
	# Markers
	if config.has("marker_zoom_thresholds"): marker_zoom_thresholds = config.marker_zoom_thresholds
	if config.has("marker_sizes_star"):   marker_sizes_star = config.marker_sizes_star
	if config.has("marker_sizes_planet"): marker_sizes_planet = config.marker_sizes_planet
	if config.has("marker_sizes_moon"):   marker_sizes_moon = config.marker_sizes_moon
	if config.has("marker_sizes_struct"): marker_sizes_struct = config.marker_sizes_struct
	if config.has("marker_selection_color"): marker_selection_color = config.marker_selection_color
	if config.has("marker_selection_width"): marker_selection_width = config.marker_selection_width
	if config.has("marker_pinned_color"):    marker_pinned_color = config.marker_pinned_color
	if config.has("marker_pinned_width"):    marker_pinned_width = config.marker_pinned_width
	if config.has("marker_label_offset"):    marker_label_offset = config.marker_label_offset
	# Orbits
	if config.has("orbit_width_default"):   orbit_width_default = config.orbit_width_default
	if config.has("orbit_width_highlight"): orbit_width_highlight = config.orbit_width_highlight
	if config.has("orbit_width_dimmed"):    orbit_width_dimmed = config.orbit_width_dimmed
	if config.has("orbit_alpha_default"):   orbit_alpha_default = config.orbit_alpha_default
	if config.has("orbit_alpha_highlight"): orbit_alpha_highlight = config.orbit_alpha_highlight
	if config.has("orbit_alpha_dimmed"):    orbit_alpha_dimmed = config.orbit_alpha_dimmed
	if config.has("orbit_color_override_enabled"): orbit_color_override_enabled = config.orbit_color_override_enabled
	if config.has("orbit_color_planet"): orbit_color_planet = config.orbit_color_planet
	if config.has("orbit_color_moon"):   orbit_color_moon = config.orbit_color_moon
	if config.has("orbit_color_dwarf"):  orbit_color_dwarf = config.orbit_color_dwarf
	if config.has("orbit_color_struct"): orbit_color_struct = config.orbit_color_struct
	# Belts
	if config.has("belt_zoom_near"):       belt_zoom_near = config.belt_zoom_near
	if config.has("belt_zoom_mid"):        belt_zoom_mid = config.belt_zoom_mid
	if config.has("belt_zoom_far"):        belt_zoom_far = config.belt_zoom_far
	if config.has("belt_point_size_near"): belt_point_size_near = config.belt_point_size_near
	if config.has("belt_point_size_mid"):  belt_point_size_mid = config.belt_point_size_mid
	if config.has("belt_point_size_far"):  belt_point_size_far = config.belt_point_size_far
	# Feature Flags
	if config.has("has_orbits"): has_orbits = config.has_orbits
	if config.has("has_grid"):   has_grid = config.has_grid
	if config.has("has_belts"):  has_belts = config.has_belts
	if config.has("has_zones"):  has_zones = config.has_zones
	if config.has("has_rings"):  has_rings = config.has_rings
	# Interaction
	if config.has("markers_clickable"): markers_clickable = config.markers_clickable
	if config.has("markers_hoverable"): markers_hoverable = config.markers_hoverable


func select_body(id: String) -> void:
	_interaction_manager.select_entity(id)


func deselect_body() -> void:
	_interaction_manager.deselect_current()


func focus_body(id: String) -> void:
	if _model == null:
		return
	var pos_px := _map_transform.km_to_px(_model.get_body_position(id))
	_map_transform.focus_on_smooth(pos_px)


func get_selected_body() -> String:
	return _interaction_manager.get_selected_entity() if _interaction_manager != null else ""


func get_map_transform() -> MapTransform: return _map_transform


func get_entity_manager() -> EntityManager: return _entity_manager


func get_culling_manager() -> CullingManager: return _culling_manager


func get_interaction_manager() -> InteractionManager: return _interaction_manager


func get_follow_manager() -> FollowManager: return _follow_manager


## Time control API

func get_map_clock() -> MapClock:
	"""Get the MapClock instance for direct control"""
	return _map_clock


## Signal handlers (subclasses override for specific behavior)

func _on_map_time_updated(time: float) -> void:
	"""Update map elements when time changes"""
	if _model == null:
		return
	_model.update_to_time(time)
	_entity_manager.update_all_positions()
	_update_features()


func _on_camera_moved(_cam_pos: Vector2) -> void: pass


func _on_zoom_changed(km_per_px: float) -> void:
	_update_features_zoom(km_per_px)


func _on_panned() -> void: pass


## Feature-Updates (von Signal-Handlern aufgerufen)

func _update_features() -> void:
	if has_orbits:
		_update_orbits()
	if has_belts and _belt_manager:
		_belt_manager.update_positions()
	if has_zones and _zone_manager:
		_zone_manager.update_zones()
	if has_rings and _ring_manager:
		_ring_manager.update_positions()


func _update_features_zoom(km_per_px: float) -> void:
	# Culling aktualisieren (inkl. Belts, Rings, Zones)
	_culling_manager.update_marker_sizes(_map_transform.zoom_exp)
	_culling_manager.apply_culling(
		_interaction_manager.get_selected_entity(),
		_interaction_manager.get_pinned_entities()
	)
	
	if has_orbits:
		_update_orbits()
		if _orbit_manager:
			_orbit_manager.update_zoom(km_per_px)
	if has_belts and _belt_manager:
		_belt_manager.update_positions()
		_belt_manager.update_zoom(km_per_px)
	if has_zones and _zone_manager:
		_zone_manager.update_zones()
		_zone_manager.update_zoom(km_per_px)
	if has_rings and _ring_manager:
		_ring_manager.update_positions()
		_ring_manager.update_zoom(km_per_px)
	if has_grid and _grid != null:
		_grid.notify_zoom_changed()


## Feature Setup

func _setup_grid() -> void:
	_grid = GridRenderer.new()
	_grid.name = "GridRenderer"
	_grid_layer.add_child(_grid)
	_grid.setup(_map_transform)


func _setup_orbits() -> void:
	_orbit_manager = OrbitManager.new()
	_orbit_manager.name = "OrbitManager"
	# Apply configuration before setup
	_orbit_manager.base_width = orbit_width_default
	_orbit_manager.highlight_width = orbit_width_highlight
	_orbit_manager.dimmed_width = orbit_width_dimmed
	_orbit_manager.alpha_default = orbit_alpha_default
	_orbit_manager.alpha_highlight = orbit_alpha_highlight
	_orbit_manager.alpha_dimmed = orbit_alpha_dimmed
	_orbit_manager.color_override_enabled = orbit_color_override_enabled
	_orbit_manager.color_planet = orbit_color_planet
	_orbit_manager.color_moon = orbit_color_moon
	_orbit_manager.color_dwarf = orbit_color_dwarf
	_orbit_manager.color_struct = orbit_color_struct
	add_child(_orbit_manager)
	_orbit_manager.setup(_orbit_layer, _map_transform, _model, _game_object_registry)
	_orbits = _orbit_manager.get_orbits()


func _setup_belts() -> void:
	_belt_manager = PointCloudManager.new()
	_belt_manager.name = "BeltManager"
	# Config before setup()
	_belt_manager.zoom_near       = belt_zoom_near
	_belt_manager.zoom_mid        = belt_zoom_mid
	_belt_manager.zoom_far        = belt_zoom_far
	_belt_manager.point_size_near = belt_point_size_near
	_belt_manager.point_size_mid  = belt_point_size_mid
	_belt_manager.point_size_far  = belt_point_size_far
	add_child(_belt_manager)
	_belt_manager.setup(_belt_layer, _map_transform, _model, "res://data/belt_data.json", "belts")


func _setup_zones() -> void:
	_zone_manager = ZoneManager.new()
	_zone_manager.name = "ZoneManager"
	add_child(_zone_manager)
	_zone_manager.setup(_zone_layer, _map_transform, _model)


func _setup_rings() -> void:
	_ring_manager = PointCloudManager.new()
	_ring_manager.name = "RingManager"
	add_child(_ring_manager)
	_ring_manager.setup(_ring_layer, _map_transform, _model, "res://data/ring_data.json", "rings")


func _update_orbits() -> void:
	if _orbit_manager:
		_orbit_manager.update_orbits()


func _on_marker_hovered_orbit(id: String) -> void:
	if _orbit_manager:
		_orbit_manager.set_highlight(id, true)


func _on_marker_unhovered_orbit(id: String) -> void:
	if _orbit_manager:
		_orbit_manager.set_highlight(id, false)


## Getters for Managers

func get_belt_manager() -> PointCloudManager:
	return _belt_manager


func get_zone_manager() -> ZoneManager:
	return _zone_manager


func get_ring_manager() -> PointCloudManager:
	return _ring_manager


func get_orbit_manager() -> OrbitManager:
	return _orbit_manager
