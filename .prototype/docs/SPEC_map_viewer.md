# Map Viewer — Spezifikation

> Vollständige technische Referenz für den Map Viewer
> Stand: 2026-03-22

---

## Überblick

Der Map Viewer ist die interaktive Kartendarstellung des Sonnensystems. Er visualisiert die Positionsdaten der `SolarSystemModel`-Simulation als 2D-Sternenkarte mit freier Navigation, stufenlosem Zoom und optionalem Time Scrubbing.

Der Viewer wird als eigenständige Szene in einen Map Screen per `SubViewport` eingebunden. Sämtliches UI (Header, Footer, Info Panel) ist Sache des Screens — der Viewer ist ausschließlich für die Karte selbst zuständig.

### Szene

```
MapViewer (Node2D)                    ← map_controller.gd
├── MapClock (Node)                   ← map_clock.gd
├── MapTransform (Node)               ← map_transform.gd
├── MapCam (Camera2D)                 ← map_cam.gd
├── ZoneLayer (Node2D)                ← zone_renderer.gd
├── BeltLayer (Node2D)                ← belt_renderer.gd
├── GridLayer (Node2D)                ← grid_renderer.gd
├── OrbitLayer (Node2D)               ← orbit_renderer.gd
└── MarkerLayer (Node2D)              ← marker_layer.gd
    ├── MapMarker (Area2D)            ← map_marker.gd (instanziiert pro Body)
    └── ...
```

Die Render-Reihenfolge (von hinten nach vorne): Zones → Belts → Grid → Orbits → Marker. Marker liegen immer obenauf.

### Setup

```gdscript
# Aufruf durch den Screen (z.B. in star_chart_screen.gd)
var map_viewer = $SubViewport/MapViewer
map_viewer.setup(solar_system, sim_clock)
```

Der Viewer erhält beim Setup Referenzen auf `SolarSystemModel` und `SimulationClock`. Er reicht diese an seine Unterkomponenten weiter und baut die Karte initial auf.

### Datenfluss

```
SimClock ──tick──► SolarSystemModel ──simulation_updated──► MapClock
                                                               │
                                         MapClock.map_time_changed(sst_s)
                                                               │
                                                               ▼
                                                         MapController
                                                          │         │
                                      query positions ◄───┘         └───► update renderers
                                      via SolarSystemModel              (Marker, Orbits, ...)
```

Der MapController reagiert auf `map_time_changed` der MapClock, fragt daraufhin Positionen beim SolarSystemModel ab, transformiert sie über MapTransform in Screenkoordinaten und verteilt die Ergebnisse an die Renderer.

---

## 1 — MapController

**Script:** `map_controller.gd`
**Extends:** `Node2D`

Zentraler Koordinator. Hält Referenzen auf alle Unterkomponenten und orchestriert den Update-Zyklus. Baut beim Setup die Karte auf (Marker, Orbits, Belts, Zones, Grid) und aktualisiert sie bei jedem Zeitschritt.

### 1.1 Verantwortlichkeiten

- Empfängt `map_time_changed` von MapClock und löst den Update-Zyklus aus
- Fragt Positionen beim SolarSystemModel ab (via `get_body_position()` im Live-Modus, `get_body_positions_at_time()` im Scrub-Modus)
- Transformiert km-Positionen über MapTransform in px-Koordinaten
- Verteilt transformierte Positionen an Marker und Orbit-Renderer
- Führt Viewport-Culling und Parent-Proximity-Culling durch
- Verwaltet die Marker-Instanzen und das Gruppensystem
- Leitet Marker-Signale (click, hover) an den Screen weiter

### 1.2 Setup

```gdscript
func setup(model: SolarSystemModel, clock: SimulationClock) -> void
```

Der Setup-Ablauf:

1. Referenzen speichern
2. MapClock initialisieren mit SimClock-Referenz
3. MapTransform initialisieren
4. MapCam initialisieren
5. Alle Bodies aus `model.get_all_body_ids()` durchgehen → pro Body einen MapMarker instanziieren
6. Alle Bodies mit Motion (circular, kepler2d) → OrbitRenderer aufbauen
7. BeltDefs und ZoneDefs über MapDataLoader laden → Belt- und Zone-Renderer aufbauen
8. GridRenderer initialisieren
9. Erstes Update auslösen

### 1.3 Update-Zyklus

Pro `map_time_changed`-Signal:

