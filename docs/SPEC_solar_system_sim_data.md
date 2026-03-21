# Solar System Simulation Data — Spezifikation

> Datenformat-Referenz für alle Simulation-Datenbankdateien
> Stand: 2026-03-21

---

## Überblick

Die Simulation nutzt vier JSON-Dateien als Datenbank. Sie werden beim Start von `CoreDataLoader` bzw. `MapDataLoader` gelesen und in typisierte Def-Objekte überführt.

| Datei | Root-Key | Def-Klasse | Loader |
| --- | --- | --- | --- |
| `res://data/solar_system_data.json` | `"bodies"` | `BodyDef` | `CoreDataLoader` |
| `res://data/struct_data.json` | `"structs"` | `BodyDef` | `CoreDataLoader` |
| `res://data/belt_data.json` | `"belts"` | `BeltDef` | `MapDataLoader` |
| `res://data/zone_data.json` | `"zones"` | `ZoneDef` | `MapDataLoader` |

Alle Dateien folgen dem gleichen Grundprinzip: ein Root-Objekt mit einem Array unter dem jeweiligen Schlüssel.

```json
{ "bodies":  [ <BodyEntry>, ... ] }
{ "structs": [ <BodyEntry>, ... ] }
{ "belts":   [ <BeltEntry>, ... ] }
{ "zones":   [ <ZoneEntry>, ... ] }
```

---

## 1 — BodyDef

Beschreibt einen natürlichen Himmelskörper oder eine künstliche Struktur. Bodies aus `solar_system_data.json` und Structs aus `struct_data.json` nutzen dasselbe Schema — sie werden intern zu einem gemeinsamen Array zusammengeführt.

