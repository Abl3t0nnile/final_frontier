## MapTransform
## Coordinate transformation and camera control with zoom/pan input

class_name MapTransform
extends Node

## Signals
signal zoom_changed(km_per_px: float)
signal camera_moved(cam_pos_px: Vector2)
signal panned()

## Zoom
var zoom_exp_min: float = 3.0
var zoom_exp_max: float = 10.0
var zoom_exp_step: float = 0.1
var zoom_overshoot: float = 0.5
var zoom_overshoot_damping: float = 0.25
var zoom_spring: float = 12.0
var zoom_hold_interval: float = 0.08

## Scale presets
var scale_presets: Array[float] = [3.7, 5.7, 6.5, 7.7, 8.7]

## Pan
var move_speed_px_s: float = 500.0
var move_accel: float = 14.0
var move_decel: float = 18.0

## State
var zoom_exp: float = 6.5
var km_per_px: float = 1000000.0
var cam_pos_px: Vector2 = Vector2.ZERO

## Private
var _pan_velocity: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2 = Vector2.ZERO
var _zoom_hold_timer: float = 0.0

## Coordinate transformation
func km_to_px(pos_km: Vector2) -> Vector2:
	return Vector2(pos_km.x / km_per_px, pos_km.y / km_per_px)

func px_to_km(pos_px: Vector2) -> Vector2:
	return Vector2(pos_px.x * km_per_px, pos_px.y * km_per_px)

func km_distance_to_px(km: float) -> float:
	return km / km_per_px

func set_km_per_px(value: float) -> void:
	km_per_px = maxf(value, 0.000001)
	zoom_exp = log(km_per_px) / log(10.0)

## Fokus
func focus_on(pos: Vector2) -> void:
	cam_pos_px = pos
	camera_moved.emit(cam_pos_px)

func focus_on_smooth(pos: Vector2) -> void:
	var tw := get_tree().create_tween()
	tw.tween_method(_set_cam_pos_emit, cam_pos_px, pos, 0.6)

func focus_on_smooth_scaled(pos: Vector2) -> void:
	var dist := (cam_pos_px - pos).length()
	var duration := clampf(dist / 2000.0, 0.3, 2.0)
	var tw := get_tree().create_tween()
	tw.tween_method(_set_cam_pos_emit, cam_pos_px, pos, duration)

func _set_cam_pos_emit(pos: Vector2) -> void:
	cam_pos_px = pos
	camera_moved.emit(cam_pos_px)

## _process: WASD-Pan + Zoom-Keys + Spring-Rubber-Band
func _process(delta: float) -> void:
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("cam_pan_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("cam_pan_down"):
		input_dir.y += 1.0
	if Input.is_action_pressed("cam_pan_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("cam_pan_right"):
		input_dir.x += 1.0

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		_pan_velocity = _pan_velocity.lerp(input_dir * move_speed_px_s, move_accel * delta)
	else:
		_pan_velocity = _pan_velocity.lerp(Vector2.ZERO, move_decel * delta)

	if _pan_velocity.length_squared() > 0.25:
		cam_pos_px += _pan_velocity * delta
		camera_moved.emit(cam_pos_px)
		if input_dir != Vector2.ZERO:
			panned.emit()

	# Zoom-Keys mit Hold-Interval
	var zoom_dir := 0
	if Input.is_action_pressed("cam_zoom_in"):
		zoom_dir = -1
	elif Input.is_action_pressed("cam_zoom_out"):
		zoom_dir = 1

	if zoom_dir != 0:
		_zoom_hold_timer += delta
		if _zoom_hold_timer >= zoom_hold_interval:
			_zoom_hold_timer = 0.0
			var vp_size := get_viewport().get_visible_rect().size
			_zoom_at(vp_size * 0.5, zoom_dir)
	else:
		_zoom_hold_timer = 0.0

	# Rubber-Band Spring
	var clamped := clampf(zoom_exp, zoom_exp_min, zoom_exp_max)
	if not is_equal_approx(clamped, zoom_exp):
		zoom_exp = lerpf(zoom_exp, clamped, zoom_spring * delta)
		km_per_px = pow(10.0, zoom_exp)
		zoom_changed.emit(km_per_px)

## _input: Maus-Scroll und Linksklick-Drag
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, -1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start_mouse = mb.position
				_drag_start_cam = cam_pos_px
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var delta_screen := mm.position - _drag_start_mouse
		cam_pos_px = _drag_start_cam - delta_screen
		camera_moved.emit(cam_pos_px)
		panned.emit()
		get_viewport().set_input_as_handled()

## _unhandled_input: Preset-Keys (1-5 für die 5 Presets)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	for i in range(scale_presets.size()):
		if event.is_action_pressed("cam_zoom_preset_%d" % (i + 1)):
			zoom_exp = scale_presets[i]
			km_per_px = pow(10.0, zoom_exp)
			zoom_changed.emit(km_per_px)
			get_viewport().set_input_as_handled()
			return

## Zoom-at-Cursor Logik
func _zoom_at(screen_pos: Vector2, direction: int) -> void:
	var old_km_px: float = km_per_px
	var delta_exp: float = zoom_exp_step * float(direction)

	# Rubber-band dampening outside limits
	if (zoom_exp < zoom_exp_min and direction < 0) or (zoom_exp > zoom_exp_max and direction > 0):
		delta_exp *= zoom_overshoot_damping

	zoom_exp = clamp(zoom_exp + delta_exp, zoom_exp_min - zoom_overshoot, zoom_exp_max + zoom_overshoot)
	km_per_px = pow(10.0, zoom_exp)

	if is_equal_approx(km_per_px, old_km_px):
		return

	# Punkt unter dem Cursor bleibt stationär
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var mouse_offset := screen_pos - vp_center
	var ratio: float = old_km_px / km_per_px
	cam_pos_px = (cam_pos_px + mouse_offset) * ratio - mouse_offset

	zoom_changed.emit(km_per_px)
	camera_moved.emit(cam_pos_px)