1. Aktuelle `sst_s` von MapClock lesen
2. Positionen aller sichtbaren Bodies abfragen
3. Positionen über `MapTransform.km_to_px()` transformieren
4. Marker-Positionen setzen
5. Orbit-Renderer aktualisieren (nur Position des Mittelpunkts, Pfadpunkte ändern sich nicht)
6. Belt-Renderer aktualisieren (Trojaner-Rotation)
7. Culling durchführen

### 1.4 Signale

```gdscript
signal marker_clicked(body_id: String)
signal marker_double_clicked(body_id: String)
signal marker_hovered(body_id: String)
signal marker_unhovered(body_id: String)
```

### 1.5 Public API

```gdscript
# Setup
func setup(model: SolarSystemModel, clock: SimulationClock) -> void

# Konfiguration (vom Screen aus steuerbar)
func set_scale_mode(mode: int) -> void          # SCALE_LINEAR, SCALE_LOG
func set_exaggeration(factor: float) -> void     # 1.0 = keine Übertreibung
func set_grid_visible(visible: bool) -> void
func set_orbits_visible(visible: bool) -> void
func set_belts_visible(visible: bool) -> void
func set_zones_visible(visible: bool) -> void

# Marker-Zugriff
func get_marker(body_id: String) -> MapMarker
func get_markers_by_group(group: String) -> Array[MapMarker]
func set_marker_state(body_id: String, state: int) -> void
func set_group_state(group: String, state: int) -> void

# Kamera-Steuerung
func focus_body(body_id: String) -> void         # Zentriert Kamera auf Body
func get_cam() -> MapCam
```

---

## 2 — MapTransform

**Script:** `map_transform.gd`
**Extends:** `Node`

Reine Mathematik-Klasse. Rechnet Simulationskoordinaten (km) in Screenkoordinaten (px) um. Unterstützt drei Modi: Linear, Logarithmisch und Exaggeration als Zusatzfaktor.

### 2.1 Skalierungsmodi

#### Linear (`SCALE_LINEAR`)

Direkte proportionale Umrechnung. Ein Pixel entspricht einer festen Anzahl Kilometer.

```
px = km / km_per_px
```

`km_per_px` wird durch den Zoom-Level bestimmt. Innerplaneten und äußeres System bei gleichem Zoom extrem unterschiedlich groß — beim Herauszoomen verschwinden Monde und innere Orbits schnell.

#### Logarithmisch (`SCALE_LOG`)

Logarithmische Transformation der Distanz zum Kartenmittelpunkt. Komprimiert große Abstände, spreizt kleine. Ermöglicht es, das gesamte System inklusive transneptunischer Objekte auf einem Bildschirm darzustellen, ohne dass die Innerplaneten zu einem Punkt kollabieren.

```
distance_km = length(position_km - center_km)
distance_px = log_base * log(1 + distance_km / ref_distance) * scale_factor
```

- `log_base`: Basis des Logarithmus (konfigurierbar, Default: 10)
- `ref_distance`: Referenzdistanz in km, ab der die Kompression einsetzt (z.B. 1 AU)
- Winkel bleibt erhalten — nur die radiale Distanz wird transformiert
- Bei `distance_km = 0` (Zentralgestirn) wird keine Transformation angewandt

#### Exaggeration (`exaggeration_factor`)

Multiplikator auf den radialen Abstand eines Körpers zu seinem Parent. Wirkt zusätzlich zu Linear oder Log. Vergrößert den visuellen Abstand zwischen Monden und ihrem Planeten oder zwischen innerplaneten. Nützlich, damit z.B. Io, Europa, Ganymede und Callisto nicht alle auf demselben Pixel liegen.

```
# Auf die lokale Position (relativ zum Parent) angewandt
local_km = body_pos_km - parent_pos_km
local_km_exaggerated = local_km * exaggeration_factor
effective_pos_km = parent_pos_km + local_km_exaggerated
```

- `exaggeration_factor`: Float, Minimum 1.0. Default: 1.0 (keine Übertreibung)
- Stufen für UI-Stepper: 1×, 2×, 5×, 10×, 20×, 50×
- Exaggeration wird vor der Linear/Log-Transformation angewandt
- Wirkt nur auf Kindkörper relativ zu ihrem Parent — der Parent selbst bleibt an seiner berechneten Position

### 2.2 API

```gdscript
# Modi
enum ScaleMode { LINEAR, LOG }

# Konfiguration
var scale_mode: ScaleMode = ScaleMode.LINEAR
var exaggeration_factor: float = 1.0
var km_per_px: float = 1000000.0    # Wird durch Zoom gesteuert

# Log-Parameter
var log_base: float = 10.0
var log_ref_distance_km: float = 149597870.7  # 1 AU

# Transformation
func km_to_px(pos_km: Vector2) -> Vector2
func px_to_km(pos_px: Vector2) -> Vector2
func km_to_px_batch(positions: Dictionary) -> Dictionary  # { id: Vector2_km } → { id: Vector2_px }

# Distanz-Hilfsfunktionen
func km_distance_to_px(km: float) -> float    # Für Radien (Orbits, Zonen)
func get_km_per_px() -> float                 # Aktueller Maßstab
```

