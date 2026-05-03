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


# Node References
@onready var _home_btn: Button        = $MarginContainer/VBox/Header/HomeBtn
@onready var _back_btn: Button        = $MarginContainer/VBox/Header/BackButton
@onready var _fwd_btn: Button         = $MarginContainer/VBox/Header/ForwardButton
@onready var _zoom_btn: Button        = $MarginContainer/VBox/Header/ZoomButton
@onready var _title_label: Label      = $MarginContainer/VBox/Header/TitleLabel
@onready var _article_title: Label    = $MarginContainer/VBox/Article/Header/TitleLabel
@onready var _summary_text: RichTextLabel = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/SummaryText
@onready var _hero_container: Control = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/Hero
@onready var _overview_panel: VBoxContainer = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel

# Data Panels (FoldableContainer – als Control typisiert)
@onready var _orbit_data: Control        = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/OrbitData
@onready var _parent_display: BodyLinkDisplay = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/OrbitData/VBox/ParentDisplay
@onready var _physics_data: Control    = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/PhysicsData
@onready var _atmo_data: Control       = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/AthmoData
@onready var _satelite_data: Control   = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/SateliteData
@onready var _satelite_list: RichTextLabel = $MarginContainer/VBox/Article/ContentBox/VBox/Overview/Panel/SateliteData/SateliteList

# Section Container (VBox innerhalb ContentBox – Spacer + Overview sind statische Kinder)
@onready var _content_vbox: VBoxContainer = $MarginContainer/VBox/Article/ContentBox/VBox

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
	_zoom_btn.pressed.connect(func() -> void: zoom_requested.emit(_current_body_id))
	_home_btn.pressed.connect(open_home)
	_back_btn.pressed.connect(_navigate_back)
	_fwd_btn.pressed.connect(_navigate_forward)
	_summary_text.meta_clicked.connect(_on_link_clicked)
	_parent_display.body_link_pressed.connect(open_body)
	_satelite_list.bbcode_enabled = true
	_satelite_list.meta_clicked.connect(_on_link_clicked)
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
	($MarginContainer/VBox/Article/ContentBox as ScrollContainer).scroll_vertical = 0

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
	_zoom_btn.visible = false
	_title_label.text = "Solar System Wiki"
	_article_title.text = "Übersicht"
	_clear_article_content()

	var text := "[font_size=18][b]Almanac des Sonnensystems[/b][/font_size]\n\n"
	text += "Der Almanac ist ein interaktives Nachschlagewerk über die Himmelskörper und astronomischen Zusammenhänge dieses Sonnensystems. Klicke einen Körper auf der Karte an, um seinen Eintrag zu öffnen — oder navigiere direkt über die Listen unten.\n\n"
	text += "Alle physikalischen Daten basieren auf realen Messwerten. Verlinkte Begriffe führen zu erklärenden Artikeln über Konzepte der Orbitalmechanik und Astronomie.\n\n"
	text += "[color=#888888]────────────────────────[/color]\n\n"

	# Himmelskörper gruppiert nach Typ
	var body_groups := {
		"star":   {"label": "Sterne",        "entries": []},
		"planet": {"label": "Planeten",       "entries": []},
		"dwarf":  {"label": "Zwergplaneten",  "entries": []},
		"moon":   {"label": "Monde",          "entries": []},
		"comet":  {"label": "Kometen",        "entries": []},
	}
	for obj: GameObject in GameRegistry.get_all_objects():
		var def := obj.body_def
		if body_groups.has(def.type):
			body_groups[def.type]["entries"].append(def)
	for type_key in ["star", "planet", "dwarf", "moon", "comet"]:
		var entries: Array = body_groups[type_key]["entries"]
		if entries.is_empty():
			continue
		text += "[b]%s[/b]\n" % body_groups[type_key]["label"]
		for def in entries:
			text += "  • [url=body:%s]%s[/url]\n" % [def.id, def.name]
		text += "\n"

	# Konzepte gruppiert nach Kategorie
	if not _concepts.is_empty():
		var sections := {
			"heliosphere": {"label": "Heliosphäre", "entries": []},
			"belts":       {"label": "Asteroidengürtel & Trojaner", "entries": []},
			"concepts":    {"label": "Konzepte & Begriffe", "entries": []},
		}
		for concept_id: String in _concepts:
			var article: Dictionary = _concepts[concept_id]
			var cat: String = article.get("category", "concepts")
			if sections.has(cat):
				sections[cat]["entries"].append([concept_id, article.get("title", concept_id)])
		for cat in ["heliosphere", "belts", "concepts"]:
			var entries: Array = sections[cat]["entries"]
			if entries.is_empty():
				continue
			text += "\n[b]%s[/b]\n" % sections[cat]["label"]
			for entry in entries:
				text += "  • [url=concept:%s]%s[/url]\n" % [entry[0], entry[1]]

	_summary_text.text = text
	_overview_panel.hide()


