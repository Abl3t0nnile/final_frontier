## GameController
## Orchestrates the game initialization sequence and manages app state.
## State machine: LOADING → READY → RUNNING
##
## LOADING: Lädt Daten, baut Simulation auf. Boot-Animation läuft im StartScreen.
## READY:   Karte wird aufgebaut, SolarMap an StarChart übergeben.
## RUNNING: GameClock startet, Spiel läuft.

class_name GameController
extends Node

enum State { LOADING, READY, RUNNING }

signal data_ready
signal game_started

## Inspector-Referenzen (im Editor setzen)
@export var solar_map_scene:   PackedScene = null
@export var planet_view_scene: PackedScene = null
@export var start_chart:       Node = null
@export var start_screen:      CanvasLayer = null
@export var almanac_scene:     PackedScene = null

var state: State = State.LOADING

var _solar_map:        Node = null
var _planet_view:      Node = null
var _almanac_concepts: Dictionary = {}


func _ready() -> void:
	if start_screen:
		start_screen.start_requested.connect(_start_game)


func _process(delta: float) -> void:
	if state == State.RUNNING:
		GameClock.advance_time(delta)


## Wird durch das Start-Signal des StartScreens ausgelöst.
## Lädt alle Daten synchron, sammelt Boot-Nachrichten, spielt Animation ab.
func _start_game() -> void:
	state = State.LOADING
	var boot_log: Array[Dictionary] = []

	boot_log.append(_msg("// FINAL FRONTIER SYSTEMSTART //", "header"))
	boot_log.append(_msg("", "info"))
	boot_log.append(_msg("Initialisiere Datensystem...", "info"))

	var loader := DataLoader.new()
	var bodies: Array[BodyDef] = loader.load_core_data()

	boot_log.append(_msg("Lade Himmelskörper [" + str(bodies.size()) + "]", "info"))
	for body in bodies:
		GameRegistry.register_game_object(GameObject.new().init(body))
		boot_log.append(_msg("  " + _type_tag(body.type) + "  " + body.name, "item"))

	boot_log.append(_msg("Lade Almanach-Daten...", "info"))
	var almanach_data := loader.load_almanach_content()
	for id: String in almanach_data["bodies"]:
		var obj: GameObject = GameRegistry.get_game_object(id)
		if obj:
			obj.add_component("almanach", almanach_data["bodies"][id])
	_almanac_concepts = almanach_data["concepts"]

	boot_log.append(_msg("Initialisiere Simulation...", "info"))
	_solar_map = solar_map_scene.instantiate()
	_build_sim()

	boot_log.append(_msg("", "info"))
	boot_log.append(_msg("SYSTEM BEREIT. STARTE...", "success"))

	data_ready.emit()

	if start_screen:
		start_screen.play_boot_sequence(boot_log)
		await start_screen.boot_complete

	state = State.READY
	call_deferred("_build_map")


func _build_sim() -> void:
	GameClock.init(false)
	GameClock.setup(0.0)
	GameClock.set_time_scale(_solar_map.time_scale_initial)
	SolarSystem.setup(GameClock, GameRegistry.get_all_body_defs())


func _build_map() -> void:
	start_chart.receive_solar_map(_solar_map)
	if planet_view_scene:
		_planet_view = planet_view_scene.instantiate()
		start_chart.receive_planet_view(_planet_view)
	var almanac := start_chart.get_node_or_null("UILayer/MainDisplay/VFrame/BodyPanel/Almanac") as Almanac
	if almanac:
		almanac.set_concepts(_almanac_concepts)
	_enter_running()


func _enter_running() -> void:
	state = State.RUNNING
	if start_screen:
		start_screen.hide()
	GameClock.start()
	game_started.emit()


## Hilfsfunktionen

func _msg(text: String, type: String) -> Dictionary:
	return {"text": text, "type": type}


func _type_tag(type: String) -> String:
	match type:
		"star":   return "[STAR]"
		"planet": return "[PLAN]"
		"moon":   return "[MOON]"
		"belt":   return "[BELT]"
		_:        return "[" + type.to_upper().left(4) + "]"
