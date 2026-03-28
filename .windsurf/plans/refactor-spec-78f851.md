# Refactor Specification Plan

## Ziel
Erstellung einer umfassenden Refactor-Spec basierend auf den gesammelten Ideen, die alle Klassen mit API, Abhängigkeiten und Datenfluss definiert.

## Vorgehen

### Phase 1: Spec-Struktur aufbauen
1. **Übersicht** - Architektur-Diagramm und Design-Prinzipien
2. **Core Layer** - Zeit-System, Math-Bibliothek, Daten-Management
3. **Entity Layer** - GameObject-System mit Hybrid-Daten
4. **Map Layer** - Modulares Map-System mit Controllern
5. **Rendering Layer** - Hybrid Rendering (Shader + CPU)
6. **UI Layer** - Integration und Datenfluss

### Phase 2: Klassen-Stubs definieren
Für jede Klasse:
- **Klassenname** und Vererbung
- **Public API** (Methods, Properties, Signals)
- **Dependencies** (welche Klassen werden benötigt)
- **Datenfluss** (wie Daten durchfließen)
- **Kurzbeschreibung** der Funktion

### Phase 3: Design-Entscheidungen dokumentieren
- Zeit-System (BaseClock → SimClock/MapClock)
- GameObject-Registry mit Lazy Loading
- Hybrid Rendering (Shader vs CPU)
- Orbit-Integration in MapMarker
- SpaceMath für Precision-Berechnungen

### Phase 4: Implementierungs-Reihenfolge
1. Core-Klassen (BaseClock, SpaceMath)
2. GameObject-System
3. Map-Komponenten
4. Rendering-System
5. UI-Integration

## Phase 1: Spec-Struktur

### 1. Übersicht & Architektur
```
[Architecture Diagram]
Design Principles:
- Separation of Concerns
- Hybrid Data Management
- Modular Map System
- Performance by Design
```

### 2. Core Layer Spec
- BaseClock
- SimClock
- MapClock
- SpaceMath
- GameObjectRegistry
- DataLoader (JSON + .tres)

### 3. Entity Layer Spec
- GameObject
- GameDataComponent
- ExplorationComponent
- TradingComponent
- MissionComponent

### 4. Map Layer Spec
- MapController (modular)
- SolarMapController
- MiniMapController
- MapTransform
- MapMarker (mit Orbit)
- Component Manager (Entity, Culling, Interaction)

### 5. Rendering Layer Spec
- ShaderRenderer (Grid, Zone, Belt)
- MapMarkerRenderer (CPU)
- OrbitRenderer (CPU, integriert)

### 6. UI Layer Spec
- MainDisplay
- InfoPanel
- DataFlow UI ↔ Map ↔ GameObject

## Phase 2: Klassen-Template

```gdscript
## ClassName
**Erweitert**: BaseType
**Zweck**: Kurze Beschreibung der Verantwortung

### Public API
```gdscript
# Properties
var property: Type

# Signals
signal signal_name(params)

# Methods
func method_name(params) -> ReturnType
```

### Dependencies
- Benötigt: DependencyClass1, DependencyClass2
- Wird verwendet von: UsingClass1, UsingClass2

### Datenfluss
```
Input → Processing → Output
```

### Implementierungsdetails
- Wichtige Überlegungen
- Performance-Anmerkungen
- Testing-Überlegungen
```

## Phase 3: Design-Entscheidungen

### Zeit-System
- BaseClock als abstrakte Basisklasse
- SimClock für Spielzeit (nur vorwärts)
- MapClock für Kartenzeit (vor/zurück)

### GameObject-System
- Zentrale Registry für alle Objekte
- BodyDef immer geladen, GameData lazy
- Komponenten-basiert für Gameplay-Features

### Rendering-Strategie
- Shader für Massenelemente (Grid, Zone, Belt)
- CPU für interaktive Elemente (Marker, Orbit)
- Orbit als Child von MapMarker

### Math-Bibliothek
- SpaceMath für alle Berechnungen
- Precision-Methoden für Wobble-Fix
- Zentral für Konsistenz

## Phase 4: Implementierungs-Plan

### Schritt 1: Foundation
1. BaseClock implementieren
2. SpaceMath mit Grundfunktionen
3. GameObjectRegistry anlegen

### Schritt 2: Entity System
1. GameObject Klasse
2. GameDataComponent Basisklasse
3. Spezielle Components (Trading, etc.)

### Schritt 3: Map Foundation
1. MapTransform überarbeiten
2. MapMarker mit Orbit-Integration
3. Component Manager

### Schritt 4: Rendering
1. Shader für Grid, Zone, Belt
2. CPU Rendering für Marker/Orbit
3. Wobble-Fix implementieren

### Schritt 5: Integration
1. MapController modularisieren
2. UI an neues System anbinden
3. Tests und Performance-Checks

## Nächste Aktion
Spec-Datei `/docs/REFACTOR_SPEC.md` erstellen mit allen Klassen-Stubs und API-Definitionen.
