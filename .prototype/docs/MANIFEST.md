# Final Frontier — Architektur-Manifest

> Grundlegende Struktur und Fluss zwischen den Teilen. Kein Detail — jeder Teil wird separat spezifiziert.

---

## Vision

Final Frontier ist Sid Meier's Pirates in Space. Der Spieler ist der Kapitän eines Raumschiffs. Es gibt keine Außenansicht. Jede Information ist die Ausgabe eines Schiffssystems — Systemkarte, Sensorkarte, Laderaum, Mannschaft, Ausrüstung, Stationsdatenbanken. Der Bordcomputer ist das Fenster zur Welt.

Beim Andocken wechselt das Spiel in einen Stationsscreen. Stationen sind hierarchische Menüs: Orte innerhalb von Orten. Dort wird gesprochen, gehandelt und das Schiff modifiziert.

Zwei grundsätzliche Spielmodi: **Schiff** (alles über Bordcomputer-Screens) und **Station** (hierarchische Menü-Navigation).

---

## Sim Core

Deterministische Positionsengine. Berechnet die Position aller Himmelskörper zu jedem beliebigen Zeitpunkt. Fertig implementiert, Dokumentation ist bindend.

Zwei Komponenten:

- **SimulationClock** — Zentraler Taktgeber. Läuft in `_physics_process`, feuert `sim_clock_tick(sst_s)` mit der aktuellen Simulationszeit in Sekunden seit t₀. Zeitbeschleunigung über `time_scale`. Läuft nie rückwärts. Eigenes Kalendersystem (360 Tage, 12 Monate).
- **SolarSystemModel** — Single State of Truth für alle Positionen. Hört auf `sim_clock_tick`, berechnet topologisch sortiert alle Körper (Eltern vor Kindern). Feuert `simulation_updated` an Konsumenten.

Zwei Abfragemodi:

- **Live-Zustand** — Aktuelle Positionen, getrieben durch die Clock. Der Normalfall.
- **Beliebiger Zeitpunkt** — Positionen einzelner oder mehrerer Körper zu einem frei gewählten Zeitpunkt, ohne die Clock zu verstellen. Die Sim ist eine reine Funktion von Zeit → Position. Das ist die Grundlage für Time Scrubbing, Routenvorausberechnung, Transferplanung und jede andere Komponente, die in die Zukunft oder Vergangenheit schauen muss.

Datengrundlage: Vier JSON-Dateien (Bodies, Structs, Belts, Zones), geladen über `CoreDataLoader` bzw. `MapDataLoader`. Format in eigener Spec definiert.

Verantwortungsgrenze: Der Core liefert ausschließlich Zeit und Positionen. Kamera, Koordinatentransformation, Rendering, Sichtbarkeit und Spiellogik liegen bei den Konsumenten.

---

## Map Views

Interaktive Visualisierungen des Simulationszustands. Jeder View ist ein eigener Screen des Bordcomputers mit eigenem Zweck, eigenen Regeln und eigenem Zoombereich. Jeder View ist in sich geschlossen — er bringt alles mit was er braucht: Kamera, Koordinatentransformation, Rendering, Sichtbarkeit. Einzelteile werden als eigene Klassen gebaut, nicht als eine monolithische View-Klasse. Gemeinsame Teile werden bei Bedarf extrahiert, wenn ein zweiter View sie braucht.

Ein View ist vorerst angedacht:

- **Solar Map** — Strategische Systemübersicht. Freies Erkunden, extremer Zoombereich (1 px = 1.000 km bis 1 px = 10¹⁰ km). Zeigt Körper, Orbits, Belts, Strukturen. Automatisches Ein-/Ausblenden von Bodies, die beim Zoomen zu nah an ihren Parent rücken. Datenquelle ist die vollständige Sim-Datenbank. Dient Planung, Navigation und Orientierung. Wird zuerst gebaut, eigene Spec vorhanden.

---

## Datenfluss

```
SimClock ──tick──► SolarSystemModel ──simulation_updated──► View
                        ▲                                     │
                        │ query(bodies, time)                 │
                        └─────────────────────────────────────┘
```

Die Sim treibt den Zustand. Der View konsumiert ihn — live oder per Zeitpunkt-Abfrage. Koordinatentransformation, Rendering und Kamera liegen beim View selbst, aufgeteilt in eigenständige Klassen.
