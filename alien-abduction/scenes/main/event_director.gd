class_name EventDirector
extends Node2D
## Zufallsereignisse: Kuh-Parade, Goldrausch, Militär, Alien-Urlauber, Entführungsfehler,
## Breaking News, Riesiger Schatten (Boss) und das geheime Sonnen-Event.

signal helper_requested(duration: float)

const EVENTS: Array[Dictionary] = [
	{"id": &"cow_parade", "weight": 10.0, "requires": &""},
	{"id": &"gold_rush", "weight": 7.0, "requires": &""},
	{"id": &"vacation", "weight": 6.0, "requires": &""},
	{"id": &"mistake", "weight": 8.0, "requires": &""},
	{"id": &"news", "weight": 8.0, "requires": &""},
	{"id": &"military", "weight": 7.0, "requires": &"unlock_military"},
	{"id": &"shadow", "weight": 5.0, "requires": &"unlock_boss"},
	{"id": &"sun", "weight": 1.5, "requires": &"sun_event"},
]

const HEADLINES: Array[String] = [
	"EILMELDUNG: Kühe verschwinden spurlos – Bauer: 'Die haben so komisch geleuchtet'",
	"Experten sicher: Das ist nur ein sehr großer Wetterballon",
	"Bürgermeister fordert: 'Bitte entführt zuerst das Finanzamt'",
	"Umfrage: 63 % der Kühe würden freiwillig mitfliegen",
	"Wissenschaftler verwirrt: Warum immer Kühe?",
	"Regierung dementiert alles. Auch Dinge, die niemand gefragt hat",
	"Mann behauptet, er sei 'nur kurz Zigaretten holen' gewesen – 3 Lichtjahre entfernt",
	"Verkehrsmeldung: Staus lösen sich überraschend in Luft auf",
	"Promi-Alarm: Influencer postet Selfie mit Traktorstrahl",
	"Hunde bellen verdächtig oft in den Himmel – Katzen unbeeindruckt",
]

var spawner: TargetSpawner
var field: Rect2 = Rect2(0, 0, 1280, 720)
var _timer: float = 50.0
var _military_time: float = 0.0
var _shadow_time: float = -1.0
var _shadow_pos: Vector2
var _t: float = 0.0


func _ready() -> void:
	z_index = -50


func _process(delta: float) -> void:
	_t += delta
	if _military_time > 0.0:
		_military_time -= delta
		_update_shields()
		if _military_time <= 0.0:
			_clear_shields()
	if _shadow_time >= 0.0:
		_shadow_time += delta
		queue_redraw()
		if _shadow_time >= 3.2:
			_shadow_time = -1.0
			queue_redraw()
			_spawn_boss()
	if not UpgradeManager.flag(&"unlock_events") or GameManager.event_running:
		return
	_timer -= delta * UpgradeManager.stat(&"event_rate")
	if _timer <= 0.0:
		_timer = randf_range(45.0, 85.0)
		start_random()


func start_random() -> void:
	var options: Array[Dictionary] = []
	var total := 0.0
	for e in EVENTS:
		if e["requires"] == &"" or UpgradeManager.flag(e["requires"]):
			options.append(e)
			total += float(e["weight"])
	var r := randf() * total
	for e in options:
		r -= float(e["weight"])
		if r <= 0.0:
			start_event(e["id"])
			return


