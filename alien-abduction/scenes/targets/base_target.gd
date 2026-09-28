class_name BaseTarget
extends Area2D
## Basis für alle entführbaren Ziele. Werte kommen aus einer TargetData-Resource.
## Unterklassen (Mensch, Kuh, Auto, ...) überschreiben nur die Reaktionen.

signal abducted(target: BaseTarget, source: StringName, reward_mult: float)
signal escaped(target: BaseTarget)

enum State { ENTER, ROAM, REACT, LIFT, FALL, LEAVE }
enum HitResult { NONE, DEFLECTED, DAMAGED, CAPTURED }

const COLLISION_LAYER := 2

@export var data: TargetData

var state: State = State.ENTER
var hp: float = 1.0
var max_hp: float = 1.0
var speed: float = 40.0
var field: Rect2 = Rect2(0, 0, 1280, 720)
var age: float = 0.0
var lifetime: float = 40.0
var state_time: float = 0.0
var react_duration: float = 0.0
var react_frame: bool = false
var anim_time: float = 0.0
var scale_mult: float = 1.0
var hp_mult: float = 1.0
var slippery: bool = false
var shielded: bool = false
var marked: bool = false
var frozen: float = 0.0
var reward_mult: float = 1.0
## Zusatzbonus (z. B. Entführungsfehler-Event)
var bonus_mult: float = 1.0
## Parade: läuft stur geradeaus
var force_straight: bool = false
var lift_source: StringName = &"player"
var desired_velocity: Vector2 = Vector2.ZERO
## Wurde durch einen Entführungsfehler abgeworfen (Erfolg "Das war nicht geplant")
var from_mistake: bool = false
## Sekunden, in denen die Flugbahn als "verändert" gilt (Kettenreaktion, Rutschen, Absturz aus dem Strahl)
var trajectory_changed: float = 0.0
## Sekunden aktiver Flucht (rennt weg, schlägt Haken)
var fleeing: float = 0.0

## Grund-Wahrscheinlichkeit pro Prüfung, dass ein Mensch den Lichtkegel bemerkt
const NOTICE_CHANCE := 0.22
const NOTICE_RADIUS := 130.0
## Vorwarnzeit (s), bevor seltene Ziele fliehen
const WARN_TIME := 2.5

var _velocity: Vector2 = Vector2.ZERO
var _turn_timer: float = 0.0
var _idle_timer: float = 3.0
var _lift_anchor: Node2D
var _anchor_pos: Vector2
var _lift_from: Vector2
var _lift_progress: float = 0.0
var _lift_tween: Tween
var _escape_at: float = -1.0
var _spin: float = 0.0
var _hp_bar_time: float = 0.0
var _flash: float = 0.0
var _ground_y: float = 0.0
var _frame_size: Vector2 = Vector2(16, 16)
var _was_inside: bool = false
var _dodge_time: float = 0.0
var _erratic_timer: float = 0.0
var _notice_timer: float = 0.0
## Vorwarnung seltener Ziele: < 0 = keine, sonst verbleibende Sekunden bis zur Flucht
var _warn_left: float = -1.0
var _warn_total: float = 1.0
var _warned: bool = false
## Ein Ziel kann dem Strahl nur einmal entkommen
var _lift_escaped: bool = false
var _capture_ctx: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


## Vor add_child() aufrufen.
func configure(p_data: TargetData, p_field: Rect2, enter_velocity_dir: Vector2, p_hp_mult: float = 1.0,
		p_scale_mult: float = 1.0, p_slippery: bool = false) -> void:
	data = p_data
	field = p_field
	hp_mult = p_hp_mult
	scale_mult = p_scale_mult
	slippery = p_slippery
	speed = data.random_speed()
	desired_velocity = enter_velocity_dir.normalized() * speed
	_velocity = desired_velocity


func _ready() -> void:
	add_to_group(&"targets")
	collision_layer = 1 << (COLLISION_LAYER - 1)
	collision_mask = 0
	monitoring = false
	input_pickable = false
	if data == null:
		push_warning("BaseTarget ohne TargetData")
		queue_free()
		return
	max_hp = data.base_hp * hp_mult
	hp = max_hp
	lifetime = data.lifetime * randf_range(0.8, 1.2)
	if data.is_golden:
		lifetime *= UpgradeManager.stat(&"golden_linger")
	anim_time = randf() * 10.0
	_turn_timer = randf_range(0.5, 2.5)
	_idle_timer = randf_range(3.0, 9.0)
	_setup_visuals()
	_on_spawned()


