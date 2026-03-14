extends Node

@export var start_time: float = 60.0 * 60.0 * 24.0 * 7.0 * 52.0 * 3.75


func _ready() -> void:
	print("Main Scene instanziert.")
	# TODO automatisches laden der startzeit funktioniert nicht?
	SimClock.set_sst_s(0.0)
