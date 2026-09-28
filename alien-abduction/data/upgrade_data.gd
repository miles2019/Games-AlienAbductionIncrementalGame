class_name UpgradeData
extends Resource
## Generische Definition für alles Kaufbare: UFO-Upgrades, Crew, Forschung, Skilltree-Knoten,
## Ruf-Shop und Dekoration. Der UpgradeManager lädt alle Resources aus res://data/upgrades/.

enum Category { UFO, CREW, CREW_MEMBER, BIOLAB, RESEARCH, SKILL, RUF, COSMETIC }
enum CostFormula { EXPONENTIAL, LINEAR, POLYNOMIAL, LOGARITHMIC, FIXED }
## ADD: +Wert pro Stufe · PERCENT: +Wert*100 % pro Stufe · MULTIPLY: *Wert pro Stufe · UNLOCK: Schalter
enum EffectMode { ADD, PERCENT, MULTIPLY, UNLOCK }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.UFO
@export var sort_order: int = 0

@export_group("Kosten")
## credits, biomass, data, skill_points, ruf
@export var currency: StringName = &"credits"
@export var cost_formula: CostFormula = CostFormula.EXPONENTIAL
@export var base_cost: float = 10.0
@export var cost_scaling: float = 1.15
## 0 = unbegrenzt
@export var max_level: int = 0

@export_group("Effekt")
@export var effect_stat: StringName = &""
@export var effect_mode: EffectMode = EffectMode.ADD
@export var effect_value: float = 0.0
@export var effect2_stat: StringName = &""
@export var effect2_mode: EffectMode = EffectMode.PERCENT
@export var effect2_value: float = 0.0

@export_group("Freischaltung")
## Liste von "upgrade_id" oder "upgrade_id:stufe"
@export var requirements: Array[String] = []
@export var resets_on_prestige: bool = true
## Versteckt, bis alle Voraussetzungen erfüllt sind (Geheimknoten)
@export var secret: bool = false

@export_group("Skilltree")
@export var branch: int = 0
@export var tree_position: Vector2 = Vector2.ZERO

@export_group("Flavor")
## Kommentar der Crew beim Kauf
@export var flavor: String = ""


func cost_at(level: int) -> float:
	match cost_formula:
		CostFormula.EXPONENTIAL:
			return base_cost * pow(cost_scaling, level)
		CostFormula.LINEAR:
			return base_cost + cost_scaling * level
		CostFormula.POLYNOMIAL:
			return base_cost * pow(level + 1.0, cost_scaling)
		CostFormula.LOGARITHMIC:
			return base_cost * (1.0 + cost_scaling * log(level + 1.0) * (level + 1.0))
		_:
			return base_cost


## Gesamtkosten für `amount` Stufen ab `level`.
func cost_for(level: int, amount: int) -> float:
	if amount <= 0:
		return 0.0
	if cost_formula == CostFormula.EXPONENTIAL and not is_equal_approx(cost_scaling, 1.0):
		return ceil(base_cost * pow(cost_scaling, level) * (pow(cost_scaling, amount) - 1.0) / (cost_scaling - 1.0))
	var total := 0.0
	for i in amount:
		total += cost_at(level + i)
	return ceil(total)


## Wie viele Stufen man sich mit `budget` leisten kann (für "Max kaufen").
func max_affordable(level: int, budget: float) -> int:
	var cap := remaining_levels(level)
	if cost_formula == CostFormula.EXPONENTIAL and cost_scaling > 1.0:
		var first := base_cost * pow(cost_scaling, level)
		if budget < first:
			return 0
		var n := int(floor(log(budget * (cost_scaling - 1.0) / first + 1.0) / log(cost_scaling)))
		while n > 0 and cost_for(level, n) > budget:
			n -= 1
		return mini(n, cap)
	var count := 0
	var spent := 0.0
	while count < cap and count < 1000:
		var c := ceilf(cost_at(level + count))
		if spent + c > budget:
			break
		spent += c
		count += 1
	return count


func remaining_levels(level: int) -> int:
	if max_level <= 0:
		return 1000000
	return maxi(0, max_level - level)


func is_one_time() -> bool:
	return max_level == 1
