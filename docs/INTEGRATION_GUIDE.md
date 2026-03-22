# Integration Guide — StarChartView

Schritt-für-Schritt Anleitung um die StarChartView in das Projekt einzubauen.

---

## Schritt 1: Dateien kopieren

Alle neuen Dateien nach `game/map/views/star_chart/` kopieren:

```
game/map/views/star_chart/
├── StarChartView.tscn          ← ERSETZT die alte (nur WorldEnv + Glow)
├── SelectionRing.tscn          ← NEU
├── star_chart_view.gd          ← NEU
├── selection_ring.gd           ← NEU
├── grid_layer.gd               ← NEU
├── zone_layer.gd               ← NEU
├── belt_layer.gd               ← NEU
└── orbit_layer.gd              ← NEU
```

> Die alte `StarChartView.tscn` wird komplett ersetzt. Die neue enthält
> alle Nodes (Layer, ViewController, FilterState, SelectionRing).

---

## Schritt 2: Typen in star_chart_view.gd fixen

Die Layer-Referenzen müssen den richtigen Typ haben, damit `.default_opacity`
etc. funktionieren. In `star_chart_view.gd` diese @onready-Zeilen ändern:

```gdscript
# VORHER (falsche Typen):
@onready var _grid_layer:    Node2D = $GridLayer
@onready var _zone_layer:    Node2D = $ZoneLayer
@onready var _belt_layer:    Node2D = $BeltLayer
@onready var _orbit_layer:   Node2D = $OrbitLayer

# NACHHER (richtige Typen):
@onready var _grid_layer:    StarChartGridLayer = $GridLayer
@onready var _zone_layer:    StarChartZoneLayer = $ZoneLayer
@onready var _belt_layer:    StarChartBeltLayer = $BeltLayer
@onready var _orbit_layer:   StarChartOrbitLayer = $OrbitLayer
```

---

## Schritt 3: Zone-Filter-Zeile fixen

In `star_chart_view.gd` → `_refresh_zones()` diese Zeile ändern:

```gdscript
# VORHER (Fehler — .get() auf Resource):
_zone_renderers[zone_id].visible = _filter.is_zone_visible(zone.zone_type) \
                                    if zone.get("zone_type") else true

# NACHHER (direkt auf Property zugreifen):
_zone_renderers[zone_id].visible = _filter.is_zone_visible(zone.zone_type)
```

---

## Schritt 4: star_chart_screen.gd anpassen

Der Screen muss die View instanziieren und in seinen SubViewport einhängen.

### 4a — Preload hinzufügen

Oben im Script, nach den Konstanten:

```gdscript
const STAR_CHART_VIEW := preload("res://game/map/views/star_chart/StarChartView.tscn")
```

### 4b — Variable für die View

Bei den Node-Referenzen:

```gdscript
var _star_chart_view: StarChartView = null
```

### 4c — View in setup() instanziieren

Am Ende von `setup()` (nach den SimClock-Connects und vor `_sync_time_scale_display()`):

```gdscript
func setup(clock: SimulationClock, solar_sys: SolarSystemModel) -> void:
    sim_clock = clock
    solar_system = solar_sys
    sim_clock.sim_clock_tick.connect(_on_sim_tick)
    sim_clock.sim_clock_time_scale_changed.connect(_on_time_scale_changed)
    sim_clock.sim_started.connect(_on_sim_started)
    sim_clock.sim_stopped.connect(_on_sim_stopped)

    # ─── NEU: View instanziieren ─────────────────────────────────
    _star_chart_view = STAR_CHART_VIEW.instantiate()
    _sub_viewport.add_child(_star_chart_view)
    _star_chart_view.setup(sim_clock, solar_system, self)
    # ──────────────────────────────────────────────────────────────

    _sync_time_scale_display()
    _update_play_pause_display()
```

> **Wichtig:** `_build_ui()` läuft in `_ready()` — das passiert BEVOR `setup()`
> aufgerufen wird. Also existiert `_sub_viewport` bereits wenn setup() läuft.

### 4d — SimClock starten

Der Screen startet die SimClock bisher nicht. Die View braucht sie laufend.
Am Ende von `setup()` hinzufügen:

```gdscript
    sim_clock.start()
```

