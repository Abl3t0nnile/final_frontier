## AlmanachPanel
## Wikipedia-artiger Almanach für Himmelskörper und astronomische Konzepte.
## Navigierbar per Hyperlinks, mit History-Stack.
## Erweitert: PanelContainer

class_name AlmanachPanel
extends PanelContainer

signal zoom_requested(body_id: String)

const _ARTICLES_PATH := "res://data/almanach/almanach_articles.json"

## Navigation History: Array von article_ids (z.B. "body:terra", "concept:eccentricity")
var _history: Array[String] = []
var _current_index: int = -1
var _current_body_id: String = ""

## Geladene Konzept-Artikel aus JSON
var _concept_articles: Dictionary = {}
## Geladene Körper-Beschreibungstexte aus JSON (key = body id)
var _body_texts: Dictionary = {}

@onready var _home_btn:    Button        = $VBox/Header/HomeBtn
@onready var _zoom_btn:    Button        = $VBox/Header/ZoomButton
@onready var _back_btn:    Button        = $VBox/Header/BackButton
@onready var _fwd_btn:     Button        = $VBox/Header/ForwardButton
@onready var _title_label: Label         = $VBox/Header/TitleLabel
@onready var _content:     RichTextLabel = $VBox/ScrollContainer/ArticleContent


func _ready() -> void:
	_load_concept_articles()
	_home_btn.pressed.connect(open_home)
	_zoom_btn.pressed.connect(func() -> void: zoom_requested.emit(_current_body_id))
	_back_btn.pressed.connect(_navigate_back)
	_fwd_btn.pressed.connect(_navigate_forward)
	_content.meta_clicked.connect(_on_link_clicked)
	_update_nav_buttons()


