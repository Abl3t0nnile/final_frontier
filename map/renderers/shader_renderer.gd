## ShaderRenderer
## GPU-beschleunigtes Rendering für Massenelemente
## Erweitert: Node2D

class_name ShaderRenderer
extends Node2D

## Render modes
enum RenderMode {
	GRID,
	ZONE,
	BELT
}

## Public Properties
var shader_material: ShaderMaterial : get = get_material
var render_mode: RenderMode : get = get_mode, set = set_mode

## Private
var _material: ShaderMaterial
var _mode: RenderMode
var _config: RenderConfig

## Public Methods
func setup(config: RenderConfig) -> void:
	"""Initialisiert Renderer mit Konfiguration"""
	_config = config
	
	# Create shader material based on render mode
	_material = ShaderMaterial.new()
	match _mode:
		RenderMode.GRID:
			_material.shader = load("res://shaders/grid.gdshader")
		RenderMode.ZONE:
			_material.shader = load("res://shaders/zone.gdshader")
		RenderMode.BELT:
			_material.shader = load("res://shaders/belt.gdshader")
	
	material = _material

func update_uniforms(uniforms: Dictionary) -> void:
	"""Aktualisiert Shader-Uniforms"""
	for key in uniforms:
		_material.set_shader_parameter(key, uniforms[key])

func set_visible(visible: bool) -> void:
	"""Setzt Sichtbarkeit"""
	self.visible = visible

## Getters/Setters
func get_material() -> ShaderMaterial:
	return _material

func get_mode() -> RenderMode:
	return _mode

func set_mode(mode: RenderMode) -> void:
	_mode = mode