Oder alternativ in `main.gd` nach `star_chart_screen.setup(...)`:

```gdscript
    sim_clock.start()
```

---

## Schritt 5: Smoke Test

1. Projekt in Godot öffnen
2. Auf Parse-Fehler prüfen (Output-Panel)
3. Hauptszene starten

### Was du sehen solltest:

- Star Chart UI (Header, Footer, InfoPanel) — wie vorher
- Im Viewport: Sonne + Planeten mit Orbitbahnen
- Konzentrische Ringe + Quadrat-Grid im Hintergrund
- Mausrad → Zoom funktioniert
- Mittelklick/WASD → Pan funktioniert
- Klick auf Body → InfoPanel füllt sich, grüner Ring erscheint
- Doppelklick auf Body → Zoom-to-fit, Monde werden sichtbar
- Escape → zurück zum vorherigen Zoom
- FILTER-Button → Settings-Panel links

---

## Mögliche Probleme & Fixes

### "Cannot find node MapViewController"
Die StarChartView.tscn referenziert `map_view_controller.gd` über den Pfad
`res://game/map/toolkit/map_view_controller.gd`. Prüfe ob die Datei dort liegt.

### "Cannot find node MapFilterState"
Gleich — prüfe `res://game/map/toolkit/filter/map_filter_state.gd`.

### "Invalid call. Nonexistent function 'is_orbit_visible'"
`MapFilterState` braucht die Methode `is_orbit_visible(parent_type: String) -> bool`.
Falls die noch nicht implementiert ist, temporärer Workaround in `star_chart_view.gd`:

```gdscript
# In _refresh_bodies(), Orbit-Sichtbarkeit:
var orbit_vis := is_vis  # Filter-Check temporär weglassen
# var orbit_vis := is_vis and _filter.is_orbit_visible(body.type)
```

### "Invalid call. Nonexistent function 'is_zone_visible'"
Gleich — `MapFilterState` braucht `is_zone_visible(zone_type: String) -> bool`.
Temporärer Workaround: Zone-Filter-Zeile auskommentieren.

### "Invalid call. Nonexistent function 'is_belt_visible'"
Gleich — `MapFilterState` braucht `is_belt_visible(belt_id: String) -> bool`.

### Selection-Ring unsichtbar trotz Selektion
SelectionRing.tscn hat `visible = false` als Default. Das ist korrekt —
`set_target()` setzt `visible = true`. Falls trotzdem unsichtbar: prüfe ob
`_selection_ring` nicht `null` ist (Pfad: `$OverlayLayer/SelectionRing`).

### Kein Glow-Effekt
WorldEnvironment braucht einen passenden Render-Modus. Falls der SubViewport
kein Glow zeigt: prüfe ob `render_target_update_mode = UPDATE_ALWAYS` und
`transparent_bg = true` gesetzt ist.

### Bodies alle bei (0,0)
SimClock läuft nicht → `simulation_updated` wird nie gefeuert → Positionen
bleiben bei 0. Sicherstellen dass `sim_clock.start()` aufgerufen wird.

---

## Dateistruktur nach Integration

```
game/
├── main.gd
├── screens/
│   ├── StarChartScreen.tscn
│   └── star_chart_screen.gd          ← angepasst (Schritt 4)
└── map/
    ├── toolkit/
    │   ├── map_view_controller.gd     ← existiert
    │   ├── MapViewController.tscn     ← existiert
    │   ├── map_camera_controller.gd   ← existiert
    │   ├── map_data_loader.gd         ← existiert
    │   ├── filter/
    │   │   ├── map_filter_state.gd    ← existiert
    │   │   └── MapFilterState.tscn    ← existiert
    │   ├── renderer/                  ← alle existieren
    │   └── scale/
    │       └── map_scale.gd           ← existiert
    └── views/
        └── star_chart/
            ├── StarChartView.tscn     ← NEU (ersetzt alte)
            ├── SelectionRing.tscn     ← NEU
            ├── star_chart_view.gd     ← NEU
            ├── selection_ring.gd      ← NEU
            ├── grid_layer.gd          ← NEU
            ├── zone_layer.gd          ← NEU
            ├── belt_layer.gd          ← NEU
            └── orbit_layer.gd         ← NEU
```
