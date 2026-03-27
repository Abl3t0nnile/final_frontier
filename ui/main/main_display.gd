extends MarginContainer


@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.BLACK
@export var dim_color: Color = Color.DIM_GRAY
@export var light_color: Color = Color.LIGHT_SLATE_GRAY

@export_group("Label Settings")
@export var h1_label_settings: LabelSettings
@export var h2_label_settings: LabelSettings
@export var caption_label_settings: LabelSettings
@export var value_label_settings: LabelSettings

@onready var _map_viewer: MapController = $HBoxContainer/MapViewer/Control/SubViewportContainer/SubViewport/MapViewer
@onready var _info_panel: VBoxContainer = $HBoxContainer/InfoPanel


func setup(model: SolarSystemModel, clock: SimulationClock) -> void:
	_map_viewer.setup(model, clock)
	
	# Apply label colors to settings FIRST
	_apply_colors()
	
	# Pass label settings to map viewer AFTER colors are applied
	if caption_label_settings:
		_map_viewer.set_marker_label_settings(caption_label_settings)
	
	# InfoPanel mit MapController verbinden
	if _info_panel and _info_panel.has_method("setup"):
		_info_panel.setup(model)
		# Pass label settings to InfoPanel
		_pass_settings_to_info_panel()
		# MapViewer-Referenz übergeben
		if _info_panel.has_method("set_map_viewer"):
			_info_panel.set_map_viewer(_map_viewer)
	
	# SidePanel select_body Signal mit MapController verbinden
	if _info_panel.has_signal("select_body"):
		_info_panel.select_body.connect(_map_viewer.select_body)
	
	# Signale verbinden
	_map_viewer.body_selected.connect(_on_body_selected)
	_map_viewer.body_deselected.connect(_on_body_deselected)


func _on_body_selected(body_id: String) -> void:
	_info_panel.visible = true
	if _info_panel.has_method("load_body"):
		_info_panel.load_body(body_id)


func _on_body_deselected() -> void:
	# InfoPanel ausblenden wenn kein Body ausgewählt ist
	_info_panel.visible = false


func select_body(body_id: String) -> void:
	# MapController anweisen, den Body auszuwählen
	_map_viewer.select_body(body_id)


func _apply_colors() -> void:
	# Apply colors to label settings
	_apply_label_colors()


func _apply_label_colors() -> void:
	# Duplicate and apply colors to h1 settings
	if h1_label_settings:
		var h1_settings = h1_label_settings.duplicate()
		h1_settings.font_color = primary_color
		h1_label_settings = h1_settings
	
	# Duplicate and apply colors to h2 settings
	if h2_label_settings:
		var h2_settings = h2_label_settings.duplicate()
		h2_settings.font_color = secondary_color
		h2_label_settings = h2_settings
	
	# Don't apply dim_color to caption_label_settings since they're used for map markers
	# The map controller will apply body type colors instead
	
	# Duplicate and apply colors to value settings
	if value_label_settings:
		var value_settings = value_label_settings.duplicate()
		value_settings.font_color = light_color
		value_label_settings = value_settings


func _pass_settings_to_info_panel() -> void:
	if _info_panel and _info_panel.has_method("apply_label_settings"):
		_info_panel.apply_label_settings(h1_label_settings, h2_label_settings, caption_label_settings, value_label_settings)
