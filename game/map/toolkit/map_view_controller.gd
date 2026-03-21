# MapViewController — Visibility, Exaggeration und Culling für Map-Views.
# Fasst die drei Entscheidungsschichten zusammen die jede View benötigt:
#   Schicht A: Scope-Filter (visible_types, visible_tags, min_orbit_px)
#   Schicht B: Exag-Gate (moon/struct nur sichtbar wenn Parent in _exag_body_ids)
#   Schicht C: Koordinaten-Transformation mit Multi-Parent-Exaggeration
#   Schicht D: Viewport-Culling
#
# View-agnostisch: kein Zugriff auf SolarSystem oder spezifische View-Klassen.
# Die View ist verantwortlich Orbit-Radien und Positionen aus SolarSystem zu holen
# und an die Methoden zu übergeben.
class_name MapViewController

extends RefCounted

const CULL_MARGIN_PX: float = 100.0

var _scope_resolver: ScopeResolver = null
var _map_scale:      MapScale      = null
var _current_scope:  ScopeConfig   = null
var _exag_body_ids:  Array[String] = []
var _dbg_exag_mult:  float         = 1.0   # Debug-Multiplikator, Standard 1.0


func setup(resolver: ScopeResolver, scale: MapScale) -> void:
	_scope_resolver = resolver
	_map_scale      = scale


# ─── Scope ────────────────────────────────────────────────────────────────────

func resolve_scope(scale_exp: float, focused_body: BodyDef) -> ScopeConfig:
	_current_scope = _scope_resolver.resolve(scale_exp, focused_body)
	return _current_scope


func set_exag_bodies(ids: Array[String]) -> void:
	_exag_body_ids = ids


func get_current_scope() -> ScopeConfig:
	return _current_scope


# ─── Visibility ───────────────────────────────────────────────────────────────

# Entscheidet ob ein Body im aktuellen Scope sichtbar ist.
# orbit_km: semi-major axis in km — von der View via SolarSystem übergeben.
func is_body_visible(body: BodyDef, orbit_km: float) -> bool:
	if _current_scope == null or body == null:
		return false

	var orbit_px   := orbit_km * _map_scale.get_px_per_km()
	var scope_exag := _current_scope.exag_faktor

	# Exag-Kind → orbit_px mit Exaggeration skalieren, context-Schwelle verwenden
	var is_exag_child := not _exag_body_ids.is_empty() and body.parent_id in _exag_body_ids
	if is_exag_child:
		orbit_px *= scope_exag * _dbg_exag_mult

	# Schicht A: Scope-Filter (type, tag, orbit)
	var vis := _scope_resolver.is_body_visible(body, _current_scope, orbit_px)

	# Context-Schwelle für Exag-Kinder (verhindert zu enge Orbits)
	if vis and is_exag_child and _current_scope.context_min_orbit_px > 0.0:
		vis = orbit_px >= _current_scope.context_min_orbit_px

	# Schicht B: Exag-Gate — moon/struct nur sichtbar wenn Parent in _exag_body_ids
	if vis and body.type in ["moon", "struct"] and not _exag_body_ids.is_empty():
		vis = body.parent_id in _exag_body_ids

	return vis


# ─── Koordinaten ──────────────────────────────────────────────────────────────

# Berechnet Displayposition mit optionaler Multi-Parent-Exaggeration.
# parent_pos_km: von der View via SolarSystem.get_body_position(body.parent_id).
# Für Bodies die kein Exag-Kind sind wird parent_pos_km ignoriert.
func world_to_display(world_km: Vector2, body: BodyDef,
		parent_pos_km: Vector2 = Vector2.ZERO) -> Vector2:
	var scope_exag     := _current_scope.exag_faktor if _current_scope else 1.0
	var effective_exag := scope_exag * _dbg_exag_mult

	if effective_exag > 1.0 and body != null and not _exag_body_ids.is_empty():
		if body.parent_id in _exag_body_ids:
			var parent_screen := _map_scale.world_to_screen(parent_pos_km)
			var local_offset  := world_km - parent_pos_km
			return parent_screen + local_offset * _map_scale.get_px_per_km() * effective_exag

	return _map_scale.world_to_screen(world_km)


# ─── Belt LOD ─────────────────────────────────────────────────────────────────

# Berechnet die anzuzeigende Partikelanzahl für einen Belt basierend auf dem Zoom-Level.
# Zoomed in (niedriger scale_exp) → mehr Partikel; zoomed out → weniger.
# Die View ruft set_density(get_belt_density(belt)) auf dem BeltRenderer auf.
func get_belt_density(belt: BeltDef) -> int:
	var t: float = clamp((_map_scale.get_scale_exp() - 4.0) / 3.0, 0.0, 1.0)
	return int(lerp(float(belt.max_points), float(belt.min_points), t))


# ─── Culling ──────────────────────────────────────────────────────────────────

# Viewport-Rect mit Margin — einmal pro Frame berechnen, dann an is_in_viewport übergeben.
func get_cull_rect(cam_pos: Vector2, vp_size: Vector2) -> Rect2:
	return Rect2(
		cam_pos - Vector2(CULL_MARGIN_PX, CULL_MARGIN_PX),
		vp_size + Vector2(CULL_MARGIN_PX * 2.0, CULL_MARGIN_PX * 2.0)
	)


func is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool:
	return cull_rect.has_point(screen_pos)
