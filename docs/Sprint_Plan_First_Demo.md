# Sprint Plan — Demo-Vorbereitung

**Ziel:** Dienstag Hands-on-Präsentation
**Verfügbare Zeit:** 2 Sprints (Samstag + Sonntag)
**Scope:** Bugfixes, UI/UX-Polish — kein neuer Content nötig

---

## Sprint 1 — Samstag: Fundament & Flow

### 1.1 — MapClock Flicker-Fix (Bugfix, kritisch)

**Problem:** Beim Zoomen im MapClock-Modus flackert die Karte, weil `SolarSystemModel` permanent von GameClock aktualisiert wird und `_on_zoom_changed()` dann Live-Positionen liest statt MapClock-Positionen.

**Lösung (sauberer Weg):**
- `SolarSystemModel` vom GameClock-Tick disconnecten wenn MapClock nicht im Live-Mode ist
- Nur MapClock steuert das Model — eine einzige Zeitquelle, kein Race Condition
- MapClock.`enter_live_mode()` → Model reconnecten
- MapClock.`exit_live_mode()` → Model disconnecten, auf MapClock-Zeit einfrieren

**Betroffene Dateien:**
- `core/simulation/solar_system_model.gd`
- `map/components/map_clock.gd`
- `map/controllers/map_controller.gd`
- `map/controllers/solar_map_controller.gd`

**Akzeptanz:** Kein Flicker beim Zoomen/Pannen im Scrub-Mode. Wechsel Live↔Scrub unterbrechungsfrei.

---

### 1.2 — Panel-Flow & Sichtbarkeitsregeln (UX, kritisch)

**Ziel:** Klare, konsistente Regeln wann welches Panel sichtbar ist.

**Regeln:**

| Große Ansicht | Nav Panel | Info Panel | Almanac |
|---------------|-----------|------------|---------|
| Map           | ✅ optional | ✅ optional | ✅ optional |
| Planet View   | ❌ nie     | ✅ optional | ✅ optional |

- Map und Planet View sind exklusiv — immer genau eins aktiv
- Info Panel und Almanac sind exklusiv — nie gleichzeitig
- Nav Panel nur mit Map, nie mit Planet View oder Almanac

**Aufgabe:**
- Panel-State-Logik in `StartChartController` zentralisieren
- Übergänge definieren (z.B. Planet View öffnen → Nav Panel schließen)
- Hotkeys an die Regeln anpassen (I/L/N/Esc)
- Details im Sprint ausarbeiten

**Betroffene Dateien:**
- `game/star_chart/start_chart_controller.gd`

---

### 1.3 — Input-Konsolidierung (UX, mittel)

**Ziel:** Alle Maus- und Keyboard-Inputs sauber definiert und zentral verwaltet.

**Aufgabe:**
- Input-Map-Datei als Referenz nutzen
- Prüfen ob Input-Handling in einen zentralen Handler gehört oder ob die aktuelle Verteilung (MapTransform, InteractionManager, StartChartController) sinnvoll bleibt
- Aktuell verteilt auf: `MapTransform._input()/_process()`, `MapTransform._unhandled_input()`, `StartChartController._unhandled_input()`
- Details im Sprint ausarbeiten

**Betroffene Dateien:**
- `map/components/map_transform.gd`
- `map/components/interaction_manager.gd`
- `game/star_chart/start_chart_controller.gd`
- Ggf. neuer `InputHandler` oder Integration in bestehenden Manager

---

## Sprint 2 — Sonntag: Polish & Theming

### 2.1 — Map-Sichtbarkeitsfilter (Feature, hoch)

**Ziel:** Dropdown-Menü mit Filteroptionen um Kartenelemente gruppenweise ein-/auszuschalten.

**Filtergruppen (voraussichtlich):**
- Monde
- Gürtel (Belts)
- Orbits
- Kometen
- Zonen
- Ringe
- Strukturen (Stationen etc.)

**Aufgabe:**
- Dropdown/Popup-Menü mit Checkboxen pro Gruppe
- Anbindung an die bestehenden Feature-Flags (`has_orbits`, `has_belts`, `has_comets`, etc.) und ggf. Culling-Filter
- Platzierung im Map-UI (z.B. Toolbar oder Overlay)
- Details im Sprint ausarbeiten

**Betroffene Dateien:**
- Neue Szene + Script für das Filtermenü
- `map/controllers/map_controller.gd` (Feature-Flags zur Laufzeit togglen)
- `map/components/culling_manager.gd` (Typ-basiertes Filtern)

---

### 2.2 — UI-Theming (Polish, hoch für Demo)

**Ziel:** Einheitliches Erscheinungsbild über alle Panels via Godot Theme-Resource.

**Aufgabe:**
- Ein zentrales `Theme` erstellen mit Definitionen für:
  - Farben (Hintergrund, Text, Akzent, Dimmed)
  - Fonts & Größen (Titel, Body, Caption, Werte)
  - StyleBoxes (Panel-Hintergründe, Buttons, Separator)
- Theme am Root-Node setzen → propagiert an alle Kinder
- Bestehende lokale Overrides (LabelSettings, StyleBoxFlat in .tscn) schrittweise durch Theme-Referenzen ersetzen
- Details im Sprint ausarbeiten

**Neue Dateien:**
- `ui/theme/final_frontier.theme` (oder `.tres`)

**Betroffene Dateien:**
- Alle Panel-Szenen (Almanac, InfoPanel, NavPanel, ClockControl, MapOverlay)

---

### 2.3 — Hauptmenü (Feature, niedrig)

**Ziel:** Minimales Hauptmenü mit zwei Funktionen:

- **Quit** — Programm beenden
- **Shader-Overlay Toggle** — Effect-Shader ein-/ausschalten

**Aufgabe:**
- Menü-Szene erstellen (Overlay oder eigener Screen)
- Hotkey zum Öffnen (Esc? Oder eigene Taste?)
- Quit-Bestätigung optional — für Demo reicht direktes Beenden
- Details im Sprint ausarbeiten

**Neue Dateien:**
- Menü-Szene + Script (Ort tbd)

---

## Priorisierung

| # | Task | Prio | Demo-Impact |
|---|------|------|-------------|
| 1.1 | MapClock Flicker-Fix | 🔴 Kritisch | Hoch — sichtbarer Bug |
| 1.2 | Panel-Flow | 🔴 Kritisch | Hoch — kaputte UX fällt in Live-Demo sofort auf |
| 1.3 | Input-Konsolidierung | 🟡 Mittel | Mittel — betrifft Bedienbarkeit |
| 2.1 | Map-Sichtbarkeitsfilter | 🟡 Mittel | Hoch — zeigt Kartenfeatures in der Demo |
| 2.2 | UI-Theming | 🟡 Mittel | Hoch — visueller Gesamteindruck |
| 2.3 | Hauptmenü | 🟢 Nice-to-have | Niedrig — professioneller Eindruck |

Falls die Zeit knapp wird: **1.1 und 1.2 sind Pflicht**, 2.1 und 2.2 haben den größten Demo-Impact danach. 1.3 und 2.3 können notfalls reduziert werden.
