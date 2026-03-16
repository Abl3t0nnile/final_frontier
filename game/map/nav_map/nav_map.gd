# nav_map.gd
class_name NavMap
extends BaseMap

# ------------------------------------------------------------------------------------------------------------------
# NavMap-spezifische Konfiguration
# ------------------------------------------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------------------------------------------
# Kamera
# ------------------------------------------------------------------------------------------------------------------

const INFO_PANEL_WIDTH := 280.0

# Referenz auf die NavMap-Kamera
var _camera: Camera2D = null
# Aktueller Kamera-Offset durch InfoPanel
var _panel_camera_offset: float = 0.0
# Zoom: Tween auf _scale_exp, additiv akkumuliert. Neuer Scroll killt laufenden Tween und startet neu.
var _zoom_tween:            Tween   = null
var _zoom_target_exp:       float   = 0.0
var _zoom_active:           bool    = false
var _zoom_anchor_world_km:  Vector2 = Vector2.ZERO
var _zoom_anchor_screen:    Vector2 = Vector2.ZERO


# ------------------------------------------------------------------------------------------------------------------
# Fokus-System
# ------------------------------------------------------------------------------------------------------------------

# ID des aktuell fokussierten Körpers, leer wenn kein Fokus
var _focused_body_id: String = ""

# ------------------------------------------------------------------------------------------------------------------
# Darstellungsmodi
# ------------------------------------------------------------------------------------------------------------------

# Ob die logarithmische Darstellung aktiv ist
var _log_scale_active: bool = false
# Einstellbarer Faktor für die Log-Skala
var _log_scale_factor: float = 1.0

# ------------------------------------------------------------------------------------------------------------------
# Initialisierung
# ------------------------------------------------------------------------------------------------------------------

@onready var _info_panel: PanelContainer = $UILayer/BodyInfoPanel

func _ready() -> void:
	_camera = $NavMapCamera
	super._ready()
	_zoom_target_exp = _scale_exp
	_info_panel.connect("focus_requested", _on_panel_focus_requested)

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

# ------------------------------------------------------------------------------------------------------------------
# Subklassen-Hooks (Override von BaseMap)
# ------------------------------------------------------------------------------------------------------------------

## Gibt den minimal erlaubten scale_exp zurück.
func _get_min_scale_exp() -> float:
	return min_scale_exp

## Gibt den maximal erlaubten scale_exp zurück.
func _get_max_scale_exp() -> float:
	return max_scale_exp

## Sichtbarkeit: LOD basierend auf Orbit-Pixelgröße.
func _is_body_visible(body: BodyDef) -> bool:
	return _get_orbit_size_px(body) >= marker_cull_threshold_px

## Orbit-Sichtbarkeit: nur wenn Orbit groß genug in Pixeln.
func _is_orbit_visible(body: BodyDef) -> bool:
	return _get_orbit_size_px(body) >= orbit_cull_threshold_px

## Löst nach jedem Positions-Update das Culling aus.
func _post_position_update() -> void:
	_update_visibility()

## Positions-Transformation: linear oder logarithmisch, je nach Modus.
func calculate_screen_position(world_pos_km: Vector2) -> Vector2:
	if _log_scale_active:
		return _apply_log_transform(world_pos_km)
	return world_pos_km * _px_per_km

## Input-Verarbeitung pro Frame.
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

# ------------------------------------------------------------------------------------------------------------------
# Kamera-Steuerung
# ------------------------------------------------------------------------------------------------------------------

## Bewegt die Kamera um den gegebenen Offset in Screen-Koordinaten.
func _pan_camera(offset: Vector2) -> void:
	_camera.position += offset
	_update_visibility()