### 2.3 Zusammenspiel mit Zoom

Der MapCam steuert `km_per_px` über seinen Zoom-Level. Bei jedem Zoom-Schritt aktualisiert der MapController den MapTransform, und alle Renderer erhalten neu transformierte Koordinaten.

Im Log-Modus beeinflusst der Zoom `scale_factor` statt `km_per_px`.

---

## 3 — MapCam

**Script:** `map_cam.gd`
**Extends:** `Camera2D`

Eigene Kamera-Implementierung. Zoom läuft nicht über Godots `Camera2D.zoom`, sondern über Map Scaling: der Zoom-Level verändert `km_per_px` im MapTransform, woraufhin alle Positionen neu berechnet werden. Die Kamera selbst bewegt sich in Screenkoordinaten.

### 3.1 Zoom

Stufenloser Zoom über Mausrad, Tastatur (`map_zoom_in`/`map_zoom_out`) und Trackpad-Pinch.

```
Zoom-Bereich:
  Min: 1 px = 1.000 km        (Nahansicht Mondorbits)
  Max: 1 px = 10.000.000.000 km  (gesamtes System + Oort Cloud)
```

Zoom-Schritte sind multiplikativ (jeder Schritt multipliziert/dividiert `km_per_px` um einen festen Faktor). Der Zoom zielt auf die Mausposition — der Punkt unter dem Cursor bleibt stationär.

#### Map Scale Presets

Direkter Sprung zu vordefinierten Zoom-Stufen über Tasten `map_scale_1` bis `map_scale_5`:

| Preset | Taste | Ungefähre Ansicht | km_per_px (Richtwert) |
|--------|-------|-------------------|-----------------------|
| 1 | `6` | Planetenansicht (Monde sichtbar) | 5.000 |
| 2 | `7` | Inneres System (Merkur–Mars) | 500.000 |
| 3 | `8` | Gesamtes Planetensystem | 5.000.000 |
| 4 | `9` | Inklusive Kuipergürtel | 50.000.000 |
| 5 | `0` | Gesamte Simulation | 500.000.000 |

Presets zentrieren die Kamera auf das Zentralgestirn (oder den aktuell fokussierten Body, falls vorhanden).

### 3.2 Bewegung

- **Tastatur:** WASD verschiebt die Kamera. Geschwindigkeit skaliert mit dem aktuellen Zoom-Level (weiter herausgezoomt = schnellere Bewegung)
- **Maus-Drag:** Mittlere Maustaste (oder Rechtsklick) + Ziehen verschiebt die Kamera
- **Trackpad:** Zwei-Finger-Swipe verschiebt die Kamera

### 3.3 Fokus

```gdscript
func focus_on(pos_px: Vector2) -> void      # Zentriert auf Screenposition
func focus_on_smooth(pos_px: Vector2) -> void  # Sanftes Gleiten zur Position
```

Bei `focus_body()` am MapController wird die aktuelle Weltposition des Bodys transformiert und an `focus_on` übergeben.

### 3.4 Signale

```gdscript
signal zoom_changed(km_per_px: float)
signal camera_moved(center_px: Vector2)
```

---

## 4 — MapClock

**Script:** `map_clock.gd`
**Extends:** `Node`

Eigene Uhr der Karte. Ermöglicht Time Scrubbing unabhängig von der Spiel-SimClock. Arbeitet mit einem Offset-Modell: die MapClock hat einen Offset zur SimClock, standardmäßig 0 (Live-Modus). Scrubbing verschiebt den Offset.

### 4.1 Modus-Modell

```
map_time = sim_clock.sst_s + offset_s
```

- **Live-Modus** (`offset_s = 0`): Die Karte zeigt den aktuellen Simulationszustand. Läuft synchron mit der SimClock.
- **Scrub-Modus** (`offset_s ≠ 0`): Die Karte zeigt einen anderen Zeitpunkt. Der Offset kann positiv (Zukunft) oder negativ (Vergangenheit) sein.

Die MapClock lauscht auf `sim_clock_tick` und berechnet bei jedem Tick `map_time = sst_s + offset_s`. Dann feuert sie ihr eigenes Signal.

### 4.2 Signale

