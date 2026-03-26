extends PanelContainer

const _AU_KM := 149_597_870.7
const _S_PER_DAY := 86_400.0

# Header
@onready var _type_label: Label = $MarginContainer/Body/Header/TypeDisplay/Label
@onready var _subtype_label: Label = $MarginContainer/Body/Header/TypeDisplay/Label2
@onready var _name_label: Label = $MarginContainer/Body/Header/NameLabel

var _model: SolarSystemModel = null

# Sub-panels
@onready var _data_panel: Control = $MarginContainer/Body/Data
@onready var _info_panel: Control = $MarginContainer/Body/Info
@onready var _satelites_panel: Control = $MarginContainer/Body/Satelites

@onready var _data_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/DataBtn
@onready var _info_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/InfoBtn
@onready var _satelites_panel_btn: Button = $MarginContainer/Body/SubPanelSelector/SatelitesBtn

# Orbit data points
@onready var _dp_aphelion: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay7
@onready var _dp_parent: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay10
@onready var _dp_perihelion: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay11
@onready var _dp_period: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay12
@onready var _dp_semi_major_axis: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay13
@onready var _dp_eccentricity: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay15
@onready var _dp_avg_orbital_speed: Control = $MarginContainer/Body/Data/OrbitDataPoints/DataPointDisplay16

# Physics data points
@onready var _dp_radius: Control = $MarginContainer/Body/Data/OrbitDataPoints2/DataPointDisplay
@onready var _dp_gravity: Control = $MarginContainer/Body/Data/OrbitDataPoints2/DataPointDisplay3


func _ready() -> void:
	_data_panel_btn.toggled.connect(_on_data_panel_btn_toggled)
	_info_panel_btn.toggled.connect(_on_info_panel_btn_toggled)
	_satelites_panel_btn.toggled.connect(_on_satelites_panel_btn_toggled)


func set_text_color(color: Color) -> void:
	for label: Label in _collect_labels(self):
		label.add_theme_color_override("font_color", color)
	for btn: Button in [_data_panel_btn, _info_panel_btn, _satelites_panel_btn]:
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
		btn.add_theme_color_override("font_hover_color", color)


func _collect_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			result.append(child)
		result.append_array(_collect_labels(child))
	return result


func setup(model: SolarSystemModel) -> void:
	_model = model


# Lädt alle verfügbaren Daten des Körpers mit der gegebenen ID ins Panel.
# Felder ohne Daten werden nicht verändert.
func load_body(body_id: String) -> void:
	if _model == null:
		return
	var body: BodyDef = _model.get_body(body_id)
	if body == null:
		return

	# Header
	if not body.name.is_empty():
		_name_label.text = body.name
	if not body.type.is_empty():
		_type_label.text = body.type.to_upper()
	if not body.subtype.is_empty():
		_subtype_label.text = body.subtype.to_upper()

	# Parent
	if not body.parent_id.is_empty():
		var parent: BodyDef = _model.get_body(body.parent_id)
		if parent != null:
			_dp_parent.set_value(parent.name)

	# Physics
	if body.radius_km > 0.0:
		_dp_radius.set_value("%.1f km" % body.radius_km)
		if body.mu_km3_s2 > 0.0:
			var g_ms2 := (body.mu_km3_s2 / (body.radius_km * body.radius_km)) * 1000.0
			_dp_gravity.set_value("%.2f m/s²" % g_ms2)

	# Orbit
	if body.has_motion():
		_load_orbit_data(body)


func _load_orbit_data(body: BodyDef) -> void:
	match body.motion.model:
		"kepler2d":
			var m := body.motion as Kepler2DMotionDef
			var e := m.e
			_dp_semi_major_axis.set_value("%.4f AU" % (m.a_km / _AU_KM))
			_dp_eccentricity.set_value("%.4f" % e)
			_dp_aphelion.set_value("%.4f AU" % (m.a_km * (1.0 + e) / _AU_KM))
			_dp_perihelion.set_value("%.4f AU" % (m.a_km * (1.0 - e) / _AU_KM))
			var parent: BodyDef = _model.get_body(body.parent_id)
			if parent != null and parent.mu_km3_s2 > 0.0 and m.a_km > 0.0:
				var period_s := TAU * sqrt(pow(m.a_km, 3.0) / parent.mu_km3_s2)
				_dp_period.set_value("%.1f d" % (period_s / _S_PER_DAY))
				_dp_avg_orbital_speed.set_value("%.2f km/s" % (TAU * m.a_km / period_s))

		"circular":
			var m := body.motion as CircularMotionDef
			var r_au := m.orbital_radius_km / _AU_KM
			_dp_semi_major_axis.set_value("%.4f AU" % r_au)
			_dp_eccentricity.set_value("0.0000")
			_dp_aphelion.set_value("%.4f AU" % r_au)
			_dp_perihelion.set_value("%.4f AU" % r_au)
			if m.period_s > 0.0:
				_dp_period.set_value("%.1f d" % (m.period_s / _S_PER_DAY))
				_dp_avg_orbital_speed.set_value("%.2f km/s" % (TAU * m.orbital_radius_km / m.period_s))


func _on_data_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_data_panel.show()
	else:
		_data_panel.hide()

func _on_info_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_info_panel.show()
	else:
		_info_panel.hide()

func _on_satelites_panel_btn_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_satelites_panel.show()
	else:
		_satelites_panel.hide()
