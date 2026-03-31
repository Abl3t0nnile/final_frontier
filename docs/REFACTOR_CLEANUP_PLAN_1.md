# Final Frontier — Refactor Cleanup Plan

> Status: Draft — March 2026
> Goal: Stabilize the rebuild, eliminate technical debt, unblock InfoPanel/Almanach feature.

---

## Guiding Principles

1. **Each phase is independently shippable** — the map works after every phase, never broken in between.
2. **Feature-unblocking first** — the InfoPanel/Almanach needs a working Entity Layer, so that comes early.
3. **Language consistency** — all code, comments, variable names, and docs switch to English during the phase they're touched. No separate "translation pass".
4. **Config stays simple for now** — `@export` vars remain during dev; `MapConfig` Resource is planned but not blocking.

---

## Phase Overview

| # | Phase | Focus | Unblocks |
|---|-------|-------|----------|
| 0 | Housekeeping | Dead code removal, English pass on touched files | Clean baseline |
| 1 | Time System | Dual-clock architecture, UI integration | Time Scrubbing, Rewind |
| 2 | Entity Layer Activation | GameObjectRegistry becomes the single source of truth | InfoPanel, Almanach |
| 3 | Manager Consolidation | Merge Belt/Ring, extract OrbitManager | Less duplication, cleaner MapController |
| 4 | Culling Rewrite | Replace vibe-coded O(n²) with clean, scalable system | Performance at scale |
| 5 | Signal Simplification | Flatten 6-hop signal chains where possible | Debuggability |
| 6 | Config Migration | `MapConfig` Resource replaces export-var-cascade | Inspector editability via .tres |

---

## Phase 0 — Housekeeping

**Goal:** Remove dead weight so subsequent phases work on a clean baseline.

### 0.1 Remove `MainDisplay`

`MainDisplay` (`ui/main/main_display.gd`) is unused — every method is a TODO stub, and the actual UI runs through `StarChartScreen` → `SolarMap` → `SolarMapController`. Keeping it creates confusion about the entry point.

**Action:**
- Delete `main_display.gd` and its scene (if any).
- Remove any references in `project.godot` or other scenes.
- Confirm `StarChartScreen` is the sole UI entry point.

### 0.2 English Pass (Incremental)

Not a separate task — whenever a file is opened in any phase, all German comments and variable names in that file get translated. No standalone "translate everything" ticket.

**Convention going forward:**
- Class names, method names, variable names: English
- Comments: English
- Signal names: English
- Doc-strings (`## ...`): English
- Commit messages: English

### 0.3 Audit Prototype Remnants

Check if any code still references prototype paths (`res://game/scenes/map/...`, `res://game/systems/map/...`, `res://game/map/...`). The rebuild uses `res://map/...` — any stale references will cause silent load failures.

**Action:**
- Grep for `res://game/` in all `.gd` and `.tscn` files.
- Fix or remove stale paths.

---

## Phase 1 — Time System

**Goal:** Clean dual-clock architecture where the MapClock is the primary time control for the map, and the SimClock runs independently as gameplay truth in the background.

### 1.1 Mental Model

```
SimClock — the game world's "real time"
    Always ticks forward. Cannot be paused or rewound by the map.
    Drives gameplay events: ship movement, pirate encounters, missions, trade.
    Runs regardless of what the user does on the star chart.

MapClock — the user's "time viewport" into the simulation
    The user's tool for exploring time on the map.
    Can run forward, backward, pause, scrub to any point.
    This is the PRIMARY time control for the map — not a special mode.
    The map ALWAYS renders the time shown by the MapClock.

Live Mode — MapClock follows SimClock
    A specific opt-in state, not the default during planning.
    Used when the user needs to see "now": active combat, ship tracking, etc.
    MapClock syncs to SimClock each tick. User can still break out at any time.
```

The user spends most of their time in **free MapClock mode** — planning routes, checking where Neptune will be in 200 days, scrubbing through orbital positions. Live mode is the exception: snapping back to "now" because gameplay demands attention (pirates approaching, mission timer running).

### 1.2 Problem Statement

The current code treats coupling (live mode) as the default and decoupling as the exception. `MapController.setup()` connects to both `_clock.tick` and `_map_clock.tick`, and `SolarMapController._on_clock_tick()` drives position updates directly from the sim clock, bypassing the map clock. This makes the map clock effectively a secondary system that only matters when explicitly decoupled.

### 1.3 Target Architecture

```
SimClock (forward-only, always running)
    │
    │  gameplay events, background simulation
    │
    ╰─── optionally observed by MapClock when in live mode

MapClock (bidirectional, user-controlled)
    │
    │  ALWAYS drives the map — regardless of mode
    │
    ├── Free mode (default):
    │     User controls time freely: play/pause/reverse/scrub/jump.
    │     Speed and direction via UI controls.
    │     SimClock keeps ticking in the background, unaffected.
    │
    └── Live mode (opt-in):
          MapClock.set_time() called each frame with SimClock.current_time.
          User sees "now". User time controls are disabled or overridden.
          Breaking out (pause, scrub, manual speed change) exits live mode.
```

