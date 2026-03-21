# Map Toolkit — Dokumentation

> Stand: 2026-03-21 · Löst `SPEC_map_system.md` (Kapitel 1–8) ab

---

## Überblick

Das Map Toolkit ist eine Sammlung **view-agnostischer, wiederverwendbarer Komponenten** für kartographische Ansichten. Es kümmert sich um Koordinatentransformation, Kamera-Navigation, Sichtbarkeitsfilterung und Rendering. Die konkrete Ansicht (StarChart, SensorDisplay etc.) orchestriert das Toolkit — kennt das Toolkit aber nicht umgekehrt.

```
map/
├── toolkit/
│   ├── map_view_controller.gd        # Haupt-API: Culling, Exag, Koordinaten
│   ├── MapViewController.tscn        # Scene: @export-Werte im Editor konfigurierbar
│   ├── map_camera_controller.gd      # Kamera-Navigation: Pan, Zoom, Inertia, Input
│   ├── map_data_loader.gd            # JSON-Loader für Belts & Zones
│   ├── filter/
│   │   ├── map_filter_state.gd      # Filter-State (Node, @export-Toggles)
│   │   └── MapFilterState.tscn      # Scene: Defaults im Editor setzbar
│   ├── scale/
│   │   └── map_scale.gd             # Koordinatensystem & Zoom-Zustand
│   └── renderer/
│       ├── body_marker.gd           # Klickbares Icon + Label
│       ├── orbit_renderer.gd        # Orbitbahn (solid/dashed/dotted)
│       ├── belt_renderer.gd         # Partikelbasierter Gürtel/Ring
│       ├── zone_renderer.gd         # Gefüllter Kreis/Ring (Magnetosphäre etc.)
│       ├── concentric_grid_renderer.gd
│       └── square_grid_renderer.gd
├── test/
│   └── map_test_scene.gd            # Demo & Integrationstest
└── views/                           # Reserviert für konkrete Views
```

---

## Architektur: 2-Regel-Culling + Filter

Für jeden Körper gelten zwei Culling-Regeln plus ein Filter:

```
Regel 1  min_orbit_px     →  orbit_km × px_per_km ≥ min_orbit_px?  (Root-Bodies ausgenommen)
Regel 2  Viewport-Culling →  Screen-Position innerhalb get_cull_rect()?

Filter   MapFilterState   →  Type/Subtype-Toggle aktiv?
```

**Exaggeration** wird automatisch aktiviert, wenn ein Fokus gesetzt ist:

- Exag-Kinder: `orbit_px × exag_faktor` wird gegen `min_orbit_px` geprüft
- Koordinate: `parent_screen + (child_world − parent_world) × px_per_km × exag_faktor`

Der `MapViewController` ist die öffentliche API für alle Sichtbarkeits- und Koordinaten-Entscheidungen.

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

### `MapCameraController`

Kapselt den gesamten Navigations-State und Input für kartenbasierte Views. Steuert `MapScale` direkt — Pan, Zoom, Inertia, Gummiband, Smooth-Gleiten.

Wird als Kind-Node eingehängt und via `setup()` konfiguriert. Hat keine Abhängigkeit zur View oder zu `SolarSystem`.

```gdscript
# Setup
func setup(map_scale: MapScale, config: Dictionary = {}) -> void
```

**Config-Keys** (alle optional):

| Key | Default | Bedeutung |
| --- | --- | --- |
| `scale_exp_min` | `1.0` | Untere Zoom-Grenze |
| `scale_exp_max` | `11.0` | Obere Zoom-Grenze |
| `scale_exp_start` | `7.5` | Start-Zoom |
| `zoom_step` | `0.08` | scale_exp-Delta pro Mausrad-Tick |
| `rubber_band_margin` | `0.5` | Überzoom-Spielraum an den Grenzen |
| `rubber_band_speed` | `5.0` | Rückfeder-Geschwindigkeit |
| `pan_inertia_decay` | `4.0` | Abbremsfaktor für Pan-Trägheit |
| `smooth_zoom_speed` | `8.0` | Interpolationsgeschwindigkeit Zoom |
| `smooth_pan_speed` | `8.0` | Interpolationsgeschwindigkeit Pan |
| `pan_key_speed_px` | `400.0` | Tastatur-Pan in px/s |
| `zoom_key_speed` | `1.5` | scale_exp-Delta/s bei Q/E |

