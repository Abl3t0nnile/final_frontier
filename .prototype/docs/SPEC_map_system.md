# Map System Specification

## Overview

This document describes the complete API and architecture of the map system, including core simulation, map visualization, and rendering components.

## Core API

### SimulationClock
**Purpose**: Time management for the simulation

**Signals**:
- `sim_clock_tick(sst_s: float)` - Emitted when simulation time advances

**Public Methods**:
- `setup(start_time: float) -> void`
- `start() -> void`
- `stop() -> void`
- `is_running() -> bool`
- `set_time_scale(scale: float) -> void`
- `get_time_scale() -> float`
- `get_sst() -> float` - Current simulation time
- `format_sst(sst: float) -> String` - Human-readable time format

### SolarSystemModel
**Purpose**: Central state of truth for all celestial bodies

**Signals**:
- `simulation_updated()` - Emitted when positions change

**Public Methods**:
- `setup(clock: SimulationClock) -> void`
- `load_bodies(bodies: Array[BodyDef]) -> void`
- `get_body(body_id: String) -> BodyDef`
- `get_all_body_ids() -> Array[String]`
- `get_body_position(body_id: String) -> Vector2`
- `get_children_of(parent_id: String) -> Array[String]`

### BodyDef
**Purpose**: Immutable definition of a celestial body

**Properties** (read-only via getters):
- `id: String` - Unique identifier
- `name: String` - Display name
- `type: String` - Main type (star, planet, moon, etc.)
- `subtype: String` - Optional subtype
- `parent_id: String` - Parent body ID
- `radius_km: float` - Physical radius
- `mu_km3_s2: float` - Gravitational parameter
- `map_icon: String` - Icon name
- `color_rgba: Color` - Map color
- `motion: BaseMotionDef` - Movement definition
- `map_tags: Array[String]` - Map-specific tags
- `gameplay_tags: Array[String]` - Gameplay tags

**Methods**:
- `is_root() -> bool` - True if no parent
- `has_motion() -> bool` - True if has movement

## Map API

### MapController
**Purpose**: Central coordinator for map visualization (829 lines - candidate for refactoring)

**Export Variables** (60+ configuration parameters):
- Zoom configuration (min, max, step, initial)
- Marker thresholds and sizes per type
- Culling parameters
- Color overrides
- Visual toggles

**Signals**:
- `marker_double_clicked(body_id: String)`
- `body_selected(body_id: String)`
- `body_deselected()`

**Public Methods**:
- `setup(model: SolarSystemModel, clock: SimulationClock) -> void`
- `select_body(body_id: String) -> void`
- `get_selected_body() -> String`
- `get_body_data(body_id: String) -> BodyDef`
- `get_children_of(parent_id: String) -> Array[String]`
- `get_bodies_in_group(group: String) -> Array[String]`
- `focus_body(body_id: String) -> void`

**Internal Responsibilities**:
- Entity lifecycle (markers, orbits, belts, zones)
- Update coordination
- Culling management
- Input handling
- Configuration application

### MapTransform
**Purpose**: Coordinate transformation and camera control

**Signals**:
- `zoom_changed(km_per_px: float)`
- `camera_moved(cam_pos_px: Vector2)`
- `panned`

**Public Methods**:
- `km_to_px(pos_km: Vector2) -> Vector2`
- `px_to_km(pos_px: Vector2) -> Vector2`
- `km_to_px_batch(positions: Dictionary) -> Dictionary`
- `focus_on(pos_px: Vector2) -> void`
- `focus_on_smooth(pos_px: Vector2) -> void`
- `set_km_per_px(value: float) -> void`
- `get_km_per_px() -> float`

**Configuration**:
- Zoom limits and stepping
- Pan speed and acceleration
- Rubber-band zoom behavior
- Scale presets

### MapMarker
**Purpose**: Visual representation of a celestial body

**Signals**:
- `clicked(marker: MapMarker)`
- `double_clicked(marker: MapMarker)`
- `hovered(marker: MapMarker)`
- `unhovered(marker: MapMarker)`

**States**:
- `INACTIVE` - Not visible
- `DEFAULT` - Normal display
- `SELECTED` - Selected by user
- `PINNED` - Pinned to view
- `DIMMED` - Culled/hidden

**Public Methods**:
- `setup(def: BodyDef, label_settings: LabelSettings) -> void`
- `set_state(state: MarkerState) -> void`
- `set_size_px(px: int) -> void`
- `force_color_update() -> void`

**Components**:
- Sprite2D - Icon display
- Label - Name display
- CollisionShape2D - Mouse interaction

### MapClock
**Purpose**: Time display for the map view

