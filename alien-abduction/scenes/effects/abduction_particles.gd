class_name AbductionParticles
extends CPUParticles2D
## Einmalige Partikel-Explosion: burst, gold, sparks, dust, confetti. Löscht sich selbst.


func play(kind: StringName, tint: Color) -> void:
	texture = load("res://assets/sprites/pixel.png")
	one_shot = true
	explosiveness = 0.95
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 6.0
	spread = 180.0
	color = tint
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	color_ramp = ramp
	match kind:
		&"gold":
			amount = 40
			lifetime = 0.9
			initial_velocity_min = 120.0
			initial_velocity_max = 380.0
			gravity = Vector2(0, 500)
			scale_amount_min = 1.0
			scale_amount_max = 2.2
			texture = load("res://assets/sprites/sparkle.png")
		&"sparks":
			amount = 10
			lifetime = 0.35
			initial_velocity_min = 80.0
			initial_velocity_max = 220.0
			gravity = Vector2(0, 300)
			scale_amount_min = 0.5
			scale_amount_max = 1.0
		&"dust":
			amount = 10
			lifetime = 0.5
			direction = Vector2(0, -1)
			spread = 70.0
			initial_velocity_min = 30.0
			initial_velocity_max = 110.0
			gravity = Vector2(0, 150)
			scale_amount_min = 1.0
			scale_amount_max = 2.2
		&"confetti":
			amount = 50
			lifetime = 1.4
			direction = Vector2(0, -1)
			spread = 60.0
			initial_velocity_min = 200.0
			initial_velocity_max = 500.0
			gravity = Vector2(0, 600)
			scale_amount_min = 1.0
			scale_amount_max = 2.0
			hue_variation_min = -1.0
			hue_variation_max = 1.0
			color = Color(1, 0.5, 0.5)
		_:
			amount = 16
			lifetime = 0.6
			initial_velocity_min = 80.0
			initial_velocity_max = 260.0
			gravity = Vector2(0, 400)
			scale_amount_min = 0.8
			scale_amount_max = 1.8
	finished.connect(queue_free)
	emitting = true
