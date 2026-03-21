# star_chart_screen.gd — Star Chart Screen
# Container-UI für die Star Chart. Verwaltet Header, Footer, InfoPanel.
# Die eigentliche Kartenansicht (View) wird später im SubViewport instanziiert.
# Baut die gesamte UI programmatisch in _ready().
# Empfängt sim_clock und solar_system via setup() — Dependency Injection.
class_name StarChartScreen
extends Control

signal body_selected(body_id: String)
signal body_deselected
signal info_panel_toggled(is_visible: bool)


# ─── Konstanten ───────────────────────────────────────────────────────────────

# Chrome — dunkelgrünes UI-Rahmenwerk
const CHROME_BG      := Color(0.118, 0.314, 0.157, 0.40)  # rgba(30,80,40,0.4)
const CHROME_BORDER  := Color(0.118, 0.314, 0.157, 0.40)
const CHROME_LIGHT   := Color(0.118, 0.314, 0.157, 0.25)
const CHROME_SUBTLE  := Color(0.118, 0.314, 0.157, 0.18)
const CHROME_FAINT   := Color(0.118, 0.314, 0.157, 0.08)

# Hintergrund
const BG_MAP   := Color(0.031, 0.047, 0.071, 1.0)  # #080c12
const BG_INFO  := Color(0.047, 0.063, 0.094, 1.0)   # #0c1018
const BG_IMAGE := Color(0.039, 0.063, 0.125, 1.0)   # #0a1020

# Text
const TEXT_BRIGHT  := Color(0.533, 0.800, 0.533, 1.0)  # #88cc88
const TEXT_MID     := Color(0.416, 0.604, 0.416, 1.0)  # #6a9a6a
const TEXT_DIM     := Color(0.353, 0.541, 0.353, 1.0)   # #5a8a5a
const TEXT_DATA    := Color(0.627, 0.800, 0.627, 1.0)   # #a0cca0
const TEXT_LABEL   := Color(0.353, 0.541, 0.353, 1.0)   # #5a8a5a
const SEP_COLOR    := Color(0.227, 0.353, 0.227, 1.0)   # #3a5a3a
const TEXT_CYAN    := Color(0.376, 0.816, 0.941, 1.0)   # #60d0f0

# Layout
const HEADER_HEIGHT   := 32
const FOOTER_HEIGHT   := 28
const INFO_PANEL_WIDTH := 320.0
const STAT_FONT_SIZE  := 12
const LABEL_FONT_SIZE := 9

# Time Scales — Multiplikatoren auf Basis 86400 (1 Tag/s)
const TIME_SCALE_BASE := 86400.0
const TIME_SCALES: Array[Dictionary] = [
	{ "label": "x1",   "mult": 1.0 },
	{ "label": "x10",  "mult": 10.0 },
	{ "label": "x100", "mult": 100.0 },
	{ "label": "x1k",  "mult": 1000.0 },
	{ "label": "x10k", "mult": 10000.0 },
]


# ─── Service-Referenzen ──────────────────────────────────────────────────────

var sim_clock:    SimulationClock  = null
var solar_system: SolarSystemModel = null


# ─── Node-Referenzen (gebaut in _build_ui) ────────────────────────────────────

# Header
var _header_scope_label:  Label = null
var _header_zoom_label:   Label = null
var _header_scale_label:  Label = null
var _header_focus_label:  Label = null
var _info_toggle_btn:     Button = null

# Content
var _content_hbox:        HBoxContainer = null
var _map_panel:           PanelContainer = null
var _viewport_container:  SubViewportContainer = null
var _sub_viewport:        SubViewport = null
var _info_panel:          PanelContainer = null

# InfoPanel — Header
var _info_color_dot:      ColorRect = null
var _info_name_label:     Label = null
var _info_type_label:     Label = null

# InfoPanel — Bild
var _info_image_rect:     TextureRect = null
var _info_image_container: PanelContainer = null