```gdscript
signal map_time_changed(sst_s: float)       # Gefeuert bei jedem Update
signal scrub_mode_changed(is_scrubbing: bool)  # Gefeuert beim Wechsel Live ↔ Scrub
```

### 4.3 API

```gdscript
# Setup
func setup(sim_clock: SimulationClock) -> void

# Offset-Steuerung
func set_offset(offset_s: float) -> void   # Setzt den Offset direkt
func add_offset(delta_s: float) -> void    # Verschiebt den Offset relativ
func reset_offset() -> void                # Setzt offset_s = 0 (zurück zu Live)

# Lookup
func get_map_time() -> float               # Aktuelle Map-Zeit (sim_time + offset)
func get_offset() -> float                 # Aktueller Offset
func is_scrubbing() -> bool                # true wenn offset_s != 0
```

### 4.4 Positionsabfrage

Der MapController entscheidet basierend auf `is_scrubbing()`:

- **Live:** `solar_system.get_body_position(id)` — nutzt den bereits berechneten Live-Zustand
- **Scrub:** `solar_system.get_body_positions_at_time(ids, map_clock.get_map_time())` — berechnet Positionen zum Scrub-Zeitpunkt ohne die SimClock zu verstellen

---

## 5 — Rendering Primitives

Die Renderer sind per se "dumm". Sie erhalten Konfiguration und fertig transformierte Pixel-Koordinaten vom MapController und übernehmen ausschließlich das Zeichnen. Kein Renderer kennt die Simulation direkt.

### 5.1 Gemeinsames Gruppensystem

Marker und Orbit-Renderer teilen ein Tag-basiertes Gruppensystem. Es nutzt die `map_tags` aus den BodyDefs und ergänzt sie um automatisch generierte Gruppen basierend auf `type` und `subtype`.

Jeder Marker/Orbit gehört zu mehreren Gruppen gleichzeitig. Das ermöglicht Group Calls wie "alle Marker im `jovian_system` dimmen" oder "alle Orbits von `minor_moon` ausblenden".

```gdscript
# Automatisch generierte Gruppen pro Marker/Orbit:
# - "type:<type>"         → z.B. "type:planet", "type:moon", "type:struct"
# - "subtype:<subtype>"   → z.B. "subtype:terrestrial", "subtype:station"
# - Jeder Eintrag aus map_tags → z.B. "inner_system", "jovian_system", "major_body"
```

---

### 5.2 MapMarker

**Script:** `map_marker.gd`
**Extends:** `Area2D`
**Szene:** `map_marker.tscn` (instanziiert pro Body)

Zeichnet einen einzelnen Himmelskörper oder eine Struktur auf die Karte.

#### 5.2.1 Aufbau

```
MapMarker (Area2D)
├── Sprite2D         ← Icon basierend auf map_icon / type / subtype
├── SelectionRing    ← Node2D, zeichnet Ring um das Icon bei state > DEFAULT
├── ColorOverlay     ← Node2D, farbige Überlagerung je nach State
├── CollisionShape2D ← Klick-/Hover-Erkennung
└── Label            ← Name-Label (optional, sichtbarkeitsgesteuert)
```

#### 5.2.2 Icon-System

Der Sprite zeigt ein vordefiniertes Icon an, bestimmt durch das `map_icon`-Feld der BodyDef:

| `map_icon` | Icon |
|------------|------|
| `sun` | Stern-Symbol (Kreis mit Strahlen) |
| `planet` | Gefüllter Kreis, Farbe aus `color_rgba` |
| `moon` | Kleinerer gefüllter Kreis, Farbe aus `color_rgba` |
| `station` | Rauten-Symbol |
| `object` | Kreuz-Symbol (Fadenkreuz) |

Icons werden als vorgefertigte Texturen aus einem Spritesheet geladen. Die `color_rgba` der BodyDef wird als Modulate auf den Sprite angewandt.

#### 5.2.3 Größenstufen

Diskrete Skalierungsstufen abhängig vom Zoom-Level und dem Typ des Körpers. Jede Stufe hat eine feste Pixelgröße.

```gdscript
enum MarkerSize { SMALL, MEDIUM, LARGE }
```

| Stufe | Pixelgröße | Verwendung |
|-------|------------|------------|
| `SMALL` | 8 px | Weit herausgezoomt, oder für minor Bodies |
| `MEDIUM` | 16 px | Standard-Ansicht |
| `LARGE` | 24 px | Nah herangezoomt, oder für major Bodies |

