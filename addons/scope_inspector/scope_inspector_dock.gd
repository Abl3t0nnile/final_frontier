@tool
extends Control

const SCOPES_DIR := "res://game/map/views/star_chart/scopes/"
const SCOPE_TYPES := ["star", "planet", "dwarf", "moon", "struct"]
const FOKUS_TAGS := [
	"major_body", "solar_orbit",
	"inner_system", "outer_system",
	"terran_system", "martian_system", "jovian_system",
	"saturnian_system", "uranian_system", "neptunian_system",
	"asteroid_belt", "kuiper_belt", "trans_neptunian",
]

var _current_scope: ScopeConfig = null
var _current_path: String = ""
var _scope_paths: Array[String] = []

# UI-Refs
var _dropdown: OptionButton
var _scope_name_edit: LineEdit
var _zoom_min: SpinBox
var _zoom_max: SpinBox
var _fokus_tags_checks: Dictionary  # tag -> CheckBox
var _exag_faktor: SpinBox
var _visible_types_checks: Dictionary  # type -> CheckBox
var _visible_tags_edit: LineEdit
var _visible_zones_edit: LineEdit
var _min_orbit_px: SpinBox
var _marker_size_spins: Dictionary     # type -> SpinBox
var _status_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(260, 300)
	_build_ui()
	_scan_scopes()


# ── UI-Aufbau ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# Toolbar
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	var scope_label := Label.new()
	scope_label.text = "Scope:"
	toolbar.add_child(scope_label)

	_dropdown = OptionButton.new()
	_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dropdown.item_selected.connect(_on_scope_selected)
	toolbar.add_child(_dropdown)

	var new_btn := Button.new()
	new_btn.text = "Neu"
	new_btn.pressed.connect(_on_new_pressed)
	toolbar.add_child(new_btn)

	var dup_btn := Button.new()
	dup_btn.text = "Dup"
	dup_btn.tooltip_text = "Duplizieren"
	dup_btn.pressed.connect(_on_duplicate_pressed)
	toolbar.add_child(dup_btn)

	root.add_child(HSeparator.new())

	# Scrollbereich
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 4)
	scroll.add_child(form)

	# ── Identifikation
	_add_section(form, "Identifikation")
	_scope_name_edit = _add_lineedit_row(form, "Name")

	# ── Aktivierung
	_add_section(form, "Aktivierung")

	var zoom_row := HBoxContainer.new()
	form.add_child(zoom_row)
	var zoom_lbl := Label.new()
	zoom_lbl.text = "Zoom:"
	zoom_lbl.custom_minimum_size.x = 90
	zoom_row.add_child(zoom_lbl)
	_zoom_min = _make_spin(-20.0, 20.0, 0.1)
	zoom_row.add_child(_zoom_min)
	var dash := Label.new()
	dash.text = " — "
	zoom_row.add_child(dash)
	_zoom_max = _make_spin(-20.0, 20.0, 0.1)
	zoom_row.add_child(_zoom_max)

	var fokus_lbl := Label.new()
	fokus_lbl.text = "Fokus Tags:"
	form.add_child(fokus_lbl)
	var fokus_grid := GridContainer.new()
	fokus_grid.columns = 2
	form.add_child(fokus_grid)
	_fokus_tags_checks = {}
	for t in FOKUS_TAGS:
		var cb := CheckBox.new()
		cb.text = t
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fokus_grid.add_child(cb)
		_fokus_tags_checks[t] = cb

	# ── Darstellung
	_add_section(form, "Darstellung")

	var exag_row := HBoxContainer.new()
	form.add_child(exag_row)
	var exag_lbl := Label.new()
	exag_lbl.text = "Exaggeration:"
	exag_lbl.custom_minimum_size.x = 90
	exag_row.add_child(exag_lbl)
	_exag_faktor = _make_spin(0.0, 100.0, 0.1)
	_exag_faktor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exag_row.add_child(_exag_faktor)

	# ── Sichtbarkeit
	_add_section(form, "Sichtbarkeit")

	var types_row := HBoxContainer.new()
	form.add_child(types_row)
	_visible_types_checks = {}
	for t in SCOPE_TYPES:
		var cb := CheckBox.new()
		cb.text = t
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		types_row.add_child(cb)
		_visible_types_checks[t] = cb

	_visible_tags_edit = _add_lineedit_row(form, "Vis Tags")
	_visible_zones_edit = _add_lineedit_row(form, "Vis Zones")

	var orbit_row := HBoxContainer.new()
	form.add_child(orbit_row)
	var orbit_lbl := Label.new()
	orbit_lbl.text = "Min Orbit px:"
	orbit_lbl.custom_minimum_size.x = 90
	orbit_row.add_child(orbit_lbl)
	_min_orbit_px = _make_spin(0.0, 1000.0, 0.5)
	_min_orbit_px.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orbit_row.add_child(_min_orbit_px)

	# ── Marker Größen
	_add_section(form, "Marker Größen (px)")

	var labels_row := HBoxContainer.new()
	form.add_child(labels_row)
	var spins_row := HBoxContainer.new()
	form.add_child(spins_row)

	_marker_size_spins = {}
	for t in SCOPE_TYPES:
		var lbl := Label.new()
		lbl.text = t
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		labels_row.add_child(lbl)

		var spin := _make_spin(1.0, 512.0, 1.0)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spins_row.add_child(spin)
		_marker_size_spins[t] = spin

	# Footer
	root.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	root.add_child(footer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.clip_text = true
	footer.add_child(_status_label)

	var save_btn := Button.new()
	save_btn.text = "Speichern"
	save_btn.pressed.connect(_on_save_pressed)
	footer.add_child(save_btn)


func _add_section(parent: Control, title: String) -> void:
	parent.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)