**Key rules:**
1. The MapController ONLY listens to the MapClock. Never to the SimClock directly.
2. The MapClock is always the source of time for `SolarSystemModel.update_to_time()`.
3. Live mode is a state of the MapClock, not a bypass. Even in live mode, the MapClock is what the map reads — it just happens to track the SimClock.
4. Any user interaction with time controls (pause, speed change, scrub) exits live mode automatically.

### 1.4 MapClock Implementation

**MapClock is a NEW class** in `map/components/map_clock.gd`. It is NOT a SimClock instance. The current approach of reusing `SimClock.new().init(true)` as the map clock is replaced. MapClock has its own focused API for time navigation and live-mode tracking.

```gdscript
# File: map/components/map_clock.gd
class_name MapClock
extends Node

# Internal state
var _current_time: float = 0.0
var _time_scale: float = 86400.0   # sim-seconds per real-second
var _running: bool = false
var _reversed: bool = false
var _live: bool = false
var _sim_clock: SimClock = null     # only set when in live mode

# Time control (user-facing)
func play() -> void              # Start ticking forward at current speed
func pause() -> void             # Stop ticking
func reverse() -> void           # Start ticking backward at current speed
func set_time(sst_s: float)      # Jump to specific time (for scrubbing)
func set_time_scale(scale: float) # Set speed (always positive, direction via play/reverse)
func get_current_time() -> float  # Current displayed time

# Live mode
func enter_live_mode(sim_clock: SimClock) -> void   # Start tracking sim clock
func exit_live_mode() -> void                        # Return to free mode
func is_live() -> bool                               # Query current mode

# Signals
signal tick(sst_s: float)            # Fired each _physics_process while running
signal time_changed(sst_s: float)    # Fired on manual set_time() / scrub / live-mode snap
signal live_mode_changed(is_live: bool)

# _physics_process behavior:
#   if _live and _sim_clock != null:
#       _current_time = _sim_clock.get_current_time()
#       tick.emit(_current_time)
#   elif _running:
#       var direction = -1.0 if _reversed else 1.0
#       _current_time += get_physics_process_delta_time() * _time_scale * direction
#       tick.emit(_current_time)

# Auto-exit: play(), pause(), reverse(), set_time(), set_time_scale()
# all call exit_live_mode() internally if is_live() == true.
```

### 1.5 Tasks

1. **Create `MapClock` class at `map/components/map_clock.gd`.**
   New file, implementation as specified in 1.4 above. This replaces the current pattern in `MapController.setup()` where a second `SimClock.new().init(true)` is created as `_map_clock`.

2. **Update `MapController.setup()` in `map/controllers/map_controller.gd`.**
   - Remove `_map_clock = SimClock.new().init(true)` — MapClock is now created and owned by the controller as the new `MapClock` class.
   - Remove `_clock.tick.connect(_on_clock_tick)` — the base controller must not connect to the sim clock at all.
   - Connect only to MapClock: `_map_clock.tick.connect(_on_map_time_updated)` and `_map_clock.time_changed.connect(_on_map_time_updated)`.
   - Remove `_on_sim_clock_tick()`, `_on_map_clock_tick()`, `_on_map_clock_time_changed()` — replaced by single `_on_map_time_updated(time)`.
   - Remove `couple_clock()` / `decouple_clock()` / `is_clock_coupled()` — replaced by `_map_clock.enter_live_mode()` / `exit_live_mode()` / `is_live()`.

3. **Remove `_on_clock_tick` override in `SolarMapController` (`map/controllers/solar_map_controller.gd`).**
   The base class `_on_map_time_updated()` already handles position updates. `SolarMapController` only adds follow-manager update and feature updates — these move into an override of `_on_map_time_updated()`.

4. **Update `SolarMap` (`game/star_chart/solar_map.gd`) time control API.**
   Replace `couple_clock()` / `decouple_clock()` with:
   ```gdscript
   func play() -> void           # _map_controller.get_map_clock().play()
   func pause() -> void          # _map_controller.get_map_clock().pause()
   func reverse() -> void        # _map_controller.get_map_clock().reverse()
   func set_time_scale(s) -> void # _map_controller.get_map_clock().set_time_scale(s)
   func scrub_to(sst_s) -> void  # _map_controller.get_map_clock().set_time(sst_s)
   func go_live() -> void        # _map_controller.get_map_clock().enter_live_mode(_clock)
   func is_live() -> bool        # _map_controller.get_map_clock().is_live()
   ```

5. **Update `StarChartController` (`game/star_chart/start_chart_controller.gd`) time UI.**
   Play/Pause button, speed selector, scrub slider, "LIVE" indicator/button.
   Pressing any time control while live → exits live mode.
   Pressing "LIVE" button → enters live mode, map snaps to current sim time.

6. **Auto-exit live mode on user time interaction.**
   Built into `MapClock` itself: `play()`, `pause()`, `reverse()`, `set_time()`, `set_time_scale()` all call `exit_live_mode()` internally if `_live == true`.

