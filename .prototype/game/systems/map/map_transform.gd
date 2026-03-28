# res://game/map/map_transform.gd
# Koordinatentransformation und Kamera-Input des MapViewer.
# Kapselt Skalierung (km → px) und Kameraposition gemeinsam,
# da Zoom-auf-Cursor beide Werte atomar verändern muss.
# Konfiguration kommt vom MapController (keine eigenen Exports).

class_name MapTransform
extends Node

signal zoom_changed(km_per_px: float)
signal camera_moved(cam_pos_px: Vector2)
signal panned


enum ScaleMode { LINEAR, LOG }

# --- Zoom als Exponent: km_per_px = 10^zoom_exp (gesetzt vom MapController) ---
var zoom_exp_min: float  = 3.0    # 10^3  = 1.000 km/px
var zoom_exp_max: float  = 10.0   # 10^10 km/px
var zoom_exp_step: float = 0.1    # Exponent-Delta pro Mausrad-Schritt

# Rubber-Band (in Exponent-Einheiten)
var zoom_overshoot: float         = 0.5
var zoom_overshoot_damping: float = 0.25
var zoom_spring: float            = 12.0
var zoom_hold_interval: float     = 0.07

# Presets als Exponenten  [6 → Monde, 7 → Inneres, 8 → Planeten, 9 → Kuiper, 0 → Alles]
var scale_presets: Array[float] = [3.7, 5.7, 6.7, 7.7, 8.7]

# --- Pan ---
var move_speed_px_s: float = 500.0
var move_accel: float      = 14.0
var move_decel: float      = 18.0

# --- Zustand ---
var scale_mode: ScaleMode      = ScaleMode.LINEAR
var exaggeration_factor: float = 1.0
var zoom_exp: float            = 6.7
var km_per_px: float           = pow(10.0, 6.7)
var cam_pos_px: Vector2        = Vector2.ZERO

# Log-Parameter
var log_base: float             = 10.0
var log_ref_distance_km: float  = 149_597_870.7  # 1 AU

var _drag_active: bool         = false
var _drag_moved: bool          = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2   = Vector2.ZERO
var _move_velocity: Vector2    = Vector2.ZERO
var _zoom_hold_timer: float    = 0.0


# ---------------------------------------------------------------------------
# Koordinaten-Mathematik
# ---------------------------------------------------------------------------

func km_to_px(pos_km: Vector2) -> Vector2:
	match scale_mode:
		ScaleMode.LINEAR:
			return pos_km / km_per_px
		ScaleMode.LOG:
			return _log_transform(pos_km)
		_:
			return pos_km / km_per_px


func px_to_km(pos_px: Vector2) -> Vector2:
	return pos_px * km_per_px


