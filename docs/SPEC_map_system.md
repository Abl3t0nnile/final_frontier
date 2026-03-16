# Map System — Spezifikation

> Design-Referenz für das Kartensystem (BaseMap, NavMap, LocalMap)
> Stand: 2026-03-15

---

## Überblick

Das Kartensystem ist die zentrale visuelle Schnittstelle zwischen Spieler und Sonnensystem. Es besteht aus einer Basisklasse (**BaseMap**) und zwei spezialisierten Subklassen:

- **NavMap** — Strategischer Sternatlas. Allwissend, freie Kamera, zeigt das gesamte System aus Datenbankwissen. Dient der Übersicht, Inspektion und Reiseplanung.
- **LocalMap** — Taktischer Sensorbildschirm. Gebunden an das Spielerschiff, eingeschränkte Reichweite, physikalisch begrenzte Wahrnehmung. Dient der unmittelbaren Navigation, Erkundung und Kampf.

Die BaseMap stellt wiederverwendbare Rendering-Bausteine und die Anbindung an den `SolarSystem`-Autoload bereit. Sie hat keine eigene Meinung über Sichtbarkeit, Kamera oder Interaktion — diese Entscheidungen treffen die Subklassen.

> **Datenquelle:** Alle Positionsdaten kommen zur Laufzeit vom [`SolarSystem`-Autoload](./ARCHITECTURE.md) über dessen öffentliche API. Körper-Metadaten (Icons, Farben, Tags) kommen aus den `BodyDef`-Objekten.

---

# Teil 1 — BaseMap

Die BaseMap ist die abstrakte Basisklasse für alle Kartenansichten. Sie instanziiert und verwaltet die Kernbausteine, überlässt aber alle Entscheidungen über Darstellung und Verhalten den Subklassen.

---

## Skalierungssystem

### Grundprinzip

Beide Maps verwenden eine Exponent-basierte Skalierung. Der zentrale Steuerungswert ist ein Exponent `scale_exp`, aus dem der Umrechnungsfaktor abgeleitet wird:

```
km_per_px = 10 ^ scale_exp
px_per_km = 1.0 / km_per_px
```

Bei `scale_exp = 5.7` entspricht 1 Pixel ≈ 501.187 km. Bei `scale_exp = 9.0` entspricht 1 Pixel = 1.000.000.000 km.

### Zoom-Schritte

| Parameter       | Wert   | Beschreibung |
|-----------------|--------|--------------|
| Schrittweite    | `0.1`  | Veränderung von `scale_exp` pro Zoom-Schritt |
| Faktor pro Step | ~1.26× | Jeder Schritt verändert den Maßstab um Faktor `10^0.1` |

Der erlaubte Bereich von `scale_exp` (Min/Max) wird **nicht** von der BaseMap festgelegt — jede Subklasse definiert ihren eigenen gültigen Bereich.

### Positions-Umrechnung

Die BaseMap stellt die Umrechnungsfunktion bereit:

```gdscript
screen_pos = world_pos_km * px_per_km
```

Wie diese Umrechnung angewendet wird (linear, logarithmisch, mit Übertreibung) ist Sache der jeweiligen Subklasse.

---

## Body-Marker (Area2D)

Jeder simulierte Körper wird als eigene Area2D-Szene instanziiert. Der Marker ist ein wiederverwendbarer Baustein, der sich selbst darstellen kann, aber **nicht** selbst entscheidet, ob er sichtbar ist.

### Verantwortlichkeiten des Markers

- Darstellung des Icons (aus `BodyDef.map_icon`)
- Darstellung der Farbe (aus `BodyDef.color_rgba`)
- Darstellung des Labels (Name des Körpers)
- Bereitstellung einer Klick-Area (Input-Events nach oben weiterreichen)

### Nicht Verantwortlichkeit des Markers

- Sichtbarkeitsentscheidung → kommt von der Subklasse
- Positionsberechnung → kommt von der Subklasse
- Reaktion auf Klick → wird von der Subklasse verarbeitet

### Größensystem

Die Marker-Größe wird durch zwei Achsen bestimmt:

**Achse 1 — Typ-Hierarchie:** Der `type` des Körpers bestimmt die relative Größe innerhalb jeder Zoom-Stufe. Die Hierarchie ist fest:

