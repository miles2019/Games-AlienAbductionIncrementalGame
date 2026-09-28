class_name LaserSatellite
extends Node2D
## Laser-Satelliten im Orbit: fegen regelmäßig einen roten Laser über das Feld.
## Alles, was er trifft, wird nach oben weggezappt.

var field: Rect2 = Rect2(0, 0, 1280, 720)
var _timer: float = 5.0
var _sweeping: bool = false
var _x: float = 0.0
var _dir: float = 1.0
var _hit: Dictionary = {}
var _anchor: Node2D
var _t: float = 0.0


func _ready() -> void:
	z_index = 28
	_anchor = Node2D.new()
	add_child(_anchor)


func count() -> int:
	return int(UpgradeManager.stat(&"laser_count"))


func period() -> float:
	return maxf(1.2, 16.0 / sqrt(maxf(1.0, count())))


func _process(delta: float) -> void:
	_t += delta
	if count() <= 0:
		visible = false
		return
	visible = true
	if not _sweeping:
		_timer -= delta
		if _timer <= 0.0:
			_start_sweep()
	else:
		_x += _dir * field.size.x / 1.6 * delta
		_anchor.global_position = Vector2(_x, field.position.y - 80.0)
		var power := UpgradeManager.stat(&"laser_power") * (1.0 + 0.1 * count())
		for n in get_tree().get_nodes_in_group(&"targets"):
			var t := n as BaseTarget
			if t == null or _hit.has(t.get_instance_id()) or not t.is_catchable():
				continue
			if absf(t.body_center().x - _x) < 16.0:
				_hit[t.get_instance_id()] = true
				var res := t.hit(power, _anchor, &"laser", 0.55, false)
				if res != BaseTarget.HitResult.NONE:
					GameManager.effect(&"sparks", t.body_center(), Color(1, 0.4, 0.4))
		if (_dir > 0.0 and _x > field.end.x + 20.0) or (_dir < 0.0 and _x < field.position.x - 20.0):
			_sweeping = false
			_timer = period()
	queue_redraw()


func _start_sweep() -> void:
	_sweeping = true
	_hit.clear()
	_dir = 1.0 if randf() < 0.5 else -1.0
	_x = field.position.x - 10.0 if _dir > 0.0 else field.end.x + 10.0
	AudioManager.play(&"laser", randf_range(0.9, 1.1), -6.0)


func _draw() -> void:
	# Satelliten am oberen Rand
	var n := mini(count(), 8)
	for i in n:
		var x := field.position.x + field.size.x * (i + 1) / (n + 1)
		var y := field.position.y + 10.0 + sin(_t * 2.0 + i) * 3.0
		draw_rect(Rect2(x - 10, y - 4, 20, 8), Color(0.75, 0.78, 0.85))
		draw_rect(Rect2(x - 22, y - 2, 10, 4), Color(0.3, 0.5, 0.9))
		draw_rect(Rect2(x + 12, y - 2, 10, 4), Color(0.3, 0.5, 0.9))
		draw_circle(Vector2(x, y + 5), 2.5, Color(1, 0.3, 0.3) if int(_t * 3.0 + i) % 2 == 0 else Color(0.5, 0.1, 0.1))
	if not _sweeping:
		return
	var top := field.position.y
	var bottom := field.end.y
	var flicker := 0.85 + randf() * 0.15
	draw_rect(Rect2(_x - 16, top, 32, bottom - top), Color(1, 0.15, 0.2, 0.18 * flicker))
	draw_rect(Rect2(_x - 7, top, 14, bottom - top), Color(1, 0.2, 0.25, 0.75 * flicker))
	draw_rect(Rect2(_x - 2, top, 4, bottom - top), Color(1, 0.9, 0.9, flicker))
	for i in 5:
		var y := randf_range(top, bottom)
		draw_line(Vector2(_x, y), Vector2(_x + randf_range(-14, 14), y + randf_range(-10, 10)), Color(1, 0.8, 0.5), 2.0)
