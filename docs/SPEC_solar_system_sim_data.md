# Solar System Simulation Data — Spezifikation

> Datenformat-Referenz für `solar_system_sim_data.json`
> Stand: 2026-03-14

---

## Überblick

Die Datei beschreibt alle deterministisch simulierten Himmelskörper und Strukturen des Sonnensystems. Sie wird beim Start von `CoreDataLoader` gelesen und in `BodyDef`-Objekte überführt, die vom `SolarSystemModel` zur Positionsberechnung verwendet werden. Die Simulation ist vollständig deterministisch — alle Positionen ergeben sich aus den Bahndaten und der aktuellen Simulationszeit (SST).

---

## Dateistruktur

```json
{
  "bodies": [ <BodyEntry>, <BodyEntry>, ... ]
}
```

Die Datei enthält ein einziges Root-Objekt mit dem Schlüssel `bodies`, einem Array aus Body-Einträgen. Die Reihenfolge im Array ist nicht relevant — die Topologie wird zur Laufzeit per `parent_id` aufgelöst (Kahn-Algorithmus).

---

## Body-Entry Schema

| Feld             | Typ              | Pflicht | Beschreibung |
|------------------|------------------|---------|--------------|
| `id`             | `string`         | ja      | Eindeutige technische ID. Lowercase, snake_case. Wird als Schlüssel im gesamten System verwendet. |
| `name`           | `string`         | ja      | Anzeigename für UI und Karte. |
| `type`           | `string`         | ja      | Hauptkategorie. Siehe Abschnitt *Type-System*. |
| `subtype`        | `string`         | ja      | Feinklassifikation innerhalb des Types. Siehe Abschnitt *Subtype-System*. |
| `parent_id`      | `string`         | ja      | ID des übergeordneten Körpers. Leer (`""`) für Wurzelobjekte (z. B. die Sonne). Muss auf eine existierende `id` verweisen. |
| `radius_km`      | `float`          | ja      | Physischer Radius in Kilometern. |
| `mu_km3_s2`      | `float`          | ja      | Standard-Gravitationsparameter μ = G·m in km³/s². `0.0` für masselose Strukturen. |
| `map_icon`       | `string`         | ja      | Symbolschlüssel für die Kartendarstellung. |
| `color_rgba`     | `float[4]`       | ja      | Farbe als RGBA-Array, Wertebereich jeweils 0.0–1.0. |
| `motion`         | `MotionEntry`    | ja      | Bewegungsdefinition. Siehe Abschnitt *Motion-Modelle*. |
| `map_tags`       | `string[]`       | ja      | Tags für Kartenfilterung und Gruppierung. Siehe Abschnitt *Map-Tag-System*. |
| `gameplay_tags`  | `string[]`       | ja      | Tags für Gameplay-Logik. Aktuell spärlich genutzt, zur freien Erweiterung vorgesehen. |
| `meta`           | `object`         | nein    | Optionale Zusatzdaten (z. B. `mass_kg`, `density_kg_m3`). Wird von der Simulation nicht gelesen, dient als Referenz. |

### Konventionen für `id`

- Immer lowercase snake_case
- Natürliche Körper verwenden ihren Eigennamen: `mercury`, `titan`, `io`
- Strukturen verwenden beschreibende Zusammensetzungen: `earth_leo_shipyard`, `ceres_freeport`
- Die ID der Erde ist `terra` (nicht `earth`) — alle `parent_id`-Referenzen müssen `"terra"` verwenden

### Konventionen für `map_icon`

| Wert       | Verwendung |
|------------|------------|
| `sun`      | Zentralgestirn |
| `planet`   | Planeten |
| `dwarf`    | Zwergplaneten |
| `moon`     | Monde |
| `station`  | Stationen, Werften, Außenposten |
| `object`   | Navigationspunkte und sonstige kleine Objekte |
| `struct`   | Generischer Struct-Fallback |

---

## Type-System

Der `type` bestimmt die Hauptkategorie eines Eintrags und steuert die Zuordnung im `SolarSystemModel._sim_objects`-Dictionary.

| Type     | Bedeutung | Anzahl |
|----------|-----------|--------|
| `star`   | Zentralgestirn des Systems | 1 |
| `planet` | Vollwertige Planeten, orbiten den Stern | 9 |
| `dwarf`  | Zwergplaneten, orbiten den Stern | 5 |
| `moon`   | Natürliche Satelliten, orbiten einen Planeten oder Zwergplaneten | 32 |
| `struct` | Künstliche Strukturen (Stationen, Relays, Werften etc.) | 26 |

