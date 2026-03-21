# res://core/sim/autoload_solar_system_sim.gd
# This autoload singleton is the central "state of truth" for the current game state. It holds the complete positional
# data for all deterministic objects within this simulation at any given time. It is automatically initialised at the 
# beginning of its lifecycle by the current SimClock time stamp. Therefore this class is directly linked to Sim Clock.
# SolarSystemModel updates itself on every SimClock.sim_clock_tick(sst: float). The public API of this class provides
# lookup funtions for the current position of every single simulated object or groups of objects. This simulation is
# completely independent from any gameplay events like ships moving in space. This simulation is 100 % deterministic.

class_name SolarSystemModelV2

extends Node

# Emitted every time the simulation updates. Should act as the central anchor point for everything about rendering
signal simulation_updated

# Central dataset for all objects within this simulation. Belts are a different Story, but every other object in this
# dict inherits BaseBodyDef.
var _sim_objects: Dictionary = {
	"center": null,
	"planets": [],
	"dwarfes": [],
	"moons": [],
	"belts": {},
	"structs": []
}

# Topologically sorted body list. Guarantees that every parent is calculated
# before any of its children. Built once during _build_sim_from_loader.
var _update_order: Array[BodyDef] = []

# Lookup table for faster acces to objects by id.
var _bodies_by_id: Dictionary = {}
# This dict holds the position of every object at the current physics_frame ordered by ids. It is the defacto "truth"
# of every objects position at any given time.
var _current_state: Dictionary = {}

# Cached local orbital path points for rendering. These paths are relative to the parent origin and therefore only need
# to be calculated once on build or rebuild.
var _local_orbit_path_cache: Dictionary = {}

# Upper limit for points in object orbit paths
var max_segments: float = 512.0


# This autoload singleton has to be after SimClock and SolarDB in the load order, as it references both objects
func _ready() -> void:
	_build_sim_from_loader(true)
	print("Solar System Model initialisiert.")
	SimClock.sim_clock_tick.connect(_update_simulation)
	print("Sim Clock connected @ Time %s" % SimClock.get_time_stamp_string_now())

# Builds the initial sim state from the SolarDB. Calculates the initial position of every body and the points on their
# orbital path.
func _build_sim_from_loader(verbose: bool = false) -> void:
	if verbose:
		print()
		print("Building Solar System Model from Loader.")
		print()
	# Reset object data
	_sim_objects["center"] = null
	_sim_objects["planets"].clear()
	_sim_objects["dwarfes"].clear()
	_sim_objects["moons"].clear()
	_sim_objects["structs"].clear()
	_sim_objects["belts"].clear()
	_bodies_by_id.clear()
	_reset_local_orbit_path_cache()
	# Get body data from data base -> SolarDB API
	var data_loader := CoreDataLoader.new()
	var all_bodies: Array[BodyDef] = data_loader.load_all_body_defs()
	# Iterate over data
	for body in all_bodies:
		if body == null:
			continue
		# Add body to sim
		_bodies_by_id[body.id] = body
		# Append body to sim data by type
		match body.type:
			"star":
				_sim_objects["center"] = body
			"planet":
				_sim_objects["planets"].append(body)
			"dwarf":
				_sim_objects["dwarfes"].append(body)
			"moon":
				_sim_objects["moons"].append(body)
			"struct":
				_sim_objects["structs"].append(body)
			_:
				pass
	
	 # Validate and sort
	if not _build_update_order():
		push_error("Solar System Model: failed to build update order. Check parent_ids.")

	# Calculate initial positions of all body, cause the game map will need initial data
	_update_simulation(0.0)
	# Calculate points for orbital path drawing once (this doesnt need to be updated, cause its real world data relative
	# to the moving parent node)
	for body in all_bodies:
		if body == null:
			continue
		_build_local_orbit_path(body)

	if verbose:
		print_current_state()


