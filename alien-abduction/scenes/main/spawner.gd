class_name TargetSpawner
extends Node
## Lässt Ziele des aktuellen Planeten auf dem Feld erscheinen (gewichtete Zufallsauswahl).
## Jede Region hat eine Zielkapazität und eine aktuelle Population: Entführte Ziele werden nach
## und nach ersetzt, nach Massenentführungen wird die Karte kurz leerer, und wenn zu wenige Ziele
## übrig sind, rollt automatisch ein Nachschub-Transport (Bus, Zug, Laster ...) an.

signal target_spawned(target: BaseTarget)
## {population, capacity, resupply, incoming, rare: Array[String], region: RegionData, lull: bool}
signal population_changed(info: Dictionary)
signal resupply_arrived(transport_name: String)

const BASE_SCENE := preload("res://scenes/targets/base_target.tscn")
const VEHICLE_SCRIPT := preload("res://scenes/main/resupply_vehicle.gd")
## Unter diesem Anteil der Kapazität startet automatisch ein Nachschub-Event
const LOW_POPULATION := 0.25
const RESUPPLY_COOLDOWN := 14.0
## So viele Entführungen innerhalb von MASS_WINDOW Sekunden gelten als Massenentführung
const MASS_COUNT := 6
const MASS_WINDOW := 3.0
const LULL_TIME := 2.5

var targets_root: Node2D
var field: Rect2 = Rect2(0, 0, 1280, 720)
var planet: PlanetData
var region: RegionData
var paused: bool = false
var _timer: float = 0.5
var _lull: float = 0.0
var _resupply_cd: float = 6.0
var _recent_losses: Array[float] = []
var _vehicle: Node2D
var _info_timer: float = 0.0
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.25
		population_changed.emit(population_info())
	if paused or planet == null or targets_root == null:
		return
	_resupply_cd -= delta
	# Nachschub-Event statt leerer Spielphase
	var cap := capacity()
	if population() < ceili(cap * LOW_POPULATION) and _resupply_cd <= 0.0 and not is_instance_valid(_vehicle) \
			and not GameManager.event_running:
		call_resupply()
	# Ruhephase nach einer Massenentführung: die Karte wird kurz leerer
	if _lull > 0.0:
		_lull -= delta
		if _lull <= 0.0 and not is_instance_valid(_vehicle):
			call_resupply(true)
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.6, 1.4) / maxf(0.05, resupply_rate())
		if population() < cap:
			spawn_random()


# ---------------------------------------------------------------- Population

## Anzahl der Ziele, die gerade auf dem Feld unterwegs sind (ohne eingesaugte)
func population() -> int:
	var n := 0
	for c in targets_root.get_children():
		var t := c as BaseTarget
		if t and not t.is_lifting() and not t.is_queued_for_deletion():
			n += 1
	return n


func count() -> int:
	return targets_root.get_child_count()


## Zielkapazität der Region (Upgrades wie Lockstoff erhöhen sie)
func capacity() -> int:
	var f := region.capacity if region else 1.0
	return maxi(3, int(UpgradeManager.stat(&"max_targets") * f))


func max_targets() -> int:
	return capacity()


## Neue Ziele pro Sekunde (solange die Kapazität nicht erreicht ist)
func resupply_rate() -> float:
	var f := region.resupply if region else 1.0
	return UpgradeManager.stat(&"spawn_rate") * f


func population_info() -> Dictionary:
	var rare: Array[String] = []
	if targets_root:
		for c in targets_root.get_children():
			var t := c as BaseTarget
			if t and (t.data.is_rare or t.data.is_golden or t.data.is_boss) and not t.is_lifting():
				var s := t.data.display_name
				if t.is_warning():
					s += " (flieht gleich!)"
				elif t.is_fleeing():
					s += " (auf der Flucht)"
				rare.append(s)
	var pop := population() if targets_root else 0
	var cap := capacity()
	var incoming := 0.0
	if not paused and _lull <= 0.0 and pop < cap:
		incoming = resupply_rate()
	return {
		"population": pop, "capacity": cap, "resupply": incoming,
		"incoming": is_instance_valid(_vehicle), "rare": rare, "region": region, "lull": _lull > 0.0,
		"transport": region.transport_name if region else "Nachschub",
	}


