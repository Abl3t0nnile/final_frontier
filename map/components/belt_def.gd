## BeltDef
## Data definition for procedural belt representations (asteroids, trojans, rings).
## Visual map data - not part of the Core/Simulation layer.

class_name BeltDef
extends Resource

@export var id: String = ""
@export var name: String = ""

@export var parent_id: String = ""
@export var reference_body_id: String = ""

@export var inner_radius_km: float = 0.0
@export var outer_radius_km: float = 0.0

@export var angular_offset_rad: float = 0.0
@export var angular_spread_rad: float = TAU

@export var min_points: int = 200
@export var max_points: int = 1000

@export var rng_seed: int = 0

@export var color_rgba: Color = Color(0.8, 0.7, 0.6, 0.6)

@export var apply_rotation: bool = true
