# map_test_scene.gd — Testszene für das Map Toolkit.
# Demonstriert alle Komponenten: BodyMarker, OrbitRenderer, BeltRenderer,
# ZoneRenderer, ConcentricGridRenderer, SquareGridRenderer, MapScale,
# ScopeConfig, ScopeResolver, MapViewController, MapDataLoader.
extends Node2D

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
var _map_scale:       MapScale          = MapScale.new()
var _scope_resolver:  ScopeResolver     = ScopeResolver.new()
var _view_controller: MapViewController = MapViewController.new()

# ─── Live renderer maps ───────────────────────────────────────────────────────
var _markers:        Dictionary = {}  # body_id  → BodyMarker
var _orbits:         Dictionary = {}  # body_id  → OrbitRenderer
var _belt_renderers: Dictionary = {}  # belt_id  → BeltRenderer
var _belt_defs:      Dictionary = {}  # belt_id  → BeltDef
var _zone_renderers: Dictionary = {}  # zone_id  → ZoneRenderer
var _zone_defs:      Dictionary = {}  # zone_id  → ZoneDef

var _concentric_grid: ConcentricGridRenderer = null
var _square_grid:     SquareGridRenderer     = null

# ─── Camera state ─────────────────────────────────────────────────────────────
var _world_center_km:  Vector2 = Vector2.ZERO  # world km shown at screen centre
var _is_panning:       bool    = false
var _pan_start_mouse:  Vector2 = Vector2.ZERO
var _pan_start_center: Vector2 = Vector2.ZERO

const SCALE_EXP_START: float = 7.5
const SCALE_EXP_MIN:   float = 4.0
const SCALE_EXP_MAX:   float = 10.0
const ZOOM_STEP:       float = 0.2

# Selected body display
var _selected_body_text: String = ""


# ─── Init ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_scale_and_scope()
	_setup_grids()
	_load_belts_and_zones()
	_spawn_bodies()
	_refresh_positions()
	SolarSystem.simulation_updated.connect(_on_simulation_updated)
	SimClock.start()


func _setup_scale_and_scope() -> void:
	_map_scale.set_scale_exp(SCALE_EXP_START)
	_sync_origin()

	var scope := ScopeConfig.new()
	scope.scope_name           = "Gesamtsystem"
	scope.zoom_min             = SCALE_EXP_MIN
	scope.zoom_max             = SCALE_EXP_MAX
	scope.fokus_tags           = []
	scope.exag_faktor          = 1.0
	scope.visible_types        = []
	scope.visible_tags         = []
	scope.visible_zones        = []
	scope.min_orbit_px         = 3.0
	scope.context_min_orbit_px = 0.0
	scope.marker_sizes         = {
		"star": 32, "planet": 24, "dwarf": 16, "moon": 14, "struct": 12
	}

	_scope_resolver.setup([scope])
	_view_controller.setup(_scope_resolver, _map_scale)
	_view_controller.resolve_scope(_map_scale.get_scale_exp(), null)


func _sync_origin() -> void:
	var vp_half   := get_viewport_rect().size * 0.5
	var km_per_px := _map_scale.get_km_per_px()
	_map_scale.set_origin(_world_center_km - vp_half * km_per_px)


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
	var scope := _view_controller.get_current_scope()

	for body_id: String in SolarSystem.get_all_body_ids():
		var body: BodyDef = SolarSystem.get_body(body_id)

		var marker: BodyMarker = BODY_MARKER_SCENE.instantiate()
		_body_layer.add_child(marker)  # erst in den Baum, dann setup — @onready-Vars brauchen den Baum
		marker.setup(body, scope.get_marker_size(body.type) if scope else 16)
		marker.clicked.connect(_on_body_clicked.bind(body_id))
		_markers[body_id] = marker

		if not body.parent_id.is_empty():
			var path: Array[Vector2] = SolarSystem.get_local_orbit_path(body_id)
			if path.size() > 1:
				var orbit: OrbitRenderer = ORBIT_SCENE.instantiate()
				orbit.setup(body_id, body.parent_id, body.color_rgba, path)
				_orbit_layer.add_child(orbit)
				_orbits[body_id] = orbit


# ─── Position refresh ─────────────────────────────────────────────────────────