func _build_update_order() -> bool:
	_update_order.clear()

	# How many unresolved parents does each body still have?
	var pending_count: Dictionary = {}   # id -> int
	# Which bodies depend on this parent?
	var dependents: Dictionary = {}      # parent_id -> Array[String]

	for body in _bodies_by_id.values():
		if body.parent_id == "" or not _bodies_by_id.has(body.parent_id):
			# Root node or parent is the implicit world origin
			pending_count[body.id] = 0
		else:
			pending_count[body.id] = 1
			if not dependents.has(body.parent_id):
				dependents[body.parent_id] = []
			dependents[body.parent_id].append(body.id)

	# Seed: all bodies with no pending parent
	var queue: Array[String] = []
	for id in pending_count:
		if pending_count[id] == 0:
			queue.append(id)

	# Process queue (Kahn's algorithm)
	while queue.size() > 0:
		var current_id: String = queue.pop_front()
		_update_order.append(_bodies_by_id[current_id])

		if dependents.has(current_id):
			for child_id in dependents[current_id]:
				pending_count[child_id] -= 1
				if pending_count[child_id] == 0:
					queue.append(child_id)

	# Validation: if we didn't process all bodies, there's a cycle or
	# a dangling parent_id
	if _update_order.size() != _bodies_by_id.size():
		var resolved_ids: Array[String] = []
		for body in _update_order:
			resolved_ids.append(body.id)

		for id in _bodies_by_id:
			if id not in resolved_ids:
				var body: BodyDef = _bodies_by_id[id]
				push_error(
                    "Unresolvable parent chain: '%s' (parent_id: '%s')"
					% [body.name, body.parent_id]
				)
		return false

	return true


func _reset_local_orbit_path_cache() -> void:
	_local_orbit_path_cache.clear()

# Calculates the positional data for all objects within this simulation at given solar standard time.
func _update_simulation(sst_s: float) -> void:
	var next_state: Dictionary = {}

	for body in _update_order:
		if body.parent_id == "":
			next_state[body.id] = Vector2.ZERO
		else:
			next_state[body.id] = _calculate_world_position_for_body(body, sst_s, next_state)

	_current_state = next_state

	if SimClock.is_running():
		simulation_updated.emit()


func _wrap_angle_rad(angle: float) -> float:
	return fposmod(angle, TAU)

func _solve_kepler_equation(mean_anomaly: float, eccentricity: float, max_iterations: int = 12) -> float:
	var M := _wrap_angle_rad(mean_anomaly)
	var e = clamp(eccentricity, 0.0, 0.999999)

	var E := M
	if e > 0.8:
		E = PI

	for i in max_iterations:
		var f = E - e * sin(E) - M
		var fp = 1.0 - e * cos(E)

		if abs(fp) < 0.000001:
			break

		var delta = f / fp
		E -= delta

		if abs(delta) < 0.000001:
			break

	return E

func _get_parent_world_position(body: BodyDef, state: Dictionary) -> Vector2:
	if body == null or body.parent_id == "":
		return Vector2.ZERO
	return state.get(body.parent_id, Vector2.ZERO)

# Shared kepler 2d calculation. Returns the local orbital position relative to the parent origin.
func _get_kepler2d_period_s(motion: Kepler2DMotionDef, parent_mu_km3_s2: float) -> float:
	if motion == null:
		return 0.0

	var a_km: float = motion.a_km
	if a_km <= 0.0 or parent_mu_km3_s2 <= 0.0:
		return 0.0

	return TAU * sqrt(pow(a_km, 3.0) / parent_mu_km3_s2)

# Shared kepler 2d calculation. Returns the local orbital position relative to the parent origin at given time.
func _sample_kepler2d_local_position(motion: Kepler2DMotionDef, parent_mu_km3_s2: float, sst_s: float) -> Vector2:
	if motion == null:
		return Vector2.ZERO

	var a_km: float = motion.a_km
	if a_km <= 0.0 or parent_mu_km3_s2 <= 0.0:
		return Vector2.ZERO

	var e = clamp(motion.e, 0.0, 0.999999)
	var period_s: float = _get_kepler2d_period_s(motion, parent_mu_km3_s2)
	if period_s <= 0.0:
		return Vector2.ZERO

	var dt: float = sst_s - motion.epoch_tt_s
	var mean_motion: float = TAU / period_s
	var direction: float = -1.0 if motion.clockwise else 1.0

	var mean_anomaly: float = motion.mean_anomaly_epoch_rad + direction * mean_motion * dt
	var eccentric_anomaly: float = _solve_kepler_equation(mean_anomaly, e)

	var b_km: float = a_km * sqrt(1.0 - e * e)
	var x_orbit: float = a_km * (cos(eccentric_anomaly) - e)
	var y_orbit: float = b_km * sin(eccentric_anomaly)

	var cos_w: float = cos(motion.arg_pe_rad)
	var sin_w: float = sin(motion.arg_pe_rad)

	var x_rot: float = x_orbit * cos_w - y_orbit * sin_w
	var y_rot: float = x_orbit * sin_w + y_orbit * cos_w

	return Vector2(x_rot, y_rot)

