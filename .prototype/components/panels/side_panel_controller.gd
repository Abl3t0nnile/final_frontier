extends VBoxContainer

signal select_body(body_id: String)

const _AU_KM := 149_597_870.7
const _S_PER_DAY := 86_400.0

# Header
@onready var _name_label: Label = $NamePanel/HBoxContainer/NameLabel
@onready var _type_label: Label = $NamePanel/HBoxContainer/NameLabel3

# Sub-panels
@onready var _data_panel: Control = $DataPanel
@onready var _info_panel: Control = $InfoPanel
@onready var _sat_panel: Control = $SatPanel
@onready var _orbit_data_panel: VBoxContainer = $DataPanel/OrbitData

# Buttons
@onready var _data_btn: Button = $SubPanelSelector/DataBtn
@onready var _info_btn: Button = $SubPanelSelector/InfoBtn
@onready var _sat_btn: Button = $SubPanelSelector/SatBtn
@onready var _zoom_btn: Button = $MapBtns/ZoomBtn

# Orbit Data
@onready var _dp_aphelion: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay
@onready var _parent_display = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ParentDisplay
@onready var _dp_perihelion: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay3
@onready var _dp_period: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay4
@onready var _dp_semi_major: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay5
@onready var _dp_avg_speed: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay6
@onready var _dp_eccentricity: ValueUnitDisplay = $DataPanel/OrbitData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay7

# Physics Data
@onready var _dp_radius: ValueUnitDisplay = $DataPanel/PhysicsData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay
@onready var _dp_mass: ValueUnitDisplay = $DataPanel/PhysicsData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay2
@onready var _dp_gravity: ValueUnitDisplay = $DataPanel/PhysicsData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay3
@onready var _dp_density: ValueUnitDisplay = $DataPanel/PhysicsData/PanelContainer3/MarginContainer/VBoxContainer/ValueDisplay4

# Satellites
@onready var _moon_container: VBoxContainer = $SatPanel/MoonSatelites/MoonPanel/MarginContainer/ScrollContainer/VBoxContainer
@onready var _moon_label: Label = $SatPanel/MoonSatelites/PanelContainer/NameLabel
@onready var _moon_panel: VBoxContainer = $SatPanel/MoonSatelites
@onready var _struct_container: VBoxContainer = $SatPanel/StructSatelites/StructPanel/MarginContainer/ScrollContainer/VBoxContainer
@onready var _struct_panel: VBoxContainer = $SatPanel/StructSatelites
@onready var _satelite_btn_scene: PackedScene = preload("res://ui/components/buttons/satelite_btn.tscn")

var _model: SolarSystemModel = null
var _map_viewer: MapController = null


func _ready() -> void:
	_data_btn.toggled.connect(_on_data_panel_btn_toggled)
	_info_btn.toggled.connect(_on_info_panel_btn_toggled)
	_sat_btn.toggled.connect(_on_sat_panel_btn_toggled)
	
	# ParentDisplay Signal verbinden
	if _parent_display.has_signal("select_body"):
		_parent_display.select_body.connect(_on_body_button_clicked)
	
	# Start mit Data-Panel
	_data_btn.button_pressed = true
	_show_panel(_data_panel)


func setup(model: SolarSystemModel) -> void:
	_model = model


func set_map_viewer(map_viewer: MapController) -> void:
	_map_viewer = map_viewer
	# Zoom-Button verbinden
	_zoom_btn.pressed.connect(_on_zoom_btn_pressed)


func _on_zoom_btn_pressed() -> void:
	if _map_viewer != null:
		_map_viewer.zoom_to_selected_body_children()


