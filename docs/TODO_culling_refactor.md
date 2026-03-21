# TODO: Culling-System Refactor

> Scope-System entfernen, Culling auf min_orbit_px + Viewport vereinfachen.
> Filter-System als eigene Klasse. Fokus ohne Stack.
> Sim Core, MapScale, Renderer und CamController bleiben unangetastet.

---

## Zusammenfassung der Entscheidungen

### Culling — 2 Regeln
1. **min_orbit_px** — `orbit_km × px_per_km ≥ MIN_ORBIT_PX` → sichtbar (globale Konstante)
2. **Viewport-Culling** — nur rendern/updaten was auf dem Bildschirm ist

### Exaggeration
- Fokus aktiv = Exag automatisch an für Kinder des fokussierten Body
- Kein Fokus = Exag aus
- Kein manueller Toggle, kein separater State

### Fokus (kein Stack)
- Doppelklick → Fokus setzen, Exag an, Zoom-to-fit
- Doppelklick anderer Body → Fokus wechseln (alter weg, neuer rein)
- Escape / Klick ins Leere / Pan → Fokus lösen, Exag aus
- Nur `_pre_focus_scale_exp` + `_pre_focus_center_km` zum Zurückkehren
- Kein FocusState-Objekt, kein Stack, kein Push/Pop/Replace

### Filter-System
- Eigene Klasse `MapFilterState` (Node, @export, im Editor konfigurierbar)
- Hierarchisch: Type-Toggle steuert alle Subtypes darunter
- Kategorien: Bodies (type+subtype), Orbits (per parent-type), Zones (per zone_type), Belts (per belt_id)
- Filter persistent über Fokus-Wechsel
- Signal `filter_changed` für Redraw

### Map Settings Menü
- Einblendbares Panel links (Gegenstück zum InfoPanel rechts)
- Toggle-Button im Header
- Enthält alle Filter-Toggles

---

## Phase 1: Scope-System löschen

### 1.1 — Dateien löschen
- [ ] `game/map/toolkit/scope/scope_config.gd` löschen
- [ ] `game/map/toolkit/scope/scope_resolver.gd` löschen
- [ ] `game/map/toolkit/scope/` Ordner löschen
- [ ] `game/map/views/star_chart/scopes/` — alle `.tres` Scope-Dateien + Ordner löschen

### 1.2 — Scope Inspector Addon löschen
- [ ] `addons/scope_inspector/` — gesamten Ordner löschen
- [ ] `project.godot` — Eintrag `"res://addons/scope_inspector/plugin.cfg"` aus `[editor_plugins] enabled` entfernen

---

## Phase 2: MapFilterState erstellen

Neue Klasse für den gesamten Filter-Zustand. Lebt als Node in der View-Scene,
wird vom Map Settings UI beschrieben und von MapViewController + View gelesen.

### 2.1 — MapFilterState schreiben

- [ ] Neue Datei: `game/map/toolkit/filter/map_filter_state.gd`

```gdscript
class_name MapFilterState extends Node

signal filter_changed

# ─── Bodies: Type-Toggles ─────────────────────────────────────────────────
# Hierarchisch: Type aus → alle Subtypes dieses Types auch aus.

@export var show_stars: bool = true
@export var show_planets: bool = true
@export var show_dwarfs: bool = true
@export var show_moons: bool = true
@export var show_structs: bool = true

# ─── Bodies: Subtype-Toggles ──────────────────────────────────────────────
# Nur relevant wenn der Parent-Type aktiv ist.

# star subtypes
@export var show_g_type: bool = true

# planet subtypes
@export var show_terrestrial: bool = true
@export var show_gas_giant: bool = true
@export var show_ice_giant: bool = true
@export var show_sub_neptune: bool = true

# dwarf subtypes
@export var show_asteroid_dwarf: bool = true
@export var show_plutoid: bool = true

# moon subtypes
@export var show_major_moon: bool = true
@export var show_minor_moon: bool = true

# struct subtypes
@export var show_station: bool = true
@export var show_shipyard: bool = true
@export var show_outpost: bool = true
@export var show_relay: bool = true
@export var show_navigation_point: bool = true

# ─── Orbits: per Parent-Type ──────────────────────────────────────────────

@export var show_planet_orbits: bool = true
@export var show_dwarf_orbits: bool = true
@export var show_moon_orbits: bool = true
@export var show_struct_orbits: bool = true

# ─── Zones: per Zone-Type ────────────────────────────────────────────────

@export var show_radiation_zones: bool = true
@export var show_magnetic_zones: bool = true
@export var show_gravity_zones: bool = true
@export var show_habitable_zones: bool = true

# ─── Belts ────────────────────────────────────────────────────────────────

@export var show_asteroid_belt: bool = true
@export var show_kuiper_belt: bool = true
```

