class_name HelperUFO
extends Node2D
## Automatisierte Helfer: Mini-Drohne, Patrouillen-UFO, Beiboot und das Urlaubs-UFO (Event).
## Sie suchen sich selbst Ziele, fliegen hin und saugen sie ein.

enum Kind { DRONE, PATROL, BEIBOOT, VACATION }
enum AIState { SEEK, MOVE, BEAM, REST }

const CONFIG := {
	Kind.DRONE: {"tex": "res://assets/sprites/drone.png", "scale": 2.5, "hover": 55.0, "speed": 150.0, "interval": 1.8, "targets": 1, "source": &"drone", "weak_only": true},
	Kind.PATROL: {"tex": "res://assets/sprites/patrol.png", "scale": 2.5, "hover": 70.0, "speed": 200.0, "interval": 1.2, "targets": 3, "source": &"patrol", "weak_only": false},
	Kind.BEIBOOT: {"tex": "res://assets/sprites/beiboot.png", "scale": 2.5, "hover": 90.0, "speed": 90.0, "interval": 3.5, "targets": 6, "source": &"beiboot", "weak_only": false},
	Kind.VACATION: {"tex": "res://assets/sprites/vacation_ufo.png", "scale": 3.0, "hover": 90.0, "speed": 260.0, "interval": 0.45, "targets": 3, "source": &"helper", "weak_only": false},
}

@export var kind: Kind = Kind.DRONE
var field: Rect2 = Rect2(0, 0, 1280, 720)
## Belohnungsfaktor – ein sichtbares UFO kann mehrere gekaufte vertreten
var efficiency: float = 1.0

var _state: AIState = AIState.SEEK
var _target: BaseTarget
var _timer: float = 0.0
var _anim: float = 0.0
var _wander_goal: Vector2
var _cfg: Dictionary
## Vom Urlaubs-UFO eingesaugte Ziele (Erfolg "Urlaub auf der Erde")
var _captured_total: int = 0
## Pausen-Deko: rein kosmetisch, erzeugt keinen Fortschritt
var _pause_goal: Vector2
var _pause_anim: float = 0.0

const VACATION_GOAL := 12

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_cfg = CONFIG[kind]
	# läuft auch in der Pause weiter – dann aber nur mit kosmetischen Aktivitäten
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.texture = load(_cfg["tex"])
	sprite.hframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * float(_cfg["scale"])
	_anim = randf() * 10.0
	_wander_goal = _random_point()
	z_index = 25
	# Einflug-Pop
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func power() -> float:
	match kind:
		Kind.DRONE:
			return UpgradeManager.stat(&"drone_power")
		Kind.PATROL:
			return UpgradeManager.stat(&"drone_power") * 5.0
		Kind.BEIBOOT:
			return UpgradeManager.stat(&"drone_power") * 25.0
		_:
			return maxf(30.0, UpgradeManager.stat(&"click_power") * 4.0)


func _move_speed() -> float:
	var s: float = _cfg["speed"]
	if kind == Kind.DRONE or kind == Kind.PATROL:
		s *= UpgradeManager.stat(&"drone_speed")
	return s


func _process(delta: float) -> void:
	if get_tree().paused:
		_pause_idle(delta)
		return
	if _pause_anim > 0.0:
		_pause_anim = 0.0
		queue_redraw()
	_anim += delta
	sprite.frame = int(_anim * 5.0) % 2
	sprite.position.y = sin(_anim * 3.0) * 3.0
	_timer -= delta * (UpgradeManager.stat(&"drone_speed") if kind != Kind.VACATION else 1.0)
	match _state:
		AIState.SEEK:
			_target = _find_target()
			if _target:
				_state = AIState.MOVE
			else:
				_fly_to(_wander_goal, delta, 0.4)
				if global_position.distance_to(_wander_goal) < 10.0:
					_wander_goal = _random_point()
		AIState.MOVE:
			if not _valid(_target):
				_state = AIState.SEEK
				return
			var goal := _target.body_center() + Vector2(0, -float(_cfg["hover"]))
			_fly_to(goal, delta, 1.0)
			if global_position.distance_to(goal) < 14.0:
				_state = AIState.BEAM
				_timer = 0.15
		AIState.BEAM:
			if not _valid(_target):
				_state = AIState.SEEK
				return
			global_position = MathUtils.damp_v(global_position, _target.body_center() + Vector2(0, -float(_cfg["hover"])), 8.0, delta)
			if _timer <= 0.0:
				_fire()
		AIState.REST:
			_fly_to(_wander_goal, delta, 0.3)
			if _timer <= 0.0:
				_state = AIState.SEEK
				_wander_goal = _random_point()