# InfoPanel — Tabs
var _tab_buttons:         Array[Button] = []
var _tab_contents:        Array[Control] = []
var _active_tab:          int = 0

# InfoPanel — Physics Grid
var _physics_grid:        GridContainer = null
# InfoPanel — Orbit Grid
var _orbit_grid:          GridContainer = null
# InfoPanel — Info Text
var _info_text:           RichTextLabel = null

# InfoPanel — Children
var _children_vbox:       VBoxContainer = null
var _children_container:  VBoxContainer = null

# Footer
var _footer_time_label:   Label = null
var _footer_day_label:    Label = null
var _footer_month_label:  Label = null
var _footer_year_label:   Label = null
var _time_scale_buttons:  Array[Button] = []
var _play_pause_btn:      Button = null
var _footer_cursor_label: Label = null


# ─── State ────────────────────────────────────────────────────────────────────

var _selected_body: BodyDef = null
var _info_visible: bool = true
var _current_time_scale_idx: int = 0


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_select_time_scale(0)


func setup(clock: SimulationClock, solar_sys: SolarSystemModel) -> void:
	sim_clock = clock
	solar_system = solar_sys
	sim_clock.sim_clock_tick.connect(_on_sim_tick)
	sim_clock.sim_clock_time_scale_changed.connect(_on_time_scale_changed)
	sim_clock.sim_started.connect(_on_sim_started)
	sim_clock.sim_stopped.connect(_on_sim_stopped)
	_sync_time_scale_display()
	_update_play_pause_display()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — für die View
# ═══════════════════════════════════════════════════════════════════════════════

func get_sub_viewport() -> SubViewport:
	return _sub_viewport


func update_header_info(scope_name: String, scale_exp: float, mkm_per_px: float) -> void:
	if _header_scope_label:
		_header_scope_label.text = "Scope: %s" % scope_name
	if _header_zoom_label:
		_header_zoom_label.text = "Zoom: %.1f" % scale_exp
	if _header_scale_label:
		_header_scale_label.text = "%.2f Mkm/px" % mkm_per_px


func update_focus_body(body_name: String) -> void:
	if _header_focus_label:
		_header_focus_label.text = "Fokus: %s" % body_name if not body_name.is_empty() else ""


func update_cursor_info(world_km: Vector2) -> void:
	if _footer_cursor_label:
		var au_x := world_km.x / 149_597_870.7
		var au_y := world_km.y / 149_597_870.7
		_footer_cursor_label.text = "Cursor: %.2f / %.2f AU" % [au_x, au_y]


func select_body(body: BodyDef) -> void:
	_selected_body = body
	_populate_info_panel(body)
	body_selected.emit(body.id)
	if not _info_visible:
		_toggle_info_panel()


func deselect_body() -> void:
	_selected_body = null
	_clear_info_panel()
	body_deselected.emit()


func is_info_panel_visible() -> bool:
	return _info_visible


# ═══════════════════════════════════════════════════════════════════════════════
# UI-AUFBAU
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	root_vbox.add_child(_build_header())

	_content_hbox = HBoxContainer.new()
	_content_hbox.size_flags_vertical = SIZE_EXPAND_FILL
	_content_hbox.add_theme_constant_override("separation", 0)
	root_vbox.add_child(_content_hbox)

	_content_hbox.add_child(_build_map_panel())
	_content_hbox.add_child(_build_info_panel())

	root_vbox.add_child(_build_footer())


# ── Header ────────────────────────────────────────────────────────────────────