### 2.2 — Query-Methoden

```gdscript
func is_body_visible(type: String, subtype: String) -> bool
    # 1. Type-Toggle prüfen (show_stars, show_planets, ...)
    # 2. Wenn Type an → Subtype-Toggle prüfen
    # 3. Beides an → true

func is_orbit_visible(parent_type: String) -> bool
    # Liest show_planet_orbits etc.

func is_zone_visible(zone_type: String) -> bool
    # Liest show_radiation_zones etc.

func is_belt_visible(belt_id: String) -> bool
    # Liest show_asteroid_belt etc.
```

### 2.3 — Setter-Methoden (für UI)

```gdscript
func set_type_enabled(type: String, enabled: bool) -> void
    # Setzt show_stars/show_planets/... + emittiert filter_changed

func set_subtype_enabled(subtype: String, enabled: bool) -> void
    # Setzt show_terrestrial/show_gas_giant/... + emittiert filter_changed

func set_orbit_enabled(parent_type: String, enabled: bool) -> void
func set_zone_type_enabled(zone_type: String, enabled: bool) -> void
func set_belt_enabled(belt_id: String, enabled: bool) -> void
```

### 2.4 — Scene erstellen
- [ ] `game/map/toolkit/filter/MapFilterState.tscn` — Root: MapFilterState Node
- [ ] Alle @export-Werte im Inspektor konfigurierbar (Defaults: alles an)

---

## Phase 3: MapViewController umbauen

Wird von RefCounted zu Node. Kein ScopeResolver/ScopeConfig mehr.
Konsumiert MapFilterState für Body-Sichtbarkeit.

### 3.1 — Neuen MapViewController schreiben

- [ ] `game/map/toolkit/map_view_controller.gd` komplett neu schreiben

```gdscript
class_name MapViewController extends Node

# ─── @export ──────────────────────────────────────────────────────────────

@export var min_orbit_px: float = 8.0
    # Globale Konstante. Orbits unter diesem Pixel-Radius werden ausgeblendet.

@export var cull_margin_px: float = 100.0
    # Margin um den Viewport für Culling.

@export var exag_faktor: float = 5.0
    # Spreizungsfaktor für Kinder des fokussierten Body.

@export var marker_sizes: Dictionary = {
    "star": 32, "planet": 24, "dwarf": 16, "moon": 14, "struct": 12
}
    # Marker-Größen pro Body-Type. Im Inspektor konfigurierbar.

# ─── Interner State ───────────────────────────────────────────────────────

var _map_scale: MapScale = null
var _filter: MapFilterState = null
var _focused_body_id: String = ""    # Leer = kein Fokus
var _exag_body_ids: Array[String] = []
```

### 3.2 — API

