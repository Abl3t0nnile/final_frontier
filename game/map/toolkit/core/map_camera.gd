class_name MapCamera
extends Node

## Navigation state manager. Handles smooth pan, zoom, inertia, and rubber-banding.
## Writes the smoothed result into MapScale every frame. Receives commands only — no input.

signal camera_moved
signal zoom_changed(scale_exp: float)
