@tool
class_name MapColorPreset
extends Resource

# Color preset resource for map visualization
# Contains all color settings for different body types and visual elements

@export var preset_name: String
@export var description: String

# Object type colors
@export var color_star: Color = Color(0.85, 0.55, 0.15, 1.0)        # Desaturated orange for stars
@export var color_planet: Color = Color(0.9, 0.7, 0.25, 1.0)        # Desaturated yellow for planets
@export var color_moon: Color = Color(0.3, 0.6, 0.55, 1.0)         # Desaturated teal for moons
@export var color_dwarf: Color = Color(0.75, 0.45, 0.15, 1.0)      # Desaturated dark orange for dwarf planets
@export var color_struct: Color = Color(0.15, 0.65, 0.6, 1.0)      # Desaturated teal for structures

# Belt color
@export var belt_color: Color = Color(0.7, 0.25, 0.2, 1.0)         # Desaturated red for belts

# State modifiers
@export var highlight_alpha_multiplier: float = 1.5
@export var dimmed_alpha_multiplier: float = 0.25

# Orbit-specific settings
@export var orbit_alpha_offset: float = 0.0  # Additional alpha for orbits (0.0 = use type alpha, 1.0 = fully opaque)
