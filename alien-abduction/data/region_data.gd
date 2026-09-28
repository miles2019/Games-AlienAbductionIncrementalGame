class_name RegionData
extends Resource
## Eine Region eines Planeten (z. B. Dorf, Großstadt, Sperrgebiet): eigene Zielkapazität,
## eigener Nachschub und eigene Zielmischung. Wird als Sub-Resource im Planeten gespeichert.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Ab diesem Spieler-Level wählbar
@export var unlock_level: int = 1

@export_group("Population")
## Faktor auf die maximale Zielanzahl (Zielkapazität)
@export var capacity: float = 1.0
## Faktor auf die Nachschubrate
@export var resupply: float = 1.0
## Credit-Faktor – dünn besiedelte Regionen sind wertvoller
@export var value_multiplier: float = 1.0
## Ziel-ID -> Gewichtsfaktor (z. B. {&"human": 2.5} für Großstädte)
@export var weight_multipliers: Dictionary = {}
## Wie der Nachschub anrollt: bus, train, truck, caravan
@export var transport: StringName = &"bus"
@export var transport_name: String = "Bus"

@export_group("Kartografie")
## Entführungen in dieser Region, bis sie vollständig kartografiert ist
@export var map_goal: int = 150


func weight_for(target_id: StringName) -> float:
	return float(weight_multipliers.get(target_id, 1.0))
