class_name HumanTarget
extends BaseTarget
## Menschen: rennen panisch weg, winken dem UFO zu, schreien beim Einsaugen.


func _on_scared(from_pos: Vector2) -> void:
	_react(1.6)
	_run_away(from_pos, 2.6)
	if randf() < 0.25:
		_say(data.reaction_lines, 1.0, Color(1, 0.92, 0.92))
		AudioManager.play(&"scream", randf_range(0.8, 1.4), -10.0, 0.25)


func _on_idle() -> void:
	# stehen bleiben und winken / nach oben schauen
	if randf() < 0.5:
		_react(1.2)
		desired_velocity = Vector2.ZERO
		if randf() < 0.3:
			_say(["Hallo?", "Ist das ein Vogel?", "Huhu!", "Was ist DAS?", "Mama, guck mal!"], 1.0)


func _on_lift_started() -> void:
	if randf() < 0.35:
		AudioManager.play(&"scream", randf_range(0.9, 1.5), -8.0, 0.15)
