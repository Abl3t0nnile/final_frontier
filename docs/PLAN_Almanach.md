# Almanach Ausarbeitung — Implementierungsplan

**Version:** Alpha 1.0 → Alpha 1.1
**Scope:** Almanach-Content-System, Panel-Refactor, Python Build-Tool

---

## Übersicht

Der Almanach wird von einem einfachen BBCode-Text-Viewer zu einem Wiki-artigen Content-System ausgebaut. Drei Säulen:

1. **Daten-Pipeline:** TOML (Source) → Python-Converter → JSON (Runtime)
2. **Content-Component:** `AlmanachContentComponent` als `GameDataComponent` auf `GameObject`
3. **Panel-Refactor:** Trennung in Article-Builder, Section-Renderer, und dünnes Panel

### Architektur-Diagramm

```
TOML Source Files                    Python Converter
┌──────────────────┐                ┌──────────────────┐
│ bodies/terra.toml │───┐           │ build_almanach.py │
│ bodies/luna.toml  │   ├──────────►│                   │
│ bodies/sol.toml   │   │           │ Validiert TOML    │
│ concepts.toml     │───┘           │ Baut JSON         │
└──────────────────┘                └────────┬─────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │ almanach_data.json│  ← Godot lädt nur das
                                    └────────┬─────────┘
                                             │
                    ┌────────────────────────┤
                    ▼                        ▼
           ┌───────────────┐       ┌──────────────────┐
           │ AlmanachContent│       │ Concept-Artikel  │
           │ Component      │       │ (Dictionary)     │
           │ auf GameObject │       │ im AlmanachPanel │
           └───────┬───────┘       └──────────────────┘
                   │
                   ▼
           ┌───────────────┐
           │ArticleBuilder │  ← Baut AlmanachArticle aus BodyDef + Component
           └───────┬───────┘
                   │
                   ▼
           ┌───────────────┐
           │SectionRenderer│  ← Konvertiert Sections → BBCode
           └───────┬───────┘
                   │
                   ▼
           ┌───────────────┐
           │ RichTextLabel  │  ← Anzeige
           └───────────────┘
```

### Drei-Tier-Daten-Strategie (unverändert)

| Tier | Quelle | Inhalt | Verfügbarkeit |
|------|--------|--------|---------------|
| 1 | `BodyDef` + `MotionDef` | Physik, Orbit, Typ, Parent | Immer |
| 2 | `AlmanachContentComponent` | Beschreibung, Bilder, Sections, Infobox | Optional, lazy |
| 3 | Fallback-Template | Auto-generiert aus Tier 1 | Immer (wenn Tier 2 fehlt) |

---

## Phase 1 — TOML-Datenformat & Python-Converter

### 1.1 Verzeichnisstruktur

```
data/
└── almanach/
    ├── source/                          ← TOML-Quelldateien (Source of Truth)
    │   ├── bodies/
    │   │   ├── sol.toml
    │   │   ├── terra.toml
    │   │   ├── luna.toml
    │   │   └── ...
    │   └── concepts.toml                ← Alle Konzept-Artikel in einer Datei
    │
    ├── almanach_data.json               ← Generiert, von Godot geladen
    └── almanach_articles.json           ← ALT, wird ersetzt durch almanach_data.json
```

### 1.2 TOML-Schema: Body-Artikel

Datei: `data/almanach/source/bodies/{body_id}.toml`

