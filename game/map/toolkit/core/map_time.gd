class_name MapTime
extends Node

## Independent time cursor for the map. Can follow the SimClock live or advance freely
## into the future without affecting the running simulation.

signal time_changed(seconds: float)
signal live_state_changed(is_live: bool)