# Returns the fixed position of given body.
func _calculate_fixed_world_position(body: BodyDef, state: Dictionary) -> Vector2:
	var motion := body.motion as FixedMotionDef
	if motion == null:
		return Vector2.ZERO

	var parent_pos: Vector2 = _get_parent_world_position(body, state)
	return Vector2(motion.x_km, motion.y_km) + parent_pos

# Calculates the position of given body at given time on its circular orbit.
func _calculate_circular_world_position(body: BodyDef, sst_s: float, state: Dictionary) -> Vector2:
	var motion := body.motion as CircularMotionDef
	if motion == null:
		return Vector2.ZERO

	var period_s: float = motion.period_s
	if period_s <= 0.0:
		return _get_parent_world_position(body, state)

	var direction: float = -1.0 if motion.clockwise else 1.0
	var omega: float = TAU / period_s
	var theta: float = motion.phase_rad + direction * omega * sst_s

	var x: float = cos(theta) * motion.orbital_radius_km
	var y: float = sin(theta) * motion.orbital_radius_km

	var parent_pos: Vector2 = _get_parent_world_position(body, state)
	return parent_pos + Vector2(x, y)

# Calculates the position of given body at given time on its simplified kepler 2d orbit.
func _calculate_kepler2d_world_position(body: BodyDef, sst_s: float, state: Dictionary) -> Vector2:
	var motion := body.motion as Kepler2DMotionDef
	if motion == null:
		return Vector2.ZERO

	var parent_pos: Vector2 = _get_parent_world_position(body, state)
	var parent_body: BodyDef = _bodies_by_id.get(body.parent_id, null)
	if parent_body == null:
		return parent_pos

	return parent_pos + _sample_kepler2d_local_position(motion, parent_body.mu_km3_s2, sst_s)

# Calculates the position of given body at given time on its orbit, defined by its lagrange point.
func _calculate_lagrange_world_position(body: BodyDef, _sst_s: float, state: Dictionary) -> Vector2:
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

	# Massenverhältnis aus µ (µ = G*m, also proportional zur Masse)
	var mu_ratio: float = secondary_body.mu_km3_s2 / max(primary_body.mu_km3_s2, 0.000001)
	# Hill-Radius-Approximation
	var r_hill: float = dist * pow(mu_ratio / 3.0, 1.0 / 3.0)

	match motion.point:
		1:  # Zwischen Primary und Secondary
			return secondary_pos - dir * r_hill
		2:  # Hinter Secondary, von Primary aus gesehen
			return secondary_pos + dir * r_hill
		3:  # Gegenüber von Secondary, hinter Primary
			return primary_pos - diff
		4:  # 60° voraus auf der Bahn des Secondary
			return primary_pos + diff.rotated(-PI / 3.0)
		5:  # 60° hinterher
			return primary_pos + diff.rotated(PI / 3.0)
		_:
			return primary_pos

# Wrapper function for trigonometric calculation, based on body.motion_type.
func _calculate_world_position_for_body(body: BodyDef, sst_s: float, state: Dictionary) -> Vector2:
	if body == null or body.motion == null:
		return Vector2.ZERO

	match body.motion.model:
		"fixed":
			return _calculate_fixed_world_position(body, state)
		"circular":
			return _calculate_circular_world_position(body, sst_s, state)
		"kepler2d":
			return _calculate_kepler2d_world_position(body, sst_s, state)
		"lagrange":
			return _calculate_lagrange_world_position(body, sst_s, state)
		_:
			return Vector2.ZERO