func load_body(body_id: String) -> void:
	var body: BodyDef = _model.get_body(body_id)
	if body == null:
		return
	
	# Immer zum Data-Tab wechseln bei Body-Auswahl
	_data_btn.button_pressed = true
	_show_panel(_data_panel)
	
	# Infos laden
	_name_label.text = ""
	_type_label.text = ""
	if not body.name.is_empty():
		_name_label.text = body.name
	if not body.subtype.is_empty():
		_type_label.text = body.subtype.to_upper()
	
	# Daten laden
	_load_data_panel(body)
	
	# Sateliten laden
	_load_satellites(body_id)


func _load_satellites(body_id: String) -> void:
	# Alte Sateliten-Buttons entfernen
	for child in _moon_container.get_children():
		child.queue_free()
	for child in _struct_container.get_children():
		child.queue_free()
	
	# Zähler für Satelliten-Typen
	var moon_count = 0
	var struct_count = 0
	
	# Label je nach Parent-Typ anpassen
	var parent: BodyDef = _model.get_body(body_id)
	if parent != null and parent.type == "star":
		_moon_label.text = "PLANETS"
	else:
		_moon_label.text = "MOONS"
	
	# Sateliten finden und hinzufügen
	for child_id: String in _model.get_all_body_ids():
		var child: BodyDef = _model.get_body(child_id)
		if child != null and child.parent_id == body_id:
			var btn: PanelContainer = _satelite_btn_scene.instantiate()
			btn.setup(child)
			btn.select_body.connect(_on_body_button_clicked)
			
			# Je nach Typ dem richtigen Container hinzufügen
			# Wenn der Parent eine Sonne ist, zeigen wir Planeten im "Moon"-Container an
			if child.type == "moon" or (child.type == "planet" and parent.type == "star"):
				_moon_container.add_child(btn)
				moon_count += 1
			elif child.type == "struct":
				_struct_container.add_child(btn)
				struct_count += 1
	
	# Panel ein-/ausblenden je nach Inhalt
	_moon_panel.visible = (moon_count > 0)
	_struct_panel.visible = (struct_count > 0)
	
	# Sat-Tab deaktivieren wenn keine Satelliten vorhanden
	_sat_btn.disabled = (moon_count == 0 and struct_count == 0)
	
	# Wenn Sat-Tab deaktiviert ist und dieser aktiv war, zum Data-Tab wechseln
	if _sat_btn.disabled and _sat_btn.button_pressed:
		_sat_btn.button_pressed = false
		_data_btn.button_pressed = true
		_show_panel(_data_panel)


func _on_body_button_clicked(body_id: String) -> void:
	select_body.emit(body_id)