func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = HEADER_HEIGHT
	panel.add_theme_stylebox_override("panel", _make_chrome_box())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# Titel
	var title := _make_label("STAR CHART", TEXT_BRIGHT, 11)
	title.add_theme_constant_override("outline_size", 0)
	hbox.add_child(title)

	hbox.add_child(_make_header_sep())

	_header_scope_label = _make_label("Scope: —", TEXT_MID, 10)
	hbox.add_child(_header_scope_label)

	hbox.add_child(_make_header_sep())

	_header_zoom_label = _make_label("Zoom: —", TEXT_MID, 10)
	hbox.add_child(_header_zoom_label)

	hbox.add_child(_make_header_sep())

	_header_scale_label = _make_label("— Mkm/px", TEXT_MID, 10)
	hbox.add_child(_header_scale_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_header_focus_label = _make_label("", TEXT_MID, 10)
	hbox.add_child(_header_focus_label)

	hbox.add_child(_make_header_sep())

	# Toggle-Button
	_info_toggle_btn = Button.new()
	_info_toggle_btn.text = "INFO  ✕"
	_info_toggle_btn.add_theme_font_size_override("font_size", 9)
	_info_toggle_btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	_info_toggle_btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	_info_toggle_btn.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)
	_info_toggle_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	_info_toggle_btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	_info_toggle_btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	_info_toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_info_toggle_btn.pressed.connect(_toggle_info_panel)
	hbox.add_child(_info_toggle_btn)

	return panel


# ── Map Panel ─────────────────────────────────────────────────────────────────

func _build_map_panel() -> PanelContainer:
	_map_panel = PanelContainer.new()
	_map_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_map_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_map_panel.add_theme_stylebox_override("panel", _make_flat_box(BG_MAP))

	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_map_panel.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.transparent_bg = true
	_viewport_container.add_child(_sub_viewport)

	return _map_panel


# ── Info Panel ────────────────────────────────────────────────────────────────

func _build_info_panel() -> PanelContainer:
	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size.x = INFO_PANEL_WIDTH
	_info_panel.size_flags_horizontal = SIZE_SHRINK_END
	_info_panel.add_theme_stylebox_override("panel", _make_flat_box(BG_INFO, CHROME_BG))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_info_panel.add_child(vbox)

	vbox.add_child(_build_info_body_header())
	vbox.add_child(_build_info_image())
	vbox.add_child(_build_info_tab_bar())
	vbox.add_child(_build_info_tab_content())
	vbox.add_child(_build_info_children())

	return _info_panel


func _build_info_body_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_flat_box(Color.TRANSPARENT, CHROME_LIGHT, 0, 0, 0, 1))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var margin := _wrap_margin(hbox, 10, 10, 14, 14)
	panel.add_child(margin)

	_info_color_dot = ColorRect.new()
	_info_color_dot.custom_minimum_size = Vector2(9, 9)
	_info_color_dot.size_flags_vertical = SIZE_SHRINK_CENTER
	hbox.add_child(_info_color_dot)

	_info_name_label = _make_label("—", Color(0.75, 0.87, 1.0), 12)
	hbox.add_child(_info_name_label)

	_info_type_label = _make_label("", Color(0.35, 0.48, 0.60), 9)
	_info_type_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_info_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_info_type_label)

	return panel


func _build_info_image() -> PanelContainer:
	_info_image_container = PanelContainer.new()
	_info_image_container.custom_minimum_size.y = 120
	_info_image_container.add_theme_stylebox_override("panel", _make_flat_box(BG_IMAGE, CHROME_LIGHT, 0, 0, 0, 1))

	_info_image_rect = TextureRect.new()
	_info_image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_info_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info_image_container.add_child(_info_image_rect)

	return _info_image_container


func _build_info_tab_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_flat_box(Color.TRANSPARENT, CHROME_LIGHT, 0, 0, 0, 1))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	var tab_names := ["Physics", "Orbit", "Info"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_tab_selected.bind(i))
		_tab_buttons.append(btn)
		hbox.add_child(btn)

	return panel


