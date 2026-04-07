## ZoneRenderer
## GPU-Renderer für Zonen (Habitzone, Magnetosphären etc.) via MeshInstance2D + Shader.
## Geometrie "circle" = gefüllter Kreis; "ring" = Hohlring.
## Position (Node2D.position) = Parent-Body in px — gesetzt vom ZoneManager.

class_name ZoneRenderer
extends Node2D

var zone_def: ZoneDef    = null
var zone_id:  String     = ""

var _map_transform: MapTransform = null
var _mmi: MeshInstance2D         = null
var _quad_mesh: QuadMesh         = null
var _mat: ShaderMaterial         = null

const _SHADER_PATH := "res://assets/shaders/map/zone_ring.gdshader"


func setup(def: ZoneDef, map_transform: MapTransform) -> void:
	zone_def       = def
	zone_id        = def.id
	_map_transform = map_transform

	_quad_mesh = QuadMesh.new()

	var shader := load(_SHADER_PATH) as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("fill_color",   def.color_rgba)
	_mat.set_shader_parameter("border_color", def.border_color_rgba)
	_mat.set_shader_parameter("border_px",    1.0)

	_mmi = MeshInstance2D.new()
	_mmi.mesh     = _quad_mesh
	_mmi.material = _mat
	add_child(_mmi)

	_update_shader_params(map_transform.km_per_px)


func notify_zoom_changed(km_per_px: float) -> void:
	_update_shader_params(km_per_px)


# ---------------------------------------------------------------------------
# Intern
# ---------------------------------------------------------------------------

func _update_shader_params(km_per_px: float) -> void:
	if zone_def == null or _mat == null:
		return

	var r_outer: float
	var r_inner: float

	match zone_def.geometry:
		"circle":
			r_outer = zone_def.radius_km / km_per_px
			r_inner = 0.0
		"ring":
			r_outer = zone_def.outer_radius_km / km_per_px
			r_inner = zone_def.inner_radius_km  / km_per_px
		_:
			r_outer = zone_def.radius_km / km_per_px
			r_inner = 0.0

	var half_size := r_outer + 2.0
	_quad_mesh.size = Vector2(half_size * 2.0, half_size * 2.0)

	_mat.set_shader_parameter("r_outer_px",   r_outer)
	_mat.set_shader_parameter("r_inner_px",   r_inner)
	_mat.set_shader_parameter("half_size_px", half_size)