```
star > planet > dwarf > moon > struct
```

**Achse 2 — Zoom-Stufe:** Es gibt 3 diskrete Zoom-Stufen, gekoppelt an `scale_exp`-Schwellen. Marker werden **größer** bei weiterem Zoom-Out — sie sind visuelle Anker auf einer zunehmend leeren Fläche.

| Stufe | Zoom | Marker-Größe |
|-------|------|--------------|
| 1 | Nah (kleiner `scale_exp`) | Klein |
| 2 | Mittel | Mittel |
| 3 | Fern (großer `scale_exp`) | Groß |

Die Marker-Größe ergibt sich aus einer **konfigurierbaren Matrix** `Typ × Zoom-Stufe`. Diese Matrix wird als Export-Variablen im Editor bereitgestellt, sodass alle Pixelwerte und Stufenschwellen ohne Code-Änderung angepasst werden können.

**Grenzwerte:**

| Regel | Wert |
|-------|------|
| Minimalgröße aller Marker | 8 px |
| Minimalgröße `star` | 64 px |

**Stufenschwellen:** Die `scale_exp`-Werte, an denen die Zoom-Stufe wechselt, sind ebenfalls Export-Variablen.

### Icon-Zuordnung

Das Icon wird durch `BodyDef.map_icon` bestimmt (siehe [`SPEC_solar_system_sim_data.md → Konventionen für map_icon`](./SPEC_solar_system_sim_data.md)). Die Farbe wird durch `BodyDef.color_rgba` bestimmt.

---

## Marker-Gruppen

Alle Body-Marker werden beim Instanziieren automatisch in Gruppen eingetragen. Die Gruppierung ermöglicht effiziente Sammeloperationen — z.B. alle Monde des Jupiter ein-/ausblenden, alle Navigationsrelais hervorheben, oder alle Planeten auf einmal abfragen.

### Gruppierungsachsen

Jeder Marker wird in **drei Kategorien** von Gruppen eingetragen:

**1. Typ-Gruppe:** Basierend auf `BodyDef.type`.

| Gruppe | Mitglieder |
|--------|------------|
| `type:star` | Alle Sterne |
| `type:planet` | Alle Planeten |
| `type:dwarf` | Alle Zwergplaneten |
| `type:moon` | Alle Monde |
| `type:struct` | Alle Strukturen |

**2. Subtyp-Gruppe:** Basierend auf `BodyDef.subtype`.

| Gruppe (Beispiele) | Mitglieder |
|---------------------|------------|
| `subtype:terrestrial` | Gesteinsplaneten |
| `subtype:gas_giant` | Gasriesen |
| `subtype:major_moon` | Große Monde |
| `subtype:station` | Stationen |
| `subtype:relay` | Kommunikationsrelais |

**3. Map-Tag-Gruppen:** Eine Gruppe pro Tag aus `BodyDef.map_tags`. Jeder Marker kann in mehreren Tag-Gruppen sein.

| Gruppe (Beispiele) | Mitglieder |
|---------------------|------------|
| `tag:jovian_system` | Jupiter + alle Monde + Structs im Jupitersystem |
| `tag:inner_system` | Alles innerhalb des Asteroidengürtels |
| `tag:major_body` | Stern, Planeten, Zwergplaneten |
| `tag:landmark` | Gameplay-relevante Orientierungspunkte |

### Namenskonvention

Gruppenname = Prefix + Wert aus dem Datensatz:

```
type:<type>          z.B. type:planet
subtype:<subtype>    z.B. subtype:major_moon
tag:<map_tag>        z.B. tag:jovian_system
```

### Nutzung

Die BaseMap stellt Funktionen bereit, um Marker über ihre Gruppen abzufragen und Sammeloperationen auszuführen. Typische Anwendungsfälle:

- **Sichtbarkeitssteuerung:** Alle Marker einer Gruppe aktivieren/deaktivieren (z.B. `tag:jovian_system` beim Fokus auf Jupiter). Deaktivierte Marker sind unsichtbar und fangen keine Input-Events ab.
- **LOD-Entscheidungen:** Alle `type:moon` ausblenden bei extremem Zoom-Out
- **Filterung:** Nur `subtype:station` anzeigen für Handelsplanung
- **Spätere Gameplay-Systeme:** Alle `tag:nav_network` hervorheben für Routenplanung