func _show_body_article(id: String) -> void:
	var obj: GameObject = GameRegistry.get_game_object(id)
	if not obj:
		_show_error("Kein Eintrag für '%s' gefunden." % id)
		return

	_current_body_id = id
	_zoom_btn.visible = true
	_title_label.text = "Solar System Wiki"
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
	_zoom_btn.visible = false
	_title_label.text = "Solar System Wiki"
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
	_build_satelite_list(def.id)


func _build_orbit_data(def: BodyDef) -> void:
	if not def.has_motion():
		_orbit_data.visible = false
		return

	_orbit_data.visible = true
	var grid := _orbit_data.get_node("VBox/Grid") as GridContainer
	_clear_grid(grid)

	if not def.parent_id.is_empty():
		var parent: BodyDef = SolarSystem.get_body(def.parent_id)
		_parent_display.setup("Umkreist", def.parent_id, parent.name if parent else def.parent_id)
	else:
		_parent_display.clear()

	var motion := def.motion
	match motion.model:
		"kepler2d":
			var km := motion as Kepler2DMotionDef
			var a := km.semi_major_axis_km
			var e := km.eccentricity
			var p_mu := _parent_mu(def.parent_id)
			var period_s := SpaceMath.get_kepler_period(a, p_mu)
			var vel := SpaceMath.mean_orbital_velocity_km_s(a, period_s)

			_add_unit_value_auto(grid, "Halbachse",     a,                                    UnitValueDisplay.UnitType.DISTANCE)
			_add_unit_value_auto(grid, "Umlaufzeit",    period_s,                             UnitValueDisplay.UnitType.PERIOD)
			_add_unit_value_auto(grid, "Exzentrizität", e,                                    UnitValueDisplay.UnitType.DIMENSIONLESS)
			_add_unit_value_auto(grid, "Periapsis",     SpaceMath.orbit_periapsis_km(a, e),   UnitValueDisplay.UnitType.DISTANCE)
			_add_unit_value_auto(grid, "Apoapsis",      SpaceMath.orbit_apoapsis_km(a, e),    UnitValueDisplay.UnitType.DISTANCE)
			_add_unit_value_auto(grid, "Ø Geschw.",     vel,                                  UnitValueDisplay.UnitType.VELOCITY)

		"circular":
			var cm := motion as CircularMotionDef
			var r_orb := cm.orbital_radius_km
			var period_s := cm.orbital_period_s
			var vel := SpaceMath.mean_orbital_velocity_km_s(r_orb, period_s)

			_add_unit_value_auto(grid, "Bahnradius",    r_orb,     UnitValueDisplay.UnitType.DISTANCE)
			_add_unit_value_auto(grid, "Umlaufzeit",    period_s,  UnitValueDisplay.UnitType.PERIOD)
			_add_unit_value_auto(grid, "Exzentrizität", 0.0,       UnitValueDisplay.UnitType.DIMENSIONLESS)
			_add_unit_value(grid, "Periapsis",     "—",       "")
			_add_unit_value(grid, "Apoapsis",      "—",       "")
			_add_unit_value_auto(grid, "Ø Geschw.",     vel,       UnitValueDisplay.UnitType.VELOCITY)


func _build_physics_data(def: BodyDef) -> void:
	_physics_data.visible = true
	var grid := _physics_data.get_node("Grid") as GridContainer
	_clear_grid(grid)

	var r  := def.body_radius_km
	var mu := def.grav_param_km3_s2

	_add_unit_value(grid, "Radius",       "%.1f" % r,                                          "km")
	_add_unit_value_auto(grid, "Masse",        SpaceMath.body_mass_kg(mu),              UnitValueDisplay.UnitType.MASS)
	_add_unit_value_auto(grid, "Dichte",       SpaceMath.body_density_g_cm3(mu, r),     UnitValueDisplay.UnitType.DENSITY)
	_add_unit_value_auto(grid, "Schwerkraft",  SpaceMath.surface_gravity_ms2(mu, r),    UnitValueDisplay.UnitType.ACCELERATION)
	_add_unit_value_auto(grid, "Fluchtgeschw.",SpaceMath.escape_velocity_km_s(mu, r),   UnitValueDisplay.UnitType.VELOCITY)


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
		_add_unit_value_auto(grid, "Druck",      float(atmo["pressure"]), UnitValueDisplay.UnitType.PRESSURE)
	if atmo.has("temp_mean"):
		_add_unit_value_auto(grid, "Temp. ⌀",   float(atmo["temp_mean"]), UnitValueDisplay.UnitType.TEMPERATURE)
	if atmo.has("temp_min"):
		_add_unit_value_auto(grid, "Temp. Min",  float(atmo["temp_min"]),  UnitValueDisplay.UnitType.TEMPERATURE)
	if atmo.has("temp_max"):
		_add_unit_value_auto(grid, "Temp. Max",  float(atmo["temp_max"]),  UnitValueDisplay.UnitType.TEMPERATURE)

	# Hauptbestandteile
	if atmo.has("composition"):
		var composition: Dictionary = atmo["composition"]
		if not composition.is_empty():
			var comp_label := Label.new()
			comp_label.text = "Hauptbestandteile"
			comp_label.theme_type_variation = "UiDisplayValue"
			vbox.add_child(comp_label)

			var sep := HSeparator.new()
			vbox.add_child(sep)

			var comp_grid := GridContainer.new()
			comp_grid.columns = 2
			vbox.add_child(comp_grid)

			for comp_name: String in composition:
				_add_unit_value_auto(comp_grid, comp_name, float(composition[comp_name]), UnitValueDisplay.UnitType.PERCENTAGE)


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
		_content_vbox.add_child(heading_label)

	if not content.is_empty():
		var rich_text := RichTextLabel.new()
		rich_text.bbcode_enabled = true
		rich_text.text = content
		rich_text.fit_content = true
		rich_text.custom_minimum_size.y = 0
		rich_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_content_vbox.add_child(rich_text)
		rich_text.meta_clicked.connect(_on_link_clicked)


