# Solar System Simulation — Core Architecture

## Overview

The simulation core is a deterministic, time-driven solar system model. It calculates the world-space positions of all celestial bodies at any given point in simulation time. It is completely independent from gameplay events (ships, combat, economy etc.) and has no side effects — given the same time input, it always produces the same output.

The core consists of two autoload singletons, one loader utility, and a set of data classes. It is driven by a single JSON data file that describes the solar system. This data file is the only thing that needs to change to define an entirely different star system — the simulation code is generic and data-agnostic.

> **Data file format:** See [`SPEC_solar_system_sim_data.md`](./SPEC_solar_system_sim_data.md) for the complete schema, type system, subtype taxonomy, motion model parameters, tag system, and body hierarchy.

---

## Autoload Load Order (important)

```
1. SimClock          (autoload_sim_clock.gd)
2. SolarSystemModel  (autoload_solar_system_sim.gd)
```

`SolarSystemModel` connects to `SimClock.sim_clock_tick` in its `_ready()`, so SimClock must be loaded first.

---

## Data Flow

```
solar_system_sim_data.json
  │
  │  read once at startup
  ▼
CoreDataLoader
  │  parses JSON → Array[BodyDef]
  ▼
SolarSystemModel._build_sim_from_loader()
  │  topological sort (Kahn) → _update_order
  │  initial position calculation
  │  orbit path cache build
  │
  │  then, every physics frame:
  │
SimClock
  │  sim_clock_tick(sst_s: float)
  ▼
SolarSystemModel._update_simulation(sst_s)
  │  iterates _update_order
  │  calculates world position per body → _current_state
  │
  │  simulation_updated  [signal]
  ▼
Renderer / UI / Gameplay systems
     poll via get_body_position(id) -> Vector2
     poll via get_local_orbit_path(id) -> Array[Vector2]
```

---

## SimClock  (`autoload_sim_clock.gd`)

**Class:** `SimulationClock` — Autoload Singleton

Central timekeeper. Runs inside `_physics_process` for fixed-rate ticking.

### Key State
| Variable | Type | Description |
|---|---|---|
| `_sst_s` | `float` | Current time in Solar Standard Time seconds since t₀ |
| `_time_scale` | `float` | Multiplier applied to `delta` each tick. Min: 1.0 |
| `_running` | `bool` | Whether the clock is actively ticking |

### Key Signals
| Signal | Payload | When |
|---|---|---|
| `sim_clock_tick` | `sst_s: float` | Every physics frame while running |
| `sim_clock_time_scale_changed` | `time_scale: float` | On scale change |
| `sim_started` / `sim_stopped` | — | On state change |

### Time System
- **Unit:** Solar Standard Time seconds (`sst_s`), a continuous float from 0.0 at game start
- **Year:** 360 days · 86 400 s = 31 104 000 s
- **Calendar:** 12 months × 30 days
- **Month names:** Helar, Selen, Meron, Venar, Terran, Aresan, Jovan, Satyr, Uranor, Nevaris, Pluton, Ceron

### API
```gdscript
SimClock.start() / stop() / toggle()
SimClock.set_time_scale(factor: float)      # min 1.0
SimClock.set_sst_s(sst_s: float)            # hard jump, emits tick
SimClock.get_sst_s_now() -> float
SimClock.get_time_scale() -> float
SimClock.is_running() -> bool

# Time formatting (all also available as _now() shorthands)
SimClock.get_time_stamp_array(sst_s)  -> [years, days, hours, minutes, seconds, hundredths]
SimClock.get_time_stamp_string(sst_s) -> "[YYYY:DDD:HH:MM:SS:hh]"
SimClock.get_date(time_stamp: Array[int]) -> [year, month, day]   # 1-based
SimClock.get_date_string(time_stamp)  -> "DD MonthName YYYY"
```

---

## SolarSystemModel  (`autoload_solar_system_sim.gd`)

**Class:** `SolarSystemModel` — Autoload Singleton

The single source of truth for all body positions at any time. Built once from `CoreDataLoader` on `_ready()`, then updated on every `SimClock.sim_clock_tick`.

### Internal State
| Variable | Type | Description |
|---|---|---|
| `_bodies_by_id` | `Dictionary` | `id → BodyDef`, flat lookup for all bodies |
| `_update_order` | `Array[BodyDef]` | Topologically sorted — parents always before their children |
| `_current_state` | `Dictionary` | `id → Vector2`, world-space positions in km at current sst_s |
| `_local_orbit_path_cache` | `Dictionary` | `id → Array[Vector2]`, pre-calculated orbit path points relative to parent origin. Built once, never invalidated. |

### Initialization Sequence
1. `_build_sim_from_loader()` — loads all `BodyDef`s from `CoreDataLoader`
2. `_build_update_order()` — topological sort via Kahn's algorithm; fails with error on cycles or dangling `parent_id`s
3. `_update_simulation(0.0)` — calculates initial positions for all bodies
4. `_build_local_orbit_path()` per body — pre-calculates orbit path points and writes to cache

