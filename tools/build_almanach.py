#!/usr/bin/env python3
"""
Almanach Build Tool
===================
Konvertiert TOML-Quelldateien zu almanach_data.json für Godot.

Aufruf:  python tools/build_almanach.py
Input:   data/almanach/source/bodies/*.toml + data/almanach/source/concepts.toml
Output:  data/almanach/almanach_data.json
"""

import json
import sys
from pathlib import Path

# Python 3.11+ hat tomllib in stdlib, sonst tomli als Fallback
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        print("ERROR: Python 3.11+ required, or install 'tomli' package")
        sys.exit(1)


# Pfade relativ zum Projekt-Root
PROJECT_ROOT = Path(__file__).parent.parent
SOURCE_DIR = PROJECT_ROOT / "data" / "almanach" / "source"
BODIES_DIR = SOURCE_DIR / "bodies"
CONCEPTS_FILE = SOURCE_DIR / "concepts.toml"
OUTPUT_FILE = PROJECT_ROOT / "data" / "almanach" / "almanach_data.json"

# Bekannte Section-Typen
KNOWN_SECTION_TYPES = {"text", "gallery", "table"}


def load_toml(path: Path) -> dict | None:
    """Lädt eine TOML-Datei und gibt den Inhalt zurück."""
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except Exception as e:
        print(f"  ERROR: Konnte {path.name} nicht laden: {e}")
        return None


def validate_body(data: dict, filename: str, warnings: list[str]) -> bool:
    """Validiert einen Body-Eintrag. Gibt True zurück wenn valide."""
    body_id = data.get("id", "")
    expected_id = Path(filename).stem
    
    if not body_id:
        print(f"  ERROR: {filename} hat kein 'id' Feld")
        return False
    
    if body_id != expected_id:
        print(f"  ERROR: {filename} hat id='{body_id}', erwartet '{expected_id}'")
        return False
    
    # Sections validieren
    for i, section in enumerate(data.get("sections", [])):
        section_type = section.get("type", "")
        if section_type and section_type not in KNOWN_SECTION_TYPES:
            warnings.append(f"{filename}: Unbekannter Section-Typ '{section_type}' in Section {i+1}")
        
        # Bild-Pfade prüfen (nur Warnung)
        for img in section.get("images", []):
            img_path = PROJECT_ROOT / str(img).replace("res://", "")
            if not img_path.exists():
                warnings.append(f"{filename}: Bild nicht gefunden: {img}")
    
    # Hero-Bild prüfen
    if data.get("image"):
        img_path = PROJECT_ROOT / data["image"].replace("res://", "")
        if not img_path.exists():
            warnings.append(f"{filename}: Hero-Bild nicht gefunden: {data['image']}")
    
    return True


def validate_concepts(data: dict, concept_ids: set[str], warnings: list[str]) -> None:
    """Validiert Konzept-Verweise in related_concepts."""
    # Diese Funktion wird nach dem Laden aller Daten aufgerufen
    pass


def build_body_entry(data: dict) -> dict:
    """Baut einen Body-Eintrag für die JSON-Ausgabe."""
    entry = {}
    
    if data.get("summary"):
        entry["summary"] = data["summary"]
    
    if data.get("image"):
        entry["image"] = data["image"]
    
    if data.get("infobox"):
        entry["infobox"] = data["infobox"]
    
    if data.get("related_concepts"):
        entry["related_concepts"] = data["related_concepts"]
    
    if data.get("sections"):
        entry["sections"] = data["sections"]
    
    # Legacy: description für Abwärtskompatibilität
    if data.get("description"):
        entry["description"] = data["description"]
    
    return entry


def build_concept_entry(data: dict) -> dict:
    """Baut einen Concept-Eintrag für die JSON-Ausgabe."""
    return {
        "title": data.get("title", ""),
        "content": data.get("content", "")
    }


def main():
    print("=" * 50)
    print("Almanach Build Tool")
    print("=" * 50)
    
    warnings: list[str] = []
    result = {
        "bodies": {},
        "concepts": {}
    }
    
    # Bodies laden
    print(f"\n[1/3] Lade Bodies aus {BODIES_DIR.relative_to(PROJECT_ROOT)}/")
    
    if not BODIES_DIR.exists():
        print(f"  WARN: Verzeichnis {BODIES_DIR} existiert nicht")
    else:
        toml_files = sorted(BODIES_DIR.glob("*.toml"))
        for toml_file in toml_files:
            data = load_toml(toml_file)
            if data is None:
                continue
            
            if not validate_body(data, toml_file.name, warnings):
                continue
            
            body_id = data["id"]
            result["bodies"][body_id] = build_body_entry(data)
            print(f"  ✓ {body_id}")
    
    # Concepts laden
    print(f"\n[2/3] Lade Concepts aus {CONCEPTS_FILE.relative_to(PROJECT_ROOT)}")
    
    if CONCEPTS_FILE.exists():
        concepts_data = load_toml(CONCEPTS_FILE)
        if concepts_data:
            for concept_id, concept_data in concepts_data.items():
                if isinstance(concept_data, dict):
                    result["concepts"][concept_id] = build_concept_entry(concept_data)
                    print(f"  ✓ {concept_id}")
    else:
        print(f"  WARN: {CONCEPTS_FILE} existiert nicht")
    
    # Konzept-Verweise validieren
    concept_ids = set(result["concepts"].keys())
    for body_id, body_data in result["bodies"].items():
        for ref in body_data.get("related_concepts", []):
            if ref not in concept_ids:
                warnings.append(f"{body_id}: Verweis auf unbekanntes Konzept '{ref}'")
    
    # Output schreiben
    print(f"\n[3/3] Schreibe {OUTPUT_FILE.relative_to(PROJECT_ROOT)}")
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    # Zusammenfassung
    print("\n" + "=" * 50)
    print("Zusammenfassung")
    print("=" * 50)
    print(f"  Bodies:   {len(result['bodies'])}")
    print(f"  Concepts: {len(result['concepts'])}")
    print(f"  Warnings: {len(warnings)}")
    
    if warnings:
        print("\nWarnungen:")
        for w in warnings:
            print(f"  ⚠ {w}")
    
    print(f"\n✓ Output: {OUTPUT_FILE.relative_to(PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