func _render_gallery_section(section: Dictionary) -> void:
	var heading: String = section.get("heading", "Galerie")
	var images: Array = section.get("images", [])

	if not heading.is_empty():
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_size_override("font_size", 16)
		heading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		_content_vbox.add_child(heading_label)

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

	_content_vbox.add_child(gallery)


func _render_table_section(section: Dictionary) -> void:
	var heading: String = section.get("heading", "Tabelle")
	var headers: Array = section.get("headers", [])
	var rows: Array = section.get("rows", [])

	if not heading.is_empty():
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_size_override("font_size", 16)
		heading_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
		_content_vbox.add_child(heading_label)

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

	_content_vbox.add_child(table)


## Helpers

func _build_satelite_list(body_id: String) -> void:
	var children: Array[BodyDef] = []
	for obj: GameObject in GameRegistry.get_all_objects():
		if obj.body_def.parent_id == body_id:
			children.append(obj.body_def)

	if children.is_empty():
		_satelite_data.visible = false
		return

	_satelite_data.visible = true
	var text := "[b]Monde & Satelliten[/b]\n"
	for def: BodyDef in children:
		var type_hint := ""
		if not def.subtype.is_empty():
			type_hint = " [color=#888888](%s)[/color]" % def.subtype
		elif not def.type.is_empty():
			type_hint = " [color=#888888](%s)[/color]" % def.type
		text += "  • [url=body:%s]%s[/url]%s\n" % [def.id, def.name, type_hint]
	_satelite_list.text = text


func _clear_article_content() -> void:
	_summary_text.text = ""
	_hero_container.visible = false
	_overview_panel.visible = false
	_satelite_data.visible = false
	_clear_sections()


func _clear_sections() -> void:
	# Statische Kinder in ContentBox/VBox: Spacer (0) + Overview (1) – alles danach sind Sections
	const STATIC_CHILDREN := 2
	for i in range(_content_vbox.get_child_count() - 1, STATIC_CHILDREN - 1, -1):
		_content_vbox.get_child(i).queue_free()


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


func _add_unit_value(grid: GridContainer, caption: String, value: String, unit: String) -> void:
	var unit_disp := _UNIT_VALUE_DISPLAY.instantiate()
	grid.add_child(unit_disp)
	unit_disp.setup(caption, value, unit)


func _add_unit_value_auto(grid: GridContainer, caption: String, raw_value: float, unit_type: UnitValueDisplay.UnitType) -> void:
	var unit_disp := _UNIT_VALUE_DISPLAY.instantiate()
	grid.add_child(unit_disp)
	unit_disp.setup_auto(caption, raw_value, unit_type)


func _on_link_clicked(meta: Variant) -> void:
	var link := str(meta)
	if link.begins_with("concept:"):
		open_concept(link.right(link.length() - 8))
	elif link.begins_with("body:"):
		open_body(link.right(link.length() - 5))


func _get_hero_texture(body_id: String, content: AlmanachContentComponent) -> Texture2D:
	# 1. Planeten-Textur aus BodyTextures Autoload
	var tex := BodyTextures.load_surface(body_id)
	if tex:
		return tex
	# 2. Fallback: Hero-Bild aus AlmanachContent
	if content and not content.image.is_empty() and ResourceLoader.exists(content.image):
		return load(content.image) as Texture2D
	return null


func _parent_mu(parent_id: String) -> float:
	if parent_id.is_empty():
		return 0.0
	var p: BodyDef = SolarSystem.get_body(parent_id)
	return p.grav_param_km3_s2 if p else 0.0
