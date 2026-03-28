## DataLoader
## Hybrid-Laden von JSON und .tres Dateien
## Erweitert: Node

class_name DataLoader
extends Node

## Public Methods
func load_core_data(path: String) -> Array[BodyDef]:
	"""Lädt BodyDef Daten aus JSON"""
	# TODO: Load and parse JSON file
	return []

func load_component(path: String) -> GameDataComponent:
	"""Lädt GameDataComponent aus .tres Datei"""
	# TODO: Load .tres resource
	return null

func load_all_components(directory: String) -> Array[GameDataComponent]:
	"""Lädt alle Components aus Ordner"""
	# TODO: Scan directory and load all .tres files
	return []

func save_component(component: GameDataComponent, path: String) -> void:
	"""Speichert GameDataComponent als .tres"""
	# TODO: Save resource to file
	pass