---

## Subtype-System

Jeder `type` hat eine eigene, einachsige Subtype-Taxonomie. Die Achse ist pro Type konsistent.

### star — Spektralklasse

| Subtype   | Beschreibung |
|-----------|--------------|
| `g_type`  | Gelber Zwerg (Hauptreihenstern) |

### planet — Komposition

Klassifikation nach physikalischer Zusammensetzung, nicht nach Größe oder Position.

| Subtype       | Beschreibung | Beispiele |
|---------------|--------------|-----------|
| `terrestrial` | Gesteinsplanet | Mercury, Venus, Earth, Mars |
| `gas_giant`   | Gasriese (H/He-dominiert) | Jupiter, Saturn |
| `ice_giant`   | Eisriese (Wasser/Ammoniak/Methan-dominiert) | Uranus, Neptune |
| `sub_neptune` | Zwischen Terrestrisch und Eisriese | Planet Nine |

### dwarf — Taxonomie

Klassifikation nach astronomischer Einordnung.

| Subtype         | Beschreibung | Beispiele |
|-----------------|--------------|-----------|
| `asteroid_dwarf`| Zwergplanet im Asteroidengürtel | Ceres |
| `plutoid`       | Transneptunischer Zwergplanet | Pluto, Haumea, Makemake, Eris |

### moon — Größe / Bedeutung

Klassifikation nach physikalischer Größe und Bedeutung. Die Orbitalzone wird separat über Map-Tags (`inner_orbit`, `outer_orbit`) abgebildet.

| Subtype      | Beschreibung | Beispiele |
|--------------|--------------|-----------|
| `major_moon` | Großer, bedeutender Mond (typisch ≥ ~150 km Radius) | Moon, Io, Europa, Titan, Triton, Charon |
| `minor_moon` | Kleiner Mond | Phobos, Deimos, Metis, Himalia, Phoebe |

### struct — Funktion

Klassifikation nach der Rolle der Struktur.

| Subtype            | Beschreibung | Beispiele |
|--------------------|--------------|-----------|
| `station`          | Bemannte Station, Drehkreuz | Venus High Anchor, Ceres Freeport |
| `shipyard`         | Werft / Produktionsstätte | Earth LEO Shipyard, Phoebe Black Yard |
| `outpost`          | Kleiner Außenposten, oft in abgelegener Position | Moon Far Side Outpost, Eris Edge Outpost |
| `relay`            | Kommunikations- oder Sensor-Relais | Mercury Polar Relay, Inner System Junction |
| `navigation_point` | Navigationsbake, Referenzpunkt, Transferknoten | Sol Central Beacon, Earth L1 Transfer Node |

---

## Motion-Modelle

Jeder Body hat genau eine `motion`-Definition, die sein Bewegungsmodell beschreibt.

```json
{
  "model": "<model_name>",
  "params": { ... }
}
```

### `fixed` — Stationäre Position

Feste Position relativ zum Elternobjekt. Geeignet für das Zentralgestirn und stationäre Strukturen.

| Parameter | Typ     | Beschreibung |
|-----------|---------|--------------|
| `x_km`    | `float` | X-Position relativ zum Parent in km |
| `y_km`    | `float` | Y-Position relativ zum Parent in km |

### `circular` — Kreisbahn

Gleichförmige Kreisbewegung um das Elternobjekt. Für Monde mit niedriger Exzentrizität und orbitale Strukturen.

| Parameter           | Typ     | Beschreibung |
|---------------------|---------|--------------|
| `orbital_radius_km` | `float` | Bahnradius in km |
| `phase_rad`         | `float` | Startphasenwinkel in Radiant bei t=0 |
| `period_s`          | `float` | Umlaufperiode in Sekunden |
| `clockwise`         | `bool`  | `true` = im Uhrzeigersinn (retrograd) |

### `kepler2d` — Vereinfachte Kepler-Ellipse (2D)

Elliptische Bahn in der Ebene, gelöst über die Kepler-Gleichung. Für Planeten und exzentrische Monde.

| Parameter                  | Typ     | Beschreibung |
|----------------------------|---------|--------------|
| `a_km`                     | `float` | Große Halbachse in km |
| `e`                        | `float` | Exzentrizität (0 = Kreis, < 1 = Ellipse) |
| `arg_pe_rad`               | `float` | Argument des Periapsis in Radiant |
| `mean_anomaly_epoch_rad`   | `float` | Mittlere Anomalie zum Epochenzeitpunkt in Radiant |
| `epoch_tt_s`               | `float` | Epochen-Referenzzeit in SST-Sekunden |
| `clockwise`                | `bool`  | `true` = im Uhrzeigersinn (retrograd) |

