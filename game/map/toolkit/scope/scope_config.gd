class_name ScopeConfig

extends Resource

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

@export var exag_faktor: float
    # Skalierungsfaktor für direkte Kinder des fokussierten Körpers.
    # 1.0 = keine Exaggeration. Werte > 1.0 spreizen die Orbital-Offsets auf,
    # sodass z.B. Monde eines fokussierten Planeten weiter auseinandergerückt
    # dargestellt werden als physikalisch korrekt.
    # Gilt für Marker-Positionen und Orbit-Linien gleichermaßen.
    # Hat keine Wirkung auf ZoneRenderer (Zonen haben eigene Skalierungslogik).

@export var visible_types: Array[String]
    # Type-Filter für Body-Sichtbarkeit.
    # Ein Body ist type-sichtbar wenn sein type in dieser Liste enthalten ist.
    # Leeres Array = kein Type-Filter (alle Types sichtbar).
    # Beispiel: ["star", "planet", "dwarf"] zeigt nur Hauptkörper.

@export var visible_tags: Array[String]
    # Tag-Filter für Body-Sichtbarkeit.
    # Ein Body ist tag-sichtbar wenn mindestens ein map_tag in dieser Liste enthalten ist (OR-Logik).
    # Leeres Array = kein Tag-Filter (alle Tags sichtbar).
    # Beispiel: ["jovian_system"] zeigt nur Körper im Jupiter-System.

@export var visible_zones: Array[String]
    # Zone-IDs die in diesem Scope sichtbar sind.
    # Referenziert Zonen über ihre eindeutige ID.
    # Leeres Array = alle Zonen sichtbar (kein Zonen-Filter).
    # Beispiel: ["asteroid_belt"] zeigt nur den Asteroidengürtel.

@export var min_orbit_px: float
    # Mindestradius eines Orbits in Pixeln (allgemeiner Filter).
    # Orbits deren Pixel-Radius unter diesem Wert liegt werden ausgeblendet.
    # Blendet sowohl den OrbitRenderer als auch den zugehörigen BodyMarker aus.
    # Verhindert visuellen Müll durch winzige, nicht erkennbare Orbit-Kreise.

@export var context_min_orbit_px: float
    # Mindestradius (in Pixeln, nach exag_faktor) für Kinder des Kontext/Fokus-Körpers.
    # Sollte deutlich höher als min_orbit_px sein — Kinder sollen erst erscheinen
    # wenn sie sichtbar vom Parent-Marker getrennt sind.
    # 0.0 = kein separater Filter (fällt auf min_orbit_px zurück).

@export var marker_sizes: Dictionary
    # Marker-Größen pro Body-Type in Pixeln.
    # Format: { "star": 32, "planet": 24, "dwarf": 18, "moon": 16, "struct": 12 }
    # Wird bei Scope-Wechsel auf alle sichtbaren Marker angewendet.
    # Wenn ein Type nicht enthalten ist: Konfigurationsfehler loggen, Fallback auf 16px.


const MARKER_SIZE_FALLBACK: int = 16


func get_marker_size(body_type: String) -> int:
    if not marker_sizes.has(body_type):
        push_warning("ScopeConfig '%s': kein marker_size für type '%s', Fallback auf %d px"
                % [scope_name, body_type, MARKER_SIZE_FALLBACK])
        return MARKER_SIZE_FALLBACK
    return int(marker_sizes[body_type])