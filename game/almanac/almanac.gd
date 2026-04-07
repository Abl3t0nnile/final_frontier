## Almanac
## Zentrales Feature: Navigierbares Nachschlagewerk für Bodies und Concepts.
## Nutzt AlmanachContentComponent + BodyDef zur Artikel-Generierung.

class_name Almanac
extends PanelContainer

signal zoom_requested(body_id: String)

# Navigation History
var _history: Array[String] = []
var _current_index: int = -1
var _current_body_id: String = ""

# Concepts Dictionary (von GameController injiziert)
var _concepts: Dictionary = {}

# Prefabs
const _UNIT_VALUE_DISPLAY = preload("res://ui/components/UnitValueDisplay.tscn")

# Planeten-Texturen (sync mit InfoPanel)
const _TEXTURE_BASE := "res://assets/textures/planets/16_levels/"
const _BODY_TEXTURES: Dictionary = {
	"sun":      { "surface": "2k_sun.png" },
	"mercury":  { "surface": "2k_mercury.png" },
	"venus":    { "surface": "black_surface.png", "cloud": "2k_venus_atmosphere.png" },
	"terra":    { "surface": "2k_earth_daymap.png", "cloud": "2k_earth_clouds.png" },
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
	"pluto":    { "surface": "2k_pluto.png" },
}

# Node References
@onready var _home_btn: Button        = $VBox/Header/HomeBtn
@onready var _back_btn: Button        = $VBox/Header/BackButton
@onready var _fwd_btn: Button         = $VBox/Header/ForwardButton
@onready var _title_label: Label      = $VBox/Header/TitleLabel
@onready var _article_title: Label    = $VBox/ContentBox/Article/Header/TitleLabel
@onready var _summary_text: RichTextLabel = $VBox/ContentBox/Article/Overview/SummaryText
@onready var _hero_container: Control = $VBox/ContentBox/Article/Overview/Panel/Hero
@onready var _overview_panel: VBoxContainer = $VBox/ContentBox/Article/Overview/Panel

# Data Panels (FoldableContainer – als Control typisiert)
@onready var _orbit_data: Control   = $VBox/ContentBox/Article/Overview/Panel/OrbitData
@onready var _physics_data: Control = $VBox/ContentBox/Article/Overview/Panel/PhysicsData
@onready var _atmo_data: Control    = $VBox/ContentBox/Article/Overview/Panel/AthmoData

# Section Container (nach Overview)
@onready var _article: VBoxContainer = $VBox/ContentBox/Article

# Hero-Image (TextureRect inside MarginContainer %Hero)
var _hero_image: TextureRect
var _hero_missing_label: Label

func _ready() -> void:
	_hero_image = _hero_container.get_node("Image") as TextureRect
	_hero_missing_label = Label.new()
	_hero_missing_label.text = "--- missing ---"
	_hero_missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_missing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_missing_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94, 0.4))
	_hero_missing_label.visible = false
	_hero_container.add_child(_hero_missing_label)
	_home_btn.pressed.connect(open_home)
	_back_btn.pressed.connect(_navigate_back)
	_fwd_btn.pressed.connect(_navigate_forward)
	_summary_text.meta_clicked.connect(_on_link_clicked)
	_update_nav_buttons()


## Public API

func set_concepts(concepts: Dictionary) -> void:
	"""Concepts Dictionary setzen (wird von GameController aufgerufen)"""
	_concepts = concepts


func open_body(id: String) -> void:
	"""Body-Artikel öffnen"""
	_navigate_to("body:" + id)


func open_concept(id: String) -> void:
	"""Concept-Artikel öffnen"""
	_navigate_to("concept:" + id)


func open_home() -> void:
	"""Home-Seite anzeigen"""
	_navigate_to("home")


func has_history() -> bool:
	"""Gibt zurück ob bereits Navigationshistorie vorhanden ist"""
	return _history.size() > 0


## Navigation

func _navigate_to(article_id: String) -> void:
	if _current_index >= 0 and _history[_current_index] == article_id:
		return

	# Forward-History verwerfen
	if _current_index < _history.size() - 1:
		_history = _history.slice(0, _current_index + 1)

	_history.append(article_id)
	_current_index = _history.size() - 1
	_display_article(article_id)
	_update_nav_buttons()


func _navigate_back() -> void:
	if _current_index > 0:
		_current_index -= 1
		_display_article(_history[_current_index])
		_update_nav_buttons()


