# ZoneDef — Datendefinition für halbtransparente Farbflächen.
# Beschreibt Strahlungsgürtel, Magnetosphären, Gravitationszonen etc.
# Wird vom ZoneRenderer genutzt um Kreise oder Ringe zu zeichnen.
class_name ZoneDef

extends Resource

# Eindeutige ID und Anzeigename.
@export var id: String = ""
@export var name: String = ""

# ID des übergeordneten Körpers (Mittelpunkt der Zone).
@export var parent_id: String = ""

# Semantischer Typ der Zone (z.B. "radiation", "magnetic", "gravity").
@export var zone_type: String = ""

# Geometrie: "circle" (gefüllter Kreis) oder "ring" (Hohlring).
@export var geometry: String = "circle"

# Radius für geometry = "circle".
@export var radius_km: float = 0.0

# Innen- und Außenradius für geometry = "ring".
@export var inner_radius_km: float = 0.0
@export var outer_radius_km: float = 0.0

# Füllfarbe der Fläche (mit Alpha für Transparenz).
@export var color_rgba: Color = Color(0.5, 0.5, 1.0, 0.1)

# Randfarbe für den Umriss.
@export var border_color_rgba: Color = Color(0.5, 0.5, 1.0, 0.4)