## Zoom: Ziel akkumulieren. Läuft noch kein Zyklus, wird einer gestartet.
func _zoom_at_position(zoom_delta: float, screen_pos: Vector2) -> void:
	_zoom_target_exp = clamp(_zoom_target_exp + zoom_delta, _get_min_scale_exp(), _get_max_scale_exp())
	var viewport_center := get_viewport_rect().size * 0.5
	if _focused_body_id != "":
		_zoom_anchor_world_km = SolarSystem.get_body_position(_focused_body_id)
	else:
		_zoom_anchor_world_km = (_camera.position + (screen_pos - viewport_center)) / _px_per_km
	_zoom_anchor_screen = screen_pos
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_active = true
	_zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_zoom_tween.tween_method(_apply_zoom_step, _scale_exp, _zoom_target_exp, zoom_tween_duration)
	_zoom_tween.finished.connect(func() -> void: _zoom_active = false)

func _apply_zoom_step(new_exp: float) -> void:
	set_scale_exp(new_exp)
	var viewport_center := get_viewport_rect().size * 0.5
	if _focused_body_id != "":
		_camera.position = calculate_screen_position(_zoom_anchor_world_km) + Vector2(_panel_camera_offset, 0.0)
	else:
		_camera.position = calculate_screen_position(_zoom_anchor_world_km) - (_zoom_anchor_screen - viewport_center)

## Setzt den Kamera-Offset für das InfoPanel (mit Tween auf _panel_camera_offset).
func _set_panel_camera_offset(offset: float) -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "_panel_camera_offset", offset, 0.25)

# ------------------------------------------------------------------------------------------------------------------
# Fokus-System
# ------------------------------------------------------------------------------------------------------------------

## Fokussiert den Körper mit der gegebenen ID. Kamera zentriert und folgt.
func focus_on_body(body_id: String) -> void:
	_focused_body_id = body_id

## Fokussiert den Körper und zoomt auf passenden Maßstab.
func focus_and_zoom_to_body(body_id: String) -> void:
	_focused_body_id = body_id
	var body := SolarSystem.get_body(body_id)
	if body.parent_id != "":
		var orbit_path := SolarSystem.get_local_orbit_path(body_id)
		if not orbit_path.is_empty():
			var orbit_radius_km := orbit_path[0].length()
			var viewport_half_px := get_viewport_rect().size.y * 0.3
			var target_exp := log(orbit_radius_km / viewport_half_px) / log(10.0)
			set_scale_exp(target_exp)

## Löst den aktuellen Fokus auf.
func release_focus() -> void:
	if _focused_body_id == "":
		return
	_focused_body_id = ""
	_close_info_panel()

## Gibt die ID des aktuell fokussierten Körpers zurück (leer wenn kein Fokus).
func get_focused_body_id() -> String:
	return _focused_body_id

## Prüft, ob der Fokus bei aktuellem Zoom-Level aufgelöst werden muss.
func _check_focus_release() -> void:
	if _focused_body_id == "":
		return
	var body := SolarSystem.get_body(_focused_body_id)
	if _get_orbit_size_px(body) < focus_release_threshold_px:
		release_focus()

## Wird pro Frame aufgerufen wenn ein Körper fokussiert ist. Kamera folgt der Position.
func _update_camera_follow() -> void:
	if _focused_body_id == "":
		return
	var world_pos := SolarSystem.get_body_position(_focused_body_id)
	var screen_pos := calculate_screen_position(world_pos)
	_camera.position = screen_pos + Vector2(_panel_camera_offset, 0.0)
	_update_visibility()

# ------------------------------------------------------------------------------------------------------------------
# Darstellungsmodi
# ------------------------------------------------------------------------------------------------------------------

## Schaltet die logarithmische Darstellung ein oder aus.
func toggle_log_scale() -> void:
	_log_scale_active = not _log_scale_active
	_on_scale_changed()

## Setzt den Log-Skala-Faktor.
func set_log_scale_factor(factor: float) -> void:
	_log_scale_factor = max(0.1, factor)
	if _log_scale_active:
		_on_scale_changed()

## Gibt zurück, ob die Log-Skala aktiv ist.
func is_log_scale_active() -> bool:
	return _log_scale_active