func _fire() -> void:
	var src: StringName = _cfg["source"]
	var lift := 0.8
	var victims: Array[BaseTarget] = [_target]
	var max_t: int = _cfg["targets"]
	if max_t > 1:
		for n in get_tree().get_nodes_in_group(&"targets"):
			var t := n as BaseTarget
			if victims.size() >= max_t:
				break
			if t and t != _target and _valid(t) and t.body_center().distance_to(_target.body_center()) < 110.0:
				victims.append(t)
	var captured := 0
	for t in victims:
		var res := t.hit(power(), self, src, lift, true, efficiency)
		if res == BaseTarget.HitResult.CAPTURED:
			var b := TractorBeam.new()
			b.setup(self, t, t.body_center(), _beam_color(), false, 16.0 if kind == Kind.DRONE else 22.0)
			b.source_offset = Vector2(0, 8)
			get_parent().add_child(b)
			captured += 1
			_captured_total += 1
		elif res == BaseTarget.HitResult.DAMAGED:
			var fb := TractorBeam.new()
			fb.setup(self, null, t.body_center(), _beam_color(), true, 12.0)
			get_parent().add_child(fb)
	if captured > 0 and kind != Kind.DRONE:
		AudioManager.play(&"zap", randf_range(1.1, 1.3), -14.0, 0.08)
	if _valid(_target) and _target.hp > 0.0:
		_timer = 0.35   # weiter bearbeiten (Mehrfach-HP)
		return
	_state = AIState.REST
	_timer = float(_cfg["interval"])
	_wander_goal = _random_point()


func _beam_color() -> Color:
	match kind:
		Kind.PATROL:
			return Color(1.0, 0.55, 0.45)
		Kind.BEIBOOT:
			return Color(0.4, 1.0, 0.95)
		Kind.VACATION:
			return Color(1.0, 0.55, 0.85)
		_:
			return Color(0.5, 0.85, 1.0)


func _find_target() -> BaseTarget:
	var best: BaseTarget
	var best_score := INF
	var p := power()
	for n in get_tree().get_nodes_in_group(&"targets"):
		var t := n as BaseTarget
		if not _valid(t) or t.has_meta(&"claimed_by"):
			continue
		if t.data.min_power > p:
			continue
		if bool(_cfg["weak_only"]) and t.max_hp > p * 3.0:
			continue
		var d := t.global_position.distance_squared_to(global_position)
		if t.data.is_golden or t.data.is_rare:
			d *= 0.3
		if d < best_score:
			best_score = d
			best = t
	if best:
		best.set_meta(&"claimed_by", get_instance_id())
		var bid := best.get_instance_id()
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			var obj := instance_from_id(bid)
			if is_instance_valid(obj) and obj.has_meta(&"claimed_by"):
				obj.remove_meta(&"claimed_by"))
	return best


## Untypisierter Parameter: das Ziel kann bereits freigegeben sein (z. B. nach einem Regionswechsel),
## ein typisierter Parameter würde dann einen Fehler auslösen.
func _valid(t: Variant) -> bool:
	if not is_instance_valid(t):
		return false
	var bt := t as BaseTarget
	return bt != null and bt.is_catchable() and field.grow(40.0).has_point(bt.global_position)


func _fly_to(goal: Vector2, delta: float, speed_factor: float) -> void:
	var dir := goal - global_position
	var step := _move_speed() * speed_factor * delta
	if dir.length() <= step:
		global_position = goal
	else:
		global_position += dir.normalized() * step
	sprite.rotation = MathUtils.damp(sprite.rotation, clampf(dir.x / 400.0, -0.25, 0.25), 6.0, delta)


func _random_point() -> Vector2:
	var r := field.grow(-40.0)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y + 20.0, r.end.y - 60.0))


func fly_away() -> void:
	set_process(false)
	if kind == Kind.VACATION and _captured_total >= VACATION_GOAL:
		GameManager._inc(&"vacation_full")
		GameManager.float_text(global_position + Vector2(0, -40), "Urlaub voll ausgekostet! (%d Ziele)" % _captured_total, UIStyle.PINK, 20)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", -150.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Pause: Drohnen dösen, drehen langsame Runden und schnarchen – ohne echte Entführungen
func _pause_idle(delta: float) -> void:
	if _pause_anim == 0.0:
		_pause_goal = _random_point()
	_pause_anim += delta
	sprite.frame = int(_pause_anim * 1.5) % 2
	sprite.position.y = sin(_pause_anim * 1.2) * 5.0
	var dir := _pause_goal - global_position
	if dir.length() < 8.0:
		_pause_goal = _random_point()
	else:
		global_position += dir.normalized() * 25.0 * delta
	sprite.rotation = sin(_pause_anim * 0.8) * 0.12
	queue_redraw()


func _draw() -> void:
	if not is_inside_tree() or not get_tree().paused:
		return
	var font := ThemeDB.fallback_font
	for i in 3:
		var k := fmod(_pause_anim * 0.6 + i / 3.0, 1.0)
		var p := Vector2(14.0 + k * 18.0, -18.0 - k * 26.0)
		draw_string(font, p, "z" if i < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 + k * 8), Color(1, 1, 1, 1.0 - k))
