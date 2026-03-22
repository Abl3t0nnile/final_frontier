class_name MapCameraController
extends Node

# Signale
signal camera_moved
signal zoom_changed(scale_exp: float)
signal empty_click(world_km: Vector2)
signal context_menu_requested(screen_pos: Vector2, world_km: Vector2)

# ─── Abhängigkeiten ────────────────────────────────────────────────────────
var _map_scale: MapScale = null

# ─── Config ────────────────────────────────────────────────────────────────
var _scale_exp_min: float = 1.0
var _scale_exp_max: float = 11.0
var _scale_exp_start: float = 7.5
var _zoom_step: float = 0.08
var _rubber_band_margin: float = 0.5
var _rubber_band_speed: float = 5.0
var _pan_inertia_decay: float = 4.0
var _smooth_zoom_speed: float = 8.0
var _smooth_pan_speed: float = 8.0
var _pan_key_speed_px: float = 400.0
var _zoom_key_speed: float = 1.5

# ─── State ─────────────────────────────────────────────────────────────────
var _world_center_km: Vector2 = Vector2.ZERO
var _scale_exp: float = 7.5
var _target_center_km: Vector2 = Vector2.ZERO
var _target_scale_exp: float = 7.5

# Pan
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_center: Vector2 = Vector2.ZERO
var _pan_velocity: Vector2 = Vector2.ZERO  # km/s

# Fokus-Anker
var _focus_anchor_km: Vector2 = Vector2.ZERO
var _has_focus_anchor: bool = false

# Viewport
var _viewport_size: Vector2 = Vector2(1920.0, 1080.0)

# Klick-Erkennung
var _left_press_pos: Vector2 = Vector2.ZERO
var _left_pressed: bool = false
const _CLICK_MAX_DRAG_PX: float = 4.0

# Änderungs-Tracking für Signale
var _prev_scale_exp: float = -1.0
var _prev_center_km: Vector2 = Vector2(-99999.0, -99999.0)

# Inertia: Velocity-Tracking über Frames
var _prev_target_center_km: Vector2 = Vector2.ZERO


# ─── Setup ─────────────────────────────────────────────────────────────────

func setup(map_scale: MapScale, config: Dictionary = {}) -> void:
	_map_scale = map_scale

	_scale_exp_min      = config.get("scale_exp_min",      1.0)
	_scale_exp_max      = config.get("scale_exp_max",      11.0)
	_scale_exp_start    = config.get("scale_exp_start",    7.5)
	_zoom_step          = config.get("zoom_step",          0.08)
	_rubber_band_margin = config.get("rubber_band_margin", 0.5)
	_rubber_band_speed  = config.get("rubber_band_speed",  5.0)
	_pan_inertia_decay  = config.get("pan_inertia_decay",  4.0)
	_smooth_zoom_speed  = config.get("smooth_zoom_speed",  8.0)
	_smooth_pan_speed   = config.get("smooth_pan_speed",   8.0)
	_pan_key_speed_px   = config.get("pan_key_speed_px",   400.0)
	_zoom_key_speed     = config.get("zoom_key_speed",     1.5)

	_scale_exp         = _scale_exp_start
	_target_scale_exp  = _scale_exp_start
	_world_center_km   = Vector2.ZERO
	_target_center_km  = Vector2.ZERO
	_prev_target_center_km = Vector2.ZERO

	_apply_to_map_scale()


func _ready() -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_viewport_size = get_viewport().get_visible_rect().size


# ─── Process ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _map_scale == null:
		return

	# Immer aktuelle Viewport-Größe lesen — _ready() läuft bevor der SubViewport
	# seine finale Größe hat, daher nie den Cached-Wert von _ready() verwenden.
	_viewport_size = get_viewport().get_visible_rect().size

	_handle_keyboard_input(delta)
	_update_inertia(delta)
	_update_smoothing(delta)
	_apply_to_map_scale()
	_emit_change_signals()

	_prev_target_center_km = _target_center_km


func _update_smoothing(delta: float) -> void:
	# Gummiband: target zurück in Grenzen federn
	var clamped = clamp(_target_scale_exp, _scale_exp_min, _scale_exp_max)
	if not is_equal_approx(_target_scale_exp, clamped):
		_target_scale_exp = lerp(_target_scale_exp, clamped, _rubber_band_speed * delta)

	_scale_exp       = lerp(_scale_exp,       _target_scale_exp,  _smooth_zoom_speed * delta)
	_world_center_km = lerp(_world_center_km, _target_center_km,  _smooth_pan_speed  * delta)


func _update_inertia(delta: float) -> void:
	if _is_panning:
		return
	const THRESHOLD: float = 0.001
	if _pan_velocity.length_squared() > THRESHOLD * THRESHOLD:
		_target_center_km += _pan_velocity * delta
		_pan_velocity = _pan_velocity.lerp(Vector2.ZERO, _pan_inertia_decay * delta)
	else:
		_pan_velocity = Vector2.ZERO


func _handle_keyboard_input(delta: float) -> void:
	var pan_dir := Vector2.ZERO
	if Input.is_action_pressed("cam_pan_up"):    pan_dir.y -= 1.0
	if Input.is_action_pressed("cam_pan_down"):  pan_dir.y += 1.0
	if Input.is_action_pressed("cam_pan_left"):  pan_dir.x -= 1.0
	if Input.is_action_pressed("cam_pan_right"): pan_dir.x += 1.0

	if pan_dir != Vector2.ZERO:
		pan_dir = pan_dir.normalized()
		var km_per_px = _map_scale.get_km_per_px()
		var pan_km = pan_dir * _pan_key_speed_px * km_per_px * delta
		_target_center_km += pan_km
		_pan_velocity = pan_dir * _pan_key_speed_px * km_per_px

	if Input.is_action_pressed("cam_zoom_in"):
		_apply_zoom_delta(-_zoom_key_speed * delta, _viewport_size * 0.5)
	if Input.is_action_pressed("cam_zoom_out"):
		_apply_zoom_delta(_zoom_key_speed * delta, _viewport_size * 0.5)

	if Input.is_action_just_pressed("cam_reset"):
		reset_view()


