# SPEC: MapCameraController

> alpha_0.3 · Technische Spezifikation für `map_camera_controller.gd`

---

## 1 — Identität

| Feld | Wert |
|---|---|
| Klasse | `MapCameraController` |
| Extends | `Node` |
| Pfad | `res://game/map/toolkit/camera/map_camera_controller.gd` |
| Zugehörigkeit | Map Toolkit (view-agnostisch, wiederverwendbar) |

Kein Autoload. Wird von der jeweiligen View als Kind eingehängt und via `setup()` konfiguriert.

---

## 2 — Verantwortlichkeit

Kapselt den gesamten Navigations-State und Input für kartenbasierte Views:
- Maus-, Trackpad- und Tastatur-Input interpretieren
- Pan und Zoom mit Smoothing auf `MapScale` anwenden
- Inertia, Gummiband-Effekte, Smooth-Glide
- Fokus-Anker-Logik (Zoom zum Cursor vs. zum Body)

Macht **nicht**: Sichtbarkeitsfilterung, Rendering, Body-Selektion, UI.

---

## 3 — Abhängigkeiten

| Von | Erhält | Via |
|---|---|---|
| `MapScale` | Referenz | `setup()` Parameter — wird vom Controller gesteuert |

Der Controller kennt weder `SolarSystemModel` noch `StarChartScreen`. Die View vermittelt bei Bedarf (z.B. Fokus-Body-Position).

---

## 4 — Setup

```
setup(map_scale: MapScale, config: Dictionary = {})
```

Config-Dictionary für View-spezifische Anpassungen (alle optional, Defaults unten):

| Key | Typ | Default | Bedeutung |
|---|---|---|---|
| `scale_exp_min` | float | `1.0` | Untere Zoom-Grenze |
| `scale_exp_max` | float | `11.0` | Obere Zoom-Grenze |
| `scale_exp_start` | float | `7.5` | Start-Zoom |
| `zoom_step` | float | `0.08` | scale_exp-Delta pro Mausrad-Tick |
| `rubber_band_margin` | float | `0.5` | Wie weit über Zoom-Grenzen hinaus gezoomt werden darf |
| `rubber_band_speed` | float | `5.0` | Rückfeder-Geschwindigkeit |
| `pan_inertia_decay` | float | `4.0` | Abbremsfaktor für Pan-Trägheit |
| `smooth_zoom_speed` | float | `8.0` | Interpolationsgeschwindigkeit für Zoom-Smoothing |
| `smooth_pan_speed` | float | `8.0` | Interpolationsgeschwindigkeit für Pan-Smoothing |
| `pan_key_speed_px` | float | `400.0` | Tastatur-Pan in px/s |
| `zoom_key_speed` | float | `1.5` | scale_exp-Delta pro Sekunde bei Q/E |

---

## 5 — State

```
# Aktueller Zustand
_world_center_km: Vector2        # Weltpunkt in Bildschirmmitte
_scale_exp: float                # Aktueller Zoom (logarithmisch)

# Zielwerte (Smoothing interpoliert dorthin)
_target_center_km: Vector2
_target_scale_exp: float

# Pan-State
_is_panning: bool
_pan_start_mouse: Vector2
_pan_start_center: Vector2
_pan_velocity: Vector2           # Für Inertia

# Fokus-Anker
_focus_anchor_km: Vector2        # Zoom-Ankerpunkt (Body-Position oder Cursor-Welt-Pos)
_has_focus_anchor: bool           # true = zum Body zoomen, false = zum Cursor

# Viewport-Referenz
_viewport_size: Vector2          # Gecacht, aktualisiert bei Resize
```

---

## 6 — Maus-Input

### Pan (Mittelklick + Ziehen)

