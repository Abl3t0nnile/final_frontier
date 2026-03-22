# SPEC: Map Toolkit

> v3 · Stand: 2026-03-22

---

## 1 — Kontext

Final Frontier ist ein Space-Simulationsspiel im Stil von Sid Meier's Pirates. Der Spieler steuert ein Raumschiff durch das Sonnensystem, fliegt von Planet zu Planet, von Mond zu Station. In Häfen interagiert er über Menüs: Dialoge, Handel, Schiffsausrüstung. Für Navigation und Erkundung nutzt der Spieler kartenbasierte Ansichten.

Das Spiel besteht aus unabhängigen Systemen:

- **Sim Core** — Deterministische Orbitalsimulation. Berechnet Positionen aller Himmelskörper zu einem gegebenen Zeitpunkt. Zentrale SimClock als Zeitbasis.
- **Map Toolkit** — Wiederverwendbare Werkzeuge für kartenbasierte Ansichten.
- **Schiff, Crew, Häfen** — Eigenständige Systeme, folgen später.

### Alpha 1.0 Scope

Der Sim Core ist fertig. Das Map Toolkit und eine vollständige Star Chart werden gebaut. Die Star Chart ist ein interaktiver Atlas des Sonnensystems — frei erkundbar, mit InfoPanel für physikalische, orbitale und Metadaten inklusive Beschreibungstexten.

---

## 2 — Geplante Ansichten

| View | Beschreibung | Status |
|---|---|---|
| Star Chart | Sonnensystem-Atlas, freie Erkundung, Kursplanung | Alpha 1.0 |
| System-Detailansicht | Einzelnes Planetensystem, Monde und Stationen | Geplant |
| Taktische Übersicht | Flotten, Bedrohungen, Einflusszonen | Geplant |
| SensorDisplay | Schiffs-Nahbereich, Kontakte, Sensorreichweiten | Geplant |

---

## 3 — Architektur-Prinzip

Das Map Toolkit ist ein **Werkzeugkasten**, keine Pipeline. Es trifft keine Entscheidungen darüber, was sichtbar ist oder wie etwas dargestellt wird. Diese Logik lebt vollständig in der jeweiligen View.

**Der View entscheidet:**

- Welche Objekte gerendert werden (Filter)
- Welcher Transformationsmodus pro Objekt gilt (linear, log, exag)
- Welche Objekte hervorgehoben, gedimmt oder ausgeblendet werden
- Was bei Klick, Doppelklick, Hover passiert (Selektion, Fokus, Pins)
- Welche UI-Elemente angezeigt werden (InfoPanel, Routen, Tooltips)

**Das Toolkit liefert:**

- Koordinaten-Mathe (km↔px, verschiedene Skalierungsmodi)
- Kamera-Navigation (Pan, Zoom, Smoothing, Inertia)
- Input-Interpretation (Maus, Tastatur, Trackpad → Kamera-Befehle + Klick-Signale)
- Zeitcursor (unabhängig von der SimClock)
- Dumme Renderer (zeichnen was und wo man ihnen sagt)

### Beispiel: Kursplanung Mars → Neptun-Station

Der View hat Mars und eine Neptun-Station gepinnt. Er entscheidet:

1. Sonne als Referenz zeigen
2. Mars: Screen-Position über `MapScale.world_to_display()` mit LOG berechnen
3. Neptun: dito, LOG
4. Station: `world_to_display()` relativ zu Neptun, mit EXAG
5. Wichtige Bodies im Bildausschnitt: normal berechnen, Renderer auf gedimmt setzen
6. Unwichtige: gar nicht rendern

Jeder dieser Aufrufe ist eine einzelne Toolkit-Funktion mit expliziten Parametern. Das Toolkit weiß nicht, dass hier eine Kursplanung stattfindet.

---

## 4 — Toolkit-Komponenten

Vier Core-Klassen plus Renderer.

