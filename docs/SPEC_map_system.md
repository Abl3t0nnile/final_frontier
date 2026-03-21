# Map System — Spezifikation

> Stand: 2026-03-20

---
## Inhaltsverzeichnis

- [Kapitel 1 — Überblick und Architektur-Prinzipien](#kapitel-1--überblick-und-architektur-prinzipien)
- [Kapitel 2 — Komponenten-Toolkit (MapScale, ScopeConfig, ScopeResolver)](#kapitel-2--komponenten-toolkit-mapscale-scopeconfig-scoperesolver)
- [Kapitel 3 — BodyMarker](#kapitel-3--bodymarker)
- [Kapitel 4 — BodyModel (Stub)](#kapitel-4--bodymodel-stub)
- [Kapitel 5 — OrbitRenderer](#kapitel-5--orbitrenderer)
- [Kapitel 6 — Flächige Rendering-Primitive (Überblick)](#kapitel-6--flächige-rendering-primitive-überblick)
- [Kapitel 7 — BeltRenderer](#kapitel-7--beltrenderer)
- [Kapitel 8 — ZoneRenderer](#kapitel-8--zonerenderer)

Weiterführende Dokumente:

- [StarChart — Spezifikation]
  - [Kapitel 9 — StarChart: Szenenstruktur und Initialisierung]
  - [Kapitel 10 — StarChart: Chart-Zeit und Moduswechsel]
  - [Kapitel 11 — StarChart: Update-Zyklus]
  - [Kapitel 12 — StarChart: Skalierung und logarithmische Transformation]
  - [Kapitel 13 — StarChart: Kamera]
  - [Kapitel 14 — StarChart: Input-Handling (Maus + Tastatur)]
  - [Kapitel 15 — StarChart: GridRenderer und HUD]
  - [Kapitel 16 — StarChart: Signale]
  - [Kapitel 17 — StarChart: Randfälle und Fehlerzustände]
  - [Kapitel 18 — StarChart: Export-Variablen Übersicht]
  - [Kapitel 19 — Einbettung: StarChartScreen (Schnittstelle)]
  - [Kapitel 20 — Weitere Views (Ausblick)]
  - [Kapitel 21 — Anforderungen an bestehende Systeme]
  - [Kapitel 22 — Offene Punkte]

---

## Kapitel 1 — Überblick und Architektur-Prinzipien

### 1.1 Zweck

Das Map System ist die zentrale visuelle Schnittstelle des Spiels. Es dient Orientierung, Kursplanung, Navigation und taktischer Entscheidung. Alle Map-Ansichten sind diegetisch — sie sind Cockpit-Displays, keine abstrakte Spieler-Übersicht. Was der Spieler sieht ist immer die Ausgabe eines Instruments.

Die Karte ist gleichzeitig der Spielbildschirm. Es gibt keinen separaten Ort an dem die "Realität" des Spiels dargestellt wird — die Map-Views sind dieser Ort. Objekte im Nahbereich (Stationen, Monde) werden maßstabsgetreu mit physischen Dimensionen und CollisionShapes dargestellt, nicht nur als Symbole.

### 1.2 Ansichten

Das System besteht aus drei eigenständigen Ansichten mit unterschiedlichem Zweck:

| Ansicht | Zweck | Status |
|---|---|---|
| `StarChart` | Strategische Übersicht, Kursplanung | Eigene Spec (`SPEC_star_chart.md`) |
| `SensorDisplay` | Lokale Lage, Sensor-Kontakte, Signalverzögerung | Spätere Spec |
| `TacticalDisplay` | Nahkampf, Manöverplanung | Spätere Spec |

Die Ansichten sind vollständig eigenständige Szenen. Es gibt keine gemeinsame Basisklasse — stattdessen teilen sie sich ein Toolkit aus wiederverwendbaren Komponenten (siehe Kapitel 2–6).

Jede Ansicht ist autark lauffähig. Sie kennt ihre Elternszene nicht und kommuniziert ausschließlich über Signale nach außen. Übergeordnete Szenen (z.B. `StarChartScreen`) verbinden sich mit diesen Signalen, die Ansicht selbst hat keine Abhängigkeiten nach oben.

### 1.3 Darstellungsarten

Das Toolkit stellt fünf verschiedene Rendering-Primitive bereit:

| Komponente | Darstellung | Charakter | Verwendung |
|---|---|---|---|
| `BodyMarker` | Symbolisch — Icon, Label, Farbe. Feste Pixelgröße, unabhängig vom Zoom. | Dumm | StarChart, Übersichtsfunktionen aller Views |
| `BodyModel` | Maßstabsgetreu — physischer Radius, CollisionShapes. Größe in km, skaliert mit Zoom. | Dumm | Nahbereich: TacticalDisplay, SensorDisplay |
| `OrbitRenderer` | Orbit-Linie — Bahnkurve eines Körpers. | Dumm | Alle Views |
| `BeltRenderer` | Prozedurale Punktwolke — Asteroidengürtel, Kuipergürtel, Trojaner, Planetenringe. | Dumm | Alle Views |
| `ZoneRenderer` | Halbtransparente Farbfläche — Strahlungsgürtel, Magnetosphären, Gravitationszonen. | Dumm | Alle Views |

"Dumm" bedeutet: Die Komponente empfängt fertige Daten von der View und stellt sie dar. Sie kennt weder die Skalierung noch den aktiven Darstellungsmodus noch ihren Kontext. Alle Entscheidungen über Position, Sichtbarkeit, Transformation und Größe trifft die View.

Ein Sim-Objekt kann mehrere Darstellungen gleichzeitig haben. Eine Station hat einen `BodyMarker` für die StarChart-Übersicht und ein `BodyModel` für den lokalen Raum im TacticalDisplay. Welche Darstellung aktiv ist, entscheidet die jeweilige View.

**Nicht Teil dieses Toolkits:** Schiffe und andere nicht-deterministische Gameplay-Objekte. Diese haben eigene Physik und Antriebssysteme und werden in einer separaten Game-Objects-Spec definiert. Die Map-Views werden Schnittstellen für deren Darstellung bereitstellen, aber die Objekte selbst gehören nicht zum Map-Toolkit.

### 1.4 Schichtenarchitektur

Jede Schicht kennt nur die Schichten unter ihr. Keine Schicht hat Abhängigkeiten nach oben.

```
Autoloads (extern, nicht Teil dieser Spec)
├── SimClock                    — Zeitgeber
└── SolarSystem                 — Positionen aller Körper

Toolkit (ansichtsagnostisch, wiederverwendbar)
├── MapScale                    — Skalierungsmathe (scale_exp → px_per_km)
├── ScopeConfig                 — Rendering-Kontext als Resource
├── ScopeResolver               — Scope-Auswahl und Sichtbarkeitslogik
├── BodyMarker                  — Symbolische Körper-Darstellung (Area2D-Szene)
├── BodyModel                   — Maßstabsgetreue Körper-Darstellung (Szene, spätere Spec)
├── OrbitRenderer               — Orbit-Linie (Node2D-Szene)
├── BeltRenderer               — Prozedurale Punktwolke: Gürtel, Trojaner, Ringe (Node2D-Szene)
└── ZoneRenderer               — Halbtransparente Farbfläche: Strahlung, Magnetosphären (Node2D-Szene)

Views (eigenständige Szenen, jeweils eigene Spec)
├── StarChart                   — SPEC_star_chart.md
├── SensorDisplay               — Spätere Spec
└── TacticalDisplay             — Spätere Spec

Einbettung (verbindet View mit Spielsystemen)
└── StarChartScreen             — Wrapper mit InfoPanel, NavPanel etc. (Teil der StarChart-Spec)
```

Die Autoloads (`SimClock`, `SolarSystem`) werden von den Views nur lesend abgefragt. Kein Map-System-Code schreibt auf die Simulation. Die Sim-API ist in `SPEC_sim_core.md` definiert.

### 1.5 Datenfluss-Prinzip

Alle Positionsdaten fließen in eine Richtung:

```
SolarSystem (Welt-km)
  → MapScale (km → px)
  → View (Transformation: linear oder log, Sichtbarkeit, Sizing)
  → BodyMarker / OrbitRenderer / ZoneRenderer (fertige Screen-Koordinaten)
```

Die Rendering-Primitive empfangen fertige Daten und stellen sie dar. Sie kennen weder die Skalierung noch den aktiven Darstellungsmodus.

Signale fließen in die entgegengesetzte Richtung (Beispiel am Fall StarChart):

```
BodyMarker (clicked / double_clicked)
  → View (verarbeitet, ändert internen Zustand)
  → Ausgehende Signale (body_focused, scope_changed etc.)
  → Einbettungsszene / andere Consumer (reagieren auf Signale)
```

Ausgehende Signale transportieren nur primitive Werte (IDs, Enums, Floats). Consumer holen sich Daten bei Bedarf über die Sim-API (`SolarSystem.get_body(id)` etc.), nicht über die Signale.

### 1.6 Koordinatensystem

Das gesamte Map System arbeitet mit zwei Koordinatenräumen:

| Raum | Einheit | Ursprung | Verwendung |
|---|---|---|---|
| Welt | km (`Vector2`) | Sonne = `(0, 0)` | SolarSystem-API, Positionsberechnungen |
| Screen | Pixel (`Vector2`) | Kamera-abhängig | Marker-Positionen, Orbit-Zeichnung, Klick-Detection |

Die Umrechnung Welt → Screen läuft über `MapScale.world_to_screen()` (lineare Basis) plus optionale logarithmische Transformation (View-intern). Die umgekehrte Richtung (`screen_to_world()`) wird für Zoom-Anker-Berechnungen benötigt.

### 1.7 Erweiterbarkeit

Neue Ansichten können jederzeit auf das bestehende Toolkit aufgesetzt werden ohne bestehenden Code zu verändern. `ScopeConfig`-Ressourcen und Rendering-Primitive sind ansichtsagnostisch.

Neue Gameplay-Systeme (Handel, Fraktionen, Missionen) integrieren sich über die Signal-Schnittstelle der Views und die Einbettungsszenen — sie berühren die Kartenlogik nicht.

---

## Kapitel 2 — Komponenten-Toolkit (MapScale, ScopeConfig, ScopeResolver)

Dieses Kapitel beschreibt die drei Nicht-Szenen-Komponenten des Toolkits. Sie kapseln reine Logik — Skalierungsmathe, Rendering-Kontext-Definitionen und Scope-Auswahl. Keine dieser Komponenten ist ein Node. Sie werden von der View instanziiert und gehalten.

Die Szenen-Komponenten (BodyMarker, BodyModel, OrbitRenderer, ZoneRenderer) werden in den Kapiteln 3–6 separat beschrieben.

---

### 2.1 MapScale

**Klasse:** `MapScale extends RefCounted`

Zustandsbehaftete Hilfsklasse. Kapselt die gesamte Skalierungsmathe und stellt Umrechnungsfunktionen in beide Richtungen bereit (Welt ↔ Screen). Wird von der View instanziiert und für die Lebensdauer der View gehalten.

MapScale kennt keine Regeln — kein Clamping, keine Min/Max-Grenzen, keine Darstellungsmodi. Sie rechnet nur um. Alle Entscheidungen über erlaubte Wertebereiche trifft die View.

Die logarithmische Transformation ist nicht Teil von MapScale — sie gehört in die View, da sie eine Darstellungsentscheidung ist, keine Skalierungsmathe. MapScale liefert die lineare Basis, auf die die View optional eine Log-Transformation aufsetzt (siehe `SPEC_star_chart.md` für die Implementierung in der StarChart).

#### 2.1.1 Kernkonzept

Die Skalierung basiert auf einem Exponenten. Jeder ganzzahlige Schritt verändert den Maßstab um Faktor 10.

```
scale_exp           → float (z.B. 5.0)
km_per_px           = 10 ^ scale_exp          (z.B. 100.000 km pro Pixel)
px_per_km           = 1.0 / km_per_px         (z.B. 0.00001 Pixel pro km)
```

Referenzwerte für die Orientierung:

| scale_exp | km_per_px | Was passt in 1920px Breite |
|---|---|---|
| 3.0 | 1.000 | 1,92 Mio km (Mond-System) |
| 4.0 | 10.000 | 19,2 Mio km (Mond-Orbit) |
| 5.0 | 100.000 | 192 Mio km (inneres System bis Mars) |
| 5.5 | ~316.000 | ~607 Mio km (bis Asteroidengürtel) |
| 6.0 | 1.000.000 | 1,92 Mrd km (bis Saturn) |
| 6.5 | ~3.160.000 | ~6 Mrd km (ganzes Hauptsystem) |
| 7.0 | 10.000.000 | 19,2 Mrd km (inkl. Kuipergürtel) |

#### 2.1.2 Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_scale_exp` | `float` | Aktueller Skalierungsexponent |
| `_px_per_km` | `float` | Abgeleitet: `1.0 / (10 ^ _scale_exp)`. Berechnet bei `set_scale_exp()`. |
| `_km_per_px` | `float` | Abgeleitet: `10 ^ _scale_exp`. Berechnet bei `set_scale_exp()`. |

Beide abgeleiteten Werte werden bei jedem `set_scale_exp()`-Aufruf einmalig neu berechnet, nicht bei jeder Abfrage. Die Berechnung (`pow()`, Division) passiert also einmal pro Zoom-Schritt, die Getter sind reine Feld-Rückgaben.

#### 2.1.3 Öffentliche API

```gdscript
# Zustand setzen
func set_scale_exp(exp: float) -> void
    # Setzt _scale_exp, berechnet _km_per_px und _px_per_km.
    # Kein Clamping — akzeptiert jeden float-Wert.

# Zustand abfragen
func get_scale_exp() -> float
func get_px_per_km() -> float
func get_km_per_px() -> float

# Umrechnung: Welt → Screen
func world_to_screen(world_km: Vector2) -> Vector2
    # Gibt world_km * _px_per_km zurück.
    # Rein lineare Multiplikation, keine Transformation.

func km_to_px(km: float) -> float
    # Gibt km * _px_per_km zurück.
    # Skalare Variante für Einzelwerte (z.B. Orbit-Radius → Pixel-Radius).

# Umrechnung: Screen → Welt
func screen_to_world(screen_px: Vector2) -> Vector2
    # Gibt screen_px * _km_per_px zurück.
    # Umkehrfunktion von world_to_screen().
    # Wird für Zoom-Anker-Berechnungen benötigt.

func px_to_km(px: float) -> float
    # Gibt px * _km_per_px zurück.
    # Skalare Umkehrfunktion von km_to_px().
```

#### 2.1.4 Verwendung

MapScale wird von jeder View einmal instanziiert und für deren gesamte Lebensdauer gehalten. Verschiedene Views können verschiedene MapScale-Instanzen mit unterschiedlichen `scale_exp`-Werten haben.

```
View._ready():
    _map_scale = MapScale.new()
    _map_scale.set_scale_exp(initial_scale_exp)

View._on_zoom():
    _map_scale.set_scale_exp(new_exp)
    # Alle Positionen neu berechnen...

View._update_marker_position(body_id, world_pos):
    marker.position = _map_scale.world_to_screen(world_pos)
```

---

### 2.2 ScopeConfig

**Klasse:** `ScopeConfig extends Resource`

Godot-Resource. Beschreibt einen Rendering-Kontext — was wird wie dargestellt, und wann gilt dieser Scope. ScopeConfigs werden als `.tres`-Dateien im Projekt gespeichert und dem ScopeResolver als geordnete Liste übergeben.

Ein ScopeConfig ist eine reine Daten-Definition. Es enthält keine Logik — die Auswertung liegt im ScopeResolver und in der View.

#### 2.2.1 Felder

```gdscript
# Identifikation
@export var scope_name: String
    # Anzeigename für HUD (ZoomDisplay) und Debug.
    # z.B. "Gesamtsystem", "Jovian System", "Mond-Nahbereich"

# ─── Bedingungen (wann gilt dieser Scope) ───

@export var zoom_min: float
@export var zoom_max: float
    # Der Scope matcht wenn scale_exp in [zoom_min, zoom_max] liegt.
    # Inklusive beider Grenzen.

@export var fokus_tags: Array[String]
    # Tags gegen die der fokussierte Körper gematcht wird.
    # OR-Logik: mindestens ein Tag des fokussierten Körpers muss enthalten sein.
    # Leeres Array = Scope gilt für alle Fokus-Körper (kein Fokus-Filter).

# ─── Darstellung ───

@export var distanz_modus: int
    # LINEAR (0) oder LOG (1).
    # Bestimmt die Standard-Darstellung. Der Spieler kann manuell überschreiben.
    # Die Interpretation dieses Feldes ist Sache der View.
    # Die StarChart nutzt es für ihre logarithmische Transformation
    # (siehe SPEC_star_chart.md). Andere Views können es ignorieren
    # oder anders interpretieren.

@export var exaggeration_faktor: float
    # Skalierungsfaktor für Enkel-Objekte im Log-Modus.
    # 1.0 = keine Exaggeration. Werte > 1.0 spreizen lokale Offsets auf.
    # Gilt für Marker-Positionen und Orbit-Linien der Enkel gleichermaßen.
    # Hat keine Wirkung auf ZoneRenderer (Zonen haben eigene Skalierungslogik).

@export var sichtbare_typen: Array[String]
    # Type-Filter für Body-Sichtbarkeit.
    # Ein Body ist type-sichtbar wenn sein type in dieser Liste enthalten ist.
    # Leeres Array = kein Type-Filter (alle Types sichtbar).
    # Beispiel: ["star", "planet", "dwarf"] zeigt nur Hauptkörper.

@export var sichtbare_tags: Array[String]
    # Tag-Filter für Body-Sichtbarkeit.
    # Ein Body ist tag-sichtbar wenn mindestens ein map_tag in dieser Liste enthalten ist (OR-Logik).
    # Leeres Array = kein Tag-Filter (alle Tags sichtbar).
    # Beispiel: ["jovian_system"] zeigt nur Körper im Jupiter-System.

@export var sichtbare_zonen: Array[String]
    # Zone-IDs die in diesem Scope sichtbar sind.
    # Referenziert Zonen über ihre eindeutige ID.
    # Leeres Array = alle Zonen sichtbar (kein Zonen-Filter).
    # Beispiel: ["asteroid_belt"] zeigt nur den Asteroidengürtel.

@export var min_orbit_px: float
    # Mindestradius eines Orbits in Pixeln.
    # Orbits deren Pixel-Radius unter diesem Wert liegt werden ausgeblendet.
    # Blendet sowohl den OrbitRenderer als auch den zugehörigen BodyMarker aus.
    # Verhindert visuellen Müll durch winzige, nicht erkennbare Orbit-Kreise.

@export var marker_sizes: Dictionary
    # Marker-Größen pro Body-Type in Pixeln.
    # Format: { "star": 32, "planet": 24, "dwarf": 18, "moon": 16, "struct": 12 }
    # Wird bei Scope-Wechsel auf alle sichtbaren Marker angewendet.
    # Wenn ein Type nicht enthalten ist: Konfigurationsfehler loggen, Fallback auf 8px.
```

#### 2.2.2 Matching-Regeln

**Fokus-Matching (`fokus_tags`):**

Der ScopeResolver prüft ob der aktuelle Fokus-Körper zu diesem Scope passt.

```
fokus_tags leer                      → Scope matcht jeden Fokus (oder keinen Fokus)
fokus_tags nicht leer                → Mindestens ein Tag des fokussierten Körpers
                                       muss in fokus_tags enthalten sein (OR-Logik)
Kein Körper fokussiert               → Nur Scopes mit leerem fokus_tags matchen
```

Beispiel: Jupiter hat die Tags `["outer_system", "jovian_system", "major_body"]`. Ein Scope mit `fokus_tags: ["jovian_system"]` matcht. Ein Scope mit `fokus_tags: ["terran_system"]` matcht nicht.

**Sichtbarkeits-Matching (`sichtbare_typen` + `sichtbare_tags`):**

Die beiden Filter werden mit AND verknüpft. Innerhalb jedes Filters gilt OR-Logik.

```
type_pass = sichtbare_typen leer  OR  body.type in sichtbare_typen
tag_pass  = sichtbare_tags leer   OR  mindestens ein body.map_tag in sichtbare_tags
sichtbar  = type_pass AND tag_pass
```

Beispiel — Scope "Jovian System":
```
sichtbare_typen: ["planet", "moon", "struct"]
sichtbare_tags:  ["jovian_system"]
```
- Jupiter (type=planet, tags enthält jovian_system): type ✓ tag ✓ → **sichtbar**
- Io (type=moon, tags enthält jovian_system): type ✓ tag ✓ → **sichtbar**
- Europa Gate Station (type=struct, tags enthält jovian_system): type ✓ tag ✓ → **sichtbar**
- Saturn (type=planet, tags enthält saturnian_system): type ✓ tag ✗ → **unsichtbar**
- Sonne (type=star): type ✗ → **unsichtbar**

#### 2.2.3 Scope-Konfigurationsrichtlinien

Die konkreten ScopeConfigs und ihre Bedingungen sind Game-Design und werden in einem separaten Dokument definiert. Die folgenden Richtlinien gelten für die Erstellung:

- Scopes müssen lückenlos den gesamten `scale_exp`-Bereich abdecken. Lücken führen zu Konfigurationsfehlern zur Laufzeit.
- Spezifischere Scopes (z.B. "Fokus auf Gasriesen") stehen in der Liste vor allgemeineren Scopes (z.B. "Kein Fokus, gesamtes System"). Erster Treffer gewinnt.
- Ein Catch-All-Scope mit `zoom_min = -INF`, `zoom_max = INF` und leeren `fokus_tags` am Ende der Liste verhindert No-Match-Fehler.

---

### 2.3 ScopeResolver

**Klasse:** `ScopeResolver extends RefCounted`

Reine Logik-Klasse. Erhält eine geordnete Liste von ScopeConfig-Ressourcen und beantwortet zwei Fragen:
1. **Welcher Scope ist aktiv?** — basierend auf aktuellem `scale_exp` und fokussiertem Körper.
2. **Ist ein bestimmter Body sichtbar?** — basierend auf dem aktiven Scope und der Orbit-Größe.

Der ScopeResolver hat keinen internen Cache. Er speichert nicht den letzten gültigen Scope — das ist Sache der View. Er verwaltet keine Pinned-Liste — auch das ist Sache der View.

#### 2.3.1 Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_scopes` | `Array[ScopeConfig]` | Geordnete Liste aller Scopes. Erster Treffer gewinnt. Gesetzt bei `setup()`. |

#### 2.3.2 Öffentliche API

```gdscript
func setup(scopes: Array[ScopeConfig]) -> void
    # Speichert die geordnete Scope-Liste.
    # Wird einmalig bei Initialisierung der View aufgerufen.
    # Die Reihenfolge bestimmt die Priorität: erster Treffer gewinnt.

func resolve(scale_exp: float, focused_body: BodyDef) -> ScopeConfig
    # Iteriert die Scope-Liste und gibt den ersten ScopeConfig zurück
    # dessen Bedingungen erfüllt sind.
    #
    # Match-Bedingungen (alle müssen zutreffen):
    #   1. scale_exp >= scope.zoom_min AND scale_exp <= scope.zoom_max
    #   2. scope.fokus_tags ist leer
    #      ODER focused_body ist null und scope.fokus_tags ist leer
    #      ODER mindestens ein Tag von focused_body.map_tags ist in scope.fokus_tags
    #
    # Gibt null zurück wenn kein Scope matcht.
    # Die View ist verantwortlich für das Fehler-Handling (loggen, letzten Scope beibehalten).

func is_body_visible(body: BodyDef, scope: ScopeConfig, orbit_px: float) -> bool
    # Prüft ob ein Körper im gegebenen Scope sichtbar ist.
    #
    # Prüft NICHT die Pinned-Liste — das muss die View vor dem Aufruf tun.
    # Die View-Logik ist:
    #   if is_pinned(body.id) → sichtbar
    #   else → is_body_visible(body, scope, orbit_px)
    #
    # Sichtbarkeits-Logik:
    #   type_pass  = scope.sichtbare_typen ist leer
    #                OR body.type in scope.sichtbare_typen
    #   tag_pass   = scope.sichtbare_tags ist leer
    #                OR mindestens ein body.map_tag in scope.sichtbare_tags
    #   orbit_pass = body hat keinen Orbit (fixed/lagrange/root)
    #                OR orbit_px >= scope.min_orbit_px
    #   return type_pass AND tag_pass AND orbit_pass
    #
    # orbit_px ist der Orbit-Radius in Pixeln zum aktuellen scale_exp.
    # Wird von der View berechnet: SolarSystem.get_body_orbit_radius_km(id) * px_per_km
    # Bei Bodies ohne Orbit (fixed motion, root bodies) wird orbit_px als 0.0 übergeben
    # und orbit_pass ist automatisch true.
```

#### 2.3.3 Resolve-Ablauf im Kontext der View

Der ScopeResolver wird von der View bei zwei Gelegenheiten aufgerufen:

1. **Bei Zoom-Änderung:** `scale_exp` hat sich geändert, der Scope könnte wechseln.
2. **Bei Fokus-Wechsel:** Ein anderer Körper ist fokussiert (oder Fokus wurde gelöst), die `fokus_tags` könnten einen anderen Scope matchen.

```
View._on_zoom_or_focus_changed():
    var new_scope = _scope_resolver.resolve(current_scale_exp, focused_body)

    if new_scope == null:
        push_error("Kein ScopeConfig matcht für scale_exp=%s, fokus=%s" % [...])
        return    # letzter Scope bleibt aktiv, keine Änderung

    if new_scope != _current_scope:
        _current_scope = new_scope
        _rebuild_active_bodies()    # Sichtbarkeit neu bewerten
        _apply_scope()              # Marker-Sizes, Linienstile, Zonen etc.
        scope_changed.emit(new_scope)
```

#### 2.3.4 Sichtbarkeits-Bewertung im Kontext der View

Die vollständige Sichtbarkeits-Prüfung für einen einzelnen Body, wie sie die View durchführt:

```
func _is_body_active(body: BodyDef) -> bool:
    # 1. Pinned → immer sichtbar
    if _pinned_bodies.has(body.id):
        return true

    # 2. Orbit-Radius in Pixel berechnen
    var orbit_radius_km = SolarSystem.get_body_orbit_radius_km(body.id)
    var orbit_px = _map_scale.km_to_px(orbit_radius_km)

    # 3. ScopeResolver entscheidet
    return _scope_resolver.is_body_visible(body, _current_scope, orbit_px)
```

Die View iteriert diese Prüfung bei jedem Scope-Wechsel über alle Bodies und baut daraus ihre aktive Body-Liste neu auf.

## Kapitel 3 — BodyMarker

**Klasse/Szene:** `BodyMarker extends Area2D`

Symbolische Darstellung eines Himmelskörpers auf der Karte. Ein Marker pro simuliertem Body. Der BodyMarker ist ein dummes Rendering-Primitiv — er empfängt fertige Daten von der View und stellt sie dar. Er kennt weder die Skalierung, noch den aktiven Scope, noch seinen Darstellungsmodus. Alle Entscheidungen über Position, Sichtbarkeit und Größe trifft die View.

Der BodyMarker hat eine Pixelgröße die nicht kontinuierlich mit dem Zoom skaliert, sondern stufenweise durch den aktiven Scope bestimmt wird. Jeder `ScopeConfig` definiert ein eigenes `marker_sizes`-Dictionary (siehe Kapitel 2.2.1), das pro Body-Type eine Pixelgröße vorgibt. Beim Scope-Wechsel — ausgelöst durch Zoom oder Fokus-Änderung — wendet die View die neuen Größen auf alle aktiven Marker an. Innerhalb eines Scopes bleibt die Pixelgröße konstant, unabhängig vom exakten `scale_exp`. Das unterscheidet ihn vom `BodyModel` (Kapitel 4), das maßstabsgetreu in km dimensioniert ist und kontinuierlich mit dem Zoom skaliert.

---

### 3.1 Szenenstruktur

```
BodyMarker (Area2D)
├── Icon (Sprite2D)              ← Symboldarstellung, zentriert
├── Label (Label)                ← Anzeigename, unterhalb des Icons
└── ClickShape (CollisionShape2D) ← Klick-Detection, etwas größer als Icon
```

Alle Kind-Nodes sind fest in der Szene verdrahtet. Der BodyMarker wird als PackedScene instanziiert und via `setup()` konfiguriert.

---

### 3.2 Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_body_id` | `String` | ID des zugehörigen Bodies. Gesetzt bei `setup()`, danach unveränderlich. |
| `_body_type` | `String` | Type des zugehörigen Bodies (für Debugging und Fallback-Logik). Gesetzt bei `setup()`. |
| `_current_size_px` | `int` | Aktuelle Markergröße in Pixeln. Gesetzt bei `setup()` und `set_size()`. |

Der BodyMarker speichert keine Referenz auf das `BodyDef`-Objekt. Er extrahiert bei `setup()` die Werte die er braucht (ID, Name, Icon-Key, Farbe, Type) und arbeitet danach nur noch mit seinen eigenen Feldern. Die View hält die Zuordnung `body_id → BodyMarker` in einem Dictionary.

---

### 3.3 Export-Variablen

```gdscript
@export var click_padding_px: int = 6
    # Zusätzlicher Radius der CollisionShape über die Icon-Größe hinaus.
    # Macht kleine Marker leichter klickbar.
    # Der CollisionShape-Radius ist: (_current_size_px / 2) + click_padding_px
```

---

### 3.4 Öffentliche API

```gdscript
func setup(body: BodyDef, size_px: int) -> void
    # Einmalige Konfiguration bei Instanziierung.
    #
    # Extrahiert und speichert:
    #   _body_id    = body.id
    #   _body_type  = body.type
    #
    # Konfiguriert Kind-Nodes:
    #   Icon  → Textur aus body.map_icon, Modulate aus body.color_rgba
    #   Label → Text aus body.name
    #
    # Ruft intern set_size(size_px) auf.

func set_size(size_px: int) -> void
    # Setzt die Markergröße. Aufgerufen bei setup() und bei Scope-Wechsel
    # (wenn der neue ScopeConfig andere marker_sizes hat).
    #
    # Aktualisiert:
    #   _current_size_px = size_px
    #   Icon-Skalierung so dass das Icon size_px × size_px groß ist
    #   CollisionShape-Radius = (size_px / 2) + click_padding_px
    #   Label-Position unterhalb des Icons (Offset abhängig von size_px)
```

---

### 3.5 Signale

```gdscript
signal clicked(body_id: String)
    # Emittiert bei Einfachklick auf den Marker.
    # Die View verbindet sich mit diesem Signal und verarbeitet den Klick
    # (Fokus setzen, Kamera-Flug starten).

signal double_clicked(body_id: String)
    # Emittiert bei Doppelklick auf den Marker.
    # Die View verbindet sich und löst Fokus + Zoom-to-Fit aus.
```

Die Unterscheidung Einfach-/Doppelklick erfolgt über Godots `InputEventMouseButton.double_click`-Flag in `_input_event()`. Der BodyMarker emittiert das passende Signal — die Interpretation liegt bei der View.

---

### 3.6 Klick-Detection

Der BodyMarker nutzt `Area2D._input_event()` für die Klick-Erkennung. Die `CollisionShape2D` ist ein `CircleShape2D` deren Radius größer als das Icon ist (`click_padding_px`). Das macht kleine Marker (12px, 16px) komfortabel klickbar ohne dass der Spieler pixelgenau treffen muss.

Die View ist dafür verantwortlich, Klicks während eines Kamera-Übergangs zu blockieren. Der BodyMarker selbst filtert nicht — er emittiert immer.

---

### 3.7 Label-Verhalten

Das Label ist immer sichtbar solange der Marker aktiv ist. Es gibt keine separate Label-Sichtbarkeitslogik — wenn der Marker sichtbar ist, ist sein Label sichtbar. Bei sehr hoher Markerdichte kann das zu Überlappungen führen. Eine Label-Collision-Avoidance ist ein mögliches späteres Feature, aber nicht Teil dieser Spec.

---

### 3.8 Aktivierung und Deaktivierung

Der BodyMarker hat zwei Zustände: **aktiv** (sichtbar, klickbar, wird positioniert) und **inaktiv** (unsichtbar, nicht klickbar, wird ignoriert).

Die View steuert den Zustand direkt:

```
Deaktivieren:
    marker.visible = false
    marker.get_node("ClickShape").disabled = true

Aktivieren:
    marker.visible = true
    marker.get_node("ClickShape").disabled = false
```

Ein inaktiver Marker wird von der View in keinem Update-Zyklus berücksichtigt — keine Positionsberechnung, kein `set_size()`, keine Sichtbarkeitsprüfung. Die View iteriert nur über ihre aktive Body-Liste.

Die View deaktiviert Marker nicht destruktiv. Alle Marker werden bei Initialisierung einmalig instanziiert und leben für die gesamte Lebensdauer der View. Aktivierung/Deaktivierung ist ein schneller Zustandswechsel, keine Instanziierung/Freigabe.

---

### 3.9 Was der BodyMarker nicht tut

- **Position setzen** — die View setzt `marker.position` direkt.
- **Sichtbarkeit entscheiden** — die View entscheidet über Scope und Pinned-Status.
- **Größe entscheiden** — die View liest `marker_sizes` aus dem aktiven `ScopeConfig` und ruft `set_size()`.
- **Zoom kennen** — der Marker weiß nicht welcher `scale_exp` aktiv ist.
- **Seinen Parent kennen** — der Marker weiß nicht in welcher Hierarchie er steht. Er ist flat unter `BodyLayer`.

## Kapitel 4 — BodyModel (Stub)

**Klasse/Szene:** `BodyModel` — Szenentyp und Basisklasse werden in der späteren Spec festgelegt.

Maßstabsgetreue Darstellung eines simulierten Himmelskörpers. Während der `BodyMarker` (Kapitel 3) ein Symbol mit fester Pixelgröße ist, bildet das `BodyModel` den physischen Körper mit seinem realen Radius in km ab. Es skaliert kontinuierlich mit dem Zoom — bei `scale_exp` 3.0 ist ein Mond mit 1.000 km Radius ein Pixel groß, bei `scale_exp` 1.0 füllt er einen nennenswerten Teil des Bildschirms.

Das BodyModel ist das Rendering-Primitiv für den Nahbereich. Es wird vom `TacticalDisplay` und `SensorDisplay` verwendet, nicht von der `StarChart`. Die StarChart arbeitet ausschließlich mit BodyMarkern.

---

### 4.1 Kernprinzipien

**Dumm wie BodyMarker:** Das BodyModel empfängt fertige Daten von der View. Es kennt weder die Skalierung noch den aktiven Darstellungsmodus. Position, Sichtbarkeit und Größenberechnung sind Sache der View.

**Physischer Radius:** Die Größe des BodyModels leitet sich aus `body.radius_km` ab. Die View berechnet die Bildschirmgröße über `MapScale.km_to_px(radius_km)` und setzt sie pro Frame (oder pro Zoom-Schritt).

**CollisionShapes:** Das BodyModel hat CollisionShapes die seinen physischen Umriss abbilden. Diese werden für Gameplay-Interaktionen im Nahbereich benötigt — Andocken, Kollisionserkennung, Zielerfassung. Die genaue Shape-Geometrie (Kreis, Polygon, zusammengesetzt) wird in der späteren Spec definiert.

**Nur Sim-Objekte:** BodyModels werden für deterministische Sim-Objekte erstellt — Monde, Stationen, Planeten, Strukturen. Schiffe und andere nicht-deterministische Gameplay-Objekte haben eigene Darstellungen und werden in der Game-Objects-Spec definiert.

---

### 4.2 Gleichzeitige Darstellungen

Ein Sim-Objekt kann einen `BodyMarker` und ein `BodyModel` gleichzeitig haben. Welche Darstellung aktiv ist, entscheidet die jeweilige View. Die StarChart aktiviert den Marker, das TacticalDisplay aktiviert das Model. Beide Darstellungen existieren unabhängig voneinander und teilen sich keine Nodes.

---

### 4.3 Offene Punkte (spätere Spec)

- Szenentyp und Basisklasse (`Area2D`, `StaticBody2D`, oder `CharacterBody2D`)
- CollisionShape-Geometrie und -Granularität
- Visuelle Darstellung (Sprite, prozedural, LOD-Stufen)
- Interaktions-API für Gameplay-Systeme (Andocken, Scanning, Zielerfassung)
- Sichtbarkeitsregeln im SensorDisplay und TacticalDisplay
- Verhältnis zur Scope-Logik (eigene Scopes oder andere Steuerung)

## Kapitel 5 — OrbitRenderer

**Klasse/Szene:** `OrbitRenderer extends Node2D`

Zeichnet die Bahnkurve eines Körpers. Ein OrbitRenderer pro Body der einen Orbit hat (Bodies mit `fixed`-Motion oder Wurzelobjekte haben keinen). Der OrbitRenderer ist ein dummes Rendering-Primitiv — er empfängt fertige Screen-Punkte von der View und zeichnet sie. Er kennt weder die Skalierung noch den Darstellungsmodus noch die Transformation die auf die Punkte angewendet wurde.

Alle OrbitRenderer liegen flat unter `OrbitsLayer` in der Szenenstruktur der View. Sie sind keine Kinder ihrer jeweiligen Parent-Marker — die View setzt ihre Position pro Frame auf die Screen-Position des orbitalen Parents.

---

### 5.1 Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_child_id` | `String` | ID des Körpers dessen Orbit dargestellt wird. Gesetzt bei `setup()`. |
| `_parent_id` | `String` | ID des orbitalen Parents. Gesetzt bei `setup()`. Die View nutzt diese ID um die Position des Renderers pro Frame auf die Parent-Screen-Position zu setzen. |
| `_color` | `Color` | Linienfarbe. Gesetzt bei `setup()`. |
| `_draw_points` | `PackedVector2Array` | Fertige Screen-Punkte, bereit zum Zeichnen. Gesetzt bei `set_draw_points()`. Relativ zur Position des Renderers (die auf dem Parent liegt). Gecacht weil Godot `_draw()` auch außerhalb von `queue_redraw()` aufrufen kann (Fensteränderung, Sichtbarkeitswechsel). |
| `_line_style` | `int` | Aktueller Linienstil: `SOLID`, `DASHED`, oder `DOTTED`. Gesetzt bei `set_line_style()`. |

---

### 5.2 Export-Variablen

```gdscript
@export var line_width: float = 1.5
    # Breite der Orbit-Linie in Pixeln.
    # Gilt für alle Linienstile gleichermaßen.

@export var antialiased: bool = true
    # Ob die Linie mit Antialiasing gezeichnet wird.
    # Sollte im Normalfall immer an sein.
```

---

### 5.3 Öffentliche API

```gdscript
func setup(child_id: String, parent_id: String, color: Color) -> void
    # Einmalige Konfiguration bei Instanziierung.
    #
    # Speichert:
    #   _child_id        = child_id
    #   _parent_id       = parent_id
    #   _color           = color

func set_draw_points(screen_points: PackedVector2Array) -> void
    # Setzt die fertigen Screen-Punkte und löst Neuzeichnung aus.
    #
    # Die View holt sich die km-Punkte bei Bedarf über die Sim-API
    # (SolarSystem.get_local_orbit_path(child_id)), transformiert sie
    # (linear, log, Exaggeration) und übergibt die fertigen Screen-Punkte.
    # Die genaue Transformationslogik ist Sache der jeweiligen View
    # (siehe z.B. SPEC_star_chart.md).
    #
    # Speichert _draw_points = screen_points, ruft queue_redraw() auf.

func set_line_style(style: int) -> void
    # Setzt den Linienstil. Aufgerufen von der View bei Scope-Wechsel
    # oder Modus-Wechsel.
    #
    # Gültige Werte: SOLID (0), DASHED (1), DOTTED (2)
    # Löst queue_redraw() aus wenn sich der Stil geändert hat.
```

---

### 5.4 Zeichnung

Die gesamte Ausgabe passiert in `_draw()`. Der OrbitRenderer zeichnet die Punkte aus `_draw_points` als zusammenhängende Linie mit `_color`, `line_width` und `antialiased`.

**Linienstile:**

| Stil | Verhalten |
|---|---|
| `SOLID` | Durchgezogene Linie via `draw_polyline()` |
| `DASHED` | Gestrichelte Segmente — abwechselnd gezeichnet und übersprungen |
| `DOTTED` | Punktierte Segmente — kurze Striche mit größeren Lücken |

Die Dash/Dot-Längen sind interne Konstanten des OrbitRenderers. Sie sind in Pixeln definiert und unabhängig vom Zoom.

Wenn `_draw_points` leer ist, zeichnet `_draw()` nichts.

---

### 5.5 Positionierung durch die View

Der OrbitRenderer zeichnet seine Punkte relativ zu seiner eigenen Position. Die View setzt diese Position pro Frame auf die Screen-Position des orbitalen Parents:

```
renderer.position = parent_marker.position
```

Dadurch bewegt sich die gesamte Orbit-Linie mit dem Parent mit, ohne dass die Punkte selbst neu berechnet werden müssen. Neuberechnung der Punkte (`set_draw_points()`) ist nur bei Zoom-Änderung nötig, nicht bei Positionsänderung des Parents.

---

### 5.6 Aktivierung und Deaktivierung

Wie beim BodyMarker: die View steuert `visible` direkt. Ein unsichtbarer OrbitRenderer wird von der View nicht positioniert und erhält keine `set_draw_points()`-Aufrufe. Die Sichtbarkeit ist an die Sichtbarkeit des zugehörigen Körpers gekoppelt — wenn der BodyMarker eines Körpers deaktiviert wird, wird auch sein OrbitRenderer deaktiviert.

Zusätzlich kann ein OrbitRenderer durch `min_orbit_px` im aktiven Scope ausgeblendet werden, auch wenn der zugehörige BodyMarker sichtbar bleibt (z.B. ein gepinnter Körper dessen Orbit zu klein zum Zeichnen ist).

---

### 5.7 Was der OrbitRenderer nicht tut

- **Punkte berechnen** — die View holt km-Punkte aus der Sim-API und berechnet daraus Screen-Punkte.
- **Orbit-Daten halten** — der Renderer speichert keine km-Punkte. Die Sim-API ist die einzige Quelle.
- **Position bestimmen** — die View setzt `renderer.position` auf den Parent.
- **Sichtbarkeit entscheiden** — die View entscheidet anhand von Scope und `min_orbit_px`.
- **Skalierung kennen** — der Renderer weiß nicht welcher `scale_exp` aktiv ist.
- **Transformation kennen** — ob die Punkte linear, logarithmisch oder exaggeriert berechnet wurden ist ihm unbekannt.

## Kapitel 6 — Flächige Rendering-Primitive (Überblick)

Neben den punkt- und linienförmigen Primitiven (BodyMarker, OrbitRenderer) stellt das Toolkit zwei flächige Rendering-Primitive bereit. Beide sind dumm — sie empfangen fertige Daten von der View und stellen sie dar. Beide werden über `sichtbare_zonen` im ScopeConfig gesteuert.

| Komponente | Darstellung | Anwendung |
|---|---|---|
| `BeltRenderer` (Kapitel 7) | Prozedurale Punktwolke | Asteroidengürtel, Kuipergürtel, Scattered Disk, Trojaner, Planetenringe |
| `ZoneRenderer` (Kapitel 8) | Halbtransparente Farbfläche | Strahlungsgürtel, Magnetosphären, Gravitationszonen |

Beide Komponenten decken die **Natur-Ebene** ab: physikalische Phänomene und astronomische Strukturen die ohne menschliches Zutun existieren. Ihre Daten sind statisch, in JSON definiert, und ändern sich zur Laufzeit nicht.

Die **Gameplay-Ebene** — Fraktionsterritorien, Einflusssphären, Sperrgebiete, Handelsrouten — wird in einer späteren Spec mit einer eigenen Renderer-Klasse definiert. Diese Zonen unterscheiden sich grundlegend:

- Geometrie aus irregulären Polygonen, nicht aus Kreisen/Ringen/Punktwolken
- Datenquelle ist das Gameplay-System, nicht eine statische JSON
- Können sich zur Laufzeit ändern (Fraktionen expandieren, Grenzen verschieben sich)
- Nicht an einzelne Bodies gebunden sondern frei im Raum positioniert
- Eigene Renderer-Klasse, eigene Datenstrukturen

Beide Ebenen werden über dasselbe `sichtbare_zonen`-Feld im ScopeConfig gesteuert.

## Kapitel 7 — BeltRenderer

**Klasse/Szene:** `BeltRenderer extends Node2D`

Prozedurale Darstellung astronomischer Gürtel und Schwärme als Punktwolken. Rein visuell — die dargestellten Punkte sind keine Sim-Objekte und haben keine `BodyDef`s. Einzelne Asteroiden werden erst als Sim-Objekte instanziiert wenn sie im Gameplay-Kontext relevant werden (z.B. Scanner-Reichweite im lokalen Modus) — das ist nicht Teil dieser Spec.

Der BeltRenderer deckt ab: Asteroidengürtel, Kuipergürtel, Scattered Disk, Jovian Trojans, Planetenringe. Er ist ein dummes Rendering-Primitiv wie BodyMarker und OrbitRenderer — er empfängt Skalierung und Positionsdaten von der View und zeichnet.

---

### 7.1 Datenquelle: BeltDef

Die Gürtel-Definitionen leben in einer eigenen JSON-Datei (`belt_data.json`), getrennt von den Body-Daten. Das Format ist minimal — alle visuellen Details werden prozedural aus dem Seed abgeleitet.

**JSON-Schema:**

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
    },
    {
      "id": "jovian_trojans_l4",
      "name": "Jovian Trojans L4",
      "parent_id": "sun",
      "reference_body_id": "jupiter",
      "inner_radius_km": 700000000,
      "outer_radius_km": 850000000,
      "angular_offset_rad": 1.047,
      "angular_spread_rad": 0.35,
      "min_points": 400,
      "max_points": 2000,
      "seed": 42,
      "color_rgba": [0.9, 0.6, 0.2, 0.7]
    },
    {
      "id": "saturn_main_rings",
      "name": "Saturn Main Rings",
      "parent_id": "saturn",
      "reference_body_id": "",
      "inner_radius_km": 67000,
      "outer_radius_km": 140000,
      "angular_offset_rad": 0.0,
      "angular_spread_rad": 6.2832,
      "min_points": 800,
      "max_points": 4000,
      "seed": 100,
      "color_rgba": [0.82, 0.76, 0.65, 0.6]
    }
  ]
}
```

**Feld-Beschreibungen:**

| Feld | Typ | Beschreibung |
|---|---|---|
| `id` | `String` | Eindeutige ID. Wird von `sichtbare_zonen` im ScopeConfig referenziert. |
| `name` | `String` | Anzeigename (für Debug und späteres HUD). |
| `parent_id` | `String` | ID des Zentrumskörpers. Bestimmt die Position des Renderers. Für heliozentrische Gürtel: `"sun"`. |
| `reference_body_id` | `String` | Referenzkörper für die Rotation. Leer bei Vollringen. Bei Trojaner-Schwärmen: ID des Planeten (z.B. `"jupiter"`). |
| `inner_radius_km` | `float` | Innerer Radius des Gürtels in km. |
| `outer_radius_km` | `float` | Äußerer Radius des Gürtels in km. |
| `angular_offset_rad` | `float` | Winkel-Offset relativ zum Referenzkörper in Radiant. Bei Vollringen: `0.0`. Bei L4-Trojanern: `+π/3`, bei L5: `-π/3`. |
| `angular_spread_rad` | `float` | Winkelbreite des Schwarms in Radiant. Bei Vollringen: `2π` (≈ 6.2832). Bei Trojanern: Breite des Bogensegments. |
| `min_points` | `int` | Mindestanzahl generierter Punkte (bei niedrigster Dichte). |
| `max_points` | `int` | Maximalanzahl generierter Punkte (bei höchster Dichte / nächstem Zoom). |
| `seed` | `int` | Seed für den Zufallsgenerator. Garantiert deterministische Punktgenerierung. |
| `color_rgba` | `float[4]` | Basisfarbe des Gürtels als RGBA. Einzelne Punkte changieren leicht um diesen Wert. |

---

### 7.2 Datenklasse: BeltDef

**Klasse:** `BeltDef extends RefCounted`

Unveränderlich nach Konstruktion, analog zu `BodyDef`. Der `CoreDataLoader` (oder ein eigener `BeltDataLoader`) liest die JSON und baut `BeltDef`-Objekte. Die View erhält die fertige Liste beim Start.

---

### 7.3 Prozedurale Punktgenerierung

Bei Instanziierung generiert der BeltRenderer alle Punkte bis `max_points` aus dem Seed. Pro Punkt werden folgende Werte deterministisch berechnet:

| Wert | Ableitung | Beschreibung |
|---|---|---|
| `radius_km` | Seed → Random | Gleichverteilt zwischen `inner_radius_km` und `outer_radius_km`. |
| `angle_rad` | Seed → Random | Gleichverteilt über `angular_spread_rad`, zentriert auf `angular_offset_rad`. |
| `point_size_px` | Seed → Random | Variable Größe pro Punkt, z.B. 1–3px. |
| `color_offset` | Seed → Random | Leichte Abweichung von der Basisfarbe (Hue/Value-Shift). Erzeugt natürliche Variation. |
| `priority` | Seed → Random | Wert zwischen 0.0 und 1.0. Bestimmt bei welcher Dichte der Punkt sichtbar wird (siehe 7.4). |

Die Punkte werden als lokale Polarkoordinaten gespeichert (`radius_km`, `angle_rad`), nicht als kartesische Positionen. Das hat zwei Vorteile: Die Rotation für Trojaner-Schwärme ist ein einfacher Winkel-Offset, und die Skalierung auf Screen-Koordinaten passiert erst beim Zeichnen.

```gdscript
# Interner Punkt-Struct (oder PackedArrays für Performance)
var _radii_km: PackedFloat32Array        # Radius pro Punkt
var _angles_rad: PackedFloat32Array      # Basiswinkel pro Punkt (ohne Rotation)
var _sizes_px: PackedFloat32Array        # Größe pro Punkt
var _color_offsets: PackedFloat32Array   # Farbvariation pro Punkt
var _priorities: PackedFloat32Array      # LOD-Priorität pro Punkt (0.0–1.0)
```

Alle Arrays haben die Länge `max_points` und sind nach `priority` aufsteigend sortiert. Beim Zeichnen reicht es dann, die ersten N Punkte zu zeichnen (siehe 7.4).

---

### 7.4 LOD: Dichte-Steuerung über Zoom

Nicht alle generierten Punkte werden immer gezeichnet. Die View berechnet aus dem aktuellen `scale_exp` einen Density-Faktor und übergibt ihn dem BeltRenderer. Der Renderer zeichnet nur Punkte deren `priority` ≤ Density ist.

Da die Arrays nach Priority sortiert sind, reduziert sich das auf: zeichne die ersten `N` Punkte, wobei `N` zwischen `min_points` und `max_points` interpoliert wird.

```
density = clamp((zoom_max - scale_exp) / (zoom_max - zoom_min), 0.0, 1.0)
visible_count = min_points + int(density * (max_points - min_points))
```

Die `zoom_min`/`zoom_max`-Werte für diese Berechnung kommen aus dem aktiven ScopeConfig oder sind Export-Variablen des BeltRenderers — das genaue Mapping wird bei der Implementierung festgelegt.

Die Auswahl ist deterministisch — beim Reinzoomen tauchen immer dieselben Punkte in derselben Reihenfolge auf. Kein Shuffling, kein Zufall zur Laufzeit.

---

### 7.5 Trojaner-Rotation

Gürtel mit einem `reference_body_id` rotieren mit dem Referenzkörper mit. Die View liefert pro Frame den aktuellen Winkel des Referenzkörpers relativ zum Parent:

```gdscript
func set_reference_angle(angle_rad: float) -> void
    # Setzt den aktuellen Winkel des Referenzkörpers.
    # Wird pro Frame von der View aufgerufen, nur für Gürtel
    # mit reference_body_id.
    #
    # Der Renderer addiert diesen Winkel auf die Basiswinkel
    # aller Punkte beim Zeichnen.
```

Für Vollringe (Asteroidengürtel, Kuiper, Scattered Disk, Planetenringe) wird `set_reference_angle()` nie aufgerufen — ein Vollring sieht bei jeder Rotation gleich aus.

Die View berechnet den Winkel aus der Weltposition des Referenzkörpers:

```
var ref_pos = SolarSystem.get_body_position(reference_body_id)
var angle = ref_pos.angle()    # atan2(y, x)
belt_renderer.set_reference_angle(angle)
```

---

### 7.6 Zeichnung

Die Ausgabe passiert in `_draw()`. Der BeltRenderer berechnet für jeden sichtbaren Punkt die Screen-Position aus den Polarkoordinaten, dem aktuellen Referenzwinkel und der Skalierung:

```
Für jeden Punkt i (0 bis visible_count - 1):
    final_angle = _angles_rad[i] + _reference_angle
    x_km = cos(final_angle) * _radii_km[i]
    y_km = sin(final_angle) * _radii_km[i]
    screen_pos = View-Transformation(x_km, y_km)    # linear oder log
    draw_circle(screen_pos, _sizes_px[i], punkt_farbe)
```

Die View-Transformation (linear/log) wird nicht vom BeltRenderer selbst durchgeführt. Stattdessen erhält er von der View eine Transformationsfunktion oder vorberechnete Skalierungswerte — der genaue Mechanismus wird bei der Implementierung festgelegt.

Die Punktfarbe pro Punkt ist: Basisfarbe des Gürtels + `_color_offsets[i]` als leichte Hue/Value-Verschiebung.

---

### 7.7 Skalierungsverhalten

Der BeltRenderer ist nicht vom Exaggeration-Faktor betroffen. Im Log-Modus wird er direkt durch die Log-Transformation behandelt wie direkte Kinder des Fokus. Das ist korrekt weil Gürtel großräumige Strukturen sind die auf derselben Hierarchie-Ebene wie die Planeten liegen. Die Details der Log-Transformation sind Sache der jeweiligen View (siehe z.B. `SPEC_star_chart.md`).

Die Punktgrößen (`_sizes_px`) sind in Pixeln definiert und ändern sich nicht mit dem Zoom. Nur die Anzahl sichtbarer Punkte und ihre Abstände ändern sich.

---

### 7.8 Öffentliche API

```gdscript
func setup(belt: BeltDef) -> void
    # Einmalige Konfiguration bei Instanziierung.
    # Generiert alle Punkte aus dem Seed (bis max_points).
    # Sortiert nach Priority.

func set_density(visible_count: int) -> void
    # Setzt die Anzahl sichtbarer Punkte.
    # Aufgerufen von der View bei Zoom-Änderung.
    # Löst queue_redraw() aus.

func set_reference_angle(angle_rad: float) -> void
    # Setzt den Rotationswinkel für Trojaner-Schwärme.
    # Aufgerufen pro Frame von der View, nur für Gürtel
    # mit reference_body_id.
    # Löst queue_redraw() aus.

func set_scale(px_per_km: float) -> void
    # Setzt den aktuellen Skalierungsfaktor für die Zeichnung.
    # Aufgerufen von der View bei Zoom-Änderung.
```

---

### 7.9 Aktivierung und Deaktivierung

Wie bei den anderen Primitives: die View steuert `visible` direkt. Sichtbarkeit wird über `sichtbare_zonen` im aktiven ScopeConfig gesteuert. Die Belt-IDs werden gegen dieses Feld geprüft — gleiche Mechanik wie beim ZoneRenderer (Kapitel 8).

---

### 7.10 Planetenringe

Der BeltRenderer eignet sich auch für Planetenringe (Saturn, Uranus, Jupiter). Das Schema unterstützt dies direkt — `parent_id` verweist auf den Planeten statt auf die Sonne, die View setzt `renderer.position` auf die Screen-Position des Planeten, und die Punkte verteilen sich im richtigen Radius drum herum. Kein `reference_body_id` nötig weil Planetenringe Vollringe sind.

Planetenringe werden bei ganz anderen Zoom-Stufen relevant als heliozentrische Gürtel. Bei `scale_exp` 5.0 sind Saturns Ringe unsichtbar klein — sie werden erst bei `scale_exp` ~3.5 oder darunter interessant. Die Steuerung erfolgt über `sichtbare_zonen` im ScopeConfig: ein Scope der auf das Saturn-System fokussiert zeigt `"saturn_main_rings"`, ein Übersichts-Scope nicht. Die LOD-Dichte skaliert dann innerhalb des sichtbaren Zoom-Bereichs.

---

### 7.11 Was der BeltRenderer nicht tut

- **Asteroiden simulieren** — die Punkte sind rein visuell, keine Sim-Objekte.
- **Sichtbarkeit entscheiden** — die View prüft `sichtbare_zonen` im Scope.
- **Dichte entscheiden** — die View berechnet `visible_count` aus dem Zoom und ruft `set_density()`.
- **Position bestimmen** — die View setzt `renderer.position` auf die Screen-Position des Parent-Bodys.
- **Referenzwinkel berechnen** — die View liefert den Winkel des Referenzkörpers.

## Kapitel 8 — ZoneRenderer

**Klasse/Szene:** `ZoneRenderer extends Node2D`

Flächige Darstellung natürlicher Zonen um Himmelskörper — Strahlungsgürtel, Magnetosphären, Gravitationszonen. Rein visuell mit einem `zone_type`-Tag für die Gameplay-Kopplung. Der ZoneRenderer ist ein dummes Rendering-Primitiv wie die anderen Toolkit-Komponenten — er empfängt fertige Skalierungsdaten von der View und zeichnet.

Der ZoneRenderer deckt ausschließlich die Natur-Ebene ab: physikalische Phänomene die ohne menschliches Zutun existieren, an Bodies gebunden, statisch, in JSON definiert. Dynamische Gameplay-Flächen (Fraktionsterritorien, Einflusssphären, Sperrgebiete) gehören zur Gameplay-Ebene und werden in einer späteren Spec mit einer eigenen Renderer-Klasse definiert.

---

### 8.1 Datenquelle: ZoneDef

Die Zone-Definitionen leben in einer eigenen JSON-Datei (`zone_data.json`), analog zu `belt_data.json`.

**JSON-Schema:**

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
    },
    {
      "id": "earth_van_allen_inner",
      "name": "Earth Inner Van Allen Belt",
      "parent_id": "earth",
      "zone_type": "radiation",
      "geometry": "ring",
      "inner_radius_km": 1000,
      "outer_radius_km": 6000,
      "color_rgba": [0.7, 0.8, 0.2, 0.12],
      "border_color_rgba": [0.7, 0.8, 0.2, 0.35]
    },
    {
      "id": "jupiter_magnetosphere",
      "name": "Jupiter Magnetosphere",
      "parent_id": "jupiter",
      "zone_type": "magnetic",
      "geometry": "circle",
      "radius_km": 7000000,
      "color_rgba": [0.3, 0.4, 0.9, 0.08],
      "border_color_rgba": [0.3, 0.4, 0.9, 0.25]
    }
  ]
}
```

**Feld-Beschreibungen:**

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `id` | `String` | ja | Eindeutige ID. Wird von `sichtbare_zonen` im ScopeConfig referenziert. |
| `name` | `String` | ja | Anzeigename (für Debug und späteres HUD). |
| `parent_id` | `String` | ja | ID des Zentrumskörpers. Bestimmt die Position des Renderers. |
| `zone_type` | `String` | ja | Klassifikation der Zone. Für Gameplay-Systeme die wissen müssen was die Zone bedeutet. Werte z.B.: `"radiation"`, `"magnetic"`, `"gravity"`. |
| `geometry` | `String` | ja | Geometrie-Typ: `"circle"` oder `"ring"`. |
| `radius_km` | `float` | circle | Radius der Zone in km. Nur bei `geometry: "circle"`. |
| `inner_radius_km` | `float` | ring | Innerer Radius in km. Nur bei `geometry: "ring"`. |
| `outer_radius_km` | `float` | ring | Äußerer Radius in km. Nur bei `geometry: "ring"`. |
| `color_rgba` | `float[4]` | ja | Füllfarbe als RGBA. Typisch niedriger Alpha-Wert für halbtransparente Fläche. |
| `border_color_rgba` | `float[4]` | ja | Farbe der Grenzlinie als RGBA. Höherer Alpha-Wert als die Füllung. |

---

### 8.2 Datenklasse: ZoneDef

**Klasse:** `ZoneDef extends RefCounted`

Unveränderlich nach Konstruktion, analog zu `BodyDef` und `BeltDef`. Ein eigener `ZoneDataLoader` (oder Erweiterung des bestehenden Loaders) liest die JSON und baut `ZoneDef`-Objekte. Die View erhält die fertige Liste beim Start.

---

### 8.3 Interner Zustand

| Variable | Typ | Beschreibung |
|---|---|---|
| `_zone_id` | `String` | ID der Zone. Gesetzt bei `setup()`. |
| `_parent_id` | `String` | ID des Zentrumskörpers. Gesetzt bei `setup()`. |
| `_zone_type` | `String` | Klassifikation der Zone. Gesetzt bei `setup()`. |
| `_geometry` | `int` | Geometrie-Typ: `CIRCLE` oder `RING`. Gesetzt bei `setup()`. |
| `_radius_km` | `float` | Radius bei Circle-Geometrie. Gesetzt bei `setup()`. |
| `_inner_radius_km` | `float` | Innerer Radius bei Ring-Geometrie. Gesetzt bei `setup()`. |
| `_outer_radius_km` | `float` | Äußerer Radius bei Ring-Geometrie. Gesetzt bei `setup()`. |
| `_color` | `Color` | Füllfarbe. Gesetzt bei `setup()`. |
| `_border_color` | `Color` | Grenzlinienfarbe. Gesetzt bei `setup()`. |
| `_px_per_km` | `float` | Aktuelle Skalierung. Gesetzt bei `set_scale()`. |

---

### 8.4 Export-Variablen

```gdscript
@export var border_width: float = 1.5
    # Breite der Grenzlinie in Pixeln.

@export var circle_segments: int = 64
    # Anzahl der Segmente für die Kreis-/Ring-Zeichnung.
    # Höhere Werte = glattere Kreise, mehr Draw-Calls.
```

---

### 8.5 Öffentliche API

```gdscript
func setup(zone: ZoneDef) -> void
    # Einmalige Konfiguration bei Instanziierung.
    #
    # Extrahiert und speichert alle Felder aus der ZoneDef.
    # Konfiguriert die Geometrie (circle oder ring).

func set_scale(px_per_km: float) -> void
    # Setzt den aktuellen Skalierungsfaktor.
    # Aufgerufen von der View bei Zoom-Änderung.
    # Die Radien werden bei der Zeichnung mit diesem Faktor
    # in Pixel umgerechnet.
    # Löst queue_redraw() aus.
```

---

### 8.6 Zeichnung

Die gesamte Ausgabe passiert in `_draw()`. Der ZoneRenderer zeichnet relativ zu seiner eigenen Position (die von der View auf den Parent gesetzt wird).

**Circle-Geometrie:**
```
radius_px = _radius_km * _px_per_km
draw_circle(Vector2.ZERO, radius_px, _color)                          # Füllung
draw_arc(Vector2.ZERO, radius_px, 0, TAU, circle_segments, _border_color, border_width)  # Rand
```

**Ring-Geometrie:**
```
inner_px = _inner_radius_km * _px_per_km
outer_px = _outer_radius_km * _px_per_km

# Füllung als Polygon-Ring (äußerer Kreis minus innerer Kreis)
draw_ring_polygon(inner_px, outer_px, _color)

# Grenzlinien
draw_arc(Vector2.ZERO, inner_px, 0, TAU, circle_segments, _border_color, border_width)
draw_arc(Vector2.ZERO, outer_px, 0, TAU, circle_segments, _border_color, border_width)
```

Die Ring-Füllung (`draw_ring_polygon`) wird als Polygon aus äußeren und inneren Kreispunkten zusammengebaut. Das ist eine interne Hilfsfunktion des ZoneRenderers.

Wenn `_px_per_km` so klein ist dass die Zone weniger als einen Pixel groß wäre, zeichnet `_draw()` nichts.

---

### 8.7 Positionierung durch die View

Wie beim BeltRenderer und OrbitRenderer: die View setzt `renderer.position` pro Frame auf die Screen-Position des Parent-Bodys. Die Zone bewegt sich mit ihrem Parent mit.

```
zone_renderer.position = parent_marker.position
```

---

### 8.8 Skalierungsverhalten

Der ZoneRenderer ist nicht vom Exaggeration-Faktor betroffen. Im Log-Modus wird er direkt durch die Log-Transformation behandelt. Die View übergibt den passenden `px_per_km`-Wert — ob linear oder log-transformiert ist dem Renderer egal.

Die Radien skalieren kontinuierlich mit dem Zoom (anders als die Punktgrößen im BeltRenderer die in Pixeln fest sind). Ein Strahlungsgürtel wird beim Reinzoomen größer, beim Rauszoomen kleiner.

**Hinweis zur Log-Transformation:** Im Log-Modus ist die Skalierung nicht uniform — Punkte näher am Zentrum werden stärker komprimiert als weiter entfernte. Ein einfacher `px_per_km`-Wert reicht dann nicht für korrekte Ring-Darstellung. Die View muss entweder die Radien einzeln log-transformieren und als Pixel-Werte übergeben, oder der ZoneRenderer bekommt beide Radien bereits in Pixeln. Der genaue Mechanismus wird bei der Implementierung festgelegt.

---

### 8.9 Sichtbarkeit

Wie bei den anderen Primitives: die View steuert `visible` direkt. Sichtbarkeit wird über `sichtbare_zonen` im aktiven ScopeConfig gesteuert. Die Zone-IDs werden gegen dieses Feld geprüft — gleiche Mechanik wie beim BeltRenderer (Kapitel 7).

---

### 8.10 Gameplay-Kopplung

Der ZoneRenderer selbst trägt keine Gameplay-Daten wie Strahlungsstärke oder Schadensrate. Er hat nur seinen `zone_type`-Tag (`"radiation"`, `"magnetic"`, `"gravity"` etc.) und seine geometrischen Dimensionen. Gameplay-Systeme können die Zone-Definitionen abfragen und selbst entscheiden was passiert — Schaden, Warnung im HUD, Routing-Malus, Scanner-Störung. Der Renderer zeigt nur an.

---

### 8.11 Was der ZoneRenderer nicht tut

- **Gameplay-Logik ausführen** — er zeigt Zonen an, er berechnet keine Effekte.
- **Sichtbarkeit entscheiden** — die View prüft `sichtbare_zonen` im Scope.
- **Position bestimmen** — die View setzt `renderer.position` auf den Parent.
- **Skalierung entscheiden** — die View übergibt `px_per_km`.
