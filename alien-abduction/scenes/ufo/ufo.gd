class_name PlayerUFO
extends Node2D
## Das Spieler-UFO: schwebt über dem Mauszeiger, feuert Traktorstrahlen auf alles im Fangradius.

signal fired(at: Vector2, engaged: int)

const HOVER := 100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var beams: Node2D = $Beams
@onready var reticle: Reticle = $Reticle

var field: Rect2 = Rect2(0, 0, 1280, 720)
var cooldown: float = 0.0
var active: bool = true
var _anim: float = 0.0
var _tilt: float = 0.0
var _wobble: float = 0.0
var _query_shape: CircleShape2D = CircleShape2D.new()
var _freeze_timer: float = 0.0
var _base_scale: Vector2 = Vector2(3, 3)


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_skin()
	GameManager.cosmetics_changed.connect(_apply_skin)
	global_position = field.get_center()


func _apply_skin() -> void:
	sprite.texture = GameManager.ufo_texture()
	sprite.hframes = 2
	sprite.scale = _base_scale
	sprite.self_modulate = GameManager.ufo_tint()


func _process(delta: float) -> void:
	_anim += delta
	cooldown = maxf(0.0, cooldown - delta)
	var mouse := get_global_mouse_position()
	var goal := Vector2(clampf(mouse.x, field.position.x, field.end.x), clampf(mouse.y, field.position.y + 40.0, field.end.y) - HOVER)
	var old := global_position
	global_position = MathUtils.damp_v(global_position, goal, UpgradeManager.stat(&"ufo_speed"), delta)
	var vx := (global_position.x - old.x) / maxf(delta, 0.0001)
	_tilt = MathUtils.damp(_tilt, clampf(vx / 1800.0, -0.3, 0.3), 10.0, delta)
	_wobble = move_toward(_wobble, 0.0, delta * 3.0)
	sprite.rotation = _tilt
	sprite.position = Vector2(randf_range(-1, 1) * _wobble * 5.0, sin(_anim * 2.4) * 3.0 + randf_range(-1, 1) * _wobble * 3.0)
	sprite.frame = int(_anim * 4.0) % 2
	# Fadenkreuz
	reticle.global_position = mouse
	reticle.visible = active
	reticle.radius = MathUtils.damp(reticle.radius, UpgradeManager.stat(&"capture_radius"), 12.0, delta)
	reticle.cooldown_ratio = cooldown / maxf(0.01, UpgradeManager.stat(&"beam_cooldown"))
	reticle.color = GameManager.beam_color(_anim)
	# Skill "Angst vor Aliens": Ziele unter dem UFO erstarren
	if UpgradeManager.flag(&"freeze_under_ufo"):
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_freeze_timer = 0.12
			for t in query_targets(mouse, UpgradeManager.stat(&"capture_radius") * 1.3):
				t.freeze(0.25)
	queue_redraw()


func can_fire() -> bool:
	return active and cooldown <= 0.0


## Feuert den Traktorstrahl. Gibt die Anzahl erfasster Ziele zurück.
func fire(at: Vector2) -> int:
	cooldown = UpgradeManager.stat(&"beam_cooldown")
	var radius := UpgradeManager.stat(&"capture_radius")
	var hits := query_targets(at, radius)
	hits.sort_custom(func(a: BaseTarget, b: BaseTarget) -> bool:
		return a.body_center().distance_squared_to(at) < b.body_center().distance_squared_to(at))
	var max_engage := int(UpgradeManager.stat(&"max_captures"))
	var power := UpgradeManager.stat(&"click_power")
	var lift_time := 0.75 / maxf(0.1, UpgradeManager.stat(&"lift_speed"))
	var engaged := 0
	var color := GameManager.beam_color(_anim)
	for t in hits:
		if engaged >= max_engage:
			break
		var result := t.hit(power, self, &"player", lift_time)
		match result:
			BaseTarget.HitResult.CAPTURED:
				add_beam(t, color)
				if t.data.weight >= 1.5:
					squash(0.25 + t.data.weight * 0.05)
				_try_chain(t, power, lift_time, color)
				engaged += 1
			BaseTarget.HitResult.DAMAGED:
				flash_beam(t.body_center(), color)
				GameManager.float_text(t.body_center() + Vector2(randf_range(-10, 10), -20), "-" + MathUtils.format_number(power, true), Color(1, 0.6, 0.6), 16)
				engaged += 1
			BaseTarget.HitResult.DEFLECTED:
				flash_beam(t.body_center(), Color(1, 0.4, 0.4))
				engaged += 1
				if randf() < 0.3:
					GameManager.comment(&"robot")
	if engaged == 0:
		flash_beam(at, color)
		GameManager.effect(&"dust", at, Color(0.9, 0.9, 0.8))
		AudioManager.play(&"miss", randf_range(0.8, 1.2), -8.0)
	else:
		AudioManager.play(&"zap", randf_range(0.9, 1.15), -5.0)
	# Umstehende erschrecken sich
	var scare_r := radius * 3.0 * UpgradeManager.stat(&"scare_radius")
	for n in get_tree().get_nodes_in_group(&"targets"):
		var bt := n as BaseTarget
		if bt and bt.is_catchable() and bt.global_position.distance_to(at) < scare_r and randf() < 0.8:
			bt.scare(at)
	# Rückstoß
	sprite.scale = Vector2(_base_scale.x * 1.12, _base_scale.y * 0.88)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	GameManager.register_click(engaged > 0)
	fired.emit(at, engaged)
	return engaged


## Skill "Unfaire Physik": ein Treffer reißt Nachbarn mit
func _try_chain(origin: BaseTarget, power: float, lift_time: float, color: Color) -> void:
	var chance := UpgradeManager.stat(&"chain_chance")
	if chance <= 0.0:
		return
	for t in query_targets(origin.body_center(), 90.0):
		if t == origin or randf() >= chance:
			continue
		t.trajectory_changed = 1.0   # mitgerissen = veränderte Flugbahn
		if t.hit(power * 3.0, self, &"player", lift_time) == BaseTarget.HitResult.CAPTURED:
			add_beam(t, color)
			GameManager.float_text(t.body_center(), "KETTE!", UIStyle.PINK, 16)
			return


func query_targets(at: Vector2, radius: float) -> Array[BaseTarget]:
	var out: Array[BaseTarget] = []
	_query_shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _query_shape
	params.transform = Transform2D(0.0, at)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 1 << (BaseTarget.COLLISION_LAYER - 1)
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 64):
		var t := hit.get("collider") as BaseTarget
		if t and t.is_catchable():
			out.append(t)
	return out


func add_beam(t: BaseTarget, color: Color) -> void:
	var b := TractorBeam.new()
	b.setup(self, t, t.body_center(), color)
	beams.add_child(b)


func flash_beam(point: Vector2, color: Color) -> void:
	var b := TractorBeam.new()
	b.setup(self, null, point, color, true)
	beams.add_child(b)


## Squash & Stretch bei schweren Zielen
func squash(amount: float = 0.3) -> void:
	_wobble = maxf(_wobble, amount * 2.0)
	sprite.scale = Vector2(_base_scale.x * (1.0 + amount), _base_scale.y * (1.0 - amount))
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	# Schatten am Boden unter dem UFO
	var ground := Vector2(0, HOVER + 8.0)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(ground + Vector2(cos(a) * 40.0, sin(a) * 9.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.16))