```
toolkit/
├── core/
│   ├── map_scale.gd          # Mathe: Zoom-Zustand + zustandslose Berechnungen
│   ├── map_camera.gd         # Navigation: Smoothing, Inertia, steuert MapScale
│   ├── map_input.gd          # Input: Maus/Tastatur/Touch → Kamera-Befehle
│   └── map_time.gd           # Zeit: Eigener Zeitcursor, unabhängig von SimClock
├── renderer/
│   ├── body_marker.gd        # Klickbares Icon + Label
│   ├── body_sprite.gd        # Maßstabsgetreue Darstellung
│   ├── orbit_renderer.gd     # Orbitbahn als Linienzug
│   ├── belt_renderer.gd      # Partikelbasierte Punktwolke
│   ├── zone_renderer.gd      # Farbfläche (Kreis/Ring)
│   ├── grid_renderer.gd      # Wrapper für Concentric + Square
│   ├── concentric_grid_renderer.gd
│   ├── square_grid_renderer.gd
│   ├── scale_renderer.gd     # Maßstabsbalken (HUD)
│   ├── path_renderer.gd      # Route / Flugbahn (Stub)
│   └── connection_renderer.gd # Relation / Distanz (Stub)
└── data/
    └── map_data_loader.gd    # JSON-Deserialisierung für Belts & Zones
```

---

### 4.1 — MapScale

> RefCounted — Zoom-Zustand + zustandslose Mathe

MapScale hat zwei Seiten. Die eine hält den aktuellen Zoom-Zustand (wird von MapCamera geschrieben). Die andere bietet zustandslose Berechnungsfunktionen, die der View pro Aufruf mit expliziten Parametern füttert.

#### Zoom-Zustand

Wird von MapCamera gesteuert.

```gdscript
set_scale_exp(exp: float)
get_scale_exp() -> float
get_px_per_km() -> float
get_km_per_px() -> float

set_origin(world_km: Vector2)       # Weltposition von Screen (0,0)
get_origin() -> Vector2
```

Logarithmischer Zoom: `km_per_px = 10^scale_exp`. Ein Anstieg von 1.0 = 10× mehr Welt pro Pixel.

#### Basis-Transformation

Nutzt den Zoom-Zustand.

```gdscript
world_to_screen(world_km: Vector2) -> Vector2
screen_to_world(screen_px: Vector2) -> Vector2
km_to_px(km: float) -> float
px_to_km(px: float) -> float
```

#### Hierarchische Transformation

Zustandslos, pro Aufruf parametrisiert. Der View entscheidet welcher Modus und welcher Exag-Faktor pro Objekt gilt.

```gdscript
enum ScaleMode { LINEAR, LOG }

world_to_display(
    world_km: Vector2,
    parent_screen: Vector2,
    orbit_km: float,
    mode: ScaleMode = LINEAR,
    exag_factor: float = 1.0
) -> Vector2
```

#### Sichtbarkeits-Hilfsfunktionen

Zustandslos. Der View gibt alle relevanten Schwellwerte mit.

```gdscript
is_orbit_visible(
    orbit_km: float,
    min_orbit_px: float,
    exag_factor: float = 1.0
) -> bool

is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool

get_cull_rect(
    cam_pos: Vector2,
    vp_size: Vector2,
    margin: float = 100.0
) -> Rect2

calc_fit_scale_exp(
    max_child_orbit_km: float,
    vp_size: Vector2,
    exag_factor: float = 1.0
) -> float
```

---

### 4.2 — MapCamera

> Node — Navigation mit Smoothing

Steuert den Zoom-Zustand in MapScale. Verwaltet Zielposition, Ziel-Zoom, Smoothing, Inertia und Gummiband. Schreibt jeden Frame das geglättete Ergebnis in MapScale. Empfängt nur Befehle, kennt keinen Input.

```gdscript
setup(scale: MapScale, config: Dictionary)

# Navigation
pan_to(world_km: Vector2)                # Smooth gleiten
jump_to(world_km: Vector2)               # Sofort, kein Smoothing
zoom_to(scale_exp: float)                # Smooth
reset_view()                             # Zurück zu Start-Position + Start-Zoom

# Referenz-Anker
set_reference_anchor(world_km: Vector2)  # Zoom zentriert auf diesen Punkt
clear_reference_anchor()                  # Zoom zentriert auf Cursor

# Abfragen
get_world_center() -> Vector2
get_scale_exp() -> float
is_panning() -> bool

# Signale
signal camera_moved
signal zoom_changed(scale_exp: float)
```

#### Config-Dictionary

Alle optional, Defaults pro View.