Die Zuordnung Zoom → Stufe wird vom MapController gesteuert. Die Schwellenwerte sind konfigurierbar. Major Bodies (Stern, Planeten) wechseln früher zu `LARGE` als Minor Bodies (kleine Monde, Structs).

#### 5.2.4 Marker State

```gdscript
enum MarkerState { INACTIVE = 0, DEFAULT, SELECTED, PINNED, DIMMED }
```

| State | Visuelle Darstellung |
|-------|---------------------|
| `INACTIVE` | Unsichtbar. Marker existiert, wird aber nicht gezeichnet. |
| `DEFAULT` | Icon in Normalfarbe. Kein Ring, kein Overlay. |
| `SELECTED` | Leuchtender Ring um das Icon (Accent-Farbe). Leichtes Glow-Overlay. |
| `PINNED` | Dauerhafter Ring (gedämpfter als SELECTED). Icon leicht hervorgehoben. |
| `DIMMED` | Icon mit reduzierter Opacity (ca. 30%). Kein Ring. |

State-Wechsel über `set_state(state: MarkerState)`. Der MapController kann States einzeln oder über Group Calls setzen.

#### 5.2.5 Label

Optionales Name-Label neben dem Marker. Anzeige abhängig vom Zoom-Level und vom Marker-State:

- `INACTIVE`: Kein Label
- `DEFAULT`: Label nur ab einer konfigurierbaren Zoom-Schwelle
- `SELECTED` / `PINNED`: Label immer sichtbar
- `DIMMED`: Kein Label

Label-Position: rechts neben dem Icon mit kleinem Offset. Bei Kollision mit dem Viewport-Rand oder anderen Labels wird die Position nicht automatisch angepasst (kein Label-Layout in Stufe 1).

#### 5.2.6 Signale

```gdscript
signal clicked(marker: MapMarker)
signal double_clicked(marker: MapMarker)
signal hovered(marker: MapMarker)
signal unhovered(marker: MapMarker)
```

Emittiert über Godots `Area2D`-Input-Handling (`_input_event`, `mouse_entered`, `mouse_exited`). Der MapController verbindet diese Signale und leitet die `body_id` an den Screen weiter.

#### 5.2.7 Daten

```gdscript
var body_def: BodyDef           # Referenz auf die zugehörige BodyDef
var body_id: String             # Kurzreferenz (= body_def.id)
var groups: Array[String]       # Generierte Gruppen-Tags
var current_state: MarkerState = MarkerState.DEFAULT
var current_size: MarkerSize = MarkerSize.MEDIUM
```

---

### 5.3 OrbitRenderer

**Script:** `orbit_renderer.gd`
**Extends:** `Node2D`
**Instanz:** Eine pro Body mit orbitaler Motion (circular oder kepler2d)

Zeichnet die Orbitlinie eines Körpers als `Line2D` oder `_draw()`-Pfad.

#### 5.3.1 Pfad-Caching

Die Orbitpunkte (lokal zum Parent) werden aus `SolarSystemModel.get_local_orbit_path(id)` geholt und intern gecacht. Der Cache wird nur bei Änderung des Scale-Modus oder der Exaggeration invalidiert — Zoom allein erfordert keine Neuberechnung, da der MapTransform die Transformation übernimmt.

Ablauf pro Frame:
1. Parent-Position in px vom MapController erhalten
2. Gecachte lokale Punkte über MapTransform in px transformieren
3. Transformierte Punkte relativ zur Parent-px-Position zeichnen

Dadurch bewegt sich der Orbit mit seinem Parent mit, ohne dass der Pfad neu berechnet werden muss.

#### 5.3.2 Orbit State

```gdscript
enum OrbitState { INACTIVE = 0, DEFAULT, HIGHLIGHT, DIMMED }
```

| State | Visuelle Darstellung |
|-------|---------------------|
| `INACTIVE` | Unsichtbar |
| `DEFAULT` | Dünne Linie (1 px), Farbe aus `body_def.color_rgba`, Alpha ca. 0.2 |
| `HIGHLIGHT` | Dickere Linie (2 px), volle Farbe, Alpha ca. 0.6 |
| `DIMMED` | Dünne Linie (1 px), stark reduzierte Alpha (ca. 0.08) |

#### 5.3.3 Linienstärke

Linienstärke ist variabel und abhängig von State und Konfiguration:

```gdscript
var base_width: float = 1.0     # Grundstärke in px
var highlight_width: float = 2.0
var dimmed_width: float = 0.5
```

Die Stärke skaliert nicht mit dem Zoom — Orbitlinien bleiben in Pixel-Einheiten konstant dünn.

#### 5.3.4 Referenz

