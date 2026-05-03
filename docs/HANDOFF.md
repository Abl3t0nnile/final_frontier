# Handoff: Final Frontier 2D-PoC → 3D-Folgeprojekt

Dieses Dokument bündelt, was vom 2D-Proof-of-Concept (Tag `v1.0-poc`) in eine 3D-Neuauflage übernommen werden kann, was wegfällt, und welche Designfragen vor dem Neubau zu klären sind.

## 1. Status & Rahmen

- **PoC-Umfang:** Interaktive 2D-Karte des Sonnensystems mit Kepler-Bahnen, Body-Detailansicht, Almanach-Wiki, Planet-Viewer. Feature-complete, keine bekannten großen Bugs.
- **Warum kein Refactor:** Die Map-Schicht ist konsequent 2D (Node2D, Area2D, `_draw()`, pixel-basierte Pseudo-Kamera). Eine 3D-Migration würde rund 70% des Map-Codes ersetzen — ein sauberer Schnitt zwischen wiederverwendbaren `core/`-Modulen und neuem Rendering ist effizienter als ein inkrementeller Umbau.

## 2. Übernehmbare Module

Diese sind bewusst von Map-Rendering und Kamera entkoppelt und tragen direkt in ein 3D-Projekt.

### Simulation & Daten (Übernahme: ~95%)
- `core/simulation/sim_clock.gd` — `SimClock`, Zeit/Tick-System mit Pause, Reverse, Time-Scale.
- `core/simulation/solar_system_model.gd` — Topologisch sortierte Update-Reihenfolge, parent-relative Positionsberechnung. Mechanische Anpassung: `Vector2 → Vector3` durchziehen.
- `core/objects/data_loader.gd`, `game_object.gd`, `game_object_registry.gd`, `components/*` — Datenmodell ist render-unabhängig.
- `core/definitions/body_def.gd`, `*motion_def.gd` — `BodyDef`, `CircularMotionDef`, `Kepler2DMotionDef`, `LagrangeMotionDef`, `FixedMotionDef`. Anpassung: Kepler braucht `inclination_rad` + `longitude_of_ascending_node_rad` (RAAN); für Achsenneigung neue Felder `axial_tilt_rad`, `rotation_period_s` in `BodyDef`.
- `core/math/space_math.gd` — Kepler-Solver, Hohmann-Transfer, AU/km/px-Konvertierungen, physikalische Körperberechnungen (Masse, Dichte, Fluchtgeschwindigkeit etc.). Anpassung: `kepler_to_cartesian()` und `sample_kepler*_position()` auf Vector3 mit zwei zusätzlichen Rotationen (Inklination um X, RAAN um Z).
- `core/autoload/body_textures.gd` — Texture-Lookup für Körper.

### Daten
- `data/solar_system/solar_system_data.json` — Bodies inkl. Kepler-Elemente. Erweitern um Inklination + RAAN aus NASA-Daten.
- `data/solar_system/belt_data.json`, `ring_data.json`, `zone_data.json` — übernehmbar; Belts/Ringe haben bei genauerer Modellierung selbst Inklinationsstreuung.
- `data/almanach/` — komplett übernehmbar.
- `data/configs/map_config.gd` — Konzept übernehmbar, Werte je nach 3D-Kamera neu zu kalibrieren.

### UI & Inhalt (komplett unabhängig vom Map-Rendering)
- `game/almanac/` — Wiki-System mit dynamischem Layout.
- `ui/panels/info/` — InfoPanel (Body-Detailansicht).
- `ui/components/` — `UnitValueDisplay`, `BodyLinkDisplay`, `ThemedIcon`.
- `game/main_menu/`, `game/start_screen/`, `game/planet_view/` — eigenständige Szenen, von der Karte entkoppelt.

### Assets
- Themes, Fonts, Cursor, Icons, Body-Texturen.
- Shader für Planet-View.

## 3. Wegfallend

Diese Module sind zu eng an 2D-Konzepte gebunden — Neuschrieb gegen idiomatische 3D-Patterns ist sinnvoller als ein Übersetzungsversuch.

- `map/` (~2700 Zeilen) — alles 2D-spezifisch:
  - `map_transform.gd` — Pseudo-Kamera (`WorldRoot.position = -cam_pos + vp/2`, `km_per_px`-Skalierung). In 3D ersetzt durch echte `Camera3D` (orthographisch oder perspektivisch).
  - `markers/map_marker.gd` (Area2D, `_draw()`-Selection-Ring) → Area3D, Mesh-basierte Selection-Visualisierung.
  - `renderers/orbit_renderer.gd` (`draw_arc` + `draw_set_transform`) → ImmediateMesh `LINE_STRIP` mit 3D-Rotation.
  - `renderers/grid_renderer.gd` → 3D-Linien in der Ekliptik.
  - `renderers/belt_renderer.gd` (MultiMeshInstance2D) → MultiMeshInstance3D.
  - `renderers/zone_renderer.gd` (MeshInstance2D) → MeshInstance3D, Hill-Sphären als echte Sphären.
  - `components/culling_manager.gd` — pixel-basiertes Proximity-Culling, in 3D via `Camera3D.unproject_position()`.
  - `controllers/*`, übrige `components/*` — Verkabelung, in 3D neu zu strukturieren.
