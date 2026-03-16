# Sonnensystem-Simulation — Kernarchitektur

> Architektur-Referenz für den Simulationskern
> Stand: 2026-03-15

---

## Überblick

Der Simulationskern ist ein deterministisches, zeitgesteuertes Sonnensystemmodell. Er berechnet die Welt-Positionen aller Himmelskörper zu jedem beliebigen Zeitpunkt der Simulationszeit. Er ist vollständig unabhängig von Gameplay-Ereignissen (Schiffe, Kampf, Wirtschaft etc.) und hat keine Seiteneffekte — bei gleicher Zeiteingabe liefert er immer das gleiche Ergebnis.

Der Kern besteht aus zwei Autoload-Singletons, einer Lade-Utility und einem Satz von Datenklassen. Er wird von einer einzigen JSON-Datei angetrieben, die das Sonnensystem beschreibt. Diese Datendatei ist das Einzige, was geändert werden muss, um ein völlig anderes Sternensystem zu definieren — der Simulationscode ist generisch und daten-agnostisch.

> **Datenformat:** Siehe [`SPEC_solar_system_sim_data.md`](./SPEC_solar_system_sim_data.md) für das vollständige Schema, Type-System, Subtype-Taxonomie, Motion-Modell-Parameter, Tag-System und Körper-Hierarchie.

---

## Autoload-Ladereihenfolge (wichtig)

```
1. SimClock      (autoload_sim_clock.gd)
2. SolarSystem   (autoload_solar_system_sim.gd)
```

`SolarSystem` verbindet sich in seiner `_ready()`-Methode mit `SimClock.sim_clock_tick`, daher muss SimClock zuerst geladen werden.

---

## Datenfluss

```
solar_system_sim_data.json
  │
  │  einmalig beim Start gelesen
  ▼
CoreDataLoader
  │  parst JSON → Array[BodyDef]
  ▼
SolarSystemModel._build_sim_from_loader()
  │  topologische Sortierung (Kahn) → _update_order
  │  initiale Positionsberechnung
  │  Orbit-Pfad-Cache aufbauen
  │
  │  dann, jeden Physics-Frame:
  │
SimClock
  │  sim_clock_tick(sst_s: float)
  ▼
SolarSystemModel._update_simulation(sst_s)
  │  iteriert _update_order
  │  berechnet Weltposition pro Körper → _current_state
  │
  │  simulation_updated  [Signal]
  ▼
Renderer / UI / Gameplay-Systeme
     Abfrage via get_body_position(id) -> Vector2
     Abfrage via get_local_orbit_path(id) -> Array[Vector2]
```

---

## SimClock (`autoload_sim_clock.gd`)

**Klasse:** `SimulationClock` — Autoload-Singleton

Zentraler Zeitgeber. Läuft innerhalb von `_physics_process` für feste Tick-Intervalle.

### Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_sst_s` | `float` | Aktuelle Zeit in Solar Standard Time Sekunden seit t₀ |
| `_time_scale` | `float` | Multiplikator, der pro Tick auf `delta` angewendet wird. Min: 1.0 |
| `_running` | `bool` | Ob die Uhr aktiv tickt |

### Signale

| Signal | Payload | Auslöser |
|---|---|---|
| `sim_clock_tick` | `sst_s: float` | Jeden Physics-Frame während die Uhr läuft |
| `sim_clock_time_scale_changed` | `time_scale: float` | Bei Änderung der Zeitskalierung |
| `sim_started` / `sim_stopped` | — | Bei Zustandswechsel |

### Zeitsystem

- **Einheit:** Solar Standard Time Sekunden (`sst_s`), ein fortlaufender Float ab 0.0 bei Spielstart
- **Jahr:** 360 Tage · 86.400 s = 31.104.000 s
- **Kalender:** 12 Monate × 30 Tage
- **Monatsnamen:** Helar, Selen, Meron, Venar, Terran, Aresan, Jovan, Satyr, Uranor, Nevaris, Pluton, Ceron

### API

