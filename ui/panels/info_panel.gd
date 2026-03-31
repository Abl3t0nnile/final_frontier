## InfoPanel
## Display information about selected objects
## Extends: VBoxContainer

class_name InfoPanel
extends VBoxContainer

## Public Properties
var selected_object: GameObject : get = get_selected_object

## Signals
signal location_requested(location_id: String)
signal trade_requested(ware_id: String)

## Private
var _selected_object: GameObject
var _map_viewer: MapController

## Public Methods
func display_object(obj: GameObject) -> void:
	"""Display information about GameObject"""
	_selected_object = obj
	
	# Clear current display
	_clear_display()
	
	# Display basic info
	_display_basic_info(obj)
	
	# Display component-specific data
	if obj.has_component("exploration"):
		show_exploration_data(obj.get_component("exploration"))
	
	if obj.has_component("trading"):
		show_trading_data(obj.get_component("trading"))
	
	if obj.has_component("mission"):
		# TODO: Display mission data
		pass

func show_exploration_data(_component: ExplorationComponent) -> void:
	"""Display exploration data"""
	# TODO: Display exploration information
	pass

func show_trading_data(_component: TradingComponent) -> void:
	"""Display trading data"""
	# TODO: Display trading information
	pass

func set_map_viewer(map_viewer: MapController) -> void:
	"""Set map viewer reference"""
	_map_viewer = map_viewer

## Private Methods
func _clear_display() -> void:
	"""Clear current display"""
	# TODO: Clear all child widgets
	pass

func _display_basic_info(_obj: GameObject) -> void:
	"""Display basic information"""
	# TODO: Display name, type, position, etc.
	pass

## Getters
func get_selected_object() -> GameObject:
	return _selected_object