func _add_lineedit_row(parent: Control, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "kommagetrennt"
	row.add_child(edit)
	return edit


func _make_spin(min_val: float, max_val: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	return spin


# ── Scopes laden ──────────────────────────────────────────────────────────────

func _scan_scopes() -> void:
	_dropdown.clear()
	_scope_paths.clear()

	var dir := DirAccess.open(SCOPES_DIR)
	if not dir:
		_set_status("Verzeichnis nicht gefunden")
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			_scope_paths.append(SCOPES_DIR + fname)
			_dropdown.add_item(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()

	if not _scope_paths.is_empty():
		_dropdown.select(0)
		_load_scope(_scope_paths[0])
	else:
		_set_status("Keine Scopes gefunden")


func _load_scope(path: String) -> void:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not res or not res is ScopeConfig:
		_set_status("Fehler beim Laden: " + path.get_file())
		return
	_current_scope = res
	_current_path = path
	_populate_form()
	_set_status("Geladen: " + path.get_file())


func _populate_form() -> void:
	if not _current_scope:
		return
	var s := _current_scope
	_scope_name_edit.text = s.scope_name
	_zoom_min.value = s.zoom_min
	_zoom_max.value = s.zoom_max
	for t in FOKUS_TAGS:
		_fokus_tags_checks[t].button_pressed = t in s.fokus_tags
	_exag_faktor.value = s.exag_faktor
	for t in SCOPE_TYPES:
		_visible_types_checks[t].button_pressed = t in s.visible_types
	_visible_tags_edit.text = ", ".join(s.visible_tags)
	_visible_zones_edit.text = ", ".join(s.visible_zones)
	_min_orbit_px.value = s.min_orbit_px
	for t in SCOPE_TYPES:
		_marker_size_spins[t].value = float(s.marker_sizes.get(t, 16))


# ── Form → Resource ───────────────────────────────────────────────────────────

func _apply_form_to_scope() -> void:
	if not _current_scope:
		return
	var s := _current_scope
	s.scope_name = _scope_name_edit.text.strip_edges()
	s.zoom_min = _zoom_min.value
	s.zoom_max = _zoom_max.value
	var ftags: Array[String] = []
	for t in FOKUS_TAGS:
		if _fokus_tags_checks[t].button_pressed:
			ftags.append(t)
	s.fokus_tags = ftags
	s.exag_faktor = _exag_faktor.value

	var vtypes: Array[String] = []
	for t in SCOPE_TYPES:
		if _visible_types_checks[t].button_pressed:
			vtypes.append(t)
	s.visible_types = vtypes

	s.visible_tags = _parse_tags(_visible_tags_edit.text)
	s.visible_zones = _parse_tags(_visible_zones_edit.text)
	s.min_orbit_px = _min_orbit_px.value

	var sizes := {}
	for t in SCOPE_TYPES:
		sizes[t] = int(_marker_size_spins[t].value)
	s.marker_sizes = sizes


func _parse_tags(text: String) -> Array[String]:
	var result: Array[String] = []
	for part in text.split(","):
		var trimmed := part.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result


# ── Scope erstellen ───────────────────────────────────────────────────────────

func _create_scope(path: String, source: ScopeConfig = null) -> void:
	var s := ScopeConfig.new()
	if source:
		s.scope_name = source.scope_name + " (Kopie)"
		s.zoom_min = source.zoom_min
		s.zoom_max = source.zoom_max
		s.fokus_tags = source.fokus_tags.duplicate()
		s.exag_faktor = source.exag_faktor
		s.visible_types = source.visible_types.duplicate()
		s.visible_tags = source.visible_tags.duplicate()
		s.visible_zones = source.visible_zones.duplicate()
		s.min_orbit_px = source.min_orbit_px
		s.marker_sizes = source.marker_sizes.duplicate()
	else:
		var base := path.get_file().get_basename()
		s.scope_name = base.replace("_", " ").capitalize()
		s.zoom_min = 0.0
		s.zoom_max = 10.0
		s.fokus_tags = []
		s.exag_faktor = 1.0
		s.visible_types = ["star", "planet", "dwarf", "moon", "struct"]
		s.visible_tags = []
		s.visible_zones = []
		s.min_orbit_px = 0.0
		s.marker_sizes = {"star": 128, "planet": 40, "dwarf": 28, "moon": 18, "struct": 16}

	var err := ResourceSaver.save(s, path)
	if err != OK:
		_set_status("Fehler beim Erstellen (Code %d)" % err)
		return

	_scope_paths.append(path)
	_dropdown.add_item(path.get_file().get_basename())
	_dropdown.select(_scope_paths.size() - 1)
	_load_scope(path)


# ── Namens-Dialog ─────────────────────────────────────────────────────────────

func _show_name_dialog(title: String, default_name: String, callback: Callable) -> void:
	var popup := Window.new()
	popup.title = title
	popup.size = Vector2i(360, 110)
	popup.exclusive = true
	popup.transient = true
	add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Dateiname (ohne .tres):"
	vbox.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = default_name
	edit.select_all_on_focus = true
	vbox.add_child(edit)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var cancel := Button.new()
	cancel.text = "Abbrechen"
	cancel.pressed.connect(popup.queue_free)
	btn_row.add_child(cancel)

	var ok := Button.new()
	ok.text = "OK"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		var fname := edit.text.strip_edges()
		if fname.is_empty():
			return
		if not fname.ends_with(".tres"):
			fname += ".tres"
		popup.queue_free()
		callback.call(SCOPES_DIR + fname)
	)
	btn_row.add_child(ok)

	# Enter-Taste bestätigt
	edit.text_submitted.connect(func(_t: String) -> void: ok.emit_signal("pressed"))

	popup.popup_centered()


# ── Signal-Handler ────────────────────────────────────────────────────────────

func _on_scope_selected(index: int) -> void:
	if index < 0 or index >= _scope_paths.size():
		return
	_load_scope(_scope_paths[index])


func _on_save_pressed() -> void:
	if not _current_scope or _current_path.is_empty():
		_set_status("Kein Scope geladen")
		return
	_apply_form_to_scope()
	var err := ResourceSaver.save(_current_scope, _current_path)
	if err == OK:
		_set_status("Gespeichert: " + _current_path.get_file())
	else:
		_set_status("Fehler beim Speichern (Code %d)" % err)


func _on_new_pressed() -> void:
	_show_name_dialog("Neuer Scope", "scope_new", func(path: String) -> void:
		_create_scope(path)
	)


func _on_duplicate_pressed() -> void:
	if not _current_scope:
		_set_status("Kein Scope geladen")
		return
	var default := _current_path.get_file().get_basename() + "_copy"
	_show_name_dialog("Scope duplizieren", default, func(path: String) -> void:
		_create_scope(path, _current_scope)
	)


# ── Hilfsmethoden ─────────────────────────────────────────────────────────────

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
