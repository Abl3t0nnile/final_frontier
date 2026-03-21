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
| `ScopeResolver` | Eigene Instanz | `= ScopeResolver.new()` |
| `MapViewController` | Eigene Instanz | `= MapViewController.new()` |
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
| Effekte | Alles von Selektion + Scope wechselt (Kinder werden sichtbar) + Zoom-to-fit + Stack-Push |
| Tracking | Kamera trackt den fokussierten Body (identisch zu Selektion) |
| State | `_focus_stack: Array[FocusState]` |

### Drei Interaktionsstufen auf Bodies

| Aktion | Effekt |
|---|---|
| Einfachklick | Selektion: InfoPanel, Ring, Kamera gleitet hin + trackt |
| Doppelklick | Fokus: Selektion + Scope-Wechsel + Zoom-to-fit + Stack-Push |
| Rechtsklick | Kontextmenü (vorerst leer, Infrastruktur vorbereiten) |

### Klicks auf leeren Bereich

| Aktion | Effekt |
|---|---|
| Linksklick (Fokus aktiv) | Stack poppt komplett, kein Fokus, keine Selektion |
| Linksklick (kein Fokus) | Kamera gleitet zum Klickpunkt |
| Rechtsklick | Kontextmenü (eigene Optionen — Details offen) |

### Pan-Verhalten bei Selektion/Fokus

| Situation | Pan-Effekt |
|---|---|
| Selektion aktiv, kein Fokus | Alles löst sich: Tracking, Ring, InfoPanel, Selektion weg |
| Fokus aktiv | Stack poppt komplett, Rückkehr zum vorherigen Zoom/Scope |

---

## 4 — Fokus-Stack

Der Fokus-Stack speichert den Kamerazustand beim Eintauchen in ein Subsystem. Jeder Stack-Eintrag merkt sich den Zustand *vor* dem Fokus-Wechsel.

### FocusState (Stack-Eintrag)

```
focused_body: BodyDef       # Der fokussierte Body auf dieser Ebene
scale_exp: float             # Zoom-Level vor dem Fokus-Wechsel
world_center_km: Vector2    # Kameraposition vor dem Fokus-Wechsel
```

### Stack-Operationen

| Aktion | Operation |
|---|---|
| Doppelklick auf Kind des Fokus-Bodys | Push (neuer Level, tiefere Hierarchie) |
| Doppelklick auf Geschwister (z.B. Jupiter fokussiert → Doppelklick Mars) | Replace (aktueller Level wird ersetzt) |
| Escape | Pop eine Ebene (zurück zum vorherigen Fokus) |
| Linksklick ins Leere | Pop komplett (Stack leer, kein Fokus, keine Selektion) |
| Pan | Pop komplett (Stack leer, Rückkehr zum vorherigen Zoom/Scope) |

### Stack-Beispiel

```
Start:              Stack = []                   scale_exp=7.5, kein Fokus
Doppelklick Jupiter: Stack = [{exp=7.5, center=(0,0)}]   → Fokus=Jupiter, zoom-to-fit
Doppelklick Io:      Stack = [{...}, {exp=5.2, center=Jup_pos}]  → Fokus=Io, zoom-to-fit
Escape:             Stack = [{exp=7.5, center=(0,0)}]   → Fokus=Jupiter, exp=5.2
Escape:             Stack = []                   → scale_exp=7.5, kein Fokus
```

### Doppelklick auf Geschwister

```
Jupiter fokussiert:  Stack = [{exp=7.5, center=(0,0)}]
Doppelklick Mars:   Stack = [{exp=7.5, center=(0,0)}]   → Replace: Fokus=Mars, zoom-to-fit
```

Der unterste Stack-Eintrag (Rückkehr-Zustand) bleibt erhalten. Nur der aktuelle Fokus-Body und Zoom wechseln.

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
| `screen.update_header_info(scope, zoom, scale)` | Zoom-Änderung, Scope-Wechsel |
| `screen.update_focus_body(name)` | Fokus-Wechsel (Push/Pop/Replace) |
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

## 9 — Scopes

*Noch zu planen. Wird als nächstes definiert.*

---

## 10 — Abgrenzung

**Die View macht:**
- Toolkit orchestrieren (MapScale, ScopeResolver, MapViewController)
- MapCameraController als Kind-Node einbinden
- Renderer spawnen und updaten
- Selektion/Fokus-Logik mit Stack
- Hover-Reaktion (Cursor, Tooltip)
- Selection-Ring zeichnen
- Screen über Änderungen informieren

**Die View macht NICHT:**
- UI-Elemente bauen (→ StarChartScreen)
- Time-Scale steuern (→ StarChartScreen)
- Input für Pan/Zoom/Tastatur verarbeiten (→ MapCameraController)
- Simulationszeit berechnen (→ SimClock)
- Body-Positionen berechnen (→ SolarSystemModel)
- Sichtbarkeitsentscheidungen treffen (→ MapViewController)
- Scope-Dateien editieren (→ Scope Inspector Addon)
