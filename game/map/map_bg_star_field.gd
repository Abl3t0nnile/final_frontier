extends CanvasLayer

@export var parallax_scale_far:  float = 0.02
@export var parallax_scale_near: float = 0.08

func _process(_delta: float) -> void:
    var cam := get_viewport().get_camera_2d()
    if cam:
        $ColorRect.material.set_shader_parameter("scroll_offset_far",  cam.global_position * parallax_scale_far)
        $ColorRect.material.set_shader_parameter("scroll_offset_near", cam.global_position * parallax_scale_near)