func _setup_visuals() -> void:
	sprite.texture = data.pick_texture()
	sprite.hframes = maxi(1, data.hframes)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := data.pixel_scale * scale_mult
	sprite.scale = Vector2(s, s)
	if sprite.texture:
		_frame_size = Vector2(sprite.texture.get_width() / float(sprite.hframes), sprite.texture.get_height())
	sprite.centered = true
	sprite.offset = Vector2(0, -_frame_size.y * 0.5)
	sprite.position = Vector2(0, -data.fly_height)
	var shape := CircleShape2D.new()
	shape.radius = maxf(_frame_size.x, _frame_size.y) * 0.5 * s * 0.8
	collision.shape = shape
	collision.position = Vector2(0, -_frame_size.y * 0.5 * s - data.fly_height)


## Mittelpunkt des Körpers in Weltkoordinaten (für Zielerfassung & Strahl)
func body_center() -> Vector2:
	return global_position + collision.position * scale


func body_height() -> float:
	return _frame_size.y * data.pixel_scale * scale_mult


func is_catchable() -> bool:
	return (state == State.ENTER or state == State.ROAM or state == State.REACT or state == State.LEAVE) \
		and not shielded and not is_queued_for_deletion()


func is_lifting() -> bool:
	return state == State.LIFT


## Ist das Ziel gerade auf der Flucht? (wegrennen oder angekündigte Flucht seltener Ziele)
func is_fleeing() -> bool:
	return fleeing > 0.0 or _warn_left >= 0.0 or (state == State.LEAVE and _warned)


func is_warning() -> bool:
	return _warn_left >= 0.0


## Kontext beim Einfangen (für Belohnung & Erfolge) – wird in start_lift() festgehalten
func capture_context() -> Dictionary:
	return _capture_ctx


func _build_capture_context() -> Dictionary:
	var close := false
	if _warn_left >= 0.0 and _warn_left < 1.0:
		close = true
	elif state == State.LEAVE:
		close = _seconds_until_exit() < 1.0
	return {
		"fleeing": is_fleeing(),
		"dodging": _dodge_time > 0.0,
		"close_call": close,
		"last_moment": close or (_warned and (state == State.LEAVE or _warn_left < 1.0)),
		"trajectory": trajectory_changed > 0.0,
		"mistake": from_mistake,
	}


## Geschätzte Zeit, bis ein fliehendes Ziel den sichtbaren Bereich verlässt
func _seconds_until_exit() -> float:
	var v := _velocity * UpgradeManager.stat(&"target_speed")
	if not field.has_point(position):
		return 0.0
	var t := INF
	if v.x < -1.0:
		t = minf(t, (position.x - field.position.x) / -v.x)
	elif v.x > 1.0:
		t = minf(t, (field.end.x - position.x) / v.x)
	if v.y < -1.0:
		t = minf(t, (position.y - field.position.y) / -v.y)
	elif v.y > 1.0:
		t = minf(t, (field.end.y - position.y) / v.y)
	return t


# ---------------------------------------------------------------- Bewegung

