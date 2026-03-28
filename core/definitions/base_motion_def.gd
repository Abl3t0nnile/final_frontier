## BaseMotionDef
## Abstrakte Basisklasse für alle Bewegungsmodelle
## Erweitert: RefCounted

class_name BaseMotionDef
extends RefCounted

## Public Properties
var model: String : get = get_model

## Private
var _model: String = ""

## Getters
func get_model() -> String:
	return _model
