# nav_map.gd
# Allwissender Sternatlas: freie Kamera, keine physikalischen Wahrnehmungsgrenzen.
# Erste Subklasse der BaseMap. Implementiert LOD-Sichtbarkeit, Fokus-System,
# logarithmische Darstellung und den 3-Phasen-Zoom:
#
# Phase 1 — Vorbereitung: Orbit-Renderer werden in Batches über mehrere Frames für den
#           Ziel-Maßstab vorberechnet. Simulation läuft weiter, Positionen updaten am alten Maßstab.
# Phase 2 — Tween: scale_exp animiert zum Ziel. Orbit-Renderer werden per Node2D.scale
#           visuell interpoliert (kein Redraw). Marker-Positionen animieren normal.
# Phase 3 — Abschluss: Vorberechnete Orbit-Punkte werden angewandt (ein Redraw pro Renderer),
#           Node2D.scale wird zurückgesetzt.
class_name NavMap
extends BaseMap

# ==================================================================================================================
# NavMap-spezifische Konfiguration
# ==================================================================================================================

## Minimaler scale_exp (maximaler Zoom-In)
@export var min_scale_exp: float = 3.0:			set = _set_min_scale_exp
## Maximaler scale_exp (maximaler Zoom-Out)
@export var max_scale_exp: float = 11.0:		set = _set_max_scale_exp
## Animationsdauer des Zoom-Tweens in Sekunden
@export var zoom_tween_duration: float = 0.3:	set = _set_zoom_tween_duration
## Minimale Orbit-Größe in Pixeln, unter der ein Marker ausgeblendet wird
@export var marker_cull_threshold_px: float = 8.0
## Minimale Orbit-Größe in Pixeln, unter der ein Orbit ausgeblendet wird
@export var orbit_cull_threshold_px: float = 8.0
## Minimale Orbit-Größe in Pixeln, unter der der Fokus auf einen Körper aufgelöst wird
@export var focus_release_threshold_px: float = 20.0

# ==================================================================================================================
# Kamera
# ==================================================================================================================

const INFO_PANEL_WIDTH := 280.0

var _camera: Camera2D = null
var _panel_camera_offset: float = 0.0

# ==================================================================================================================
# Zoom-Zustand
# ==================================================================================================================

# Zoom-Tween und Anker
var _zoom_tween:            Tween   = null
var _zoom_target_exp:       float   = 0.0
var _zoom_active:           bool    = false
var _zoom_anchor_world_km:  Vector2 = Vector2.ZERO
var _zoom_anchor_screen:    Vector2 = Vector2.ZERO

# ==================================================================================================================
# Fokus-System
# ==================================================================================================================

var _focused_body_id: String = ""

# ==================================================================================================================
# Darstellungsmodi
# ==================================================================================================================

var _log_scale_active: bool = false
var _log_scale_factor: float = 1.0

# ==================================================================================================================
# LOD-Cache
# ==================================================================================================================

# body_id → Orbit-Radius in km (einmalig beim Build).
var _orbit_radius_km: Dictionary = {}

# ==================================================================================================================
# Initialisierung
# ==================================================================================================================

@onready var _info_panel: PanelContainer = $UILayer/BodyInfoPanel

func _ready() -> void:
	_camera = $NavMapCamera
	super._ready()
	_zoom_target_exp = _scale_exp
	_build_orbit_radius_cache()
	_info_panel.connect("focus_requested", _on_panel_focus_requested)
	orbit_preparation_completed.connect(_on_orbit_preparation_completed)
	orbit_apply_completed.connect(_on_orbit_apply_completed)

func _build_orbit_radius_cache() -> void:
	for body_id in _markers_by_id:
		var body: BodyDef = get_body_def(body_id)
		if body.parent_id == "":
			continue
		var path := SolarSystem.get_local_orbit_path(body_id)
		if path.is_empty():
			_orbit_radius_km[body_id] = 0.0
		else:
			_orbit_radius_km[body_id] = path[0].length()

func _set_min_scale_exp(value: float) -> void:
	min_scale_exp = value
	if is_inside_tree():
		set_scale_exp(_scale_exp)

func _set_max_scale_exp(value: float) -> void:
	max_scale_exp = value
	if is_inside_tree():
		set_scale_exp(_scale_exp)

func _set_zoom_tween_duration(value: float) -> void:
	zoom_tween_duration = value

# ==================================================================================================================
# Subklassen-Hooks (Override von BaseMap)
# ==================================================================================================================

func _get_min_scale_exp() -> float:
	return min_scale_exp

func _get_max_scale_exp() -> float:
	return max_scale_exp

func _is_body_visible(body: BodyDef) -> bool:
	return _get_orbit_size_px(body) >= marker_cull_threshold_px

func _is_orbit_visible(body: BodyDef) -> bool:
	return _get_orbit_size_px(body) >= orbit_cull_threshold_px