---

## Orbit-Renderer (Node2D)

Alle Orbit-Renderer liegen **flat unter einem gemeinsamen `OrbitsLayer`** (Node2D), der in jeder Map-Szene als erster Kind-Node vor dem `BodyLayer` eingefügt wird. Dadurch werden Orbits immer unterhalb der Marker gerendert.

Die `position` jedes Orbit-Renderers wird pro Tick von der BaseMap gesetzt — er zeigt auf die aktuelle Screen-Position des zugehörigen Parent-Körpers. Die Zeichenpunkte sind relativ zu dieser Position, sodass der Orbit korrekt um den Parent zentriert ist.

### Zeichenlogik

Die Punkte aus dem Cache sind relativ zum Parent-Ursprung in km und werden mit `px_per_km` in Screen-Koordinaten umgerechnet:

```gdscript
func _draw() -> void:
    var points_km: Array[Vector2] = SolarSystem.get_local_orbit_path(child_id)
    var scaled_points: PackedVector2Array = PackedVector2Array()
    for p in points_km:
        scaled_points.append(p * px_per_km)
    draw_polyline(scaled_points, orbit_color, orbit_width)
```

### Positions-Update pro Tick

BaseMap setzt die `position` jedes Orbit-Renderers in `_on_simulation_updated()`:

```gdscript
var parent_pos := SolarSystem.get_body_position(parent_id)
renderer.position = calculate_screen_position(parent_pos)
```

### Neuzeichnung

`_draw()` wird **nicht** pro Frame aufgerufen. `queue_redraw()` wird nur bei Änderung von `px_per_km` (Zoom) aufgerufen. Die Positions-Verschiebung durch Tick-Updates erfolgt über `renderer.position`, nicht durch Neuzeichnung.

### Darstellungsregeln

- Farbe der Orbitlinie leitet sich von `BodyDef.color_rgba` des **Kindes** ab (gedimmt / reduzierte Alpha)
- Linienbreite ist konstant in Pixeln (skaliert nicht mit Zoom)
- Wann ein Orbit gezeichnet wird, entscheidet die Subklasse — nicht der Renderer

### Performance

Die Simulation enthält ~65–70 Orbit-Renderer mit je 64–200 Pfadpunkten. Im Normalbetrieb (kein Zoom) findet kein Neuzeichnen statt. Beim Zoom-Schritt zeichnen nur die sichtbaren Orbits einmal neu. Für diese Größenordnung ist kein besonderer Optimierungsbedarf gegeben.

---

## Anbindung an SolarSystem

Die BaseMap stellt die Brücke zum `SolarSystem`-Autoload bereit:

- Positions-Abfrage: `SolarSystem.get_body_position(id) → Vector2` (Welt-km)
- Orbit-Pfade: `SolarSystem.get_local_orbit_path(id) → Array[Vector2]` (relativ zum Parent, km)
- Body-Daten: `SolarSystem.get_body(id) → BodyDef`
- Hierarchie: `get_child_bodies()`, `get_bodies_by_type()`, `get_root_bodies()`, etc.
- Update-Signal: `SolarSystem.simulation_updated`

Die BaseMap lauscht auf `simulation_updated` und aktualisiert die Positionen aller Marker und Orbit-Renderer. Die Subklasse entscheidet, welche davon sichtbar sind.

---

## Subklassen-Hooks

Die BaseMap definiert folgende Hooks, die von Subklassen implementiert werden müssen:

| Hook | Beschreibung |
|------|--------------|
| Skalenbereich | Min/Max `scale_exp` für diese Map |
| Sichtbarkeitslogik | Entscheidung pro Körper: sichtbar oder nicht |
| Positionstransformation | Wie km → px umgerechnet wird (linear, log, übertrieben) |
| Kamera-Setup | Typ, Steuerung und Einschränkungen der Kamera |
| Input-Handling | Tastatur- und Mauseingaben verarbeiten |
| UI-Layer | Map-spezifische Panels und Overlays |

---

## Zusammenfassung: BaseMap vs. Subklassen