### 1.6 Acceptance Criteria

- Map updates are driven exclusively by MapClock in all modes.
- In free mode: user can play, pause, reverse, scrub, change speed. SimClock is unaffected.
- In live mode: map shows "now" (SimClock time). Time controls are available but using them exits live mode.
- `go_live()` snaps MapClock to SimClock's current time and starts tracking.
- Pausing the MapClock does NOT pause the SimClock (pirates keep coming).
- `SolarSystemModel.update_to_time()` always receives the MapClock's time, never the SimClock's directly.

---

## Phase 2 — Entity Layer Activation

**Goal:** Make `GameObjectRegistry` the single source of truth for all entity data. The registry is populated first during startup, and all downstream systems — including `SolarSystemModel` — receive their data from it. This unblocks the InfoPanel and Almanach.

### 2.1 Problem Statement

The current startup flow has two problems:

1. **Data flows bypasses the registry.** `SolarMap._ready()` loads BodyDefs via `DataLoader`, passes them directly to `SolarSystemModel.setup()`, and only then creates GameObjects for the registry as an afterthought in `MapController.setup()`. The registry is populated after the sim is already running, and no downstream system reads from it.

2. **`SolarSystemModel` owns entity metadata.** The model exposes `get_body(id) → BodyDef`, `get_all_body_ids()`, `get_child_bodies()`, `get_bodies_by_type()` — all metadata queries that don't belong in a physics engine. Every manager uses these instead of the registry.

### 2.2 Target Startup Flow

```gdscript
# In SolarMap._ready() — the ONLY place that orchestrates setup:

# 1. Load raw data
var data_loader := DataLoader.new()
var body_defs: Array[BodyDef] = data_loader.load_core_data()

# 2. Registry first — single source of truth for entity data
_registry = GameObjectRegistry.new()
add_child(_registry)
for def in body_defs:
    var obj := GameObject.new().init(def)
    _registry.register(obj)

# 3. SimClock
_clock = SimClock.new()
_clock.init(false)
_clock.setup(0.0)
add_child(_clock)

# 4. SolarSystemModel gets its BodyDefs FROM the registry
_solar_system = SolarSystemModel.new()
add_child(_solar_system)
_solar_system.setup(_clock, _registry.get_all_body_defs())
#                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#    Sim receives BodyDefs from registry, not from DataLoader directly.
#    After setup, the sim holds internal references for position calculation.
#    The sim does NOT become a metadata query API — that's the registry's job.

# 5. MapController gets both registry and model
_map_controller.setup(_solar_system, _clock, _registry, ...)
```

### 2.3 Target Architecture

```
DataLoader
    ├── load_core_data() → Array[BodyDef]
    └── load_body_content(id) → BodyContentDef  ← NEW

GameObjectRegistry (single source of truth for ALL entity data)
    ├── register(obj: GameObject) → void
    ├── get_object(id) → GameObject
    ├── get_all_ids() → Array[String]
    ├── get_all_body_defs() → Array[BodyDef]    ← used by SolarSystemModel.setup()
    ├── get_children(parent_id) → Array[GameObject]
    ├── get_by_type(type) → Array[GameObject]
    └── get_by_group(group) → Array[GameObject]

GameObject
    ├── body_def: BodyDef (always loaded)
    ├── content: BodyContentDef (lazy, for InfoPanel)
    └── components: Dictionary (lazy, for gameplay)

SolarSystemModel (physics only — no metadata queries)
    ├── setup(clock, body_defs) → void          ← receives data, doesn't own it
    ├── update_to_time(sst_s) → void
    ├── get_body_position(id) → Vector2
    ├── get_body_positions_at_time(ids, sst_s) → Dictionary
    └── get_local_orbit_path(id) → Array[Vector2]
    ✗ get_body() — REMOVED, use registry
    ✗ get_all_body_ids() — REMOVED, use registry
    ✗ get_child_bodies() — REMOVED, use registry
    ✗ get_bodies_by_type() — REMOVED, use registry
```

**The sim keeps its internal BodyDef references** for position calculation (it needs `motion`, `parent_id`, `mu` etc. during `update_to_time()`). But external consumers no longer query the sim for metadata. They go through the registry.

### 2.4 Tasks

1. **Add `get_all_body_defs()` to `GameObjectRegistry`.**
   Returns `Array[BodyDef]` extracted from all registered GameObjects. Used once during setup to feed the sim.

2. **Restructure `SolarMap._ready()` to registry-first order.**
   Load data → populate registry → setup sim from registry → setup map with registry reference.

3. **Pass registry to `MapController.setup()`.**
   Change the signature from `setup(model, clock, config)` to `setup(model, clock, registry, config)`. The controller stores the registry reference and passes it to managers that need entity metadata. Specifically:
   - `EntityManager.setup(model, map_transform, registry, world_root)` — needs registry for iteration, model for positions.
   - `CullingManager.setup(entity_manager, registry, map_transform)` — needs registry for body_def lookups (type, parent_id). No longer needs model reference.
   - `InteractionManager` — unchanged (works with EntityManager markers, no model/registry access needed).
   - `FollowManager.setup(map_transform, model)` — unchanged (only needs positions).
   - `OrbitManager` (Phase 3) — will need registry to find orbiting bodies, model for orbit paths.