func _navigate_forward() -> void:
	if _current_index < _history.size() - 1:
		_current_index += 1
		_display_article(_history[_current_index])
		_update_nav_buttons()


func _update_nav_buttons() -> void:
	var on_home := _current_index >= 0 and _history[_current_index] == "home"
	_home_btn.disabled = on_home or _current_index < 0
	_back_btn.disabled = _current_index <= 0
	_fwd_btn.disabled = _current_index >= _history.size() - 1


## Article Display

func _display_article(article_id: String) -> void:
	# ScrollContainer zurücksetzen
	($VBox/ContentBox as ScrollContainer).scroll_vertical = 0

	match article_id:
		"home":
			_show_home()
		_:
			var parts := article_id.split(":", false, 1)
			if parts.size() != 2:
				_show_error("Ungültige Artikel-ID: " + article_id)
				return

			var ns := parts[0]
			var key := parts[1]
			match ns:
				"body":
					_show_body_article(key)
				"concept":
					_show_concept_article(key)
				_:
					_show_error("Unbekannter Namespace: " + ns)


func _show_home() -> void:
	_current_body_id = ""
	_title_label.text = "Almanac"
	_article_title.text = "Übersicht"
	_clear_article_content()

	var text := "[font_size=18][b]Almanac des Sonnensystems[/b][/font_size]\n\n"
	text += "Der Almanac ist ein interaktives Nachschlagewerk über die Himmelskörper und astronomischen Zusammenhänge dieses Sonnensystems. Klicke einen Körper auf der Karte an, um seinen Eintrag zu öffnen — oder navigiere direkt über die Listen unten.\n\n"
	text += "Alle physikalischen Daten basieren auf realen Messwerten. Verlinkte Begriffe führen zu erklärenden Artikeln über Konzepte der Orbitalmechanik und Astronomie.\n\n"

	_summary_text.text = text
	_overview_panel.hide()


func _show_body_article(id: String) -> void:
	var obj: GameObject = GameRegistry.get_game_object(id)
	if not obj:
		_show_error("Kein Eintrag für '%s' gefunden." % id)
		return

	_current_body_id = id
	_title_label.text = "Almanac"
	_article_title.text = obj.body_def.name

	_build_body_overview(obj)
	_build_body_sections(obj)

	_overview_panel.show()


func _show_concept_article(id: String) -> void:
	if not _concepts.has(id):
		_show_error("Kein Konzept-Eintrag für '%s' gefunden." % id)
		return

	var article: Dictionary = _concepts[id]
	_current_body_id = ""
	_title_label.text = "Almanac"
	_article_title.text = article.get("title", id)

	_clear_article_content()
	_summary_text.text = article.get("content", "")
	_overview_panel.hide()


func _show_error(msg: String) -> void:
	_title_label.text = "Fehler"
	_article_title.text = ""
	_clear_article_content()
	_summary_text.text = "[color=#cc4444]%s[/color]" % msg
	_overview_panel.hide()


## Body Article Builder

func _build_body_overview(obj: GameObject) -> void:
	var def: BodyDef = obj.body_def
	var content: AlmanachContentComponent = obj.get_component("almanach")

	# Summary
	if content and not content.summary.is_empty():
		_summary_text.text = content.summary
	elif content and not content.description.is_empty():
		_summary_text.text = content.description
	else:
		_summary_text.text = "Keine Beschreibung verfügbar."

	# Hero-Bild
	var tex := _get_hero_texture(obj.body_def.id, content)
	_hero_image.texture = tex
	_hero_image.visible = tex != null
	_hero_missing_label.visible = tex == null
	_hero_container.visible = true

	# Dynamische Daten-Panels
	_build_orbit_data(def)
	_build_physics_data(def)
	_build_atmo_data(def, content)


