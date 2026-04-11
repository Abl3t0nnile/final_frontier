## SolarMap
## Eigenständige Szene: lädt Daten, baut Simulation und Karte auf.
## Wird in einen SubViewport instanziert — kein externer Setup nötig.
## Fassade für StarChart-UI: verwaltet Exports und leitet an Controller weiter.

extends Node

## Konfiguration – Zoom
@export_group("Zoom")
@export var zoom_exp_min: float      = 3.0
@export var zoom_exp_max: float      = 10.0
@export var zoom_exp_step: float     = 0.1
@export var zoom_exp_initial: float  = 6.5
@export var zoom_scale_presets: Array[float] = [3.7, 5.7, 6.5, 7.7, 8.7]
@export_range(0.1, 2.0, 0.1) var pinch_zoom_sensitivity: float = 0.5

## Konfiguration – Pan
@export_group("Pan")
@export var move_speed_px_s: float = 500.0
@export var move_accel: float      = 14.0
@export var move_decel: float      = 18.0

## Konfiguration – Culling
@export_group("Culling")
@export var culling_min_parent_dist_px: float  = 32.0

## Feature Flags
@export_group("Features")
@export var has_orbits: bool  = true
@export var has_grid: bool    = true
@export var grid_color: Color = Color(0.29, 1.0, 0.54, 1.0)
@export var has_belts: bool   = true
@export var has_zones: bool   = true
@export var has_comets: bool  = true

## Interaction
@export_group("Interaction")
@export var markers_clickable: bool = true
@export var markers_hoverable: bool = true

## Konfiguration – Markers
@export_group("Markers")
@export_subgroup("Zoom Thresholds")
@export var marker_zoom_thresholds: Vector2 = Vector2(5.0, 7.0)  # x=nah, y=fern
@export_subgroup("Sizes (nah, mittel, fern)")
@export var marker_sizes_star:   Vector3i = Vector3i(40, 28, 18)
@export var marker_sizes_planet: Vector3i = Vector3i(28, 20, 14)
@export var marker_sizes_moon:   Vector3i = Vector3i(18, 12, 8)
@export var marker_sizes_struct: Vector3i = Vector3i(14, 10, 6)
@export var marker_sizes_comet:  Vector3i = Vector3i(14, 10, 6)
@export_subgroup("Selection Ring")
@export var marker_selection_color: Color  = Color(1.0, 1.0, 1.0, 0.9)
@export var marker_selection_width: float  = 2.0
@export var marker_pinned_color: Color     = Color(1.0, 1.0, 1.0, 0.35)
@export var marker_pinned_width: float     = 1.5
@export_subgroup("Label")
@export var marker_label_offset: Vector2   = Vector2(4.0, -8.0)

## Konfiguration – Orbits
@export_group("Orbits")
@export_subgroup("Line Width")
@export var orbit_width_default: float   = 1.0
@export var orbit_width_highlight: float = 2.0
@export var orbit_width_dimmed: float    = 0.5
@export_subgroup("Alpha")
@export var orbit_alpha_default: float   = 0.2
@export var orbit_alpha_highlight: float = 0.6
@export var orbit_alpha_dimmed: float    = 0.08
@export_subgroup("Color Overrides (optional)")
@export var orbit_color_override_enabled: bool = false
@export var orbit_color_planet: Color    = Color.CYAN
@export var orbit_color_moon: Color      = Color.GRAY
@export var orbit_color_dwarf: Color     = Color.ORANGE
@export var orbit_color_struct: Color    = Color.YELLOW
@export var orbit_color_comet: Color     = Color(0.75, 0.88, 1.0)

## Konfiguration – Belts
@export_group("Belts")
@export_subgroup("Zoom Thresholds (exp)")
@export var belt_zoom_exp_near: float = 4.0
@export var belt_zoom_exp_mid: float  = 6.35
@export var belt_zoom_exp_far: float  = 8.7
@export_subgroup("Point Sizes")
@export var belt_point_size_near: float = 3.0
@export var belt_point_size_mid: float  = 2.0
@export var belt_point_size_far: float  = 1.0

## Konfiguration – Zeit
@export_group("Time")
@export var time_scale_initial: float = 86400.0  # 1 Tag pro Sekunde
@export var time_scale_presets: Array[float] = [
	1.0,      # 1 Sekunde
	60.0,     # 1 Minute
	3600.0,   # 1 Stunde
	86400.0,  # 1 Tag
	518400.0, # 6 Tage (eigene Woche)
	2592000.0, # 30 Tage
	7776000.0, # 90 Tage
	15552000.0, # 180 Tage
	31104000.0  # 360 Tage
]
@export var time_scale_labels: Array[String] = [
	"1 sec", "1 min", "1 hour", "1 day", "1 week", "30 days", "90 days", "180 days", "360 days"
]


