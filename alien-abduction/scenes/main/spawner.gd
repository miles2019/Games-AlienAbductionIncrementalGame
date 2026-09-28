class_name TargetSpawner
extends Node
## Lässt Ziele des aktuellen Planeten auf dem Feld erscheinen (gewichtete Zufallsauswahl).

signal target_spawned(target: BaseTarget)

const BASE_SCENE := preload("res://scenes/targets/base_target.tscn")

var targets_root: Node2D
var field: Rect2 = Rect2(0, 0, 1280, 720)
var planet: PlanetData
var paused: bool = false
var _timer: float = 0.5


func _process(delta: float) -> void:
	if paused or planet == null or targets_root == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.6, 1.4) / maxf(0.05, UpgradeManager.stat(&"spawn_rate"))
		if count() < max_targets():
			spawn_random()


func count() -> int:
	return targets_root.get_child_count()


func max_targets() -> int:
	return int(UpgradeManager.stat(&"max_targets"))


func available_pool() -> Array[TargetData]:
	var out: Array[TargetData] = []
	for d in planet.targets:
		if d.required_upgrade == &"" or UpgradeManager.has(d.required_upgrade):
			out.append(d)
	return out


func spawn_random() -> void:
	if planet.golden_target and randf() < UpgradeManager.stat(&"golden_chance") * UpgradeManager.stat(&"rare_mult"):
		spawn(planet.golden_target)
		return
	var pool := available_pool()
	if pool.is_empty():
		return
	var total := 0.0
	for d in pool:
		total += _weight(d)
	var r := randf() * total
	for d in pool:
		r -= _weight(d)
		if r <= 0.0:
			spawn(d)
			return
	spawn(pool.back())


func pick_weighted(pool: Array[TargetData]) -> TargetData:
	var total := 0.0
	for d in pool:
		total += _weight(d)
	var r := randf() * total
	for d in pool:
		r -= _weight(d)
		if r <= 0.0:
			return d
	return pool.back()


func _weight(d: TargetData) -> float:
	var w := d.spawn_weight
	if d.is_rare:
		w *= UpgradeManager.stat(&"rare_mult")
	if d.id == &"cow" and UpgradeManager.has(&"sk_cowmagnet"):
		w *= 2.0
	return w


## Spawnt ein Ziel. at = Vector2.INF → vom Feldrand hereinlaufen.
func spawn(data: TargetData, at: Vector2 = Vector2.INF) -> BaseTarget:
	if data.movement == TargetData.Movement.FLOCK and data.group_size > 1 and at == Vector2.INF:
		return _spawn_flock(data)
	var pos := at
	var dir := Vector2.ZERO
	var inside := at != Vector2.INF
	if not inside:
		var edge := _edge_spawn(data)
		pos = edge[0]
		dir = edge[1]
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
		if data.movement == TargetData.Movement.DRIVE:
			dir = Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
	return _create(data, pos, dir, inside)


func _create(data: TargetData, pos: Vector2, dir: Vector2, inside: bool) -> BaseTarget:
	var scene: PackedScene = data.scene if data.scene else BASE_SCENE
	var t := scene.instantiate() as BaseTarget
	if t == null:
		push_warning("Szene für %s ist kein BaseTarget" % data.id)
		return null
	t.configure(data, field, dir, planet.target_hp_multiplier, planet.target_scale, planet.slippery)
	t.position = pos
	if inside:
		t.state = BaseTarget.State.ROAM
		t.scale = Vector2.ZERO
		t.create_tween().tween_property(t, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	targets_root.add_child(t)
	target_spawned.emit(t)
	if data.is_golden:
		GameManager.float_text(field.get_center() if not inside else pos + Vector2(0, -60), "✦ %s ✦" % data.display_name.to_upper(), UIStyle.GOLD, 26)
		if randf() < 0.5:
			GameManager.comment(&"golden", &"glorp" if UpgradeManager.has(&"crew_glorp") else &"")
	return t


func _edge_spawn(data: TargetData) -> Array:
	var r := field
	var left := randf() < 0.5
	var y := randf_range(r.position.y + 60.0, r.end.y - 10.0)
	if data.movement == TargetData.Movement.WANDER and randf() < 0.3:
		# von unten hereinlaufen
		var x := randf_range(r.position.x + 30.0, r.end.x - 30.0)
		return [Vector2(x, r.end.y + 40.0), Vector2(randf_range(-0.3, 0.3), -1.0)]
	var pos := Vector2(r.position.x - 40.0 if left else r.end.x + 40.0, y)
	var dir := Vector2(1.0 if left else -1.0, 0.0)
	if data.movement == TargetData.Movement.WANDER:
		dir = dir.rotated(randf_range(-0.5, 0.5))
	return [pos, dir]


func _spawn_flock(data: TargetData) -> BaseTarget:
	var edge := _edge_spawn(data)
	var first: BaseTarget = null
	for i in data.group_size:
		var off := Vector2(-edge[1].x * (i % 3) * 26.0 - floori(i / 3.0) * 20.0 * edge[1].x, (i % 3 - 1) * 24.0 + randf_range(-6, 6))
		var t := _create(data, edge[0] + off, edge[1], false)
		if first == null:
			first = t
	return first


func spawn_burst(amount: int, ids: Array[StringName] = []) -> void:
	for i in amount:
		var data: TargetData
		if ids.is_empty():
			var pool := available_pool()
			if pool.is_empty():
				return
			data = pick_weighted(pool)
			if data.movement == TargetData.Movement.FLOCK:
				data = pool[0]
		else:
			data = GameManager.get_target(ids.pick_random())
		if data:
			var r := field.grow(-40.0)
			spawn(data, Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y + 50.0, r.end.y)))


## Eine Parade: Ziele laufen in einer Reihe quer über den Bildschirm
func spawn_parade(id: StringName, amount: int) -> void:
	var data := GameManager.get_target(id)
	if data == null:
		return
	var y := randf_range(field.position.y + 120.0, field.end.y - 60.0)
	var left := randf() < 0.5
	for i in amount:
		var x := (field.position.x - 60.0 - i * 55.0) if left else (field.end.x + 60.0 + i * 55.0)
		var t := _create(data, Vector2(x, y + sin(i * 0.9) * 14.0), Vector2(1.0 if left else -1.0, 0.0), false)
		if t:
			t.force_straight = true
			t.speed = 55.0
			t.desired_velocity = Vector2(1.0 if left else -1.0, 0.0) * 55.0


func update_field(rect: Rect2) -> void:
	field = rect
	for n in targets_root.get_children():
		var t := n as BaseTarget
		if t:
			t.field = rect


func clear_all() -> void:
	for n in targets_root.get_children():
		n.queue_free()