```toml
# Pflichtfeld — muss mit BodyDef.id übereinstimmen
id = "terra"

# Zusammenfassung — wird über der Infobox angezeigt
summary = """\
Die Erde ist der dritte Planet des Sol-Systems und Ursprungswelt \
der Menschheit. Mit einem Radius von 6.371 km ist sie der größte \
terrestrische Planet des Systems."""

# Hero-Bild (optional) — wird in der Infobox angezeigt
image = "res://assets/almanach/terra_hero.png"

# Infobox-Overrides (optional)
# Ergänzt die auto-generierten Werte aus BodyDef.
# Keys werden 1:1 als Zeilen in der Infobox angezeigt.
[infobox]
"Atmosphäre" = "N₂/O₂ (78/21%)"
"Mittlere Temperatur" = "288 K"
"Tageslänge" = "24h 0m"

# Konzept-Links (optional)
# Werden am Ende des Artikels als "Siehe auch" angezeigt.
related_concepts = ["kepler_laws", "eccentricity"]

# ── Sections ──────────────────────────────────────────
# Jede [[sections]] wird in Reihenfolge unter der Zusammenfassung gerendert.
# Pflichtfelder pro Section: heading, type
# Weitere Felder je nach type.

[[sections]]
heading = "Geographie & Klima"
type = "text"
content = """\
Die Oberfläche besteht zu 71% aus Wasser. Drei große \
Kontinentalmassen dominieren die Landverteilung."""

[[sections]]
heading = "Ansichten"
type = "gallery"
images = [
    "res://assets/almanach/terra_surface.png",
    "res://assets/almanach/terra_orbit.png",
]
captions = ["Oberflächenaufnahme", "Orbitalansicht"]

[[sections]]
heading = "Stationen & Infrastruktur"
type = "table"
columns = ["Name", "Typ", "Orbit"]
rows = [
    ["ISS-VII", "Forschung", "LEO"],
    ["Gateway Prime", "Handelsstation", "GEO"],
]
```

**Initiale Section-Typen:**

| type | Pflichtfelder | Optionale Felder | Beschreibung |
|------|--------------|------------------|-------------|
| `text` | `content` | — | Fließtext mit BBCode-Links |
| `gallery` | `images` | `captions` | Bild-Carousel |
| `table` | `columns`, `rows` | — | Datentabelle |

Neue Typen können jederzeit ergänzt werden — der Renderer ignoriert unbekannte Typen mit Warnung.

### 1.3 TOML-Schema: Konzept-Artikel

Datei: `data/almanach/source/concepts.toml`

```toml
[kepler_laws]
title = "Keplersche Gesetze"
content = """\
Die drei Keplerschen Gesetze beschreiben die Bewegung \
von Himmelskörpern auf elliptischen Bahnen..."""

[eccentricity]
title = "Exzentrizität"
content = """\
Die Exzentrizität (Symbol: e) beschreibt, wie stark \
eine Umlaufbahn von einem Kreis abweicht..."""
```

Konzepte haben vorerst nur `title` + `content` (Fließtext mit BBCode-Links). Falls nötig kann das später auf das Section-System erweitert werden.

### 1.4 JSON-Ausgabeformat

Datei: `data/almanach/almanach_data.json`

```json
{
  "bodies": {
    "terra": {
      "summary": "Die Erde ist...",
      "image": "res://assets/almanach/terra_hero.png",
      "infobox": {
        "Atmosphäre": "N₂/O₂ (78/21%)",
        "Mittlere Temperatur": "288 K"
      },
      "related_concepts": ["kepler_laws"],
      "sections": [
        {
          "heading": "Geographie & Klima",
          "type": "text",
          "content": "Die Oberfläche..."
        },
        {
          "heading": "Ansichten",
          "type": "gallery",
          "images": ["res://assets/almanach/terra_surface.png"],
          "captions": ["Oberflächenaufnahme"]
        }
      ]
    }
  },
  "concepts": {
    "kepler_laws": {
      "title": "Keplersche Gesetze",
      "content": "Die drei Keplerschen Gesetze..."
    }
  }
}
```

### 1.5 Python-Converter

Datei: `tools/build_almanach.py`

```
Aufruf:  python tools/build_almanach.py
Input:   data/almanach/source/bodies/*.toml + data/almanach/source/concepts.toml
Output:  data/almanach/almanach_data.json
```

**Funktionalität:**