| BaseMap (geteilt) | Subklasse (Map-spezifisch) |
|-------------------|----------------------------|
| Skalierungsmathe (`10^exp`, px↔km) | Erlaubter Skalenbereich |
| Body-Marker-Szene (Icon, Farbe, Label, Klick-Area) | Sichtbarkeitsentscheidung |
| Marker-Größenmatrix (Typ × Zoom-Stufe) | Stufenschwellen (wann welche Stufe gilt) |
| Orbit-Renderer (`_draw()` Logik) | Wann Orbits gezeichnet werden |
| Positionsupdate aus SolarSystemModel | Wie Positionen transformiert werden |
| Instanziierung und Verwaltung der Marker | Kamera (Typ, Steuerung, Constraints) |
| | Input-Handling und Interaktion |
| | UI-Panels und Overlays |

---

# Teil 2 — NavMap

Die NavMap ist die erste Subklasse der BaseMap. Sie ist ein allwissender Sternatlas: freie Kamera, keine physikalischen Wahrnehmungsgrenzen, alle bekannten Körper sind verfügbar.

---

## Szenenbaum

```
NavMap (extends BaseMap)
│
├── NavMapCamera (Camera2D)               ← Freie Kamera, Pan + Culling
│
├── OrbitsLayer (Node2D)                  ← Alle Orbit-Renderer flat, von BaseMap verwaltet
│   ├── [OrbitRenderer] (Node2D)          ← BaseMap: ein Renderer pro Körper mit Parent
│   ├── [OrbitRenderer] (Node2D)
│   └── ...
│
├── BodyLayer (Node2D)                    ← Alle Body-Marker flat, von BaseMap verwaltet
│   ├── [StarMarker] (Area2D)
│   ├── [PlanetMarker] (Area2D)
│   ├── [MoonMarker] (Area2D)
│   └── ...
│
└── UILayer (CanvasLayer)                 ← NavMap-spezifisch
    ├── InfoPanel                         ← Rechts, 1/3 Breite
    ├── MapControls                       ← Zoom, Log-Toggle, etc.
    └── RoutePlannerOverlay (TBD)
```

---

## Kamera

### Verhalten

Die NavMap verwendet eine **freie Camera2D**. Sie ist für Panning und Viewport-Culling zuständig — **nicht für Zoom**. Der Zoom wird ausschließlich über `scale_exp` gesteuert. Die Kamera hat keine Positionsbeschränkung.

### Steuerung

| Eingabe          | Aktion |
|------------------|--------|
| Pfeiltasten      | Kamera-Pan in Blickrichtung |
| Maus-Drag        | Kamera-Pan (Grab & Move) |
| Mausrad          | Zoom (`scale_exp` ± 0.1), zentriert auf Mausposition |
| `+` / `-` Tasten | Zoom (`scale_exp` ± 0.1), zentriert auf Mausposition |

### Zoom auf Mausposition

Der Zoom verhält sich wie Google Maps: Der Punkt unter dem Cursor bleibt stationär, die Kamera verschiebt sich entsprechend.

### Kamera-Offset bei InfoPanel

Wenn das InfoPanel geöffnet ist (rechte Seite, ca. 1/3 der Breite), wird das logische Kamera-Zentrum verschoben:

```
offset_x = -panel_width / 2.0
```

Der Offset wird beim Öffnen/Schließen interpoliert (Tween), nicht hart gesetzt.

### Skalenbereich

| Parameter       | Wert | Beschreibung |
|-----------------|------|--------------|
| Min `scale_exp` | TBD  | Maximaler Zoom-In |
| Max `scale_exp` | TBD  | Maximaler Zoom-Out |

---

## Darstellungsmodi

### Lineare Darstellung (Standard)

Im Standardmodus werden Positionen linear umgerechnet:

```
screen_pos = world_pos_km * px_per_km
```

Alle Abstände sind maßstabsgetreu.

### Logarithmische Darstellung (zuschaltbar)

Per Toggle kann eine logarithmische Skalierung aktiviert werden. Diese komprimiert große Distanzen, sodass das gesamte System im Viewport sichtbar bleibt.

Die Log-Skala hat einen eigenen einstellbaren Faktor `log_scale_factor`, der die Stärke der Kompression steuert:

```
log_distance = log_scale_factor * log10(1.0 + distance_km)
```

> **Hinweis:** Die exakte Transformationsformel und das Zusammenspiel von `log_scale_factor` mit `scale_exp` wird bei der Implementierung finalisiert.

