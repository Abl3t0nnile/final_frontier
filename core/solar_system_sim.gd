# res://core/solar_system_sim.gd
# Central "state of truth" for the current positional simulation. Holds the complete
# positional data for all deterministic objects at any given time.
# Instantiated and configured by main.gd — not an autoload.
# Call setup() after add_child() to connect the clock and load data.

class_name SolarSystemModel

extends Node

# Emitted every time the simulation updates.
signal simulation_updated

# Central dataset for all objects within this simulation.
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

# Lookup table for faster access to objects by id.
var _bodies_by_id: Dictionary = {}
# Current world position of every object, ordered by id.
var _current_state: Dictionary = {}

# Cached local orbital path points for rendering. Relative to parent origin.
var _local_orbit_path_cache: Dictionary = {}

# Upper limit for points in object orbit paths
var max_segments: float = 1028.0

# Reference to SimulationClock — set via setup()
var _clock: SimulationClock = null


func setup(
    clock: SimulationClock,
    bodies_path: String = CoreDataLoader.DEFAULT_DATA_PATH,
    structs_path: String = CoreDataLoader.DEFAULT_STRUCTS_PATH
) -> void:
    _clock = clock
    _build_sim_from_loader(bodies_path, structs_path, true)
    print("Solar System Model initialisiert.")
    _clock.sim_clock_tick.connect(_update_simulation)
    print("Sim Clock connected @ Time %s" % _clock.get_time_stamp_string_now())


func _build_sim_from_loader(bodies_path: String, structs_path: String, verbose: bool = false) -> void:
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

    var data_loader := CoreDataLoader.new()
    var all_bodies: Array[BodyDef] = data_loader.load_all_body_defs(bodies_path)
    var all_structs: Array[BodyDef] = data_loader.load_all_struct_defs(structs_path)
    var combined: Array[BodyDef] = all_bodies + all_structs

    for body in combined:
        if body == null:
            continue
        _bodies_by_id[body.id] = body
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

    if not _build_update_order():
        push_error("Solar System Model: failed to build update order. Check parent_ids.")

    _update_simulation(0.0)

    for body in combined:
        if body == null:
            continue
        _build_local_orbit_path(body)

    if verbose:
        print_current_state()


func _build_update_order() -> bool:
    _update_order.clear()

    var pending_count: Dictionary = {}
    var dependents: Dictionary = {}

    for body in _bodies_by_id.values():
        if body.parent_id == "" or not _bodies_by_id.has(body.parent_id):
            pending_count[body.id] = 0
        else:
            pending_count[body.id] = 1
            if not dependents.has(body.parent_id):
                dependents[body.parent_id] = []
            dependents[body.parent_id].append(body.id)

    var queue: Array[String] = []
    for id in pending_count:
        if pending_count[id] == 0:
            queue.append(id)

    while queue.size() > 0:
        var current_id: String = queue.pop_front()
        _update_order.append(_bodies_by_id[current_id])

        if dependents.has(current_id):
            for child_id in dependents[current_id]:
                pending_count[child_id] -= 1
                if pending_count[child_id] == 0:
                    queue.append(child_id)

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


func _update_simulation(sst_s: float) -> void:
    var next_state: Dictionary = {}

    for body in _update_order:
        if body.parent_id == "":
            next_state[body.id] = Vector2.ZERO
        else:
            next_state[body.id] = _calculate_world_position_for_body(body, sst_s, next_state)

    _current_state = next_state

    if _clock != null and _clock.is_running():
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

func _get_kepler2d_period_s(motion: Kepler2DMotionDef, parent_mu_km3_s2: float) -> float:
    if motion == null:
        return 0.0

    var a_km: float = motion.a_km
    if a_km <= 0.0 or parent_mu_km3_s2 <= 0.0:
        return 0.0

    return TAU * sqrt(pow(a_km, 3.0) / parent_mu_km3_s2)

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

func _calculate_fixed_world_position(body: BodyDef, state: Dictionary) -> Vector2:
    var motion := body.motion as FixedMotionDef
    if motion == null:
        return Vector2.ZERO

    var parent_pos: Vector2 = _get_parent_world_position(body, state)
    return Vector2(motion.x_km, motion.y_km) + parent_pos

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

func _calculate_kepler2d_world_position(body: BodyDef, sst_s: float, state: Dictionary) -> Vector2:
    var motion := body.motion as Kepler2DMotionDef
    if motion == null:
        return Vector2.ZERO

    var parent_pos: Vector2 = _get_parent_world_position(body, state)
    var parent_body: BodyDef = _bodies_by_id.get(body.parent_id, null)
    if parent_body == null:
        return parent_pos

    return parent_pos + _sample_kepler2d_local_position(motion, parent_body.mu_km3_s2, sst_s)

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

    var mu_ratio: float = secondary_body.mu_km3_s2 / max(primary_body.mu_km3_s2, 0.000001)
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

func get_all_body_ids() -> Array:
    return _bodies_by_id.keys()

func get_body(id: String) -> BodyDef:
    return _bodies_by_id.get(id, null)

func get_body_position(id: String) -> Vector2:
    return _current_state.get(id, Vector2.ZERO)

func get_body_orbit_radius_km(id: String) -> float:
    var body = _bodies_by_id.get(id, null)
    if body == null:
        return 0.0
    return _get_body_orbit_radius_km(body)

func get_body_positions_at_time(ids: Array[String], sst: float) -> Dictionary:
    if ids.is_empty():
        return {}

    var needed: Dictionary = {}
    for id in ids:
        if not _bodies_by_id.has(id):
            continue
        var current_id: String = id
        while current_id != "":
            if needed.has(current_id):
                break
            needed[current_id] = true
            var body: BodyDef = _bodies_by_id.get(current_id, null)
            if body == null:
                break
            current_id = body.parent_id

    var temp_state: Dictionary = {}
    for body in _update_order:
        if not needed.has(body.id):
            continue
        if body.parent_id == "":
            temp_state[body.id] = Vector2.ZERO
        else:
            temp_state[body.id] = _calculate_world_position_for_body(body, sst, temp_state)

    var result: Dictionary = {}
    for id in ids:
        if temp_state.has(id):
            result[id] = temp_state[id]

    return result

func get_body_position_at_time(id: String, sst: float) -> Vector2:
    var result := get_body_positions_at_time([id], sst)
    return result.get(id, Vector2.ZERO)

func get_local_orbit_path(id: String) -> Array[Vector2]:
    return _local_orbit_path_cache.get(id, [Vector2.ZERO])

func get_child_bodies(parent_id: String) -> Array[BodyDef]:
    var children: Array[BodyDef] = []

    for body in _bodies_by_id.values():
        if body == null:
            continue
        if body.parent_id == parent_id:
            children.append(body)

    return children

func get_bodies_by_type(type: String) -> Array[BodyDef]:
    var bodies: Array[BodyDef] = []

    for body in _bodies_by_id.values():
        if body == null:
            continue
        if body.type == type:
            bodies.append(body)

    return bodies

func get_children_by_type(parent_id: String, type: String) -> Array[BodyDef]:
    var children: Array[BodyDef] = []

    for body in _bodies_by_id.values():
        if body == null:
            continue
        if body.parent_id == parent_id and body.type == type:
            children.append(body)

    return children

func get_root_bodies() -> Array[BodyDef]:
    var roots: Array[BodyDef] = []

    for body in _bodies_by_id.values():
        if body == null:
            continue
        if body.parent_id == "":
            roots.append(body)

    return roots

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
