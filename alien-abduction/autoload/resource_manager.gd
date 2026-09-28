extends Node
## Verwaltet alle Währungen: Credits, Biomasse, Alien-Daten, Skillpunkte, Kosmischer Ruf – plus Energie.

signal resource_changed(type: StringName, amount: float, delta: float)
signal energy_changed(current: float, maximum: float)

const CREDITS := &"credits"
const BIOMASS := &"biomass"
const DATA := &"data"
const SKILL_POINTS := &"skill_points"
const RUF := &"ruf"
const ALL: Array[StringName] = [&"credits", &"biomass", &"data", &"skill_points", &"ruf"]
## Diese Währungen gehen beim Planetenraub verloren
const RESET_ON_PRESTIGE: Array[StringName] = [&"credits", &"biomass"]

const INFO := {
	&"credits": {"name": "Credits", "icon": "res://assets/icons/coin.png"},
	&"biomass": {"name": "Biomasse", "icon": "res://assets/icons/biomass.png"},
	&"data": {"name": "Alien-Daten", "icon": "res://assets/icons/data.png"},
	&"skill_points": {"name": "Skillpunkte", "icon": "res://assets/icons/skillpoint.png"},
	&"ruf": {"name": "Kosmischer Ruf", "icon": "res://assets/icons/ruf.png"},
}

var amounts: Dictionary = {}
var run_totals: Dictionary = {}
var lifetime_totals: Dictionary = {}
var energy: float = 0.0
var _icons: Dictionary = {}


func _ready() -> void:
	reset_all()
	for type in ALL:
		_icons[type] = load(INFO[type]["icon"])


func reset_all() -> void:
	for type in ALL:
		amounts[type] = 0.0
		run_totals[type] = 0.0
		lifetime_totals[type] = 0.0
	energy = 0.0


func icon(type: StringName) -> Texture2D:
	return _icons.get(type)


func display_name(type: StringName) -> String:
	return INFO.get(type, {"name": String(type)})["name"]


func get_amount(type: StringName) -> float:
	return float(amounts.get(type, 0.0))


func run_total(type: StringName) -> float:
	return float(run_totals.get(type, 0.0))


func lifetime_total(type: StringName) -> float:
	return float(lifetime_totals.get(type, 0.0))


func add(type: StringName, amount: float) -> void:
	if amount <= 0.0 or is_nan(amount):
		return
	amounts[type] = get_amount(type) + amount
	run_totals[type] = run_total(type) + amount
	lifetime_totals[type] = lifetime_total(type) + amount
	resource_changed.emit(type, amounts[type], amount)


func can_afford(type: StringName, amount: float) -> bool:
	return get_amount(type) + 0.0001 >= amount


func spend(type: StringName, amount: float) -> bool:
	if not can_afford(type, amount):
		return false
	amounts[type] = maxf(0.0, get_amount(type) - amount)
	resource_changed.emit(type, amounts[type], -amount)
	return true


func set_amount(type: StringName, value: float) -> void:
	var old := get_amount(type)
	amounts[type] = maxf(0.0, value)
	resource_changed.emit(type, amounts[type], amounts[type] - old)


# ---------------------------------------------------------------- Energie

func energy_max() -> float:
	return UpgradeManager.stat(&"energy_max")


func energy_unlocked() -> bool:
	return UpgradeManager.flag(&"unlock_gadgets")


func spend_energy(amount: float) -> bool:
	if energy + 0.001 < amount:
		return false
	energy -= amount
	energy_changed.emit(energy, energy_max())
	return true


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, energy_max())
	energy_changed.emit(energy, energy_max())


func _process(delta: float) -> void:
	if not energy_unlocked():
		return
	var maximum := energy_max()
	if energy < maximum:
		energy = minf(maximum, energy + UpgradeManager.stat(&"energy_regen") * delta)
		energy_changed.emit(energy, maximum)


# ---------------------------------------------------------------- Prestige & Speichern

func reset_for_prestige() -> void:
	for type in RESET_ON_PRESTIGE:
		amounts[type] = 0.0
	for type in ALL:
		run_totals[type] = 0.0
		resource_changed.emit(type, get_amount(type), 0.0)


func to_dict() -> Dictionary:
	return {"amounts": _stringify(amounts), "run": _stringify(run_totals), "life": _stringify(lifetime_totals), "energy": energy}


func from_dict(d: Dictionary) -> void:
	reset_all()
	var a := SaveSystem.get_dict(d, "amounts")
	var r := SaveSystem.get_dict(d, "run")
	var l := SaveSystem.get_dict(d, "life")
	for type in ALL:
		amounts[type] = SaveSystem.get_float(a, String(type))
		run_totals[type] = SaveSystem.get_float(r, String(type))
		lifetime_totals[type] = SaveSystem.get_float(l, String(type))
		resource_changed.emit(type, amounts[type], 0.0)
	energy = SaveSystem.get_float(d, "energy")


func _stringify(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[String(k)] = dict[k]
	return out