1. Liest alle `*.toml` aus `source/bodies/`, validiert Pflichtfelder (`id`)
2. Liest `source/concepts.toml`
3. Validierung:
   - `id` im TOML muss mit Dateiname übereinstimmen (`terra.toml` → `id = "terra"`)
   - Section-Typen müssen bekannt sein (Warnung bei unbekannten, kein Fehler)
   - `images`-Pfade: Warnung wenn Datei nicht existiert (kein Fehler — Assets kommen später)
   - Konzept-Links in `related_concepts`: Warnung wenn Konzept-ID nicht in `concepts.toml` existiert
4. Schreibt `almanach_data.json`
5. Gibt Zusammenfassung aus: X Bodies, Y Concepts, Z Warnings

**Abhängigkeiten:** Nur Python stdlib + `tomllib` (Python 3.11+) oder `tomli` als Fallback.

### 1.6 Tasks

| # | Task | Datei |
|---|------|-------|
| 1.1 | Python-Converter implementieren | `tools/build_almanach.py` |
| 1.2 | Bestehende `almanach_articles.json` Bodies+Concepts nach TOML migrieren | `data/almanach/source/` |
| 1.3 | Converter ausführen, Output verifizieren | `data/almanach/almanach_data.json` |
| 1.4 | Alte `almanach_articles.json` entfernen | — |

### 1.7 Akzeptanzkriterien

- `python tools/build_almanach.py` läuft ohne Fehler
- Output-JSON enthält alle Bodies und Concepts aus den TOML-Quellen
- Converter gibt Warnungen bei fehlenden Konzept-Links oder Bildern
- Alte JSON-Datei ist gelöscht

---

## Phase 2 — AlmanachContentComponent

### 2.1 Ziel

Almanach-Content als `GameDataComponent` ins Entity-System integrieren. Der `DataLoader` lädt die JSON-Daten und erstellt Components. Jeder `GameObject` mit Content bekommt einen `AlmanachContentComponent`.

### 2.2 Neue Klasse: AlmanachContentComponent

Datei: `core/objects/components/almanach_content_component.gd`

```gdscript
class_name AlmanachContentComponent
extends GameDataComponent

## Zusammenfassung
var summary: String = ""

## Hero-Bild Pfad
var image: String = ""

## Infobox-Overrides (ergänzt BodyDef-Daten)
var infobox: Dictionary = {}  # String → String

## Content-Sections in Reihenfolge
var sections: Array[Dictionary] = []
# Jede Section: { "heading": String, "type": String, ... }

## Verwandte Konzept-IDs
var related_concepts: Array[String] = []
```

Kein `load_data()` override nötig — die Daten werden beim Startup direkt gesetzt.

### 2.3 DataLoader-Erweiterung

Datei: `core/objects/data_loader.gd` — neue Methode:

```gdscript
const ALMANACH_DATA_PATH := "res://data/almanach/almanach_data.json"

func load_almanach_content() -> Dictionary:
    """Lädt Almanach-Daten. Gibt Dictionary zurück:
    { "bodies": { id: AlmanachContentComponent }, "concepts": Dictionary }"""
    var result := { "bodies": {}, "concepts": {} }

    var raw: Variant = _load_json_file(ALMANACH_DATA_PATH)
    if typeof(raw) != TYPE_DICTIONARY:
        return result

    # Body-Content → AlmanachContentComponent
    var bodies: Dictionary = raw.get("bodies", {})
    for id: String in bodies:
        var data: Dictionary = bodies[id]
        var comp := AlmanachContentComponent.new()
        comp.component_id = "almanach"
        comp.summary = data.get("summary", "")
        comp.image = data.get("image", "")
        comp.infobox = data.get("infobox", {})
        comp.sections = data.get("sections", [])
        comp.related_concepts = _to_string_array(data.get("related_concepts", []))
        comp._is_loaded = true
        result["bodies"][id] = comp

    # Concepts bleiben Dictionaries (kein eigener Component-Typ nötig)
    result["concepts"] = raw.get("concepts", {})

    return result
```