func calculate_screen_position(world_pos_km: Vector2) -> Vector2:
	if _log_scale_active:
		return _apply_log_transform(world_pos_km)
	return world_pos_km * _px_per_km

func _process_map_input(delta: float) -> void:
	if not _zoom_active:
		_update_camera_follow()
		_check_focus_release()
	var pan := Vector2.ZERO
	var pan_speed := 500.0
	if Input.is_action_pressed("ui_left"):  pan.x -= pan_speed * delta
	if Input.is_action_pressed("ui_right"): pan.x += pan_speed * delta
	if Input.is_action_pressed("ui_up"):    pan.y -= pan_speed * delta
	if Input.is_action_pressed("ui_down"):  pan.y += pan_speed * delta
	if pan != Vector2.ZERO:
		release_focus()
		_pan_camera(pan)

# ==================================================================================================================
# Kamera-Steuerung
# ==================================================================================================================

func _pan_camera(offset: Vector2) -> void:
	_camera.position += offset
	_update_visibility()

# ==================================================================================================================
# Zoom — Phase 1: Vorbereitung starten
# ==================================================================================================================

## Nimmt Zoom-Input entgegen und startet die Orbit-Vorbereitung.
## Der eigentliche Tween startet erst wenn die Vorbereitung abgeschlossen ist.
## Bei erneutem Scroll während Vorbereitung oder Tween wird das Ziel akkumuliert
## und die Vorbereitung neu gestartet.
func _zoom_at_position(zoom_delta: float, screen_pos: Vector2) -> void:
	_zoom_target_exp = clamp(_zoom_target_exp + zoom_delta, _get_min_scale_exp(), _get_max_scale_exp())

	# Anker berechnen: Punkt unter dem Cursor (oder fokussierter Körper) bleibt stationär
	var viewport_center := get_viewport_rect().size * 0.5
	if _focused_body_id != "":
		_zoom_anchor_world_km = SolarSystem.get_body_position(_focused_body_id)
	else:
		_zoom_anchor_world_km = (_camera.position + (screen_pos - viewport_center)) / _px_per_km
	_zoom_anchor_screen = screen_pos

	# Laufenden Tween abbrechen — Vorbereitung startet neu
	if _zoom_tween:
		_zoom_tween.kill()
		_zoom_tween = null
	_zoom_active = true

	# Orbit-Vorbereitung für Ziel-Maßstab starten (bei Re-Zoom wird die Queue neu gefüllt)
	var target_px_per_km := 1.0 / pow(10.0, _zoom_target_exp)
	begin_orbit_preparation(target_px_per_km)

# ==================================================================================================================
# Zoom — Phase 2: Tween starten (nach Vorbereitung)
# ==================================================================================================================

## Wird aufgerufen wenn BaseMap alle Orbit-Renderer fertig vorberechnet hat.
## Startet den Zoom-Tween, der scale_exp und Kamera-Position animiert.
func _on_orbit_preparation_completed() -> void:
	# Sicherheitscheck: Wenn kein Zoom mehr aktiv ist (z.B. durch cancel), abbrechen
	if not _zoom_active:
		return

	_zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_zoom_tween.tween_method(_apply_zoom_step, _scale_exp, _zoom_target_exp, zoom_tween_duration)
	_zoom_tween.finished.connect(_on_zoom_tween_finished)

## Wird pro Tween-Schritt aufgerufen. Aktualisiert Skalierung, Positionen und
## interpoliert die Orbit-Renderer visuell per Node2D.scale (kein Redraw).
func _apply_zoom_step(new_exp: float) -> void:
	set_scale_exp(new_exp)

	# Orbit-Renderer visuell skalieren: ratio = aktueller Maßstab / gezeichneter Maßstab.
	# Das ist eine reine Transform-Änderung (Node2D.scale), kein Redraw.
	for body_id in _orbit_renderers_by_id:
		var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
		if renderer.visible:
			var drawn := renderer.get_draw_px_per_km()
			if drawn > 0.0:
				var ratio := _px_per_km / drawn
				renderer.scale = Vector2(ratio, ratio)

	# Kamera positionieren: Anker bleibt stationär
	var viewport_center := get_viewport_rect().size * 0.5
	if _focused_body_id != "":
		_camera.position = calculate_screen_position(_zoom_anchor_world_km) + Vector2(_panel_camera_offset, 0.0)
	else:
		_camera.position = calculate_screen_position(_zoom_anchor_world_km) - (_zoom_anchor_screen - viewport_center)

# ==================================================================================================================
# Zoom — Phase 3: Abschluss
# ==================================================================================================================

## Wird aufgerufen wenn der Zoom-Tween abgeschlossen ist.
## Startet die gebatchte Anwendung der vorberechneten Orbit-Punkte.
func _on_zoom_tween_finished() -> void:
	apply_prepared_orbits()
	_zoom_tween = null

