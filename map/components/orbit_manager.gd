## OrbitManager
## Manages orbit renderers for all bodies with orbital motion

class_name OrbitManager
extends Node

# Configuration properties
var base_width: float      = 1.0
var highlight_width: float = 2.0
var dimmed_width: float    = 0.5
var alpha_default: float   = 0.2
var alpha_highlight: float = 0.6
var alpha_dimmed: float    = 0.08
var color_override_enabled: bool = false
var color_planet: Color    = Color.CYAN
var color_moon: Color      = Color.GRAY
var color_dwarf: Color     = Color.ORANGE
var color_struct: Color    = Color.YELLOW
var color_comet: Color     = Color(0.75, 0.88, 1.0)
var has_comets: bool       = true

var _orbit_layer: Node2D         = null
var _map_transform: MapTransform = null
var _model: SolarSystemModel     = null
var _registry: GameObjectRegistry = null
var _orbits: Dictionary = {}  # id -> OrbitRenderer


func setup(orbit_layer: Node2D, map_transform: MapTransform,
		model: SolarSystemModel, registry: GameObjectRegistry) -> void:
	_orbit_layer = orbit_layer
	_map_transform = map_transform
	_model = model
	_registry = registry
	
	# Create orbit renderers for all bodies with circular/kepler2d motion
	for game_object in _registry.get_all_objects():
		if not game_object or not game_object.body_def:
			continue
		
		var def: BodyDef = game_object.body_def
		if def.motion == null:
			continue
		if def.motion.model not in ["circular", "kepler2d"]:
			continue
		if def.type == "comet" and not has_comets:
			continue
		
		var orbit := OrbitRenderer.new()
		_orbit_layer.add_child(orbit)
		orbit.setup(def, _map_transform)
		_apply_orbit_config(orbit, def)
		_orbits[def.id] = orbit


func _apply_orbit_config(orbit: OrbitRenderer, def: BodyDef) -> void:
	# Apply width configuration
	orbit.base_width = base_width
	orbit.highlight_width = highlight_width
	orbit.dimmed_width = dimmed_width
	orbit.alpha_default = alpha_default
	orbit.alpha_highlight = alpha_highlight
	orbit.alpha_dimmed = alpha_dimmed
	
	# Apply color configuration if enabled
	if color_override_enabled:
		match def.type:
			"planet": orbit.color = color_planet
			"moon":   orbit.color = color_moon
			"dwarf":  orbit.color = color_dwarf
			"struct": orbit.color = color_struct
			"comet":  orbit.color = color_comet


func update_orbits() -> void:
	for id in _orbits:
		var orbit: OrbitRenderer = _orbits[id]
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		
		var parent_pos: Vector2 = Vector2.ZERO
		if def.parent_id != "":
			parent_pos = _model.get_body_position(def.parent_id)
		
		# Convert to map transform coordinates
		var map_pos := _map_transform.km_to_px(parent_pos)
		orbit.position = map_pos


func update_zoom(_km_per_px: float) -> void:
	for orbit in _orbits.values():
		orbit.queue_redraw()


func set_highlight(id: String, on: bool) -> void:
	var orbit: OrbitRenderer = _orbits.get(id)
	if orbit:
		if on:
			orbit.set_state(OrbitRenderer.OrbitState.HIGHLIGHT)
		else:
			orbit.set_state(OrbitRenderer.OrbitState.DEFAULT)


func set_visibility(id: String, visible: bool) -> void:
	var orbit: OrbitRenderer = _orbits.get(id)
	if orbit:
		orbit.visible = visible


func get_orbit(id: String) -> OrbitRenderer:
	return _orbits.get(id)


func get_orbits() -> Dictionary:
	return _orbits