### 2.4 Startup-Integration

In `SolarMap._ready()` (oder wo der Startup orchestriert wird), nach Registry-Population:

```gdscript
# Nach: Registry mit GameObjects befüllt
# Neu: Almanach-Content laden und als Components anhängen

var almanach_data := data_loader.load_almanach_content()
for id: String in almanach_data["bodies"]:
    var obj: GameObject = _registry.get_object(id)
    if obj:
        obj.add_component("almanach", almanach_data["bodies"][id])

# Concepts an AlmanachPanel weitergeben
_almanach_panel.set_concept_articles(almanach_data["concepts"])
```

### 2.5 Tasks

| # | Task | Datei |
|---|------|-------|
| 2.1 | `AlmanachContentComponent` erstellen | `core/objects/components/almanach_content_component.gd` |
| 2.2 | `DataLoader.load_almanach_content()` implementieren | `core/objects/data_loader.gd` |
| 2.3 | Startup-Flow erweitern: Content laden + Components anhängen | `game/solar_map.gd` o.ä. |
| 2.4 | Verifizieren: `game_object.get_component("almanach")` liefert Daten | — |

### 2.6 Akzeptanzkriterien

- `GameObject.has_component("almanach")` gibt `true` für Bodies mit Content
- `AlmanachContentComponent` enthält korrekte Daten aus JSON
- Bodies ohne TOML-Datei haben keinen Component (Tier 3 Fallback greift)
- Concepts sind als Dictionary im AlmanachPanel verfügbar

---

## Phase 3 — Panel-Refactor: Article-Builder & Section-Renderer

### 3.1 Ziel

`AlmanachPanel` von ~300 Zeilen monolithischem Code auf drei klar getrennte Zuständigkeiten aufteilen:

- **`AlmanachArticleBuilder`** — Baut eine `AlmanachArticle`-Datenstruktur aus BodyDef + Component
- **`AlmanachSectionRenderer`** — Konvertiert Sections zu BBCode
- **`AlmanachPanel`** — Nur noch Navigation + Anzeige

### 3.2 Datenstruktur: AlmanachArticle

Datei: `ui/panels/almanach/almanach_article.gd`

```gdscript
class_name AlmanachArticle
extends RefCounted

var title: String = ""
var subtitle: String = ""       # z.B. "Terrestrischer Planet · Typ M"
var body_id: String = ""        # Leer bei Konzept-Artikeln
var sections: Array[Dictionary] = []
# Jede Section: { "type": String, "heading": String, ... }

## Factory: Aus BodyDef + optionalem Component
static func from_body(def: BodyDef, content: AlmanachContentComponent = null) -> AlmanachArticle:
    # Delegiert an AlmanachArticleBuilder
    return AlmanachArticleBuilder.build_body_article(def, content)

## Factory: Aus Konzept-Dictionary
static func from_concept(id: String, data: Dictionary) -> AlmanachArticle:
    return AlmanachArticleBuilder.build_concept_article(id, data)
```

### 3.3 Article-Builder

Datei: `ui/panels/almanach/almanach_article_builder.gd`