## Wird aufgerufen wenn alle Orbit-Renderer ihre vorberechneten Punkte angewandt haben.
## Erst jetzt ist der Zoom-Übergang vollständig abgeschlossen.
func _on_orbit_apply_completed() -> void:
	_zoom_active = false

# ==================================================================================================================
# Kamera-Offset (InfoPanel)
# ==================================================================================================================

func _set_panel_camera_offset(offset: float) -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "_panel_camera_offset", offset, 0.25)

# ==================================================================================================================
# Fokus-System
# ==================================================================================================================

func focus_on_body(body_id: String) -> void:
	_focused_body_id = body_id

func focus_and_zoom_to_body(body_id: String) -> void:
	_focused_body_id = body_id
	var body := get_body_def(body_id)
	if body.parent_id != "":
		var radius_km: float = _orbit_radius_km.get(body_id, 0.0)
		if radius_km > 0.0:
			var viewport_half_px := get_viewport_rect().size.y * 0.3
			var target_exp := log(radius_km / viewport_half_px) / log(10.0)
			set_scale_exp(target_exp)

func release_focus() -> void:
	if _focused_body_id == "":
		return
	_focused_body_id = ""
	_close_info_panel()

func get_focused_body_id() -> String:
	return _focused_body_id

func _check_focus_release() -> void:
	if _focused_body_id == "":
		return
	var body := get_body_def(_focused_body_id)
	if _get_orbit_size_px(body) < focus_release_threshold_px:
		release_focus()

func _update_camera_follow() -> void:
	if _focused_body_id == "":
		return
	var world_pos := SolarSystem.get_body_position(_focused_body_id)
	var screen_pos := calculate_screen_position(world_pos)
	_camera.position = screen_pos + Vector2(_panel_camera_offset, 0.0)

# ==================================================================================================================
# Darstellungsmodi
# ==================================================================================================================

func toggle_log_scale() -> void:
	_log_scale_active = not _log_scale_active
	_on_scale_changed()

func set_log_scale_factor(factor: float) -> void:
	_log_scale_factor = max(0.1, factor)
	if _log_scale_active:
		_on_scale_changed()

func is_log_scale_active() -> bool:
	return _log_scale_active

func _apply_log_transform(world_pos_km: Vector2) -> Vector2:
	var distance_km := world_pos_km.length()
	if distance_km == 0.0:
		return Vector2.ZERO
	var log_distance := _log_scale_factor * log(1.0 + distance_km) / log(10.0)
	return world_pos_km.normalized() * log_distance * _px_per_km

# ==================================================================================================================
# Orbit-Übertreibung (TBD laut SPEC)
# ==================================================================================================================

func _calculate_orbit_exaggeration(_parent_body: BodyDef) -> float:
	return 1.0

func _is_exaggeration_within_bounds(_parent_body: BodyDef, _factor: float) -> bool:
	return true

# ==================================================================================================================
# LOD-Hilfsfunktionen
# ==================================================================================================================

func _get_orbit_size_px(body: BodyDef) -> float:
	if body.parent_id == "":
		return INF
	return _orbit_radius_km.get(body.id, 0.0) * _px_per_km

func _is_in_viewport(screen_pos: Vector2) -> bool:
	if not _camera:
		return true
	var cam_pos := _camera.position
	var half := get_viewport_rect().size * 0.5
	var margin := 64.0
	return abs(screen_pos.x - cam_pos.x) < half.x + margin \
		and abs(screen_pos.y - cam_pos.y) < half.y + margin

# ==================================================================================================================
# InfoPanel
# ==================================================================================================================

func _open_info_panel(body_id: String) -> void:
	var body := get_body_def(body_id)
	var already_open := _info_panel.visible
	_info_panel.show_body(body)
	if not already_open:
		_set_panel_camera_offset(INFO_PANEL_WIDTH / 2.0)

func _close_info_panel() -> void:
	if not _info_panel.visible:
		return
	_info_panel.hide_panel()
	_set_panel_camera_offset(0.0)

# ==================================================================================================================
# Input-Handler
# ==================================================================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_position(-0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_position(0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not event.double_click:
				release_focus()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL:
			_zoom_at_position(-0.1, get_viewport_rect().size * 0.5)
		elif event.keycode == KEY_MINUS:
			_zoom_at_position(0.1, get_viewport_rect().size * 0.5)
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		release_focus()
		_pan_camera(-event.relative)

func _on_marker_clicked(body_id: String) -> void:
	focus_on_body(body_id)
	_open_info_panel(body_id)

func _on_marker_double_clicked(body_id: String) -> void:
	focus_and_zoom_to_body(body_id)
	_open_info_panel(body_id)

func _on_panel_focus_requested(body_id: String) -> void:
	focus_and_zoom_to_body(body_id)
	_open_info_panel(body_id)