| Key | Typ | Default | Beschreibung |
|---|---|---|---|
| `scale_exp_min` | float | 1.0 | Untere Zoom-Grenze |
| `scale_exp_max` | float | 11.0 | Obere Zoom-Grenze |
| `scale_exp_start` | float | 7.5 | Start-Zoom |
| `zoom_step` | float | 0.08 | scale_exp-Delta pro Mausrad-Tick |
| `rubber_band_margin` | float | 0.5 | Über-Zoom über Grenzen hinaus |
| `rubber_band_speed` | float | 5.0 | Rückfeder-Geschwindigkeit |
| `pan_inertia_decay` | float | 4.0 | Abbremsfaktor Pan-Trägheit |
| `smooth_zoom_speed` | float | 8.0 | Zoom-Interpolation |
| `smooth_pan_speed` | float | 8.0 | Pan-Interpolation |
| `pan_key_speed_px` | float | 400.0 | Tastatur-Pan px/s |

#### Smoothing (_process)

Pro Frame:

```
1. scale_exp = lerp(scale_exp, target_scale_exp, smooth_zoom_speed × delta)
2. world_center = lerp(world_center, target_center, smooth_pan_speed × delta)
3. Gummiband: scale_exp außerhalb [min, max] → target clampen, zurückfedern
4. Inertia: nicht am pannen + velocity > threshold → target_center -= velocity, velocity × decay
5. map_scale.set_scale_exp(scale_exp)
6. map_scale.set_origin(world_center - viewport_half × km_per_px)
7. Signal: camera_moved
```

---

### 4.3 — MapInput

> Node — Input-Interpretation

Interpretiert rohe Eingaben und ruft MapCamera-Methoden auf. Handhabt Pan und Zoom. Klicks auf BodyMarker gehen direkt über deren Signale an den View — MapInput weiß nichts über Marker.

```gdscript
setup(camera: MapCamera, scale: MapScale, config: Dictionary)
set_enabled(bool)
get_mouse_world_position() -> Vector2

signal empty_click(world_km: Vector2)
signal context_menu(screen_pos: Vector2, world_km: Vector2)
```

#### Input-Mapping (Google Maps Modell + Tastatur)

| Input | Aktion |
|---|---|
| Linksklick + Drag auf leere Fläche | Pan |
| Mausrad | Zoom zum Cursor |
| Pinch (Trackpad/Touch) | Zoom zur Gestenmitte |
| WASD / Pfeiltasten | Pan |
| Q / E | Zoom rein / raus |
| R | Reset View |
| Linksklick ohne Drag auf leere Fläche | `empty_click` Signal |
| Rechtsklick | `context_menu` Signal |

#### Abgrenzung MapInput ↔ BodyMarker

MapInput und BodyMarker sind unabhängig. MapInput verarbeitet Interaktion mit der leeren Kartenfläche. BodyMarker verarbeiten ihre eigenen Klick/Hover-Events und senden Signale direkt an den View. Der View verbindet beide Quellen zu seiner Interaktionslogik.

---

### 4.4 — MapTime

> Node — Zeitcursor

Eigener Zeitcursor, unabhängig von der SimClock. Kann Live folgen oder frei in die Zukunft bewegt werden. Liefert den Zeitpunkt, zu dem die Sim Positionen berechnen soll.

```gdscript
setup(sim_clock: SimulationClock)

# Zeit setzen
set_time(seconds: float)
get_time() -> float
step(delta: float)
set_step_size(seconds: float)

# Play
play()
pause()
is_playing() -> bool
set_play_speed(multiplier: float)    # Frei wählbar (z.B. 1.0, 10.0, 100.0)

# Live-Modus
reset_to_live()
is_live() -> bool
get_offset() -> float

# Anzeige
get_date_string() -> String

# Signale
signal time_changed(seconds: float)
signal live_state_changed(is_live: bool)
```

#### Zwei Modi

**Live:** Folgt der SimClock. T = jetzt. Jeder SimClock-Tick aktualisiert die Map Time.

**Planung:** Eigener Zeitcursor, ab jetzt vorwärts. Jede manuelle Zeitmanipulation (step, set_time, play) deaktiviert Live. `reset_to_live()` kehrt zurück.

---

## 5 — Renderer

Alle Renderer sind `Node2D`-Subklassen. Sie sind **dumm**: Sie empfangen Daten und zeichnen — sie entscheiden nichts über Sichtbarkeit, Position oder Darstellungsmodus. Der View positioniert sie und setzt ihre Eigenschaften.