Die Umlaufperiode wird zur Laufzeit aus `a_km` und dem `mu_km3_s2` des Elternkörpers berechnet.

### `lagrange` — Lagrange-Punkt

Position an einem der fünf Lagrange-Punkte zweier Referenzkörper. Für Strukturen an gravitativen Gleichgewichtspunkten.

| Parameter      | Typ      | Beschreibung |
|----------------|----------|--------------|
| `primary_id`   | `string` | ID des Primärkörpers (z. B. Stern) |
| `secondary_id` | `string` | ID des Sekundärkörpers (z. B. Planet) |
| `point`        | `int`    | Lagrange-Punkt: 1, 2, 3, 4 oder 5 |

Die Position wird zur Laufzeit aus den aktuellen Positionen beider Referenzkörper und deren Massenverhältnis (via μ) berechnet.

---

## Map-Tag-System

Map-Tags sind ein flaches, mehrdimensionales Tagging-System für Kartenfilterung und Gruppierung. Jeder Body trägt ein oder mehrere Tags. Die Tags folgen drei orthogonalen Achsen plus Sonderkategorien.

### Achse 1: Systemzone

Grobe räumliche Einordnung im Sonnensystem.

| Tag              | Bedeutung |
|------------------|-----------|
| `inner_system`   | Innerhalb des Asteroidengürtels (Sonne bis Mars, inkl. Ceres) |
| `outer_system`   | Außerhalb des Asteroidengürtels (Jupiter bis Kuipergürtel) |
| `trans_neptunian` | Jenseits der Neptunbahn (aktuell nur Planet Nine) |

### Achse 2: Planetensystem

Zugehörigkeit zu einem spezifischen Planetensystem. Wird vom Planeten selbst und allen seinen Monden und Strukturen getragen.

| Tag                 | System |
|---------------------|--------|
| `mercurian_system`  | Mercury und Begleiter |
| `venusian_system`   | Venus und Begleiter |
| `terran_system`     | Earth und Begleiter (Moon, Structs) |
| `martian_system`    | Mars und Begleiter |
| `jovian_system`     | Jupiter und Begleiter |
| `saturnian_system`  | Saturn und Begleiter |
| `uranian_system`    | Uranus und Begleiter |
| `neptunian_system`  | Neptune und Begleiter |

### Achse 3: Signifikanz

Größenbasierte Einstufung für Kartendarstellung und Zoom-Level.

| Tag           | Bedeutung |
|---------------|-----------|
| `major_body`  | Stern, Planeten, Zwergplaneten — physisch bedeutende Objekte |
| `minor_body`  | Monde, Strukturen — untergeordnete Objekte |
| `landmark`    | Gameplay-relevanter Orientierungspunkt (kein physisch großer Körper) |

### Sonderkategorien

| Tag              | Bedeutung |
|------------------|-----------|
| `solar_orbit`    | Direkt heliozentrisch — orbitet die Sonne ohne Zugehörigkeit zu einem Planetensystem |
| `asteroid_belt`  | Im Asteroidengürtel (zwischen Mars und Jupiter) |
| `kuiper_belt`    | Im Kuipergürtel (transneptunisch) |
| `inner_orbit`    | Mond auf einer inneren, planetennahen Bahn |
| `outer_orbit`    | Mond auf einer äußeren, planetenfernen oder irregulären Bahn |

### Tag-Kombinationsregeln

- Jeder Body hat **mindestens einen Zonen-Tag** (`inner_system` oder `outer_system`)
- Jeder Body innerhalb eines Planetensystems hat den entsprechenden **System-Tag**
- Jeder Body hat genau einen **Signifikanz-Tag** (`major_body`, `minor_body`, oder `landmark`)
- Gürtel-Tags (`asteroid_belt`, `kuiper_belt`) werden zusätzlich vergeben wo zutreffend
- Orbital-Tags (`inner_orbit`, `outer_orbit`) werden nur bei Monden vergeben und ergänzen den Subtype

---

## Gameplay-Tags

Das `gameplay_tags`-Array ist für spiellogische Klassifikation reserviert und wird von der orbitalen Simulation nicht ausgewertet. Es kann frei für Systeme wie Handel, Fraktionszugehörigkeit, Missionen etc. erweitert werden.

Aktuell vergebene Tags:

| Tag           | Verwendung |
|---------------|------------|
| `nav_network` | Teil des Navigationsnetzwerks |

---

## Eltern-Kind-Hierarchie

