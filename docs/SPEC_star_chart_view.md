# SPEC: Star Chart View

> alpha_0.3 · Technische Spezifikation für `star_chart_view.gd`

---

## 1 — Identität

| Feld | Wert |
|---|---|
| Klasse | `StarChartView` |
| Extends | `Node2D` |
| Pfad | `res://game/map/views/star_chart/star_chart_view.gd` |
| Scene | `res://game/map/views/StarChartView.tscn` (existiert bereits, enthält WorldEnvironment + Glow) |
| Lebt in | `SubViewport` des `StarChartScreen` |
| Instanziierung | `StarChartScreen` instanziiert die Scene und hängt sie in `get_sub_viewport()` ein |

Kein Autoload. Empfängt alle Abhängigkeiten via `setup()`.

---

## 2 — Abhängigkeiten

| Von | Erhält | Via |
|---|---|---|
| `SimulationClock` | Referenz | `setup()` Parameter |
| `SolarSystemModel` | Referenz | `setup()` Parameter |
| `StarChartScreen` | Referenz | `setup()` Parameter |
| `MapScale` | Eigene Instanz | `= MapScale.new()` |
| `MapViewController` | Kind-Node aus Scene | `$MapViewController` |
| `MapFilterState` | Kind-Node aus Scene | `$MapFilterState` |
| `MapCameraController` | Kind-Node | Via `add_child()` + `setup(map_scale, config)` |
| `MapDataLoader` | Lokale Instanz | Nur beim Laden von Belts/Zones |

---

## 3 — Selektion & Fokus

Zwei getrennte Konzepte mit unterschiedlicher Funktion:

### Selektion

**Bedeutung:** "Ich schaue mir diesen Body an."

| Eigenschaft | Wert |
|---|---|
| Auslöser | Einfachklick auf BodyMarker |
| Effekte | InfoPanel zeigt Body-Daten, Selection-Ring erscheint, Kamera gleitet hin + trackt Body |
| Tracking | Kamera folgt der Weltposition des selektierten Bodys jeden Frame (keine Rotation) |
| State | `_selected_body: BodyDef` (oder `null`) |

### Fokus

**Bedeutung:** "Ich tauche in dieses System ein."

| Eigenschaft | Wert |
|---|---|
| Auslöser | Doppelklick auf BodyMarker |
| Effekte | Alles von Selektion + Exaggeration wird aktiviert (Kinder werden spreizend sichtbar) + Zoom-to-fit |
| Tracking | Kamera trackt den fokussierten Body (identisch zu Selektion) |
| State | `_focused_body_id: String` (leer = kein Fokus) |

### Drei Interaktionsstufen auf Bodies

| Aktion | Effekt |
|---|---|
| Einfachklick | Selektion: InfoPanel, Ring, Kamera gleitet hin + trackt |
| Doppelklick | Fokus: Selektion + Exag an + Zoom-to-fit |
| Rechtsklick | Kontextmenü (vorerst leer, Infrastruktur vorbereiten) |

### Klicks auf leeren Bereich

| Aktion | Effekt |
|---|---|
| Linksklick (Fokus aktiv) | Fokus lösen, Exag aus, Kamera zurück zu `_pre_focus_*` |
| Linksklick (kein Fokus) | Kamera gleitet zum Klickpunkt |
| Rechtsklick | Kontextmenü (eigene Optionen — Details offen) |

### Pan-Verhalten bei Selektion/Fokus

| Situation | Pan-Effekt |
|---|---|
| Selektion aktiv, kein Fokus | Alles löst sich: Tracking, Ring, InfoPanel, Selektion weg |
| Fokus aktiv | Fokus lösen, Exag aus, Rückkehr zu `_pre_focus_*` |

---

## 4 — Fokus-System (kein Stack)

Kein FocusState-Objekt, kein Stack. Der Fokus-Zustand besteht aus drei Variablen:

```gdscript
_focused_body_id:    String   # Body-ID des Fokus; leer = kein Fokus
_pre_focus_scale_exp: float   # Zoom-Level vor dem Fokus setzen
_pre_focus_center_km: Vector2 # Kameraposition vor dem Fokus setzen
```

### Fokus setzen (Doppelklick)

```
1. _pre_focus_scale_exp = aktueller scale_exp
2. _pre_focus_center_km = aktueller world_center_km
3. _view_controller.set_focus(body_id)
4. Zoom-to-fit: calc_fit_scale_exp(max_child_orbit_km, vp_size)
5. Kamera gleitet zum fokussierten Body
6. screen.update_focus_body(body.name)
```

### Fokus wechseln (Doppelklick auf anderen Body)

```
1. _view_controller.set_focus(new_body_id)   ← pre_focus bleibt erhalten
2. Zoom-to-fit für neuen Body
3. Kamera gleitet zum neuen Body
4. screen.update_focus_body(new_body.name)
```

### Fokus lösen (Escape / Klick ins Leere / Pan)