### Position Calculation

Dispatch in `_calculate_world_position_for_body()` based on `body.motion.model`:

| Motion model | Notes |
|---|---|
| `"fixed"` | Static offset from parent origin |
| `"circular"` | Uniform circular orbit |
| `"kepler2d"` | Elliptical orbit; period derived from `a_km` and parent `mu_km3_s2`; Newton-Raphson Kepler solver |
| `"lagrange"` | Derived from current positions of `primary_id` and `secondary_id` via Hill sphere approximation |

All positions are **world-space `Vector2` in km**, absolute from the simulation origin. The star center is always `Vector2.ZERO`.

### Public API
```gdscript
# Position
SolarSystemModel.get_body_position(id: String) -> Vector2            # world-space km
SolarSystemModel.get_local_orbit_path(id: String) -> Array[Vector2] # relative to parent

# Body lookup
SolarSystemModel.get_body(id: String) -> BodyDef
SolarSystemModel.get_all_body_ids() -> Array
SolarSystemModel.get_child_bodies(parent_id: String) -> Array[BodyDef]
SolarSystemModel.get_bodies_by_type(type: String) -> Array[BodyDef]
SolarSystemModel.get_children_by_type(parent_id, type) -> Array[BodyDef]
SolarSystemModel.get_root_bodies() -> Array[BodyDef]

# Signal
SolarSystemModel.simulation_updated   # emitted after every _current_state update, only while clock is running
```

---

## CoreDataLoader  (`core_data_loader.gd`)

**Class:** `CoreDataLoader extends RefCounted` — not a singleton, instantiated once by `SolarSystemModel` at startup. Has no runtime role after the initial build.

Reads `res://data/solar_system_sim_data.json` and parses it into typed `BodyDef` objects.

```gdscript
CoreDataLoader.new().load_all_body_defs() -> Array[BodyDef]
CoreDataLoader.new().load_body_def(body_id: String) -> BodyDef
```

> The expected JSON structure is defined in [`SPEC_solar_system_sim_data.md`](./SPEC_solar_system_sim_data.md).

---

## Data Classes

### BodyDef  (`body_def.gd`)

Immutable after construction — all setters are no-ops. Fields are written directly to backing `_variables` by `CoreDataLoader` only.

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique technical ID (lowercase snake_case) |
| `name` | `String` | Display name |
| `type` | `String` | `"star"` `"planet"` `"dwarf"` `"moon"` `"struct"` |
| `subtype` | `String` | Subcategory within type — see Spec |
| `parent_id` | `String` | ID of parent body; `""` = root |
| `radius_km` | `float` | Physical radius in km |
| `mu_km3_s2` | `float` | Standard gravitational parameter μ = G·M in km³/s² |
| `map_icon` | `String` | Icon key for map rendering |
| `color_rgba` | `Color` | Display color |
| `motion` | `BaseMotionDef` | Motion definition (typed subclass) |
| `map_tags` | `Array[String]` | Map filtering / grouping tags |
| `gameplay_tags` | `Array[String]` | Gameplay logic tags |

Helper methods: `is_root() -> bool`, `has_motion() -> bool`

### Motion Def Class Hierarchy

```
BaseMotionDef           _model: String (read-only)
├── FixedMotionDef      model = "fixed"
├── CircularMotionDef   model = "circular"
├── Kepler2DMotionDef   model = "kepler2d"
└── LagrangeMotionDef   model = "lagrange"
```

All motion defs are immutable after construction. For the full parameter reference of each model see [`SPEC_solar_system_sim_data.md → Motion-Modelle`](./SPEC_solar_system_sim_data.md#motion-modelle).

---

## Design Notes

- **Data-agnostic simulation:** The entire codebase is generic. Any star system can be expressed purely through a different `solar_system_sim_data.json` — no code changes required.
- **Immutability:** `BodyDef` and all `MotionDef` subclasses enforce read-only access after construction via no-op setters. Only `CoreDataLoader` writes to backing fields.
- **Determinism:** Position calculation is a pure function of `sst_s` and the loaded data. No randomness, no gameplay state bleeds in.
- **Coordinate system:** 2D (x/y plane), world-space, km. Star center = `(0, 0)`. Rendering systems are responsible for scaling to screen space.
- **Orbit path cache:** Built once on load, never invalidated. Points are relative to the parent body's world position, so they can be rendered by a node that is parented to the moving parent without recalculation.
- **`simulation_updated` vs `sim_clock_tick`:** `simulation_updated` only fires when the clock is running. On a hard `set_sst_s()` call, `sim_clock_tick` fires and `_update_simulation` runs, but `simulation_updated` is **not** emitted — downstream systems should connect to `sim_clock_tick` directly if they need to react to hard time jumps.
