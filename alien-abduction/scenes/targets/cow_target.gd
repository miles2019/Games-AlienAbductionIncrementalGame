class_name CowTarget
extends BaseTarget
## Kühe: bleiben stehen und glotzen direkt in die Kamera. Schwer und befriedigend.


func _on_scared(_from_pos: Vector2) -> void:
	_react(1.5)
	desired_velocity = Vector2.ZERO
	if randf() < 0.2:
		_say(data.reaction_lines, 1.0)


func _on_idle() -> void:
	if randf() < 0.6:
		_react(randf_range(1.2, 2.2))
		desired_velocity = Vector2.ZERO
		if randf() < 0.25:
			_say(data.reaction_lines, 1.0)
			AudioManager.play(&"moo", randf_range(0.8, 1.15), -12.0, 0.5)


func _on_lift_started() -> void:
	if randf() < 0.5:
		AudioManager.play(&"moo", randf_range(0.85, 1.2), -6.0, 0.2)
