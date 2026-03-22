class_name BodyMarker
extends Node2D

## Clickable icon and label for a celestial body. Emits interaction signals
## for click, double-click, and hover events.

signal clicked(body_id: String)
signal double_clicked(body_id: String)
signal hovered(body_id: String)
signal unhovered(body_id: String)