### Orbit-Übertreibung

Wenn Körper bei aktuellem Maßstab zu dicht zusammenfallen (z.B. Monde eines fokussierten Planeten), können Orbitradien übertrieben dargestellt werden.

**Obergrenze:** Die Übertreibung hat eine harte Grenze. Wenn die nötige Vergrößerung dazu führen würde, dass Kind-Orbits aus dem visuellen Kontext ihres Elternsystems herausbrechen (z.B. Jupitermonde im Asteroidengürtel), wird die Übertreibung nicht angewendet. Stattdessen werden die Kinder ausgeblendet und der Fokus löst sich.

---

## Sichtbarkeitslogik

Die NavMap entscheidet pro Körper, ob er sichtbar ist. Die Entscheidung basiert auf:

1. **Bildschirmgröße des Orbits:** Orbit bei aktuellem `px_per_km` kleiner als Schwellwert in Pixeln → Körper + Orbit ausblenden.
2. **Viewport-Culling:** Körper außerhalb des Kamerabereichs werden nicht gerendert.
3. **Fokus-Kontext:** Kinder eines fokussierten Körpers werden bevorzugt angezeigt (ggf. mit Orbit-Übertreibung).

| Situation | Verhalten |
|-----------|-----------|
| Orbit < Schwellwert (px) | Körper + Orbit ausblenden |
| Orbit ≥ Schwellwert, im Viewport | Körper + Orbit anzeigen |
| Orbit ≥ Schwellwert, außerhalb Viewport | Ausblenden (Culling) |
| Parent fokussiert, Orbit zu klein | Orbit-Übertreibung, wenn innerhalb Obergrenze |
| Parent fokussiert, Übertreibung sprengt Kontext | Kinder ausblenden, Fokus löst sich |

---

## Fokus-System

### Interaktion

| Aktion | Ergebnis |
|--------|----------|
| Klick auf Körper | Kamera zentriert, folgt dem Körper. LOD passt sich an. InfoPanel öffnet. |
| Doppelklick auf Körper | Kamera fliegt zum Körper, zoomt auf passenden Maßstab. |
| Klick ins Leere | Fokus löst sich. InfoPanel schließt. Kamera stoppt Folgen. |
| Rauszoomen über Schwelle | Fokus löst sich automatisch. |

### Kamera-Folgen

Bei aktivem Fokus folgt die Kamera der Weltposition des Körpers pro Frame.

### Fokus-Auflösung

Der Fokus löst sich automatisch, wenn der Zoom so weit herausgezogen wird, dass das fokussierte System visuell zusammenfällt. Der Schwellwert orientiert sich an der Orbit-Größe des fokussierten Körpers relativ zum aktuellen Maßstab.

---

## InfoPanel

### Layout

Rechte Bildschirmseite, ca. **1/3 der Bildschirmbreite**. CanvasLayer-Element über der Karte.

### Inhalt

| Feld | Quelle |
|------|--------|
| Name | `BodyDef.name` |
| Typ / Subtype | `BodyDef.type`, `BodyDef.subtype` |
| Icon | `BodyDef.map_icon` |
| Farbe | `BodyDef.color_rgba` |
| Radius | `BodyDef.radius_km` |
| Orbit-Daten | Aus `BodyDef.motion` (Typ-abhängig) |
| Parent | `BodyDef.parent_id` → aufgelöst zum Namen |
| Map-Tags | `BodyDef.map_tags` |
| Gameplay-Tags | `BodyDef.gameplay_tags` |

> **Erweiterung:** Später kommen Gameplay-Daten hinzu (Handelsrouten, Fraktionen, Missionen), die nicht aus dem `BodyDef` stammen.

### Öffnen / Schließen

- Öffnet bei Fokus auf einen Körper
- Schließt bei Fokus-Auflösung
- Animation via Tween
- Kamera-Offset wird synchron interpoliert

---

## Routenplanung (TBD)

Wird als separater Layer über der NavMap implementiert. Details in eigener Spezifikation.

Vorgesehene Grundfunktionen:
- Auswahl von Start- und Zielkörper
- Visualisierung der Route als Overlay
- Distanz- und Reisezeitberechnung
- Mehrere Wegpunkte

---

## Steuerungs-Übersicht

