## AlmanachContentComponent
## Speichert Almanach-Rich-Content für einen Body
## Erweitert: GameDataComponent

class_name AlmanachContentComponent
extends GameDataComponent

## Zusammenfassung (wird über der Infobox angezeigt)
var summary: String = ""

## Hero-Bild Pfad (für Infobox)
var image: String = ""

## Infobox-Overrides (ergänzt BodyDef-Daten)
## Keys werden 1:1 als Zeilen in der Infobox angezeigt
var infobox: Dictionary = {}  # String → String

## Content-Sections in Reihenfolge
## Jede Section: { "heading": String, "type": String, ... }
var sections: Array[Dictionary] = []

## Verwandte Konzept-IDs
var related_concepts: Array[String] = []

## Legacy: BBCode-Beschreibung (Abwärtskompatibilität)
var description: String = ""
