# Map System — Implementierungs-Leitfaden

> Kompakte Arbeitsgrundlage für die Code-Session. Abgeleitet aus `SPEC_map_system.md` (Stand 2026-03-19), `SPEC_sim_core.md` und `SPEC_solar_system_sim_data.md`.

---

## 1. Gesamtbild

Das Map System ist die zentrale visuelle Schnittstelle eines Weltraumspiels in **Godot 4 (GDScript)**. Alle Ansichten sind diegetisch (Cockpit-Displays). Die Karte IST der Spielbildschirm.

**Drei Views (nur StarChart wird jetzt implementiert):**

| View | Zweck | Status |
|---|---|---|
| **StarChart** | Strategische Übersicht, Kursplanung | **Implementierung jetzt** |
| SensorDisplay | Lokale Lage, Signalverzögerung | Spätere Spec |
| TacticalDisplay | Nahkampf, Manöver | Spätere Spec |

**Bestehende Autoloads (extern, nicht verändern):**

- `SimClock` — Zeitgeber, `sim_clock_tick(sst_s: float)` Signal
- `SolarSystem` — Positionen aller ~73 Bodies (1 Stern, 9 Planeten, 5 Zwerge, 32 Monde, 26 Structs)

---

## 2. Schichtenarchitektur

```
Autoloads (BESTEHEND, read-only)
├── SimClock                    — sim_clock_tick(sst_s)
└── SolarSystem                 — get_body_position(id), get_local_orbit_path(id), etc.

Toolkit (NEU, ansichtsagnostisch, wiederverwendbar)
├── MapScale                    — RefCounted, Skalierungsmathe
├── ScopeConfig                 — Resource (.tres), Rendering-Kontext
├── ScopeResolver               — RefCounted, Scope-Auswahl + Sichtbarkeitslogik
├── BodyMarker                  — Area2D-Szene, symbolische Darstellung
├── BodyModel                   — Stub (spätere Spec)
├── OrbitRenderer               — Node2D-Szene, Orbit-Linie
├── BeltRenderer                — Node2D-Szene, prozedurale Punktwolke
└── ZoneRenderer                — Node2D-Szene, halbtransparente Farbfläche

Views (NEU, eigenständige Szenen)
└── StarChart                   — Diese Implementierung

Einbettung (NEU)
└── StarChartScreen             — Wrapper mit InfoPanel, NavPanel etc.
```

**Datenfluss-Prinzip:** Immer Top-Down. Kein Toolkit-Code schreibt auf die Sim.

```
SolarSystem (Welt-km)
  → MapScale (km → px)
  → View (Transformation: linear oder log, Sichtbarkeit, Sizing)
  → BodyMarker / OrbitRenderer / etc. (fertige Screen-Koordinaten)
```

Signale fließen Bottom-Up: `BodyMarker.clicked → StarChart → StarChartScreen`

---

## 3. SolarSystem API (bestehend, read-only)

```gdscript
# Positionen
SolarSystem.get_body_position(id: String) -> Vector2           # Welt-km, aktueller Zeitpunkt
SolarSystem.get_body_positions_at_time(ids: Array[String], sst: float) -> Dictionary  # Batch, keine Seiteneffekte
SolarSystem.get_body_position_at_time(id: String, sst: float) -> Vector2
SolarSystem.get_local_orbit_path(id: String) -> Array[Vector2] # relativ zum Parent, einmalig gecacht

# Körper-Abfragen
SolarSystem.get_body(id: String) -> BodyDef
SolarSystem.get_all_body_ids() -> Array
SolarSystem.get_child_bodies(parent_id: String) -> Array[BodyDef]
SolarSystem.get_bodies_by_type(type: String) -> Array[BodyDef]
SolarSystem.get_root_bodies() -> Array[BodyDef]
SolarSystem.get_body_orbit_radius_km(id: String) -> float

# Signal
SolarSystem.simulation_updated  # nach jedem _current_state-Update (nur bei laufender Uhr)
```

**BodyDef-Felder:** `id`, `name`, `type` (star/planet/dwarf/moon/struct), `subtype`, `parent_id`, `radius_km`, `mu_km3_s2`, `map_icon`, `color_rgba` (Color), `motion` (BaseMotionDef), `map_tags` (Array[String]), `gameplay_tags` (Array[String])

