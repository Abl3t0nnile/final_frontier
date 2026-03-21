# Map Toolkit — Dokumentation

> Stand: 2026-03-21 · Löst `SPEC_map_system.md` (Kapitel 1–8) ab

---

## Überblick

Das Map Toolkit ist eine Sammlung **view-agnostischer, wiederverwendbarer Komponenten** für kartographische Ansichten. Es kümmert sich um Koordinatentransformation, Sichtbarkeitsfilterung und Rendering. Die konkrete Ansicht (StarChart, SensorDisplay etc.) orchestriert das Toolkit — kennt das Toolkit aber nicht umgekehrt.

```
map/
├── toolkit/
│   ├── map_view_controller.gd        # Haupt-API: Orchestriert alle Layer
│   ├── map_data_loader.gd            # JSON-Loader für Belts & Zones
│   ├── scale/
│   │   └── map_scale.gd             # Koordinatensystem & Zoom-Zustand
│   ├── scope/
│   │   ├── scope_config.gd          # Datenklass: Filterregeln pro Zoombereich
│   │   └── scope_resolver.gd        # Logik: Scope-Matching & Sichtbarkeit
│   └── renderer/
│       ├── body_marker.gd           # Klickbares Icon + Label
│       ├── orbit_renderer.gd        # Orbitbahn (solid/dashed/dotted)
│       ├── belt_renderer.gd         # Partikelbasierter Gürtel/Ring
│       ├── zone_renderer.gd         # Gefüllter Kreis/Ring (Magnetosphäre etc.)
│       ├── concentric_grid_renderer.gd
│       └── square_grid_renderer.gd
├── test/
│   └── map_test_scene.gd            # Demo & Integrationsttest
└── views/                           # Reserviert für konkrete Views
```

---

## Architektur: 4-Layer-Pipeline

Jeder Körper durchläuft vier unabhängige Filter- und Transformations-Layer:

```
Layer A  ScopeResolver       →  Welcher Scope ist aktiv? (Zoomstufe + Fokus-Körper)
Layer B  ScopeResolver       →  Ist der Körper im aktiven Scope sichtbar?
Layer C  MapViewController   →  Exaggeration + Koordinatentransformation
Layer D  MapViewController   →  Viewport-Culling
```

Der `MapViewController` ist die öffentliche API für alle vier Layer.

---

## Komponenten

### `MapScale`

Reine Mathematik-Bibliothek. Kapselt den Zoom-Zustand und transformiert zwischen Welt- und Bildschirmkoordinaten.

**Logarithmischer Zoom:** `km_per_px = 10^scale_exp`. Ein Anstieg von 1.0 in `scale_exp` = 10× mehr Welt pro Pixel.

```gdscript
set_scale_exp(exp: float)
get_scale_exp() -> float
get_px_per_km() -> float
get_km_per_px() -> float

set_origin(world_km: Vector2)          # Weltposition von Bildschirm (0,0)
get_origin() -> Vector2

world_to_screen(world_km: Vector2) -> Vector2
screen_to_world(screen_px: Vector2) -> Vector2
km_to_px(km: float) -> float
px_to_km(px: float) -> float
```

---

### `ScopeConfig`

Datenklasse (kein Node). Definiert Filterregeln und Darstellungsparameter für einen Zoombereich.

```gdscript
# Matching-Bedingungen
scope_name: String
zoom_min: float           # scale_exp-Untergrenze (inklusiv)
zoom_max: float           # scale_exp-Obergrenze (inklusiv)
fokus_tags: Array[String] # Tags des fokussierten Körpers (OR-Logik; leer = immer)

# Sichtbarkeitsfilter
visible_types: Array[String]  # Körper-Typen ("star", "planet" …); leer = alle
visible_tags:  Array[String]  # Körper-Tags (OR-Logik); leer = alle
visible_zones: Array[String]  # Zone-IDs; leer = alle
visible_belts: Array[String]  # Belt-IDs; leer = alle

# Darstellungsparameter
exag_faktor:          float  # Orbitale Spreizung (1.0 = keine)
min_orbit_px:         float  # Mindest-Orbitradius in Pixeln
context_min_orbit_px: float  # Mindest-Orbitradius für exaggerierte Kinder
marker_sizes: Dictionary     # Typ → Größe in px

get_marker_size(body_type: String) -> int
```

