extends Node

const SimClockScript    := preload("res://core/sim_clock.gd")
const SolarSystemScript := preload("res://core/solar_system_sim.gd")

@export var bodies_data_path:  String = "res://data/solar_system_data.json"
@export var structs_data_path: String = "res://data/struct_data.json"
@export var start_sst_s: float = 0.0

var sim_clock:         SimulationClock  = null
var solar_system:      SolarSystemModel = null


func _ready() -> void:
	print("Main Scene instanziert.")

	# 1. Sim Core
	sim_clock = SimClockScript.new()
	sim_clock.name = "SimClock"
	add_child(sim_clock)
	sim_clock.setup(start_sst_s)

	solar_system = SolarSystemScript.new()
	solar_system.name = "SolarSystem"
	add_child(solar_system)
	solar_system.setup(sim_clock, bodies_data_path, structs_data_path)