```gdscript
class_name AlmanachArticleBuilder
extends RefCounted

static func build_body_article(
    def: BodyDef,
    content: AlmanachContentComponent = null
) -> AlmanachArticle:
    var article := AlmanachArticle.new()
    article.title = def.name
    article.body_id = def.id

    # Subtitle aus Typ/Subtyp
    var sub := def.type
    if not def.subtype.is_empty():
        sub += " · " + def.subtype
    article.subtitle = sub

    # ── Section-Aufbau (Wiki-Layout) ──

    # 1. Summary + Infobox (nebeneinander im Renderer)
    article.sections.append(_build_summary_section(def, content))
    article.sections.append(_build_infobox_section(def, content))

    # 2. Separator
    article.sections.append({ "type": "separator" })

    # 3. Content-Sections (aus Component, falls vorhanden)
    if content:
        for section: Dictionary in content.sections:
            article.sections.append(section)

    # 4. Auto-generierte Sections
    var orbit_section := _build_orbit_section(def)
    if not orbit_section.is_empty():
        article.sections.append(orbit_section)

    var children_section := _build_children_section(def.id)
    if not children_section.is_empty():
        article.sections.append(children_section)

    # 5. Related Concepts
    if content and not content.related_concepts.is_empty():
        article.sections.append({
            "type": "links",
            "heading": "Siehe auch",
            "links": content.related_concepts.map(
                func(cid: String) -> Dictionary:
                    return { "id": "concept:" + cid, "label": cid }
            )
        })

    return article


static func build_concept_article(id: String, data: Dictionary) -> AlmanachArticle:
    var article := AlmanachArticle.new()
    article.title = data.get("title", id)
    article.sections.append({
        "type": "text",
        "content": data.get("content", "")
    })
    return article


# ── Private Builder-Methoden ──

static func _build_summary_section(
    def: BodyDef,
    content: AlmanachContentComponent = null
) -> Dictionary:
    var text := ""
    if content and not content.summary.is_empty():
        text = content.summary
    else:
        # Fallback: Auto-generierte Zusammenfassung
        text = "%s ist ein %s" % [def.name, def.type]
        if not def.subtype.is_empty():
            text += " vom Typ %s" % def.subtype
        if not def.parent_id.is_empty():
            var parent: BodyDef = SolarSystem.get_body(def.parent_id)
            var parent_name := parent.name if parent else def.parent_id
            text += ", in Orbit um [url=body:%s]%s[/url]" % [def.parent_id, parent_name]
        text += "."
    return { "type": "summary", "content": text }


static func _build_infobox_section(
    def: BodyDef,
    content: AlmanachContentComponent = null
) -> Dictionary:
    # Auto-generierte Zeilen aus BodyDef
    var rows: Array[Array] = []

    rows.append(["Typ", def.type])
    if not def.subtype.is_empty():
        rows.append(["Subtyp", def.subtype])
    if not def.parent_id.is_empty():
        var parent: BodyDef = SolarSystem.get_body(def.parent_id)
        var parent_name := parent.name if parent else def.parent_id
        rows.append(["Orbit", "[url=body:%s]%s[/url]" % [def.parent_id, parent_name]])
    if def.body_radius_km > 0.0:
        rows.append(["Radius", "%.1f km" % def.body_radius_km])
    if def.grav_param_km3_s2 > 0.0:
        var mass := SpaceMath.body_mass_kg(def.grav_param_km3_s2)
        rows.append(["Masse", _format_mass(mass)])

    # Infobox-Overrides aus Content einfügen
    if content:
        for key: String in content.infobox:
            rows.append([key, content.infobox[key]])

    var image := ""
    if content and not content.image.is_empty():
        image = content.image

    return { "type": "infobox", "rows": rows, "image": image }


static func _build_orbit_section(def: BodyDef) -> Dictionary:
    if def.parent_id.is_empty() or def.motion == null:
        return {}
    # Orbit-Daten je nach Motion-Typ sammeln...
    # (Logik aus bestehendem _generate_body_bbcode übernehmen)
    var rows: Array[Array] = []
    # ... rows befüllen ...
    if rows.is_empty():
        return {}
    return { "type": "data_table", "heading": "Orbitdaten", "rows": rows }


static func _build_children_section(parent_id: String) -> Dictionary:
    var children: Array[Dictionary] = []
    for obj: GameObject in GameRegistry.get_all_objects():
        if obj.body_def.parent_id == parent_id:
            var d := obj.body_def
            var sub := d.subtype if not d.subtype.is_empty() else d.type
            children.append({
                "id": "body:" + d.id,
                "label": "%s (%s)" % [d.name, sub]
            })
    if children.is_empty():
        return {}
    return { "type": "links", "heading": "Bekannte Trabanten", "links": children }


static func _format_mass(kg: float) -> String:
    if kg <= 0.0:
        return "—"
    var magnitude := floori(log(kg) / log(10.0))
    var mantissa  := kg / pow(10.0, float(magnitude))
    return "%.3f × 10^%d kg" % [mantissa, magnitude]
```