func _process(delta: float) -> void:
	age += delta
	state_time += delta
	_flash = maxf(0.0, _flash - delta)
	_hp_bar_time = maxf(0.0, _hp_bar_time - delta)
	var speed_factor := UpgradeManager.stat(&"target_speed")
	anim_time += delta * (0.4 + speed_factor * 0.6)
	trajectory_changed = maxf(0.0, trajectory_changed - delta)
	_dodge_time = maxf(0.0, _dodge_time - delta)
	if state == State.LIFT or state == State.FALL:
		sprite.frame = mini(3, sprite.hframes - 1)
		queue_redraw()
		return
	_process_flight(delta)
	if frozen > 0.0:
		frozen -= delta
		_update_animation(true)
		queue_redraw()
		return
	match state:
		State.ENTER:
			if field.grow(-10.0).has_point(position) or data.movement != TargetData.Movement.WANDER:
				_set_state(State.ROAM)
		State.ROAM:
			_roam(delta)
		State.REACT:
			if state_time >= react_duration:
				react_frame = false
				_set_state(State.ROAM)
				_on_react_finished()
		State.LEAVE:
			pass
	# Idle-Reaktionen (winken, glotzen, hupen)
	if state == State.ROAM:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_idle_timer = randf_range(4.0, 10.0)
			_on_idle()
	# Geschwindigkeit anwenden (auf dem Eisplaneten mit Trägheit)
	if slippery:
		_velocity = _velocity.lerp(desired_velocity, 1.0 - exp(-1.2 * delta))
		# deutliches Rutschen = veränderte Flugbahn
		if (_velocity - desired_velocity).length() > speed * 0.8:
			trajectory_changed = maxf(trajectory_changed, 0.3)
	else:
		_velocity = desired_velocity
	position += _velocity * speed_factor * delta
	if state == State.ROAM or state == State.REACT:
		_keep_in_field()
	# Verlassen?
	if field.has_point(position):
		_was_inside = true
	var out_margin := 90.0 * scale_mult + _frame_size.x * data.pixel_scale
	if not field.grow(out_margin).has_point(position) and (_was_inside or age > 45.0):
		if _warned:
			# seltenes Ziel ist entkommen – es taucht nicht wieder auf
			GameManager._inc(&"rare_fled")
			var inner := field.grow(-40.0)
			GameManager.float_text(position.clamp(inner.position, inner.end), "%s ist entkommen!" % data.display_name, Color(1, 0.6, 0.4), 18)
		queue_free()
		return
	_update_animation(false)
	queue_redraw()


func _roam(delta: float) -> void:
	if force_straight:
		return
	match data.movement:
		TargetData.Movement.WANDER:
			_turn_timer -= delta
			if _turn_timer <= 0.0:
				_turn_timer = randf_range(1.2, 3.5)
				if randf() < 0.2:
					desired_velocity = Vector2.ZERO
				else:
					var ang := randf() * TAU
					desired_velocity = Vector2(cos(ang), sin(ang) * 0.7).normalized() * speed
			if age > lifetime:
				_lifetime_over()
		TargetData.Movement.STATIONARY:
			desired_velocity = Vector2.ZERO
			if age > lifetime:
				_lifetime_over()
		_:
			pass


## Lebenszeit abgelaufen: normale Ziele gehen, seltene kündigen ihre Flucht vorher gut sichtbar an
func _lifetime_over() -> void:
	if _warn_left >= 0.0:
		return
	if (data.is_rare or data.is_golden) and not data.is_boss and not _warned:
		_warned = true
		_warn_total = WARN_TIME * UpgradeManager.stat(&"warn_time") * (1.6 if data.is_golden else 1.25)
		_warn_left = _warn_total
		GameManager.float_text(global_position + Vector2(0, -body_height() - 24), "Will fliehen!", Color(1, 0.55, 0.35), 18)
		AudioManager.play(&"deny", 1.4, -6.0, 0.3)
		if randf() < 0.5:
			GameManager.comment(&"flee")
		return
	if data.movement == TargetData.Movement.STATIONARY and not _warned:
		_fade_out()
	else:
		_start_leaving()


## Fluchtverhalten: Lichtkegel bemerken, Haken schlagen, Vorwarnung seltener Ziele
func _process_flight(delta: float) -> void:
	if frozen > 0.0:
		return
	# Vorwarnung läuft ab -> Flucht (höchstens einmal, niemals Rückkehr)
	if _warn_left >= 0.0:
		_warn_left -= delta
		if _warn_left < 0.0:
			_warn_left = -1.0
			fleeing = 99.0
			_start_leaving()
			desired_velocity = desired_velocity.normalized() * speed * 1.7 * UpgradeManager.stat(&"flee_speed")
		return
	if fleeing > 0.0:
		fleeing -= delta
		# schnelle Ziele schlagen unregelmäßig Haken
		if state != State.LEAVE and data.kind != TargetData.Kind.VEHICLE and (data.reaction == TargetData.Reaction.FLEE or data.speed_max >= 60.0):
			_erratic_timer -= delta
			if _erratic_timer <= 0.0 and desired_velocity.length() > 1.0:
				_erratic_timer = randf_range(0.3, 0.7)
				desired_velocity = desired_velocity.rotated(randf_range(0.5, 1.1) * (1.0 if randf() < 0.5 else -1.0))
				_dodge_time = 0.45
	# Menschen bemerken den Lichtkegel unter dem UFO und rennen los
	if data.kind == TargetData.Kind.HUMAN and data.reaction == TargetData.Reaction.PANIC and state == State.ROAM \
			and not GameManager.event_running:
		_notice_timer -= delta
		if _notice_timer <= 0.0:
			_notice_timer = 0.5
			var ufo_pos := get_global_mouse_position()
			if ufo_pos.distance_to(global_position) < NOTICE_RADIUS * UpgradeManager.stat(&"scare_radius") and randf() < NOTICE_CHANCE:
				_say(["Da oben!", "Ein Lichtkegel!", "LAUF!", "Nicht schon wieder!"], 0.5, Color(1, 0.9, 0.7))
				scare(ufo_pos)


