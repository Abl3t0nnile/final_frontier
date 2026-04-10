#!/usr/bin/env python3
"""
Halbautomatische Überarbeitung der Almanach-Body-TOMLs.

Nutzt die Projekt-venv. Installation:
    source tools/.venv/bin/activate
    pip install python-toml

Ausführung:
    python tools/refine_almanach_bodies.py
"""

import os
import re
import sys
import tomllib
from pathlib import Path
from dataclasses import dataclass
from typing import Optional

# Body-Datenbank: Etymologie, Entdeckung, Entdecker
BODY_DATA = {
    "sun": {
        "etymology": "Altenglisch sunne, germanisch *sunnōn; indoeuropäische Wurzel *séh₂ul. Das Wort ist in indogermanischen Sprachen weit verbreitet (lat. sol, gr. hḗlios, sanskr. sū́rya).",
        "discovery": "Prähistorisch; das Objekt definiert selbst den Begriff des Tageslichts.",
        "discoverer": "—"
    },
    "mercury": {
        "etymology": "Benannt nach dem römischen Gott Mercurius (Gott der Händler, Diebe und Boten). Griechisch: Ἑρμῆς (Hermes). Das Symbol ☿ repräsentiert den Hermesstab.",
        "discovery": "Prähistorisch; als beweglicher 'Wanderstern' seit mindestens babylonischer Zeit dokumentiert (~14. Jh. v. Chr.)",
        "discoverer": "—"
    },
    "venus": {
        "etymology": "Benannt nach der römischen Göttin Venus (Göttin der Liebe und Schönheit). Griechisch: Ἀφροδίτη (Aphrodite). Das Symbol ♀ ist das stilisierte Spiegel-Emblem der Göttin.",
        "discovery": "Prähistorisch; als hellster Planet bekannt seit Sumerern (~3000 v. Chr., Inanna) und Babyloniern (Ištar).",
        "discoverer": "—"
    },
    "terra": {
        "etymology": "Erde: germanisch *erþō (Boden, Erdboden). Terra: lateinisch für 'Erde, festes Land'. Das Symbol ♁ stilisiert Globus und Meridiane.",
        "discovery": "—",
        "discoverer": "—"
    },
    "moon": {
        "etymology": "Englisch moon, germanisch *mēnōþ-, indoeuropäisch *mḗh₁n̥s (Monat, Mond). Luna: lateinisch; verwandt mit 'Licht' (leicht). Symbol: ☽ (abnehmende Mondsichel).",
        "discovery": "Prähistorisch; prägt als nächster Himmelskörper die Begriffe von Zeit (Monat) und Gezeiten.",
        "discoverer": "—"
    },
    "mars": {
        "etymology": "Benannt nach dem römischen Kriegsgott Mars. Griechisch: Ἄρης (Ares). Das Symbol ♂ ist Schild und Speer des Gottes, später auch Alchemie-Symbol für Eisen.",
        "discovery": "Prähistorisch; Babylonier als Nergal (~7. Jh. v. Chr.), Ägypter als 'Horus des Horizonts'.",
        "discoverer": "—"
    },
    "jupiter": {
        "etymology": "Benannt nach dem römischen Göttervater Jupiter (Griechisch: Ζεύς / Zeus). Das Symbol ♃ ist stilisiertes Z für Zeus.",
        "discovery": "Prähistorisch; Babylonier als Marduk, Chaldäer als primus inter pares der Planeten.",
        "discoverer": "—"
    },
    "saturn": {
        "etymology": "Benannt nach dem römischen Gott Saturnus (Gott der Landwirtschaft und Ernte). Griechisch: Κρόνος (Kronos). Symbol: ♄ (stilisierte Sichel).",
        "discovery": "Prähistorisch; am äußeren Rand des klassischen Planetensystems bekannt seit babylonischer Zeit.",
        "discoverer": "—"
    },
    "uranus": {
        "etymology": "Benannt nach der griechischen Himmelsgottheit Οὐρανός (Uranos), Vater der Titanen. Vorschlag Johann Bode 1782; vorher 'Georgium Sidus' (Herschel).",
        "discovery": "1781-03-13 (erste dokumentierte Beobachtung als Planet)",
        "discoverer": "William Herschel"
    },
    "neptune": {
        "etymology": "Benannt nach dem römischen Meeresgott Neptunus (Griechisch: Ποσειδῶν / Poseidon). Vorschlag von Urbain Le Verrier 1846, unabhängig von Galle/Encke. Symbol: ♆ (Dreizack).",
        "discovery": "1846-09-23 (erste visuelle Bestätigung)",
        "discoverer": "Johann Gottfried Galle (nach Berechnungen von Le Verrier und Adams)"
    },
    "pluto": {
        "etymology": "Benannt nach dem römischen Unterweltsgott Pluto (Griechisch: Πλούτων / Plouton). Vorschlag von Venetia Burney (11-jährige Schülerin) 1930. Symbol: ♇ (PL-Monogramm).",
        "discovery": "1930-02-18 (Fotografische Aufnahme am Lowell Observatory)",
        "discoverer": "Clyde Tombaugh"
    },
    "ceres": {
        "etymology": "Benannt nach der römischen Göttin Ceres (Griechisch: Δημήτηρ / Demeter), Göttin der Landwirtschaft und Fruchtbarkeit. Symbol: ⚳ (Sichel).",
        "discovery": "1801-01-01",
        "discoverer": "Giuseppe Piazzi"
    },
    "eris": {
        "etymology": "Benannt nach der griechischen Göttin Ἔρις (Eris), Göttin der Zwietracht und des Streits. Benennung 2006 parallel zur Neudefinition des Planetenbegriffs.",
        "discovery": "2003-10-21 (Aufnahmen), 2005-01-05 (offizielle Ankündigung)",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "haumea": {
        "etymology": "Benannt nach der hawaiianischen Göttin Haumea der Geburt und Fruchtbarkeit. Passt zur Entdeckung durch ein hawaiisches Observatorium.",
        "discovery": "2004-12-28 (offizielle Ankündigung 2005, Namensgabe 2008)",
        "discoverer": "Michael E. Brown et al. (Caltech); unabhängig José Luis Ortiz Moreno et al. (Sierra Nevada Observatory)"
    },
    "makemake": {
        "etymology": "Benannt nach dem Schöpfergott der Rapa Nui (Osterinsel). Symbol: 🜚 (stilisiertes Gesicht nach Petroglyphen).",
        "discovery": "2005-03-31",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "gonggong": {
        "etymology": "Benannt nach dem chinesischen Wassergott 共工 (Gònggōng), Gott der Fluten und Chaos. Namensgebung 2019.",
        "discovery": "2007-07-17 (Bilder), 2009 (offizielle Ankündigung)",
        "discoverer": "Megan E. Schwamb, Michael E. Brown, David L. Rabinowitz"
    },
    "quaoar": {
        "etymology": "Benannt nach dem Tongva-Schöpfergott Quaoar aus der Mythologie der Los Angeles Basin. Erste Benennung eines KBO nach indianischer Mythologie.",
        "discovery": "2002-06-04",
        "discoverer": "Chad Trujillo, Michael E. Brown"
    },
    "sedna": {
        "etymology": "Benannt nach der inuitischen Meeresgöttin ᓴᓐᓇ (Sedna), Herrscherin über die Arktis und Meerestiere.",
        "discovery": "2003-11-14",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "orcus": {
        "etymology": "Benannt nach dem etruskisch-römischen Unterweltsgott Orcus, Pächter der verfluchten Toten. Paraname 'Vanth' (etruskische Unterweltsführerin).",
        "discovery": "2004-02-17",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "io": {
        "etymology": "Nach Io, der von Zeus verfolgten Priestertochter (griech. Ἰώ), in Gestalt eines weißen Stiers. Er verwandelte sie zur Kuh; sie floh über den Bosporus. Galilei 1610.",
        "discovery": "1610-01-07 (Beobachtung), 1610 (Veröffentlichung Sidereus Nuncius)",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "europa": {
        "etymology": "Nach der phönizischen Königstochter Εὐρώπη (Eurṓpē), die Zeus als weißer Stier entführte. Kontinent Europa nach ihr benannt.",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "ganymede": {
        "etymology": "Nach Γανυμήδης (Ganymēdēs), trojanischer Prinz und Ganymed, Mundschenk der Götter, von Zeus als Adler entführt.",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "callisto": {
        "etymology": "Nach Καλλιστώ (Kallistṓ), Nymphe und Gefährtin Artemis', von Zeus verführt; von Hera in Bärin verwandelt. Ursa Major nach ihr.",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "titan": {
        "etymology": "Nach den Τιτᾶνες (Titanes), dem Urgeschlecht griechischer Götter, Väter von Zeus und Olympiern. Huygens 1655.",
        "discovery": "1655-03-25",
        "discoverer": "Christiaan Huygens"
    },
    "enceladus": {
        "etymology": "Nach Ἐγκέλαδος (Enkélados), einem der Giganten der griechischen Mythologie, von Athene unter Sizilien begraben (Ätna = sein Atem).",
        "discovery": "1789-08-28",
        "discoverer": "William Herschel"
    },
    "triton": {
        "etymology": "Nach Τρίτων (Trítōn), Sohn Poseidons/Neptuns, Meeresgott mit Dreizack und Fischschwanz.",
        "discovery": "1846-10-10 (16 Tage nach Neptun)",
        "discoverer": "William Lassell"
    },
    "charon": {
        "etymology": "Nach Χάρων (Chárōn), Fährmann der Toten über den Styx. Vorgeschlagen von James Christy; 'C-H' = Christy und seine Frau Charlene.",
        "discovery": "1978-06-22 (Aufnahme), 1978-07-07 (Bestätigung)",
        "discoverer": "James W. Christy (US Naval Observatory)"
    },
    "deimos": {
        "etymology": "Nach Δεῖμος (Deimos), Sohn des Ares/Mars, Personifikation der Furcht (Schwester: Phobos).",
        "discovery": "1877-08-12",
        "discoverer": "Asaph Hall (US Naval Observatory)"
    },
    "phobos": {
        "etymology": "Nach Φόβος (Phobos), Sohn des Ares/Mars, Personifikation der Panik und Angst.",
        "discovery": "1877-08-18",
        "discoverer": "Asaph Hall (US Naval Observatory)"
    },
}

# Default-Eintrag für nicht gelistete Körper
default_entry = {
    "etymology": "Benennung nach mythologischer oder kultureller Referenz.",
    "discovery": "Entdeckungsdatum nicht spezifiziert.",
    "discoverer": "—"
}

def get_body_info(body_id: str) -> dict:
    """Liefert Etymologie, Entdeckung und Entdecker für einen Körper."""
    return BODY_DATA.get(body_id, default_entry)


def format_new_description(body_id: str, old_desc: str) -> str:
    """
    Formatiert eine neue wissenschaftliche Beschreibung.
    Extrahiert Fakten aus alter Beschreibung, fügt Metadaten hinzu.
    """
    info = get_body_info(body_id)
    
    # Extrahiere Basisdaten mit Regex
    radius_match = re.search(r'Radius von (\d[\d\.,\s]*\s*km)', old_desc)
    mass_match = re.search(r'Masse von ([\d\.,\s×10¹²³⁴⁵⁶⁷⁸⁹⁰]+\s*kg)', old_desc)
    
    radius = radius_match.group(1) if radius_match else "—"
    mass = mass_match.group(1) if mass_match else "—"
    
    # Aufbereiteter Header mit Fakten
    lines = [
        f'[b]{body_id.capitalize()}[/b]',
        "",
        "[b]Physikalische Parameter[/b]",
        f"[indent]• Radius: {radius}",
        f"• Masse: {mass}[/indent]",
        "",
        "[b]Etymologie[/b]",
        info["etymology"],
        "",
        "[b]Entdeckung[/b]",
        f"Datum: {info['discovery']}",
        f"Entdecker: {info['discoverer']}",
        "",
    ]
    
    # Original-Beschreibung als Referenz (optional komprimierbar)
    # Hier wird die alte Beschreibung strukturiert übernommen
    lines.append("[b]Beschreibung[/b]")
    
    # Extrahiere Absätze für Strukturierung
    paragraphs = [p.strip() for p in old_desc.split('\n\n') if p.strip()]
    for p in paragraphs[1:] if len(paragraphs) > 1 else paragraphs:
        # Erste Zeile meist redundant (Radius/Masse bereits extrahiert)
        if 'Radius' in p and 'Masse' in p and len(paragraphs) > 1:
            continue
        lines.append(p)
        lines.append("")
    
    return '\n'.join(lines)


def process_body_file(filepath: Path) -> bool:
    """Verarbeitet eine einzelne Body-TOML-Datei."""
    try:
        with open(filepath, 'rb') as f:
            data = tomllib.load(f)
        
        body_id = data.get('id', filepath.stem)
        old_desc = data.get('description', '')
        
        if not old_desc:
            print(f"⚠️  {filepath.name}: Keine description gefunden")
            return False
        
        # Neue formatierte Beschreibung
        new_desc = format_new_description(body_id, old_desc)
        
        # TOML-Output mit neuem Schema
        output = f'''id = "{body_id}"

description = """\
{new_desc}"""
'''
        
        # Infoboxen beibehalten
        if 'infobox' in data:
            for section, values in data['infobox'].items():
                output += f'\n[infobox.{section}]\n'
                for key, val in values.items():
                    if isinstance(val, dict):
                        output += f'\n[infobox.{section}.{key}]\n'
                        for k2, v2 in val.items():
                            output += f'"{k2}" = {v2}\n'
                    else:
                        output += f'{key} = {val}\n'
        
        # Backup und Schreiben
        backup_path = filepath.with_suffix('.toml.bak')
        if not backup_path.exists():
            filepath.rename(backup_path)
            print(f"📦 Backup: {backup_path.name}")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output)
        
        print(f"✅ Überarbeitet: {filepath.name}")
        return True
        
    except Exception as e:
        print(f"❌ Fehler bei {filepath.name}: {e}")
        return False


def main():
    """Hauptfunktion: Verarbeitet alle Body-TOMLs."""
    bodies_dir = Path(__file__).parent.parent / 'data' / 'almanach' / 'source' / 'bodies'
    
    if not bodies_dir.exists():
        print(f"❌ Verzeichnis nicht gefunden: {bodies_dir}")
        sys.exit(1)
    
    toml_files = sorted(bodies_dir.glob('*.toml'))
    print(f"📁 Gefunden: {len(toml_files)} Body-Dateien")
    print("=" * 50)
    
    success = 0
    failed = 0
    
    for toml_file in toml_files:
        if process_body_file(toml_file):
            success += 1
        else:
            failed += 1
    
    print("=" * 50)
    print(f"✅ Erfolgreich: {success}")
    print(f"❌ Fehlgeschlagen: {failed}")
    print(f"📦 Backups: *.toml.bak im selben Verzeichnis")


if __name__ == '__main__':
    main()
