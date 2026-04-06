# Sim Core — Dokumentation

> Stand: 2026-03-21 · Beschreibt `SimulationClock`, `SolarSystemModel`, `CoreDataLoader` und alle Datendefinitionen

---

## Überblick

Der Sim Core ist die **Simulationsgrundlage** des Spiels. Er berechnet deterministisch die Position aller Himmelskörper zu jedem beliebigen Zeitpunkt und stellt diese Daten dem Rest des Projekts zur Verfügung.

```
core/
├── sim_clock.gd              # Zeitgeber: treibt den Update-Loop
├── solar_system_sim.gd       # Positionssimulation: Zustand aller Körper
├── core_data_loader.gd       # JSON-Loader für Bodies & Structs
└── defs/
    ├── body_def.gd            # Datenklass: Himmelskörper
    ├── base_motion_def.gd     # Basisklasse für Bewegungsmodelle
    ├── fixed_motion_def.gd    # Bewegungsmodell: Feste Position
    ├── circular_motion_def.gd # Bewegungsmodell: Kreisbahn
    ├── kepler2d_motion_def.gd # Bewegungsmodell: Keplersche Ellipse
    ├── lagrange_motion_def.gd # Bewegungsmodell: Lagrange-Punkt
    ├── belt_def.gd            # Datenklass: Asteroidengürtel / Trojaner
    └── zone_def.gd            # Datenklass: Räumliche Zone
```

**Kein Autoload.** `SimulationClock` und `SolarSystemModel` werden von `main.gd` instanziiert, als Kinder eingehängt und per `setup()` verbunden. Andere Systeme (z. B. das Map Toolkit) erhalten Referenzen über Dependency Injection.

---

## Architektur: Signal-getriebener Update-Loop

```
_physics_process (fixed rate)
    │
    ▼
SimulationClock  ──► sim_clock_tick(sst_s)
                              │
                              ▼
                    SolarSystemModel._update_simulation(sst_s)
                              │
                              ▼
                    Topologisch sortierter Update aller Körper
                    (Eltern immer vor Kindern)
                              │
                              ▼
                    simulation_updated  ──►  Views / UI
```

`SimulationClock` läuft in `_physics_process` → feste Tick-Rate unabhängig von FPS.
`SolarSystemModel` hört nur auf `sim_clock_tick` → kein direkter Frame-Zugriff nötig.

---

## Komponenten

### `SimulationClock`

Zentraler Zeitgeber. Seine einzige Aufgabe ist, den Simulationszeitpunkt (`sst_s`) vorzurücken und das Tick-Signal zu feuern.

**Zeiteinheit:** Simulationssekunden seit `t_0 = 0`. Der Faktor `time_scale` gibt an, wie viele Simulationssekunden pro Echtzeitsekunde verstreichen. Standardwert: `86400.0` (1 Echtzeitsekunde = 1 Simulationstag).

```gdscript
setup(start_sst_s: float = 0.0) -> void

# Signale
sim_clock_tick(sst_s: float)           # Jeder Physik-Tick
sim_clock_time_scale_changed(ts: float)
sim_started
sim_stopped
```

**Clock Control:**
```gdscript
start() -> void
stop() -> void
toggle() -> void
set_sst_s(sst_s: float) -> void         # Sprung zu Zeitpunkt (feuert tick)
set_time_scale(to: float) -> void       # Minimum: 1.0
```

**Lookup:**
```gdscript
is_running() -> bool
get_sst_s_now() -> float
get_time_scale() -> float
```

**Zeitstempel-Funktionen:**

Der `SimulationClock` rechnet `sst_s` in ein fiktives Kalendersystem um (360 Tage/Jahr, 12 Monate à 30 Tage).

```gdscript
# Statisch — kann ohne Instanz aufgerufen werden
static get_time_stamp_array(sst_s: float) -> Array
# → [year, day_of_year, hour, minute, second, hundredths]

# Instanz-Varianten (nutzen aktuelles _sst_s)
get_time_stamp_array_now() -> Array
get_time_stamp_string(sst_s: float) -> String   # "[YYYY:DDD:HH:MM:SS:cc]"
get_time_stamp_string_now() -> String

# Datumsberechnung
get_date(time_stamp: Array[int]) -> Array[int]        # → [year, month, day]
get_date_string(time_stamp: Array[int]) -> String     # "5 Terran 42"
```

**Kalender-Konstanten:**

| Konstante | Wert |
|---|---|
| `DAYS_PER_YEAR` | 360 |
| `MONTHS_PER_YEAR` | 12 |
| `DAYS_PER_MONTH` | 30 |
| `DAYS_PER_WEEK` | 6 |
| `WEEKS_PER_YEAR` | 60 |

Monatsnamen: Helar, Selen, Meron, Venar, Terran, Aresan, Jovan, Satyr, Uranor, Nevaris, Pluton, Ceron.

---

### `SolarSystemModel`

Hält den vollständigen Positionszustand aller Himmelskörper zu jedem Simulationszeitpunkt. Empfängt `sim_clock_tick` und berechnet daraufhin alle Positionen neu.