func _keep_in_field() -> void:
	if data.movement != TargetData.Movement.WANDER or force_straight:
		return
	var r := field.grow(-12.0)
	if position.x < r.position.x and desired_velocity.x < 0.0:
		desired_velocity.x = absf(desired_velocity.x)
	elif position.x > r.end.x and desired_velocity.x > 0.0:
		desired_velocity.x = -absf(desired_velocity.x)
	if position.y < r.position.y + body_height() and desired_velocity.y < 0.0:
		desired_velocity.y = absf(desired_velocity.y)
	elif position.y > r.end.y and desired_velocity.y > 0.0:
		desired_velocity.y = -absf(desired_velocity.y)


func _start_leaving() -> void:
	_set_state(State.LEAVE)
	var to_left := position.x - field.position.x < field.end.x - position.x
	desired_velocity = Vector2(-1.0 if to_left else 1.0, randf_range(-0.2, 0.2)).normalized() * speed * 1.2


func _fade_out() -> void:
	_set_state(State.LEAVE)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _update_animation(idle: bool) -> void:
	var moving := _velocity.length() > 3.0 and not idle
	var frame := 0
	if react_frame:
		frame = 2
	elif data.movement == TargetData.Movement.STATIONARY:
		frame = int(anim_time * 4.0) % mini(4, sprite.hframes)
	elif moving or data.movement == TargetData.Movement.FLOCK:
		frame = int(anim_time * (14.0 if data.movement == TargetData.Movement.FLOCK else 8.0)) % 2
	sprite.frame = mini(frame, sprite.hframes - 1)
	if absf(_velocity.x) > 2.0:
		sprite.flip_h = _velocity.x < 0.0
	# kleines Hüpfen beim Laufen (bouncy!)
	var hop := absf(sin(anim_time * 9.0)) * 3.0 if moving and data.movement == TargetData.Movement.WANDER else 0.0
	if data.movement == TargetData.Movement.FLOCK:
		hop = sin(anim_time * 3.0) * 6.0
	sprite.position.y = -data.fly_height - hop
	sprite.self_modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0


# ---------------------------------------------------------------- Treffer & Einsaugen

## Wird vom Traktorstrahl aufgerufen.
func hit(power: float, source_node: Node2D, source: StringName, lift_time: float, allow_escape: bool = true, p_reward_mult: float = 1.0) -> HitResult:
	if not is_catchable():
		return HitResult.NONE
	if data.min_power > 0.0 and power < data.min_power:
		_on_deflected(source_node)
		GameManager.register_deflect(data, source)
		return HitResult.DEFLECTED
	var dmg := power * (UpgradeManager.stat(&"boss_damage") if data.is_boss else 1.0)
	hp -= dmg
	_flash = 0.1
	_squash()
	if hp <= 0.0:
		start_lift(source_node, source, lift_time, allow_escape, p_reward_mult)
		return HitResult.CAPTURED
	_hp_bar_time = 2.5
	_on_damaged(source_node)
	return HitResult.DAMAGED


