@tool
class_name PlanetViewer
extends Control

@export_group("Texture")
@export var surface_texture: Texture2D:
	set(value):
		surface_texture = value
		_update_material()

@export_group("Clouds")
@export var cloud_texture: Texture2D:
	set(value):
		cloud_texture = value
		_update_material()

@export var cloud_enabled: bool = false:
	set(value):
		cloud_enabled = value
		_set_param("cloud_enabled", cloud_enabled)

@export_range(-3.14159, 3.14159) var cloud_rotation_offset: float = 0.0:
	set(value):
		cloud_rotation_offset = value
		_set_param("cloud_rotation_offset", cloud_rotation_offset)

@export_range(0.0, 1.0) var cloud_transparency: float = 1.0:
	set(value):
		cloud_transparency = value
		_set_param("cloud_transparency", cloud_transparency)

@export_range(0.0, 1.0) var cloud_speed: float = 0.02

@export_group("Sphere")
@export var sphere_size: int = 1024:
	set(value):
		sphere_size = value
		_update_size()

@export_group("Rotation")
@export var drag_sensitivity: float = 0.005
@export var pitch_limit: float = 1.4
@export var auto_rotate: bool = false:
	set(value):
		auto_rotate = value
		if is_inside_tree():
			mouse_filter = Control.MOUSE_FILTER_IGNORE if auto_rotate else Control.MOUSE_FILTER_STOP
@export_range(0.0, 2.0) var auto_rotate_speed: float = 0.15

@export_group("Lighting")
@export var light_direction: Vector3 = Vector3(0.5, -0.3, 0.8):
	set(value):
		light_direction = value
		_set_param("light_dir", light_direction)

@export_group("Dithering")
@export_range(1, 16) var bayer_scale: int = 4:
	set(value):
		bayer_scale = value
		_set_param("bayer_scale", bayer_scale)

@export_range(0.0, 0.5) var black_floor: float = 0.15:
	set(value):
		black_floor = value
		_set_param("black_floor", black_floor)

@export_range(0.5, 1.0) var white_ceil: float = 0.8:
	set(value):
		white_ceil = value
		_set_param("white_ceil", white_ceil)

@export_group("Outline")
@export var outline_enabled: bool = true:
	set(value):
		outline_enabled = value
		_set_param("outline_enabled", outline_enabled)

@export_range(0.0, 0.1) var outline_width: float = 0.02:
	set(value):
		outline_width = value
		_set_param("outline_width", outline_width)

@export_group("Sun")
@export var use_sun_shader: bool = false:
	set(value):
		use_sun_shader = value
		if _sphere_rect != null:
			var shader := load(_get_shader_path()) as Shader
			_material.shader = shader
			_sync_all_params()

@export_range(0.5, 1.0) var sphere_scale: float = 0.8:
	set(value):
		sphere_scale = value
		_set_param("sphere_scale", sphere_scale)

@export_range(0.0, 0.5) var corona_width: float = 0.15:
	set(value):
		corona_width = value
		_set_param("corona_width", corona_width)

@export_range(0.0, 1.0) var corona_density: float = 0.5:
	set(value):
		corona_density = value
		_set_param("corona_density", corona_density)

@export_range(0.0, 10.0) var flicker_speed: float = 2.0:
	set(value):
		flicker_speed = value
		_set_param("flicker_speed", flicker_speed)

@export_range(0.0, 0.5) var flicker_intensity: float = 0.1:
	set(value):
		flicker_intensity = value
		_set_param("flicker_intensity", flicker_intensity)

var _rotation_y: float = 0.0
var _rotation_x: float = 0.0
var _dragging: bool = false
var _cloud_offset: float = 0.0
var _sphere_rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	_setup_sphere()
	if auto_rotate:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if use_sun_shader:
		_set_param("time", Time.get_ticks_msec() / 1000.0)
	elif cloud_enabled and cloud_speed > 0.0:
		_cloud_offset += delta * cloud_speed
		if _cloud_offset > TAU:
			_cloud_offset -= TAU
		_set_param("cloud_rotation_offset", cloud_rotation_offset + _cloud_offset)
	if auto_rotate and not Engine.is_editor_hint():
		_rotation_y += delta * auto_rotate_speed
		_set_param("rotation_y", _rotation_y)


func _setup_sphere() -> void:
	_sphere_rect = ColorRect.new()
	_sphere_rect.name = "SphereRect"
	_sphere_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sphere_rect)

	var shader := load(_get_shader_path()) as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader
	_sphere_rect.material = _material

	mouse_filter = Control.MOUSE_FILTER_STOP

	_update_size()
	_update_material()
	_sync_all_params()


func _get_shader_path() -> String:
	const BASE := "res://assets/shaders/planet/"
	return BASE + ("sun_sphere.gdshader" if use_sun_shader else "planet_sphere.gdshader")


func _set_param(param: String, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)


func _update_size() -> void:
	if _sphere_rect == null:
		return
	_sphere_rect.size = Vector2(sphere_size, sphere_size)
	custom_minimum_size = Vector2(sphere_size, sphere_size)
	size = Vector2(sphere_size, sphere_size)


func _update_material() -> void:
	if _material == null:
		return
	if surface_texture != null:
		_material.set_shader_parameter("surface_texture", surface_texture)
	if cloud_texture != null:
		_material.set_shader_parameter("cloud_texture", cloud_texture)


func _sync_all_params() -> void:
	_set_param("rotation_y", _rotation_y)
	_set_param("rotation_x", _rotation_x)
	_set_param("bayer_scale", bayer_scale)
	_set_param("black_floor", black_floor)
	_set_param("white_ceil", white_ceil)
	_set_param("outline_enabled", outline_enabled)
	_set_param("outline_width", outline_width)
	if use_sun_shader:
		_set_param("sphere_scale", sphere_scale)
		_set_param("corona_width", corona_width)
		_set_param("corona_density", corona_density)
		_set_param("flicker_speed", flicker_speed)
		_set_param("flicker_intensity", flicker_intensity)
	else:
		_set_param("light_dir", light_direction)
		_set_param("cloud_enabled", cloud_enabled)
		_set_param("cloud_rotation_offset", cloud_rotation_offset)
		_set_param("cloud_transparency", cloud_transparency)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var center := size / 2.0
				var offset := mb.position - center
				var radius := float(sphere_size) / 2.0
				if offset.length() <= radius:
					_dragging = true
			else:
				_dragging = false

	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_rotation_y += mm.relative.x * drag_sensitivity
		_rotation_x += mm.relative.y * drag_sensitivity
		_rotation_x = clampf(_rotation_x, -pitch_limit, pitch_limit)
		_set_param("rotation_y", _rotation_y)
		_set_param("rotation_x", _rotation_x)


func set_planet_rotation(yaw: float, pitch: float) -> void:
	_rotation_y = yaw
	_rotation_x = clampf(pitch, -pitch_limit, pitch_limit)
	_set_param("rotation_y", _rotation_y)
	_set_param("rotation_x", _rotation_x)


func get_planet_rotation() -> Vector2:
	return Vector2(_rotation_y, _rotation_x)