# Calculates a number of points on the orbital path of given body and returns them as an array.
func _build_local_orbit_path(body: BodyDef, min_segments: int = 64) -> Array[Vector2]:
	if body == null:
		return [Vector2.ZERO]

	if _local_orbit_path_cache.has(body.id):
		return _local_orbit_path_cache[body.id]

	var points: Array[Vector2]

	if body.motion == null or body.motion.model == "fixed":
		points = [Vector2.ZERO]
		_local_orbit_path_cache[body.id] = points
		return points

	var a_km: float = _get_body_orbit_radius_km(body)
	if a_km <= 0.0:
		var zero_points: Array[Vector2] = [Vector2.ZERO]
		_local_orbit_path_cache[body.id] = zero_points
		return zero_points

	var segments: int = min_segments

	match body.motion.model:
		"circular":
			var motion := body.motion as CircularMotionDef
			var direction: float = -1.0 if motion.clockwise else 1.0

			points = []
			points.resize(segments + 1)
			for i in range(segments + 1):
				var t: float = float(i) / float(segments)
				var theta: float = motion.phase_rad + direction * TAU * t
				points[i] = Vector2(cos(theta), sin(theta)) * motion.orbital_radius_km

		"kepler2d":
			var motion := body.motion as Kepler2DMotionDef
			# Higher eccentricity needs more segments for smooth periapsis region
			segments = clampi(min_segments + int(192.0 * motion.e), min_segments, max_segments)

			var parent_body: BodyDef = _bodies_by_id.get(body.parent_id, null)
			var parent_mu_km3_s2: float = 0.0
			if parent_body != null:
				parent_mu_km3_s2 = parent_body.mu_km3_s2

			var period_s: float = _get_kepler2d_period_s(motion, parent_mu_km3_s2)

			points = []
			points.resize(segments + 1)
			for i in range(segments + 1):
				var t: float = float(i) / float(segments)
				var orbit_time_s: float = motion.epoch_tt_s + period_s * t
				points[i] = _sample_kepler2d_local_position(motion, parent_mu_km3_s2, orbit_time_s)

		_:
			var fallback_points: Array[Vector2] = [Vector2.ZERO]
			_local_orbit_path_cache[body.id] = fallback_points
			return fallback_points

	_local_orbit_path_cache[body.id] = points
	return points

func _get_body_orbit_radius_km(body: BodyDef) -> float:
	if body == null or body.motion == null:
		return 0.0

	match body.motion.model:
		"circular":
			var m := body.motion as CircularMotionDef
			return max(m.orbital_radius_km, 0.0)
		"kepler2d":
			var m := body.motion as Kepler2DMotionDef
			return max(m.a_km, 0.0)
		_:
			return 0.0


########################################################################################################################
# PUBLIC - API
########################################################################################################################

# ----------------------------------------------------------------------------------------------------------------------
# Clock Control
# ----------------------------------------------------------------------------------------------------------------------

# Returns an array containing all ids currently present within this simulation
func get_all_body_ids() -> Array:
	return _bodies_by_id.keys()

# Returns the BodyDef of the object with given id. Returns null if the id is not found.
func get_body(id: String) -> BodyDef:
	return _bodies_by_id.get(id, null)

# Returns the position of a given body by id as Vector2 in real world position.
func get_body_position(id: String) -> Vector2:
	return _current_state.get(id, Vector2.ZERO)


func get_body_orbit_radius_km(id: String) -> float:
	var body = _bodies_by_id.get(id, null)
	if body == null:
		return 0.0
	return _get_body_orbit_radius_km(body)


