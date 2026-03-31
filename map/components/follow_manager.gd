## FollowManager
## Steuert das Kamera-Tracking für verfolgte Entitäten.
## Animiert die Kamera zum Ziel mit distanzbasierter Dauer.

class_name FollowManager
extends Node

signal follow_started(id: String)
signal follow_stopped()

## Animation Config
var anim_duration_min: float = 0.2
var anim_duration_max: float = 1.5
var anim_distance_ref: float = 20000.0  # Referenz-Distanz in px für max Duration

var _target_id: String           = ""
var _map_transform: MapTransform = null
var _model: SolarSystemModel     = null
var _tween: Tween                = null
var _is_animating: bool          = false
var _anim_start_pos: Vector2     = Vector2.ZERO


func setup(map_transform: MapTransform, model: SolarSystemModel) -> void:
	_map_transform = map_transform
	_model         = model


func start_following(entity_id: String) -> void:
	_target_id = entity_id
	_start_camera_animation()
	follow_started.emit(entity_id)


func stop_following() -> void:
	if _target_id == "":
		return
	_cancel_animation()
	_target_id = ""
	follow_stopped.emit()


func update_camera_position() -> void:
	if _target_id == "" or _model == null or _map_transform == null:
		return
	if _is_animating:
		return  # Animation läuft, nicht direkt setzen
	var pos_px := _map_transform.km_to_px(_model.get_body_position(_target_id))
	_map_transform.focus_on(pos_px)


func get_target() -> String:
	return _target_id


func is_following() -> bool:
	return _target_id != ""


func _start_camera_animation() -> void:
	if _model == null or _map_transform == null:
		return
	_cancel_animation()
	
	_anim_start_pos = _map_transform.cam_pos_px
	var target_pos := _map_transform.km_to_px(_model.get_body_position(_target_id))
	var distance := (target_pos - _anim_start_pos).length()
	
	# Dauer basierend auf Distanz (logarithmisch skaliert für große Distanzen)
	var t := clampf(log(distance + 1.0) / log(anim_distance_ref + 1.0), 0.0, 1.0)
	var duration := lerpf(anim_duration_min, anim_duration_max, t)
	
	_is_animating = true
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUART)
	_tween.tween_method(_animate_to_target, 0.0, 1.0, duration)
	_tween.finished.connect(_on_animation_finished)


func _animate_to_target(progress: float) -> void:
	if _target_id == "" or _model == null:
		return
	# Zielposition aktualisieren (Körper bewegt sich während Animation)
	var target_pos := _map_transform.km_to_px(_model.get_body_position(_target_id))
	# Interpolieren von Startposition zum aktuellen Ziel
	var new_pos := _anim_start_pos.lerp(target_pos, progress)
	_map_transform.focus_on(new_pos)


func _on_animation_finished() -> void:
	_is_animating = false
	_tween = null
	# Finale Position setzen
	if _target_id != "":
		var pos_px := _map_transform.km_to_px(_model.get_body_position(_target_id))
		_map_transform.focus_on(pos_px)


func _cancel_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_is_animating = false
