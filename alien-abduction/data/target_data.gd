class_name TargetData
extends Resource
## Beschreibt einen Zieltyp (Mensch, Kuh, Auto, ...). Neue Einheiten einfach im Editor
## als neue TargetData-Resource unter res://data/targets/ anlegen und einem Planeten zuweisen.

enum Movement { WANDER, DRIVE, FLOCK, STATIONARY }
enum Reaction { NONE, PANIC, STARE, HONK, RESIST, FLEE }
## Grobe Zielart – für Statistik, Erfolge und Fluchtverhalten (Tiere weichen zufällig aus, Autos fahren weg).
enum Kind { HUMAN, ANIMAL, VEHICLE, MACHINE, OTHER }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.HUMAN

@export_group("Darstellung")
## Varianten – beim Spawnen wird eine zufällig gewählt. Spritesheet mit 4 Frames:
## 0/1 = Laufen, 2 = Reaktion, 3 = Eingesaugt.
@export var textures: Array[Texture2D] = []
@export var hframes: int = 4
@export var pixel_scale: float = 3.0
@export var shadow_width: float = 12.0
@export var fly_height: float = 0.0
## Optional eigene Szene (muss ein BaseTarget sein). Leer = base_target.tscn
@export var scene: PackedScene

@export_group("Werte")
@export var base_hp: float = 1.0
## Schwere Ziele brauchen länger und bringen das UFO zum Wackeln.
@export var weight: float = 1.0
@export var credits: float = 1.0
@export var biomass: float = 0.0
@export var alien_data: float = 0.0
@export_range(0.0, 1.0) var data_chance: float = 0.01
@export var xp: float = 1.0
@export var mothership_charge: float = 1.0
## Braucht mindestens diese Saugkraft, sonst prallt der Strahl ab.
@export var min_power: float = 0.0
@export_range(0.0, 1.0) var escape_chance: float = 0.03

@export_group("Bewegung")
@export var movement: Movement = Movement.WANDER
@export var speed_min: float = 30.0
@export var speed_max: float = 60.0
## Sekunden bis das Ziel das Feld wieder verlässt.
@export var lifetime: float = 45.0
@export var group_size: int = 1

@export_group("Spawn")
@export var spawn_weight: float = 10.0
## Upgrade/Forschung, die das Ziel freischaltet (leer = immer verfügbar).
@export var required_upgrade: StringName = &""
@export var is_rare: bool = false
@export var is_golden: bool = false
@export var is_boss: bool = false

@export_group("Reaktion")
@export var reaction: Reaction = Reaction.PANIC
@export var sound: StringName = &"slurp"
@export var reaction_lines: Array[String] = []
@export var abduct_lines: Array[String] = []


func pick_texture() -> Texture2D:
	if textures.is_empty():
		return null
	return textures.pick_random()


func random_speed() -> float:
	return randf_range(speed_min, speed_max)