```gdscript
# Setup — empfängt MapScale + MapFilterState Referenzen
func setup(scale: MapScale, filter: MapFilterState) -> void

# ─── Sichtbarkeit ─────────────────────────────────────────────────────────

func is_body_visible(body: BodyDef, orbit_km: float) -> bool
    # 1. Root-Bodies (parent_id leer) → immer min_orbit_px passieren
    # 2. orbit_px = orbit_km * px_per_km
    # 3. Wenn Exag-Kind (parent_id in _exag_body_ids):
    #    orbit_px *= exag_faktor
    # 4. orbit_px >= min_orbit_px?
    # 5. filter.is_body_visible(body.type, body.subtype)?

func get_marker_size(body_type: String) -> int
    # Liest aus marker_sizes, Fallback: 16

# ─── Koordinaten ──────────────────────────────────────────────────────────

func world_to_display(world_km: Vector2, body: BodyDef,
        parent_pos_km: Vector2 = Vector2.ZERO) -> Vector2
    # Wenn body.parent_id in _exag_body_ids:
    #   parent_screen + (child_world - parent_world) * px_per_km * exag_faktor
    # Sonst: map_scale.world_to_screen(world_km)

# ─── Viewport-Culling ────────────────────────────────────────────────────

func get_cull_rect(cam_pos: Vector2, vp_size: Vector2) -> Rect2
func is_in_viewport(screen_pos: Vector2, cull_rect: Rect2) -> bool

# ─── Fokus & Exaggeration ────────────────────────────────────────────────

func set_focus(body_id: String) -> void
    # Setzt _focused_body_id und _exag_body_ids = [body_id]

func clear_focus() -> void
    # _focused_body_id = "", _exag_body_ids = []

func get_focused_body_id() -> String
func is_focused() -> bool

# ─── Zoom-to-Fit ─────────────────────────────────────────────────────────

func calc_fit_scale_exp(max_child_orbit_km: float, vp_size: Vector2) -> float
    # Berechnet den scale_exp bei dem der äußerste Kind-Orbit
    # (mit Exag) ca. 1/3 des Viewports füllt.
    # target_px = min(vp_size.x, vp_size.y) / 3.0
    # effective_orbit = max_child_orbit_km * exag_faktor
    # return log10(effective_orbit / target_px)

# ─── Belt-LOD ─────────────────────────────────────────────────────────────

func get_belt_density(belt: BeltDef) -> int
    # Unverändert
```

### 3.3 — MapViewController.tscn erstellen
- [ ] Neue Scene `game/map/toolkit/MapViewController.tscn`
- [ ] Root-Node: MapViewController
- [ ] Alle @export-Werte im Inspektor sichtbar

---

## Phase 4: Map Settings Menü (UI)

Einblendbares Panel auf der linken Seite des StarChartScreen.

### 4.1 — Toggle-Button im Header
- [ ] Neuen Button im Header hinzufügen (links, z.B. Zahnrad-Icon oder "Filter")
- [ ] Button toggled Sichtbarkeit des Map Settings Panels

### 4.2 — Map Settings Panel bauen
- [ ] Lebt als Child des StarChartScreen (neben InfoPanel)
- [ ] Linke Seite, gleiche Höhe wie Map-Bereich
- [ ] Visueller Stil: gleicher Chrome wie InfoPanel
- [ ] Default: ausgeblendet

### 4.3 — Panel-Inhalt (Sections mit Toggles)

```
[Map Settings]

├─ Bodies
│  ├─ [✓] Stars
│  │   └─ [✓] G-Type
│  ├─ [✓] Planets
│  │   ├─ [✓] Terrestrial
│  │   ├─ [✓] Gas Giant
│  │   ├─ [✓] Ice Giant
│  │   └─ [✓] Sub-Neptune
│  ├─ [✓] Dwarfs
│  │   ├─ [✓] Asteroid Dwarf
│  │   └─ [✓] Plutoid
│  ├─ [✓] Moons
│  │   ├─ [✓] Major Moon
│  │   └─ [✓] Minor Moon
│  └─ [✓] Structures
│      ├─ [✓] Station
│      ├─ [✓] Shipyard
│      ├─ [✓] Outpost
│      ├─ [✓] Relay
│      └─ [✓] Navigation Point
│
├─ Orbits
│  ├─ [✓] Planet Orbits
│  ├─ [✓] Dwarf Orbits
│  ├─ [✓] Moon Orbits
│  └─ [✓] Struct Orbits
│
├─ Zones
│  ├─ [✓] Radiation
│  ├─ [✓] Magnetic
│  ├─ [✓] Gravity
│  └─ [✓] Habitable
│
└─ Belts
   ├─ [✓] Asteroid Belt
   └─ [✓] Kuiper Belt
```

