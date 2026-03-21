# MapViewController — Visibility, Exaggeration und Culling für Map-Views.
# Zwei Culling-Regeln:
#   1. min_orbit_px — Orbits unter diesem Pixel-Radius werden ausgeblendet
#   2. Viewport-Culling — nur rendern was auf dem Bildschirm ist
#
# Fokus setzt Exaggeration automatisch an für Kinder des fokussierten Body.
# View-agnostisch: kein Zugriff auf SolarSystem oder spezifische View-Klassen.
class_name MapViewController

extends Node

# ─── @export ──────────────────────────────────────────────────────────────

@export var min_orbit_px: float = 8.0
	## Globale Konstante. Orbits unter diesem Pixel-Radius werden ausgeblendet.

@export var cull_margin_px: float = 100.0
	## Margin um den Viewport für Culling.

@export var exag_faktor: float = 5.0
	## Spreizungsfaktor für Kinder des fokussierten Body.

@export var marker_sizes: Dictionary = {
	"star": 32, "planet": 24, "dwarf": 16, "moon": 14, "struct": 12
}
	## Marker-Größen pro Body-Type. Im Inspektor konfigurierbar.

# ─── Interner State ───────────────────────────────────────────────────────

var _map_scale: MapScale = null
var _filter: MapFilterState = null
var _focused_body_id: String = ""
var _exag_body_ids: Array[String] = []


# ─── Setup ────────────────────────────────────────────────────────────────

func setup(scale: MapScale, filter: MapFilterState) -> void:
	_map_scale = scale
	_filter = filter


# ─── Sichtbarkeit ─────────────────────────────────────────────────────────

func is_body_visible(body: BodyDef, orbit_km: float) -> bool:
	if body == null:
		return false

	# Root-Bodies (kein Parent) überspringen den min_orbit_px-Check
	if body.parent_id != "":
		var orbit_px := orbit_km * _map_scale.get_px_per_km()

		# Exag-Kind → orbit_px mit Exaggeration skalieren
		if not _exag_body_ids.is_empty() and body.parent_id in _exag_body_ids:
			orbit_px *= exag_faktor

		if orbit_px < min_orbit_px:
			return false

	if _filter != null:
		return _filter.is_body_visible(body.type, body.subtype)

	return true


func get_marker_size(body_type: String) -> int:
	if marker_sizes.has(body_type):
		return marker_sizes[body_type]
	return 16


# ─── Koordinaten ──────────────────────────────────────────────────────────

func world_to_display(world_km: Vector2, body: BodyDef,
		parent_pos_km: Vector2 = Vector2.ZERO) -> Vector2:
	if body != null and exag_faktor > 1.0 and not _exag_body_ids.is_empty():
		if body.parent_id in _exag_body_ids:
			var parent_screen := _map_scale.world_to_screen(parent_pos_km)
			var local_offset  := world_km - parent_pos_km
			return parent_screen + local_offset * _map_scale.get_px_per_km() * exag_faktor

	return _map_scale.world_to_screen(world_km)


# ─── Viewport-Culling ────────────────────────────────────────────────────

func get_cull_rect(cam_pos: Vector2, vp_size: Vector2) -> Rect2:
	return Rect2(
		cam_pos - Vector2(cull_margin_px, cull_margin_px),
		vp_size + Vector2(cull_margin_px * 2.0, cull_margin_px * 2.0)
	)


func is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool:
	return cull_rect.has_point(screen_pos)


# ─── Fokus & Exaggeration ────────────────────────────────────────────────

func set_focus(body_id: String) -> void:
	_focused_body_id = body_id
	_exag_body_ids = [body_id]


func clear_focus() -> void:
	_focused_body_id = ""
	_exag_body_ids = []


func get_focused_body_id() -> String:
	return _focused_body_id


func is_focused() -> bool:
	return _focused_body_id != ""


# ─── Zoom-to-Fit ─────────────────────────────────────────────────────────

func calc_fit_scale_exp(max_child_orbit_km: float, vp_size: Vector2) -> float:
	var target_px := minf(vp_size.x, vp_size.y) / 3.0
	var effective_orbit := max_child_orbit_km * exag_faktor
	if effective_orbit <= 0.0 or target_px <= 0.0:
		return _map_scale.get_scale_exp()
	return log(effective_orbit / target_px) / log(10.0)


# ─── Belt-LOD ─────────────────────────────────────────────────────────────

func get_belt_density(belt: BeltDef) -> int:
	var t: float = clamp((_map_scale.get_scale_exp() - 4.0) / 3.0, 0.0, 1.0)
	return int(lerp(float(belt.max_points), float(belt.min_points), t))