```gdscript
var body_def: BodyDef               # Zugehörige BodyDef
var body_id: String                  # Kurzreferenz
var parent_id: String                # ID des Mittelpunkts
var groups: Array[String]            # Gleiche Gruppen wie der zugehörige Marker
var local_path_cache: Array[Vector2] # Gecachte Orbitpunkte (lokal, km)
```

---

### 5.4 BeltRenderer

**Script:** `belt_renderer.gd`
**Extends:** `Node2D`
**Instanz:** Eine pro BeltDef

Zeichnet eine prozedurale Punktwolke basierend auf einer `BeltDef`. Kann vollständige Ringe (Asteroiden-, Kuipergürtel) oder Ringsegmente (Trojaner-Wolken) darstellen.

#### 5.4.1 Punktgenerierung

Beim Setup werden die Punkte einmalig aus der BeltDef generiert:

1. RNG mit `belt_def.rng_seed` initialisieren
2. Punktanzahl basierend auf aktuellem LOD zwischen `min_points` und `max_points` interpolieren
3. Pro Punkt: zufälligen Winkel innerhalb `[angular_offset_rad, angular_offset_rad + angular_spread_rad]` und zufälligen Radius innerhalb `[inner_radius_km, outer_radius_km]` generieren
4. Punkte als lokale km-Koordinaten relativ zum `parent_id` speichern

Determinismus: Gleicher Seed + gleiche Punktanzahl = identische Wolke.

#### 5.4.2 LOD

Die aktive Punktanzahl skaliert mit dem Zoom-Level:

- Weit herausgezoomt: `min_points` (Gürtel als dezente Wolke)
- Nah herangezoomt: `max_points` (dichtere Darstellung)
- Interpolation zwischen Min und Max basierend auf `km_per_px`

Bei LOD-Wechsel werden Punkte neu generiert (gleicher Seed = gleiche Positionen für die ersten N Punkte).

#### 5.4.3 Punktdarstellung

- Größe: skaliert mit Zoom (1–3 px)
- Farbe: `belt_def.color_rgba`
- Rendering: `draw_circle()` oder `draw_rect()` in `_draw()`

#### 5.4.4 Rotation (Trojaner)

Für Belts mit `apply_rotation = true`: die gesamte Punktwolke rotiert mit der Orbitalposition des Parent (z.B. die Sonne dreht sich nicht, aber die Punkte rotieren um sie).

Für Belts mit `apply_rotation = false` (Trojaner): die Wolke bleibt fixiert relativ zum `reference_body_id`. Die Position des Referenzkörpers bestimmt den aktuellen Offset.

---

### 5.5 ZoneRenderer

**Script:** `zone_renderer.gd`
**Extends:** `Node2D`
**Instanz:** Eine pro ZoneDef

Zeichnet halbtransparente Flächen: Kreise oder Ringe um einen Zentralkörper.

#### 5.5.1 Geometrie

Basierend auf `zone_def.geometry`:

- **`circle`**: Gefüllter Kreis mit `radius_km`, transformiert in px
- **`ring`**: Hohlring zwischen `inner_radius_km` und `outer_radius_km`

Rendering über `_draw()` mit `draw_circle()` bzw. `draw_arc()` / Polygon für Ringe.

#### 5.5.2 Darstellung

- Füllung: `zone_def.color_rgba` (empfohlen Alpha 0.05–0.2)
- Rand: `zone_def.border_color_rgba`
- Position: folgt dem Parent-Körper (Position in px vom MapController)

#### 5.5.3 Sichtbarkeit

Zonen sind per Default sichtbar, können über den MapController global ein-/ausgeblendet werden. Einzelne Zonen können über ihren `zone_type` gefiltert werden.

---

### 5.6 GridRenderer

**Script:** `grid_renderer.gd`
**Extends:** `Node2D`
**Instanz:** Genau eine, direkt als Kind des MapViewer

Zeichnet ein Orientierungsgitter auf die Karte. Unterstützt zwei Modi.

#### 5.6.1 Radiales Grid

Konzentrische Kreise um das Zentralgestirn in festen Abständen (z.B. 1 AU, 5 AU, 10 AU). Plus optionale Winkellinien (z.B. alle 30° oder 45°).

- Kreisabstände passen sich dem Zoom an: bei engem Zoom engere Ringe, bei weitem Zoom weitere
- Beschriftung der Ringe mit Distanzangabe (z.B. "1 AU", "5 AU")
- Farbe: sehr dezent (Alpha ~0.05–0.1), darf die Karte nicht dominieren

#### 5.6.2 Quadratisches Grid

