@tool
class_name ThemedIcon
extends TextureRect

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		modulate = get_theme_color("icon_color", "ThemedIcon")