**Signale:**

```gdscript
signal camera_moved                                        # Jedes Frame bei Positionsänderung
signal zoom_changed(scale_exp: float)                      # Bei Zoom-Änderung
signal empty_click(world_km: Vector2)                      # Linksklick ins Leere
signal context_menu_requested(screen_pos, world_km)        # Rechtsklick
```

**Navigation-API:**

```gdscript
pan_to(world_km: Vector2)            # Smooth gleiten zum Weltpunkt
jump_to(world_km: Vector2)           # Sofortsprung, kein Smoothing
zoom_to(scale_exp: float)            # Smooth zoomen
reset_view()                         # Zurück zu Start-Position + Start-Zoom

set_focus_anchor(world_km: Vector2)  # Zoom zentriert auf diesen Punkt (+ löscht Inertia)
clear_focus_anchor()                 # Zoom zentriert auf Cursor
```

**Abfragen:**

```gdscript
get_world_center() -> Vector2
get_scale_exp() -> float
get_mouse_world_position() -> Vector2
is_panning() -> bool
```

**Input Actions** (müssen in `project.godot` definiert sein):

| Action | Taste | Verhalten |
| --- | --- | --- |
| `cam_pan_up/down/left/right` | W S A D | Pan, skaliert mit Zoom |
| `cam_zoom_in` / `cam_zoom_out` | Q / E | Kontinuierliches Zoomen |
| `cam_reset` | R | Zurück zu Start |

Mausrad, Mittelklick-Pan, Trackpad-Pan und Pinch-to-Zoom werden intern verarbeitet.

**Verhalten Linksklick:**

- Kein Fokus-Anker gesetzt → Kamera gleitet zum Klickpunkt + emittiert `empty_click`
- Fokus-Anker gesetzt → nur `empty_click` emittieren, View entscheidet (z.B. Fokus lösen)

---

### `MapFilterState`

Node-Klasse mit `@export`-Toggles für die Sichtbarkeit von Bodies, Orbits, Zonen und Gürteln. Lebt als Kind-Node in der View-Scene oder in MapFilterState.tscn.

```gdscript
# Type-Toggles (hierarchisch: Type aus → alle Subtypes auch aus)
@export var show_stars, show_planets, show_dwarfs, show_moons, show_structs: bool

# Subtype-Toggles (nur relevant wenn Parent-Type aktiv)
@export var show_g_type, show_terrestrial, show_gas_giant, ...

# Orbits, Zones, Belts
@export var show_planet_orbits, show_radiation_zones, show_asteroid_belt, ...

signal filter_changed

# Query
func is_body_visible(type: String, subtype: String) -> bool
func is_orbit_visible(parent_type: String) -> bool
func is_zone_visible(zone_type: String) -> bool
func is_belt_visible(belt_id: String) -> bool

# Setter (für UI — emittieren filter_changed)
func set_type_enabled(type: String, enabled: bool) -> void
func set_subtype_enabled(subtype: String, enabled: bool) -> void
func set_orbit_enabled(parent_type: String, enabled: bool) -> void
func set_zone_type_enabled(zone_type: String, enabled: bool) -> void
func set_belt_enabled(belt_id: String, enabled: bool) -> void
```

Filter sind persistent über Fokus-Wechsel. Views reagieren auf `filter_changed` mit einem Redraw.

---

### `MapViewController`

Haupt-API des Toolkits für Sichtbarkeit und Koordinaten. Extends `Node`, konfigurierbar über `@export`. Hat keine Abhängigkeit zur konkreten View.