func start_lift(anchor: Node2D, source: StringName, duration: float, allow_escape: bool = true, p_reward_mult: float = 1.0) -> void:
	if state == State.LIFT:
		return
	_capture_ctx = _build_capture_context()
	_warn_left = -1.0
	fleeing = 0.0
	_set_state(State.LIFT)
	marked = false
	shielded = false
	lift_source = source
	reward_mult = p_reward_mult
	_lift_anchor = anchor
	_anchor_pos = anchor.global_position if is_instance_valid(anchor) else global_position + Vector2(0, -400)
	_lift_from = global_position
	_ground_y = global_position.y
	z_index = 20
	_spin = randf_range(-6.0, 6.0)
	_escape_at = -1.0
	if allow_escape and not _lift_escaped:
		var chance := maxf(0.0, data.escape_chance + UpgradeManager.stat(&"escape_chance"))
		if randf() < chance:
			_escape_at = randf_range(0.4, 0.6)
	duration *= sqrt(maxf(0.3, data.weight))
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_method(_lift_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_lift_tween.tween_callback(_finish_lift)
	_on_lift_started()


func _lift_step(p: float) -> void:
	_lift_progress = p
	if is_instance_valid(_lift_anchor):
		_anchor_pos = _lift_anchor.global_position
	var to := _anchor_pos + Vector2(0, 6)
	var pos := _lift_from.lerp(to, p)
	pos.x += sin(anim_time * 26.0) * 7.0 * (1.0 - p)   # wackeln
	global_position = pos
	sprite.rotation = sin(anim_time * 13.0) * 0.45 * (1.0 - p) + _spin * p * p
	var s := lerpf(1.0, 0.2, p * p)
	scale = Vector2(s, s)
	if _escape_at > 0.0 and p >= _escape_at:
		_escape()


func _finish_lift() -> void:
	if state != State.LIFT:
		return
	abducted.emit(self, lift_source, reward_mult)
	queue_free()


func _escape() -> void:
	_escape_at = -1.0
	_lift_escaped = true
	trajectory_changed = 3.0
	var inner := field.grow(-20.0)
	var land_x := clampf(_lift_from.x + randf_range(-30, 30), inner.position.x, inner.end.x)
	var land_y := clampf(_ground_y, inner.position.y + body_height(), inner.end.y)
	_ground_y = land_y
	if _lift_tween:
		_lift_tween.kill()
	_set_state(State.FALL)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position:y", land_y, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:x", land_x, 0.7)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "rotation", 0.0, 0.4)
	tw.chain().tween_callback(func() -> void:
		z_index = 0
		hp = max_hp
		_set_state(State.ROAM)
		scare(global_position + Vector2(randf_range(-10, 10), -10)))
	escaped.emit(self)
	GameManager.register_escape(global_position + Vector2(0, -60))
	AudioManager.play(&"boing", randf_range(0.9, 1.1))