```gdscript
SimClock.start() / stop() / toggle()
SimClock.set_time_scale(factor: float)      # min 1.0
SimClock.set_sst_s(sst_s: float)            # harter Zeitsprung, emittiert Tick
SimClock.get_sst_s_now() -> float
SimClock.get_time_scale() -> float
SimClock.is_running() -> bool

# Zeitformatierung (alle auch als _now()-Kurzformen verfügbar)
SimClock.get_time_stamp_array(sst_s)  -> [years, days, hours, minutes, seconds, hundredths]
SimClock.get_time_stamp_string(sst_s) -> "[YYYY:DDD:HH:MM:SS:hh]"
SimClock.get_date(time_stamp: Array[int]) -> [year, month, day]   # 1-basiert
SimClock.get_date_string(time_stamp)  -> "DD Monatsname YYYY"
```

---

## SolarSystem (`autoload_solar_system_sim.gd`)

**Klasse:** `SolarSystemModel` — Autoload-Singleton, registriert als `SolarSystem`

Die zentrale Quelle der Wahrheit für alle Körper-Positionen zu jedem Zeitpunkt. Wird einmalig aus `CoreDataLoader` bei `_ready()` aufgebaut und bei jedem `SimClock.sim_clock_tick` aktualisiert.

### Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_bodies_by_id` | `Dictionary` | `id → BodyDef`, flache Lookup-Tabelle für alle Körper |
| `_update_order` | `Array[BodyDef]` | Topologisch sortiert — Eltern immer vor ihren Kindern |
| `_current_state` | `Dictionary` | `id → Vector2`, Weltpositionen in km zum aktuellen sst_s |
| `_local_orbit_path_cache` | `Dictionary` | `id → Array[Vector2]`, vorberechnete Orbit-Pfadpunkte relativ zum Parent-Ursprung. Einmalig berechnet, nie invalidiert. |

### Initialisierungsreihenfolge

1. `_build_sim_from_loader()` — lädt alle `BodyDef`s aus `CoreDataLoader`
2. `_build_update_order()` — topologische Sortierung via Kahn-Algorithmus; schlägt mit Fehler fehl bei Zyklen oder ungültigen `parent_id`s
3. `_update_simulation(0.0)` — berechnet initiale Positionen für alle Körper
4. `_build_local_orbit_path()` pro Körper — berechnet Orbit-Pfadpunkte vor und schreibt sie in den Cache

### Positionsberechnung

Dispatch in `_calculate_world_position_for_body()` basierend auf `body.motion.model`:

| Bewegungsmodell | Beschreibung |
|---|---|
| `"fixed"` | Statischer Offset vom Parent-Ursprung |
| `"circular"` | Gleichförmige Kreisbahn |
| `"kepler2d"` | Elliptische Bahn; Periode abgeleitet aus `a_km` und `mu_km3_s2` des Elternkörpers; Newton-Raphson Kepler-Löser |
| `"lagrange"` | Abgeleitet aus aktuellen Positionen von `primary_id` und `secondary_id` via Hill-Sphären-Approximation |

Alle Positionen sind **Welt-`Vector2` in km**, absolut vom Simulationsursprung. Das Zentralgestirn steht immer bei `Vector2.ZERO`.

### Öffentliche API

```gdscript
# Position
SolarSystem.get_body_position(id: String) -> Vector2            # Welt-km
SolarSystem.get_local_orbit_path(id: String) -> Array[Vector2] # relativ zum Parent

# Körper-Abfragen
SolarSystem.get_body(id: String) -> BodyDef
SolarSystem.get_all_body_ids() -> Array
SolarSystem.get_child_bodies(parent_id: String) -> Array[BodyDef]
SolarSystem.get_bodies_by_type(type: String) -> Array[BodyDef]
SolarSystem.get_children_by_type(parent_id, type) -> Array[BodyDef]
SolarSystem.get_root_bodies() -> Array[BodyDef]

# Signal
SolarSystem.simulation_updated   # emittiert nach jedem _current_state-Update, nur bei laufender Uhr
```

---

## CoreDataLoader (`core_data_loader.gd`)

**Klasse:** `CoreDataLoader extends RefCounted` — kein Singleton, wird einmalig von `SolarSystemModel` beim Start instanziiert. Hat nach dem initialen Aufbau keine Laufzeit-Rolle.

