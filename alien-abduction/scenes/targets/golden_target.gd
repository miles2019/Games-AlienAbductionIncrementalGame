class_name GoldenTarget
extends BaseTarget
## Goldene Ziele: selten, glitzern, flüchten vor dem Mauszeiger, geben ein Vielfaches.

var _sparkles: CPUParticles2D


func _on_spawned() -> void:
	_sparkles = CPUParticles2D.new()
	_sparkles.texture = load("res://assets/sprites/sparkle.png")
	_sparkles.amount = 14
	_sparkles.lifetime = 0.9
	_sparkles.local_coords = false
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkles.emission_rect_extents = Vector2(_frame_size.x * data.pixel_scale * 0.45, _frame_size.y * data.pixel_scale * 0.4)
	_sparkles.position = Vector2(0, -body_height() * 0.5)
	_sparkles.gravity = Vector2(0, -30)
	_sparkles.initial_velocity_min = 5.0
	_sparkles.initial_velocity_max = 20.0
	_sparkles.scale_amount_min = 1.0
	_sparkles.scale_amount_max = 2.5
	_sparkles.color = Color(1.0, 0.95, 0.55)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.8, 1))
	ramp.set_color(1, Color(1, 0.8, 0.2, 0))
	_sparkles.color_ramp = ramp
	add_child(_sparkles)
	# Schimmern
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "modulate", Color(1.4, 1.3, 0.9), 0.35)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)
	AudioManager.play(&"gold", 1.3, -8.0)


func _process(delta: float) -> void:
	super(delta)
	# flüchtet vor dem Mauszeiger
	if is_catchable() and state != State.REACT:
		var mouse := get_global_mouse_position()
		if mouse.distance_to(body_center()) < 150.0:
			_react(0.7, false)
			_run_away(mouse, 2.0)


func _on_lift_started() -> void:
	if _sparkles:
		_sparkles.amount = 30
