## MainDisplay
## Haupt-UI Container und Setup-Koordination
## Erweitert: MarginContainer

class_name MainDisplay
extends MarginContainer

## Nodes
@onready var _map_viewer: MapController = $HBoxContainer/MapViewer/Control/SubViewportContainer/SubViewport/MapViewer
@onready var _info_panel: VBoxContainer = $HBoxContainer/InfoPanel

## Private
var _ui_config: UIConfig
var _label_settings: Dictionary = {}

## Public Methods
func setup(model: SolarSystemModel, clock: SimClock, ui_config: UIConfig = null) -> void:
	"""Initialisiert Main Display"""
	# Store UI config
	_ui_config = ui_config
	
	# Setup map viewer
	if _map_viewer:
		_map_viewer.setup(model, clock)
	
	# Apply configuration
	if _ui_config:
		_apply_config()
	
	# Pass label settings to map viewer
	if _label_settings.has("caption"):
		# TODO: _map_viewer.set_marker_label_settings(_label_settings["caption"])
		pass
	
	# Setup info panel
	if _info_panel and _info_panel.has_method("setup"):
		_info_panel.setup(model)
		_pass_settings_to_info_panel()
		
		if _info_panel.has_method("set_map_viewer"):
			_info_panel.set_map_viewer(_map_viewer)

func set_ui_config(config: UIConfig) -> void:
	"""Setzt UI-Konfiguration"""
	_ui_config = config
	if _ui_config:
		_apply_config()

## Private Methods
func _apply_config() -> void:
	"""Wendet UI-Konfiguration an"""
	# TODO: Apply colors from config
	# TODO: Setup label settings from config
	pass

func _apply_colors() -> void:
	"""Veraltet - Verwendung _apply_config()"""
	# TODO: Remove this method after migration
	pass

func _pass_settings_to_info_panel() -> void:
	"""Übergibt Label-Settings an InfoPanel"""
	# TODO: Pass label settings to info panel
	pass