func _build_info_tab_content() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(stack)

	# Tab 0: Physics
	_physics_grid = GridContainer.new()
	_physics_grid.columns = 2
	_physics_grid.add_theme_constant_override("h_separation", 8)
	_physics_grid.add_theme_constant_override("v_separation", 4)
	var physics_margin := _wrap_margin(_physics_grid, 10, 10, 14, 14)
	_tab_contents.append(physics_margin)
	stack.add_child(physics_margin)

	# Tab 1: Orbit
	_orbit_grid = GridContainer.new()
	_orbit_grid.columns = 2
	_orbit_grid.add_theme_constant_override("h_separation", 8)
	_orbit_grid.add_theme_constant_override("v_separation", 4)
	var orbit_margin := _wrap_margin(_orbit_grid, 10, 10, 14, 14)
	_tab_contents.append(orbit_margin)
	stack.add_child(orbit_margin)

	# Tab 2: Info
	_info_text = RichTextLabel.new()
	_info_text.fit_content = true
	_info_text.bbcode_enabled = true
	_info_text.add_theme_font_size_override("normal_font_size", 11)
	_info_text.add_theme_color_override("default_color", Color(0.48, 0.60, 0.48))
	var info_margin := _wrap_margin(_info_text, 10, 10, 14, 14)
	_tab_contents.append(info_margin)
	stack.add_child(info_margin)

	_on_tab_selected(0)
	return scroll


func _build_info_children() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_flat_box(Color.TRANSPARENT, CHROME_LIGHT, 1, 0, 0, 0))

	_children_container = VBoxContainer.new()
	_children_container.add_theme_constant_override("separation", 0)
	var margin := _wrap_margin(_children_container, 10, 12, 14, 14)
	panel.add_child(margin)

	var header := _make_label("CHILDREN", TEXT_LABEL, 8)
	_children_container.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	_children_container.add_child(spacer)

	_children_vbox = VBoxContainer.new()
	_children_vbox.add_theme_constant_override("separation", 3)
	_children_container.add_child(_children_vbox)

	return panel


# ── Footer ────────────────────────────────────────────────────────────────────