4. **Switch all metadata queries from model to registry.**
   - `EntityManager`: uses registry for `get_all_ids()`, model only for `get_body_position()`.
   - `CullingManager`: uses registry for `get_object(id).body_def` (type, parent_id).
   - `MapController`: uses registry for `get_children_of()`, `get_bodies_in_group()`.
   - `SolarMap`: uses registry for `get_body_data()`, `get_all_body_ids()`.

5. **Remove metadata API from `SolarSystemModel`.**
   Remove these public methods — all metadata queries go through the registry:
   - `get_body(id) → BodyDef` — REMOVE
   - `get_all_body_ids() → Array` — REMOVE
   - `get_child_bodies(parent_id) → Array[BodyDef]` — REMOVE
   - `get_children_by_type(parent_id, type) → Array[BodyDef]` — REMOVE
   - `get_bodies_by_type(type) → Array[BodyDef]` — REMOVE
   - `get_root_bodies() → Array[BodyDef]` — REMOVE

   These methods STAY (physics/position API):
   - `setup(clock, body_defs: Array[BodyDef])` — receives all bodies (including structs) as flat array
   - `update_to_time(sst_s)` — position calculation
   - `get_body_position(id) → Vector2` — KEEP
   - `get_body_position_at_time(id, sst_s) → Vector2` — KEEP
   - `get_body_positions_at_time(ids, sst_s) → Dictionary` — KEEP
   - `get_local_orbit_path(id) → Array[Vector2]` — KEEP
   - `get_body_orbit_radius_km(id) → float` — KEEP (used by MapController for focus zoom scaling)

   Note: The current code loads bodies and structs from separate JSON files (`solar_system_data.json` + `struct_data.json`). In the new flow, `DataLoader.load_core_data()` should load BOTH and return a single merged `Array[BodyDef]`. The sim no longer needs to know about separate data sources — it just receives all bodies.

6. **Add `BodyContentDef` resource class.**
   File: `core/defs/body_content_def.gd`. Per-body `.tres` files in `res://data/content/` (e.g., `mars.tres`, `earth.tres`). Not every body needs one. The system uses a three-tier data strategy:

   - **Always available (from BodyDef/MotionDef):** orbit period, semi-major axis, eccentricity, radius, type/subtype, parent. These auto-populate the Data tab.
   - **Optional rich content (from BodyContentDef .tres):** description, image, factions, trade, settlements. Loaded lazily when the Info tab is opened.
   - **Fallback template:** When no .tres exists, the Info tab shows a generated summary from BodyDef values plus a placeholder text (e.g., "No detailed records available for this body.").

   ```
   BodyContentDef (Resource)
       description: String
       image_path: String
       tags: Array[String]
       settlements: Array[Dictionary]
       factions: Array[Dictionary]
       trade_exports: Array[String]
       trade_imports: Array[String]
   ```

   Loading convention: `DataLoader.load_body_content(id)` tries `res://data/content/{id}.tres` → returns `null` if not found → `GameObject.get_content()` returns the .tres or a generated fallback.

7. **Expand `GameObjectRegistry` query API.**
   Add `get_children(parent_id)`, `get_by_type(type)`, `get_by_group(group)`. These replace the ad-hoc methods currently scattered across `MapController` and `SolarMap`.

8. **Wire `InfoPanel` to `GameObjectRegistry`.**
   When a body is selected, the InfoPanel gets a `GameObject` from the registry. The Data tab reads `body_def` (orbit params, radius, etc.). The Info tab reads `content` (lazy-loaded on first access). The Children tab queries `registry.get_children(id)`.

### 2.5 Acceptance Criteria

- `GameObjectRegistry` is populated before `SolarSystemModel.setup()` is called.
- `SolarSystemModel.setup()` receives its BodyDefs from the registry.
- No manager or UI component uses `SolarSystemModel` for metadata queries. Only for positions and orbit paths.
- `SolarSystemModel` no longer exposes `get_body()`, `get_all_body_ids()`, or any structural query API.
- InfoPanel Data tab populates from `body_def`.
- InfoPanel Info tab populates from `BodyContentDef` (even if with placeholder content initially).
- InfoPanel Children tab populates from `registry.get_children()`.

---

## Phase 3 — Manager Consolidation

**Goal:** Reduce code duplication and simplify `MapController` by extracting an `OrbitManager` and merging `BeltManager`/`RingManager`.

### 3.1 Merge Belt + Ring into `PointCloudManager`

`BeltManager` and `RingManager` are 95% identical. The only differences:
- Data path (`belt_data.json` vs `ring_data.json`)
- JSON root key (`"belts"` vs `"rings"`)
- Toggle independence (belts can be hidden while rings stay visible)

**Solution: One `PointCloudManager` class, instantiated twice.**