```gdscript
setup(
    clock: SimulationClock,
    bodies_path: String = CoreDataLoader.DEFAULT_DATA_PATH,
    structs_path: String = CoreDataLoader.DEFAULT_STRUCTS_PATH
) -> void

# Signal
simulation_updated   # Gefeuert nach jedem Update-Zyklus (wenn Uhr läuft)
```

**Public API — Körper abfragen:**

```gdscript
get_all_body_ids() -> Array                            # Alle IDs (Bodies + Structs)
get_body(id: String) -> BodyDef                        # BodyDef oder null
get_body_position(id: String) -> Vector2               # Weltposition in km (aktueller Tick)
get_body_orbit_radius_km(id: String) -> float          # Bahnradius in km (a_km / orbital_radius_km)
```

**Positionen zu beliebigem Zeitpunkt:**

```gdscript
get_body_positions_at_time(ids: Array[String], sst: float) -> Dictionary
# → { "body_id": Vector2, ... }
# Berechnet nur die angefragten Körper + deren gesamte Elternkette.

get_body_position_at_time(id: String, sst: float) -> Vector2
```

**Konfiguration:**

```gdscript
max_segments: float = 512.0   # Maximale Segmentanzahl für Kepler2D-Orbitpfade
```

**Orbitpfade (gecacht, lokal zum Elternkörper):**

```gdscript
get_local_orbit_path(id: String) -> Array[Vector2]
# Vorberechneter Pfad in lokalen Koordinaten (relativ zum Elternkörper).
# Für circular: immer 64 Punkte.
# Für kepler2d: 64–512 Punkte, skaliert mit Exzentrizität (gesteuert von max_segments).
```

**Strukturelle Abfragen:**

```gdscript
get_child_bodies(parent_id: String) -> Array[BodyDef]
get_bodies_by_type(type: String) -> Array[BodyDef]
get_children_by_type(parent_id: String, type: String) -> Array[BodyDef]
get_root_bodies() -> Array[BodyDef]                    # Körper ohne parent_id
```

