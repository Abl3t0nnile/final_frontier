## SolarSystemModel
## Zentrale Berechnung aller Objekt-Positionen und Zustands-Management
## Erweitert: Node

class_name SolarSystemModel
extends Node

## Signals
signal simulation_updated()

## Private
var _clock: SimClock = null
var _bodies_by_id: Dictionary = {}
var _update_order: Array[BodyDef] = []
var _current_state: Dictionary = {}


## Public Methods
func setup(clock: SimClock, bodies: Array[BodyDef]) -> void:
	"""Initialisiert Model mit Uhr und BodyDefs"""
	_clock = clock
	_bodies_by_id.clear()
	_update_order.clear()
	_current_state.clear()

	for body in bodies:
		if body != null:
			_bodies_by_id[body.id] = body

	if not _build_update_order():
		push_error("SolarSystemModel: failed to build update order. Check parent_ids.")

	# Initiale Positionen berechnen
	_update_simulation(0.0)

	# Mit Uhr verbinden
	if _clock:
		_clock.tick.connect(_on_clock_tick)


func set_game_clock_enabled(enabled: bool) -> void:
	"""GameClock-Updates aktivieren oder deaktivieren.
	Wird von MapController genutzt: Map-View wird ausschließlich von MapClock gesteuert."""
	if _clock == null:
		return
	if enabled:
		if not _clock.tick.is_connected(_on_clock_tick):
			_clock.tick.connect(_on_clock_tick)
	else:
		if _clock.tick.is_connected(_on_clock_tick):
			_clock.tick.disconnect(_on_clock_tick)


func get_body(id: String) -> BodyDef:
	"""Holt BodyDef nach ID"""
	return _bodies_by_id.get(id, null)


func get_body_position(id: String) -> Vector2:
	"""Holt aktuelle Position eines Körpers in km"""
	return _current_state.get(id, Vector2.ZERO)


func get_body_position_at_time(id: String, time_s: float) -> Vector2:
	"""Berechnet Position zu bestimmter Zeit (für Zeitreisen)"""
	var body: BodyDef = _bodies_by_id.get(id, null)
	if body == null:
		return Vector2.ZERO

	# Berechne alle benötigten Parent-Positionen
	var needed_ids: Array[String] = []
	var current_id := id
	while current_id != "":
		needed_ids.append(current_id)
		var b: BodyDef = _bodies_by_id.get(current_id, null)
		if b == null:
			break
		current_id = b.parent_id

	# Berechne in umgekehrter Reihenfolge (Parents zuerst)
	needed_ids.reverse()
	var temp_state: Dictionary = {}
	for nid in needed_ids:
		var b: BodyDef = _bodies_by_id.get(nid, null)
		if b == null:
			continue
		if b.parent_id == "":
			temp_state[nid] = Vector2.ZERO
		else:
			temp_state[nid] = _calculate_world_position(b, time_s, temp_state)

	return temp_state.get(id, Vector2.ZERO)


func get_all_body_ids() -> Array:
	"""Holt alle Body-IDs"""
	return _bodies_by_id.keys()


func get_children_of(parent_id: String) -> Array[String]:
	"""Holt alle Kinder eines Objekts"""
	var children: Array[String] = []
	for body: BodyDef in _bodies_by_id.values():
		if body.parent_id == parent_id:
			children.append(body.id)
	return children


func update_to_time(time_s: float) -> void:
	"""Aktualisiert alle Positionen zu gegebener Zeit (für Map-Scrubbing)"""
	_update_simulation(time_s)


func get_body_orbit_radius_km(id: String) -> float:
	"""Holt Orbit-Radius eines Körpers"""
	var body: BodyDef = _bodies_by_id.get(id, null)
	if body == null or body.motion == null:
		return 0.0

	match body.motion.model:
		"circular":
			var m := body.motion as CircularMotionDef
			return maxf(m.orbital_radius_km, 0.0) if m else 0.0
		"kepler2d":
			var m := body.motion as Kepler2DMotionDef
			return maxf(m.semi_major_axis_km, 0.0) if m else 0.0
		_:
			return 0.0


## Private Methods
func _on_clock_tick(_delta: float) -> void:
	if _clock:
		_update_simulation(_clock.current_time)


