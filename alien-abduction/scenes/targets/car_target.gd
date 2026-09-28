class_name CarTarget
extends BaseTarget
## Autos: fahren geradeaus, hupen bei Gefahr, brauchen mehr Saugkraft.


func _on_spawned() -> void:
	desired_velocity = Vector2(signf(desired_velocity.x) if desired_velocity.x != 0.0 else 1.0, 0.0) * speed
	_velocity = desired_velocity


func _honk() -> void:
	AudioManager.play(&"honk", randf_range(0.9, 1.1), -6.0, 0.2)
	GameManager.float_text(global_position + Vector2(0, -body_height() - 12), ["HUP!", "HUP HUP!", "TÖÖÖT!", "Aus dem Weg!"].pick_random(), Color(1.0, 0.95, 0.5), 18)


func _on_scared(_from_pos: Vector2) -> void:
	_react(0.5)
	desired_velocity = desired_velocity.normalized() * speed * 1.8
	if randf() < 0.5:
		_honk()


func _on_damaged(_source_node: Node2D) -> void:
	_honk()
	desired_velocity = desired_velocity.normalized() * speed * 1.4


func _on_react_finished() -> void:
	pass


func _on_idle() -> void:
	if randf() < 0.15:
		_honk()