| Renderer | Beschreibung | Status |
|---|---|---|
| BodyMarker | Klickbares Icon + Label | Alpha |
| BodySprite | Maßstabsgetreue Darstellung | Alpha |
| OrbitRenderer | Orbitbahn als Linienzug | Alpha |
| BeltRenderer | Partikelbasierte Punktwolke | Alpha |
| ZoneRenderer | Farbfläche (Kreis/Ring) | Alpha |
| GridRenderer | Wrapper, delegiert an Concentric/Square | Alpha |
| ConcentricGridRenderer | Konzentrische Referenzringe + Achsen | Alpha |
| SquareGridRenderer | Rechteckiges Koordinatengitter | Alpha |
| ScaleRenderer | Maßstabsbalken (HUD) | Alpha |
| PathRenderer | Route / Flugbahn | Stub |
| ConnectionRenderer | Relation / Distanz | Stub |

### BodyMarker

Klickbares Icon + Label für ein Objekt auf der Karte. Signale gehen direkt an den View.

```gdscript
setup(body: BodyDef, size_px: int)
set_size(size_px: int)
get_body_id() -> String

signal clicked(body_id: String)
signal double_clicked(body_id: String)
signal hovered(body_id: String)
signal unhovered(body_id: String)
```

### BodySprite

Zeigt ein Objekt in realer Größe relativ zum Maßstab. Der View entscheidet wann Sprite statt Marker gezeigt wird (z.B. ab einem Schwellwert von `radius_km × px_per_km`).

```gdscript
setup(body: BodyDef, radius_km: float)
set_px_per_km(px_per_km: float)
```

### OrbitRenderer

Orbitbahn als Linienzug mit konfigurierbarem Stil.

```gdscript
setup(child_id: String, parent_id: String, color: Color,
      path_points_km: Array[Vector2])
set_draw_points(screen_points: PackedVector2Array)
set_line_style(style: int)   # SOLID | DASHED | DOTTED
```

### BeltRenderer

Partikelbasierte Punktwolke. Partikel werden einmalig deterministisch generiert (Seeded RNG). LOD steuert wie viele sichtbar sind.

```gdscript
setup(belt: BeltDef)
set_density(visible_count: int)
set_reference_angle(angle_rad: float)
set_px_per_km(px_per_km: float)
```

### ZoneRenderer

Räumliche Region als gefüllter Kreis oder Ring.

```gdscript
setup(zone: ZoneDef)
set_px_per_km(px_per_km: float)
```

### GridRenderer

Wrapper, delegiert an `ConcentricGridRenderer` oder `SquareGridRenderer`.

```gdscript
enum GridMode { RADIAL, SQUARE, OFF }

setup(mode: GridMode, spacing_km: float)
set_mode(mode: GridMode)
set_px_per_km(px_per_km: float)
set_draw_rect(rect_screen: Rect2)
```

### ConcentricGridRenderer

Konzentrische Referenzringe + Kreuzachsen.

```gdscript
setup(ring_spacing_km: float, ring_count: int)
set_px_per_km(px_per_km: float)
```

### SquareGridRenderer

Rechteckiges Koordinatengitter, auf sichtbaren Bereich beschränkt.

```gdscript
setup(cell_size_km: float)
set_px_per_km(px_per_km: float)
set_draw_rect(rect_screen: Rect2)
```

### ScaleRenderer

Maßstabsbalken als HUD-Element. Berechnet automatisch eine sinnvolle Schrittweite (z.B. 1 AU, 0.1 AU, 1000 km) passend zum Zoom.

```gdscript
set_px_per_km(px_per_km: float)
set_viewport_size(vp_size: Vector2)
```

### PathRenderer (Stub)

Geplante Route oder Flugbahn.

```gdscript
setup(points_km: Array[Vector2], color: Color)
set_draw_points(screen_points: PackedVector2Array)
```

### ConnectionRenderer (Stub)

Relation zwischen zwei Punkten (Distanzanzeige, Kommunikationslink).

```gdscript
setup(from_id: String, to_id: String, color: Color)
set_endpoints(screen_a: Vector2, screen_b: Vector2)
```

---

## 6 — Data

### MapDataLoader

> RefCounted — JSON-Deserialisierung

Stateless, wird nur beim Setup gebraucht.

```gdscript
load_belt_defs(path: String) -> Array[BeltDef]
load_zone_defs(path: String) -> Array[ZoneDef]
```

---

## 7 — Verantwortlichkeit der View

Die gesamte Orchestrierung liegt bei der View. Jede View baut ihre eigene Render- und Interaktionslogik und nutzt die Toolkit-Klassen als Werkzeuge.

### Was die View macht