func km_to_px_batch(positions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in positions:
		result[id] = km_to_px(positions[id])
	return result


func km_distance_to_px(km: float) -> float:
	return km / km_per_px


func get_km_per_px() -> float:
	return km_per_px


func set_km_per_px(value: float) -> void:
	# Konvertiere km_per_px zu zoom_exp
	zoom_exp = log(value) / log(10.0)
	zoom_exp = clamp(zoom_exp, zoom_exp_min, zoom_exp_max)
	km_per_px = pow(10.0, zoom_exp)
	zoom_changed.emit(km_per_px)


func _log_transform(pos_km: Vector2) -> Vector2:
	var distance_km := pos_km.length()
	if distance_km < 0.001:
		return Vector2.ZERO
	var direction := pos_km / distance_km
	var scale_factor := log_ref_distance_km / km_per_px
	var distance_px := log_base * log(1.0 + distance_km / log_ref_distance_km) * scale_factor
	return direction * distance_px


# ---------------------------------------------------------------------------
# Kameraposition
# ---------------------------------------------------------------------------

func focus_on(pos_px: Vector2) -> void:
	cam_pos_px = pos_px
	camera_moved.emit(cam_pos_px)


func focus_on_smooth(pos_px: Vector2) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(focus_on, cam_pos_px, pos_px, 0.35)


func focus_on_smooth_scaled(pos_px: Vector2, base_duration: float = 0.35) -> void:
	var distance := cam_pos_px.distance_to(pos_px)
	# Skaliere die Dauer mit der Entfernung (logarithmische Skalierung)
	var distance_factor := log(1.0 + distance / 100.0) / log(2.0)
	var duration: float = base_duration * clamp(distance_factor, 0.5, 3.0)
	
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(focus_on, cam_pos_px, pos_px, duration)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_handle_wasd(delta)
	_handle_zoom_keys(delta)
	_handle_zoom_spring(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _drag_active:
		_handle_drag_motion(event as InputEventMouseMotion)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		_handle_key(event as InputEventKey)


func _handle_wasd(delta: float) -> void:
	var target_dir := Vector2.ZERO
	if Input.is_action_pressed("cam_pan_up"):    target_dir.y -= 1.0
	if Input.is_action_pressed("cam_pan_down"):  target_dir.y += 1.0
	if Input.is_action_pressed("cam_pan_left"):  target_dir.x -= 1.0
	if Input.is_action_pressed("cam_pan_right"): target_dir.x += 1.0

	var target_vel: Vector2 = target_dir.normalized() * move_speed_px_s \
		if target_dir != Vector2.ZERO else Vector2.ZERO
	var t: float = move_accel if target_dir != Vector2.ZERO else move_decel
	_move_velocity = _move_velocity.lerp(target_vel, clamp(t * delta, 0.0, 1.0))

	if _move_velocity.length_squared() < 0.25:
		_move_velocity = Vector2.ZERO
		return

	cam_pos_px += _move_velocity * delta
	camera_moved.emit(cam_pos_px)
	panned.emit()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, -1)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			_drag_active = event.pressed
			if event.pressed:
				_drag_start_mouse = event.position
				_drag_start_cam   = cam_pos_px
				_drag_moved       = false


func _handle_drag_motion(event: InputEventMouseMotion) -> void:
	if not _drag_moved:
		_drag_moved = true
		panned.emit()
	cam_pos_px = _drag_start_cam - (event.position - _drag_start_mouse)
	camera_moved.emit(cam_pos_px)


func _handle_zoom_keys(delta: float) -> void:
	var zi: bool = Input.is_action_pressed("cam_zoom_in")
	var zo: bool = Input.is_action_pressed("cam_zoom_out")
	if not zi and not zo:
		_zoom_hold_timer = 0.0
		return
	_zoom_hold_timer -= delta
	if _zoom_hold_timer > 0.0:
		return
	_zoom_hold_timer = zoom_hold_interval
	var vp_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if zi:
		_zoom_at(vp_center, -1)
	else:
		_zoom_at(vp_center, 1)


func _handle_key(event: InputEventKey) -> void:
	if event.is_action("cam_reset"):
		_reset_camera()
		get_viewport().set_input_as_handled()
	else:
		match event.keycode:
			KEY_6: _apply_preset(0)
			KEY_7: _apply_preset(1)
			KEY_8: _apply_preset(2)
			KEY_9: _apply_preset(3)
			KEY_0: _apply_preset(4)


# ---------------------------------------------------------------------------
# Zoom
# ---------------------------------------------------------------------------

func _zoom_at(screen_pos: Vector2, direction: int) -> void:
	var old_km_px: float = km_per_px
	var delta_exp: float = zoom_exp_step * float(direction)

	# Rubber-Band: Schritt dämpfen wenn bereits außerhalb der Grenze
	if (zoom_exp < zoom_exp_min and direction < 0) or (zoom_exp > zoom_exp_max and direction > 0):
		delta_exp *= zoom_overshoot_damping

	zoom_exp  = clamp(zoom_exp + delta_exp, zoom_exp_min - zoom_overshoot, zoom_exp_max + zoom_overshoot)
	km_per_px = pow(10.0, zoom_exp)

	if is_equal_approx(km_per_px, old_km_px):
		return

	# Punkt unter dem Cursor bleibt stationär
	var vp_center: Vector2    = get_viewport().get_visible_rect().size * 0.5
	var mouse_offset: Vector2 = screen_pos - vp_center
	var ratio: float          = old_km_px / km_per_px
	cam_pos_px = (cam_pos_px + mouse_offset) * ratio - mouse_offset

	zoom_changed.emit(km_per_px)
	camera_moved.emit(cam_pos_px)


# BUG: _handle_zoom_spring ändert km_per_px jedes Frame, emittiert aber kein camera_moved.
# Ohne Follow-Target wird WorldRoot.position dabei nicht nachgeführt → Körperpositionen
# und WorldRoot laufen auseinander → sichtbares Zittern bei engem Zoom.
# Außerdem geht der Zoom-Ankerpunkt (Cursorposition beim Scrollen) während der Spring-Animation
# verloren, weil cam_pos_px nicht proportional mitgezogen wird.
# Fix: Zoom-Ankerpunkt (Weltposition in km + Screen-Offset) in _zoom_at speichern und in
# _handle_zoom_spring cam_pos_px darüber rekonstruieren + camera_moved emittieren.
# Achtung: Naiver Fix halbiert die Framerate weil zoom_changed + camera_moved pro Frame
# den gesamten Update-Zyklus (Marker, Orbits, Belts, Zones, Culling) doppelt auslösen.
# Benötigt: Update-Zyklus entkoppeln oder camera_moved im Spring weglassen und stattdessen
# WorldRoot direkt in _handle_zoom_spring repositionieren.
func _handle_zoom_spring(delta: float) -> void:
	var target_exp: float = clamp(zoom_exp, zoom_exp_min, zoom_exp_max)
	if abs(zoom_exp - target_exp) < 0.001:
		if not is_equal_approx(zoom_exp, target_exp):
			zoom_exp  = target_exp
			km_per_px = pow(10.0, zoom_exp)
			zoom_changed.emit(km_per_px)
		return
	zoom_exp  = lerpf(zoom_exp, target_exp, clamp(zoom_spring * delta, 0.0, 1.0))
	km_per_px = pow(10.0, zoom_exp)
	zoom_changed.emit(km_per_px)


func _apply_preset(index: int) -> void:
	zoom_exp  = scale_presets[index]
	km_per_px = pow(10.0, zoom_exp)
	zoom_changed.emit(km_per_px)
	camera_moved.emit(cam_pos_px)


func _reset_camera() -> void:
	cam_pos_px = Vector2.ZERO
	zoom_exp   = scale_presets[2]
	km_per_px  = pow(10.0, zoom_exp)
	zoom_changed.emit(km_per_px)
	camera_moved.emit(cam_pos_px)
