# map_test_scene.gd — Testszene für das Map Toolkit.
# Demonstriert alle Komponenten: BodyMarker, OrbitRenderer, BeltRenderer,
# ZoneRenderer, ConcentricGridRenderer, SquareGridRenderer, MapScale,
# MapFilterState, MapViewController, MapCameraController, MapDataLoader.
extends Node2D

# ─── Service refs (injected by main) ──────────────────────────────────────────
@export var sim_clock:    SimulationClock  = null
@export var solar_system: SolarSystemModel = null

# ─── Scene refs ───────────────────────────────────────────────────────────────
@onready var _grid_layer:  Node2D = $GridLayer
@onready var _belt_layer:  Node2D = $BeltLayer
@onready var _zone_layer:  Node2D = $ZoneLayer
@onready var _orbit_layer: Node2D = $OrbitLayer
@onready var _body_layer:  Node2D = $BodyLayer
@onready var _hud_label:   Label  = $HUD/HudLabel

# ─── Preloaded renderer scenes ────────────────────────────────────────────────
const BODY_MARKER_SCENE  := preload("res://game/map/toolkit/renderer/BodyMarker.tscn")
const ORBIT_SCENE        := preload("res://game/map/toolkit/renderer/OrbitRenderer.tscn")
const BELT_SCENE         := preload("res://game/map/toolkit/renderer/BeltRenderer.tscn")
const ZONE_SCENE         := preload("res://game/map/toolkit/renderer/ZoneRenderer.tscn")
const CONCENTRIC_SCENE   := preload("res://game/map/toolkit/renderer/ConcentricGridRenderer.tscn")
const SQUARE_GRID_SCENE  := preload("res://game/map/toolkit/renderer/SquareGridRenderer.tscn")

# ─── Toolkit objects ──────────────────────────────────────────────────────────
var _map_scale:       MapScale             = MapScale.new()
var _filter:          MapFilterState       = null
var _view_controller: MapViewController    = null
var _cam_controller:  MapCameraController  = null

# ─── Live renderer maps ───────────────────────────────────────────────────────
var _markers:        Dictionary = {}  # body_id  → BodyMarker
var _orbits:         Dictionary = {}  # body_id  → OrbitRenderer
var _belt_renderers: Dictionary = {}  # belt_id  → BeltRenderer
var _belt_defs:      Dictionary = {}  # belt_id  → BeltDef
var _zone_renderers: Dictionary = {}  # zone_id  → ZoneRenderer
var _zone_defs:      Dictionary = {}  # zone_id  → ZoneDef

var _concentric_grid: ConcentricGridRenderer = null
var _square_grid:     SquareGridRenderer     = null

const SIM_CLOCK_SCRIPT    := preload("res://core/sim_clock.gd")
const SOLAR_SYSTEM_SCRIPT := preload("res://core/solar_system_sim.gd")

const BODIES_DATA_PATH:  String = "res://data/solar_system_data.json"
const STRUCTS_DATA_PATH: String = "res://data/struct_data.json"

var _selected_body_text: String = ""


# ─── Init ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if sim_clock == null:
		sim_clock = SIM_CLOCK_SCRIPT.new()
		sim_clock.name = "SimClock"
		add_child(sim_clock)
		sim_clock.setup(0.0)
	if solar_system == null:
		solar_system = SOLAR_SYSTEM_SCRIPT.new()
		solar_system.name = "SolarSystem"
		add_child(solar_system)
		solar_system.setup(sim_clock, BODIES_DATA_PATH, STRUCTS_DATA_PATH)
	start()


func start() -> void:
	if sim_clock == null or solar_system == null:
		push_error("MapTestScene: sim_clock und solar_system müssen vor start() gesetzt sein!")
		return
	_setup_toolkit()
	_setup_grids()
	_load_belts_and_zones()
	_spawn_bodies()
	_refresh_positions()
	solar_system.simulation_updated.connect(_on_simulation_updated)
	sim_clock.start()


func _setup_toolkit() -> void:
	_filter = MapFilterState.new()
	_filter.name = "MapFilterState"
	add_child(_filter)

	_view_controller = MapViewController.new()
	_view_controller.name = "MapViewController"
	add_child(_view_controller)
	_view_controller.setup(_map_scale, _filter)

	_cam_controller = MapCameraController.new()
	_cam_controller.name = "MapCameraController"
	add_child(_cam_controller)
	_cam_controller.setup(_map_scale, {
		"scale_exp_start": 7.5,
		"scale_exp_min":   4.0,
		"scale_exp_max":   10.0,
		"zoom_step":       0.2,
	})
	_cam_controller.camera_moved.connect(_refresh_positions)


# ─── Grids ────────────────────────────────────────────────────────────────────

func _setup_grids() -> void:
	_concentric_grid = CONCENTRIC_SCENE.instantiate()
	_concentric_grid.setup(500_000_000.0, 20)
	_concentric_grid.set_px_per_km(_map_scale.get_px_per_km())
	_grid_layer.add_child(_concentric_grid)

	_square_grid = SQUARE_GRID_SCENE.instantiate()
	_square_grid.setup(200_000_000.0)
	_square_grid.set_px_per_km(_map_scale.get_px_per_km())
	_grid_layer.add_child(_square_grid)


# ─── Belts & Zones ────────────────────────────────────────────────────────────