Liest `res://data/solar_system_sim_data.json` und parst die Daten in typisierte `BodyDef`-Objekte.

```gdscript
CoreDataLoader.new().load_all_body_defs() -> Array[BodyDef]
CoreDataLoader.new().load_body_def(body_id: String) -> BodyDef
```

> Die erwartete JSON-Struktur ist in [`SPEC_solar_system_sim_data.md`](./SPEC_solar_system_sim_data.md) definiert.

---

## Datenklassen

### BodyDef (`body_def.gd`)

Unveränderlich nach Konstruktion — alle Setter sind No-Ops. Felder werden direkt auf die Backing-Variablen (`_variables`) ausschließlich durch `CoreDataLoader` geschrieben.

| Eigenschaft | Typ | Beschreibung |
|---|---|---|
| `id` | `String` | Eindeutige technische ID (lowercase snake_case) |
| `name` | `String` | Anzeigename |
| `type` | `String` | `"star"` `"planet"` `"dwarf"` `"moon"` `"struct"` |
| `subtype` | `String` | Unterkategorie innerhalb des Typs — siehe Spec |
| `parent_id` | `String` | ID des Elternkörpers; `""` = Wurzelobjekt |
| `radius_km` | `float` | Physischer Radius in km |
| `mu_km3_s2` | `float` | Standard-Gravitationsparameter μ = G·M in km³/s² |
| `map_icon` | `String` | Symbolschlüssel für Kartendarstellung |
| `color_rgba` | `Color` | Darstellungsfarbe |
| `motion` | `BaseMotionDef` | Bewegungsdefinition (typisierte Subklasse) |
| `map_tags` | `Array[String]` | Tags für Kartenfilterung / Gruppierung |
| `gameplay_tags` | `Array[String]` | Tags für Gameplay-Logik |

Hilfsmethoden: `is_root() -> bool`, `has_motion() -> bool`

### Motion-Def-Klassenhierarchie

```
BaseMotionDef           _model: String (read-only)
├── FixedMotionDef      model = "fixed"
├── CircularMotionDef   model = "circular"
├── Kepler2DMotionDef   model = "kepler2d"
└── LagrangeMotionDef   model = "lagrange"
```

Alle Motion-Defs sind nach Konstruktion unveränderlich. Für die vollständige Parameterreferenz jedes Modells siehe [`SPEC_solar_system_sim_data.md → Motion-Modelle`](./SPEC_solar_system_sim_data.md#motion-modelle).

---

## Design-Hinweise

- **Daten-agnostische Simulation:** Der gesamte Code ist generisch. Jedes Sternensystem kann rein über eine andere `solar_system_sim_data.json` ausgedrückt werden — keine Code-Änderungen nötig.
- **Unveränderlichkeit:** `BodyDef` und alle `MotionDef`-Subklassen erzwingen schreibgeschützten Zugriff nach Konstruktion via No-Op-Setter. Nur `CoreDataLoader` schreibt auf die Backing-Felder.
- **Determinismus:** Die Positionsberechnung ist eine reine Funktion von `sst_s` und den geladenen Daten. Kein Zufall, kein Gameplay-Zustand fließt ein.
- **Koordinatensystem:** 2D (x/y-Ebene), Weltraum, km. Zentralgestirn = `(0, 0)`. Rendering-Systeme sind für die Skalierung auf Bildschirmkoordinaten verantwortlich.
- **Orbit-Pfad-Cache:** Einmalig beim Laden berechnet, nie invalidiert. Punkte sind relativ zur Weltposition des Elternkörpers, sodass sie von einem Node gerendert werden können, das an den sich bewegenden Elternkörper angehängt ist — ohne Neuberechnung.
- **`simulation_updated` vs. `sim_clock_tick`:** `simulation_updated` feuert nur bei laufender Uhr. Bei einem harten `set_sst_s()`-Aufruf feuert `sim_clock_tick` und `_update_simulation` läuft, aber `simulation_updated` wird **nicht** emittiert — nachgelagerte Systeme sollten sich direkt mit `sim_clock_tick` verbinden, wenn sie auf harte Zeitsprünge reagieren müssen.