# ─── Input ─────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _map_scale == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		var km_per_px = _map_scale.get_km_per_px()
		_target_center_km += pg.delta * km_per_px
		_pan_velocity = Vector2.ZERO
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		# factor > 1 = auseinander (reinzoomen), factor < 1 = zusammen (rauszoomen)
		var zoom_delta = -log(mg.factor) / log(10.0) * 3.0
		_apply_zoom_delta(zoom_delta, mg.position)


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse  = mb.position
				_pan_start_center = _target_center_km
				_pan_velocity     = Vector2.ZERO
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				_is_panning = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

		MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_pressed   = true
				_left_press_pos = mb.position
			else:
				if _left_pressed:
					var drag = mb.position.distance_to(_left_press_pos)
					if drag < _CLICK_MAX_DRAG_PX:
						var world_km = _map_scale.screen_to_world(mb.position)
						# Kein Fokus-Anker → Kamera gleitet zum Klickpunkt
						if not _has_focus_anchor:
							pan_to(world_km)
						empty_click.emit(world_km)
				_left_pressed = false

		MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var world_km = _map_scale.screen_to_world(mb.position)
				context_menu_requested.emit(mb.position, world_km)

		MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom_delta(-_zoom_step, mb.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom_delta(_zoom_step, mb.position)


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if not _is_panning:
		return
	var delta_px  = mm.position - _pan_start_mouse
	var km_per_px = _map_scale.get_km_per_px()
	var new_target = _pan_start_center - delta_px * km_per_px
	# Velocity aus Änderung schätzen (für Inertia)
	var dt = get_process_delta_time()
	if dt > 0.0:
		_pan_velocity = (new_target - _target_center_km) / dt
	_target_center_km = new_target


# ─── Zoom-Algorithmus ──────────────────────────────────────────────────────

func _apply_zoom_delta(delta: float, screen_anchor: Vector2) -> void:
	var hard_min = _scale_exp_min - _rubber_band_margin
	var hard_max = _scale_exp_max + _rubber_band_margin

	if _has_focus_anchor:
		# Zoom Richtung Fokus-Anker
		_target_scale_exp = clamp(_target_scale_exp + delta, hard_min, hard_max)
		# Center sanft in Richtung Anker verschieben
		_target_center_km = _target_center_km.lerp(_focus_anchor_km, abs(delta) * 1.5)
	else:
		# Zoom unter Cursor: Weltpunkt unter screen_anchor bleibt stabil
		var world_under_cursor = _map_scale.screen_to_world(screen_anchor)
		_target_scale_exp = clamp(_target_scale_exp + delta, hard_min, hard_max)
		var new_km_per_px = pow(10.0, _target_scale_exp)
		var vp_half       = _viewport_size * 0.5
		# world_under_cursor = new_center + (screen_anchor - vp_half) * new_km_per_px
		_target_center_km = world_under_cursor - (screen_anchor - vp_half) * new_km_per_px


func _apply_to_map_scale() -> void:
	_map_scale.set_scale_exp(_scale_exp)
	var km_per_px = _map_scale.get_km_per_px()
	var vp_half   = _viewport_size * 0.5
	_map_scale.set_origin(_world_center_km - vp_half * km_per_px)


func _emit_change_signals() -> void:
	var changed := false
	if not is_equal_approx(_scale_exp, _prev_scale_exp):
		zoom_changed.emit(_scale_exp)
		_prev_scale_exp = _scale_exp
		changed = true
	if not _world_center_km.is_equal_approx(_prev_center_km):
		_prev_center_km = _world_center_km
		changed = true
	if changed:
		camera_moved.emit()


# ─── Public API ────────────────────────────────────────────────────────────

## Kamera gleitet smooth zum Weltpunkt.
func pan_to(world_km: Vector2) -> void:
	_target_center_km = world_km
	_pan_velocity = Vector2.ZERO

## Kamera springt sofort zum Weltpunkt (kein Smoothing).
func jump_to(world_km: Vector2) -> void:
	_target_center_km = world_km
	_world_center_km  = world_km
	_pan_velocity = Vector2.ZERO

## Kamera zoomt smooth auf gegebenen scale_exp.
func zoom_to(target_scale_exp: float) -> void:
	_target_scale_exp = target_scale_exp

## Zurück zu Startposition + Start-Zoom (smooth).
func reset_view() -> void:
	_target_center_km = Vector2.ZERO
	_target_scale_exp = _scale_exp_start
	_pan_velocity = Vector2.ZERO

## Zoom-Anker setzen — Mausrad/Q/E zoomen auf diesen Weltpunkt.
func set_focus_anchor(world_km: Vector2) -> void:
	_focus_anchor_km  = world_km
	_has_focus_anchor = true
	_pan_velocity = Vector2.ZERO

## Zoom-Anker löschen — Mausrad/Q/E zoomen auf Cursor.
func clear_focus_anchor() -> void:
	_has_focus_anchor = false

func get_world_center() -> Vector2:
	return _world_center_km

func get_scale_exp() -> float:
	return _scale_exp

## Aktuelle Mausposition in Weltkoordinaten (km).
func get_mouse_world_position() -> Vector2:
	if _map_scale == null:
		return Vector2.ZERO
	return _map_scale.screen_to_world(get_viewport().get_mouse_position())

func is_panning() -> bool:
	return _is_panning