Rechtwinkliges Gitter mit festen Abständen in km, transformiert in px. Nützlich als Alternative zum radialen Grid.

- Gitterabstand passt sich dem Zoom an (Verdopplung/Halbierung bei Schwellenwerten)
- Achsenkreuz durch den Koordinatenursprung (Sonne)

#### 5.6.3 Konfiguration

```gdscript
enum GridMode { RADIAL, SQUARE, OFF }

var grid_mode: GridMode = GridMode.RADIAL
var grid_color: Color = Color(0.29, 1.0, 0.54, 0.05)  # Dezentes Grün
var show_labels: bool = true
```

#### 5.6.4 Zeichenlogik

Grid wird in `_draw()` gerendert. Nur Linien innerhalb des Viewports werden gezeichnet (kein vollständiges Gitter für das gesamte System). Das Grid reagiert auf `zoom_changed` und `camera_moved` vom MapCam.

---

## 6 — Culling

Zwei Culling-Mechanismen reduzieren visuelle Überladung und verbessern Performance.

### 6.1 Viewport-Culling

Bodies, Orbits und Belt-Punkte außerhalb des sichtbaren Viewport-Bereichs werden nicht gezeichnet. Die Prüfung erfolgt pro Frame anhand der transformierten px-Position und der Viewport-Grenzen.

- Marker: unsichtbar wenn px-Position + Marker-Radius außerhalb des Viewports
- Orbits: unsichtbar wenn die gesamte Bounding Box des Orbits außerhalb des Viewports liegt
- Belt-Punkte: Punkt-für-Punkt, oder über Bounding-Arc für den gesamten Belt

### 6.2 Parent-Proximity-Culling

Beim Herauszoomen rücken Kindkörper visuell immer näher an ihren Parent. Ab einem konfigurierbaren Mindestabstand in Pixeln werden Kinder ausgeblendet, da sie den Parent optisch überlagern würden.

```gdscript
const MIN_PARENT_DISTANCE_PX: float = 15.0  # Konfigurierbarer Schwellenwert
```

Logik:
1. Pro Kind: Abstand zum Parent in px berechnen
2. Wenn Abstand < `MIN_PARENT_DISTANCE_PX` → Kind-Marker und Kind-Orbit auf `INACTIVE` setzen
3. Wenn Abstand wieder ≥ Schwellenwert → vorherigen State wiederherstellen

Dies betrifft rekursiv die gesamte Hierarchie: wenn Jupiter ausgeblendet ist (weil zu nah an der Sonne), werden auch alle Jupiter-Monde und Jupiter-Strukturen ausgeblendet.

---

## 7 — Mausinteraktion

### 7.1 Hover

Wenn der Mauszeiger über einen MapMarker fährt, wird `marker_hovered` emittiert. Der Screen kann darauf reagieren (z.B. Tooltip anzeigen, Info Panel befüllen).

- Hover-Erkennung über `Area2D.mouse_entered` / `mouse_exited`
- Die Collision-Shape des Markers skaliert nicht mit dem Zoom — sie bleibt immer interaktionsfreundlich groß (min. 16 px Radius)
- Bei überlappenden Markern: der Marker mit dem kleinsten `type`-Rang gewinnt (struct > moon > dwarf > planet > star). Dadurch sind kleine Strukturen auch neben großen Planeten klickbar.

### 7.2 Klick

Einfacher Klick: emittiert `marker_clicked`. Typische Reaktion des Screens: Body im Info Panel anzeigen, Marker auf `SELECTED` setzen.

Doppelklick: emittiert `marker_double_clicked`. Typische Reaktion: Kamera auf den Body zentrieren und hineinzoomen.

### 7.3 Prioritäten bei Überlappung

Wenn mehrere Marker unter dem Cursor liegen:

1. Höchste Priorität: `struct` (kleinste, am schwersten zu treffen)
2. Dann: `moon`
3. Dann: `dwarf`
4. Dann: `planet`
5. Niedrigste: `star`

Implementierung über Z-Index der Marker im MarkerLayer oder über manuelle Hit-Detection mit Prioritätsliste.

---

## 8 — Implementierung in Stufen

Die Implementierung erfolgt inkrementell. Jede Stufe baut auf der vorherigen auf und ist einzeln testbar.

### Stufe 1 — Grundlagen

**Ziel:** Leere Karte mit funktionierender Infrastruktur.

- MapController: Setup-Methode, empfängt `simulation_updated`
- MapTransform: `km_to_px()` im Linear-Modus (nur Grundumrechnung)
- MapClock: Live-Modus (Offset 0, leitet SimClock-Ticks weiter)
- MapCam: Existiert als Camera2D, noch keine Interaktion
- Alle Layer als leere Node2D-Kinder vorhanden

