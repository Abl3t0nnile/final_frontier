## InfoPanel
## Zeigt Basisinformationen zum fokussierten Body (Name, Type, Subtype,
## physikalische und orbitale Daten).

class_name InfoPanel
extends PanelContainer

const _TEXTURE_BASE := "res://assets/textures/planets_16_levels/"

## body_id → { "surface": filename, "cloud": filename (optional) }
const _BODY_TEXTURES: Dictionary = {
	"sun":      { "surface": "2k_sun.png" },
	"mercury":  { "surface": "2k_mercury.png" },
	"venus":    { "surface": "black_surface.png", "cloud": "2k_venus_atmosphere.png" },
	"terra":    { "surface": "2k_earth_daymap.png",  "cloud": "2k_earth_clouds.png" },
	"mars":     { "surface": "2k_mars.png" },
	"jupiter":  { "surface": "black_surface.png", "cloud": "2k_jupiter.png" },
	"saturn":   { "surface": "black_surface.png", "cloud": "2k_saturn.png" },
	"uranus":   { "surface": "black_surface.png", "cloud": "2k_uranus.png" },
	"neptune":  { "surface": "black_surface.png", "cloud": "2k_neptune.png" },
	"moon":     { "surface": "2k_moon.png" },
	"ceres":    { "surface": "2k_ceres.png" },
	"eris":     { "surface": "2k_eris.png" },
	"haumea":   { "surface": "2k_haumea.png" },
	"makemake": { "surface": "2k_makemake.png" },
}

@onready var _name_label:    Label = $VBox/Header/NameDisplay/NameLabel
@onready var _type_label:    Label = $VBox/Header/NameDisplay/HBoxContainer/TypeLabel
@onready var _subtype_label: Label = $VBox/Header/NameDisplay/HBoxContainer/SubtypeLabel
@onready var _planet_viewer:  PlanetViewer = $VBox/Image/SubViewport/PlanetViewer
@onready var _missing_label:  Label        = $VBox/Image/SubViewport/MissingLabel

## Physikalische Felder
@onready var _phys_radius:   Node = $VBox/PhysikSection/PhysikGrid/Radius
@onready var _phys_mass:     Node = $VBox/PhysikSection/PhysikGrid/Masse
@onready var _phys_density:  Node = $VBox/PhysikSection/PhysikGrid/Dichte
@onready var _phys_gravity:  Node = $VBox/PhysikSection/PhysikGrid/Schwerkraft
@onready var _phys_escape:   Node = $VBox/PhysikSection/PhysikGrid/Fluchtgeschw

## Orbitale Felder
@onready var _orb_axis:      Node = $VBox/OrbitSection/OrbitGrid/Halbachse
@onready var _orb_period:    Node = $VBox/OrbitSection/OrbitGrid/Umlaufzeit
@onready var _orb_ecc:       Node = $VBox/OrbitSection/OrbitGrid/Exzentrizitaet
@onready var _orb_peri:      Node = $VBox/OrbitSection/OrbitGrid/Periapsis
@onready var _orb_apo:       Node = $VBox/OrbitSection/OrbitGrid/Apoapsis
@onready var _orb_vel:       Node = $VBox/OrbitSection/OrbitGrid/Geschwindigkeit



func load_body(id: String) -> void:
	var def: BodyDef = SolarSystem.get_body(id)
	_setup_planet_viewer(id)
	if def == null:
		_name_label.text    = id
		_type_label.text    = ""
		_subtype_label.text = ""
		_clear_data()
		return
	_name_label.text    = def.name
	_type_label.text    = def.type
	_subtype_label.text = def.subtype
	_display_physical_data(def)
	_display_orbital_data(def)


func _setup_planet_viewer(id: String) -> void:
	var entry: Dictionary = _BODY_TEXTURES.get(id, {})
	var has_texture := not entry.is_empty()
	_planet_viewer.visible = has_texture
	_missing_label.visible = not has_texture
	if not has_texture:
		return
	_planet_viewer.use_sun_shader = (id == "sun")
	var surface_path: String = _TEXTURE_BASE + entry.get("surface", "black_surface.png")
	_planet_viewer.surface_texture = load(surface_path) as Texture2D
	if entry.has("cloud"):
		_planet_viewer.cloud_texture = load(_TEXTURE_BASE + entry["cloud"]) as Texture2D
		_planet_viewer.cloud_enabled = true
	else:
		_planet_viewer.cloud_texture = null
		_planet_viewer.cloud_enabled = false


func clear() -> void:
	_name_label.text    = ""
	_type_label.text    = ""
	_subtype_label.text = ""
	_clear_data()


# ── Private ───────────────────────────────────────────────────────────────────