```gdscript
# File: map/components/point_cloud_manager.gd (NEW — replaces belt_manager.gd and ring_manager.gd)
class_name PointCloudManager extends Node

func setup(layer: Node2D, map_transform: MapTransform, model: SolarSystemModel,
        data_path: String, json_root_key: String) -> void
func update_positions() -> void      # set renderer positions from parent body
func update_zoom(km_per_px) -> void  # notify renderers of zoom change
func get_renderers() -> Array        # Array[BeltRenderer]
func get_defs() -> Array             # Array[BeltDef]
```

```gdscript
# In MapController._setup_belts() / _setup_rings():
_belt_manager = PointCloudManager.new()
_belt_manager.name = "BeltManager"
add_child(_belt_manager)
_belt_manager.setup(_belt_layer, _map_transform, _model, "res://data/belt_data.json", "belts")

_ring_manager = PointCloudManager.new()
_ring_manager.name = "RingManager"
add_child(_ring_manager)
_ring_manager.setup(_ring_layer, _map_transform, _model, "res://data/ring_data.json", "rings")
```

After migration: delete `map/components/belt_manager.gd` and `map/components/ring_manager.gd`.

Both use `BeltRenderer` + `BeltDef` as before (consider renaming to `PointCloudRenderer` / `PointCloudDef` for clarity, but not blocking).

### 3.2 Extract `OrbitManager`

Currently, orbit setup, update, hover-highlight and culling-sync are all inline in `MapController`:
- `_setup_orbits()` — creates renderers
- `_update_orbits()` — sets positions
- `_on_marker_hovered_orbit()` / `_on_marker_unhovered_orbit()` — state changes
- Culling sync in `CullingManager.apply_culling()` — sets orbit visibility

**Decision: OrbitManager owns renderers programmatically** (same pattern as Belt/Zone/Ring managers). Creates `OrbitRenderer` instances, adds them to OrbitLayer, manages their lifecycle.

```gdscript
# File: map/components/orbit_manager.gd
class_name OrbitManager extends Node

# Setup: iterates registry to find all bodies with circular/kepler2d motion,
# creates an OrbitRenderer for each, adds to orbit_layer.
func setup(orbit_layer: Node2D, map_transform: MapTransform,
        model: SolarSystemModel, registry: GameObjectRegistry) -> void

func update_orbits() -> void                   # set positions from parent body via model
func update_zoom(km_per_px: float) -> void     # redraw + notify renderers
func set_highlight(id: String, on: bool) -> void  # orbit state DEFAULT/HIGHLIGHT
func set_visibility(id: String, visible: bool) -> void  # called by CullingManager
func get_orbit(id: String) -> OrbitRenderer    # nullable
func get_orbits() -> Dictionary                # id -> OrbitRenderer
```

This removes ~80 lines from `MapController` and the orbit-specific signal wiring.

### 3.3 Simplify `MapController._setup_grid()`

Replace the fragile dynamic `load()` + `set_script()` pattern:

```gdscript
# Before (fragile, no compile-time check):
_grid = Node2D.new()
var script := load("res://map/renderers/grid_renderer.gd")
_grid.set_script(script)
_grid.call("setup", _map_transform)

# After (type-safe):
_grid = GridRenderer.new()
_grid_layer.add_child(_grid)
_grid.setup(_map_transform)
```

### 3.4 Acceptance Criteria

- `BeltManager` and `RingManager` are replaced by two `PointCloudManager` instances.
- `MapController` has no inline orbit logic — it delegates to `OrbitManager`.
- Grid setup uses typed instantiation.
- All belt/ring/orbit toggle behavior still works.
- Total line count in `MapController` drops significantly.

---

## Phase 4 — Culling Rewrite

**Goal:** Replace the current vibe-coded O(n²) culling with a clean, rule-based system. Marker sizes are discrete steps (no interpolation). Markers never shrink to nothing — they are either visible at a fixed size or hidden entirely. All visibility is controlled by viewport bounds and proximity rules.

### 4.1 Marker Sizing — Discrete Steps, No Interpolation

Markers scale in **3 or 5 fixed size steps** (exact count TBD during implementation). Each step is a fixed pixel value per body type. The step is determined by the current `zoom_exp` and the body type.

```
Example with 3 steps:
  Star:   [40, 28, 18] px
  Planet: [28, 20, 14] px
  Moon:   [18, 12,  8] px
  Struct: [14, 10,  6] px

Step boundaries defined by zoom_exp thresholds (configurable).
Marker snaps to a step — no lerp between sizes.
```

**Critical: Markers do NOT shrink until they disappear.** A marker is either visible at one of its discrete sizes, or it is INACTIVE (hidden). The transition from "visible at smallest size" to "hidden" is controlled exclusively by the proximity and viewport culling rules below — never by size.

### 4.2 Culling Rules

All rules are **bidirectional** — each rule describes a hide condition, and the inverse condition causes the element to reappear. Culling is re-evaluated on: zoom change, pan/camera move, selection change, pin/unpin.

#### Rule 1 — Viewport Culling