**Koordinatensystem:** 2D (x/y-Ebene), km, Sonne = (0,0).

---

## 4. Toolkit-Komponenten

### 4.1 MapScale (`extends RefCounted`)

Reine Skalierungsmathe. Kein Clamping, keine Regeln.

```gdscript
# Kern: Exponentielles Zoom-System
# scale_exp → km_per_px = 10^scale_exp → px_per_km = 1/km_per_px

# API:
func set_scale_exp(exp: float) -> void      # Setzt alles, berechnet Ableitungen
func get_scale_exp() -> float
func get_px_per_km() -> float
func get_km_per_px() -> float
func world_to_screen(world_km: Vector2) -> Vector2   # world_km * px_per_km
func screen_to_world(screen_px: Vector2) -> Vector2   # screen_px * km_per_px
func km_to_px(km: float) -> float
func px_to_km(px: float) -> float
```

**Referenzwerte:**

| scale_exp | km_per_px | ~Breite bei 1920px |
|---|---|---|
| 3.0 | 1.000 | 1,92 Mio km (Mond-System) |
| 5.0 | 100.000 | 192 Mio km (inneres System) |
| 6.0 | 1.000.000 | 1,92 Mrd km (bis Saturn) |
| 7.0 | 10.000.000 | 19,2 Mrd km (Kuipergürtel) |

### 4.2 ScopeConfig (`extends Resource`)

Godot-Resource (.tres). Beschreibt einen Rendering-Kontext.

```gdscript
# Identifikation
@export var scope_name: String

# Bedingungen
@export var zoom_min: float
@export var zoom_max: float
@export var fokus_tags: Array[String]   # OR-Logik gegen fokussierten Body

# Darstellung
@export var distanz_modus: int          # LINEAR (0) oder LOG (1)
@export var exaggeration_faktor: float  # Spreizung für Enkel im Log-Modus
@export var sichtbare_typen: Array[String]   # Type-Filter (OR, leer=alle)
@export var sichtbare_tags: Array[String]    # Tag-Filter (OR, leer=alle)
@export var sichtbare_zonen: Array[String]   # Zone/Belt-IDs für Flächen
@export var min_orbit_px: float              # Orbits < diesen Wert ausblenden
@export var marker_sizes: Dictionary         # {"star": 32, "planet": 24, ...}
```

**Sichtbarkeitslogik:**
```
type_pass  = sichtbare_typen leer OR body.type in sichtbare_typen
tag_pass   = sichtbare_tags leer  OR ≥1 body.map_tag in sichtbare_tags
orbit_pass = kein Orbit           OR orbit_px >= min_orbit_px
sichtbar   = type_pass AND tag_pass AND orbit_pass
```

### 4.3 ScopeResolver (`extends RefCounted`)

```gdscript
func setup(scopes: Array[ScopeConfig]) -> void
func resolve(scale_exp: float, focused_body: BodyDef) -> ScopeConfig   # Erster Treffer gewinnt
func is_body_visible(body: BodyDef, scope: ScopeConfig, orbit_px: float) -> bool
```

Kein interner Cache. Kein Pinned-Management (das macht die View).

### 4.4 BodyMarker (`extends Area2D`)

Szene: `BodyMarker > Icon (Sprite2D) + Label (Label) + ClickShape (CollisionShape2D)`

```gdscript
# Interner Zustand
var _body_id: String
var _body_type: String
var _current_size_px: int

@export var click_padding_px: int = 6

# API
func setup(body: BodyDef, size_px: int) -> void
func set_size(size_px: int) -> void

# Signale
signal clicked(body_id: String)
signal double_clicked(body_id: String)
```

- Feste Pixelgröße (Scope-gesteuert, nicht Zoom-kontinuierlich)
- Speichert KEINE BodyDef-Referenz — nur extrahierte Werte
- Position wird von der View direkt gesetzt: `marker.position = ...`
- Aktivierung: `visible + ClickShape.disabled`

### 4.5 OrbitRenderer (`extends Node2D`)