**Interner Update-Order:**
Beim Laden wird eine **topologisch sortierte** Liste aller Körper gebaut (Kahn's Algorithmus). Dadurch ist garantiert, dass jeder Elternkörper berechnet ist, bevor seine Kinder folgen. Zirkelreferenzen im JSON werden als Fehler gemeldet.

---

### `CoreDataLoader`

Deserialisiert `BodyDef`-Objekte aus JSON-Dateien. Kein Node — wird als lokale Instanz erzeugt.

```gdscript
load_all_body_defs(data_path: String = DEFAULT_DATA_PATH) -> Array[BodyDef]
load_all_struct_defs(data_path: String = DEFAULT_STRUCTS_PATH) -> Array[BodyDef]
load_body_def(body_id: String, data_path: String = DEFAULT_DATA_PATH) -> BodyDef
```

Standardpfade:
- Bodies: `res://data/solar_system_data.json`
- Structs: `res://data/struct_data.json`

---

## Datendefinitionen

### `BodyDef`

Unveränderliche Datenklass (`RefCounted`) für einen Himmelskörper. Alle Properties sind read-only (Setter sind leer).

```gdscript
id: String           # Eindeutige technische ID
name: String         # Anzeigename
type: String         # "star" | "planet" | "dwarf" | "moon" | "struct"
subtype: String      # Feinere Kategorisierung (z.B. "terrestrial", "g_type")
parent_id: String    # ID des Elternkörpers; "" bei Wurzelobjekten
radius_km: float     # Physischer Radius in km
mu_km3_s2: float     # Gravitationsparameter μ in km³/s²
map_icon: String     # Icon-Symbolname für die Karte
color_rgba: Color    # Darstellungsfarbe
motion: BaseMotionDef
map_tags: Array[String]       # Tags für Kartendarstellung & Filterung
gameplay_tags: Array[String]  # Tags für Spiellogik

# Hilfsmethoden
is_root() -> bool    # true wenn parent_id == ""
has_motion() -> bool # true wenn motion != null
```

---

### Bewegungsmodelle

Alle Bewegungsmodelle erben von `BaseMotionDef` und haben eine read-only `model`-Property (`"fixed"` | `"circular"` | `"kepler2d"` | `"lagrange"`).

#### `FixedMotionDef` — `model = "fixed"`

Feste Position relativ zum Elternkörper. Zeitunabhängig.

```gdscript
x_km: float   # Horizontaler Offset vom Eltern
y_km: float   # Vertikaler Offset vom Eltern
```

#### `CircularMotionDef` — `model = "circular"`

Ideale Kreisbahn um den Elternkörper.

```gdscript
orbital_radius_km: float  # Bahnradius in km
phase_rad: float          # Startwinkel in Radiant
period_s: float           # Umlaufdauer in Sekunden
clockwise: bool           # true = Uhrzeigersinn
```

Formel: `θ(t) = phase_rad ± (TAU / period_s) × t`

#### `Kepler2DMotionDef` — `model = "kepler2d"`

Physikalisch korrekte Ellipsenbahn (2D-Kepler). Die exzentrische Anomalie wird per Newton-Raphson-Iteration gelöst.

```gdscript
a_km: float                    # Große Halbachse in km
e: float                       # Exzentrizität (0 = Kreis, 0..1 = Ellipse)
arg_pe_rad: float              # Argument des Periapsis in Radiant
mean_anomaly_epoch_rad: float  # Mittlere Anomalie zur Epoche
epoch_tt_s: float              # Epochenzeitpunkt in Simulationssekunden
clockwise: bool                # true = Uhrzeigersinn
```

Perioden-Formel: `T = TAU × sqrt(a³ / μ_parent)`

#### `LagrangeMotionDef` — `model = "lagrange"`

Position an einem Lagrange-Punkt zwischen zwei Körpern. Zeitunabhängig (folgt dem Sekundärkörper).

```gdscript
primary_id: String    # ID des Primärkörpers (z.B. Stern)
secondary_id: String  # ID des Sekundärkörpers (z.B. Planet)
point: int            # Lagrange-Punkt: 1–5
```

**Approximationen:**
- **L1/L2:** Hill-Radius-basiert: `r_hill = dist × (μ_secondary / (3 × μ_primary))^(1/3)`
- **L3:** Gegenüberliegend (spiegelbildlich zum Sekundärkörper)
- **L4:** `+60°` vor dem Sekundärkörper (Trojaner)
- **L5:** `−60°` hinter dem Sekundärkörper (Trojaner)

---

## JSON-Datenformat

### `solar_system_data.json`

```json
{
  "bodies": [
    {
      "id": "sun",
      "name": "Sun",
      "type": "star",
      "subtype": "g_type",
      "parent_id": "",
      "radius_km": 696340.0,
      "mu_km3_s2": 132712440018.0,
      "map_icon": "sun",
      "color_rgba": [1.0, 0.85, 0.3, 1.0],
      "map_tags": ["inner_system", "major_body"],
      "gameplay_tags": [],
      "motion": {
        "model": "fixed",
        "params": { "x_km": 0.0, "y_km": 0.0 }
      }
    },
    {
      "id": "mercury",
      "type": "planet",
      "parent_id": "sun",
      "mu_km3_s2": 22031.78,
      "motion": {
        "model": "kepler2d",
        "params": {
          "a_km": 57909227.0,
          "e": 0.2056,
          "arg_pe_rad": 0.509,
          "mean_anomaly_epoch_rad": 3.05,
          "epoch_tt_s": 0.0,
          "clockwise": false
        }
      }
    }
  ]
}
```

### `struct_data.json`

Gleiche Struktur, aber Root-Key heißt `"structs"`. Structs haben `"type": "struct"` und einen `parent_id`, dem sie folgen.

---

## Integrations-Pattern

### Setup (in `main.gd`)

```gdscript
# 1. Clock erzeugen und einrichten
sim_clock = SimulationClock.new()
sim_clock.name = "SimClock"
add_child(sim_clock)
sim_clock.setup(start_sst_s)

# 2. SolarSystem erzeugen und einrichten (add_child VOR setup!)
solar_system = SolarSystemModel.new()
solar_system.name = "SolarSystem"
add_child(solar_system)
solar_system.setup(sim_clock, bodies_path, structs_path)
```

### Positionen pro Frame abfragen

```gdscript
# Empfohlen: auf simulation_updated reagieren (statt _process)
solar_system.simulation_updated.connect(_on_simulation_updated)

func _on_simulation_updated() -> void:
    var pos: Vector2 = solar_system.get_body_position("earth")
    var orbit_km: float = solar_system.get_body_orbit_radius_km("earth")
```

### Zeitkontrolle

```gdscript
sim_clock.set_time_scale(86400.0 * 30)  # 30 Tage / Echtzeitsekunde
sim_clock.stop()
sim_clock.start()
sim_clock.toggle()

# Zeitsprung
sim_clock.set_sst_s(target_sst_s)       # Feuert einmalig sim_clock_tick
```

### Zukünftige Positionen berechnen (ohne Zeitsprung)

```gdscript
var future_sst := sim_clock.get_sst_s_now() + 86400.0 * 365.0
var positions := solar_system.get_body_positions_at_time(["earth", "mars"], future_sst)
var earth_next_year: Vector2 = positions["earth"]
```

### Zeitstempel anzeigen

```gdscript
sim_clock.sim_clock_tick.connect(func(sst_s):
    var stamp := SimulationClock.get_time_stamp_array(sst_s)
    var date  := sim_clock.get_date_string(stamp)
    label.text = date   # z.B. "15 Aresan 3"
)
```

---

## Verantwortlichkeit des Cores

Der Core übernimmt **ausschließlich** Zeitverwaltung und Positionsberechnung. Folgendes liegt bei den Konsumenten:

- Kamera- und Eingabesteuerung
- Koordinatentransformation (→ Map Toolkit)
- Sichtbarkeitsfilterung (→ Map Toolkit)
- Rendering (→ Map Toolkit)
- Belt- und Zone-Definitionen laden (→ `MapDataLoader`)
- Spiellogik und Ereignisse