| Eingabe | Aktion |
|---------|--------|
| Pfeiltasten | Kamera-Pan |
| Maus-Drag (linke Taste) | Kamera-Pan |
| Mausrad | Zoom (`scale_exp` ± 0.1), auf Mausposition |
| `+` / `-` | Zoom (`scale_exp` ± 0.1), auf Mausposition |
| Linksklick auf Körper | Fokus + InfoPanel |
| Doppelklick auf Körper | Fokus + Zoom-To-Fit |
| Linksklick ins Leere | Fokus lösen, InfoPanel schließen |
| Log-Toggle (Taste TBD) | Logarithmische Skala ein/aus |

---

# Teil 3 — LocalMap

Die LocalMap ist die zweite Subklasse der BaseMap. Sie ist ein taktischer Sensorbildschirm, gebunden an das Spielerschiff. Was der Spieler sieht, ist nicht die objektive Wahrheit, sondern das, was seine Instrumente ihm zeigen.

---

## Kerncharakteristik

| Eigenschaft | NavMap | LocalMap |
|-------------|--------|----------|
| Perspektive | Allwissend (Datenbank) | Schiffsgebunden (Sensorik) |
| Kamera | Frei, keine Grenzen | An Schiff gebunden, begrenzter Radius |
| Skalenbereich | Gesamtes System | Eingeschränkt, lokaler Bereich |
| Sichtbarkeit | LOD + Zoom-basiert | Sensorreichweite bestimmt |
| Datenquelle | `SolarSystemModel` direkt | `SolarSystemModel` + Sensor-Filter |
| Zeitverhalten | Echtzeit | Signalverzögerung bei Entfernung |

---

## Kamera

Die LocalMap-Kamera ist an das Spielerschiff gebunden. Sie kann sich nur innerhalb eines definierten Radius vom Schiff entfernen. Das Schiff bleibt immer im oder nahe am sichtbaren Bereich.

| Parameter | Beschreibung |
|-----------|--------------|
| Kamera-Anker | Position des Spielerschiffs |
| Max. Entfernung | Maximaler Abstand der Kamera vom Schiff (TBD) |
| Skalenbereich | Eingeschränkter `scale_exp`-Bereich (TBD) |

---

## Sichtbarkeitslogik

Die Sichtbarkeit auf der LocalMap wird **nicht** durch Zoom und LOD bestimmt, sondern durch die Sensorik des Schiffes:

### Sensorreichweite

Jedes Schiff hat eine definierte Sensorreichweite. Objekte außerhalb dieser Reichweite sind unsichtbar — unabhängig vom Zoom-Level. Innerhalb der Reichweite können Objekte je nach Sensoreigenschaften unterschiedlich detailliert dargestellt werden.

### Signalverzögerung

Informationen über entfernte Objekte erreichen das Schiff mit Verzögerung. Wenn ein Schiff in großer Entfernung seinen Kurs ändert, sieht der Spieler diese Änderung erst nach einer Verzögerung, die proportional zur Entfernung ist.

```
verzögerung_s = entfernung_km / signal_geschwindigkeit_km_s
```

> **Hinweis:** Die genauen Werte für Signalgeschwindigkeit und ob diese Lichtgeschwindigkeit entspricht oder spielerisch angepasst wird, ist Gameplay-Design und wird separat festgelegt.

### Konsequenzen für die Darstellung

- Objekte auf der LocalMap zeigen **nicht** ihre aktuelle Position, sondern ihre Position zum Zeitpunkt des letzten empfangenen Signals
- Je weiter ein Objekt entfernt ist, desto veralteter ist seine angezeigte Position
- Deterministische Körper (Planeten, Monde) können aus der Datenbank vorherberechnet werden — hier wirkt keine Verzögerung
- Nicht-deterministische Objekte (Schiffe, Kontakte) unterliegen der Verzögerung

---

## Szenenbaum (Vorschau)