```gdscript
var _child_id: String
var _parent_id: String
var _color: Color
var _path_points_km: Array[Vector2]   # Original, unveränderlich
var _draw_points: PackedVector2Array  # Fertige Screen-Punkte
var _line_style: int                   # SOLID(0), DASHED(1), DOTTED(2)

@export var line_width: float = 1.5
@export var antialiased: bool = true

func setup(child_id, parent_id, color, path_points_km) -> void
func set_draw_points(screen_points: PackedVector2Array) -> void
func set_line_style(style: int) -> void
func get_path_points_km() -> Array[Vector2]
```

- Zeichnet relativ zu eigener Position (View setzt `renderer.position = parent_marker.position`)
- Neuberechnung nur bei Zoom-Änderung, nicht bei Parent-Bewegung

### 4.6 BeltRenderer (`extends Node2D`)

Prozedurale Punktwolke für Asteroiden-/Kuipergürtel, Trojaner, Planetenringe.

**Datenquelle:** `belt_data.json` → `BeltDef extends RefCounted`

```gdscript
# BeltDef-Felder: id, name, parent_id, reference_body_id, inner_radius_km,
# outer_radius_km, angular_offset_rad, angular_spread_rad, min_points,
# max_points, seed, color_rgba

# Intern: PackedFloat32Arrays für radii_km, angles_rad, sizes_px, color_offsets, priorities
# Sortiert nach priority, LOD durch visible_count

func setup(belt: BeltDef) -> void
func set_density(visible_count: int) -> void
func set_reference_angle(angle_rad: float) -> void   # Nur für Trojaner
func set_scale(px_per_km: float) -> void
```

**LOD-Formel:**
```
density = clamp((zoom_max - scale_exp) / (zoom_max - zoom_min), 0, 1)
visible_count = min_points + int(density * (max_points - min_points))
```

### 4.7 ZoneRenderer (`extends Node2D`)

Halbtransparente Farbflächen für Strahlungsgürtel, Magnetosphären etc.

**Datenquelle:** `zone_data.json` → `ZoneDef extends RefCounted`

```gdscript
# ZoneDef-Felder: id, name, parent_id, zone_type, geometry (circle/ring),
# radius_km, inner_radius_km, outer_radius_km, color_rgba, border_color_rgba

@export var border_width: float = 1.5
@export var circle_segments: int = 64

func setup(zone: ZoneDef) -> void
func set_scale(px_per_km: float) -> void
```

- Circle: `draw_circle()` + `draw_arc()`
- Ring: Polygon aus äußerem/innerem Kreis + 2× `draw_arc()`
- Position von View gesetzt: `zone_renderer.position = parent_marker.position`

---

## 5. StarChart — Szenenstruktur

```
StarChart (Node2D)
├── Camera2D
├── BackgroundLayer (CanvasLayer, z=-100)
├── ZonesLayer (Node2D)         ← ZoneRenderer-Instanzen
├── BeltsLayer (Node2D)         ← BeltRenderer-Instanzen
├── OrbitsLayer (Node2D)        ← OrbitRenderer-Instanzen
├── BodyLayer (Node2D)          ← BodyMarker-Instanzen (flat, nicht hierarchisch!)
├── GridLayer (Node2D)          ← GridRenderer
└── HUDLayer (CanvasLayer)      ← ZoomDisplay, Zeitanzeige, Debug-Overlays
```

**Alle Marker/Renderer liegen flat** — keine Szenen-Hierarchie die die Sim-Hierarchie spiegelt. Die View positioniert alles explizit.

---

## 6. StarChart — Kernzustand

```gdscript
# Toolkit-Instanzen
var _map_scale: MapScale
var _scope_resolver: ScopeResolver
var _current_scope: ScopeConfig

# Fokus
var _focused_body_id: String = ""     # Leer = kein Fokus
var _pinned_bodies: Dictionary = {}   # id → true

# Body-Tracking
var _all_markers: Dictionary = {}     # id → BodyMarker
var _all_orbit_renderers: Dictionary = {}  # id → OrbitRenderer
var _active_body_ids: Array[String] = []   # Aktuell sichtbare Bodies

# Darstellungsmodus
var _display_mode: int = LINEAR       # LINEAR oder LOG (kann manuell überschrieben werden)
```

---

## 7. StarChart — Update-Zyklus

