## UnitValueDisplay
## Zeigt einen beschrifteten Messwert mit Einheit an.
## Formatiert Werte automatisch basierend auf dem Einheitstyp.
@tool
class_name UnitValueDisplay
extends VBoxContainer

## Einheitstypen für automatische Formatierung
enum UnitType {
	CUSTOM,        ## Manuelle Angabe (Fallback)
	DISTANCE,      ## Automatisch AU/km basierend auf Größe
	PERIOD,        ## Zeitraum: Jahre/Tage
	VELOCITY,      ## Geschwindigkeit: km/s
	MASS,          ## Masse: kg (wissenschaftliche Notation)
	DENSITY,       ## Dichte: g/cm³
	ACCELERATION,  ## Beschleunigung: m/s²
	PRESSURE,      ## Druck: bar
	TEMPERATURE,   ## Temperatur: °C
	PERCENTAGE,    ## Prozent: %
	DIMENSIONLESS, ## Keine Einheit (z.B. Exzentrizität)
}

## Schwellenwert ab dem Distanzen in AU statt km angezeigt werden (0.01 AU ≈ 1.5 Mio km)
const AU_THRESHOLD_KM := 1_000_000.0
## km pro AU
const KM_PER_AU := 149_597_870.7
## Sekunden pro Tag
const SECONDS_PER_DAY := 86400.0
## Tage pro Jahr
const DAYS_PER_YEAR := 360.0

@export var caption: String = "caption"
@export var value: String = "0"
@export var unit: String = "unit"

@onready var _caption: Label = $Caption
@onready var _value:   Label = $Panel/HBox/Value
@onready var _unit:    Label = $Panel/HBox/Unit

func _ready() -> void:
	setup(caption, value, unit)


## Manuelle Angabe von Wert und Einheit (Legacy-Kompatibilität)
func setup(new_caption: String, new_value: String, new_unit: String) -> void:
	caption = new_caption
	value = new_value
	unit = new_unit
	
	_caption.text = caption
	_value.text   = value
	_unit.text    = unit


## Automatische Formatierung basierend auf Einheitstyp
## raw_value: Der Rohwert in der Basiseinheit (km, Sekunden, kg, etc.)
func setup_auto(new_caption: String, raw_value: float, unit_type: UnitType) -> void:
	caption = new_caption
	_caption.text = caption
	
	var formatted := _format_value(raw_value, unit_type)
	value = formatted.value
	unit = formatted.unit
	
	_value.text = value
	_unit.text = unit


## Wert aktualisieren mit automatischer Formatierung
func set_value_auto(raw_value: float, unit_type: UnitType) -> void:
	var formatted := _format_value(raw_value, unit_type)
	value = formatted.value
	unit = formatted.unit
	_value.text = value
	_unit.text = unit


## Legacy: Manuelles Setzen des Werts
func set_value(new_value: String) -> void:
	value = new_value
	_value.text = new_value


## Formatiert einen Rohwert basierend auf dem Einheitstyp
func _format_value(raw_value: float, unit_type: UnitType) -> Dictionary:
	if is_nan(raw_value) or is_inf(raw_value):
		return { "value": "—", "unit": "" }
	
	match unit_type:
		UnitType.DISTANCE:
			return _format_distance(raw_value)
		UnitType.PERIOD:
			return _format_period(raw_value)
		UnitType.VELOCITY:
			return _format_velocity(raw_value)
		UnitType.MASS:
			return _format_mass(raw_value)
		UnitType.DENSITY:
			return _format_simple(raw_value, 2, "g/cm³")
		UnitType.ACCELERATION:
			return _format_simple(raw_value, 2, "m/s²")
		UnitType.PRESSURE:
			return _format_simple(raw_value, 3, "bar")
		UnitType.TEMPERATURE:
			return _format_simple(raw_value, 1, "°C")
		UnitType.PERCENTAGE:
			return _format_simple(raw_value, 2, "%")
		UnitType.DIMENSIONLESS:
			return _format_dimensionless(raw_value)
		_:
			return { "value": str(raw_value), "unit": "" }


## Distanz: Automatisch AU oder km wählen
func _format_distance(km: float) -> Dictionary:
	if is_zero_approx(km):
		return { "value": "—", "unit": "" }
	
	if absf(km) >= AU_THRESHOLD_KM:
		var au := km / KM_PER_AU
		return { "value": "%.4f" % au, "unit": "AU" }
	else:
		if absf(km) >= 1000.0:
			return { "value": "%.1f" % km, "unit": "km" }
		else:
			return { "value": "%.2f" % km, "unit": "km" }


## Zeitraum: Jahre oder Tage (Eingabe in Sekunden)
func _format_period(seconds: float) -> Dictionary:
	if seconds <= 0.0:
		return { "value": "—", "unit": "" }
	
	var days := seconds / SECONDS_PER_DAY
	if days >= DAYS_PER_YEAR:
		var years := days / DAYS_PER_YEAR
		return { "value": "%.2f" % years, "unit": "a" }
	else:
		return { "value": "%.1f" % days, "unit": "d" }


## Geschwindigkeit: km/s
func _format_velocity(km_s: float) -> Dictionary:
	if is_zero_approx(km_s):
		return { "value": "—", "unit": "" }
	return { "value": "%.2f" % km_s, "unit": "km/s" }


## Masse: Wissenschaftliche Notation
func _format_mass(kg: float) -> Dictionary:
	if kg <= 0.0:
		return { "value": "—", "unit": "" }
	
	var magnitude := floori(log(kg) / log(10.0))
	var mantissa := kg / pow(10.0, float(magnitude))
	return { "value": "%.3f e%d" % [mantissa, magnitude], "unit": "kg" }


## Einfache Formatierung mit fester Dezimalanzahl
func _format_simple(val: float, decimals: int, unit_str: String) -> Dictionary:
	if is_zero_approx(val):
		return { "value": "—", "unit": "" }
	return { "value": "%.*f" % [decimals, val], "unit": unit_str }


## Dimensionslos (z.B. Exzentrizität)
func _format_dimensionless(val: float) -> Dictionary:
	if is_zero_approx(val):
		return { "value": "0", "unit": "" }
	return { "value": "%.4f" % val, "unit": "" }
