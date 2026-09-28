class_name PlanetData
extends Resource
## Ein Planet: Bodenfarben, eigene Ziele, Multiplikatoren und Sonderregeln.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Reihenfolge – Planet n wird nach n Planetenrauben freigeschaltet.
@export var order: int = 0

@export_group("Hintergrund")
@export var ground_color: Color = Color(0.45, 0.72, 0.35)
@export var ground_color_2: Color = Color(0.4, 0.66, 0.31)
@export var detail_color: Color = Color(0.32, 0.55, 0.26)
@export var detail_color_2: Color = Color(1, 1, 1)
## grass, sand, snow, metal, candy
@export var detail_style: StringName = &"grass"

@export_group("Ziele")
@export var targets: Array[TargetData] = []
@export var golden_target: TargetData
## Regionen mit eigener Zielkapazität und eigenem Nachschub (erste = Startregion)
@export var regions: Array[RegionData] = []

@export_group("Regeln")
@export var credit_multiplier: float = 1.0
@export var spawn_rate_multiplier: float = 1.0
@export var max_targets_multiplier: float = 1.0
@export var target_speed_multiplier: float = 1.0
@export var target_scale: float = 1.0
@export var target_hp_multiplier: float = 1.0
@export var beam_cooldown_multiplier: float = 1.0
## Eisplanet: Ziele rutschen
@export var slippery: bool = false
@export var rule_text: String = ""