func start_event(id: StringName) -> void:
	GameManager._inc(&"events")
	match id:
		&"cow_parade":
			_announce(id, "KUH-PARADE!", Color(1, 1, 1))
			spawner.spawn_parade(&"cow", 16 + randi() % 10)
			GameManager.start_buff(&"parade", 20.0)
		&"gold_rush":
			_announce(id, "GOLDRAUSCH!", UIStyle.GOLD)
			GameManager.start_buff(&"gold_rush", 15.0)
			AudioManager.play(&"gold", 0.8)
		&"vacation":
			_announce(id, "ALIEN-URLAUBER HILFT MIT!", UIStyle.PINK)
			helper_requested.emit(30.0)
		&"mistake":
			_announce(id, "ENTFÜHRUNGSFEHLER!", Color(1, 0.7, 0.4))
			_drop_mistake()
		&"news":
			GameManager.news_requested.emit(HEADLINES.pick_random(), 20.0)
			GameManager.start_buff(&"news", 20.0)
			AudioManager.play(&"news")
			GameManager.comment(&"news")
			GameManager.event_announced.emit(id, "BREAKING NEWS – Medienrummel: Credits x2!")
		&"military":
			_announce(id, "MILITÄRISCHE GEGENWEHR!", Color(0.6, 0.8, 0.4))
			GameManager.comment(&"military")
			var jeep := GameManager.get_target(&"jeep")
			if jeep:
				for i in 3:
					spawner.spawn(jeep)
			_military_time = 25.0
		&"shadow":
			_announce(id, "Etwas Großes kommt...", Color(0.8, 0.6, 1.0))
			var r := field.grow(-150.0)
			_shadow_pos = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y + 100.0, r.end.y))
			_shadow_time = 0.0
			AudioManager.play(&"rumble", 0.7)
		&"sun":
			_announce(id, "BITTE NICHT DIE SONNE!", Color(1, 0.6, 0.2))
			GameManager.comment(&"sun")
			GameManager.start_buff(&"sun", 12.0)
			GameManager._inc(&"sun_events")
			GameManager.shake(10.0)


func _announce(id: StringName, title: String, color: Color) -> void:
	GameManager.banner.emit(title, color, 1.4)
	GameManager.event_announced.emit(id, title)


func _drop_mistake() -> void:
	var pool := spawner.available_pool()
	if pool.is_empty():
		return
	var data: TargetData = spawner.pick_weighted(pool)
	if data.movement == TargetData.Movement.FLOCK:
		data = pool[0]
	var r := field.grow(-100.0)
	var land := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y + 80.0, r.end.y))
	var t := spawner.spawn(data, land)
	if t == null:
		return
	t.bonus_mult = 10.0
	t.frozen = 1.2
	var start := land + Vector2(0, -500)
	t.position = start
	var tw := t.create_tween()
	tw.tween_property(t, "position", land, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		GameManager.effect(&"dust", land, Color(0.9, 0.85, 0.7))
		GameManager.float_text(land + Vector2(0, -70), "Ups, zurück! BONUS x10", UIStyle.GOLD, 20))


func _spawn_boss() -> void:
	var boss := GameManager.get_target(&"giant_cow")
	if boss:
		var t := spawner.spawn(boss, _shadow_pos)
		if t:
			t.lifetime = 40.0
	GameManager.banner.emit("RIESENKUH!", Color(1, 0.8, 1), 1.2)


func _update_shields() -> void:
	var jeeps: Array[BaseTarget] = []
	var all := get_tree().get_nodes_in_group(&"targets")
	for n in all:
		var t := n as BaseTarget
		if t and t.data.id == &"jeep" and t.is_inside_tree() and t.state != BaseTarget.State.LIFT:
			jeeps.append(t)
	var radius := UpgradeManager.stat(&"shield_radius")
	for n in all:
		var t := n as BaseTarget
		if t == null or t.data.id == &"jeep" or t.state == BaseTarget.State.LIFT:
			continue
		var protected := false
		for j in jeeps:
			if j.global_position.distance_to(t.global_position) < radius:
				protected = true
				break
		t.shielded = protected
	if jeeps.is_empty():
		_military_time = minf(_military_time, 0.01)


func _clear_shields() -> void:
	for n in get_tree().get_nodes_in_group(&"targets"):
		var t := n as BaseTarget
		if t:
			t.shielded = false


func _draw() -> void:
	if _shadow_time < 0.0:
		return
	var k := clampf(_shadow_time / 3.0, 0.0, 1.0)
	var r := lerpf(20.0, 110.0, k)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(_shadow_pos + Vector2(cos(a) * r, sin(a) * r * 0.35))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.15 + 0.35 * k))
	if int(_t * 4.0) % 2 == 0:
		draw_string(ThemeDB.fallback_font, _shadow_pos + Vector2(-8, -r * 0.35 - 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.3, 0.3))