Verbindet sich mit `SolarSystem.simulation_updated`:

```
Pro Frame (wenn Sim läuft):
1. Positionen aller _active_body_ids von SolarSystem abfragen
2. Positionen durch MapScale.world_to_screen() + ggf. Log-Transformation
3. Marker.position setzen
4. OrbitRenderer.position auf Parent-Marker setzen
5. BeltRenderer.position + reference_angle updaten
6. ZoneRenderer.position updaten
```

**Scope-Neubewertung** (nur bei Zoom oder Fokus-Änderung):

```
1. new_scope = _scope_resolver.resolve(scale_exp, focused_body)
2. if new_scope != _current_scope:
     _current_scope = new_scope
     _rebuild_active_bodies()  → iteriert ALLE Bodies, prüft Sichtbarkeit
     _apply_scope()            → Marker-Sizes, Belt/Zone-Sichtbarkeit
3. Orbit-Punkte neu berechnen (set_draw_points)
```

**Sichtbarkeitsprüfung pro Body:**

```gdscript
func _is_body_active(body: BodyDef) -> bool:
    if _pinned_bodies.has(body.id): return true
    var orbit_px = _map_scale.km_to_px(SolarSystem.get_body_orbit_radius_km(body.id))
    return _scope_resolver.is_body_visible(body, _current_scope, orbit_px)
```

---

## 8. StarChart — Skalierung und Log-Transformation

**Linearer Modus:** `screen_pos = MapScale.world_to_screen(world_km)` — direkt.

**Logarithmischer Modus:** Für Systemübersichten, wo Entfernungen viele Größenordnungen umfassen. Die Log-Transformation komprimiert weit entfernte Objekte und spreizt nahe. Details werden bei der Implementierung festgelegt (Kapitel 10-11 der Spec noch ausstehend).

**Exaggeration-Faktor:** Spreizt lokale Offsets von Enkeln im Log-Modus (z.B. Monde eines Planeten). Wert > 1.0 in ScopeConfig. Gilt für Marker-Positionen UND Orbit-Linien. Gilt NICHT für ZoneRenderer.

---

## 9. StarChart — Kamera und Input

**Kamera:** Standard Godot Camera2D, gesteuert von der StarChart.

**Input:**
- **Scroll:** Zoom (scale_exp ändern, smooth)
- **Drag:** Pan
- **Klick auf Marker:** Fokus setzen
- **Doppelklick auf Marker:** Fokus + Zoom-to-Fit
- **Tastatur:** Zoom-Stufen, Fokus-Navigation

**Zoom-Anker:** Beim Zoomen bleibt der Punkt unter dem Cursor an seiner Bildschirmposition (erfordert `screen_to_world` für Anker-Berechnung).

---

## 10. StarChart — Signale (nach außen)

```gdscript
signal body_focused(body_id: String)
signal body_unfocused()
signal scope_changed(scope: ScopeConfig)
signal body_selected(body_id: String)      # Für UI-Panels
signal zoom_changed(scale_exp: float)
```

Signale transportieren nur primitive Werte. Consumer holen Details über SolarSystem-API.

---

## 11. StarChartScreen — Einbettung

Wrapper-Szene die StarChart mit UI-Panels verbindet:

```
StarChartScreen (Control)
├── StarChart                  ← Die eigentliche Kartenszene
├── InfoPanel                  ← Body-Details bei Selektion
├── NavPanel                   ← Kursplanung
├── TimeControl                ← Zeitsteuerung (SimClock)
└── ZoomDisplay                ← Aktuelle Zoom-Stufe / Scope-Name
```

StarChartScreen verbindet sich mit StarChart-Signalen und steuert die Panels.

---

## 12. Zusätzliche Daten-Dateien (NEU zu erstellen)

### belt_data.json

```json
{
  "belts": [
    {
      "id": "asteroid_belt",
      "name": "Asteroid Belt",
      "parent_id": "sun",
      "reference_body_id": "",
      "inner_radius_km": 329000000,
      "outer_radius_km": 478700000,
      "angular_offset_rad": 0.0,
      "angular_spread_rad": 6.2832,
      "min_points": 600,
      "max_points": 3000,
      "seed": 1,
      "color_rgba": [0.85, 0.25, 0.2, 0.7]
    }
    // + Kuipergürtel, Scattered Disk, Trojaner (L4/L5 für Jupiter+Mars), Planetenringe
  ]
}
```