func _load_concept_articles() -> void:
	if not FileAccess.file_exists(_ARTICLES_PATH):
		push_warning("AlmanachPanel: Artikeldatei nicht gefunden: " + _ARTICLES_PATH)
		return
	var file := FileAccess.open(_ARTICLES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		if parsed.has("bodies"):
			_body_texts = parsed["bodies"]
			parsed.erase("bodies")
		_concept_articles = parsed


# ── Public API ─────────────────────────────────────────────────────────────────

func open_body(id: String) -> void:
	_navigate_to("body:" + id)


func open_concept(id: String) -> void:
	_navigate_to("concept:" + id)


func open_home() -> void:
	_navigate_to("home")


func has_history() -> bool:
	return not _history.is_empty()


# ── Navigation ─────────────────────────────────────────────────────────────────

func _navigate_to(article_id: String) -> void:
	if _current_index >= 0 and _history[_current_index] == article_id:
		return
	# Forward-History verwerfen wenn neuer Artikel geöffnet wird
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
	_fwd_btn.disabled  = _current_index >= _history.size() - 1


func _display_article(article_id: String) -> void:
	_content.scroll_to_line(0)
	if article_id == "home":
		_show_home()
		return
	var sep := article_id.find(":")
	if sep == -1:
		_show_error("Ungültige Artikel-ID: " + article_id)
		return
	var ns  := article_id.left(sep)
	var key := article_id.right(article_id.length() - sep - 1)
	match ns:
		"body":    _show_body_article(key)
		"concept": _show_concept_article(key)
		_:         _show_error("Unbekannter Namespace: " + ns)


# ── Artikel-Anzeige ────────────────────────────────────────────────────────────

func _show_home() -> void:
	_current_body_id = ""
	_zoom_btn.visible = false
	_title_label.text = "Almanach"
	var text := "[font_size=18][b]Almanach des Sonnensystems[/b][/font_size]\n\n"
	text += "Der Almanach ist ein interaktives Nachschlagewerk über die Himmelskörper und astronomischen Zusammenhänge dieses Sonnensystems. Klicke einen Körper auf der Karte an, um seinen Eintrag zu öffnen — oder navigiere direkt über die Listen unten.\n\n"
	text += "Alle physikalischen Daten basieren auf realen Messwerten. Verlinkte Begriffe führen zu erklärenden Artikeln über Konzepte der Orbitalmechanik und Astronomie.\n\n"
	text += "[color=#888888]────────────────────────[/color]\n\n"

	text += "[b]Himmelskörper[/b]\n"
	for obj: GameObject in GameRegistry.get_all_objects():
		var def := obj.body_def
		var type_hint := ""
		if not def.subtype.is_empty():
			type_hint = " [color=#888888](%s)[/color]" % def.subtype
		elif not def.type.is_empty():
			type_hint = " [color=#888888](%s)[/color]" % def.type
		text += "  • [url=body:%s]%s[/url]%s\n" % [def.id, def.name, type_hint]

	text += "\n[b]Konzepte & Begriffserklärungen[/b]\n"
	for concept_id: String in _concept_articles:
		var article: Dictionary = _concept_articles[concept_id]
		text += "  • [url=concept:%s]%s[/url]\n" % [concept_id, article.get("title", concept_id)]

	_content.text = text


func _show_body_article(id: String) -> void:
	var def: BodyDef = SolarSystem.get_body(id)
	if def == null:
		_show_error("Kein Eintrag für '%s' gefunden." % id)
		return
	_current_body_id = id
	_zoom_btn.visible = true
	_title_label.text = def.name
	_content.text = _generate_body_bbcode(def)


func _show_concept_article(id: String) -> void:
	_current_body_id = ""
	_zoom_btn.visible = false
	if not _concept_articles.has(id):
		_show_error("Kein Konzept-Eintrag für '%s' gefunden." % id)
		return
	var article: Dictionary = _concept_articles[id]
	_title_label.text = article.get("title", id)
	_content.text     = article.get("content", "")


func _show_error(msg: String) -> void:
	_title_label.text = "Fehler"
	_content.text = "[color=#cc4444]%s[/color]" % msg


# ── Body-Artikel Generator ─────────────────────────────────────────────────────

func _generate_body_bbcode(def: BodyDef) -> String:
	var t := ""

	# Titel & Typ-Zeile
	t += "[font_size=20][b]%s[/b][/font_size]\n" % def.name
	var type_line := def.type
	if not def.subtype.is_empty():
		type_line += " · " + def.subtype
	t += "[i]%s[/i]\n\n" % type_line

	# Eltern-Link
	if not def.parent_id.is_empty():
		var parent_def: BodyDef = SolarSystem.get_body(def.parent_id)
		var parent_name := parent_def.name if parent_def else def.parent_id
		t += "Umkreist: [url=body:%s]%s[/url]\n" % [def.parent_id, parent_name]
		t += "\n"

	t += "[color=#888888]────────────────────────[/color]\n\n"

	# Beschreibungstext (falls vorhanden)
	if _body_texts.has(def.id):
		var desc: String = _body_texts[def.id].get("description", "")
		if not desc.is_empty():
			t += desc + "\n\n"
			t += "[color=#888888]────────────────────────[/color]\n\n"

	# Physikalische Daten
	t += "[b]Physikalische Daten[/b]\n"
	var r  := def.body_radius_km
	var mu := def.grav_param_km3_s2
	t += "Radius: [b]%.1f km[/b]\n" % r
	var mass := SpaceMath.body_mass_kg(mu)
	t += "Masse: [b]%s kg[/b]\n" % _format_mass(mass)
	var density := SpaceMath.body_density_g_cm3(mu, r)
	if not is_zero_approx(density):
		t += "Dichte: [b]%.2f g/cm³[/b]\n" % density
	var gravity := SpaceMath.surface_gravity_ms2(mu, r)
	if not is_zero_approx(gravity):
		t += "Oberflächenschwerkraft: [b]%.2f m/s²[/b]\n" % gravity
	var v_esc := SpaceMath.escape_velocity_km_s(mu, r)
	if not is_zero_approx(v_esc):
		t += "[url=concept:escape_velocity]Fluchtgeschwindigkeit[/url]: [b]%.2f km/s[/b]\n" % v_esc
	t += "\n"

	# Orbitaldaten
	if def.has_motion():
		t += "[b]Orbitaldaten[/b]\n"
		var motion := def.motion
		match motion.model:
			"kepler2d":
				var km    := motion as Kepler2DMotionDef
				var a     := km.semi_major_axis_km
				var e     := km.eccentricity
				var p_mu  := _parent_mu(def.parent_id)
				var period_s := SpaceMath.get_kepler_period(a, p_mu)
				var vel   := SpaceMath.mean_orbital_velocity_km_s(a, period_s)
				t += "[url=concept:semi_major_axis]Große Halbachse[/url]: [b]%.4f AU[/b]\n"  % SpaceMath.km_to_au(a)
				t += "[url=concept:orbital_period]Umlaufzeit[/url]: [b]%s[/b]\n"              % _format_period(period_s)
				t += "[url=concept:eccentricity]Exzentrizität[/url]: [b]%.4f[/b]\n"           % e
				t += "[url=concept:periapsis]Periapsis[/url]: [b]%.4f AU[/b]\n"               % SpaceMath.km_to_au(SpaceMath.orbit_periapsis_km(a, e))
				t += "[url=concept:apoapsis]Apoapsis[/url]: [b]%.4f AU[/b]\n"                 % SpaceMath.km_to_au(SpaceMath.orbit_apoapsis_km(a, e))
				if not is_zero_approx(vel):
					t += "[url=concept:orbital_velocity]Ø Orbitalgeschwindigkeit[/url]: [b]%.2f km/s[/b]\n" % vel
			"circular":
				var cm       := motion as CircularMotionDef
				var r_orb    := cm.orbital_radius_km
				var period_s := cm.orbital_period_s
				var vel      := SpaceMath.mean_orbital_velocity_km_s(r_orb, period_s)
				t += "[url=concept:semi_major_axis]Bahnradius[/url]: [b]%.4f AU[/b]\n"        % SpaceMath.km_to_au(r_orb)
				t += "[url=concept:orbital_period]Umlaufzeit[/url]: [b]%s[/b]\n"              % _format_period(period_s)
				t += "[url=concept:eccentricity]Exzentrizität[/url]: [b]0[/b] (kreisförmig)\n"
				if not is_zero_approx(vel):
					t += "[url=concept:orbital_velocity]Ø Orbitalgeschwindigkeit[/url]: [b]%.2f km/s[/b]\n" % vel
		t += "\n"

	# Trabanten (Kinder)
	var children := _get_children(def.id)
	if not children.is_empty():
		t += "[b]Bekannte Trabanten[/b]\n"
		for child: BodyDef in children:
			var sub := child.subtype if not child.subtype.is_empty() else child.type
			t += "  • [url=body:%s]%s[/url] [color=#888888](%s)[/color]\n" % [child.id, child.name, sub]
		t += "\n"

	return t


# ── Helpers ────────────────────────────────────────────────────────────────────

func _get_children(parent_id: String) -> Array[BodyDef]:
	var result: Array[BodyDef] = []
	for obj: GameObject in GameRegistry.get_all_objects():
		if obj.body_def.parent_id == parent_id:
			result.append(obj.body_def)
	return result


func _parent_mu(parent_id: String) -> float:
	if parent_id.is_empty():
		return 0.0
	var p: BodyDef = SolarSystem.get_body(parent_id)
	return p.grav_param_km3_s2 if p else 0.0


func _on_link_clicked(meta: Variant) -> void:
	var link := str(meta)
	var sep := link.find(":")
	if sep == -1:
		return
	_navigate_to(link)


func _format_mass(kg: float) -> String:
	if kg <= 0.0:
		return "—"
	var magnitude := floori(log(kg) / log(10.0))
	var mantissa  := kg / pow(10.0, float(magnitude))
	return "%.3f e%d" % [mantissa, magnitude]


func _format_period(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var days := seconds / 86400.0
	if days >= 365.25:
		return "%.2f a" % (days / 365.25)
	return "%.1f d" % days
