extends MarginContainer


@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.BLACK
@export var dim_color: Color = Color.DIM_GRAY
@export var light_color: Color = Color.LIGHT_SLATE_GRAY

@onready var _map_viewer: MapController = $HBoxContainer/MapViewer/Control/SubViewportContainer/SubViewport/MapViewer


func setup(model: SolarSystemModel, clock: SimulationClock) -> void:
	_map_viewer.setup(model, clock)