```
1. _view_controller.clear_focus()
2. Kamera gleitet zurück zu _pre_focus_center_km + _pre_focus_scale_exp
3. screen.update_focus_body("")
```

### Tracking-Verhalten

Die Kamera trackt immer den fokussierten (bzw. selektierten) Body:
- Kamera folgt der Weltposition des Bodys jeden Frame
- Keine Rotation — achsenfeste 2D-Draufsicht
- Kinder des Bodys kreisen um ihn
- Elternkörper und andere Bodies driften im Hintergrund
- Pan löst das Tracking (und je nach Zustand die Selektion/den Fokus)

---

## 5 — Hover-Verhalten

Basiert auf den `hovered`/`unhovered`-Signalen des `BodyMarker`.

| Eigenschaft | Wert |
|---|---|
| Auslöser | Maus verweilt über BodyMarker |
| Cursor-Wechsel | `CURSOR_POINTING_HAND` bei Hover, zurück zu Standard bei Verlassen |
| Tooltip | Name + Type, nach ~0.4s Verzögerung |
| Ausblendung | Sofort bei Mausbewegung weg vom Body |

---

## 6 — Selection-Ring

Visueller Indikator um den selektierten Body.

| Eigenschaft | Wert |
|---|---|
| Node | `Node2D` als Kind der View, über dem BodyLayer |
| Zeichnung | `draw_arc()` in `_draw()` |
| Farbe | `#4aff8a`, Alpha ~0.5 (grüner Glow, passend zum UI-Chrome) |
| Radius | Marker-Größe des selektierten Bodys + Padding |
| Position | Folgt der Screen-Position des selektierten Markers |
| Sichtbarkeit | Nur sichtbar wenn `_selected_body != null` |

---

## 7 — Screen-Kommunikation

### View → Screen

| Methode | Wann |
|---|---|
| `screen.update_header_info(zoom, scale)` | Zoom-Änderung |
| `screen.update_focus_body(name)` | Fokus setzen / wechseln / lösen |
| `screen.update_cursor_info(world_km)` | Mausbewegung |
| `screen.select_body(body)` | Einfachklick / Doppelklick auf Body |
| `screen.deselect_body()` | Selektion aufgehoben (Pan, Klick ins Leere, Escape) |

### Screen → View

| Signal | Reaktion |
|---|---|
| `body_selected(body_id)` | Child-Klick im InfoPanel: View selektiert den Body, Kamera gleitet hin |

---

## 8 — Kontextmenü

Infrastruktur wird vorbereitet, Inhalte kommen später.

| Kontext | alpha_0.3 | Geplant |
|---|---|---|
| Auf Body | Leeres Menü | Fokussieren, Route planen, Details, Wegpunkt |
| Auf leeren Bereich | Leeres Menü | Koordinaten kopieren, Bookmark setzen |

---

## 9 — Culling

Zwei Regeln bestimmen ob ein Body gerendert wird:

1. **min_orbit_px** — `orbit_km × px_per_km ≥ min_orbit_px` → sichtbar
   - Root-Bodies (kein Parent) sind immer sichtbar
   - Exag-Kinder: `orbit_px × exag_faktor` vor dem Vergleich
2. **Viewport-Culling** — Bodies außerhalb von `get_cull_rect()` werden nicht gerendert

Zusätzlich greift `MapFilterState`: Type/Subtype-Toggles können Bodies unabhängig vom Orbit-Radius ausblenden.

Exaggeration wird automatisch aktiviert wenn ein Fokus gesetzt ist, und automatisch deaktiviert wenn der Fokus gelöst wird. Kein manueller Toggle.

---

## 10 — Map Settings Panel

Das `StarChartScreen` stellt ein einblendbares Filter-Panel auf der linken Seite bereit:

- Toggle via "FILTER"-Button im Header
- Enthält alle `MapFilterState`-Toggles (Bodies, Orbits, Zones, Belts)
- Verdrahtung über `screen.connect_settings_panel(filter)` nach dem View-Setup
- Filter persistent über Fokus-Wechsel

---

## 11 — Abgrenzung

**Die View macht:**

- Toolkit orchestrieren (MapScale, MapViewController, MapFilterState)
- MapCameraController als Kind-Node einbinden
- Renderer spawnen und updaten
- Selektion/Fokus-Logik (ohne Stack)
- Hover-Reaktion (Cursor, Tooltip)
- Selection-Ring zeichnen
- Screen über Änderungen informieren
- Settings-Panel nach Setup mit Filter verdrahten

**Die View macht NICHT:**

- UI-Elemente bauen (→ StarChartScreen)
- Time-Scale steuern (→ StarChartScreen)
- Input für Pan/Zoom/Tastatur verarbeiten (→ MapCameraController)
- Simulationszeit berechnen (→ SimClock)
- Body-Positionen berechnen (→ SolarSystemModel)
- Sichtbarkeitsentscheidungen treffen (→ MapViewController)