func _build_footer() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = FOOTER_HEIGHT
	panel.add_theme_stylebox_override("panel", _make_chrome_box())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	_footer_time_label = _make_label("SST: —", TEXT_MID, 10)
	_footer_time_label.custom_minimum_size.x = 175
	_footer_time_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(_footer_time_label)

	hbox.add_child(_make_header_sep())

	_footer_day_label = _make_label("", TEXT_MID, 10)
	_footer_day_label.custom_minimum_size.x = 22
	_footer_day_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(_footer_day_label)

	var gap_dm := Control.new()
	gap_dm.custom_minimum_size.x = 4
	hbox.add_child(gap_dm)

	_footer_month_label = _make_label("", TEXT_MID, 10)
	_footer_month_label.custom_minimum_size.x = 52
	_footer_month_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(_footer_month_label)

	var gap_my := Control.new()
	gap_my.custom_minimum_size.x = 4
	hbox.add_child(gap_my)

	_footer_year_label = _make_label("", TEXT_DIM, 10)
	_footer_year_label.custom_minimum_size.x = 36
	_footer_year_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(_footer_year_label)

	hbox.add_child(_make_header_sep())

	# Play/Pause
	_play_pause_btn = Button.new()
	_play_pause_btn.text = "▶"
	_play_pause_btn.custom_minimum_size = Vector2(22, 22)
	_play_pause_btn.add_theme_font_size_override("font_size", 9)
	_play_pause_btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	_play_pause_btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	_play_pause_btn.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)
	_play_pause_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	_play_pause_btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	_play_pause_btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	_play_pause_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_play_pause_btn.pressed.connect(_on_play_pause)
	hbox.add_child(_play_pause_btn)

	# Spacer zwischen Play und Time Scales
	var gap := Control.new()
	gap.custom_minimum_size.x = 8
	hbox.add_child(gap)

	# Time-Scale-Buttons
	for i in TIME_SCALES.size():
		var btn := Button.new()
		btn.text = TIME_SCALES[i]["label"]
		btn.custom_minimum_size = Vector2(34, 0)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_time_scale_btn.bind(i))
		_time_scale_buttons.append(btn)
		hbox.add_child(btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_footer_cursor_label = _make_label("", TEXT_DIM, 10)
	hbox.add_child(_footer_cursor_label)

	return panel


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNE LOGIK
# ═══════════════════════════════════════════════════════════════════════════════

# ── Sim-Clock Callbacks ───────────────────────────────────────────────────────

func _on_sim_tick(sst_s: float) -> void:
	if _footer_time_label:
		_footer_time_label.text = "SST: %s" % sim_clock.get_time_stamp_string(sst_s)
	if _footer_day_label:
		var stamp := SimulationClock.get_time_stamp_array(sst_s)
		var date  := sim_clock.get_date(stamp)
		_footer_day_label.text   = "%02d" % date[2]
		_footer_month_label.text = SimulationClock.MONTH_NAMES[date[1] - 1]
		_footer_year_label.text  = "%d" % date[0]


func _on_time_scale_changed(_ts: float) -> void:
	_sync_time_scale_display()


func _on_sim_started() -> void:
	_update_play_pause_display()


func _on_sim_stopped() -> void:
	_update_play_pause_display()


# ── Time Controls ─────────────────────────────────────────────────────────────

func _on_play_pause() -> void:
	if sim_clock:
		sim_clock.toggle()


func _on_time_scale_btn(index: int) -> void:
	_select_time_scale(index)


func _select_time_scale(index: int) -> void:
	_current_time_scale_idx = clampi(index, 0, TIME_SCALES.size() - 1)
	if sim_clock:
		var mult: float = TIME_SCALES[_current_time_scale_idx]["mult"]
		sim_clock.set_time_scale(TIME_SCALE_BASE * mult)
	_sync_time_scale_display()


func _sync_time_scale_display() -> void:
	var active_mult := 1.0
	if sim_clock:
		active_mult = sim_clock.get_time_scale() / TIME_SCALE_BASE

	for i in _time_scale_buttons.size():
		var btn := _time_scale_buttons[i]
		var mult: float = TIME_SCALES[i]["mult"]
		if is_equal_approx(mult, active_mult):
			btn.add_theme_color_override("font_color", TEXT_BRIGHT)
			btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
			_current_time_scale_idx = i
		else:
			btn.add_theme_color_override("font_color", TEXT_DIM)
			btn.add_theme_color_override("font_hover_color", TEXT_MID)


func _update_play_pause_display() -> void:
	if _play_pause_btn == null:
		return
	if sim_clock and sim_clock.is_running():
		_play_pause_btn.text = "▮▮"
	else:
		_play_pause_btn.text = "▶"


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("toggle_sim_clock"):
		_on_play_pause()
	elif event.is_action_pressed("time_scale_1"):
		_select_time_scale(0)
	elif event.is_action_pressed("time_scale_2"):
		_select_time_scale(1)
	elif event.is_action_pressed("time_scale_3"):
		_select_time_scale(2)
	elif event.is_action_pressed("time_scale_4"):
		_select_time_scale(3)
	elif event.is_action_pressed("time_scale_5"):
		_select_time_scale(4)


# ── Info Panel Toggle ─────────────────────────────────────────────────────────

func _toggle_info_panel() -> void:
	_info_visible = not _info_visible
	_info_panel.visible = _info_visible
	_info_toggle_btn.text = "INFO  ✕" if _info_visible else "INFO  ▸"
	info_panel_toggled.emit(_info_visible)


# ── Tab Switching ─────────────────────────────────────────────────────────────

func _on_tab_selected(index: int) -> void:
	_active_tab = index
	for i in _tab_contents.size():
		_tab_contents[i].visible = (i == index)
	for i in _tab_buttons.size():
		if i == index:
			_tab_buttons[i].add_theme_color_override("font_color", TEXT_BRIGHT)
			_tab_buttons[i].add_theme_color_override("font_hover_color", TEXT_BRIGHT)
		else:
			_tab_buttons[i].add_theme_color_override("font_color", TEXT_DIM)
			_tab_buttons[i].add_theme_color_override("font_hover_color", TEXT_MID)


# ── Body-Info befüllen ────────────────────────────────────────────────────────

func _populate_info_panel(body: BodyDef) -> void:
	if body == null:
		_clear_info_panel()
		return

	# Header
	_info_color_dot.color = body.color_rgba
	_info_name_label.text = body.name
	_info_type_label.text = "%s / %s" % [body.type, body.subtype] if not body.subtype.is_empty() else body.type

	# Physics Tab
	_clear_grid(_physics_grid)
	_add_grid_row(_physics_grid, "Radius", _fmt_km(body.radius_km))
	_add_grid_row(_physics_grid, "GM (μ)", _fmt_mu(body.mu_km3_s2))

	# Orbit Tab
	_clear_grid(_orbit_grid)
	if body.motion != null:
		_populate_orbit_tab(body)

	# Info Tab
	_info_text.text = ""

	# Children
	_populate_children(body)


func _populate_orbit_tab(body: BodyDef) -> void:
	match body.motion.model:
		"kepler2d":
			var m := body.motion as Kepler2DMotionDef
			_add_grid_row(_orbit_grid, "Semi-Major (a)", _fmt_km(m.a_km))
			_add_grid_row(_orbit_grid, "Eccentricity (e)", "%.4f" % m.e)
			_add_grid_row(_orbit_grid, "Arg. Periapsis", "%.3f rad" % m.arg_pe_rad)
			_add_grid_row(_orbit_grid, "Mean Anomaly₀", "%.3f rad" % m.mean_anomaly_epoch_rad)
			# Orbitalperiode berechnen, wenn Parent-μ verfügbar
			if solar_system and not body.parent_id.is_empty():
				var parent := solar_system.get_body(body.parent_id)
				if parent and parent.mu_km3_s2 > 0.0:
					var period_s := TAU * sqrt(pow(m.a_km, 3) / parent.mu_km3_s2)
					_add_grid_row(_orbit_grid, "Periode", _fmt_period(period_s))
		"circular":
			var m := body.motion as CircularMotionDef
			_add_grid_row(_orbit_grid, "Orbital Radius", _fmt_km(m.orbital_radius_km))
			_add_grid_row(_orbit_grid, "Phase₀", "%.3f rad" % m.phase_rad)
			if solar_system and not body.parent_id.is_empty():
				var parent := solar_system.get_body(body.parent_id)
				if parent and parent.mu_km3_s2 > 0.0:
					var period_s := TAU * sqrt(pow(m.orbital_radius_km, 3) / parent.mu_km3_s2)
					_add_grid_row(_orbit_grid, "Periode", _fmt_period(period_s))
		"fixed":
			var m := body.motion as FixedMotionDef
			_add_grid_row(_orbit_grid, "Position X", _fmt_km(m.x_km))
			_add_grid_row(_orbit_grid, "Position Y", _fmt_km(m.y_km))
		"lagrange":
			var m := body.motion as LagrangeMotionDef
			_add_grid_row(_orbit_grid, "Lagrange-Punkt", "L%d" % m.point)
			_add_grid_row(_orbit_grid, "Primärkörper", m.primary_id)
			_add_grid_row(_orbit_grid, "Sekundärkörper", m.secondary_id)


func _populate_children(body: BodyDef) -> void:
	# Alte Einträge entfernen
	for child_node in _children_vbox.get_children():
		child_node.queue_free()

	if solar_system == null:
		return

	var children := solar_system.get_child_bodies(body.id)
	if children.is_empty():
		_children_container.visible = false
		return

	_children_container.visible = true
	for child_body in children:
		var row := _make_child_row(child_body)
		_children_vbox.add_child(row)


func _make_child_row(body: BodyDef) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_flat_box(CHROME_FAINT, Color.TRANSPARENT))
	panel.mouse_default_cursor_shape = CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var margin := _wrap_margin(hbox, 4, 4, 7, 7)
	panel.add_child(margin)

	# Icon-Punkt
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = SIZE_SHRINK_CENTER
	dot.color = body.color_rgba
	hbox.add_child(dot)

	var name_lbl := _make_label(body.name, Color(0.54, 0.67, 0.54), 9)
	hbox.add_child(name_lbl)

	var type_lbl := _make_label(body.subtype if not body.subtype.is_empty() else body.type, Color(0.35, 0.48, 0.35), 8)
	type_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(type_lbl)

	# Click-Handler
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_body(body)
	)

	return panel


