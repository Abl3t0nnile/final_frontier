class_name MapInput
extends Node

## Interprets raw mouse, keyboard, and trackpad input and delegates commands to MapCamera.
## Swappable or configurable per view.

signal empty_click(world_km: Vector2)
signal context_menu(screen_pos: Vector2, world_km: Vector2)