func _build_update_order() -> bool:
	"""Baut topologisch sortierte Update-Reihenfolge auf"""
	_update_order.clear()

	var pending_count: Dictionary = {}
	var dependents: Dictionary = {}

	for body: BodyDef in _bodies_by_id.values():
		if body.parent_id == "" or not _bodies_by_id.has(body.parent_id):
			pending_count[body.id] = 0
		else:
			pending_count[body.id] = 1
			if not dependents.has(body.parent_id):
				dependents[body.parent_id] = []
			dependents[body.parent_id].append(body.id)

	var queue: Array[String] = []
	for id: String in pending_count:
		if pending_count[id] == 0:
			queue.append(id)

	while queue.size() > 0:
		var current_id: String = queue.pop_front()
		_update_order.append(_bodies_by_id[current_id])

		if dependents.has(current_id):
			for child_id: String in dependents[current_id]:
				pending_count[child_id] -= 1
				if pending_count[child_id] == 0:
					queue.append(child_id)

	if _update_order.size() != _bodies_by_id.size():
		var resolved_ids: Array[String] = []
		for body: BodyDef in _update_order:
			resolved_ids.append(body.id)

		for id: String in _bodies_by_id:
			if id not in resolved_ids:
				var body: BodyDef = _bodies_by_id[id]
				push_error("Unresolvable parent chain: '%s' (parent_id: '%s')" % [body.name, body.parent_id])
		return false

	return true


func _update_simulation(time_s: float) -> void:
	"""Aktualisiert alle Positionen"""
	var next_state: Dictionary = {}

	for body: BodyDef in _update_order:
		if body.parent_id == "":
			next_state[body.id] = Vector2.ZERO
		else:
			next_state[body.id] = _calculate_world_position(body, time_s, next_state)

	_current_state = next_state

	if _clock != null and _clock.is_running:
		simulation_updated.emit()


func _calculate_world_position(body: BodyDef, time_s: float, state: Dictionary) -> Vector2:
	"""Berechnet Weltposition eines Körpers"""
	if body == null or body.motion == null:
		return Vector2.ZERO

	match body.motion.model:
		"fixed":
			return _calculate_fixed_position(body, state)
		"circular":
			return _calculate_circular_position(body, time_s, state)
		"kepler2d":
			return _calculate_kepler2d_position(body, time_s, state)
		"lagrange":
			return _calculate_lagrange_position(body, time_s, state)
		_:
			return Vector2.ZERO


func _get_parent_position(body: BodyDef, state: Dictionary) -> Vector2:
	"""Holt Parent-Position aus State"""
	if body == null or body.parent_id == "":
		return Vector2.ZERO
	return state.get(body.parent_id, Vector2.ZERO)


func _calculate_fixed_position(body: BodyDef, state: Dictionary) -> Vector2:
	var motion := body.motion as FixedMotionDef
	if motion == null:
		return Vector2.ZERO

	var parent_pos := _get_parent_position(body, state)
	return Vector2(motion.x_km, motion.y_km) + parent_pos


func _calculate_circular_position(body: BodyDef, time_s: float, state: Dictionary) -> Vector2:
	var motion := body.motion as CircularMotionDef
	if motion == null:
		return Vector2.ZERO

	var parent_pos := _get_parent_position(body, state)
	var local_pos := SpaceMath.sample_circular_position(motion, time_s)

	return parent_pos + local_pos


func _calculate_kepler2d_position(body: BodyDef, time_s: float, state: Dictionary) -> Vector2:
	var motion := body.motion as Kepler2DMotionDef
	if motion == null:
		return Vector2.ZERO

	var parent_pos := _get_parent_position(body, state)
	var parent_body: BodyDef = _bodies_by_id.get(body.parent_id, null)
	if parent_body == null:
		return parent_pos

	var local_pos := SpaceMath.sample_kepler2d_position(motion, parent_body.grav_param_km3_s2, time_s)

	return parent_pos + local_pos


func _calculate_lagrange_position(body: BodyDef, _time_s: float, state: Dictionary) -> Vector2:
	var motion := body.motion as LagrangeMotionDef
	if motion == null:
		return Vector2.ZERO

	var primary_pos: Vector2 = state.get(motion.primary_id, Vector2.ZERO)
	var secondary_pos: Vector2 = state.get(motion.secondary_id, Vector2.ZERO)

	var diff: Vector2 = secondary_pos - primary_pos
	var dist: float = diff.length()

	if dist < 0.001:
		return primary_pos

	var dir: Vector2 = diff / dist

	var primary_body: BodyDef = _bodies_by_id.get(motion.primary_id, null)
	var secondary_body: BodyDef = _bodies_by_id.get(motion.secondary_id, null)
	if primary_body == null or secondary_body == null:
		return primary_pos

	var mu_ratio: float = secondary_body.grav_param_km3_s2 / maxf(primary_body.grav_param_km3_s2, 0.000001)
	var r_hill: float = dist * pow(mu_ratio / 3.0, 1.0 / 3.0)

	match motion.point:
		1:
			return secondary_pos - dir * r_hill
		2:
			return secondary_pos + dir * r_hill
		3:
			return primary_pos - diff
		4:
			return primary_pos + diff.rotated(-PI / 3.0)
		5:
			return primary_pos + diff.rotated(PI / 3.0)
		_:
			return primary_pos