Any element whose visual bounds are entirely outside the viewport is hidden.

**Markers:** Hidden when marker center + half marker size is outside viewport bounds on all sides.

**Orbits:** Hidden when the orbit's bounding box (parent position ± orbit radius in px) does not intersect the viewport.

**Belts and Rings:** Hidden when the belt's bounding box (parent position ± outer_radius in px) does not intersect the viewport. **Important edge case:** Belts are large structures that are frequently partially visible — only a section of the arc may be on screen. The renderer already handles this internally (only draws points within the viewport). The culling check must use the full bounding box, not the center point. A belt is visible if ANY part of its bounding box intersects the viewport. Do not use center-point distance for belt visibility.

**Zones:** Same bounding-box logic as belts.

#### Rule 2 — Parent Hides Children (Proximity)

When zooming out, child bodies approach their parent visually. When a child marker's distance to its parent marker drops below a configurable pixel threshold (`min_parent_dist_px`), the child is hidden.

```
for each marker:
    if marker is pinned or selected or focused → SKIP (always visible)
    parent_marker = get_marker(body_def.parent_id)
    if parent_marker == null → SKIP (root body, no parent)
    dist_px = marker.position.distance_to(parent_marker.position)
    if dist_px < min_parent_dist_px → hide marker
```

This is **O(n)** — each body has exactly one parent. No pairwise comparison.

**Cascading:** If a marker is hidden by this rule, all its own children are also hidden (they are even closer). Implementation: process bodies in **topological order** (roots first, leaves last). When checking a child, first check if its parent is already hidden — if yes, hide the child immediately without distance check.

```
for each marker in topological order (roots first):
    if marker is pinned or selected → SKIP (always visible)
    parent_marker = get_marker(body_def.parent_id)
    if parent_marker == null → SKIP (root body, no parent)
    if parent_marker.current_state == INACTIVE → hide marker (cascade)
    elif marker.position.distance_to(parent_marker.position) < min_parent_dist_px → hide marker
```

**Orbits, Belts, Rings, Zones:** If a parent marker is hidden by proximity culling, all renderers attached to that parent are also hidden.

#### Rule 3 — Child Hides Parent (Focus Override)

When a body is **selected or pinned**, it is always visible regardless of proximity. This creates a conflict: if you zoom into Jupiter and select Io, both Io and Jupiter are close together on screen. The child (Io) must remain visible because it is selected. But Jupiter, although it is a higher-priority body, now overlaps with Io visually.

**Rule:** If a selected or pinned body's parent marker is within `min_parent_dist_px` of the selected/pinned body, the **parent** is hidden instead.

```
for each selected or pinned marker:
    parent_marker = get_marker(body_def.parent_id)
    if parent_marker == null → SKIP
    if parent_marker is also pinned → SKIP (both stay visible — see edge case below)
    dist_px = marker.position.distance_to(parent_marker.position)
    if dist_px < min_parent_dist_px → hide parent_marker
```

**Edge case — both parent and child are pinned:** Both remain visible. The user explicitly pinned both, so neither should be hidden. Accept the visual overlap.

**Edge case — multiple children are selected/pinned under the same parent:** The parent is hidden if ANY selected/pinned child is within proximity. The parent only reappears when ALL selected/pinned children are far enough away.

#### Rule 4 — Siblings Hide Each Other (Sibling Proximity)

When two children of the same parent are close together on screen (but not yet close enough to their parent to trigger Rule 2), the lower-priority sibling is hidden.

**Priority order** (lower number = higher priority = survives):
```
star: 0, planet: 1, dwarf: 2, moon: 3, struct: 4
```

Same priority: the body with the lexicographically smaller `id` survives (stable, deterministic).

```
for each pair of visible siblings (same parent_id):
    dist_px = marker_a.position.distance_to(marker_b.position)
    if dist_px < min_sibling_dist_px:
        hide the lower-priority sibling
```

**This is the only rule that involves pairwise comparison.** To keep it manageable:
- Only compare siblings (same `parent_id`), not all markers globally.
- Pre-group markers by `parent_id` so the comparison is per-group.
- Typical group sizes: Sun has ~10 children (planets + dwarfs), Jupiter has ~5 (major moons). This is O(k²) per group where k is small, not O(n²) globally.

`min_sibling_dist_px` is a separate configurable value (may differ from `min_parent_dist_px`).

**Selected or pinned markers are exempt** — they are never hidden by siblings. They CAN hide siblings though (a selected body always wins over an unselected sibling within proximity).

#### Rule 5 — Viewport Culling During Pan (Belt Edge Case)

Panning without zooming changes which elements intersect the viewport. Belts are the most affected because they can be very large (the asteroid belt spans hundreds of AU in px at close zoom).

**Scenario:** Camera is zoomed in close to Mars. The asteroid belt's bounding box does not intersect the viewport → belt is hidden. The user pans outward (away from the sun) without changing zoom. At some point, the belt's arc enters the viewport edge → belt must become visible.

**Implementation:** Viewport culling must be re-evaluated on every camera move (`camera_moved` signal), not just on zoom change. For belts specifically:

```
belt_center_px = map_transform.km_to_px(parent_position)
belt_outer_radius_px = belt_def.outer_radius_km / km_per_px
belt_bbox = Rect2(
    belt_center_px.x - belt_outer_radius_px,
    belt_center_px.y - belt_outer_radius_px,
    belt_outer_radius_px * 2,
    belt_outer_radius_px * 2
)
viewport_rect = get_viewport_rect() offset by camera position
belt.visible = belt_bbox.intersects(viewport_rect)
```

This applies equally to zones and rings — any large-radius renderer must use bounding-box intersection, not center-point checks.

### 4.3 Evaluation Order

The rules must be applied in a specific order to handle cascading correctly:

```
1. Reset all markers to DEFAULT (or SELECTED/PINNED if applicable)
2. Rule 3 — Child hides parent (process selected/pinned markers first)
3. Rule 2 — Parent hides children (reverse topological order, skip pinned/selected)
4. Rule 4 — Siblings hide each other (per parent group, skip pinned/selected)
5. Rule 1 — Viewport culling (final pass, hides anything off-screen)
6. Sync dependent renderers (orbits follow marker visibility,
   belts/rings/zones follow parent marker visibility + viewport check)
```

### 4.4 Configurable Values

```
min_parent_dist_px: float   — threshold for Rule 2 (parent hides children)
min_sibling_dist_px: float  — threshold for Rule 4 (siblings hide each other)
```

Both are set via the MapController config (currently export vars, later MapConfig resource). They may have the same value or differ — keeping them separate allows tuning parent-proximity and sibling-proximity independently.

### 4.5 Triggers

Culling is re-evaluated when:
- `zoom_changed` — marker sizes change, distances change → full re-evaluation
- `camera_moved` — viewport bounds change → viewport culling (Rule 1 + Rule 5)
- `body_selected` / `body_deselected` — focus state changes → Rules 2, 3, 4
- `body_pinned` / `body_unpinned` — pin state changes → Rules 2, 3, 4

**Optimization:** Rules 2/3/4 (proximity-based) only need re-evaluation on zoom or selection change, not on every pan. Rule 1 (viewport) needs re-evaluation on every camera move. Split these into two methods:

```gdscript
func update_proximity_culling(selected_id, pinned_ids) → Rules 2, 3, 4
func update_viewport_culling(camera_rect) → Rules 1, 5
```

### 4.6 Acceptance Criteria

- Marker sizes are discrete steps — no interpolation between sizes.
- Markers never shrink to invisibility — they are either visible at a fixed size or hidden.
- Zooming out: children disappear before they overlap their parent.
- Zooming out: siblings disappear before they overlap each other.
- Selected/pinned bodies are always visible; they hide their parent if too close.
- Two pinned bodies that overlap both remain visible (user intent wins).
- Panning at constant zoom correctly shows/hides belts entering/leaving the viewport.
- Belt visibility uses bounding-box intersection, not center-point distance.
- No O(n²) global comparison — sibling checks are grouped by parent.
- All rules are bidirectional — zooming back in / deselecting reverses the hiding.

---

## Phase 5 — Signal Simplification

**Goal:** Reduce signal hop count where possible without breaking the modular architecture.

### 5.1 Current Chain (6 hops for a click)

```
MapMarker.clicked
  → lambda in MapController
    → InteractionManager.select_entity()
      → InteractionManager.body_selected signal
        → MapController.body_selected signal (forwarded)
          → SolarMap.body_selected signal (forwarded)
            → StarChartController._on_body_selected()
```

### 5.2 Proposed Simplification

The internal chain (MapMarker → lambda → InteractionManager) is fine — that's the manager doing its job. The problem is the double-forwarding from InteractionManager → MapController → SolarMap.

**Option A: SolarMap subscribes directly to InteractionManager.**

```gdscript
# In SolarMap, after controller setup:
var interaction := _map_controller.get_interaction_manager()
interaction.body_selected.connect(body_selected.emit)
```

This removes one hop (MapController no longer re-emits). MapController still exposes the manager via getter, but doesn't parrot its signals.

**Option B: Keep the current structure but document the chain.**

If the forwarding exists for a design reason (e.g., MapController may transform/filter events before re-emitting in the future), keep it but add a comment explaining why.

### 5.3 Recommendation

Go with Option A for signals that are pure pass-through (body_selected, body_deselected, marker_hovered, marker_unhovered, body_pinned, body_unpinned). Keep forwarding only for signals that MapController genuinely transforms or filters.

### 5.4 Tasks

1. **These signals in `MapController` are pure forwarding — remove them from MapController:**
   - `body_selected` — forwarded from `InteractionManager.body_selected`
   - `body_deselected` — forwarded from `InteractionManager.body_deselected`
   - `marker_hovered` — forwarded from `InteractionManager.marker_hovered`
   - `marker_unhovered` — forwarded from `InteractionManager.marker_unhovered`
   - `body_pinned` — forwarded from `InteractionManager.body_pinned`
   - `body_unpinned` — forwarded from `InteractionManager.body_unpinned`