func _build_orbit_data(def: BodyDef) -> void:
	if not def.has_motion():
		_orbit_data.visible = false
		return

	_orbit_data.visible = true
	var grid := _orbit_data.get_node("Grid") as GridContainer
	_clear_grid(grid)

	var motion := def.motion
	match motion.model:
		"kepler2d":
			var km := motion as Kepler2DMotionDef
			var a := km.semi_major_axis_km
			var e := km.eccentricity
			var p_mu := _parent_mu(def.parent_id)
			var period_s := SpaceMath.get_kepler_period(a, p_mu)
			var vel := SpaceMath.mean_orbital_velocity_km_s(a, period_s)

			_add_unit_value(grid, "Halbachse",     "%.4f" % SpaceMath.km_to_au(a),                                      "AU")
			_add_unit_value(grid, "Umlaufzeit",    _format_period(period_s),                                             "")
			_add_unit_value(grid, "Exzentrizität", "%.4f" % e,                                                           "")
			_add_unit_value(grid, "Periapsis",     "%.4f" % SpaceMath.km_to_au(SpaceMath.orbit_periapsis_km(a, e)),      "AU")
			_add_unit_value(grid, "Apoapsis",      "%.4f" % SpaceMath.km_to_au(SpaceMath.orbit_apoapsis_km(a, e)),       "AU")
			_add_unit_value(grid, "Ø Geschw.",     _fmt_or_dash(vel, 2),                                                 "km/s")

		"circular":
			var cm := motion as CircularMotionDef
			var r_orb := cm.orbital_radius_km
			var period_s := cm.orbital_period_s
			var vel := SpaceMath.mean_orbital_velocity_km_s(r_orb, period_s)

			_add_unit_value(grid, "Bahnradius",    "%.4f" % SpaceMath.km_to_au(r_orb), "AU")
			_add_unit_value(grid, "Umlaufzeit",    _format_period(period_s),            "")
			_add_unit_value(grid, "Exzentrizität", "0",                                 "")
			_add_unit_value(grid, "Periapsis",     "—",                                 "")
			_add_unit_value(grid, "Apoapsis",      "—",                                 "")
			_add_unit_value(grid, "Ø Geschw.",     _fmt_or_dash(vel, 2),               "km/s")


func _build_physics_data(def: BodyDef) -> void:
	_physics_data.visible = true
	var grid := _physics_data.get_node("Grid") as GridContainer
	_clear_grid(grid)

	var r  := def.body_radius_km
	var mu := def.grav_param_km3_s2

	_add_unit_value(grid, "Radius",       "%.1f" % r,                                          "km")
	_add_unit_value(grid, "Masse",        _format_mass(SpaceMath.body_mass_kg(mu)),             "kg")
	_add_unit_value(grid, "Dichte",       _fmt_or_dash(SpaceMath.body_density_g_cm3(mu, r), 2), "g/cm³")
	_add_unit_value(grid, "Schwerkraft",  _fmt_or_dash(SpaceMath.surface_gravity_ms2(mu, r), 2),"m/s²")
	_add_unit_value(grid, "Fluchtgeschw.",_fmt_or_dash(SpaceMath.escape_velocity_km_s(mu, r), 2),"km/s")


func _build_atmo_data(_def: BodyDef, content: AlmanachContentComponent) -> void:
	# Panel ausblenden wenn keine Atmosph.-Daten vorhanden oder leer
	if not content or not content.infobox.has("atmosphere"):
		_atmo_data.visible = false
		return

	var atmo: Dictionary = content.infobox["atmosphere"]
	if atmo.is_empty():
		_atmo_data.visible = false
		return

	_atmo_data.visible = true
	var vbox := _atmo_data.get_node("VBox") as VBoxContainer

	# Alle bestehenden Kinder löschen und neu aufbauen
	for child in vbox.get_children():
		child.queue_free()

	# Daten-Grid (Druck + Temperaturen)
	var grid := GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)

	if atmo.has("pressure"):
		_add_unit_value(grid, "Druck",      "%.3f" % float(atmo["pressure"]), "bar")
	if atmo.has("temp_mean"):
		_add_unit_value(grid, "Temp. ⌀",   str(atmo["temp_mean"]),           "°C")
	if atmo.has("temp_min"):
		_add_unit_value(grid, "Temp. Min",  str(atmo["temp_min"]),            "°C")
	if atmo.has("temp_max"):
		_add_unit_value(grid, "Temp. Max",  str(atmo["temp_max"]),            "°C")

	# Hauptbestandteile
	if atmo.has("composition"):
		var composition: Dictionary = atmo["composition"]
		if not composition.is_empty():
			var comp_label := Label.new()
			comp_label.text = "Hauptbestandteile"
			vbox.add_child(comp_label)

			var sep := HSeparator.new()
			vbox.add_child(sep)

			var comp_grid := GridContainer.new()
			comp_grid.columns = 2
			vbox.add_child(comp_grid)

			for comp_name: String in composition:
				_add_unit_value(comp_grid, comp_name, "%.3f" % float(composition[comp_name]), "%")


