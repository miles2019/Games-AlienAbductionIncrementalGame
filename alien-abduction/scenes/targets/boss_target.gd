class_name BossTarget
extends BaseTarget
## Boss (Riesenkuh): viel HP, stampft, der Bildschirm bebt.

var _stomp_timer: float = 2.0


func _on_spawned() -> void:
	AudioManager.play(&"stomp", 0.7)
	GameManager.shake(12.0)
	GameManager.comment(&"boss")


func _process(delta: float) -> void:
	super(delta)
	if is_catchable():
		_stomp_timer -= delta
		if _stomp_timer <= 0.0:
			_stomp_timer = randf_range(1.8, 3.0)
			AudioManager.play(&"stomp", randf_range(0.8, 1.0), -2.0)
			GameManager.shake(6.0)
			GameManager.effect(&"dust", global_position, Color(0.8, 0.75, 0.6))
			_squash()


func _on_scared(_from_pos: Vector2) -> void:
	if randf() < 0.3:
		_say(data.reaction_lines, 1.0, Color(1, 0.8, 1))


func _on_damaged(_source_node: Node2D) -> void:
	_hp_bar_time = 99.0
	if randf() < 0.15:
		AudioManager.play(&"moo", 0.55, -2.0, 0.4)


func _on_lift_started() -> void:
	AudioManager.play(&"moo", 0.5, 0.0)
	GameManager.shake(16.0)
