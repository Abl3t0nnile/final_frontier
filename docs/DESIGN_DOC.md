# Final Frontier - Design Document

## Schichten

1. Sim Core
2. Map Toolkit
3. Map Views
4. Raumschiffe
5. Crew
6. Raumhäfen

## Simulation Core

Der SimCore ist eine deterministische Engine, welche die Positionen der simulierten Körper zu einer gegebenen Zeit berechnet. Der Core ist für die Positionierung aller Objekte auf orbitalen Bahnen zuständig.

### Simulation Clock

Die SimClock ist der zentrale Taktgeber der Simulation. Ist sie aktiv, feuert sie in jedem physics_process einen tick mit der aktuellen SST (SolarStandardTime). Diese fortlaufende Zeitvariable liefert die Zeit in vergangenen Sekunden seit t_0. Zeitbeschleunigung läuft über größere Zeitsprünge pro tick. Diese Uhr läuft niemals rückwärts.

### Solar System Model

Die SolarSystemSim ist der single state of truth für die Position aller orbitalen Körper. Sie ist direkt an die SimClock gebunden und aktuallisisert die Position aller Objekte bei jedem tick der Uhr. Die Sim stellt außerdem Funktionen zur Berechnung eines oder mehrerer Körper zu einem beliebigen Zeitpunkt. Diese Funktion bietet die Grundlage für Time Scrubbing innerhalb der Map Views.

## Map Toolkit

Das MapToolkit stellt Rendering Primitives zur Darstellung aller relevanten Gameplay Objekte zur Verfügung. Es stellt eine Mathe Engine, mit der ein View die Echtweltposition eines Objektes skaliert darstellen kann. Außerdem bietet es eine konfigurierbarke Kamera incl. Input Handling über Maus, Trackpad und Tastatur. Eine MapClock zum Handling einer MapTime (Time Scrubbing) ist ebenfalls Teil des Toolkits.

## Map Views

Ein Mapview ist eine interaktive Visualisierung des Simulationszustandes. Je nach View kann die Art der Darstellung stark abweichen. Ein MapView nutzt das MapToolkit um die Objekte des SolarSystemModel für den User interpretierbar zu machen.