func _build_body_sections(obj: GameObject) -> void:
	var content: AlmanachContentComponent = obj.get_component("almanach")
	if not content or content.sections.is_empty():
		_clear_sections()
		return

	_clear_sections()

	for section: Dictionary in content.sections:
		_render_section(section)


## Section Renderer

func _render_section(section: Dictionary) -> void:
	var type: String = section.get("type", "text")

	match type:
		"text":
			_render_text_section(section)
		"gallery":
			_render_gallery_section(section)
		"table":
			_render_table_section(section)
		_:
			push_warning("Almanac: Unknown section type '%s'" % type)


func _render_text_section(section: Dictionary) -> void:
	var heading: String = section.get("heading", "")
	var content: String = section.get("content", "")

	if not heading.is_empty():
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_size_override("font_size", 16)
		heading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		_article.add_child(heading_label)

	if not content.is_empty():
		var rich_text := RichTextLabel.new()
		rich_text.bbcode_enabled = true
		rich_text.text = content
		rich_text.fit_content = true
		rich_text.custom_minimum_size.y = 0
		rich_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_article.add_child(rich_text)
		rich_text.meta_clicked.connect(_on_link_clicked)


func _render_gallery_section(section: Dictionary) -> void:
	var heading: String = section.get("heading", "Galerie")
	var images: Array = section.get("images", [])

	if not heading.is_empty():
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_size_override("font_size", 16)
		heading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		_article.add_child(heading_label)

	var gallery := HFlowContainer.new()
	gallery.add_theme_constant_override("h_separation", 8)
	gallery.add_theme_constant_override("v_separation", 8)

	for img_path: String in images:
		var tex := load(img_path)
		if tex:
			var img_rect := TextureRect.new()
			img_rect.texture = tex
			img_rect.custom_minimum_size = Vector2(200, 150)
			img_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			gallery.add_child(img_rect)

	_article.add_child(gallery)


func _render_table_section(section: Dictionary) -> void:
	var heading: String = section.get("heading", "Tabelle")
	var headers: Array = section.get("headers", [])
	var rows: Array = section.get("rows", [])

	if not heading.is_empty():
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_size_override("font_size", 16)
		heading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		_article.add_child(heading_label)

	var table := GridContainer.new()
	table.columns = headers.size()

	for header: String in headers:
		var label := Label.new()
		label.text = header
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		table.add_child(label)

	for row: Array in rows:
		for cell in row:
			var label := Label.new()
			label.text = str(cell)
			table.add_child(label)

	_article.add_child(table)


## Helpers

func _clear_article_content() -> void:
	_summary_text.text = ""
	_hero_container.visible = false
	_overview_panel.visible = false
	_clear_sections()


func _clear_sections() -> void:
	# Statische Kinder: Header (0) + Overview (1) – alles danach sind Sections
	const STATIC_CHILDREN := 2
	while _article.get_child_count() > STATIC_CHILDREN:
		_article.get_child(STATIC_CHILDREN).queue_free()


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


func _add_unit_value(grid: GridContainer, caption: String, value: String, unit: String) -> void:
	var unit_disp := _UNIT_VALUE_DISPLAY.instantiate()
	grid.add_child(unit_disp)
	unit_disp.setup(caption, value, unit)


func _on_link_clicked(meta: Variant) -> void:
	var link := str(meta)
	if link.begins_with("concept:"):
		open_concept(link.right(link.length() - 8))
	elif link.begins_with("body:"):
		open_body(link.right(link.length() - 5))


func _get_hero_texture(body_id: String, content: AlmanachContentComponent) -> Texture2D:
	# 1. Planeten-Textur aus _BODY_TEXTURES (wie InfoPanel)
	var entry: Dictionary = _BODY_TEXTURES.get(body_id, {})
	if not entry.is_empty():
		var surface_path: String = _TEXTURE_BASE + (entry.get("surface", "") as String)
		if ResourceLoader.exists(surface_path):
			return load(surface_path) as Texture2D
	# 2. Fallback: Hero-Bild aus AlmanachContent
	if content and not content.image.is_empty() and ResourceLoader.exists(content.image):
		return load(content.image) as Texture2D
	return null


func _parent_mu(parent_id: String) -> float:
	if parent_id.is_empty():
		return 0.0
	var p: BodyDef = SolarSystem.get_body(parent_id)
	return p.grav_param_km3_s2 if p else 0.0


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
