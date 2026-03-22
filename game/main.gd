extends Node

const SimClockScript    := preload("res://core/sim_clock.gd")
const SolarSystemScript := preload("res://core/solar_system_sim.gd")

var sim_clock:    SimulationClock  = null
var solar_system: SolarSystemModel = null


func _ready() -> void:
	print("Main Scene instanziert.")

	# 1. Sim Core
	sim_clock = SimClockScript.new()
	sim_clock.name = "SimClock"
	add_child(sim_clock)
	sim_clock.setup(0.0)

	solar_system = SolarSystemScript.new()
	solar_system.name = "SolarSystem"
	add_child(solar_system)
	solar_system.setup(sim_clock)

	# 2. Solar Map UI initialisieren
	var solar_map = $SolarMap
	solar_map.setup(solar_system, sim_clock)

	# 3. Simulation starten
	sim_clock.start()