### 3.4 Section-Renderer

Datei: `ui/panels/almanach/almanach_section_renderer.gd`

Konvertiert eine Section-Dictionary zu BBCode. Erweiterbar: neuer Typ = neue `_render_*` Methode.

```gdscript
class_name AlmanachSectionRenderer
extends RefCounted

## Rendert eine vollständige AlmanachArticle zu BBCode
static func render(article: AlmanachArticle) -> String:
    var bbcode := ""

    # Header
    bbcode += "[font_size=20][b]%s[/b][/font_size]\n" % article.title
    if not article.subtitle.is_empty():
        bbcode += "[i]%s[/i]\n" % article.subtitle
    bbcode += "\n"

    # Sections
    for section: Dictionary in article.sections:
        var type: String = section.get("type", "")
        bbcode += _render_section(type, section)

    return bbcode


static func _render_section(type: String, data: Dictionary) -> String:
    match type:
        "summary":    return _render_summary(data)
        "infobox":    return _render_infobox(data)
        "separator":  return _render_separator()
        "text":       return _render_text(data)
        "data_table": return _render_data_table(data)
        "table":      return _render_table(data)
        "gallery":    return _render_gallery(data)
        "links":      return _render_links(data)
        _:
            push_warning("AlmanachSectionRenderer: unknown section type '%s'" % type)
            return ""


# ── Render-Methoden pro Typ ──

static func _render_summary(data: Dictionary) -> String:
    return "%s\n\n" % data.get("content", "")


static func _render_infobox(data: Dictionary) -> String:
    # Infobox: Bild + Datentabelle, rechts ausgerichtet
    # (RichTextLabel hat keine Float/Columns — wir rendern als Block)
    var t := "[color=#888888]────────────────────────[/color]\n"
    var image: String = data.get("image", "")
    if not image.is_empty():
        t += "[img]%s[/img]\n\n" % image
    for row: Array in data.get("rows", []):
        if row.size() >= 2:
            t += "%s: [b]%s[/b]\n" % [row[0], row[1]]
    t += "[color=#888888]────────────────────────[/color]\n\n"
    return t


static func _render_separator() -> String:
    return "[color=#888888]────────────────────────[/color]\n\n"


static func _render_text(data: Dictionary) -> String:
    var t := ""
    var heading: String = data.get("heading", "")
    if not heading.is_empty():
        t += "[font_size=16][b]%s[/b][/font_size]\n" % heading
    t += "%s\n\n" % data.get("content", "")
    return t


static func _render_data_table(data: Dictionary) -> String:
    var t := ""
    var heading: String = data.get("heading", "")
    if not heading.is_empty():
        t += "[font_size=16][b]%s[/b][/font_size]\n" % heading
    for row: Array in data.get("rows", []):
        if row.size() >= 2:
            t += "%s: [b]%s[/b]\n" % [row[0], row[1]]
    t += "\n"
    return t


static func _render_table(data: Dictionary) -> String:
    var t := ""
    var heading: String = data.get("heading", "")
    if not heading.is_empty():
        t += "[font_size=16][b]%s[/b][/font_size]\n" % heading
    # Spaltenheader
    var columns: Array = data.get("columns", [])
    if not columns.is_empty():
        var header_parts: PackedStringArray = []
        for col in columns:
            header_parts.append("[b]%s[/b]" % str(col))
        t += " | ".join(header_parts) + "\n"
    # Zeilen
    for row: Array in data.get("rows", []):
        var parts: PackedStringArray = []
        for cell in row:
            parts.append(str(cell))
        t += " | ".join(parts) + "\n"
    t += "\n"
    return t


static func _render_gallery(data: Dictionary) -> String:
    var t := ""
    var heading: String = data.get("heading", "")
    if not heading.is_empty():
        t += "[font_size=16][b]%s[/b][/font_size]\n" % heading
    var images: Array = data.get("images", [])
    var captions: Array = data.get("captions", [])
    for i in range(images.size()):
        t += "[img]%s[/img]\n" % images[i]
        if i < captions.size() and not str(captions[i]).is_empty():
            t += "[i]%s[/i]\n" % captions[i]
    t += "\n"
    return t


static func _render_links(data: Dictionary) -> String:
    var t := ""
    var heading: String = data.get("heading", "")
    if not heading.is_empty():
        t += "[font_size=16][b]%s[/b][/font_size]\n" % heading
    for link: Dictionary in data.get("links", []):
        t += "  • [url=%s]%s[/url]\n" % [link.get("id", ""), link.get("label", "")]
    t += "\n"
    return t
```

