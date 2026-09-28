class_name BirdTarget
extends BaseTarget
## Vögel: fliegen im Schwarm quer übers Feld, zerstreuen sich bei Gefahr.

var flock_offset: float = 0.0


func _on_spawned() -> void:
	flock_offset = randf() * TAU


func _on_scared(_from_pos: Vector2) -> void:
	_react(0.8, false)
	desired_velocity = desired_velocity.rotated(randf_range(-0.9, 0.9)) * 1.6
	if randf() < 0.3:
		AudioManager.play(&"tweet", randf_range(0.9, 1.3), -10.0, 0.1)


func _on_react_finished() -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	if state == State.ROAM or state == State.ENTER:
		desired_velocity = desired_velocity.rotated(sin(anim_time * 2.0 + flock_offset) * 0.3 * delta)