```gdscript
# @export
@export var min_orbit_px: float = 8.0
@export var cull_margin_px: float = 100.0
@export var exag_faktor: float = 5.0
@export var marker_sizes: Dictionary = {"star": 32, "planet": 24, ...}

# Setup
func setup(scale: MapScale, filter: MapFilterState) -> void

# Sichtbarkeit
func is_body_visible(body: BodyDef, orbit_km: float) -> bool
func get_marker_size(body_type: String) -> int

# Koordinaten mit Exaggeration
func world_to_display(
    world_km: Vector2,
    body: BodyDef,
    parent_pos_km: Vector2 = Vector2.ZERO
) -> Vector2

# Culling
func get_cull_rect(cam_pos: Vector2, vp_size: Vector2) -> Rect2
func is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool

# Fokus & Exaggeration (automatisch verknüpft)
func set_focus(body_id: String) -> void
func clear_focus() -> void
func get_focused_body_id() -> String
func is_focused() -> bool

# Zoom-to-Fit bei Fokus
func calc_fit_scale_exp(max_child_orbit_km: float, vp_size: Vector2) -> float

# Belt-LOD
func get_belt_density(belt: BeltDef) -> int
```

**`is_body_visible` — Prüfkette:**

1. Root-Body (leere `parent_id`)? → min_orbit_px-Check überspringen
2. `orbit_px = orbit_km × px_per_km`
3. Exag-Kind? → `orbit_px × exag_faktor`
4. `orbit_px ≥ min_orbit_px`?
5. `filter.is_body_visible(body.type, body.subtype)`?

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
signal clicked(body_id: String)
signal double_clicked(body_id: String)
signal hovered(body_id: String)
signal unhovered(body_id: String)

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
# 1. MapScale erzeugen (RefCounted — kein add_child nötig)
_map_scale = MapScale.new()

# 2. Filter + ViewController als Nodes einrichten
_filter = MapFilterState.new()
add_child(_filter)

_view_controller = MapViewController.new()
add_child(_view_controller)
_view_controller.setup(_map_scale, _filter)

# 3. CameraController als Node einrichten (add_child VOR setup!)
_cam_controller = MapCameraController.new()
add_child(_cam_controller)
_cam_controller.setup(_map_scale, {
    "scale_exp_start": 7.5,
    "scale_exp_min":   4.0,
    "scale_exp_max":   10.0,
})
_cam_controller.camera_moved.connect(_refresh_positions)

# 4. Daten laden
var loader = MapDataLoader.new()
_belts = loader.load_all_belt_defs()
_zones = loader.load_all_zone_defs()

# 5. Renderer instanziieren (add_child VOR setup bei @onready-Nodes!)
var marker = BODY_MARKER_SCENE.instantiate()
add_child(marker)
marker.setup(body_def, _view_controller.get_marker_size(body_def.type))

# 6. Refresh-Methode — wird von camera_moved + simulation_updated aufgerufen
func _refresh_positions():
    var px_per_km := _map_scale.get_px_per_km()
    var vp_size   := get_viewport_rect().size
    var cull_rect := _view_controller.get_cull_rect(Vector2.ZERO, vp_size)

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

# 7. Fokus setzen (z.B. bei Doppelklick)
_view_controller.set_focus(body_id)          # Exag automatisch an
_cam_controller.set_focus_anchor(body_pos)   # Zoom zentriert auf Body

# 8. Fokus lösen
_view_controller.clear_focus()              # Exag automatisch aus
_cam_controller.clear_focus_anchor()        # Zoom zentriert auf Cursor
_cam_controller.pan_to(pre_focus_center)    # Kamera gleitet zurück
```

**Wichtig:** `add_child()` immer vor `setup()` bei Nodes die `@onready`-Variablen nutzen. `MapScale` ist `RefCounted` und braucht kein `add_child()`.

---

## Verantwortlichkeit der View

Das Toolkit übernimmt **keine** dieser Aufgaben — sie liegen bei der konkreten View:

- Körperpositionen von `SolarSystem` abfragen
- Orbitpfade berechnen
- Fokus-Logik (Doppelklick → `set_focus`, Escape → `clear_focus`, pre_focus-State speichern)
- Selektion + Selection-Ring zeichnen
- Hover-Reaktion (Cursor, Tooltip)
- Screen über Änderungen informieren
- Update-Loop antreiben (`simulation_updated` verbinden)