### 3.5 AlmanachPanel — Refactored

Datei: `ui/panels/almanach/almanach_panel.gd`

Das Panel wird dünn. Es behält:
- Navigation (History-Stack, Back/Forward) — **unverändert**
- Link-Handling (`_on_link_clicked`) — **unverändert**
- Home-Seite — **angepasst** (nutzt jetzt Registry statt eigene Iteration)

Es verliert:
- `_generate_body_bbcode()` → ersetzt durch `AlmanachArticleBuilder`
- `_format_mass()`, `_format_period()`, `_get_children()`, `_parent_mu()` → in Builder verschoben
- `_body_texts`, `_concept_articles` als rohe Dictionaries → Component-System

**Geänderte Methoden:**

```gdscript
# Statt _load_concept_articles():
var _concept_articles: Dictionary = {}

func set_concept_articles(concepts: Dictionary) -> void:
    _concept_articles = concepts

# Statt _show_body_article() mit inline BBCode-Generation:
func _show_body_article(id: String) -> void:
    var obj: GameObject = GameRegistry.get_object(id)
    if obj == null:
        _show_error("Kein Eintrag für '%s' gefunden." % id)
        return
    _current_body_id = id
    _zoom_btn.visible = true
    _title_label.text = obj.body_def.name

    var content: AlmanachContentComponent = obj.get_component("almanach")
    var article := AlmanachArticle.from_body(obj.body_def, content)
    _content.text = AlmanachSectionRenderer.render(article)

# Statt _show_concept_article() mit rohem BBCode:
func _show_concept_article(id: String) -> void:
    _current_body_id = ""
    _zoom_btn.visible = false
    if not _concept_articles.has(id):
        _show_error("Kein Konzept-Eintrag für '%s' gefunden." % id)
        return
    var article := AlmanachArticle.from_concept(id, _concept_articles[id])
    _content.text = AlmanachSectionRenderer.render(article)
```

**Zu entfernende Methoden/Variablen:**
- `_body_texts: Dictionary`
- `_load_concept_articles()` (JSON-Laden verschiebt sich zum DataLoader)
- `_generate_body_bbcode()`
- `_get_children()`
- `_parent_mu()`
- `_format_mass()`
- `_format_period()`

### 3.6 Tasks

| # | Task | Datei |
|---|------|-------|
| 3.1 | `AlmanachArticle` erstellen | `ui/panels/almanach/almanach_article.gd` |
| 3.2 | `AlmanachArticleBuilder` erstellen (Logik aus Panel extrahieren) | `ui/panels/almanach/almanach_article_builder.gd` |
| 3.3 | `AlmanachSectionRenderer` erstellen | `ui/panels/almanach/almanach_section_renderer.gd` |
| 3.4 | `AlmanachPanel` refactoren: Builder+Renderer nutzen, alte Methoden entfernen | `ui/panels/almanach/almanach_panel.gd` |
| 3.5 | Home-Seite anpassen (Registry statt eigene Iteration) | `ui/panels/almanach/almanach_panel.gd` |

