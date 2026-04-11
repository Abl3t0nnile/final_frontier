## InfoPanel
## Zeigt Basisinformationen zum fokussierten Body (Name, Type, Subtype,
## physikalische und orbitale Daten).

class_name InfoPanel
extends PanelContainer

signal almanach_requested(body_id: String)
signal zoom_requested(body_id: String)
signal pin_requested(body_id: String)
signal unpin_requested(body_id: String)


@onready var _name_label:    Label = $MarginContainer/VBox/Header/NameDisplay/NameLabel
@onready var _type_label:    Label = $MarginContainer/VBox/Header/NameDisplay/HBoxContainer/TypeLabel
@onready var _subtype_label: Label = $MarginContainer/VBox/Header/NameDisplay/HBoxContainer/SubtypeLabel
@onready var _planet_viewer:  PlanetViewer = $MarginContainer/VBox/Image/SubViewport/PlanetViewer
@onready var _missing_label:  Label        = $MarginContainer/VBox/Image/SubViewport/MissingLabel
@onready var _almanach_btn:   Button = $MarginContainer/VBox/Header/AlmanachBtn
@onready var _pin_btn:        Button = $MarginContainer/VBox/Header/PinBtn
@onready var _unpin_btn:      Button = $MarginContainer/VBox/Header/UnpinBtn
@onready var _zoom_btn:       Button = $MarginContainer/VBox/Header/ZoomBtn

var _current_id: String = ""

## Physikalische Felder
@onready var _phys_radius:   Node = $MarginContainer/VBox/PhysikSection/PhysikGrid/Radius
@onready var _phys_mass:     Node = $MarginContainer/VBox/PhysikSection/PhysikGrid/Masse
@onready var _phys_density:  Node = $MarginContainer/VBox/PhysikSection/PhysikGrid/Dichte
@onready var _phys_gravity:  Node = $MarginContainer/VBox/PhysikSection/PhysikGrid/Schwerkraft
@onready var _phys_escape:   Node = $MarginContainer/VBox/PhysikSection/PhysikGrid/Fluchtgeschw

## Orbitale Felder
@onready var _orb_axis:      Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Halbachse
@onready var _orb_period:    Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Umlaufzeit
@onready var _orb_ecc:       Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Exzentrizitaet
@onready var _orb_peri:      Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Periapsis
@onready var _orb_apo:       Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Apoapsis
@onready var _orb_vel:       Node = $MarginContainer/VBox/OrbitSection/OrbitGrid/Geschwindigkeit



func _ready() -> void:
	_almanach_btn.pressed.connect(func() -> void: almanach_requested.emit(_current_id))
	_pin_btn.pressed.connect(func() -> void: pin_requested.emit(_current_id))
	_unpin_btn.pressed.connect(func() -> void: unpin_requested.emit(_current_id))
	_zoom_btn.pressed.connect(func() -> void: zoom_requested.emit(_current_id))


func set_pinned(pinned: bool) -> void:
	_pin_btn.visible   = not pinned
	_unpin_btn.visible = pinned


func load_body(id: String) -> void:
	_current_id = id
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
	var found := _planet_viewer.load_body(id)
	_planet_viewer.visible = found
	_missing_label.visible = not found


func clear() -> void:
	_name_label.text    = ""
	_type_label.text    = ""
	_subtype_label.text = ""
	_clear_data()


# ── Private ───────────────────────────────────────────────────────────────────

func _display_physical_data(def: BodyDef) -> void:
	var r  := def.body_radius_km
	var mu := def.grav_param_km3_s2
	_phys_radius.setup( "Radius",      "%.1f"  % r,                        "km")
	_phys_mass.setup_auto(   "Masse",       SpaceMath.body_mass_kg(mu),          UnitValueDisplay.UnitType.MASS)
	_phys_density.setup_auto("Dichte",      SpaceMath.body_density_g_cm3(mu, r), UnitValueDisplay.UnitType.DENSITY)
	_phys_gravity.setup_auto("Schwerkraft", SpaceMath.surface_gravity_ms2(mu, r),UnitValueDisplay.UnitType.ACCELERATION)
	_phys_escape.setup_auto( "Fluchtgeschw",SpaceMath.escape_velocity_km_s(mu, r),UnitValueDisplay.UnitType.VELOCITY)


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
			_orb_axis.setup_auto(   "Halbachse",    a,                                  UnitValueDisplay.UnitType.DISTANCE)
			_orb_period.setup_auto( "Umlaufzeit",   period_s,                           UnitValueDisplay.UnitType.PERIOD)
			_orb_ecc.setup_auto(    "Exzentrizität",e,                                   UnitValueDisplay.UnitType.DIMENSIONLESS)
			_orb_peri.setup_auto(   "Periapsis",    SpaceMath.orbit_periapsis_km(a, e), UnitValueDisplay.UnitType.DISTANCE)
			_orb_apo.setup_auto(    "Apoapsis",     SpaceMath.orbit_apoapsis_km(a, e),  UnitValueDisplay.UnitType.DISTANCE)
			_orb_vel.setup_auto(    "Ø Geschw.",    vel,                                UnitValueDisplay.UnitType.VELOCITY)

		"circular":
			var cm := (motion as CircularMotionDef)
			var r      := cm.orbital_radius_km
			var period_s := cm.orbital_period_s
			var vel    := SpaceMath.mean_orbital_velocity_km_s(r, period_s)
			_orb_axis.setup_auto(   "Bahnradius",   r,         UnitValueDisplay.UnitType.DISTANCE)
			_orb_period.setup_auto( "Umlaufzeit",   period_s,  UnitValueDisplay.UnitType.PERIOD)
			_orb_ecc.setup_auto(    "Exzentrizität",0.0,       UnitValueDisplay.UnitType.DIMENSIONLESS)
			_orb_peri.setup(   "Periapsis",    "—",       "")
			_orb_apo.setup(    "Apoapsis",     "—",       "")
			_orb_vel.setup_auto(    "Ø Geschw.",    vel,       UnitValueDisplay.UnitType.VELOCITY)

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
