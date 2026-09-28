class_name EffectsLayer
extends Node2D
## Hört auf GameManager-Signale und erzeugt Floating Text & Partikel in der Welt.

const FLOATING_TEXT := preload("res://scenes/effects/floating_text.tscn")
const PARTICLES := preload("res://scenes/effects/abduction_particles.tscn")
const MAX_TEXTS := 40


func _ready() -> void:
	z_index = 60
	GameManager.floating_text_requested.connect(spawn_text)
	GameManager.effect_requested.connect(spawn_effect)


func spawn_text(world_pos: Vector2, text: String, color: Color, size: int) -> void:
	if get_child_count() > MAX_TEXTS + 30:
		return
	var ft: FloatingText = FLOATING_TEXT.instantiate()
	add_child(ft)
	ft.popup(world_pos, text, color, size)


func spawn_effect(kind: StringName, world_pos: Vector2, color: Color) -> void:
	if not GameManager.settings.get("particles", true) and kind != &"gold":
		return
	var p: AbductionParticles = PARTICLES.instantiate()
	p.position = world_pos
	add_child(p)
	p.play(kind, color)