---

### `ScopeResolver`

Sucht zum aktuellen Zoom + Fokus-Körper den passenden `ScopeConfig` und prüft Sichtbarkeit.

```gdscript
setup(scopes: Array[ScopeConfig]) -> void

resolve(scale_exp: float, focused_body: BodyDef) -> ScopeConfig
# Iteriert Scopes der Reihe nach; gibt ersten Treffer zurück.
# Fallback: letzter Scope in der Liste.

is_body_visible(body: BodyDef, scope: ScopeConfig, orbit_px: float) -> bool
# Prüft: Typ-Filter, Tag-Filter, Mindest-Orbitradius

is_zone_visible(zone: ZoneDef, scope: ScopeConfig) -> bool
is_belt_visible(belt: BeltDef, scope: ScopeConfig) -> bool
```

**Matching-Algorithmus:**
1. Ist `scale_exp` im Bereich `[zoom_min, zoom_max]`?
2. Hat der Fokus-Körper mindestens ein Tag aus `fokus_tags`? (leer = immer wahr)
3. Erster Treffer gewinnt.

---

### `MapViewController`

Haupt-API des Toolkits. Kombiniert alle 4 Layer. Hat keine Abhängigkeit zur konkreten View.

```gdscript
setup(resolver: ScopeResolver, scale: MapScale) -> void

# Scope
resolve_scope(scale_exp: float, focused_body: BodyDef) -> ScopeConfig
set_exag_bodies(ids: Array[String]) -> void  # Körper, die exaggeriert werden
get_current_scope() -> ScopeConfig

# Sichtbarkeit (Layer A + B + D)
is_body_visible(body: BodyDef, orbit_km: float) -> bool

# Koordinaten mit Exaggeration (Layer C)
world_to_display(
    world_km: Vector2,
    body: BodyDef,
    parent_pos_km: Vector2 = Vector2.ZERO
) -> Vector2

# Culling
get_cull_rect(cam_pos: Vector2, vp_size: Vector2) -> Rect2
is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool

# Belt-LOD
get_belt_density(belt: BeltDef) -> int
```

**Exaggeration-Logik (`world_to_display`):**

Wenn der Elternkörper eines Körpers exaggeriert ist:
```
screen_pos = parent_screen + (child_world − parent_world) × px_per_km × exag_faktor
```
Nicht-exaggerierte Körper: direkte Welttransformation über `MapScale`.

**`is_body_visible` — vollständige Prüfkette:**
1. Orbit in px berechnen. Ist Elternteil exaggeriert? → mit `exag_faktor` multiplizieren.
2. Typ-/Tag-/Mindestradius-Filter via `ScopeResolver`.
3. Exaggeration-Gate: Monde/Structs sind nur sichtbar, wenn ihr Elternteil exaggeriert ist.
4. Kontext-Schwelle: exaggerierte Kinder müssen `context_min_orbit_px` überschreiten.

---

### `MapDataLoader`

Deserialisiert Belt- und Zone-Definitionen aus JSON.

```gdscript
load_all_belt_defs(data_path: String = BELT_DATA_PATH) -> Array[BeltDef]
load_all_zone_defs(data_path: String = ZONE_DATA_PATH) -> Array[ZoneDef]
```

Standardpfade: `res://data/belt_data.json`, `res://data/zone_data.json`.

---

## Renderer

Alle Renderer sind `Node2D`-Subklassen. Sie sind **dumb**: Sie empfangen Daten und zeichnen — sie entscheiden nichts über Sichtbarkeit oder Position.

### `BodyMarker`

Klickbares Icon + Label für einen Himmelskörper.

```gdscript
# Signal
clicked(body_id: String)

setup(body: BodyDef, size_px: int) -> void
set_size(size_px: int) -> void
get_body_id() -> String
```

Icon-Auflösung basiert auf `type` + `subtype` (Fallback: `Cross.png`). Klick-Fläche ist ein `Area2D`-Kreis mit etwas Padding.

---

### `OrbitRenderer`

Orbitbahn als Linienzug.

```gdscript
setup(child_id: String, parent_id: String, color: Color,
      path_points_km: Array[Vector2]) -> void
set_draw_points(screen_points: PackedVector2Array) -> void
set_line_style(style: int) -> void   # LineStyle.SOLID | DASHED | DOTTED
get_path_points_km() -> Array[Vector2]
```

