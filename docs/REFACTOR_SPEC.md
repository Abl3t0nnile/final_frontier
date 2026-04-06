# Final Frontier - Refactor Specification

## Table of Contents

1. [Overview](#overview)
   - Architecture Diagram
   - Design Principles

2. [Core Layer Specification](#core-layer-specification)
   - Clock
   - SolarSystemModel
   - SpaceMath
   - Data Definitions
     - BodyDef
     - BaseMotionDef
     - FixedMotionDef
     - CircularMotionDef
     - Kepler2DMotionDef
     - LagrangeMotionDef
   - GameObjectRegistry
   - DataLoader

3. [Entity Layer Specification](#entity-layer-specification)
   - GameObject
   - GameDataComponent
   - ExplorationComponent
   - TradingComponent
   - MissionComponent

4. [Map Layer Specification](#map-layer-specification)
   - MapController
   - SolarMapController
   - MiniMapController
   - MapTransform
   - MapMarker
   - EntityManager
   - CullingManager
   - InteractionManager
   - BeltManager
   - ZoneManager
   - FollowManager
   - MapConfig

5. [Rendering Layer Specification](#rendering-layer-specification)
   - ShaderRenderer
   - GridShaderRenderer
   - ZoneShaderRenderer
   - BeltShaderRenderer
   - OrbitRenderer

6. [UI Layer Specification](#ui-layer-specification)
   - MainDisplay
   - InfoPanel

7. [Data Flow Specification](#data-flow-specification)
   - Initialisierung
   - Runtime Loop
   - User-Interaktion
   - Lazy Loading

8. [Scene Structure Example: Solar Map with Time Warping](#scene-structure-example-solar-map-with-time-warping)
   - Scene Tree
   - Initialisierungs-Flow
   - Runtime Loop
   - Datenfluss bei Time Warp
   - Performance-Optimierungen
   - Key Points

9. [Implementation Priority](#implementation-priority)
   - Phase 1: Foundation
   - Phase 2: Entity System
   - Phase 3: Map Foundation
   - Phase 4: Rendering
   - Phase 5: Integration

---

## Overview

This specification defines the complete refactored architecture of the Final Frontier map system, incorporating all collected ideas and design decisions.

### Architecture Diagram

```txt
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │ MainDisplay │  │ InfoPanel   │  │ SidePanel   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                       Map Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │MapController│  │MapTransform │  │MapMarker    │      │
│  │             │  │             │  │+Orbit       │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │EntityManager│  │CullingMgr   │  │Interaction  │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    Entity Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │GameObject   │  │GameRegistry │  │GameDataComp │      │
│  │             │  │             │  │+SubTypes    │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                      Core Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │ Clock       │  │  SpaceMath  │  │DataLoader   │      │
│  │ (rewind)    │  │             │  │JSON+.tres   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  BodyDef    │  │BaseMotionDef│  │GameObject   │      │
│  │+MotionDefs  │  │ +4 Types    │  │ Registry    │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Separation of Concerns** - Visual, Simulation, and Gameplay data are separate
2. **Hybrid Data Management** - Core data always loaded, gameplay data lazy loaded
3. **Modular Map System** - Map types can be combined and extended
4. **Performance by Design** - Shader for mass elements, CPU for interaction
5. **Precision Where Needed** - SpaceMath for critical calculations

### Ordnerstruktur

```
core/
├── simulation/
│   ├── clock.gd
│   ├── solar_system_model.gd
│   └── space_math.gd
├── definitions/
│   ├── body_def.gd
│   ├── base_motion_def.gd
│   ├── fixed_motion_def.gd
│   ├── circular_motion_def.gd
│   ├── kepler2d_motion_def.gd
│   └── lagrange_motion_def.gd
└── objects/
    ├── components/
    │   ├── game_data_component.gd
    │   ├── exploration_component.gd
    │   ├── trading_component.gd
    │   └── mission_component.gd
    ├── data_loader.gd
    ├── game_object.gd
    └── game_object_registry.gd
```

---

## Core Layer Specification

### Clock

**Erweitert**: Node
**Zweck**: Zeit-Management für Simulation und Map

#### Public API

```gdscript
# Properties
var current_time: float : get = get_current_time
var time_scale: float : get = get_time_scale, set = set_time_scale
var is_running: bool : get = get_is_running
var allow_rewind: bool : get = get_allow_rewind  # false = nur vorwärts, true = auch rückwärts

# Signals
signal tick(time: float)  # Normaler Zeitfortschritt (absolute Zeit)
signal time_changed(time: float)  # Harter Zeit-Sprung (Rewind, Jump)

# Methods
func init(rewind_allowed: bool) -> Clock
func setup(start_time: float) -> void
func start() -> void
func stop() -> void
func set_time_scale(scale: float) -> void
func set_time(time: float) -> void  # Emittiert time_changed
func set_time_range(min_t: float, max_t: float) -> void
func advance_time(delta: float) -> void  # Emittiert tick
func format_time(time: float) -> String
```

#### Dependencies

- Wird verwendet von: SolarSystemModel, MapController

#### Signal-Verwendung

| Signal | Auslöser | Zweck |
|--------|----------|-------|
| `tick(time)` | `advance_time()` | Normaler Simulationsfortschritt |
| `time_changed(time)` | `set_time()` | Harter Sprung (Zeitreise) |

#### Verwendung

```gdscript
# Simulation: nur vorwärts
var sim_clock = Clock.new().init(false)
sim_clock.tick.connect(_on_sim_tick)

# Map: auch rückwärts erlaubt
var map_clock = Clock.new().init(true)
map_clock.time_changed.connect(_on_time_jump)
```

---

### SolarSystemModel

**Erweitert**: Node
**Zweck**: Zentrale Berechnung aller Objekt-Positionen und Zustands-Management

#### Public API

```gdscript
# Properties
var clock: Clock : get = get_clock
var game_objects: Array[GameObject] : get = get_game_objects

# Signals
signal simulation_updated()
signal object_position_changed(id: String, position: Vector2)

# Methods
func setup(clock: Clock, game_objects: Array[GameObject]) -> void
func update_positions_for_time(time: float) -> void
func get_object_position(id: String) -> Vector2
func get_object_position_at_time(id: String, time: float) -> Vector2
func get_children_of(parent_id: String) -> Array[String]
```

#### Dependencies

- Benötigt: Clock, GameObject, BodyDef, SpaceMath
- Wird verwendet von: MapController, UI Layer

#### Datenfluss

```
Clock.tick(time) → SolarSystemModel.update_positions_for_time(time) → 
SpaceMath.kepler_* → position cache → simulation_updated
```

#### Implementierungsdetails

- Nutzt SpaceMath für präzise Kepler-Berechnungen
- Caching von Positionen für Performance
- Unterstützt Zeitreisen über Clock mit allow_rewind=true
- Motion-Dispatch basierend auf `body.motion.model`

#### Motion-Dispatch-Mechanismus

```gdscript
func _calculate_world_position(body: BodyDef, time: float) -> Vector2:
    if not body.has_motion():
        return Vector2.ZERO
    
    match body.motion.model:
        "fixed":
            return _calculate_fixed_position(body)
        "circular":
            return _calculate_circular_position(body, time)
        "kepler2d":
            return _calculate_kepler2d_position(body, time)
        "lagrange":
            return _calculate_lagrange_position(body, time)
        _:
            push_error("Unknown motion model: %s" % body.motion.model)
            return Vector2.ZERO
```

---

### SpaceMath

**Erweitert**: RefCounted
**Zweck**: Zentrale Math-Bibliothek für präzise Berechnungen

#### Public API

```gdscript
# Koordinatentransformation
static func km_to_px(pos_km: Vector2, km_per_px: float) -> Vector2
static func px_to_km(pos_px: Vector2, km_per_px: float) -> Vector2
static func km_to_px_precise(pos_km: Vector2, km_per_px: float) -> Vector2
static func px_to_km_precise(pos_px: Vector2, km_per_px: float) -> Vector2

# Kepler-Berechnungen
static func solve_kepler(e: float, M: float) -> float
static func kepler_to_cartesian(a: float, e: float, nu: float) -> Vector2
static func get_orbit_position_precise(body: BodyDef, time: float, km_per_px: float) -> Vector2

# Kurslinien-Berechnungen
static func hohmann_transfer(r1: float, r2: float) -> Dictionary
static func calculate_delta_v(initial_orbit: Dictionary, final_orbit: Dictionary) -> float

# Skalierungen
static func smooth_step(edge0: float, edge1: float, x: float) -> float
static func lerp_zoom(zoom_exp: float, target: float, weight: float) -> float
```

#### Dependencies

- Unabhängig (Utility-Klasse)
- Wird verwendet von: MapTransform, OrbitRenderer, SolarSystemModel

---

## Data Definitions Specification

### BodyDef

**Erweitert**: RefCounted
**Zweck**: Pure Datenstruktur für physikalische Eigenschaften von Himmelskörpern

#### Public API

```gdscript
# Properties
var id: String : get = get_id
var name: String : get = get_name
var type: String : get = get_type
var subtype: String : get = get_subtype
var parent_id: String : get = get_parent_id
var body_radius_km: float : get = get_body_radius_km
var grav_param_km3_s2: float : get = get_grav_param_km3_s2
var map_icon: String : get = get_map_icon
var color_rgba: Color : get = get_color_rgba
var motion: BaseMotionDef : get = get_motion
var map_tags: Array[String] : get = get_map_tags

# Methods
func is_root() -> bool
func has_motion() -> bool
```

#### Dependencies

- Benötigt: BaseMotionDef (optional)
- Wird verwendet von: GameObject, SolarSystemModel, MapMarker, OrbitRenderer

#### JSON-Struktur

```json
{
  "id": "string",
  "name": "string",
  "type": "star|planet|dwarf|moon|struct",
  "subtype": "string",
  "parent_id": "string",
  "body_radius_km": float,
  "grav_param_km3_s2": float,
  "map_icon": "string",
  "color_rgba": [float, float, float, float],
  "motion": { "model": "string", "params": {...} },
  "map_tags": ["string"],
}
```

---

### BaseMotionDef

**Erweitert**: RefCounted
**Zweck**: Abstrakte Basisklasse für alle Bewegungsmodelle

#### Public API

```gdscript
# Properties
var model: String : get = get_model
```

#### Dependencies

- Wird verwendet von: BodyDef, SolarSystemModel

---

### FixedMotionDef

**Erweitert**: BaseMotionDef
**Zweck**: Stationäre Position relativ zum Elternkörper

#### Public API
```gdscript
# Properties
var x_km: float : get = get_x_km
var y_km: float : get = get_y_km
```

#### JSON-Struktur

```json
{
  "model": "fixed",
  "params": {
    "x_km": float,
    "y_km": float
  }
}
```

---

### CircularMotionDef

**Erweitert**: BaseMotionDef
**Zweck**: Gleichförmige Kreisbewegung

#### Public API

```gdscript
# Properties
var orbital_radius_km: float : get = get_orbital_radius_km
var initial_phase_rad: float : get = get_initial_phase_rad
var orbital_period_s: float : get = get_orbital_period_s
var orbit_direction: int : get = get_orbit_direction  # +1 prograd, -1 retrograd
```

#### JSON-Struktur

```json
{
  "model": "circular",
  "params": {
    "orbital_radius_km": float,
    "initial_phase_rad": float,
    "orbital_period_s": float,
    "orbit_direction": int  // +1 prograd, -1 retrograd
  }
}
```

---

### Kepler2DMotionDef

**Erweitert**: BaseMotionDef
**Zweck**: Physikalisch korrekte Ellipsenbahn in der Ebene

#### Public API

```gdscript
# Properties
var semi_major_axis_km: float : get = get_semi_major_axis_km
var eccentricity: float : get = get_eccentricity
var argument_of_periapsis_rad: float : get = get_argument_of_periapsis_rad
var mean_anomaly_epoch_rad: float : get = get_mean_anomaly_epoch_rad
var epoch_time_s: float : get = get_epoch_time_s
var orbit_direction: int : get = get_orbit_direction  # +1 prograd, -1 retrograd
```

#### JSON-Struktur
```json
{
  "model": "kepler2d",
  "params": {
    "semi_major_axis_km": float,
    "eccentricity": float,
    "argument_of_periapsis_rad": float,
    "mean_anomaly_epoch_rad": float,
    "epoch_time_s": float,
    "orbit_direction": int  // +1 prograd, -1 retrograd
  }
}
```

---

### LagrangeMotionDef
**Erweitert**: BaseMotionDef
**Zweck**: Position an Lagrange-Punkten zweier Referenzkörper

#### Public API
```gdscript
# Properties
var primary_id: String : get = get_primary_id
var secondary_id: String : get = get_secondary_id
var point: int : get = get_point
```

#### JSON-Struktur

```json
{
  "model": "lagrange",
  "params": {
    "primary_id": "string",
    "secondary_id": "string",
    "point": int  // 1-5
  }
}
```

---

### GameObjectRegistry

**Erweitert**: Node
**Zweck**: Zentraler Cache und API für alle GameObjects

#### Public API
```gdscript
# Properties
var game_objects: Dictionary : get = get_game_objects  # read-only

# Signals
signal game_object_loaded(id: String)
signal game_data_loaded(id: String)

# Methods
func register_game_object(obj: GameObject) -> void
func get_game_object(id: String) -> GameObject
func get_all_objects() -> Array[GameObject]
func get_objects_in_group(group: String) -> Array[GameObject]
func clear_cache() -> void
```

#### Dependencies
- Benötigt: GameObject, DataLoader
- Wird verwendet von: MapController, UI Layer

#### Datenfluss
```
DataLoader → GameObjectRegistry → GameObject
                                      ↓
                              Components (lazy)
```

---

### DataLoader
**Erweitert**: Node
**Zweck**: Hybrid-Laden von JSON und .tres Dateien

#### Public API
```gdscript
# Methods
func load_core_data(path: String) -> Array[BodyDef]  # JSON
func load_component(path: String) -> GameDataComponent  # .tres
func load_all_components(directory: String) -> Array[GameDataComponent]
func save_component(component: GameDataComponent, path: String) -> void
```

#### Dependencies
- Benötigt: BodyDef, GameDataComponent
- Wird verwendet von: GameObjectRegistry

#### Implementierungsdetails
- Parst JSON mit "model" und "params" für MotionDef
- Erstellt konkrete MotionDef-Klassen basierend auf model-Feld
- Validiert erforderliche Parameter für jeden Motion-Typ

#### JSON-Ladeprozess
```gdscript
func _create_motion_def_from_json(motion_data: Dictionary) -> BaseMotionDef:
    match motion_data.get("model", ""):
        "fixed":
            return FixedMotionDef.new().from_dict(motion_data.params)
        "circular":
            return CircularMotionDef.new().from_dict(motion_data.params)
        "kepler2d":
            return Kepler2DMotionDef.new().from_dict(motion_data.params)
        "lagrange":
            return LagrangeMotionDef.new().from_dict(motion_data.params)
        _:
            push_error("Unknown motion model: %s" % motion_data.model)
            return null
```

---

## Entity Layer Specification

### GameObject
**Erweitert**: RefCounted
**Zweck**: Vereinigt BodyDef mit optionalen Gameplay-Komponenten

#### Public API
```gdscript
# Properties
var id: String : get = get_id
var body_def: BodyDef : get = get_body_def
var children: Array[String] : get = get_children
var parent: String : get = get_parent

# Methods
func has_component(type: String) -> bool
func get_component(type: String) -> GameDataComponent
func add_component(type: String, component: GameDataComponent) -> void
func remove_component(type: String) -> void
func get_all_components() -> Array[GameDataComponent]
```

#### Dependencies
- Benötigt: BodyDef, GameDataComponent
- Wird verwendet von: GameObjectRegistry, MapController

#### Datenfluss
```
BodyDef (immer) → GameObject → Components (lazy)
```

#### Implementierungsdetails
- GameObject kennt seine Position nicht
- Position wird vom SolarSystemModel berechnet
- MapController holt Position und gibt sie an Marker weiter
- Components werden direkt im GameObject gehalten (kein separater GameData Container)

---

### GameDataComponent
**Erweitert**: Resource
**Zweck**: Basisklasse für Gameplay-Komponenten

#### Public API
```gdscript
# Properties
var component_id: String
var is_loaded: bool : get = get_is_loaded

# Methods
func load_data() -> void
func save_data() -> void
```

#### Dependencies
- Wird verwendet von: ExplorationComponent, TradingComponent, MissionComponent

---

### ExplorationComponent
**Erweitert**: GameDataComponent
**Zweck**: Erkundungs-Features für Objekte (Platzhalter)

#### Public API
```gdscript
# Properties
var is_discovered: bool : get = get_is_discovered
```

---

### TradingComponent
**Erweitert**: GameDataComponent
**Zweck**: Handels-Features für Stationen (Platzhalter)

#### Public API
```gdscript
# Properties
var has_market: bool : get = get_has_market
```

---

### MissionComponent
**Erweitert**: GameDataComponent
**Zweck**: Missionen für Objekte (Platzhalter)

#### Public API
```gdscript
# Properties
var has_missions: bool : get = get_has_missions
```

---

## Map Layer Specification

### MapController
**Erweitert**: Node2D
**Zweck**: Modularer Basis-Controller für alle Karten-Typen

#### Public API
```gdscript
# Properties
var map_transform: MapTransform : get = get_map_transform
var entity_manager: EntityManager : get = get_entity_manager
var culling_manager: CullingManager : get = get_culling_manager
var interaction_manager: InteractionManager : get = get_interaction_manager

# Signals
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)

# Methods
func setup(model: SolarSystemModel, clock: Clock, config: MapConfig) -> void
func select_body(id: String) -> void
func deselect_body() -> void
func focus_body(id: String) -> void
func get_selected_body() -> String
```

#### Dependencies
- Benötigt: MapTransform, EntityManager, CullingManager, InteractionManager
- Wird verwendet von: SolarMapController, MiniMapController

---

### SolarMapController
**Erweitert**: MapController
**Zweck**: Spezialisiert für Solar System Karte

#### Public API
```gdscript
# Properties
var belt_manager: BeltManager : get = get_belt_manager
var zone_manager: ZoneManager : get = get_zone_manager
var follow_manager: FollowManager : get = get_follow_manager

# Methods
func enable_time_travel() -> void
func set_time_display_mode(mode: TimeDisplayMode) -> void
```

---

### MiniMapController
**Erweitert**: MapController
**Zweck**: Reduzierte Karte für Übersicht

#### Public API
```gdscript
# Methods
func set_readonly_mode() -> void
func set_aggressive_culling() -> void
func sync_with_main_camera(main_transform: MapTransform) -> void
```

---

### MapTransform
**Erweitert**: Node
**Zweck**: Koordinatentransformation und Kamera-Steuerung

#### Public API
```gdscript
# Properties
var km_per_px: float : get = get_km_per_px, set = set_km_per_px
var zoom_exp: float : get = get_zoom_exp, set = set_zoom_exp
var cam_pos_px: Vector2 : get = get_cam_pos_px

# Signals
signal zoom_changed(km_per_px: float)
signal camera_moved(cam_pos_px: Vector2)

# Methods
func km_to_px(pos_km: Vector2) -> Vector2
func px_to_km(pos_px: Vector2) -> Vector2
func km_to_px_batch(positions: Dictionary) -> Dictionary
func focus_on(pos_px: Vector2) -> void
func focus_on_smooth(pos_px: Vector2) -> void
```

#### Dependencies
- Benötigt: SpaceMath (für precision-Berechnungen)

---

### MapMarker
**Erweitert**: Area2D
**Zweck**: Visuelle Repräsentation mit integriertem Orbit

#### Public API
```gdscript
# Properties
var body_def: BodyDef : get = get_body_def
var current_state: MarkerState : get = get_state, set = set_state
var orbit_renderer: OrbitRenderer : get = get_orbit_renderer

# Signals
signal clicked(marker: MapMarker)
signal double_clicked(marker: MapMarker)
signal hovered(marker: MapMarker)

# Methods
func setup(game_object: GameObject, label_settings: LabelSettings) -> void
func set_state(state: MarkerState) -> void
func set_size_px(px: int) -> void
func update_position(position: Vector2) -> void
```

#### Dependencies
- Benötigt: GameObject, OrbitRenderer (optional)

---

### EntityManager
**Erweitert**: Node
**Zweck**: Verwaltung aller visuellen Entitäten

#### Public API
```gdscript
# Properties
var markers: Dictionary : get = get_markers  # read-only

# Signals
signal entity_hovered(id: String)
signal entity_selected(id: String)

# Methods
func create_marker(game_object: GameObject) -> MapMarker
func update_all_positions() -> void
func get_marker(id: String) -> MapMarker
func get_markers_in_group(group: String) -> Array[MapMarker]
```

#### Dependencies
- Benötigt: GameObjectRegistry, MapMarker

---

### CullingManager
**Erweitert**: Node
**Zweck**: Performance-Optimierung durch Culling

#### Public API
```gdscript
# Properties
var culling_mode: CullingMode : get = get_mode, set = set_mode

# Methods
func update_culling(camera_pos: Vector2, viewport_size: Vector2, zoom: float) -> void
func is_entity_visible(id: String) -> bool
func set_culling_mode(mode: CullingMode) -> void
```

---

### InteractionManager

**Erweitert**: Node
**Zweck**: User-Interaktionen mit der Karte

#### Public API

```gdscript
# Properties
var selected_entity: String : get = get_selected_entity
var hovered_entity: String : get = get_hovered_entity

# Signals
signal body_selected(id: String)
signal body_deselected()
signal marker_hovered(id: String)

# Methods
func handle_input(event: InputEvent) -> void
func select_entity(id: String) -> void
func deselect_current() -> void
func set_interaction_mode(mode: InteractionMode) -> void
```

---

### BeltManager

**Erweitert**: Node
**Zweck**: Verwaltung der Asteroidengürtel in der Karte

#### Public API

```gdscript
# Properties
var active_belts: Dictionary : get = get_active_belts

# Methods
func setup(belt_data: Array) -> void
func update_belts(time: float, zoom: float) -> void
func show_belt(id: String) -> void
func hide_belt(id: String) -> void
```

---

### ZoneManager

**Erweitert**: Node
**Zweck**: Verwaltung der Zonen (Einflussbereiche) in der Karte

#### Public API

```gdscript
# Properties
var active_zones: Dictionary : get = get_active_zones

# Methods
func setup(zone_data: Array) -> void
func update_zones(time: float, zoom: float) -> void
func set_zone_visibility(id: String, visible: bool) -> void
```

---

### FollowManager

**Erweitert**: Node
**Zweck**: Steuert das Kamera-Tracking für verfolgte Entitäten

#### Public API

```gdscript
# Properties
var is_following: bool : get = get_is_following
var target_entity_id: String : get = get_target_entity_id

# Signals
signal follow_started(entity_id: String)
signal follow_stopped()

# Methods
func start_following(entity_id: String) -> void
func stop_following() -> void
func update_camera_position(delta: float) -> void
```

---

### MapConfig

**Erweitert**: Resource
**Zweck**: Basis-Ressourcenklasse für Kartenkonfigurationen

#### Public API

```gdscript
# Properties
var primary_color: Color
var secondary_color: Color
var min_zoom: float
var max_zoom: float
var default_culling_mode: CullingMode
```

---

## Rendering Layer Specification

### ShaderRenderer
**Erweitert**: Node2D
**Zweck**: Basisklasse für GPU-beschleunigtes Rendering für Massenelemente

#### Public API
```gdscript
# Properties
var shader_material: ShaderMaterial : get = get_material
var render_mode: RenderMode : get = get_mode, set = set_mode

# Methods
func setup(config: RenderConfig) -> void
func update_uniforms(uniforms: Dictionary) -> void
func set_visible(visible: bool) -> void
```

---

### GridShaderRenderer

**Erweitert**: ShaderRenderer
**Zweck**: Zeichnet konzentrische Ringe als Navigationsgitter

#### Public API

```gdscript
# Properties
var base_radius_km: float

# Methods
func setup_grid(config: Dictionary) -> void
func update_grid(time: float, zoom: float) -> void
```

---

### ZoneShaderRenderer

**Erweitert**: ShaderRenderer
**Zweck**: Zeichnet semi-transparente Einflusszonen um Himmelskörper

#### Public API

```gdscript
# Properties
var zone_color: Color
var zone_radius_km: float

# Methods
func setup_zone(color: Color, radius: float) -> void
func update_zone(time: float, zoom: float) -> void
```

---

### BeltShaderRenderer

**Erweitert**: ShaderRenderer
**Zweck**: Zeichnet Asteroidengürtel als Partikel-Clouds über Shader

#### Public API

```gdscript
# Properties
var inner_radius_km: float
var outer_radius_km: float
var particle_density: float

# Methods
func setup_belt(inner: float, outer: float, density: float) -> void
func update_belt(time: float, zoom: float) -> void
```

---

### OrbitRenderer
**Erweitert**: Node2D
**Zweck**: Orbit-Visualisierung (CPU-basiert, integriert in MapMarker)

#### Public API
```gdscript
# Properties
var body_def: BodyDef : get = get_body_def
var current_state: OrbitState : get = get_state, set = set_state

# Methods
func setup(body_def: BodyDef, map_transform: MapTransform) -> void
func set_state(state: OrbitState) -> void
func update_position(parent_position: Vector2) -> void
```

---

## UI Layer Specification

### MainDisplay
**Erweitert**: MarginContainer
**Zweck**: Haupt-UI Container und Setup-Koordination

#### Public API
```gdscript
# Properties
var map_controller: MapController : get = get_map_controller
var info_panel: InfoPanel : get = get_info_panel

# Methods
func setup(model: SolarSystemModel, clock: Clock) -> void
func apply_colors(primary: Color, secondary: Color) -> void
```

---

### InfoPanel
**Erweitert**: VBoxContainer
**Zweck**: Anzeige von Informationen über ausgewählte Objekte

#### Public API
```gdscript
# Properties
var selected_object: GameObject : get = get_selected_object

# Signals
signal location_requested(location_id: String)
signal trade_requested(ware_id: String)

# Methods
func display_object(obj: GameObject) -> void
func show_exploration_data(component: ExplorationComponent) -> void
func show_trading_data(component: TradingComponent) -> void
```

---

## Data Flow Specification

### Initialisierung
```
MainDisplay
  ├── DataLoader lädt JSON → BodyDef[]
  ├── GameObjectRegistry erstellt GameObjects
  ├── Clock (sim) startet
  ├── MapController wird mit Model & Clock eingerichtet
  └── EntityManager erstellt MapMarker für alle GameObjects
```

### Runtime Loop
```
Clock.tick(time) → SolarSystemModel.update_positions_for_time(time) → 
EntityManager.update_positions → 
MapMarker.update_position → CullingManager.update
```

### User-Interaktion
```
InputEvent → InteractionManager.handle_input → 
MapMarker.click → GameObjectRegistry.get → 
InfoPanel.display_object
```

### Lazy Loading
```
GameObject.get_component → DataLoader.load_component → 
GameDataComponent.load_data → UI aktualisieren
```

---

## Scene Structure Example: Solar Map with Time Warping

### Scene Tree
```
SolarMapScene (Node2D)
├── SimClock (Clock)  # allow_rewind=false
├── MapClock (Clock)  # allow_rewind=true
├── SolarSystemModel (SolarSystemModel)
├── GameObjectRegistry (GameObjectRegistry)
├── DataLoader (DataLoader)
├── SolarMapController (SolarMapController)
│   ├── MapTransform (MapTransform)
│   ├── EntityManager (EntityManager)
│   │   ├── Marker_Sun (MapMarker)
│   │   │   └── Orbit_Sun (OrbitRenderer)
│   │   ├── Marker_Earth (MapMarker)
│   │   │   └── Orbit_Earth (OrbitRenderer)
│   │   └── Marker_Mars (MapMarker)
│   │       └── Orbit_Mars (OrbitRenderer)
│   ├── CullingManager (CullingManager)
│   ├── InteractionManager (InteractionManager)
│   ├── BeltManager (BeltManager)
│   │   └── AsteroidBelt (ShaderRenderer)
│   └── ZoneManager (ZoneManager)
│       └── EarthZone (ShaderRenderer)
└── WorldRoot (Node2D)
    ├── GridLayer (Node2D)
    │   └── GridRenderer (ShaderRenderer)
    ├── OrbitLayer (Node2D)  # Leerer Layer, Orbits sind in Markern
    ├── BeltLayer (Node2D)   # Leerer Layer, Belts sind Shader
    └── ZoneLayer (Node2D)   # Leerer Layer, Zones sind Shader
```

### Initialisierungs-Flow
```gdscript
# 1. Setup der Zeit-Systeme
sim_clock.setup(0.0)
sim_clock.start()
map_clock.setup(0.0)
map_clock.set_time_range(-1000000, 1000000)  # +/- 1M seconds

# 2. Daten laden
var body_defs = data_loader.load_core_data("solar_system.json")
var game_objects = []
for def in body_defs:
    var obj = GameObject.new(def)
    game_registry.register_game_object(obj)
    game_objects.append(obj)

# 3. Model verbinden
solar_system_model.setup(sim_clock, game_objects)
solar_system_model.simulation_updated.connect(_on_simulation_updated)

# 4. Map Controller setup
solar_map_controller.setup(solar_system_model, map_clock, solar_map_config)
solar_map_controller.focus_body("sun")

# 5. Time Warping aktivieren
map_clock.set_time_scale(1000.0)  # 1000x Geschwindigkeit
```

### Runtime Loop
```gdscript
# sim_clock (allow_rewind=false) treibt die Simulation an
func _on_sim_clock_tick(time: float):
    solar_system_model.update_positions_for_time(time)

# map_clock (allow_rewind=true) kann unabhängig spulen
func _on_time_slider_changed(time: float):
    map_clock.set_time(time)
    # Positionen werden neu berechnet für die angezeigte Zeit
    solar_system_model.update_positions_for_time(time)
```

### Datenfluss bei Time Warp
```
UI Time Slider → map_clock.set_time() → 
SolarSystemModel.update_positions_for_time() → 
SpaceMath.kepler_to_cartesian() mit neuer Zeit → 
EntityManager.update_all_positions() → 
MapMarker.update_position() → 
OrbitRenderer neu zeichnen
```

### Performance-Optimierungen
```gdscript
# CullingManager versteckt entfernte Objekte
culling_manager.update_culling(camera_pos, viewport_size, zoom)

# Shader Renderer für Massenelemente
asteroid_belt.update_uniforms({
    "time": map_clock.current_time,
    "zoom": map_transform.km_per_px
})

# Orbit Wobble-Fix bei hohem Zoom
if map_transform.km_per_px < WOBBLE_THRESHOLD:
    for marker in entity_manager.get_all_markers():
        marker.orbit_renderer.snap_to_precise_position()
```

### Key Points
1. **Zeit-Entkopplung**: Clock(rewind=false) für Gameplay, Clock(rewind=true) für Anzeige
2. **Zentrale Berechnung**: SolarSystemModel berechnet alle Positionen
3. **Orbit-Integration**: Orbits sind Child-Nodes der Marker
4. **Shader-Performance**: Belts/Zones/Gitter als GPU-Shader
5. **Precision-Handling**: SpaceMath für Wobble-Fix bei Zoom

---

## Implementation Priority

### Phase 1: Foundation
1. Clock mit allow_rewind Flag
2. SpaceMath mit Grundfunktionen
3. BodyDef und MotionDef Hierarchie
4. GameObjectRegistry

### Phase 2: Entity System
1. GameObject Klasse
2. GameDataComponent Hierarchie
3. DataLoader (JSON + .tres)

### Phase 3: Map Foundation
1. MapTransform überarbeiten
2. MapMarker mit Orbit-Integration
3. Component Manager

### Phase 4: Rendering
1. Shader für Grid, Zone, Belt
2. OrbitRenderer mit Wobble-Fix
3. Performance-Optimierung

### Phase 5: Integration
1. MapController modularisieren
2. UI an neues System anbinden
3. Tests und Validierung