### 4.4 — Hierarchisches Toggle-Verhalten
- [ ] Type-Toggle aus → alle Subtype-Toggles ausgegraut + aus
- [ ] Type-Toggle an → Subtype-Toggles wieder individuell steuerbar
- [ ] Subtype-Toggles merken sich ihren letzten Zustand wenn Type aus/an geht

### 4.5 — Verdrahtung
- [ ] Jeder Toggle ruft den passenden Setter auf MapFilterState auf
- [ ] MapFilterState emittiert `filter_changed`
- [ ] View reagiert auf `filter_changed` → Redraw

---

## Phase 5: Test-Szene anpassen

### 5.1 — map_test_scene.gd refactorn
- [ ] Alle ScopeConfig/ScopeResolver Referenzen entfernen
- [ ] `_setup_scale_and_scope()` → `_setup_scale()` — kein Scope-Setup mehr
- [ ] MapFilterState als Node instanziieren oder aus Scene laden
- [ ] MapViewController: `setup(scale, filter)` statt `setup(resolver, scale)`
- [ ] Marker-Size: `_view_controller.get_marker_size(body.type)` statt `scope.get_marker_size()`
- [ ] `is_body_visible()` direkt ohne Scope-Zwischenschritt
- [ ] Orbit-Sichtbarkeit: `filter.is_orbit_visible(body.type)`
- [ ] HUD: Scope-Label entfernen, ggf. Filter-Status anzeigen

### 5.2 — MapTestScene.tscn aktualisieren
- [ ] MapViewController als Child-Node einhängen
- [ ] MapFilterState als Child-Node einhängen
- [ ] @export-Werte setzen (min_orbit_px, marker_sizes, Filter-Defaults)

---

## Phase 6: StarChartView-Spec anpassen

### 6.1 — SPEC_star_chart_view.md überarbeiten
- [ ] Abhängigkeiten-Tabelle:
  - ScopeResolver → entfernen
  - MapViewController: `= MapViewController.new()` → Child-Node aus Scene
  - Neu: MapFilterState als Child-Node oder Referenz
- [ ] Fokus-System komplett vereinfachen:
  - FocusState-Klasse entfernen
  - Stack-Operationen (Push/Pop/Replace) entfernen
  - Ersetzen durch:
    - `_focused_body_id: String` (oder leer)
    - `_pre_focus_scale_exp: float`
    - `_pre_focus_center_km: Vector2`
  - Doppelklick: Fokus setzen, `_pre_focus_*` speichern, Exag an, zoom-to-fit
  - Doppelklick anderer Body: Fokus wechseln (pre_focus bleibt)
  - Escape / Klick ins Leere / Pan: Fokus lösen, Kamera zurück zu pre_focus, Exag aus
- [ ] "Scope wechselt (Kinder werden sichtbar)" → "Exag wird aktiviert"
- [ ] Abschnitt 9 (Scopes) → komplett ersetzen durch Culling-Beschreibung
- [ ] Abschnitt 10 (Abgrenzung): "Scope-Dateien editieren" → entfernen
- [ ] Neu dokumentieren: Map Settings Menü (links, Filter-Panel)

### 6.2 — star_chart_screen.gd anpassen
- [ ] Header: `_header_scope_label` entfernen
- [ ] Header: neuen Toggle-Button für Map Settings Menü hinzufügen
- [ ] Map Settings Panel als Child-Node (links)
- [ ] `update_header_info()` Signatur: kein Scope-Name mehr

---

## Phase 7: CamController-Spec anpassen

Der CamController selbst bleibt unverändert. Nur die Spec-Dokumentation
muss an den Stellen angepasst werden wo sie den Scope-Kontext referenziert.

### 7.1 — SPEC_map_cam_controller.md
- [ ] Keine Code-Änderungen am CamController nötig
- [ ] Prüfen ob die Spec irgendwo "Scope" erwähnt → durch Culling-Terminologie ersetzen
- [ ] Fokus-Anker-Logik bleibt wie dokumentiert (View setzt den Anker)

---

## Phase 8: Dokumentation