- `game/star_chart/solar_map.gd`, `map_overlay.gd` — Fassade über `map/`.

## 4. Designfragen für das 3D-Projekt

Diese Entscheidungen sind im PoC implizit (durch 2D) getroffen; im 3D-Projekt müssen sie bewusst geklärt werden.

### Kamera
- **Orthographisch oder perspektivisch?** Orthographisch erhält die Karten-Ästhetik (Top-Down + leichte Neigung), `km_per_px` übersetzt sich in `orthographic_size`. Perspektivisch gibt echtes Raumgefühl, aber Marker-Größen, Zoom und Distanz-Wahrnehmung müssen neu gedacht werden.
- **Steuerung:** Orbit-Kamera mit Pivot, Yaw + Pitch + Distanz. Maus-Drag wird Rotation statt Pan. Pinch-Zoom auf Distanz, nicht auf Skalierung.

### Skalierung & Präzision
- Sonnensystem: ~10¹⁰ km. Float32 in 3D wird bei direkten km-Werten unpräzise (Wobble, Z-Fighting).
- Optionen:
  - **Welt-Einheit ≠ km** (z. B. 1 unit = 1 AU oder = 100 000 km). Skalierung im Renderer, Sim rechnet weiter in km.
  - **Floating-Origin**: Welt wird relativ zur Kamera positioniert.
- Empfehlung: Welt-Einheit-Skalierung als simpler Erstwurf, Floating-Origin später nur falls nötig.

### Marker-Repräsentation
- 2D: pixel-genaue Größen via `set_size_px()`. In 3D mit perspektivischer Kamera nicht direkt übersetzbar.
- Optionen: Billboard-Sprites mit Distance-Scaling, kleine Sphären mit Outline-Shader, oder reine Screen-Space-Overlays über `unproject_position()`.

### Inklination und Bezugsebene
- Welche Ebene ist „flach"? Ekliptik (Erd-Bahn-Ebene, astronomischer Standard) oder invariante Ebene des Sonnensystems? Empfehlung: Ekliptik, da JSON-Daten und Almanach darauf verweisen.
- Mond-Bahnen sind zur Bahnebene ihres Mutterkörpers geneigt — die Hierarchie (`parent_id` + Inklination) muss konsistent bleiben.
- Lagrange-Punkte: liegen in der Bahnebene des Sekundärkörpers, nicht der Ekliptik. Berechnung in `solar_system_model.gd:_calculate_lagrange_position()` muss diese Rotation mitführen.

## 5. Lessons Learned aus dem PoC

- **`core/` sauber von Rendering trennen** war die wichtigste Architekturentscheidung — sie macht diesen Handoff überhaupt erst möglich.
- **Topologische Update-Reihenfolge** (`SolarSystemModel._build_update_order()`) ist robust und sollte beibehalten werden.
- **MapClock vs. SimClock** als getrennte Taktquellen für Live- und Scrub-Modus hat sich bewährt. Konzept übernehmen.
- **Hover/Select/Pin-Zustandsmaschine** mit Priority-basiertem Proximity-Culling funktioniert gut — die Logik ist übertragbar, nur die Distanz-Metrik wird zu Screen-Space-Distanz im 3D-Projekt.
- **Pixel-basierte Marker-Größen + zoom-abhängige Schwellen** sind bequem, aber in 3D nicht direkt übersetzbar — früh entscheiden.
- **Trackpad-Gesten** (Pan, Pinch) auf macOS: `InputEventPanGesture` und `InputEventMagnifyGesture` sind brauchbar; in 3D anders zu interpretieren (Pan → Orbit, Pinch → Distanz).
- **JSON-Daten + DataLoader** statt `.tres`-Resources hat sich für die Body-Definitionen bewährt — leichter editierbar, gut versionierbar.

## 6. Empfehlung für den Start

1. Neues Godot-Projekt anlegen, `core/`, `data/`, `ui/components/`, `game/almanac/`, Almanach-Daten und Themes übernehmen.
2. `Vector2 → Vector3` in `core/simulation/` und `core/math/` als erster Commit ohne Renderer.
3. Kepler-Daten um Inklination und RAAN ergänzen (`solar_system_data.json`, `Kepler2DMotionDef` → `Kepler3DMotionDef` oder gleicher Name mit erweiterten Feldern).
4. Minimaler 3D-Renderer: Sonne + Planeten als Kugeln, Orbits als `ImmediateMesh`-Linien, orthographische Kamera. Kein Belt, keine Zonen, kein Culling — erst die Bahnen sichtbar machen.
5. Schrittweise erweitern: Orbit-Kamera, Selektion, Almanach-Anbindung, Belts, Zones.