Position wird von der View gesetzt. Neuberechnung der Bildschirmpunkte nur bei Zoom-Änderung (nicht bei Elternbewegung).

---

### `BeltRenderer`

Hochperformantes Partikel-System für Asteroidengürtel, Trojanerwolken, Ringe.

```gdscript
setup(belt: BeltDef) -> void
set_density(visible_count: int) -> void        # LOD: erste N Partikel rendern
set_reference_angle(angle_rad: float) -> void  # Für Trojaner (L4/L5)
set_px_per_km(px_per_km: float) -> void

# Export-Variablen
rotation_speed_0: float  # Rotationsgeschwindigkeit Layer 0 (rad/s)
rotation_speed_1: float  # Rotationsgeschwindigkeit Layer 1 (etwas schneller)
apply_rotation: bool     # false für Trojaner
```

**Intern:** Partikel werden einmalig deterministisch (Seeded RNG) generiert und in zwei `ArrayMesh`-Layern gespeichert → 2 Draw Calls statt N. LOD steuert, wie viele der vorgemischten Partikel sichtbar sind.

---

### `ZoneRenderer`

Räumliche Region (Strahlungszone, Magnetosphäre etc.) als gefüllter Kreis oder Ring.

```gdscript
setup(zone: ZoneDef) -> void
set_px_per_km(px_per_km: float) -> void
```

Geometrien: `"circle"` (gefüllt) | `"ring"` (Innen- + Außenradius).

---

### `ConcentricGridRenderer`

Konzentrische Referenzringe + Kreuzachsen.

```gdscript
setup(ring_spacing_km: float, ring_count: int) -> void
set_px_per_km(px_per_km: float) -> void
```

---

### `SquareGridRenderer`

Rechteckiges Koordinatengitter, auf sichtbaren Bereich beschränkt.

```gdscript
setup(cell_size_km: float) -> void
set_px_per_km(px_per_km: float) -> void
set_draw_rect(rect_screen: Rect2) -> void  # Sichtbarer Viewport-Bereich
```

---

## Integrations-Pattern

```gdscript
## 1. Komponenten erzeugen
_map_scale      = MapScale.new()
_scope_resolver = ScopeResolver.new()
_view_controller = MapViewController.new()

## 2. Scopes konfigurieren & einrichten
_scope_resolver.setup([scope_a, scope_b, ...])
_view_controller.setup(_scope_resolver, _map_scale)

## 3. Daten laden
var loader = MapDataLoader.new()
_belts = loader.load_all_belt_defs()
_zones = loader.load_all_zone_defs()

## 4. Renderer instanziieren (add_child VOR setup!)
var marker = BODY_MARKER_SCENE.instantiate()
add_child(marker)
marker.setup(body_def, scope.get_marker_size(body_def.type))

## 5. Pro Frame: Positionen & Sichtbarkeit aktualisieren
func _refresh():
    _map_scale.set_origin(camera_world_km)
    var cull_rect = _view_controller.get_cull_rect(cam_pos, vp_size)

    for body_id in SolarSystem.get_all_body_ids():
        var body     = SolarSystem.get_body(body_id)
        var orbit_km = SolarSystem.get_body_orbit_radius_km(body_id)

        if _view_controller.is_body_visible(body, orbit_km):
            var world_pos  = SolarSystem.get_body_position(body_id)
            var parent_pos = SolarSystem.get_body_position(body.parent_id)
            var screen_pos = _view_controller.world_to_display(world_pos, body, parent_pos)
            marker.position = screen_pos
            marker.visible  = _view_controller.is_in_viewport(screen_pos, cull_rect)
        else:
            marker.visible = false
```

**Wichtig:** `add_child()` immer vor `setup()`, da `setup()` auf `@onready`-Variablen zugreifen kann.

---

## Verantwortlichkeit der View

Das Toolkit übernimmt **keine** dieser Aufgaben — sie liegen bei der konkreten View:

- Körperpositionen von `SolarSystem` abfragen
- Orbitpfade berechnen
- Kamera-/Pan-Steuerung
- Input-Events verarbeiten
- Gepinnte Körper verwalten
- Update-Loop treiben