func _load_data_panel(body: BodyDef) -> void:
	# Orbit-Panel nur anzeigen wenn Body eine Bewegung hat
	_orbit_data_panel.visible = body.has_motion()
	
	# Parent anzeigen
	if not body.parent_id.is_empty():
		var parent: BodyDef = _model.get_body(body.parent_id)
		if parent != null:
			_parent_display.setup(parent)
			_parent_display.visible = true
		else:
			_parent_display.visible = false
	else:
		_parent_display.visible = false
	
	# Orbit-Daten berechnen und anzeigen
	if body.has_motion():
		var motion = body.motion
		match motion.model:
			"circular":
				var circular = motion as CircularMotionDef
				var radius_km = circular.orbital_radius_km
				var period_s = circular.period_s
				var speed_km_s = (2.0 * PI * radius_km) / period_s
				
				# Aphel/Perihelion (bei Kreisbahn gleich)
				# Für kleine Orbits (< 0.01 AU) km anzeigen, sonst AU
				if radius_km < (_AU_KM * 0.01):
					_dp_aphelion.set_value("%.1f" % radius_km)
					_dp_perihelion.set_value("%.1f" % radius_km)
					_dp_aphelion.set_unit("km")
					_dp_perihelion.set_unit("km")
				else:
					_dp_aphelion.set_value("%.3f" % (radius_km / _AU_KM))
					_dp_perihelion.set_value("%.3f" % (radius_km / _AU_KM))
					_dp_aphelion.set_unit("AU")
					_dp_perihelion.set_unit("AU")
				
				# Periode
				var days = period_s / 86400.0
				if days < 365.25:
					_dp_period.set_value("%.1f" % days)
					_dp_period.set_unit("days")
				else:
					_dp_period.set_value("%.2f" % (days / 365.25))
					_dp_period.set_unit("years")
				
				# Semi-major axis
				if radius_km < (_AU_KM * 0.01):
					_dp_semi_major.set_value("%.1f" % radius_km)
					_dp_semi_major.set_unit("km")
				else:
					_dp_semi_major.set_value("%.3f" % (radius_km / _AU_KM))
					_dp_semi_major.set_unit("AU")
				
				# Durchschnittsgeschwindigkeit
				_dp_avg_speed.set_value("%.2f" % speed_km_s)
				_dp_avg_speed.set_unit("km/s")
				
				# Exzentrizität (Kreisbahn = 0)
				_dp_eccentricity.set_value("0.000")
				_dp_eccentricity.set_unit("")
				
			"kepler2d":
				var kepler = motion as Kepler2DMotionDef
				var a_km = kepler.a_km
				var e = kepler.e
				
				# Periode aus Kepler's 3. Gesetz berechnen
				var period_s = 0.0
				if not body.parent_id.is_empty():
					var parent: BodyDef = _model.get_body(body.parent_id)
					if parent != null and parent.mu_km3_s2 > 0.0:
						period_s = TAU * sqrt(pow(a_km, 3.0) / parent.mu_km3_s2)
				
				# Aphel
				var aphelion_km = a_km * (1.0 + e)
				if a_km < (_AU_KM * 0.01):
					_dp_aphelion.set_value("%.1f" % aphelion_km)
					_dp_aphelion.set_unit("km")
				else:
					_dp_aphelion.set_value("%.3f" % (aphelion_km / _AU_KM))
					_dp_aphelion.set_unit("AU")
				
				# Perihelion
				var perihelion_km = a_km * (1.0 - e)
				if a_km < (_AU_KM * 0.01):
					_dp_perihelion.set_value("%.1f" % perihelion_km)
					_dp_perihelion.set_unit("km")
				else:
					_dp_perihelion.set_value("%.3f" % (perihelion_km / _AU_KM))
					_dp_perihelion.set_unit("AU")
				
				# Periode
				if period_s > 0.0:
					var days = period_s / 86400.0
					if days < 365.25:
						_dp_period.set_value("%.1f" % days)
						_dp_period.set_unit("days")
					else:
						_dp_period.set_value("%.2f" % (days / 365.25))
						_dp_period.set_unit("years")
				else:
					_dp_period.set_value("N/A")
					_dp_period.set_unit("")
				
				# Semi-major axis
				if a_km < (_AU_KM * 0.01):
					_dp_semi_major.set_value("%.1f" % a_km)
					_dp_semi_major.set_unit("km")
				else:
					_dp_semi_major.set_value("%.3f" % (a_km / _AU_KM))
					_dp_semi_major.set_unit("AU")
				
				# Durchschnittsgeschwindigkeit (näherungsweise)
				if period_s > 0.0:
					var avg_speed_km_s = (2.0 * PI * a_km) / period_s
					_dp_avg_speed.set_value("%.2f" % avg_speed_km_s)
					_dp_avg_speed.set_unit("km/s")
				else:
					_dp_avg_speed.set_value("N/A")
					_dp_avg_speed.set_unit("")
				
				# Exzentrizität
				_dp_eccentricity.set_value("%.3f" % e)
				_dp_eccentricity.set_unit("")
	else:
		# Keine Orbit-Daten verfügbar
		_dp_aphelion.set_value("N/A")
		_dp_aphelion.set_unit("")
		_dp_perihelion.set_value("N/A")
		_dp_perihelion.set_unit("")
		_dp_period.set_value("N/A")
		_dp_period.set_unit("")
		_dp_semi_major.set_value("N/A")
		_dp_semi_major.set_unit("")
		_dp_avg_speed.set_value("N/A")
		_dp_avg_speed.set_unit("")
		_dp_eccentricity.set_value("N/A")
		_dp_eccentricity.set_unit("")
	
	# Physics-Daten
	if body.radius_km > 0.0:
		_dp_radius.set_value("%.1f" % body.radius_km)
		_dp_radius.set_unit("km")
	else:
		_dp_radius.set_value("N/A")
		_dp_radius.set_unit("")
	
	# Masse aus Gravitationsparameter berechnen: M = μ / G
	var mass_kg = 0.0
	if body.mu_km3_s2 > 0.0:
		# μ ist in km³/s², G = 6.67430e-20 km³/(kg·s²)
		var G_km3 = 6.67430e-20
		mass_kg = body.mu_km3_s2 / G_km3
	
	if mass_kg > 0.0:
		# Masse in wissenschaftlicher Notation (z.B. 5.97e+24)
		var exponent = 0
		var mantissa = mass_kg
		
		# Finde den Exponenten
		while abs(mantissa) >= 10.0:
			mantissa /= 10.0
			exponent += 1
		while abs(mantissa) < 1.0 and mantissa > 0.0:
			mantissa *= 10.0
			exponent -= 1
		
		var exp_sign = ""
		if exponent < 0:
			exp_sign = "-"
		_dp_mass.set_value("%.2f e %s%d" % [mantissa, exp_sign, exponent])
		_dp_mass.set_unit("kg")
	else:
		_dp_mass.set_value("N/A")
		_dp_mass.set_unit("")
	
	# Oberflächengravitation berechnen
	if body.radius_km > 0.0 and mass_kg > 0.0:
		# g = G * M / r²
		var G = 6.67430e-11  # m³ kg⁻¹ s⁻²
		var r_m = body.radius_km * 1000.0
		var g_m_s2 = G * mass_kg / (r_m * r_m)
		
		if g_m_s2 < 10.0:
			# Kleine Gravitation in m/s²
			_dp_gravity.set_value("%.3f" % g_m_s2)
			_dp_gravity.set_unit("m/s²")
		else:
			# Große Gravitation in g
			var g_earth = g_m_s2 / 9.80665
			_dp_gravity.set_value("%.2f" % g_earth)
			_dp_gravity.set_unit("g")
	else:
		_dp_gravity.set_value("N/A")
		_dp_gravity.set_unit("")
	
	# Dichte berechnen
	if body.radius_km > 0.0 and mass_kg > 0.0:
		# ρ = M / V
		var r_m = body.radius_km * 1000.0
		var volume_m3 = (4.0/3.0) * PI * pow(r_m, 3.0)
		var density_kg_m3 = mass_kg / volume_m3
		
		# In g/cm³ umrechnen (1000 kg/m³ = 1 g/cm³)
		var density_g_cm3 = density_kg_m3 / 1000.0
		
		if density_g_cm3 < 10.0:
			_dp_density.set_value("%.2f" % density_g_cm3)
		else:
			_dp_density.set_value("%.1f" % density_g_cm3)
		_dp_density.set_unit("g/cm³")
	else:
		_dp_density.set_value("N/A")
		_dp_density.set_unit("")


func _show_panel(panel: Control) -> void:
	_data_panel.visible = (panel == _data_panel)
	_info_panel.visible = (panel == _info_panel)
	_sat_panel.visible = (panel == _sat_panel)


func _on_data_panel_btn_toggled(pressed: bool) -> void:
	if pressed:
		_show_panel(_data_panel)


func _on_info_panel_btn_toggled(pressed: bool) -> void:
	if pressed:
		_show_panel(_info_panel)


func _on_sat_panel_btn_toggled(pressed: bool) -> void:
	if pressed:
		_show_panel(_sat_panel)