## Signals (forwarded für StarChart-UI)
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)
signal marker_unhovered(id: String)
signal body_pinned(id: String)
signal body_unpinned(id: String)
signal marker_right_clicked(id: String)

signal time_changed(sim_time: float)
signal time_scale_changed(scale: float)
signal clock_started()
signal clock_paused()
signal clock_mode_changed(is_live: bool)  # true = live mode, false = scrub mode

signal zoom_changed(km_per_px: float)
signal camera_moved(pos_px: Vector2)

@onready var _map_controller: SolarMapController = $SolarMapController


func setup() -> void:
	_map_controller.apply_config(_build_config())
	_map_controller.setup(SolarSystem, GameClock, GameRegistry, null)
	_map_controller.center_on_body("sun")
	_connect_signals()
	_map_controller.get_map_clock().enter_live_mode(GameClock)


## Public API for parent scenes

# Time control
func play() -> void:
	GameClock.start()

func pause() -> void:
	GameClock.stop()

func toggle_playback() -> void:
	if GameClock.is_running:
		GameClock.stop()
	else:
		GameClock.start()

func set_time_scale(scale: float) -> void:
	GameClock.set_time_scale(scale)

func get_time_scale() -> float:
	return GameClock.get_time_scale()

func set_sim_time(time: float) -> void:
	GameClock.setup(time)

func get_sim_time() -> float:
	return GameClock.get_current_time()

func get_time_scale_presets() -> Array[float]:
	return time_scale_presets

func get_time_scale_labels() -> Array[String]:
	return time_scale_labels

# Clock mode control
func set_live_mode() -> void:
	"""Activate live mode (tracks simulation clock)"""
	_map_controller.get_map_clock().enter_live_mode(GameClock)
	clock_mode_changed.emit(true)

func set_scrub_mode() -> void:
	"""Activate scrub mode (independent time control)"""
	_map_controller.get_map_clock().exit_live_mode()
	clock_mode_changed.emit(false)

func is_live_mode() -> bool:
	return _map_controller.get_map_clock().is_live()

# Scrub functions for scrub mode
func scrub_forward(seconds: float) -> void:
	if not is_live_mode():
		var map_clock = _map_controller.get_map_clock()
		if map_clock:
			var current_time = map_clock.get_current_time()
			map_clock.set_time(current_time + seconds)

func scrub_backward(seconds: float) -> void:
	if not is_live_mode():
		var map_clock = _map_controller.get_map_clock()
		if map_clock:
			var current_time = map_clock.get_current_time()
			map_clock.set_time(current_time - seconds)





# Map navigation
func focus_body(id: String) -> void:
	_map_controller.focus_body(id)


func set_zoom_preset(index: int) -> void:
	if index >= 0 and index < zoom_scale_presets.size():
		var map_transform := _map_controller.get_map_transform()
		if map_transform:
			map_transform.set_zoom_exp(zoom_scale_presets[index])


func zoom_in() -> void:
	var map_transform := _map_controller.get_map_transform()
	if map_transform:
		map_transform.zoom_in()


func zoom_out() -> void:
	var map_transform := _map_controller.get_map_transform()
	if map_transform:
		map_transform.zoom_out()


func get_zoom_level() -> float:
	var map_transform := _map_controller.get_map_transform()
	return map_transform.km_per_px if map_transform else 0.0


func get_zoom_presets() -> Array[float]:
	return zoom_scale_presets


# Body-Interaktion
func select_body(id: String) -> void:
	_map_controller.select_body(id)


func deselect_body() -> void:
	_map_controller.deselect_body()


func get_selected_body() -> String:
	return _map_controller.get_selected_body()


func pin_body(id: String) -> void:
	var interaction := _map_controller.get_interaction_manager()
	if interaction:
		interaction.pin_entity(id)


func unpin_body(id: String) -> void:
	var interaction := _map_controller.get_interaction_manager()
	if interaction:
		interaction.unpin_entity(id)


func is_body_pinned(id: String) -> bool:
	var interaction := _map_controller.get_interaction_manager()
	return interaction.get_pinned_entities().has(id) if interaction else false


func get_body_data(id: String) -> BodyDef:
	return SolarSystem.get_body(id)


# Interne Referenzen (für fortgeschrittene Nutzung)
func get_map_controller() -> SolarMapController:
	return _map_controller


func get_clock() -> SimClock:
	return GameClock


func get_solar_system() -> SolarSystemModel:
	return SolarSystem