func _load_belts_and_zones() -> void:
	var loader := MapDataLoader.new()

	for belt: BeltDef in loader.load_all_belt_defs():
		var r: BeltRenderer = BELT_SCENE.instantiate()
		r.setup(belt)
		r.set_px_per_km(_map_scale.get_px_per_km())
		r.set_density(_view_controller.get_belt_density(belt))
		_belt_layer.add_child(r)
		_belt_renderers[belt.id] = r
		_belt_defs[belt.id]      = belt

	for zone: ZoneDef in loader.load_all_zone_defs():
		var r: ZoneRenderer = ZONE_SCENE.instantiate()
		r.setup(zone)
		r.set_px_per_km(_map_scale.get_px_per_km())
		_zone_layer.add_child(r)
		_zone_renderers[zone.id] = r
		_zone_defs[zone.id]      = zone


# ─── Bodies ───────────────────────────────────────────────────────────────────

func _spawn_bodies() -> void:
	for body_id: String in solar_system.get_all_body_ids():
		var body: BodyDef = solar_system.get_body(body_id)

		var marker: BodyMarker = BODY_MARKER_SCENE.instantiate()
		_body_layer.add_child(marker)  # erst in den Baum, dann setup — @onready-Vars brauchen den Baum
		marker.setup(body, _view_controller.get_marker_size(body.type))
		marker.clicked.connect(_on_body_clicked.bind(body_id))
		_markers[body_id] = marker

		if not body.parent_id.is_empty():
			var path: Array[Vector2] = solar_system.get_local_orbit_path(body_id)
			if path.size() > 1:
				var orbit: OrbitRenderer = ORBIT_SCENE.instantiate()
				orbit.setup(body_id, body.parent_id, body.color_rgba, path)
				_orbit_layer.add_child(orbit)
				_orbits[body_id] = orbit


# ─── Position refresh ─────────────────────────────────────────────────────────

func _refresh_positions() -> void:
	var px_per_km := _map_scale.get_px_per_km()
	var vp_size   := get_viewport_rect().size
	var cull_rect := _view_controller.get_cull_rect(Vector2.ZERO, vp_size)

	# Grids — px_per_km aktualisieren + zentriert am Ursprung positionieren
	var sun_screen := _map_scale.world_to_screen(Vector2.ZERO)
	if _concentric_grid:
		_concentric_grid.set_px_per_km(px_per_km)
		_concentric_grid.position = sun_screen
	if _square_grid:
		_square_grid.set_px_per_km(px_per_km)
		_square_grid.position = sun_screen
		_square_grid.set_draw_rect(Rect2(-sun_screen, vp_size))

	# Bodies
	for body_id: String in _markers:
		var body:   BodyDef    = solar_system.get_body(body_id)
		var marker: BodyMarker = _markers[body_id]

		var orbit_km := solar_system.get_body_orbit_radius_km(body_id)
		var is_vis   := _view_controller.is_body_visible(body, orbit_km)

		if is_vis:
			var world_pos  := solar_system.get_body_position(body_id)
			var parent_pos := solar_system.get_body_position(body.parent_id) \
								if not body.parent_id.is_empty() else Vector2.ZERO
			var scr := _view_controller.world_to_display(world_pos, body, parent_pos)
			marker.position = scr
			marker.visible  = _view_controller.is_in_viewport(scr, cull_rect)
		else:
			marker.visible = false

		# Orbit
		if body_id in _orbits:
			var orbit: OrbitRenderer = _orbits[body_id]
			var parent_pos := solar_system.get_body_position(body.parent_id) \
								if not body.parent_id.is_empty() else Vector2.ZERO
			orbit.position = _map_scale.world_to_screen(parent_pos)

			if is_vis:
				var km_pts  := orbit.get_path_points_km()
				var scr_pts := PackedVector2Array()
				scr_pts.resize(km_pts.size())
				for i in km_pts.size():
					scr_pts[i] = km_pts[i] * px_per_km
				orbit.set_draw_points(scr_pts)
				orbit.visible = true
			else:
				orbit.visible = false

	# Belts — px_per_km + Position am Parent-Body
	for belt_id: String in _belt_renderers:
		var belt: BeltDef = _belt_defs[belt_id]
		var parent_pos := solar_system.get_body_position(belt.parent_id) \
							if not belt.parent_id.is_empty() else Vector2.ZERO
		_belt_renderers[belt_id].set_px_per_km(px_per_km)
		_belt_renderers[belt_id].set_density(_view_controller.get_belt_density(belt))
		_belt_renderers[belt_id].position = _map_scale.world_to_screen(parent_pos)

	# Zones — px_per_km + Position am Parent-Body
	for zone_id: String in _zone_renderers:
		var zone: ZoneDef = _zone_defs[zone_id]
		var parent_pos := solar_system.get_body_position(zone.parent_id) \
							if not zone.parent_id.is_empty() else Vector2.ZERO
		_zone_renderers[zone_id].set_px_per_km(px_per_km)
		_zone_renderers[zone_id].position = _map_scale.world_to_screen(parent_pos)

	_update_hud()


# ─── Signals ──────────────────────────────────────────────────────────────────

func _on_simulation_updated() -> void:
	_refresh_positions()


func _on_body_clicked(body_id: String) -> void:
	var body := solar_system.get_body(body_id)
	if body:
		_selected_body_text = "Ausgewählt: %s  [%s / %s]" % [body.name, body.type, body_id]
	_update_hud()


# ─── HUD ──────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	var scale_exp  := _map_scale.get_scale_exp()
	var mkm_per_px := _map_scale.get_km_per_px() / 1_000_000.0
	var time_str   := sim_clock.get_time_stamp_string_now()

	var lines: Array[String] = [
		"Zoom: %.1f  |  %.2f Mkm/px" % [scale_exp, mkm_per_px],
		"Zeit: %s" % time_str,
	]
	if not _selected_body_text.is_empty():
		lines.append(_selected_body_text)
	lines.append("")
	lines.append("[Mausrad / Q·E] Zoom   [Mittelklick / WASD] Pan   [R] Reset")

	_hud_label.text = "\n".join(lines)