### 8.1 — MAP_TOOLKIT.md komplett überarbeiten
- [ ] Dateistruktur aktualisieren:
  - `scope/` Ordner → weg
  - `filter/` Ordner → neu (map_filter_state.gd, MapFilterState.tscn)
  - MapViewController.tscn → neu
- [ ] "4-Layer-Pipeline" → "2-Regel-Culling + Filter"
- [ ] ScopeConfig Abschnitt → komplett entfernen
- [ ] ScopeResolver Abschnitt → komplett entfernen
- [ ] MapViewController Abschnitt → neue API dokumentieren
- [ ] Neuer Abschnitt: MapFilterState
- [ ] Neuer Abschnitt: Fokus-System (ohne Stack)
- [ ] Setup-Beispiel: neuen Flow zeigen
- [ ] Exaggeration-Logik: automatisch bei Fokus, nicht per Toggle

### 8.2 — file_structure.txt aktualisieren
- [ ] `scope/` Einträge → entfernen
- [ ] `scope_inspector/` Addon → entfernen
- [ ] `filter/` Einträge → hinzufügen
- [ ] MapViewController.tscn → hinzufügen
- [ ] MapFilterState.tscn → hinzufügen
- [ ] Kommentare anpassen

---

## Phase 9: Aufräumen

### 9.1 — Referenzen prüfen (globale Suche)
- [ ] `ScopeConfig` — alle Referenzen entfernen
- [ ] `ScopeResolver` — alle Referenzen entfernen
- [ ] `scope_resolver` — alle Referenzen entfernen
- [ ] `_current_scope` — alle Referenzen entfernen
- [ ] `resolve_scope` — alle Referenzen entfernen
- [ ] `fokus_tags` — alle Referenzen entfernen
- [ ] `visible_types` / `visible_tags` / `visible_zones` / `visible_belts` — Scope-bezogene entfernen
- [ ] `FocusState` — alle Referenzen entfernen (falls schon implementiert)
- [ ] `_focus_stack` — alle Referenzen entfernen (falls schon implementiert)

### 9.2 — Smoke Test
- [ ] Projekt in Godot öffnen — keine Parse-Fehler?
- [ ] MapTestScene starten — Bodies sichtbar?
- [ ] Rein-/Rauszoomen — Bodies erscheinen/verschwinden bei min_orbit_px?
- [ ] Viewport-Culling — Bodies außerhalb des Sichtfelds nicht gerendert?
- [ ] Fokus testen — Doppelklick → Exag an, Kinder sichtbar?
- [ ] Fokus lösen — Escape → Kamera zurück, Exag aus?
- [ ] Filter testen — Typen ausblenden → Bodies verschwinden?
- [ ] Filter + Fokus — Filter überlebt Fokus-Wechsel?

---

## Architekturänderung — Vorher / Nachher

```
GELÖSCHT:
  scope_config.gd              Datenklasse für Scope-Regeln
  scope_resolver.gd            Scope-Matching & Sichtbarkeit
  scope/ Ordner                Gesamter Ordner
  scopes/*.tres                Alle Scope-Dateien
  scope_inspector/ Addon       Editor-Plugin
  FocusState Klasse            Stack-Einträge
  _focus_stack                 Fokus-Stack

NEU:
  filter/
    map_filter_state.gd        Filter-State (Node, @export)
    MapFilterState.tscn         Scene für Editor-Konfiguration

UMGEBAUT:
  map_view_controller.gd       RefCounted → Node, @export
    - setup(scale, filter)       statt setup(resolver, scale)
    - is_body_visible()          min_orbit_px + filter statt Scope
    - set_focus() / clear_focus() statt resolve_scope()
    - calc_fit_scale_exp()       neu (für Zoom-to-fit bei Fokus)
    - get_marker_size()          war auf ScopeConfig, jetzt @export Dictionary
  MapViewController.tscn        Neu (Scene für Editor-Konfiguration)

UNVERÄNDERT:
  map_scale.gd                 Koordinaten & Zoom
  map_camera_controller.gd     Navigation & Input
  map_data_loader.gd           JSON-Loader
  Alle Renderer                body_marker, orbit_renderer, belt_renderer, etc.
  Sim Core                     sim_clock, solar_system_sim, body_def, etc.
```