func _refresh_positions() -> void:
	_sync_origin()
	var px_per_km := _map_scale.get_px_per_km()
	var vp_size   := get_viewport_rect().size
	var cull_rect := _view_controller.get_cull_rect(Vector2.ZERO, vp_size)

	# Grids — centred at solar-system origin in screen space
	var sun_screen := _map_scale.world_to_screen(Vector2.ZERO)
	if _concentric_grid:
		_concentric_grid.position = sun_screen
	if _square_grid:
		_square_grid.position = sun_screen
		_square_grid.set_draw_rect(Rect2(-sun_screen, vp_size))

	# Bodies
	for body_id: String in _markers:
		var body:   BodyDef    = SolarSystem.get_body(body_id)
		var marker: BodyMarker = _markers[body_id]

		var orbit_km   := SolarSystem.get_body_orbit_radius_km(body_id)
		var is_vis := _view_controller.is_body_visible(body, orbit_km)

		if is_vis:
			var world_pos  := SolarSystem.get_body_position(body_id)
			var parent_pos := SolarSystem.get_body_position(body.parent_id) \
								if not body.parent_id.is_empty() else Vector2.ZERO
			var scr := _view_controller.world_to_display(world_pos, body, parent_pos)
			marker.position = scr
			marker.visible  = _view_controller.is_in_viewport(scr, cull_rect)
		else:
			marker.visible = false

		# Orbit
		if body_id in _orbits:
			var orbit: OrbitRenderer = _orbits[body_id]
			var parent_pos := SolarSystem.get_body_position(body.parent_id) \
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

	# Belts — positioned at parent-body screen position
	for belt_id: String in _belt_renderers:
		var belt: BeltDef = _belt_defs[belt_id]
		var parent_pos := SolarSystem.get_body_position(belt.parent_id) \
							if not belt.parent_id.is_empty() else Vector2.ZERO
		_belt_renderers[belt_id].position = _map_scale.world_to_screen(parent_pos)

	# Zones — positioned at parent-body screen position
	for zone_id: String in _zone_renderers:
		var zone: ZoneDef = _zone_defs[zone_id]
		var parent_pos := SolarSystem.get_body_position(zone.parent_id) \
							if not zone.parent_id.is_empty() else Vector2.ZERO
		_zone_renderers[zone_id].position = _map_scale.world_to_screen(parent_pos)

	_update_hud()


# ─── Zoom ─────────────────────────────────────────────────────────────────────

func _do_zoom(delta_exp: float, mouse_pos: Vector2) -> void:
	var old_exp := _map_scale.get_scale_exp()
	var new_exp = clamp(old_exp + delta_exp, SCALE_EXP_MIN, SCALE_EXP_MAX)
	if new_exp == old_exp:
		return

	# Keep the world point under the mouse stationary
	var vp_half         := get_viewport_rect().size * 0.5
	var offset_px       := mouse_pos - vp_half
	var world_at_mouse  := _world_center_km + offset_px * _map_scale.get_km_per_px()

	_map_scale.set_scale_exp(new_exp)
	_world_center_km = world_at_mouse - offset_px * _map_scale.get_km_per_px()

	_on_zoom_changed()


func _on_zoom_changed() -> void:
	var px_per_km := _map_scale.get_px_per_km()
	_view_controller.resolve_scope(_map_scale.get_scale_exp(), null)

	if _concentric_grid:
		_concentric_grid.set_px_per_km(px_per_km)
	if _square_grid:
		_square_grid.set_px_per_km(px_per_km)

	for belt_id: String in _belt_renderers:
		_belt_renderers[belt_id].set_px_per_km(px_per_km)
		_belt_renderers[belt_id].set_density(_view_controller.get_belt_density(_belt_defs[belt_id]))

	for zone_id: String in _zone_renderers:
		_zone_renderers[zone_id].set_px_per_km(px_per_km)

	_refresh_positions()


# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_do_zoom(-ZOOM_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_do_zoom(ZOOM_STEP, event.position)
			MOUSE_BUTTON_RIGHT:
				_is_panning = event.pressed
				if _is_panning:
					_pan_start_mouse  = event.position
					_pan_start_center = _world_center_km

	elif event is InputEventMouseMotion:
		if _is_panning:
			var delta = event.position - _pan_start_mouse
			_world_center_km = _pan_start_center - delta * _map_scale.get_km_per_px()
			_refresh_positions()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_world_center_km = Vector2.ZERO
			_map_scale.set_scale_exp(SCALE_EXP_START)
			_on_zoom_changed()


# ─── Signals ──────────────────────────────────────────────────────────────────

func _on_simulation_updated() -> void:
	_refresh_positions()


func _on_body_clicked(body_id: String) -> void:
	var body := SolarSystem.get_body(body_id)
	if body:
		_selected_body_text = "Ausgewählt: %s  [%s / %s]" % [body.name, body.type, body_id]
	_update_hud()


# ─── HUD ──────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	var scale_exp  := _map_scale.get_scale_exp()
	var mkm_per_px := _map_scale.get_km_per_px() / 1_000_000.0
	var scope      := _view_controller.get_current_scope()
	var scope_name := scope.scope_name if scope else "—"
	var time_str   := SimClock.get_time_stamp_string_now()

	var lines: Array[String] = [
		"Zoom: %.1f  |  %.2f Mkm/px  |  Scope: %s" % [scale_exp, mkm_per_px, scope_name],
		"Zeit: %s" % time_str,
	]
	if not _selected_body_text.is_empty():
		lines.append(_selected_body_text)
	lines.append("")
	lines.append("[Mausrad] Zoom   [Rechtsklick] Pan   [R] Reset")

	_hud_label.text = "\n".join(lines)