### 3.7 Akzeptanzkriterien

- Bestehende Funktionalität bleibt erhalten (Navigation, Links, Home, Body-Artikel, Konzepte)
- Bodies mit Content-Component zeigen rich content (Summary, Infobox-Overrides, Sections)
- Bodies ohne Content-Component zeigen auto-generierten Fallback (wie bisher, aber über Builder)
- Konzept-Artikel funktionieren wie bisher
- Unbekannte Section-Typen erzeugen eine Warnung, keinen Crash
- `AlmanachPanel` enthält keine BBCode-Generierung mehr

---

## Phase 4 — Content-Migration & Erweiterung

### 4.1 Ziel

Bestehende Inhalte aus `almanach_articles.json` nach TOML migrieren und um Rich Content erweitern.

### 4.2 Tasks

| # | Task |
|---|------|
| 4.1 | Bestehende Body-Texte (`bodies` aus JSON) als TOML-Dateien anlegen |
| 4.2 | Bestehende Konzept-Artikel nach `concepts.toml` migrieren |
| 4.3 | Converter laufen lassen, testen |
| 4.4 | Alte `almanach_articles.json` und `_ARTICLES_PATH` Konstante entfernen |
| 4.5 | Rich Content für ausgewählte Bodies schreiben (Summary, Infobox, Sections) |

### 4.3 Akzeptanzkriterien

- Alle bestehenden Artikel sind verlustfrei in TOML migriert
- Converter Output matcht funktional den alten JSON-Inhalt
- Mindestens 3-5 Bodies haben erweiterten Rich Content als Proof-of-Concept

---

## Dependency Graph

```
Phase 1 (TOML + Converter)
    │
    └──► Phase 2 (AlmanachContentComponent)
              │
              └──► Phase 3 (Panel-Refactor)
                        │
                        └──► Phase 4 (Content-Migration)
```

Strikt sequenziell — jede Phase baut auf der vorherigen auf.

---

## Dateien-Übersicht

### Neue Dateien

| Datei | Phase |
|-------|-------|
| `tools/build_almanach.py` | 1 |
| `data/almanach/source/bodies/*.toml` | 1 |
| `data/almanach/source/concepts.toml` | 1 |
| `core/objects/components/almanach_content_component.gd` | 2 |
| `ui/panels/almanach/almanach_article.gd` | 3 |
| `ui/panels/almanach/almanach_article_builder.gd` | 3 |
| `ui/panels/almanach/almanach_section_renderer.gd` | 3 |

### Geänderte Dateien

| Datei | Phase | Änderung |
|-------|-------|----------|
| `core/objects/data_loader.gd` | 2 | `load_almanach_content()` hinzufügen |
| `game/solar_map.gd` (o.ä. Startup) | 2 | Content laden + Components anhängen |
| `ui/panels/almanach/almanach_panel.gd` | 3 | Refactor: Builder+Renderer nutzen |

### Gelöschte Dateien

| Datei | Phase |
|-------|-------|
| `data/almanach/almanach_articles.json` | 4 |

---

## Offene Entscheidungen

1. **Gallery-Widget:** RichTextLabel unterstützt `[img]` aber kein Carousel-Interaktion. Optionen: (a) Einfach: Bilder untereinander, (b) Custom Control als Alternative zu RichTextLabel für Gallery-Sections. → Entscheidung bei Phase 3 Implementation.

2. **Infobox-Layout:** RichTextLabel hat keine CSS-Float/Columns. Summary und Infobox können nur vertikal (untereinander) oder als Custom Layout gelöst werden. → Entscheidung bei Phase 3 Implementation.

3. **Konzepte auf Section-System erweitern?** Aktuell nur `title` + `content`. Kann später auf `[[sections]]` umgestellt werden wenn nötig.