| Schritt | Verhalten |
|---|---|
| Mittelklick gedrückt | `_is_panning = true`, Startpunkt merken, Cursor → Grab |
| Mausbewegung bei Pan | `_target_center_km = pan_start_center - delta_px * km_per_px` |
| Mittelklick losgelassen | `_is_panning = false`, Cursor → Standard, Inertia starten |
| Inertia | `_pan_velocity` wird pro Frame mit `pan_inertia_decay * delta` abgebremst |

### Zoom (Mausrad)

| Schritt | Verhalten |
|---|---|
| Scroll-Up | `_target_scale_exp -= zoom_step` (reinzoomen) |
| Scroll-Down | `_target_scale_exp += zoom_step` (rauszoomen) |
| Ankerpunkt | `_has_focus_anchor == true` → Zoom Richtung `_focus_anchor_km`. Sonst → Weltpunkt unter Cursor |
| Gummiband | Target darf `rubber_band_margin` über min/max hinaus. `_process` federt sanft zurück |

**Zoom-unter-Cursor-Algorithmus:**
```
1. mouse_world = screen_to_world(mouse_pos)
2. _target_scale_exp += delta
3. Nach Interpolation: world_center_km anpassen damit mouse_world unter Cursor bleibt
```

**Zoom-zum-Fokus-Algorithmus:**
```
1. _target_scale_exp += delta
2. Nach Interpolation: world_center_km in Richtung _focus_anchor_km interpolieren
```

### Linksklick (leer, kein Body)

| Zustand | Verhalten |
|---|---|
| Fokus aktiv | Fokus lösen (View-Verantwortung, Controller emittiert Signal) |
| Kein Fokus | Cam gleitet zum Klickpunkt: `_target_center_km = screen_to_world(click_pos)` |

### Rechtsklick

Controller emittiert Signal mit Klickposition. Kontextmenü ist View/Screen-Verantwortung.

---

## 7 — Trackpad-Input

### Pan (Zwei-Finger-Geste)

Godot meldet Trackpad-Pan als `InputEventPanGesture`. Wird wie Maus-Pan behandelt: `_target_center_km -= gesture_delta * km_per_px`.

### Zoom (Pinch-to-Zoom)

Godot meldet Pinch als `InputEventMagnifyGesture`. Der `factor` wird in `scale_exp`-Delta umgerechnet.

---

## 8 — Tastatur-Input

### Input Actions

Eigene Actions, getrennt von Godots `ui_*`-Actions. Alte Actions (`cam_zoom_in (+)`, `cam_zoom_out (-)`, `map_zoom_in (+)`, `map_zoom_out (-)`) werden entfernt.

| Action | Taste | Typ | Verhalten |
|---|---|---|---|
| `cam_pan_up` | W | Gehalten | Pan nach oben, konstant px/s |
| `cam_pan_down` | S | Gehalten | Pan nach unten |
| `cam_pan_left` | A | Gehalten | Pan nach links |
| `cam_pan_right` | D | Gehalten | Pan nach rechts |
| `cam_zoom_in` | Q | Gehalten | Reinzoomen, smooth, kontinuierlich |
| `cam_zoom_out` | E | Gehalten | Rauszoomen, smooth, kontinuierlich |
| `cam_reset` | R | Einmalig | Zurück zu Startposition + Start-Zoom |

### Pan (WASD)

- Geschwindigkeit: `pan_key_speed_px * km_per_px * delta` — skaliert linear mit dem Zoom
- Diagonales Pan möglich (z.B. W+D gleichzeitig) — Richtungsvektor normalisieren
- Setzt `_target_center_km` pro Frame: `target += direction * pan_key_speed_px * km_per_px * delta`
- Inertia nach Loslassen: identisch zu Maus/Trackpad (kurzes Nachgleiten, `pan_inertia_decay`)

### Zoom (Q/E)

- Kontinuierlich bei gedrückt halten: `_target_scale_exp += zoom_key_speed * delta`
- Zoom-Anker: Fokus-Body vorhanden → zum Body. Kein Fokus → zur Bildschirmmitte
- Gummiband an den Grenzen identisch zu Mausrad