func _display_physical_data(def: BodyDef) -> void:
	var r  := def.body_radius_km
	var mu := def.grav_param_km3_s2
	_phys_radius.setup( "Radius",      "%.1f"  % r,                                         "km")
	_phys_mass.setup(   "Masse",       _format_mass(SpaceMath.body_mass_kg(mu)),             "kg")
	_phys_density.setup("Dichte",      _fmt_or_dash(SpaceMath.body_density_g_cm3(mu, r), 2), "g/cm³")
	_phys_gravity.setup("Schwerkraft", _fmt_or_dash(SpaceMath.surface_gravity_ms2(mu, r), 2),"m/s²")
	_phys_escape.setup( "Fluchtgeschw",_fmt_or_dash(SpaceMath.escape_velocity_km_s(mu, r), 2),  "km/s")


func _display_orbital_data(def: BodyDef) -> void:
	if not def.has_motion():
		_orb_axis.setup(   "Halbachse",    "—", "")
		_orb_period.setup( "Umlaufzeit",   "—", "")
		_orb_ecc.setup(    "Exzentrizität","—", "")
		_orb_peri.setup(   "Periapsis",    "—", "")
		_orb_apo.setup(    "Apoapsis",     "—", "")
		_orb_vel.setup(    "Ø Geschw.",    "—", "")
		return

	var motion := def.motion

	match motion.model:
		"kepler2d":
			var km := (motion as Kepler2DMotionDef)
			var a     := km.semi_major_axis_km
			var e     := km.eccentricity
			var parent_mu := _get_parent_mu(def.parent_id)
			var period_s  := SpaceMath.get_kepler_period(a, parent_mu)
			var vel       := SpaceMath.mean_orbital_velocity_km_s(a, period_s)
			_orb_axis.setup(   "Halbachse",    "%.4f" % SpaceMath.km_to_au(a),                            "AU")
			_orb_period.setup( "Umlaufzeit",   _format_period(period_s),                                  "")
			_orb_ecc.setup(    "Exzentrizität","%.4f" % e,                                                 "")
			_orb_peri.setup(   "Periapsis",    "%.4f" % SpaceMath.km_to_au(SpaceMath.orbit_periapsis_km(a, e)), "AU")
			_orb_apo.setup(    "Apoapsis",     "%.4f" % SpaceMath.km_to_au(SpaceMath.orbit_apoapsis_km(a, e)),  "AU")
			_orb_vel.setup(    "Ø Geschw.",    _fmt_or_dash(vel, 2),                                       "km/s")

		"circular":
			var cm := (motion as CircularMotionDef)
			var r      := cm.orbital_radius_km
			var period_s := cm.orbital_period_s
			var vel    := SpaceMath.mean_orbital_velocity_km_s(r, period_s)
			_orb_axis.setup(   "Bahnradius",   "%.4f" % SpaceMath.km_to_au(r), "AU")
			_orb_period.setup( "Umlaufzeit",   _format_period(period_s),       "")
			_orb_ecc.setup(    "Exzentrizität","0",                             "")
			_orb_peri.setup(   "Periapsis",    "—",                            "")
			_orb_apo.setup(    "Apoapsis",     "—",                            "")
			_orb_vel.setup(    "Ø Geschw.",    _fmt_or_dash(vel, 2),           "km/s")

		_:
			_orb_axis.setup(   "Halbachse",    "—", "")
			_orb_period.setup( "Umlaufzeit",   "—", "")
			_orb_ecc.setup(    "Exzentrizität","—", "")
			_orb_peri.setup(   "Periapsis",    "—", "")
			_orb_apo.setup(    "Apoapsis",     "—", "")
			_orb_vel.setup(    "Ø Geschw.",    "—", "")


func _clear_data() -> void:
	for field: Node in [
		_phys_radius, _phys_mass, _phys_density, _phys_gravity, _phys_escape,
		_orb_axis, _orb_period, _orb_ecc, _orb_peri, _orb_apo, _orb_vel
	]:
		field.setup("", "—", "")


func _get_parent_mu(parent_id: String) -> float:
	if parent_id.is_empty():
		return 0.0
	var parent: BodyDef = SolarSystem.get_body(parent_id)
	return parent.grav_param_km3_s2 if parent else 0.0


func _fmt_or_dash(value: float, decimals: int) -> String:
	if is_zero_approx(value):
		return "—"
	return "%.*f" % [decimals, value]


func _format_mass(kg: float) -> String:
	if kg <= 0.0:
		return "—"
	var magnitude := floori(log(kg) / log(10.0))
	var mantissa := kg / pow(10.0, float(magnitude))
	return "%.3f e%d" % [mantissa, magnitude]


func _format_period(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var days := seconds / 86400.0
	if days >= 365.25:
		return "%.2f a" % (days / 365.25)
	return "%.1f d" % days