```
LocalMap (extends BaseMap)
│
├── LocalMapCamera (Camera2D)             ← Schiffsgebunden, begrenzter Radius
│
├── OrbitsLayer (Node2D)                  ← Alle Orbit-Renderer flat, von BaseMap verwaltet
│   └── ... (wie NavMap, gleiche Struktur)
│
├── BodyLayer (Node2D)                    ← Alle Body-Marker flat, von BaseMap verwaltet
│   └── ... (wie NavMap, gleiche Marker)
│
├── SensorLayer (Node2D)                  ← LocalMap-spezifisch
│   ├── SensorRangeIndicator             ← Visualisierung der Sensorreichweite
│   ├── [ContactMarker] (Area2D)         ← Nicht-deterministische Kontakte
│   └── ...
│
└── UILayer (CanvasLayer)                 ← LocalMap-spezifisch
    ├── ShipHUD                           ← Schiffsstatus
    ├── ContactList                       ← Erkannte Kontakte
    └── ...
```

---

## Offene Punkte LocalMap

| Thema | Status |
|-------|--------|
| Sensorreichweite: Datenmodell und Werte | Gameplay-Design, eigene Spec |
| Signalgeschwindigkeit und Verzögerungsformel | Gameplay-Design, eigene Spec |
| Kamera: Max. Entfernung vom Schiff | Bei Implementierung festlegen |
| Skalenbereich (`scale_exp` Min/Max) | Bei Implementierung festlegen |
| Kontakt-System (nicht-deterministische Objekte) | Eigene Spec |
| Interaktion und Steuerung | Bei Implementierung festlegen |
| UI-Layout (ShipHUD, ContactList) | Bei Implementierung festlegen |
| Mining, Kampf, Erkundungs-Overlays | Eigene Specs |

---

# Teil 4 — Offene Punkte (Gesamt)

| Thema | Betrifft | Status |
|-------|----------|--------|
| Min/Max `scale_exp` | NavMap | Bei Implementierung festlegen |
| Min/Max `scale_exp` | LocalMap | Bei Implementierung festlegen |
| Marker-Größenmatrix: Pixelwerte | BaseMap | Export-Variablen, im Editor tweaken |
| Marker-Stufenschwellen (`scale_exp`) | BaseMap | Export-Variablen, im Editor tweaken |
| Schwellwerte für LOD-Sichtbarkeit (px) | NavMap | Bei Implementierung festlegen |
| Schwellwerte für Fokus-Auflösung | NavMap | Bei Implementierung festlegen |
| Schwellwerte für Orbit-Übertreibung | NavMap | Bei Implementierung festlegen |
| Log-Skala: exakte Transformationsformel | NavMap | Bei Implementierung festlegen |
| Log-Skala: Wertebereich `log_scale_factor` | NavMap | Bei Implementierung festlegen |
| Routenplanung: Interaktionsmodell | NavMap | Eigene Spec |
| Label-Einblendung: ab welchem Zoom | NavMap | Bei Implementierung festlegen |
| Tastenbelegung Log-Toggle | NavMap | Bei Implementierung festlegen |
| Tween-Dauer Panel + Kamera-Offset | NavMap | Bei Implementierung festlegen |
| Sensor-Datenmodell | LocalMap | Eigene Spec |
| Signalverzögerungs-Gameplay | LocalMap | Eigene Spec |
| Kontakt-System | LocalMap | Eigene Spec |

---

# Teil 5 — Design-Prinzipien

- **BaseMap liefert Bausteine, Subklassen treffen Entscheidungen.** Die BaseMap rendert und rechnet, hat aber keine Meinung über Sichtbarkeit, Kamera oder Interaktion.
- **Daten-getrieben.** Die Karte rendert, was das `SolarSystemModel` liefert. Keine hart kodierten Körper oder Positionen.
- **Lineare Ehrlichkeit.** Im Standardmodus sind Abstände maßstabsgetreu. Übertreibungen und Log-Skala sind bewusste, vom Spieler gesteuerte Abweichungen.
- **Icons als Marker, nicht als Abbilder.** Körper werden durch symbolische Marker dargestellt, nicht durch maßstabsgetreue Kreise. Ihre Größe folgt einer Typ-Hierarchie und Zoom-Stufe, nicht dem physischen Radius.
- **Performance über Vollständigkeit.** Nur rendern, was der Spieler sehen kann.
- **NavMap = Allwissender Atlas.** Keine physikalischen Wahrnehmungsgrenzen. Alles Bekannte ist zugänglich.
- **LocalMap = Sensorbildschirm.** Gebunden an Schiffsposition, Sensorreichweite und Signalverzögerung. Was der Spieler sieht, ist eine Interpretation der Realität, keine objektive Wahrheit.