func _clear_info_panel() -> void:
	_info_color_dot.color = Color(0.3, 0.3, 0.3)
	_info_name_label.text = "—"
	_info_type_label.text = ""
	_clear_grid(_physics_grid)
	_clear_grid(_orbit_grid)
	_info_text.text = ""
	for child_node in _children_vbox.get_children():
		child_node.queue_free()
	_children_container.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# HILFSFUNKTIONEN
# ═══════════════════════════════════════════════════════════════════════════════

# ── Formatting ────────────────────────────────────────────────────────────────

func _fmt_km(km: float) -> String:
	if km >= 1_000_000.0:
		return "%.2f Mkm" % (km / 1_000_000.0)
	elif km >= 1_000.0:
		return "%s km" % _fmt_number(km)
	else:
		return "%.1f km" % km


func _fmt_mu(mu: float) -> String:
	if mu >= 1e9:
		return "%.2e km³/s²" % mu
	elif mu >= 1.0:
		return "%.2f km³/s²" % mu
	else:
		return "%.4f km³/s²" % mu


func _fmt_period(seconds: float) -> String:
	var days := seconds / SimulationClock.SEC_PER_DAY
	if days >= SimulationClock.DAYS_PER_YEAR:
		return "%.1f Jahre" % (days / SimulationClock.DAYS_PER_YEAR)
	elif days >= 1.0:
		return "%.1f Tage" % days
	else:
		return "%.1f Stunden" % (seconds / SimulationClock.SEC_PER_HOUR)