# Returns the world positions of a set of bodies at an arbitrary point in time.
# Does NOT modify _current_state — pure function, no side effects.
# Makes a single pass through _update_order (topological order) and resolves all
# ancestors needed by the requested ids. Returns a Dictionary { id -> Vector2 }.
#
# Prefer this over get_body_position_at_time when querying multiple bodies at once
# (e.g. all visible bodies in StarChart Vorspul-Modus). With 200+ bodies in the
# simulation a per-body call would rebuild the full ancestor chain repeatedly.
func get_body_positions_at_time(ids: Array[String], sst: float) -> Dictionary:
	if ids.is_empty():
		return {}

	# Build a set of all ids we need to resolve: the requested bodies plus all
	# their ancestors (required by _calculate_world_position_for_body).
	var needed: Dictionary = {}
	for id in ids:
		if not _bodies_by_id.has(id):
			continue
		# Walk up the parent chain and mark every ancestor as needed.
		var current_id: String = id
		while current_id != "":
			if needed.has(current_id):
				break  # Already marked — ancestor chain already covered.
			needed[current_id] = true
			var body: BodyDef = _bodies_by_id.get(current_id, null)
			if body == null:
				break
			current_id = body.parent_id

	# Single pass in topological order — only compute bodies we actually need.
	var temp_state: Dictionary = {}
	for body in _update_order:
		if not needed.has(body.id):
			continue
		if body.parent_id == "":
			temp_state[body.id] = Vector2.ZERO
		else:
			temp_state[body.id] = _calculate_world_position_for_body(body, sst, temp_state)

	# Return only the originally requested ids.
	var result: Dictionary = {}
	for id in ids:
		if temp_state.has(id):
			result[id] = temp_state[id]

	return result


# Convenience wrapper for a single body. For multiple bodies prefer
# get_body_positions_at_time to avoid redundant ancestor resolution.
func get_body_position_at_time(id: String, sst: float) -> Vector2:
	var result := get_body_positions_at_time([id], sst)
	return result.get(id, Vector2.ZERO)


# Returns the local orbit path of a given body by id. These points are relative to the parent origin and are meant to
# be drawn by a node that is attached to the moving parent node.
func get_local_orbit_path(id: String) -> Array[Vector2]:
	return _local_orbit_path_cache.get(id, [Vector2.ZERO])


# Returns all direct child body defs of the given parent body id.
func get_child_bodies(parent_id: String) -> Array[BodyDef]:
	var children: Array[BodyDef] = []

	for body in _bodies_by_id.values():
		if body == null:
			continue
		if body.parent_id == parent_id:
			children.append(body)

	return children


# Returns all body defs of the given type.
func get_bodies_by_type(type: String) -> Array[BodyDef]:
	var bodies: Array[BodyDef] = []

	for body in _bodies_by_id.values():
		if body == null:
			continue
		if body.type == type:
			bodies.append(body)

	return bodies


# Returns all direct child body defs of the given parent body id that match the given type.
func get_children_by_type(parent_id: String, type: String) -> Array[BodyDef]:
	var children: Array[BodyDef] = []

	for body in _bodies_by_id.values():
		if body == null:
			continue
		if body.parent_id == parent_id and body.type == type:
			children.append(body)

	return children


# Returns all root body defs that do not have a parent body.
func get_root_bodies() -> Array[BodyDef]:
	var roots: Array[BodyDef] = []

	for body in _bodies_by_id.values():
		if body == null:
			continue
		if body.parent_id == "":
			roots.append(body)

	return roots


# Debug print function
func print_current_state() -> void:
	var center: BodyDef = _sim_objects["center"]
	if center != null:
		print("Center: %s @ Pos: %s" % [center.name, _current_state.get(center.id, Vector2.ZERO)])

	print()
	print("Planets:")
	print("--------")
	print()
	for planet in _sim_objects["planets"]:
		print("Planet: %s @ Pos: %s" % [planet.name, _current_state.get(planet.id, Vector2.ZERO)])

	print()
	print("Dwarf Planets:")
	print("--------------")
	print()
	for dwarf in _sim_objects["dwarfes"]:
		print("Dwarf: %s @ Pos: %s" % [dwarf.name, _current_state.get(dwarf.id, Vector2.ZERO)])

	print()
	print("Moons:")
	print("------")
	print()
	for moon in _sim_objects["moons"]:
		print("Moon: %s, orbiting parent: %s @ Pos: %s" % [moon.name, moon.parent_id, _current_state.get(moon.id, Vector2.ZERO)])

	print()
	print("Structures:")
	print("-----------")
	print()
	for struct in _sim_objects["structs"]:
		print("Struct: %s, orbiting parent: %s @ Pos: %s" % [struct.name, struct.parent_id, _current_state.get(struct.id, Vector2.ZERO)])

	print()
