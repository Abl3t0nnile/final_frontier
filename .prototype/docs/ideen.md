# Ideen & Lücken

## Offene Fragen

- [ ]

## Gesehene Probleme

- [ ]

## Verbesserungsideen

- [ ] Orbit-Rendering vereinfachen: Immer über den Body steuern
  - **Aktuell**: OrbitRenderer als eigenständige Node, getrennt vom Marker
  - **Neu**: Orbit als Teil des MapMarker oder als Child-Node des Markers
  - **Logik**: Kein Orbit ohne Body, aber Body ohne Orbit möglich
  - **Vorteile**:
    - Weniger separate Objekte im Scene Tree
    - Automatische Synchronisation (Body-Position = Orbit-Zentrum)
    - Einfacheres State Management (selected/highlighted für beide)
    - Weniger komplexe Parent-Child Logik im MapController
- [ ] Wobble-Effekt bei hohem Zoom beheben: Float-Precision Problem
  - **Problem**: Body wobbelt auf Orbit bei nahem Zoom (float rounding errors)
  - **Lösung**: Screen-Position des Bodies an Orbit-Linie ausrichten
  - **Implementierung**:
    - Orbit berechnet exakte Pixel-Position
    - Body wird auf diese Position "gesnapped"
    - Nur bei Zoom-Level über Schwellenwert aktiv
  - **Alternative**: Double precision für kritische Berechnungen

## Fehlende Definitionen

- [ ]

## Architektur-Ideen

- [ ] Zeit-System überarbeiten: Allgemeine Clock-Basisklasse mit API für Zeit-Management
  - Basisklasse: `BaseClock` mit Zeit-Delta-Addition und Time-Travel API
  - `SimClock`: Erbt von BaseClock, aber ohne Rückspulen-Möglichkeit (nur vorwärts)
  - `MapClock`: Erbt von BaseClock, kann vor- und zurückspulen für Sternenkarte
  - `SolarSystemModel.get_body_position_at_time()` wird von MapClock genutzt
- [ ] Zentrale Math-Klasse für Berechnungen: `SpaceMath` oder `OrbitalMath`
  - Kepler-Berechnungen (Position, Geschwindigkeit, Orbital-Elemente)
  - Koordinatentransformationen (km ↔ px, screen ↔ world, spherical ↔ cartesian)
  - Skalierungen und Interpolationen (LOD, smooth transitions)
  - Kurslinien-Berechnungen (Hohmann-Transfer, porkchop plots, flight path angles)
  - Wiederverwendbar für: Sim Core, Map Transform, UI Data Panels, zukünftige Kurslinien-Renderer
  - **Precision-Methoden**: `km_to_px_precise()`, `px_to_km_precise()` für Wobble-Fix
- [ ] Daten-Strategie überarbeiten: Trennung von statischen und game-design Daten
  - **Himmelskörper**: JSON für klar definierte, seltener ändernde Daten (realistisch)
  - **Structs/Game Objects**: .tres Resources für game-design-spezifische, oft ändernde Daten
  - **Editor-Tool**: Zukünftiges Tool zum Erstellen und Tunen von Structs als Godot Editor Plugin
  - **Hybrid-Laden**: CoreDataLoader lädt JSON, StructDataLoader lädt .tres aus Ordnerstruktur
- [ ] Gameplay-Daten-Schicht einführen: `GameDataComponent` oder `EntityData`
  - **Trennung klar machen**: Visualisierung (BodyDef) ≠ Gameplay-Daten
  - **GameData**: Infotexte, erkundbare Orte, Handelswaren, Missionen, Reputationen
  - **Komponenten-basiert**: Jedes Objekt kann verschiedene Gameplay-Komponenten haben
    - `ExplorationComponent` - Orte, Scans, Entdeckungen
    - `TradingComponent` - Waren, Preise, Kapazitäten
    - `MissionComponent` - Available missions, requirements
  - **Lazy Loading**: Gameplay-Daten nur bei Bedarf laden (z.B. wenn Station ausgewählt)
- [ ] Alternative: Zentrales GameObject-System mit vereinigten Daten
  - **GameObject**: Kombiniert BodyDef + Gameplay-Daten in einer Klasse
  - **GameObjectRegistry**: Zentraler Cache für alle GameObjects
  - **API-Zugriff**: Statt lazy loading, alles über `GameObjectRegistry.get(id)` abrufbar
  - **Vorteile**: Einfacherer Zugriff, zentrales Caching, konsistente Daten
  - **Nachteile**: Mehr RAM, längere Ladezeit, engere Kopplung
- [ ] **Entschiedene Architektur**: Hybrid-GameObject-System
  - **Basis**: Alle 350-400 Sonnesystem-Objekte als GameObjects mit BodyDef + API
  - **Lazy Loading**: Gameplay-Daten on-demand (Trading, Missionen, etc.)
  - **Skalierbarkeit**: Asteroidenfelder und andere große Mengen via lazy loading
  - **GameObject.get_game_data()**: Zentraler Zugriff mit automatischem Laden

## UI-Integration

- [ ]

## Performance-Überlegungen

- [ ] **Entschiedene Strategie**: Hybrid Rendering System
  - **Shader-basiert**: GridRenderer, ZoneRenderer, BeltRenderer
    - GPU-beschleunigt, perfekt für statische/prozedurale Elemente
    - Grid: Konzentrische Ringe via Fragment Shader
    - Zones: Semi-transparente Flächen mit uniforms
    - Belts: Instanced Point Clouds im Shader
  - **CPU-basiert**: MapMarker + OrbitRenderer (vereint)
    - Body: Sprite2D oder _draw() für Icons
    - Orbit: _draw() abhängig vom Marker-Zustand
    - Vorteile: Einfache UI-Integration, hover states, selection
  - **Kopplung**: Orbit sichtbar nur wenn Marker sichtbar
  - **Performance**: Shader für Massenelemente, CPU für Interaktion
