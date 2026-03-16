# res://game/ui/body_info_panel/body_info_panel.gd
#
# BodyInfoPanel
# -------------
# Zeigt BodyDef-Daten für den aktuell fokussierten Körper an.
# Wird von NavMap über show_body() / hide_panel() gesteuert.

class_name BodyInfoPanel
extends PanelContainer

signal focus_requested(body_id: String)

const PANEL_WIDTH   := 280.0
const ANIM_DURATION := 0.25
const G_KM3_KG_S2   := 6.674e-20   # Gravitationskonstante in km³/(kg·s²)
const SEC_EXPANDED  := "▼ "
const SEC_COLLAPSED := "▶ "

@onready var _label_name:          Label        = $ScrollContainer/MarginContainer/VBoxContainer/LabelName
@onready var _label_type:          Label        = $ScrollContainer/MarginContainer/VBoxContainer/LabelType

@onready var _btn_info:            Button       = $ScrollContainer/MarginContainer/VBoxContainer/BtnSectionInfo
@onready var _section_info:        VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/SectionInfo
@onready var _label_flavor:        Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionInfo/LabelFlavor

@onready var _btn_physics:         Button       = $ScrollContainer/MarginContainer/VBoxContainer/BtnSectionPhysics
@onready var _section_physics:     VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/SectionPhysics
@onready var _label_radius:        Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionPhysics/LabelRadius
@onready var _label_mass:          Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionPhysics/LabelMass
@onready var _label_density:       Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionPhysics/LabelDensity
@onready var _label_mu:            Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionPhysics/LabelMu

@onready var _btn_orbit:           Button       = $ScrollContainer/MarginContainer/VBoxContainer/BtnSectionOrbit
@onready var _section_orbit:       VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/SectionOrbit
@onready var _label_parent:        Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionOrbit/LabelParent
@onready var _label_orbit_details: Label        = $ScrollContainer/MarginContainer/VBoxContainer/SectionOrbit/LabelOrbitDetails

@onready var _btn_children:        Button       = $ScrollContainer/MarginContainer/VBoxContainer/BtnSectionChildren
@onready var _section_children:    VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/SectionChildren


func _ready() -> void:
	_btn_info.pressed.connect(func() -> void: _toggle_section(_btn_info, _section_info, "Info"))
	_btn_physics.pressed.connect(func() -> void: _toggle_section(_btn_physics, _section_physics, "Physik"))
	_btn_orbit.pressed.connect(func() -> void: _toggle_section(_btn_orbit, _section_orbit, "Orbit"))
	_btn_children.pressed.connect(func() -> void: _toggle_section(_btn_children, _section_children, "Kinder"))


func show_body(body: BodyDef) -> void:
	_populate(body)
	if visible:
		return  # Inhalt aktualisiert, Animation nicht wiederholen
	visible = true
	offset_left = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "offset_left", -PANEL_WIDTH, ANIM_DURATION)


func hide_panel() -> void:
	if not visible:
		return
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "offset_left", 0.0, ANIM_DURATION)
	tween.finished.connect(func() -> void: visible = false)


# ----------------------------------------------------------------------------------------------------------------------
# Inhalt befüllen
# ----------------------------------------------------------------------------------------------------------------------

func _populate(body: BodyDef) -> void:
	_label_name.text = body.name

	var type_str := body.type
	if body.subtype != "":
		type_str += " · " + body.subtype
	_label_type.text = type_str

	# Info-Sektion (Placeholder — Bild und Flavortext noch nicht im Datensatz)
	_label_flavor.text = "Kein Beschreibungstext vorhanden."

	# Physik-Sektion
	_label_radius.text = "Radius:    %.0f km" % body.radius_km
	_label_mu.text     = "μ:         %.3e km³/s²" % body.mu_km3_s2

	if body.mu_km3_s2 > 0.0 and body.radius_km > 0.0:
		var mass_kg       := body.mu_km3_s2 / G_KM3_KG_S2
		var vol_km3       := (4.0 / 3.0) * PI * pow(body.radius_km, 3.0)
		var density_g_cm3 := (mass_kg / vol_km3) * 1e-12   # kg/km³ → g/cm³
		_label_mass.text    = "Masse:     %.3e kg" % mass_kg
		_label_density.text = "Dichte:    %.2f g/cm³" % density_g_cm3
	else:
		_label_mass.text    = "Masse:     —"
		_label_density.text = "Dichte:    —"

	# Orbit-Sektion
	var parent_name := "—"
	if body.parent_id != "":
		parent_name = SolarSystem.get_body(body.parent_id).name
	_label_parent.text        = "Elternkörper: " + parent_name
	_label_orbit_details.text = _format_motion(body.motion)

	# Kinder-Sektion
	_populate_children(body.id)


func _populate_children(body_id: String) -> void:
	for child in _section_children.get_children():
		child.queue_free()

	var children := SolarSystem.get_child_bodies(body_id)
	if children.is_empty():
		var lbl := Label.new()
		lbl.text = "Keine Kinder"
		_section_children.add_child(lbl)
		return

	for child_body: BodyDef in children:
		var btn := Button.new()
		btn.text = child_body.name
		var cid  := child_body.id
		btn.pressed.connect(func() -> void: focus_requested.emit(cid))
		_section_children.add_child(btn)


# ----------------------------------------------------------------------------------------------------------------------
# Sektionen ein-/ausklappen
# ----------------------------------------------------------------------------------------------------------------------

func _toggle_section(btn: Button, section: Control, label: String) -> void:
	section.visible = not section.visible
	btn.text = (SEC_EXPANDED if section.visible else SEC_COLLAPSED) + label


# ----------------------------------------------------------------------------------------------------------------------
# Hilfsfunktionen
# ----------------------------------------------------------------------------------------------------------------------

func _format_motion(motion: BaseMotionDef) -> String:
	if not motion:
		return "Kein Bahnmodell"
	match motion.model:
		"circular":
			var m := motion as CircularMotionDef
			return "Kreisbahn\nRadius:    %.0f km\nPeriode:   %s" % [
				m.orbital_radius_km, _format_period(m.period_s)]
		"kepler2d":
			var m := motion as Kepler2DMotionDef
			return "Kepler-Ellipse\nHalbachse: %.3e km\nExz.:      %.4f" % [m.a_km, m.e]
		"fixed":
			return "Fixierte Position"
		"lagrange":
			var m := motion as LagrangeMotionDef
			var prim := SolarSystem.get_body(m.primary_id).name
			var sec  := SolarSystem.get_body(m.secondary_id).name
			return "Lagrange L%d\n%s / %s" % [m.point, prim, sec]
	return "Unbekannt"


func _format_period(period_s: float) -> String:
	var days := period_s / 86400.0
	if days >= 360.0:
		return "%.1f Jahre" % (days / 360.0)
	if days >= 1.0:
		return "%.1f Tage" % days
	return "%.1f Std" % (period_s / 3600.0)