## Ein Ziel wurde entführt – bei vielen Entführungen in kurzer Zeit gibt es eine kurze Ruhephase
func _on_target_lost(_t: BaseTarget, source: StringName, _mult: float) -> void:
	if source == &"mothership" or source == &"prestige":
		return
	_recent_losses.append(_time)
	while not _recent_losses.is_empty() and _time - _recent_losses[0] > MASS_WINDOW:
		_recent_losses.pop_front()
	if _recent_losses.size() >= MASS_COUNT and _lull <= 0.0 and not is_instance_valid(_vehicle):
		_recent_losses.clear()
		_lull = LULL_TIME


## Nachschub-Transport fährt quer übers Feld und lädt neue Ziele ab
func call_resupply(quiet: bool = false) -> void:
	if planet == null or is_instance_valid(_vehicle) or targets_root == null:
		return
	_resupply_cd = RESUPPLY_COOLDOWN
	var amount := clampi(capacity() - population(), 3, 14)
	var v := Node2D.new()
	v.set_script(VEHICLE_SCRIPT)
	v.set("transport", region.transport if region else &"bus")
	v.set("label", region.transport_name if region else "Nachschub")
	v.set("drops", amount)
	v.set("field", field)
	v.connect("drop", _on_vehicle_drop)
	targets_root.get_parent().add_child(v)
	_vehicle = v
	var name_txt: String = region.transport_name if region else "Nachschub"
	resupply_arrived.emit(name_txt)
	if not quiet:
		GameManager.banner.emit("NACHSCHUB: %s!" % name_txt.to_upper(), UIStyle.BLUE, 1.0)
		if randf() < 0.5:
			GameManager.comment(&"resupply")
	AudioManager.play(&"honk", 0.8, -6.0, 0.2)


func _on_vehicle_drop(pos: Vector2) -> void:
	if paused:
		return
	var pool := available_pool()
	if pool.is_empty():
		return
	var data := pick_weighted(pool)
	if data.movement == TargetData.Movement.FLOCK or data.movement == TargetData.Movement.STATIONARY:
		data = pool[0]
	var inner := field.grow(-30.0)
	var t := spawn(data, (pos + Vector2(randf_range(-20, 20), randf_range(6, 26))).clamp(inner.position, inner.end))
	if t:
		t.desired_velocity = Vector2(randf_range(-1, 1), randf_range(-0.2, 1.0)).normalized() * t.speed


# ---------------------------------------------------------------- Auswahl

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
	spawn(pick_weighted(pool))


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
	if region:
		w *= region.weight_for(d.id)
	return w


# ---------------------------------------------------------------- Spawnen

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
	t.abducted.connect(_on_target_lost)
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


## Füllt das Feld auf einen Anteil der Kapazität (Spielstart, Regionswechsel)
func fill(fraction: float = 0.5) -> void:
	spawn_burst(maxi(0, int(capacity() * fraction) - population()))


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
	if is_instance_valid(_vehicle):
		_vehicle.set("field", rect)


func clear_all() -> void:
	for n in targets_root.get_children():
		n.queue_free()
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()
	_lull = 0.0
	_recent_losses.clear()


## Regionswechsel: alte Ziele verschwinden, die neue Region füllt sich
func change_region(r: RegionData) -> void:
	region = r
	for n in targets_root.get_children():
		var t := n as BaseTarget
		if t and t.is_catchable():
			var tw := t.create_tween()
			tw.tween_property(t, "modulate:a", 0.0, 0.3)
			tw.tween_callback(t.queue_free)
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()
	_lull = 0.0
	_resupply_cd = 4.0
	await get_tree().create_timer(0.35).timeout
	fill(0.5)
