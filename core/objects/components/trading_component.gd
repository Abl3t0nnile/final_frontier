## TradingComponent
## Handels-Features für Stationen
## Erweitert: GameDataComponent

class_name TradingComponent
extends GameDataComponent

## Public Properties
var has_market: bool : get = get_has_market

## Private
var _has_market: bool = false

## Getters
func get_has_market() -> bool:
	return _has_market
