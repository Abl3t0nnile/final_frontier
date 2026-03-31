## OrbitManager
## Manages orbit renderers for all bodies with orbital motion

class_name OrbitManager
extends Node

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
		
		var orbit := OrbitRenderer.new()
		_orbit_layer.add_child(orbit)
		orbit.setup(def, _map_transform)
		_apply_orbit_config(orbit, def)
		_orbits[def.id] = orbit


func _apply_orbit_config(orbit: OrbitRenderer, def: BodyDef) -> void:
	# Apply configuration based on body type
	match def.type:
		"star":
			orbit.color = Color.YELLOW
			orbit.base_width = 2.0
		"planet":
			orbit.color = Color.CYAN
			orbit.base_width = 1.5
		"dwarf":
			orbit.color = Color.GRAY
			orbit.base_width = 1.0
		"moon":
			orbit.color = Color.WHITE
			orbit.base_width = 0.8
		_:
			orbit.color = Color.GRAY
			orbit.base_width = 1.0


func update_orbits() -> void:
	for id in _orbits:
		var orbit: OrbitRenderer = _orbits[id]
		var def: BodyDef = _model.get_body(id)
		if def == null:
			continue
		
		var parent_pos: Vector2 = Vector2.ZERO
		if def.parent_id != "":
			parent_pos = _model.get_body_position(def.parent_id)
		
		orbit.set_global_position(parent_pos)


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