func _squash() -> void:
	var base := Vector2.ONE * data.pixel_scale * scale_mult
	var tw := create_tween()
	sprite.scale = Vector2(base.x * 1.25, base.y * 0.8)
	tw.tween_property(sprite, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func freeze(seconds: float) -> void:
	frozen = maxf(frozen, seconds)


# ---------------------------------------------------------------- Reaktionen (überschreibbar)

## Etwas Unheimliches passiert in der Nähe (Strahl, UFO, Explosion)
func scare(from_pos: Vector2) -> void:
	if not is_catchable() or (state == State.REACT and state_time < 0.4):
		return
	_on_scared(from_pos)


func _react(duration: float, show_frame: bool = true) -> void:
	_set_state(State.REACT)
	react_duration = duration
	react_frame = show_frame


func _run_away(from_pos: Vector2, factor: float = 2.4) -> void:
	var away := (global_position - from_pos)
	if away.length() < 1.0:
		away = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	# Tarnungs-Upgrades verlangsamen Fliehende; die letzten Ziele werden NICHT schneller
	desired_velocity = away.normalized() * speed * factor * UpgradeManager.stat(&"flee_speed")
	fleeing = maxf(fleeing, react_duration + 1.2)


## Tiere weichen eher zufällig aus statt gezielt wegzurennen
func _dodge_randomly(factor: float = 2.0) -> void:
	var dir := desired_velocity.normalized() if desired_velocity.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
	dir = dir.rotated(randf_range(PI * 0.35, PI * 0.8) * (1.0 if randf() < 0.5 else -1.0))
	desired_velocity = dir * speed * factor * UpgradeManager.stat(&"flee_speed")
	_dodge_time = 0.6
	fleeing = maxf(fleeing, 1.0)


func _say(lines: Array[String], chance: float = 1.0, color: Color = Color.WHITE) -> void:
	if lines.is_empty() or randf() > chance:
		return
	GameManager.float_text(global_position + Vector2(0, -body_height() - 16), lines.pick_random(), color, 16)


func _on_spawned() -> void:
	pass


func _on_scared(from_pos: Vector2) -> void:
	match data.reaction:
		TargetData.Reaction.PANIC, TargetData.Reaction.FLEE:
			_react(1.6)
			if data.kind == TargetData.Kind.ANIMAL:
				_dodge_randomly(2.2)
			else:
				_run_away(from_pos)
		TargetData.Reaction.STARE:
			_react(1.4)
			desired_velocity = Vector2.ZERO
		TargetData.Reaction.HONK:
			_react(0.6)
			desired_velocity *= 1.5
		_:
			pass


func _on_idle() -> void:
	pass


func _on_react_finished() -> void:
	if data.movement == TargetData.Movement.WANDER and desired_velocity.length() > speed * 1.2:
		desired_velocity = desired_velocity.normalized() * speed


func _on_damaged(source_node: Node2D) -> void:
	if is_instance_valid(source_node):
		scare(source_node.global_position + Vector2(0, 100))


func _on_deflected(_source_node: Node2D) -> void:
	_flash = 0.1
	_squash()
	AudioManager.play(&"clank", randf_range(0.9, 1.2), -4.0, 0.1)
	GameManager.float_text(global_position + Vector2(0, -body_height() - 10), "KLONK!", Color(0.8, 0.85, 1.0), 18)
	GameManager.effect(&"sparks", body_center(), Color(1, 0.9, 0.4))


func _on_lift_started() -> void:
	pass


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	# Schatten bleibt am Boden, auch wenn das Ziel angehoben wird
	var shadow_y := 0.0
	var shadow_scale := 1.0
	if state == State.LIFT or state == State.FALL:
		shadow_y = (_ground_y - global_position.y) / maxf(scale.y, 0.05)
		shadow_scale = maxf(0.2, 1.0 - _lift_progress * 0.8)
	var sw := data.shadow_width * scale_mult * shadow_scale
	_draw_ellipse(Vector2(0, shadow_y + 1), Vector2(sw, sw * 0.3), Color(0, 0, 0, 0.22))
	var top := -body_height() - data.fly_height
	if shielded:
		var r := body_height() * 0.75
		draw_circle(Vector2(0, top * 0.5), r, Color(0.4, 0.8, 1.0, 0.18))
		draw_arc(Vector2(0, top * 0.5), r, 0, TAU, 32, Color(0.6, 0.9, 1.0, 0.7), 2.0)
	if (_hp_bar_time > 0.0 or data.is_boss) and hp < max_hp and state != State.LIFT:
		var w := clampf(body_height() * 1.1, 34.0, 160.0)
		var y := top - 10.0
		draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 7), Color(0.05, 0.03, 0.1, 0.9))
		draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color(1.0, 0.35, 0.4).lerp(Color(0.45, 1.0, 0.5), hp / max_hp))
	if bonus_mult > 1.0 and state != State.LIFT:
		var by := top - 22.0 + sin(anim_time * 6.0) * 3.0
		draw_rect(Rect2(-14, by - 9, 28, 16), Color(1.0, 0.85, 0.25))
		draw_rect(Rect2(-14, by - 9, 28, 16), Color(0.4, 0.2, 0.0), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-11, by + 4), "x%d" % int(bonus_mult), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.1, 0.0))
	# gut sichtbare Vorwarnung, bevor ein seltenes Ziel flieht (faire Reaktionschance)
	if _warn_left >= 0.0 and state != State.LIFT:
		var k := clampf(_warn_left / maxf(0.01, _warn_total), 0.0, 1.0)
		var wc := Color(1.0, 0.35, 0.25).lerp(Color(1.0, 0.85, 0.3), k)
		var wy := top - 30.0 - absf(sin(anim_time * 8.0)) * 5.0
		draw_circle(Vector2(0, wy), 13.0, Color(0.1, 0.02, 0.05, 0.85))
		draw_arc(Vector2(0, wy), 13.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, wc, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4, wy + 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, wc)
	if marked and state != State.LIFT:
		var c := Color(1, 0.3, 0.35, 0.9)
		var ctr := Vector2(0, top * 0.5)
		var rr := body_height() * 0.6 + sin(anim_time * 10.0) * 3.0
		draw_arc(ctr, rr, 0, TAU, 24, c, 2.0)
		for i in 4:
			var d := Vector2.RIGHT.rotated(i * PI / 2.0)
			draw_line(ctr + d * (rr - 5), ctr + d * (rr + 6), c, 2.0)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