- **Render-Logik:** Entscheidet welche Objekte gerendert werden, in welchem Modus (lin/log/exag) und mit welchen visuellen Eigenschaften (Farbe, Opacity, Größe)
- **Positionen berechnen:** Fragt `MapScale.world_to_display()` pro Objekt mit passenden Parametern
- **Filter:** Eigene Filter-Logik (Toggles, Fraktionsfilter, Sensorreichweiten — je nach View)
- **Selektion & Fokus:** View-spezifische Interaktionslogik (Klick = InfoPanel, Doppelklick = Eintauchen, Pins für Routen)
- **Referenz-Body:** Setzt `camera.set_reference_anchor()` basierend auf eigener Logik
- **Marker↔Sprite Wechsel:** Entscheidet ab welchem Zoom-Level ein Sprite statt einem Marker gezeigt wird
- **Renderer spawnen und updaten:** Erstellt Instanzen, setzt Position, Sichtbarkeit, Opacity
- **Hover-Reaktion:** Cursor, Tooltip
- **Screen-Kommunikation:** Informiert UI über Änderungen
- **Update-Loop:** Reagiert auf `camera_moved` und `time_changed`

### Beispiel: Frame-Render in der StarChartView

```gdscript
func _on_update():
    var t         = map_time.get_time()
    var cull_rect = map_scale.get_cull_rect(cam_pos, vp_size, 100.0)
    var px_per_km = map_scale.get_px_per_km()

    # Grid + Scale
    grid_renderer.set_px_per_km(px_per_km)
    grid_renderer.set_draw_rect(cull_rect)
    scale_renderer.set_px_per_km(px_per_km)

    # Bodies — View entscheidet pro Objekt
    var screen_positions = {}

    for body in solar_system.get_all_bodies():

        # View-eigene Filter-Logik
        if not _my_filter.is_visible(body):
            _hide(body.id)
            continue

        # View entscheidet: welcher Modus für dieses Objekt?
        var mode = _get_scale_mode_for(body)
        var exag = _get_exag_for(body)

        # Toolkit: Orbit groß genug?
        if not body.is_root():
            if not map_scale.is_orbit_visible(body.orbit_km, _min_orbit_px, exag):
                _hide(body.id)
                continue

        # Toolkit: Screen-Position berechnen
        var world_km = solar_system.get_position(body.id, t)
        var parent_screen = screen_positions.get(body.parent_id, Vector2.ZERO)
        var screen_pos = map_scale.world_to_display(
            world_km, parent_screen, body.orbit_km, mode, exag)

        # Toolkit: Im Viewport?
        if not map_scale.is_in_viewport(screen_pos, cull_rect):
            _hide(body.id)
            continue

        # Sichtbar — Renderer updaten
        screen_positions[body.id] = screen_pos
        markers[body.id].position = screen_pos
        markers[body.id].visible = true
        markers[body.id].modulate.a = _get_opacity_for(body)

    # Belts, Zones — gleiche Logik
    _update_belts(screen_positions, px_per_km)
    _update_zones(screen_positions, px_per_km)

    # UI
    _update_screen_info()
```

Die Methoden `_get_scale_mode_for()`, `_get_exag_for()`, `_get_opacity_for()` sind View-interne Logik. Hier entscheidet die StarChart z.B.: gepinnte Bodies bekommen LOG, Kinder des Fokus-Bodys bekommen EXAG, Hintergrund-Bodies werden gedimmt. Eine andere View trifft andere Entscheidungen — das Toolkit bleibt gleich.

---

## 8 — Star Chart UI

### 8.1 — Layout

16:9, drei Bereiche:

```
┌─────────────────────────────────────────────────────────────────┐
│ HEADER: Title + Display Controls                                │
├─────────────────────────────────────────────────────────────────┤
│                                                    │ INFO PANEL │
│                                                    │ (optional) │
│                    MAP VIEWPORT                     │  max 25%   │
│                                                    │            │
│  [≡]                                               │            │
│                                                    │            │
├─────────────────────────────────────────────────────────────────┤
│ FOOTER: Map Time + Transport Controls                           │
└─────────────────────────────────────────────────────────────────┘
```

UI-Mockup: siehe `mockup_star_chart_ui.html`

### 8.2 — Header

Einzeilig. Links: Titel ("STAR CHART"), Zoom-Level, km/px-Anzeige.

Rechts die Display-Controls:

| Control | Typ | Werte | Steuert |
|---|---|---|---|
| SCALE | Toggle | LIN, LOG | View-interner Parameter → `world_to_display()` mode |
| EXAG | Stepper (−/+) | OFF, 5×, 10×, 25× … | View-interner Parameter → `world_to_display()` exag_factor |
| MIN ORBIT | Stepper (−/+) | Wert in px | View-interner Parameter → `is_orbit_visible()` min_orbit_px |
| GRID | Toggle | RAD, SQR, OFF | `grid_renderer.set_mode()` |

### 8.3 — Map Viewport

Volle Restbreite (bzw. 75% bei offenem InfoPanel). Zeigt:

- Himmelskörper als BodyMarker (Icon + Label)
- Orbitbahnen als Linien
- Asteroidengürtel als Punktwolken
- Referenzgitter (Radial oder Square)
- Maßstabsbalken (unten rechts, HUD)
- Burger-Menü oben links → öffnet Filter-Panel als Overlay

### 8.4 — Footer

Map Time Controls. Drei Bereiche:

**Links:** Live-Indikator + Zeitanzeige

- Grüner Punkt + "LIVE" wenn Karte der SimClock folgt
- Map Time im SST-Format: `MAP T: 0042:187:14:32:05`
- Darunter menschenlesbares Datum: `6 Jul 2284 · 14:32 UTC`
- Bei Zukunftsplanung: LIVE erlischt, Offset wird angezeigt

**Mitte:** Transport-Controls + Step-Size

- `|◁` Zurück zu Jetzt → `map_time.reset_to_live()`
- `◁◁` Schnell zurück
- `◁` Schritt zurück → `map_time.step(-step_size)`
- `▶` Play/Pause → `map_time.play()` / `map_time.pause()`
- `▷` Schritt vor → `map_time.step(step_size)`
- `▷▷` Schnell vor
- Step-Size: 1h, 1d, 10d, 100d → `map_time.set_step_size()`

**Rechts:** Reserviert

### 8.5 — InfoPanel

Optionales Panel, rechts, max 25% Breite. Eigener ×-Close-Button. Reine View-Logik.

**Immer sichtbar (über den Tabs):**

- Type / Subtype (z.B. PLANET · TERRESTRIAL)
- Name (z.B. Mars)
- Bild / Artist Rendering
- Tags als farbige Badges (z.B. "habitable candidate", "colonized")

**Tab 1 — Data:**
Orbit- und Physikdaten zusammengefasst. 2-Spalten-Grid, gruppiert (ORBIT, PHYSICS). Parent-Link klickbar.

**Tab 2 — Info:**
Beschreibungstext, Points of Interest (klickbar), Fraktionen (mit Einfluss-Badge), Handelsübersicht (Exports/Imports).

**Tab 3 — Children:**
Nach Kategorie gruppiert (Moons, Structures). Klickbar → Navigation zum Child.

### 8.6 — Filter-Panel

Reine View-Logik. Burger-Menü → Overlay auf der Karte. Hierarchische Toggles:

- Bodies: Stars, Planets (Terrestrial, Gas Giant, …), Dwarfs, Moons, Structures
- Orbits: nach Parent-Type
- Zones: Radiation, Magnetic, Gravity, Habitable
- Belts: Asteroid Belt, Kuiper Belt

Type aus → alle Subtypes ausgegraut. Subtypes merken sich ihren Zustand.

---

## 9 — Dateistruktur

```
game/map/
├── toolkit/
│   ├── core/
│   │   ├── map_scale.gd
│   │   ├── map_camera.gd
│   │   ├── map_input.gd
│   │   └── map_time.gd
│   ├── renderer/
│   │   ├── body_marker.gd              + .tscn
│   │   ├── body_sprite.gd              + .tscn
│   │   ├── orbit_renderer.gd           + .tscn
│   │   ├── belt_renderer.gd            + .tscn
│   │   ├── zone_renderer.gd            + .tscn
│   │   ├── grid_renderer.gd            + .tscn
│   │   ├── concentric_grid_renderer.gd + .tscn
│   │   ├── square_grid_renderer.gd     + .tscn
│   │   ├── scale_renderer.gd           + .tscn
│   │   ├── path_renderer.gd            + .tscn    # Stub
│   │   └── connection_renderer.gd       + .tscn    # Stub
│   └── data/
│       └── map_data_loader.gd
├── views/
│   └── star_chart/
│       ├── star_chart_view.gd
│       ├── StarChartView.tscn
│       ├── star_chart_filter.gd
│       └── ...
└── test/
    └── map_test_scene.gd
```
