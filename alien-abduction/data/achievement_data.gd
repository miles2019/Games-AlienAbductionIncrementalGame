class_name AchievementData
extends Resource
## Erfolg: wird freigeschaltet, sobald GameManager.get_stat_value(stat) >= threshold.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var stat: StringName = &""
@export var threshold: float = 1.0
## Dauerhafter Credit-Bonus (0.02 = +2 %)
@export var bonus: float = 0.02
@export var secret: bool = false
@export var sort_order: int = 0