### Reset (R)

- `_target_center_km = Vector2.ZERO`
- `_target_scale_exp = scale_exp_start`
- Smooth-Gleiten zum Ziel, kein harter Sprung

### Config-Erweiterung

| Key | Typ | Default | Bedeutung |
|---|---|---|---|
| `pan_key_speed_px` | float | `400.0` | Tastatur-Pan in px/s |
| `zoom_key_speed` | float | `1.5` | scale_exp-Delta pro Sekunde bei Q/E |

---

## 9 — Cursor-Management

| Zustand | Cursor |
|---|---|
| Standard | Pfeil (`CURSOR_ARROW`) |
| Pannen aktiv | Grab (`CURSOR_DRAG`) |

**Hinweis:** Hand-Cursor über Bodies (`CURSOR_POINTING_HAND`) ist View-Verantwortung, nicht Controller.

---

## 10 — Hover / Tooltip

Nicht Verantwortung des Controllers. Hover-Erkennung liegt beim `BodyMarker` (Signale `hovered`/`unhovered`). Tooltip-Logik und Cursor-Wechsel auf Hand sind View-Verantwortung.

---

## 11 — Smooth-Verhalten (_process)

Pro Frame in `_process(delta)`:

```
1. scale_exp = lerp(scale_exp, target_scale_exp, smooth_zoom_speed * delta)
2. world_center_km = lerp(world_center_km, target_center_km, smooth_pan_speed * delta)
3. Gummiband: if scale_exp außerhalb [min, max] → target_scale_exp clampen, zurückfedern
4. Inertia: if not panning und velocity > threshold → target_center -= velocity, velocity *= decay
5. map_scale.set_scale_exp(scale_exp)
6. map_scale.set_origin(world_center_km - viewport_half * km_per_px)
7. Signal emittieren: camera_moved
```

---

## 12 — Signale

| Signal | Parameter | Wann |
|---|---|---|
| `camera_moved` | — | Jedes Frame wenn sich Position oder Zoom geändert hat |
| `zoom_changed` | `scale_exp: float` | Bei Zoom-Änderung (nach Smoothing) |
| `empty_click` | `world_km: Vector2` | Linksklick ins Leere |
| `context_menu_requested` | `screen_pos: Vector2, world_km: Vector2` | Rechtsklick |

---

## 13 — Public API

```
# Setup
setup(map_scale: MapScale, config: Dictionary = {})

# Navigation
pan_to(world_km: Vector2)                    # Smooth gleiten
jump_to(world_km: Vector2)                   # Sofort, kein Smoothing
zoom_to(scale_exp: float)                    # Smooth
reset_view()                                 # Zurück zu Start-Position + Start-Zoom

# Fokus-Anker
set_focus_anchor(world_km: Vector2)          # Zoom zentriert auf diesen Punkt
clear_focus_anchor()                         # Zoom zentriert auf Cursor

# Abfragen
get_world_center() -> Vector2
get_scale_exp() -> float
get_mouse_world_position() -> Vector2        # Aktuelle Mausposition in Weltkoordinaten
is_panning() -> bool
```

---

## 14 — Abgrenzung

**Der Controller macht:**
- Input interpretieren (Maus, Trackpad, Tastatur)
- `MapScale` steuern (Position, Zoom)
- Smoothing, Inertia, Gummiband
- Cursor setzen (Grab beim Pannen)
- Signale für Klick-Events emittieren
- Input Actions definieren (`cam_pan_*`, `cam_zoom_*`, `cam_reset`)

**Der Controller macht NICHT:**
- Body-Selektion / Fokus-Logik (→ View)
- Sichtbarkeitsfilterung (→ MapViewController)
- Kontextmenü anzeigen (→ View / Screen)
- Tooltip anzeigen (→ View)
- Body-Hover erkennen (→ BodyMarker)
- Tastatur-Shortcuts für Time-Scale (→ Screen)