### 1.1 Felder

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | `string` | ja | Eindeutige technische ID. Lowercase snake_case. Wird systemweit als Schlüssel genutzt. |
| `name` | `string` | ja | Anzeigename für UI und Karte. |
| `type` | `string` | ja | Hauptkategorie. Siehe [Abschnitt 1.3](#13-type-system). |
| `subtype` | `string` | ja | Feinklassifikation innerhalb des Types. Siehe [Abschnitt 1.4](#14-subtype-system). |
| `parent_id` | `string` | ja | ID des Elternkörpers. Leer `""` für Wurzelobjekte. Muss auf eine existierende `id` verweisen. |
| `radius_km` | `float` | ja | Physischer Radius in km. `0.0` für masselose Strukturen. |
| `mu_km3_s2` | `float` | ja | Gravitationsparameter μ = G·m in km³/s². `0.0` für masselose Strukturen. |
| `map_icon` | `string` | ja | Icon-Schlüssel für die Kartendarstellung. Siehe [Abschnitt 1.2](#12-map_icon). |
| `color_rgba` | `float[4]` | ja | Farbe als RGBA-Array, Wertebereich 0.0–1.0. |
| `motion` | `MotionEntry` | ja | Bewegungsdefinition. Siehe [Abschnitt 1.5](#15-motion-modelle). |
| `map_tags` | `string[]` | ja | Tags für Kartenfilterung. Siehe [Abschnitt 1.6](#16-tag-taxonomie). |
| `gameplay_tags` | `string[]` | ja | Tags für Spiellogik. Siehe [Abschnitt 1.7](#17-gameplay-tags). |
| `meta` | `object` | nein | Physikalische Referenzdaten. Wird von der Simulation nicht gelesen. |

### 1.2 `map_icon`

| Wert | Verwendung |
| --- | --- |
| `sun` | Zentralgestirn |
| `planet` | Planeten und Zwergplaneten |
| `moon` | Monde |
| `station` | Stationen, Werften, Relais, Außenposten |
| `object` | Navigationspunkte und sonstige Objekte |

### 1.3 Type-System

Der `type` steuert die interne Sortierung im `SolarSystemModel`.

| Type | Bedeutung |
| --- | --- |
| `star` | Zentralgestirn. Exakt eines pro Simulation. Hat `parent_id: ""`. |
| `planet` | Vollwertiger Planet. Orbitet direkt den Stern. |
| `dwarf` | Zwergplanet. Orbitet direkt den Stern. |
| `moon` | Natürlicher Satellit. Orbitet einen Planeten oder Zwergplaneten. |
| `struct` | Künstliche Struktur. Kann jeden Körper als Elternteil haben. |

### 1.4 Subtype-System

Jeder Type hat eine eigene Subtype-Achse. Die Achse ist pro Type konsistent.

#### `star` — Spektralklasse

| Subtype | Beschreibung |
| --- | --- |
| `g_type` | Gelber Zwerg (Hauptreihenstern) |

#### `planet` — Komposition

Klassifikation nach physikalischer Zusammensetzung.

| Subtype | Beschreibung | Beispiele |
| --- | --- | --- |
| `terrestrial` | Gesteinsplanet | Mercury, Venus, Terra, Mars |
| `gas_giant` | Gasriese (H/He-dominiert) | Jupiter, Saturn |
| `ice_giant` | Eisriese (Wasser/Ammoniak/Methan) | Uranus, Neptune |
| `sub_neptune` | Zwischen terrestrisch und Eisriese | Planet Nine |

#### `dwarf` — Taxonomie

Klassifikation nach astronomischer Einordnung.

| Subtype | Beschreibung | Beispiele |
| --- | --- | --- |
| `asteroid_dwarf` | Zwergplanet im Asteroidengürtel | Ceres |
| `plutoid` | Transneptunischer Zwergplanet | Pluto, Haumea, Makemake, Eris |

#### `moon` — Größe und Bedeutung

| Subtype | Beschreibung | Beispiele |
| --- | --- | --- |
| `major_moon` | Großer, bedeutender Mond (typisch ≥ 150 km Radius) | Moon, Io, Europa, Titan, Triton, Charon |
| `minor_moon` | Kleiner Mond oder irregulärer Satellit | Phobos, Deimos, Himalia, Phoebe |

Die Orbitalzone (innen/außen) wird nicht im Subtype abgebildet, sondern über `map_tags` (`inner_orbit`, `outer_orbit`).

#### `struct` — Funktion

| Subtype | Beschreibung | Beispiele |
| --- | --- | --- |
| `station` | Bemannte Station, Drehkreuz | Venus High Anchor, Ceres Freeport |
| `shipyard` | Werft / Produktionsstätte | Earth LEO Shipyard, Phoebe Black Yard |
| `outpost` | Kleiner Außenposten, abgelegene Position | Moon Far Side Outpost, Eris Edge Outpost |
| `relay` | Kommunikations- oder Sensor-Relais | Mercury Polar Relay |
| `navigation_point` | Navigationsbake, Transferknoten, Referenzpunkt | Sol Central Beacon, Earth L1 Transfer Node |

### 1.5 Motion-Modelle

Jeder Body hat exakt eine `motion`-Definition.

```json
{
  "model": "<model_name>",
  "params": { ... }
}
```

#### `fixed` — Stationäre Position

Feste Position relativ zum Elternkörper. Zeitunabhängig. Für Zentralgestirn und ortsfeste Strukturen.

| Parameter | Typ | Beschreibung |
| --- | --- | --- |
| `x_km` | `float` | X-Offset zum Elternkörper in km |
| `y_km` | `float` | Y-Offset zum Elternkörper in km |

#### `circular` — Kreisbahn

Gleichförmige Kreisbewegung. Für Monde mit niedriger Exzentrizität und orbitale Strukturen.

| Parameter | Typ | Beschreibung |
| --- | --- | --- |
| `orbital_radius_km` | `float` | Bahnradius in km |
| `phase_rad` | `float` | Startwinkel in Radiant bei t = 0 |
| `period_s` | `float` | Umlaufperiode in Sekunden |
| `clockwise` | `bool` | `true` = Uhrzeigersinn (retrograd) |

#### `kepler2d` — Kepler-Ellipse (2D)

Physikalisch korrekte Ellipsenbahn in der Ebene. Für Planeten und exzentrische Monde. Die Periode wird aus `a_km` und `mu_km3_s2` des Elternkörpers berechnet. Die exzentrische Anomalie wird per Newton-Raphson gelöst (max. 12 Iterationen).

| Parameter | Typ | Beschreibung |
| --- | --- | --- |
| `a_km` | `float` | Große Halbachse in km |
| `e` | `float` | Exzentrizität (0 = Kreis, 0–1 = Ellipse). Wird auf 0.999999 geclampt. |
| `arg_pe_rad` | `float` | Argument des Periapsis in Radiant |
| `mean_anomaly_epoch_rad` | `float` | Mittlere Anomalie zum Epochenzeitpunkt in Radiant |
| `epoch_tt_s` | `float` | Epochen-Referenzzeit in SST-Sekunden |
| `clockwise` | `bool` | `true` = Uhrzeigersinn (retrograd) |

#### `lagrange` — Lagrange-Punkt

Position an einem der fünf Lagrange-Punkte zweier Referenzkörper. Für Strukturen an gravitativen Gleichgewichtspunkten. Die Position wird zur Laufzeit aus den aktuellen Positionen und dem Massenverhältnis beider Körper berechnet.

| Parameter | Typ | Beschreibung |
| --- | --- | --- |
| `primary_id` | `string` | ID des Primärkörpers (z. B. Stern) |
| `secondary_id` | `string` | ID des Sekundärkörpers (z. B. Planet) |
| `point` | `int` | Lagrange-Punkt: 1–5 |

L1/L2 nutzen eine Hill-Radius-Approximation. L4/L5 liegen exakt ±60° vor/hinter dem Sekundärkörper.

### 1.6 Tag-Taxonomie

Map-Tags sind ein flaches, mehrdimensionales Tagging-System für Kartenfilterung, Scope-Matching und Gruppierung. Die Tags folgen vier orthogonalen Achsen.

#### Achse 1: Systemzone

Grobe räumliche Einordnung im Sonnensystem.

| Tag | Bedeutung |
| --- | --- |
| `inner_system` | Innerhalb des Asteroidengürtels (Sonne bis Mars, inkl. Ceres) |
| `outer_system` | Außerhalb des Asteroidengürtels (Jupiter bis Kuipergürtel) |
| `trans_neptunian` | Jenseits der Neptunbahn (Planet Nine, Scattered Disc) |

#### Achse 2: Planetensystem

Zugehörigkeit zu einem konkreten Planetensystem. Wird vom Planeten selbst und allen seinen Monden und Strukturen getragen.

| Tag | System |
| --- | --- |
| `mercurian_system` | Mercury und Begleiter |
| `venusian_system` | Venus und Begleiter |
| `terran_system` | Terra (Earth) und Begleiter |
| `martian_system` | Mars und Begleiter |
| `jovian_system` | Jupiter und Begleiter |
| `saturnian_system` | Saturn und Begleiter |
| `uranian_system` | Uranus und Begleiter |
| `neptunian_system` | Neptune und Begleiter |

Sonderfall: `solar_orbit` für Körper, die direkt heliozentrisch orbiten und keinem Planetensystem angehören.

#### Achse 3: Signifikanz

Granulare Einstufung nach Typ und Bedeutung. Jeder Body trägt genau einen dieser Tags.

| Tag | Wird vergeben an |
| --- | --- |
| `major_body` | Stern und alle vollwertigen Planeten |
| `minor_body` | Alle Zwergplaneten |
| `major_moon` | Monde mit Subtype `major_moon` |
| `minor_moon` | Monde mit Subtype `minor_moon` |
| `major_struct` | Strukturen mit Subtype `station` oder `shipyard` |
| `minor_struct` | Strukturen mit Subtype `relay`, `outpost` oder `navigation_point` |

#### Achse 4: Orbitalzone (nur Monde)

Feinklassifikation der Bahnposition innerhalb eines Planetensystems.

| Tag | Bedeutung |
| --- | --- |
| `inner_orbit` | Mond auf einer inneren, planetennahen Bahn |
| `outer_orbit` | Mond auf einer äußeren, planetenfernen oder irregulären Bahn |

#### Sonderkategorien

| Tag | Bedeutung |
| --- | --- |
| `solar_orbit` | Direkt heliozentrisch, ohne Planetensystem-Zugehörigkeit |
| `asteroid_belt` | Körper im Asteroidengürtel (zwischen Mars und Jupiter) |
| `kuiper_belt` | Körper im Kuipergürtel (transneptunisch) |

#### Kombinationsregeln

- Jeder Body hat **genau einen Zonen-Tag** (`inner_system`, `outer_system` oder `trans_neptunian`)
- Jeder Body innerhalb eines Planetensystems trägt den entsprechenden **System-Tag**
- Direkt heliozentrische Körper ohne Planetenbindung tragen `solar_orbit` statt eines System-Tags
- Jeder Body hat **genau einen Signifikanz-Tag** aus Achse 3
- Der Signifikanz-Tag ergibt sich deterministisch aus `type` und `subtype` — er muss nicht manuell gewählt werden
- Monde tragen zusätzlich einen **Orbital-Tag** (`inner_orbit` oder `outer_orbit`)

### 1.7 Gameplay-Tags

Das `gameplay_tags`-Array wird von der orbitalen Simulation nicht ausgewertet und steht für Spiellogik frei zur Verfügung.

| Tag | Verwendung |
| --- | --- |
| `nav_network` | Teil des aktiven Navigationsnetzwerks |

### 1.8 `meta`-Objekt (optional)

Physikalische Referenzdaten für Dokumentationszwecke. Wird von keinem System gelesen.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `mass_kg` | `float` | Masse in Kilogramm |
| `density_kg_m3` | `float` | Dichte in kg/m³ |

### 1.9 ID-Konventionen

- Immer **lowercase snake_case**
- Natürliche Körper verwenden ihren Eigennamen: `mercury`, `titan`, `io`
- Die Erde heißt `terra` — Referenzen als `"earth"` sind ungültig
- Strukturen nutzen beschreibende Zusammensetzungen: `earth_leo_shipyard`, `ceres_freeport`

### 1.10 Validierungsregeln

- Jede `parent_id` muss auf eine existierende `id` verweisen oder leer sein
- Es dürfen keine zyklischen Abhängigkeiten entstehen (Kahn-Algorithmus bricht mit Fehler ab)
- Lagrange-Bodies müssen gültige `primary_id` und `secondary_id` in den Motion-Params tragen
- Der Stern (`type: "star"`) ist exakt einmal vorhanden und hat `parent_id: ""`

---

## 2 — BeltDef

Beschreibt eine prozedurale Punktwolke für Gürtel, Trojaner-Wolken oder Planetenringe. Wird von `MapDataLoader` geladen und ausschließlich vom `BeltRenderer` genutzt. Hat keine Auswirkung auf die Positionssimulation.

### 2.1 Felder

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | `string` | ja | Eindeutige ID. Lowercase snake_case. |
| `name` | `string` | ja | Anzeigename. |
| `parent_id` | `string` | ja | ID des Zentralkörpers (Mittelpunkt des Gürtels). |
| `reference_body_id` | `string` | ja | Referenzkörper für Trojaner-Positionierung. Leer `""` für vollständige Ringe. |
| `inner_radius_km` | `float` | ja | Innerer Bahnradius des Gürtels in km. |
| `outer_radius_km` | `float` | ja | Äußerer Bahnradius des Gürtels in km. |
| `angular_offset_rad` | `float` | ja | Startwinkel in Radiant (0 = positive X-Achse). Bei Trojanern: Offset relativ zum Referenzkörper. |
| `angular_spread_rad` | `float` | ja | Winkelbreite in Radiant. `TAU` (≈ 6.2832) = vollständiger Ring. |
| `min_points` | `int` | ja | Anzahl Partikel bei niedrigstem LOD. |
| `max_points` | `int` | ja | Anzahl Partikel bei höchstem LOD. |
| `seed` | `int` | ja | RNG-Seed. Gleicher Seed = identische Punktwolke. Jeder Eintrag braucht einen eigenen Seed. |
| `color_rgba` | `float[4]` | ja | Partikelfarbe als RGBA-Array (0.0–1.0). Alpha kontrolliert Transparenz. |
| `apply_rotation` | `bool` | ja | `false` für Trojaner — Layer-Rotation würde die Wolke aus der L4/L5-Position driften lassen. |

### 2.2 Beispiel — vollständiger Gürtel

```json
{
  "id": "asteroid_belt",
  "name": "Asteroid Belt",
  "parent_id": "sun",
  "reference_body_id": "",
  "inner_radius_km": 329115316,
  "outer_radius_km": 478713187,
  "angular_offset_rad": 0.0,
  "angular_spread_rad": 6.2832,
  "min_points": 400,
  "max_points": 1400,
  "seed": 1,
  "color_rgba": [0.55, 0.08, 0.08, 0.50],
  "apply_rotation": true
}
```

### 2.3 Beispiel — Trojaner-Wolke

```json
{
  "id": "jupiter_trojans_l4",
  "name": "Jupiter Trojans L4 (Greeks)",
  "parent_id": "sun",
  "reference_body_id": "jupiter",
  "inner_radius_km": 700000000,
  "outer_radius_km": 860000000,
  "angular_offset_rad": 0.611,
  "angular_spread_rad": 0.873,
  "min_points": 80,
  "max_points": 400,
  "seed": 4,
  "color_rgba": [0.60, 0.28, 0.05, 0.60],
  "apply_rotation": false
}
```

**Belegte Seeds:** 1 (Asteroid Belt), 2 (Kuiper Belt), 3 (Scattered Disc), 4 (Jupiter Trojans L4), 5 (Jupiter Trojans L5), 6 (Oort Cloud).

---

## 3 — ZoneDef

Beschreibt eine halbtransparente Farbfläche für räumliche Zonen (Strahlungsgürtel, Magnetosphären, Gravitationszonen). Wird von `MapDataLoader` geladen und ausschließlich vom `ZoneRenderer` genutzt. Hat keine Auswirkung auf die Positionssimulation.

### 3.1 Felder

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | `string` | ja | Eindeutige ID. Lowercase snake_case. |
| `name` | `string` | ja | Anzeigename. |
| `parent_id` | `string` | ja | ID des Zentralkörpers (Mittelpunkt der Zone). |
| `zone_type` | `string` | ja | Semantischer Typ. Siehe [Abschnitt 3.2](#32-zone-typen). |
| `geometry` | `string` | ja | Geometrieform: `"circle"` oder `"ring"`. |
| `radius_km` | `float` | bei `geometry: "circle"` | Radius des gefüllten Kreises in km. |
| `inner_radius_km` | `float` | bei `geometry: "ring"` | Innenradius des Rings in km. |
| `outer_radius_km` | `float` | bei `geometry: "ring"` | Außenradius des Rings in km. |
| `color_rgba` | `float[4]` | ja | Füllfarbe als RGBA-Array. Alpha empfohlen: 0.05–0.2. |
| `border_color_rgba` | `float[4]` | ja | Randfarbe als RGBA-Array. |

### 3.2 Zone-Typen

| `zone_type` | Bedeutung |
| --- | --- |
| `radiation` | Strahlungsgürtel |
| `magnetic` | Magnetosphäre |
| `gravity` | Gravitationsbereich / Hill-Sphäre |
| `habitable` | Habitabilitätszone |

### 3.3 Beispiel — Ring

```json
{
  "id": "jupiter_radiation_belt",
  "name": "Jupiter Radiation Belt",
  "parent_id": "jupiter",
  "zone_type": "radiation",
  "geometry": "ring",
  "inner_radius_km": 200000,
  "outer_radius_km": 600000,
  "color_rgba": [0.9, 0.3, 0.1, 0.08],
  "border_color_rgba": [0.9, 0.3, 0.1, 0.3]
}
```

---

## 4 — Körperhierarchie

Vollständige Eltern-Kind-Hierarchie der aktuellen Datenbasis. Strukturen (`struct`) sind eingerückt unter ihrem jeweiligen Elternkörper aufgeführt.

```text
sun (fixed)
├── mercury (kepler2d)
│   ├── mercury_polar_relay (circular)
│   └── mercury_dawn_station (circular)
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
└── nav_relay_l4_terra (lagrange, L4: sun–terra)
```

---

## 5 — Hinweise zur Erweiterung

- **Neue Körper** müssen alle Pflichtfelder ausfüllen und einen gültigen `parent_id` haben
- **Neue Subtypes** müssen die Achse ihres Types respektieren (Komposition für Planeten, Funktion für Structs etc.)
- **Neue Map-Tags** müssen einer bestehenden Achse zugeordnet oder als neue dokumentierte Kategorie angelegt werden
- **Retrograde Bahnen** werden durch `"clockwise": true` markiert — gilt für `circular` und `kepler2d`
- **Neue Belts** brauchen einen einzigartigen `seed` — Seeds 1–6 sind vergeben
- **Neue Zones** sollten einen der definierten `zone_type`-Werte nutzen; neue Typen sind erlaubt aber zu dokumentieren