Die Baumstruktur wird über `parent_id` definiert. `SolarSystemModel` löst die Topologie per Kahn-Algorithmus auf und garantiert, dass jeder Elternknoten vor seinen Kindern berechnet wird.

```
sun (fixed @ 0,0)
├── mercury (kepler2d)
│   └── mercury_polar_relay (circular)
├── venus (kepler2d)
│   └── venus_high_anchor (circular)
├── terra (kepler2d)
│   ├── moon (circular)
│   │   └── moon_far_side_outpost (circular)
│   ├── earth_leo_shipyard (circular)
│   └── earth_l1_transfer_node (circular)
├── mars (kepler2d)
│   ├── phobos (circular)
│   ├── deimos (circular)
│   ├── mars_low_orbit_station (circular)
│   └── phobos_ring_node (circular)
├── ceres (kepler2d)
│   ├── ceres_freeport (circular)
│   └── ceres_mass_driver_yard (circular)
├── jupiter (kepler2d)
│   ├── metis (circular)
│   ├── amalthea (circular)
│   ├── thebe (circular)
│   ├── io (circular)
│   ├── europa (circular)
│   │   └── europa_gate_station (circular)
│   ├── ganymede (circular)
│   │   └── ganymede_high_yard (circular)
│   ├── callisto (circular)
│   │   └── callisto_deep_dock (circular)
│   ├── himalia (kepler2d)
│   ├── elara (kepler2d)
│   ├── pasiphae (kepler2d, retrograd)
│   ├── jupiter_inner_relay (circular)
│   ├── himalia_remote_outpost (kepler2d)
│   └── pasiphae_watch_relay (kepler2d, retrograd)
├── saturn (kepler2d)
│   ├── janus (circular)
│   ├── mimas (circular)
│   ├── enceladus (circular)
│   ├── tethys (circular)
│   ├── dione (circular)
│   ├── rhea (circular)
│   ├── titan (circular)
│   │   └── titan_transfer_node (circular)
│   ├── hyperion (kepler2d)
│   ├── iapetus (circular)
│   ├── phoebe (kepler2d, retrograd)
│   ├── saturn_ring_hub (circular)
│   └── phoebe_black_yard (kepler2d, retrograd)
├── uranus (kepler2d)
│   ├── miranda (circular)
│   ├── ariel (circular)
│   ├── umbriel (circular)
│   ├── titania (circular)
│   └── oberon (circular)
├── neptune (kepler2d)
│   ├── proteus (circular)
│   ├── triton (circular, retrograd)
│   ├── nereid (kepler2d)
│   └── nereid_far_marker (kepler2d)
├── planet_nine (kepler2d)
├── pluto (kepler2d)
│   └── charon (circular)
├── haumea (kepler2d)
├── makemake (kepler2d)
├── eris (kepler2d)
│   └── eris_edge_outpost (kepler2d)
├── sol_central_beacon (fixed)
├── inner_system_junction (fixed)
├── mars_cycler_anchor (fixed)
├── belt_trade_crossing (fixed)
├── outer_system_reference_zero (fixed)
└── nav_relay_l4_terra (lagrange L4: sun–terra)
```

### Validierungsregeln

- Jeder `parent_id` muss auf eine existierende `id` verweisen oder leer sein
- Es dürfen keine zyklischen Abhängigkeiten entstehen
- Die ID der Erde ist `terra` — Referenzen als `"earth"` sind ungültig
- Lagrange-Objekte benötigen zusätzlich gültige `primary_id` und `secondary_id` in ihren Motion-Params

---

## Meta-Objekt

Das optionale `meta`-Objekt enthält physikalische Referenzdaten, die von der Simulation nicht gelesen werden.

| Feld              | Typ     | Beschreibung |
|-------------------|---------|--------------|
| `mass_kg`         | `float` | Masse in Kilogramm |
| `density_kg_m3`   | `float` | Dichte in kg/m³ (optional) |

---

## Hinweise zur Erweiterung

- **Neue Körper** müssen alle Pflichtfelder ausfüllen und einen gültigen `parent_id` haben
- **Neue Subtypes** sollten die jeweilige Achse ihres Types respektieren (Komposition für Planeten, Taxonomie für Dwarfs, Größe für Monde, Funktion für Structs)
- **Neue Map-Tags** sollten einer der bestehenden Achsen zugeordnet werden oder eine neue, dokumentierte Kategorie bilden
- **Retrograde Bahnen** werden durch `"clockwise": true` markiert und sind sowohl bei `circular` als auch bei `kepler2d` möglich