**Public Methods**:
- `setup(clock: SimulationClock) -> void`
- `set_display_mode(mode: DisplayMode) -> void`

## Renderer Architecture

### Common Pattern
All renderers follow this pattern:

1. **Setup Phase**:
   - `setup(def, map_transform)` - Initialize with data and transform
   - Load configuration from MapController

2. **Update Phase**:
   - `notify_zoom_changed(km_per_px)` - React to zoom changes
   - Position updates via Node2D.position (set by MapController)

3. **Render Phase**:
   - `_draw()` - Custom drawing implementation
   - Viewport culling in draw loop

### BeltRenderer
**Purpose**: Procedural point cloud for asteroid belts

**Key Features**:
- LOD system with point count based on zoom
- Deterministic point generation from seed
- Weight-based coloring and sizing
- Viewport culling in draw loop

**Configuration**:
- Zoom thresholds for LOD
- Point sizes at different zoom levels
- Color overrides

### OrbitRenderer
**Purpose**: Orbital path visualization

**Draw Modes**:
- `CIRCLE` - For circular orbits
- `ELLIPSE` - For Keplerian orbits
- `POLYLINE` - Fallback for custom paths

**States**:
- `INACTIVE` - Hidden
- `DEFAULT` - Normal display
- `HIGHLIGHT` - Hover/selected
- `DIMMED` - Culled

### GridRenderer
**Purpose**: Orientation grid display

**Features**:
- Radial grid with AU-spaced rings
- Major/minor ring differentiation
- Axis lines
- Labels for major rings

### ZoneRenderer
**Purpose**: Semi-transparent zone areas

**Geometries**:
- `circle` - Filled circle
- `ring` - Annulus (hollow ring)

## Open Decisions

### 1. Sprite vs Custom Drawing for MapMarker

**Current Approach**:
- Uses Sprite2D with texture assets
- Custom _draw() only for selection rings
- TODO in code (lines 91-99) suggests full custom drawing

**Custom Drawing Pros**:
- No texture loading/sampling overhead
- Always sharp at any zoom level
- No mipmapping issues
- Full programmatic control
- Smaller memory footprint

**Custom Drawing Cons**:
- Manual hit-testing required
- More complex code for simple shapes
- Loses Godot's built-in sprite optimizations
- Need to implement all shapes (circles, diamonds, crosses)

**Recommendation**: Keep Sprite2D for now, consider custom drawing only if performance becomes an issue.

### 2. Collision Detection: Godot vs Custom

**Current Approach**:
- Uses Area2D + CollisionShape2D
- Built-in mouse event handling
- Automatic hit-testing

**Custom Implementation Pros**:
- Potential performance gains for thousands of markers
- Custom spatial partitioning possible
- Fine-grained control over hit-testing

**Custom Implementation Cons**:
- Reimplementing battle-tested functionality
- Edge cases to handle (overlapping markers, z-order)
- Maintenance burden
- Godot's system is already optimized

**Recommendation**: Keep Godot's collision system unless you have >10,000 markers with performance issues.

## Data Flow

```
SimClock --(tick)--> SolarSystemModel --(positions)--> MapController
                                                          |
                                                          v
                                              +-----------------------+
                                              | MapTransform          |
                                              | - Coordinate conversion|
                                              | - Camera control      |
                                              +-----------------------+
                                                          |
                                                          v
                                              +-----------------------+
                                              | Renderers             |
                                              | - BeltRenderer        |
                                              | - OrbitRenderer       |
                                              | - GridRenderer        |
                                              | - ZoneRenderer        |
                                              +-----------------------+
                                                          |
                                                          v
                                              +-----------------------+
                                              | MapMarkers            |
                                              | - Sprite2D + Label    |
                                              | - Collision detection |
                                              +-----------------------+
```

## Performance Considerations

1. **Culling**: Proximity and viewport culling reduce draw calls
2. **LOD**: Belt renderer adjusts point count based on zoom
3. **Batching**: Consider batching similar renderers
4. **Spatial Partitioning**: Not implemented yet, could help with many markers

## Future Extensions

1. **Hybrid Belt System**: Visual + simulation objects
2. **Multiple Map Types**: MiniMap, CombatMap, PlanetSurface
3. **Custom Shaders**: For advanced visual effects
4. **Streaming**: For very large systems
5. **VR Support**: Additional rendering considerations

## Known Issues

1. **MapTransform Zoom Spring**: Camera position not updated during spring animation
2. **Belt Culling**: First frame culling doesn't work (TODO in lines 24-25)
3. **Performance**: Could be optimized for >1000 entities