func _fmt_number(n: float) -> String:
	var s := "%d" % int(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0 and s[i] != "-":
			result = "," + result
		result = s[i] + result
		count += 1
	return result


# ── Grid ──────────────────────────────────────────────────────────────────────

func _add_grid_row(grid: GridContainer, property: String, value: String) -> void:
	var lbl_name := _make_label(property, TEXT_LABEL, LABEL_FONT_SIZE)
	grid.add_child(lbl_name)
	var lbl_val := _make_label(value, TEXT_DATA, STAT_FONT_SIZE)
	grid.add_child(lbl_val)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


# ── Label Factory ─────────────────────────────────────────────────────────────

func _make_label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


# ── Header-Separator ──────────────────────────────────────────────────────────

func _make_header_sep() -> Label:
	var sep := Label.new()
	sep.text = "  |  "
	sep.add_theme_color_override("font_color", SEP_COLOR)
	sep.add_theme_font_size_override("font_size", 10)
	return sep


# ── StyleBox-Factories ────────────────────────────────────────────────────────

func _make_chrome_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CHROME_BG
	box.border_color = CHROME_BORDER
	box.border_width_bottom = 1
	box.border_width_top = 1
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _make_flat_box(
	bg: Color,
	border_color: Color = Color.TRANSPARENT,
	border_top: int = 0,
	border_bottom: int = 0,
	border_left: int = 0,
	border_right: int = 0,
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border_color
	box.border_width_top = border_top
	box.border_width_bottom = border_bottom
	box.border_width_left = border_left
	box.border_width_right = border_right
	return box


func _make_btn_style(hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CHROME_LIGHT if hover else Color.TRANSPARENT
	box.border_color = Color(0.314, 0.706, 0.314, 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


# ── Margin Wrapper ────────────────────────────────────────────────────────────

func _wrap_margin(child: Control, top: int, bottom: int, left: int, right: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_child(child)
	return margin