### zone_data.json

```json
{
  "zones": [
    {
      "id": "jupiter_radiation_belt",
      "name": "Jupiter Radiation Belt",
      "parent_id": "jupiter",
      "zone_type": "radiation",
      "geometry": "ring",
      "inner_radius_km": 92000,
      "outer_radius_km": 800000,
      "color_rgba": [0.9, 0.3, 0.1, 0.15],
      "border_color_rgba": [0.9, 0.3, 0.1, 0.4]
    }
    // + Van Allen Belts (Earth), Jupiter Magnetosphere, etc.
  ]
}
```

---

## 13. Implementierungs-Reihenfolge (empfohlen)

### Phase 1 — Toolkit-Fundament
1. `MapScale` (RefCounted, reine Mathe — einfachster Start)
2. `ScopeConfig` (Resource-Klasse, reine Daten)
3. `ScopeResolver` (RefCounted, Logik)

### Phase 2 — Rendering-Primitive
4. `BodyMarker` (Area2D-Szene + Script)
5. `OrbitRenderer` (Node2D-Szene + Script)
6. `BeltDef` + `BeltRenderer` (Datenklasse + Node2D)
7. `ZoneDef` + `ZoneRenderer` (Datenklasse + Node2D)

### Phase 3 — StarChart-View
8. Szenenstruktur aufbauen (Layer-Hierarchy)
9. Initialisierung: Alle Marker/Renderer instanziieren
10. Update-Zyklus: Positionen, Scope-Bewertung
11. Kamera + Input (Zoom, Pan, Klick)
12. Log-Transformation + Exaggeration

### Phase 4 — Integration
13. ScopeConfig .tres-Dateien definieren (Game-Design)
14. `belt_data.json` + `zone_data.json` erstellen
15. `StarChartScreen` Wrapper
16. HUD-Elemente (ZoomDisplay, Zeitanzeige)

---

## 14. Design-Prinzipien (Zusammenfassung)

- **Dumme Primitive:** Marker/Renderer empfangen fertige Daten. Keine eigene Logik.
- **View entscheidet alles:** Position, Sichtbarkeit, Größe, Transformation.
- **Flat statt hierarchisch:** Alle Marker unter BodyLayer, alle Renderer unter OrbitsLayer. Keine Szenen-Hierarchie = einfacheres Management.
- **Einmal instanziieren, nie zerstören:** Marker leben für die gesamte View-Lebensdauer. Aktivierung = `visible + collision`.
- **Scopes definieren Kontext:** Ein Scope beschreibt WAS sichtbar ist und WIE es aussieht. Erster Treffer gewinnt.
- **Pinned overrides Scope:** Gepinnte Bodies sind immer sichtbar, unabhängig vom Scope.
- **Determinismus:** Die Simulation ist pure function von Zeit. Kein Zufall, kein Gameplay-State.

---

## 15. Offene Punkte (Kapitel 9-20 der Spec noch ausstehend)

Die folgenden Kapitel sind in der Spec referenziert aber noch nicht ausformuliert:

- **Kap. 9:** StarChart Update-Zyklus (Details)
- **Kap. 10:** Logarithmische Transformation (Formel, Übergänge)
- **Kap. 11:** Kamera (Zoom-Verhalten, Anker, Grenzen)
- **Kap. 12:** Input-Handling (Maus + Tastatur, Doppelklick-Logik)
- **Kap. 13:** GridRenderer und HUD
- **Kap. 14:** Signale (vollständige Liste)
- **Kap. 15:** Randfälle und Fehlerzustände
- **Kap. 16:** Export-Variablen Übersicht
- **Kap. 17:** StarChartScreen Einbettung (Details)
- **Kap. 18:** Weitere Views (Ausblick)
- **Kap. 19:** Anforderungen an bestehende Systeme
- **Kap. 20:** Offene Punkte

→ Bei der Implementierung dieser Bereiche: pragmatische Entscheidungen treffen und dokumentieren, damit die spätere Spec-Ausarbeitung den Code widerspiegelt.
