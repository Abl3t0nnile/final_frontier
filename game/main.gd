## Main
## App-Einstiegspunkt. Simulation und Karte werden von StartChart → SolarMap aufgebaut.

extends Node


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
