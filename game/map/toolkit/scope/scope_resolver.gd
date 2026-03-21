# ScopeResolver — Scope-Auswahl und Body-Sichtbarkeitslogik.
# Bestimmt anhand von Zoom-Level und fokussiertem Körper den aktiven ScopeConfig.
# Prüft ob ein Body im gegebenen Scope sichtbar ist.
# Kein Pinned-Management (Verantwortung der View), kein SolarSystem-Zugriff.
class_name ScopeResolver

extends RefCounted

var _scopes: Array[ScopeConfig] = []


func setup(scopes: Array[ScopeConfig]) -> void:
	_scopes = scopes


func resolve(scale_exp: float, focused_body: BodyDef) -> ScopeConfig:
	for scope in _scopes:
		if scale_exp < scope.zoom_min or scale_exp > scope.zoom_max:
			continue
		if scope.fokus_tags.is_empty():
			return scope
		if focused_body == null:
			continue
		for tag in focused_body.map_tags:
			if tag in scope.fokus_tags:
				return scope
	# Fallback: letzter Scope
	if not _scopes.is_empty():
		return _scopes[-1]
	return null


func is_zone_visible(zone: ZoneDef, scope: ScopeConfig) -> bool:
	if scope == null or zone == null:
		return false
	return scope.visible_zones.is_empty() or zone.id in scope.visible_zones


func is_belt_visible(belt: BeltDef, scope: ScopeConfig) -> bool:
	if scope == null or belt == null:
		return false
	return scope.visible_belts.is_empty() or belt.id in scope.visible_belts


func is_body_visible(body: BodyDef, scope: ScopeConfig, orbit_px: float) -> bool:
	if scope == null or body == null:
		return false

	var type_pass: bool = scope.visible_types.is_empty() or body.type in scope.visible_types

	var tag_pass: bool = scope.visible_tags.is_empty()
	if not tag_pass:
		for tag in body.map_tags:
			if tag in scope.visible_tags:
				tag_pass = true
				break

	var orbit_pass: bool = body.parent_id.is_empty() or orbit_px >= scope.min_orbit_px

	return type_pass and tag_pass and orbit_pass