2. **`SolarMap._connect_signals()` subscribes directly to `InteractionManager`:**
   ```gdscript
   var interaction := _map_controller.get_interaction_manager()
   interaction.body_selected.connect(body_selected.emit)
   interaction.body_deselected.connect(body_deselected.emit)
   interaction.marker_hovered.connect(marker_hovered.emit)
   interaction.marker_unhovered.connect(marker_unhovered.emit)
   interaction.body_pinned.connect(body_pinned.emit)
   interaction.body_unpinned.connect(body_unpinned.emit)
   ```

3. Remove the signal declarations and `.connect(...emit)` wiring from `MapController`.
4. Verify `StarChartController` and `InfoPanel` still receive all events via `SolarMap` signals.

### 5.5 Acceptance Criteria

- No signal is forwarded without transformation.
- Click-to-handler path has max 4 hops (Marker → lambda → Manager → SolarMap → StarChartController).
- All existing UI reactions still work.

---

## Phase 6 — Config Migration (Future)

**Goal:** Replace the export-var cascade with a proper `MapConfig` Resource.

> This phase is **not urgent** — it's planned for when the tweaking phase ends and the config values stabilize.

### 6.1 Target

```gdscript
class_name MapConfig extends Resource

@export_group("Zoom")
@export var zoom_exp_min: float = 3.0
@export var zoom_exp_max: float = 10.0
# ... all config values

@export_group("Markers")
@export var sizes_star: Vector3i = Vector3i(40, 28, 18)
# ... etc.
```

`SolarMap` holds a single `@export var config: MapConfig` and passes it through. Each manager reads its slice:

```gdscript
func setup(..., config: MapConfig) -> void:
    min_parent_dist_px = config.culling_min_parent_dist_px
```

### 6.2 Benefits

- Single `.tres` file per map type (solar, mini, sector).
- Inspector-editable via the resource editor.
- No Dictionary intermediary.
- Adding a config value = one place (MapConfig) + one consumer.

### 6.3 Not Now Because

The current export vars on `SolarMap` are **faster to tweak in the Inspector** during active development. Switching to a Resource adds one click (open the .tres) which slows down iteration. Do this when values are stable.

---

## Dependency Graph

```
Phase 0 (Housekeeping)
    │
    ├──► Phase 1 (Time System)
    │        │
    │        └──► Phase 2 (Entity Layer) ──► InfoPanel / Almanach Feature
    │
    ├──► Phase 3 (Manager Consolidation) — independent of Phase 1/2
    │
    ├──► Phase 4 (Culling Rewrite) — can start after Phase 3
    │        │                        (uses new OrbitManager)
    │        └──► Phase 5 (Signal Simplification)
    │
    └──► Phase 6 (Config Migration) — whenever values stabilize
```

**Critical path to InfoPanel: Phase 0 → Phase 1 → Phase 2.**
Phase 2 is the heaviest lift — it restructures the startup flow (registry before sim), removes metadata API from SolarSystemModel, and switches all managers to use the registry.
Phases 3–5 can run in parallel or after, they don't block the next feature.

---

## Resolved Decisions

1. **BodyContentDef storage format → `.tres` files.**
   Per-body `.tres` files in `res://data/content/`. Not every body needs one — if no `.tres` exists, the InfoPanel and Almanach fall back to a standard template populated from BodyDef/MotionDef computed values (orbit period, radius, type description, etc.). This means content is optional and additive: you can ship 80 bodies with rich content for 20 of them, and the rest still show useful auto-generated data.

2. **OrbitManager ownership → Manager owns renderers (Variant A).**
   OrbitManager creates renderers programmatically and adds them to OrbitLayer, same pattern as Belt/Zone/Ring managers. Editor visibility is not needed — orbit configuration is purely data-driven via the map system. This keeps all layer managers consistent and avoids scene-tree / JSON synchronization overhead.

3. **Culling architecture → Proximity-based, no type-based zoom thresholds.**
   Markers do not have per-type zoom thresholds for visibility. Instead, visibility is controlled entirely by viewport culling and proximity rules (parent-child distance, sibling distance). Markers scale in discrete fixed steps (no interpolation) and never shrink to nothing — they are either visible at a step size or hidden by proximity/viewport rules. See Phase 4 for full specification.

4. **MapMarkerIcon → Keep current PNG system, revisit later.**
   The existing `MarkerIcon` class (`map/markers/map_marker_icon.gd`) works and loads PNGs by subtype. Icon rendering is a visual/style decision with no architectural impact. Deferred — may switch to SVG or programmatic `_draw()` later.

5. **Startup flow → Registry-first, sim receives data from registry.**
   `GameObjectRegistry` is populated before `SolarSystemModel.setup()`. The sim receives its `Array[BodyDef]` from the registry, not directly from the DataLoader. After setup, the sim holds internal references for physics but does not serve as a public metadata query API. All metadata queries (get_body, get_children, get_by_type) go through the registry. See Phase 2 for full specification.