**Testbar:** Szene lädt ohne Fehler, MapController empfängt Ticks, Positionen können im Debug-Log ausgegeben werden.

### Stufe 2 — Radiales Grid

**Ziel:** Visuelle Orientierung auf der Karte.

- GridRenderer: Radiales Grid mit konzentrischen Kreisen (1, 5, 10, 30, 50 AU)
- Distanz-Labels an den Ringen
- Grid reagiert auf Zoom (Ringe ein-/ausblenden je nach Relevanz)

**Testbar:** Grid ist sichtbar, Abstände stimmen mit den Sim-Daten überein.

### Stufe 3 — Kamera

**Ziel:** Freie Navigation auf der Karte.

- MapCam: Zoom mit `map_zoom_in`/`map_zoom_out` (aktualisiert `km_per_px`)
- MapCam: Bewegung mit WASD (geschwindigkeitsskaliert)
- MapCam: Maus-Drag
- MapCam: Zoom auf Mausposition
- Map Scale Presets (Tasten 6–0)
- Grid reagiert korrekt auf Zoom und Kamerabewegung

**Testbar:** Man kann frei navigieren, Grid bleibt korrekt, Zoom fühlt sich flüssig an.

### Stufe 4 — Marker

**Ziel:** Alle Bodies als Marker auf der Karte sichtbar.

- MapMarker-Szene mit Icon-Sprite und State-System
- MapController instanziiert pro Body einen Marker
- Positionen werden pro Tick aktualisiert (Live-Modus)
- Marker-Größenstufen reagieren auf Zoom
- Gruppensystem basierend auf type/subtype/map_tags
- Labels für Planeten und Major Bodies

**Testbar:** Alle Planeten, Monde und Strukturen sichtbar an korrekten Positionen, bewegen sich mit der Simulation.

### Stufe 5 — Orbits

**Ziel:** Orbitlinien für alle Bodies mit orbitaler Motion.

- OrbitRenderer mit gecachten Pfaden
- Orbits bewegen sich mit ihrem Parent
- Orbit-States (Default, Highlight, Dimmed)
- Orbit-Gruppensystem synchron mit Markern

**Testbar:** Orbitlinien sichtbar, bewegen sich korrekt, Highlight bei Hover über zugehörigen Marker.

### Stufe 6 — Belts

**Ziel:** Asteroiden-, Kuiper-Gürtel und Trojaner-Wolken sichtbar.

- BeltRenderer: Punktwolken aus BeltDefs
- LOD-System (Punktanzahl abhängig vom Zoom)
- Trojaner-Rotation (folgt Reference Body)
- Punkt-Skalierung abhängig vom Zoom

**Testbar:** Alle definierten Belts sichtbar, LOD funktioniert, Trojaner folgen ihren Planeten.

### Stufe 7 — Culling

**Ziel:** Saubere Darstellung bei allen Zoom-Stufen.

- Viewport-Culling für Marker, Orbits und Belt-Punkte
- Parent-Proximity-Culling (Kinder ausblenden bei Mindestabstand)
- Rekursives Culling über die Body-Hierarchie
- Performance-optimiert (Culling-Check nur bei Zoom-/Positionsänderung)

**Testbar:** Herauszoomen blendet sauber Monde und Strukturen aus, Reinzoomen bringt sie zurück. Kein visuelles Chaos bei extremem Zoom.

### Stufe 8 — Mausinteraktion

**Ziel:** Klick- und Hover-Interaktion mit Markern.

- Hover-Detection mit Area2D
- Click und Double-Click Signale
- Überlappungs-Priorität (struct > moon > dwarf > planet > star)
- Visueller Hover-Feedback (State-Wechsel oder Screen-Tooltip)
- MarkerLayer leitet Signale an MapController → Screen

**Testbar:** Marker reagieren auf Hover und Klick, korrekte Priorität bei Überlappung.

### Stufe 9 — Erweiterte Features

**Ziel:** Vollständige Feature-Parität mit den Mockups.

- MapTransform: Log-Modus implementieren
- MapTransform: Exaggeration implementieren
- MapClock: Scrub-Modus (Offset-Steuerung)
- ZoneRenderer: Zonen zeichnen
- GridRenderer: Quadratisches Grid als Alternative
- MapController API: Alle Konfigurations-Methoden für den Screen

**Testbar:** Alle Modi umschaltbar, Time Scrubbing funktioniert, Zonen sichtbar.