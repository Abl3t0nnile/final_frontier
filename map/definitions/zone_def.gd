## ZoneDef
## Datendefinition für halbtransparente Farbflächen (Magnetosphären, Habitzone etc.).
## Visuelle Map-Daten – nicht Teil des Core/Simulation-Layers.

class_name ZoneDef
extends Resource

@export var id: String = ""
@export var name: String = ""

@export var parent_id: String = ""
@export var zone_type: String = ""

## "circle" = gefüllter Kreis, "ring" = Hohlring
@export var geometry: String = "circle"

@export var radius_km: float = 0.0

@export var inner_radius_km: float = 0.0
@export var outer_radius_km: float = 0.0

@export var color_rgba: Color = Color(0.5, 0.5, 1.0, 0.1)
@export var border_color_rgba: Color = Color(0.5, 0.5, 1.0, 0.4)
