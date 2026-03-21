# BeltDef — Datendefinition für prozedurale Gürtel-Darstellungen.
# Beschreibt Asteroiden-, Kuipergürtel, Trojaner und Planetenringe.
# Wird vom BeltRenderer genutzt um eine deterministische Punktwolke zu erzeugen.
class_name BeltDef

extends Resource

# Eindeutige ID und Anzeigename.
@export var id: String = ""
@export var name: String = ""

# ID des übergeordneten Körpers (z.B. "sun" für den Asteroidengürtel).
@export var parent_id: String = ""

# Referenzkörper für winkelabhängige Gürtel wie Trojaner (L4/L5).
# Leer = kein Referenzkörper (vollständiger Gürtel).
@export var reference_body_id: String = ""

# Radiale Ausdehnung des Gürtels in km.
@export var inner_radius_km: float = 0.0
@export var outer_radius_km: float = 0.0

# Winkelbereich des Gürtels in Radiant.
# angular_offset_rad: Startwinkel (0 = positive X-Achse).
# angular_spread_rad: Gesamtbreite (TAU = vollständiger Ring).
@export var angular_offset_rad: float = 0.0
@export var angular_spread_rad: float = TAU

# Punktanzahl für LOD. BeltRenderer interpoliert zwischen min und max.
@export var min_points: int = 200
@export var max_points: int = 1000

# Seed für den Pseudo-Zufallsgenerator. Gleicher Seed = identische Punktwolke.
@export var rng_seed: int = 0

# Darstellungsfarbe inklusive Alpha.
@export var color_rgba: Color = Color(0.8, 0.7, 0.6, 0.6)

# Deaktivieren für Trojaner: Layer-Rotation würde die Wolke aus der L4/L5-Position driften lassen.
@export var apply_rotation: bool = true
