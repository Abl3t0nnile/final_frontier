## MapConfig
## Base resource class for map configurations

class_name MapConfig
extends Resource

var primary_color: Color   = Color(0.29, 1.0, 0.54)
var secondary_color: Color = Color(0.88, 0.36, 0.27)
var min_zoom: float        = 3.0
var max_zoom: float        = 10.0
var default_culling_mode: int = 2  # CullingManager.CullingMode.HYBRID

## Culling
var culling_min_parent_dist_px: float  = 32.0
var culling_marker_thresholds: Vector2 = Vector2(5.0, 7.0)
var culling_sizes_star:   Vector3i     = Vector3i(40, 28, 18)
var culling_sizes_planet: Vector3i     = Vector3i(28, 20, 14)
var culling_sizes_moon:   Vector3i     = Vector3i(18, 12, 8)
var culling_sizes_struct: Vector3i     = Vector3i(14, 10, 6)
