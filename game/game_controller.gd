## GameController
## Orchestrates the game initialization sequence and manages app state.
## State machine: LOADING → READY → RUNNING
##
## LOADING: Lädt Daten, baut Simulation auf. Loading-Screen-Animation läuft parallel.
## READY:   Beide done → Karte wird aufgebaut, SolarMap an StarChart übergeben.
## RUNNING: GameClock startet, Spiel läuft.

class_name GameController
extends Node

enum State { LOADING, READY, RUNNING }

signal data_ready
signal game_started

## Inspector-Referenzen (im Editor setzen)
@export var solar_map_scene:  PackedScene = null
@export var planet_view_scene: PackedScene = null
@export var start_chart: Node = null
@export var loading_screen: CanvasLayer = null
@export var almanac_scene: PackedScene = null

var state: State = State.LOADING

var _solar_map:   Node = null
var _planet_view: Node = null
var _data_loaded: bool = false
var _animation_done: bool = false


func _ready() -> void:
	if loading_screen and loading_screen.has_signal("animation_finished"):
		loading_screen.animation_finished.connect(_on_animation_finished)
	else:
		_animation_done = true

	_solar_map = solar_map_scene.instantiate()

	_load_data()
	_build_sim()
	_data_loaded = true
	data_ready.emit()
	_check_transition()


func _process(delta: float) -> void:
	if state == State.RUNNING:
		GameClock.advance_time(delta)


## Initialisierungs-Phasen

func _load_data() -> void:
	var loader := DataLoader.new()
	var bodies: Array[BodyDef] = loader.load_core_data()
	for body in bodies:
		GameRegistry.register_game_object(GameObject.new().init(body))

	# Almanach-Content laden und als Components anhängen
	var almanach_data := loader.load_almanach_content()
	for id: String in almanach_data["bodies"]:
		var obj: GameObject = GameRegistry.get_game_object(id)
		if obj:
			obj.add_component("almanach", almanach_data["bodies"][id])
	
	# Almanac instanziieren und Concepts injizieren
	if almanac_scene:
		var almanac = almanac_scene.instantiate()
		almanac.set_concepts(almanach_data["concepts"])
		# TODO: Almanac in UI-Struktur einhängen (abhängig von StarChart-Setup)


func _build_sim() -> void:
	GameClock.init(false)
	GameClock.setup(0.0)
	GameClock.set_time_scale(_solar_map.time_scale_initial)
	SolarSystem.setup(GameClock, GameRegistry.get_all_body_defs())


## State-Übergänge

func _on_animation_finished() -> void:
	_animation_done = true
	_check_transition()


func _check_transition() -> void:
	if _data_loaded and _animation_done:
		_enter_ready()


func _enter_ready() -> void:
	state = State.READY
	# Deferred: sicherstellen dass StartChart._ready() durch ist
	call_deferred("_build_map")


func _build_map() -> void:
	start_chart.receive_solar_map(_solar_map)
	if planet_view_scene:
		_planet_view = planet_view_scene.instantiate()
		start_chart.receive_planet_view(_planet_view)
	_enter_running()


func _enter_running() -> void:
	state = State.RUNNING
	if loading_screen:
		loading_screen.hide()
	GameClock.start()
	game_started.emit()