func get_game_object_registry() -> GameObjectRegistry:
	return GameRegistry


func get_map_clock() -> MapClock:
	return _map_controller.get_map_clock()


# New MapClock control API
func map_play() -> void:
	_map_controller.get_map_clock().play()

func map_pause() -> void:
	_map_controller.get_map_clock().pause()

func map_reverse() -> void:
	_map_controller.get_map_clock().reverse()

func map_set_time_scale(scale: float) -> void:
	_map_controller.get_map_clock().set_time_scale(scale)

func map_scrub_to(sst_s: float) -> void:
	_map_controller.get_map_clock().set_time(sst_s)

func map_go_live() -> void:
	_map_controller.get_map_clock().enter_live_mode(GameClock)




func _connect_signals() -> void:
	# Body events direct from InteractionManager
	var interaction := _map_controller.get_interaction_manager()
	interaction.body_selected.connect(body_selected.emit)
	interaction.body_deselected.connect(body_deselected.emit)
	interaction.marker_hovered.connect(marker_hovered.emit)
	interaction.marker_unhovered.connect(marker_unhovered.emit)
	interaction.body_pinned.connect(body_pinned.emit)
	interaction.body_unpinned.connect(body_unpinned.emit)
	
	# Right-click on marker from MapController
	_map_controller.marker_right_clicked.connect(marker_right_clicked.emit)

	# Time events from clock
	GameClock.tick.connect(func(t: float): time_changed.emit(t))
	GameClock.time_scale_changed.connect(func(s: float): time_scale_changed.emit(s))
	GameClock.started.connect(clock_started.emit)
	GameClock.paused.connect(clock_paused.emit)

	# Map events from MapTransform (via controller)
	var map_transform := _map_controller.get_map_transform()
	map_transform.zoom_changed.connect(zoom_changed.emit)
	map_transform.camera_moved.connect(camera_moved.emit)


func _build_config() -> Dictionary:
	return {
		# Zoom
		"zoom_exp_min": zoom_exp_min,
		"zoom_exp_max": zoom_exp_max,
		"zoom_exp_step": zoom_exp_step,
		"zoom_exp_initial": zoom_exp_initial,
		"scale_presets": zoom_scale_presets,
		"pinch_zoom_sensitivity": pinch_zoom_sensitivity,
		# Pan
		"move_speed_px_s": move_speed_px_s,
		"move_accel": move_accel,
		"move_decel": move_decel,
		# Culling
		"culling_min_parent_dist_px": culling_min_parent_dist_px,
		# Markers
		"marker_zoom_thresholds": marker_zoom_thresholds,
		"marker_sizes_star": marker_sizes_star,
		"marker_sizes_planet": marker_sizes_planet,
		"marker_sizes_moon": marker_sizes_moon,
		"marker_sizes_struct": marker_sizes_struct,
		"marker_sizes_comet": marker_sizes_comet,
		"marker_selection_color": marker_selection_color,
		"marker_selection_width": marker_selection_width,
		"marker_pinned_color": marker_pinned_color,
		"marker_pinned_width": marker_pinned_width,
		"marker_label_offset": marker_label_offset,
		# Orbits
		"orbit_width_default": orbit_width_default,
		"orbit_width_highlight": orbit_width_highlight,
		"orbit_width_dimmed": orbit_width_dimmed,
		"orbit_alpha_default": orbit_alpha_default,
		"orbit_alpha_highlight": orbit_alpha_highlight,
		"orbit_alpha_dimmed": orbit_alpha_dimmed,
		"orbit_color_override_enabled": orbit_color_override_enabled,
		"orbit_color_planet": orbit_color_planet,
		"orbit_color_moon": orbit_color_moon,
		"orbit_color_dwarf": orbit_color_dwarf,
		"orbit_color_struct": orbit_color_struct,
		"orbit_color_comet": orbit_color_comet,
		# Belts
		"belt_zoom_exp_near": belt_zoom_exp_near,
		"belt_zoom_exp_mid": belt_zoom_exp_mid,
		"belt_zoom_exp_far": belt_zoom_exp_far,
		"belt_point_size_near": belt_point_size_near,
		"belt_point_size_mid": belt_point_size_mid,
		"belt_point_size_far": belt_point_size_far,
		# Feature Flags
		"has_orbits": has_orbits,
		"has_grid": has_grid,
		"grid_color": grid_color,
		"has_belts": has_belts,
		"has_zones": has_zones,
		"has_comets": has_comets,
		# Interaction
		"markers_clickable": markers_clickable,
		"markers_hoverable": markers_hoverable,
	}
