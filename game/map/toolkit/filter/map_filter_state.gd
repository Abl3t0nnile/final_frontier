class_name MapFilterState extends Node

signal filter_changed

# ─── Bodies: Type-Toggles ─────────────────────────────────────────────────
# Hierarchisch: Type aus → alle Subtypes dieses Types auch aus.

@export var show_stars: bool = true
@export var show_planets: bool = true
@export var show_dwarfs: bool = true
@export var show_moons: bool = true
@export var show_structs: bool = true

# ─── Bodies: Subtype-Toggles ──────────────────────────────────────────────
# Nur relevant wenn der Parent-Type aktiv ist.

# star subtypes
@export var show_g_type: bool = true

# planet subtypes
@export var show_terrestrial: bool = true
@export var show_gas_giant: bool = true
@export var show_ice_giant: bool = true
@export var show_sub_neptune: bool = true

# dwarf subtypes
@export var show_asteroid_dwarf: bool = true
@export var show_plutoid: bool = true

# moon subtypes
@export var show_major_moon: bool = true
@export var show_minor_moon: bool = true

# struct subtypes
@export var show_station: bool = true
@export var show_shipyard: bool = true
@export var show_outpost: bool = true
@export var show_relay: bool = true
@export var show_navigation_point: bool = true

# ─── Orbits: per Parent-Type ──────────────────────────────────────────────

@export var show_planet_orbits: bool = true
@export var show_dwarf_orbits: bool = true
@export var show_moon_orbits: bool = true
@export var show_struct_orbits: bool = true

# ─── Zones: per Zone-Type ────────────────────────────────────────────────

@export var show_region_zones: bool = true
@export var show_radiation_zones: bool = true
@export var show_magnetic_zones: bool = true
@export var show_gravity_zones: bool = true
@export var show_habitable_zones: bool = true

# ─── Belts ────────────────────────────────────────────────────────────────

@export var show_asteroid_belt: bool = true
@export var show_kuiper_belt: bool = true

# ─── Query-Methoden ───────────────────────────────────────────────────────

func is_body_visible(type: String, subtype: String) -> bool:
	match type:
		"star":
			if not show_stars:
				return false
			match subtype:
				"g_type": return show_g_type
				_: return true
		"planet":
			if not show_planets:
				return false
			match subtype:
				"terrestrial": return show_terrestrial
				"gas_giant": return show_gas_giant
				"ice_giant": return show_ice_giant
				"sub_neptune": return show_sub_neptune
				_: return true
		"dwarf":
			if not show_dwarfs:
				return false
			match subtype:
				"asteroid_dwarf": return show_asteroid_dwarf
				"plutoid": return show_plutoid
				_: return true
		"moon":
			if not show_moons:
				return false
			match subtype:
				"major_moon": return show_major_moon
				"minor_moon": return show_minor_moon
				_: return true
		"struct":
			if not show_structs:
				return false
			match subtype:
				"station": return show_station
				"shipyard": return show_shipyard
				"outpost": return show_outpost
				"relay": return show_relay
				"navigation_point": return show_navigation_point
				_: return true
	return true


func is_orbit_visible(parent_type: String) -> bool:
	match parent_type:
		"planet": return show_planet_orbits
		"dwarf": return show_dwarf_orbits
		"moon": return show_moon_orbits
		"struct": return show_struct_orbits
	return true


func is_zone_visible(zone_type: String) -> bool:
	match zone_type:
		"region": return show_region_zones
		"radiation": return show_radiation_zones
		"magnetic": return show_magnetic_zones
		"gravity": return show_gravity_zones
		"habitable": return show_habitable_zones
	return true


func is_belt_visible(belt_id: String) -> bool:
	match belt_id:
		"asteroid_belt": return show_asteroid_belt
		"kuiper_belt": return show_kuiper_belt
	return true

# ─── Setter-Methoden (für UI) ─────────────────────────────────────────────

func set_type_enabled(type: String, enabled: bool) -> void:
	match type:
		"star": show_stars = enabled
		"planet": show_planets = enabled
		"dwarf": show_dwarfs = enabled
		"moon": show_moons = enabled
		"struct": show_structs = enabled
	filter_changed.emit()


func set_subtype_enabled(subtype: String, enabled: bool) -> void:
	match subtype:
		"g_type": show_g_type = enabled
		"terrestrial": show_terrestrial = enabled
		"gas_giant": show_gas_giant = enabled
		"ice_giant": show_ice_giant = enabled
		"sub_neptune": show_sub_neptune = enabled
		"asteroid_dwarf": show_asteroid_dwarf = enabled
		"plutoid": show_plutoid = enabled
		"major_moon": show_major_moon = enabled
		"minor_moon": show_minor_moon = enabled
		"station": show_station = enabled
		"shipyard": show_shipyard = enabled
		"outpost": show_outpost = enabled
		"relay": show_relay = enabled
		"navigation_point": show_navigation_point = enabled
	filter_changed.emit()


func set_orbit_enabled(parent_type: String, enabled: bool) -> void:
	match parent_type:
		"planet": show_planet_orbits = enabled
		"dwarf": show_dwarf_orbits = enabled
		"moon": show_moon_orbits = enabled
		"struct": show_struct_orbits = enabled
	filter_changed.emit()


func set_zone_type_enabled(zone_type: String, enabled: bool) -> void:
	match zone_type:
		"radiation": show_radiation_zones = enabled
		"magnetic": show_magnetic_zones = enabled
		"gravity": show_gravity_zones = enabled
		"habitable": show_habitable_zones = enabled
	filter_changed.emit()


func set_belt_enabled(belt_id: String, enabled: bool) -> void:
	match belt_id:
		"asteroid_belt": show_asteroid_belt = enabled
		"kuiper_belt": show_kuiper_belt = enabled
	filter_changed.emit()