## Berechnet die logarithmisch transformierte Position für eine Welt-Position.
func _apply_log_transform(world_pos_km: Vector2) -> Vector2:
	var distance_km := world_pos_km.length()
	if distance_km == 0.0:
		return Vector2.ZERO
	var log_distance := _log_scale_factor * log(1.0 + distance_km) / log(10.0)
	return world_pos_km.normalized() * log_distance * _px_per_km

# ------------------------------------------------------------------------------------------------------------------
# Orbit-Übertreibung (TBD laut SPEC)
# ------------------------------------------------------------------------------------------------------------------

## Berechnet den Übertreibungsfaktor für die Kinder des fokussierten Körpers.
func _calculate_orbit_exaggeration(_parent_body: BodyDef) -> float:
	return 1.0

## Prüft, ob die Übertreibung die Kontextgrenze überschreiten würde.
func _is_exaggeration_within_bounds(_parent_body: BodyDef, _factor: float) -> bool:
	return true

# ------------------------------------------------------------------------------------------------------------------
# Sichtbarkeitslogik
# ------------------------------------------------------------------------------------------------------------------

## Berechnet die Orbit-Größe eines Körpers in Pixeln bei aktuellem Maßstab.
func _get_orbit_size_px(body: BodyDef) -> float:
	if body.parent_id == "":
		return INF
	var path := SolarSystem.get_local_orbit_path(body.id)
	if path.is_empty():
		return 0.0
	return path[0].length() * _px_per_km

## Prüft, ob ein Körper im aktuellen Viewport sichtbar ist.
func _is_in_viewport(screen_pos: Vector2) -> bool:
	if not _camera:
		return true
	var cam_pos := _camera.position
	var half := get_viewport_rect().size * 0.5
	var margin := 64.0
	return abs(screen_pos.x - cam_pos.x) < half.x + margin \
		and abs(screen_pos.y - cam_pos.y) < half.y + margin

## Aktualisiert die Sichtbarkeit aller Körper und Orbits.
func _update_visibility() -> void:
	for body_id in _markers_by_id:
		var body := SolarSystem.get_body(body_id)
		_markers_by_id[body_id].visible = _is_body_visible(body)
	for body_id in _orbit_renderers_by_id:
		var body := SolarSystem.get_body(body_id)
		var should_be_visible := _is_orbit_visible(body)
		var renderer: OrbitRenderer = _orbit_renderers_by_id[body_id]
		if should_be_visible and not renderer.visible:
			renderer.scale = Vector2.ONE
			renderer.update_scale(_px_per_km)
		renderer.visible = should_be_visible

# ------------------------------------------------------------------------------------------------------------------
# InfoPanel (TBD — Node existiert noch nicht)
# ------------------------------------------------------------------------------------------------------------------

## Öffnet das InfoPanel für den gegebenen Körper.
func _open_info_panel(body_id: String) -> void:
	var body := SolarSystem.get_body(body_id)
	var already_open := _info_panel.visible
	_info_panel.show_body(body)
	if not already_open:
		_set_panel_camera_offset(INFO_PANEL_WIDTH / 2.0)

## Schließt das InfoPanel.
func _close_info_panel() -> void:
	if not _info_panel.visible:
		return
	_info_panel.hide_panel()
	_set_panel_camera_offset(0.0)

# ------------------------------------------------------------------------------------------------------------------
# Input-Handler
# ------------------------------------------------------------------------------------------------------------------

## Verarbeitet unhandled Input (Tastatur, Mausrad).
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

## Callback wenn ein Body-Marker angeklickt wird.
func _on_marker_clicked(body_id: String) -> void:
	focus_on_body(body_id)
	_open_info_panel(body_id)

## Callback wenn ein Body-Marker doppelt angeklickt wird.
func _on_marker_double_clicked(body_id: String) -> void:
	focus_and_zoom_to_body(body_id)
	_open_info_panel(body_id)

## Callback wenn im InfoPanel ein Kind-Button gedrückt wird.
func _on_panel_focus_requested(body_id: String) -> void:
	focus_and_zoom_to_body(body_id)
	_open_info_panel(body_id)
