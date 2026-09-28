extends Node2D
## Hauptszene: verbindet Welt, UFO, Spawner, Helfer, Events und HUD über Signale.

const HELPER_SCENE := preload("res://scenes/ufo/helper_ufo.tscn")
## Höchstens so viele Helfer entführen gleichzeitig – sonst leert sich das Feld zu schnell.
## Weitere gekaufte Einheiten erhöhen stattdessen die Effizienz (Belohnung) der aktiven.
const MAX_VISIBLE := {HelperUFO.Kind.DRONE: 4, HelperUFO.Kind.PATROL: 2, HelperUFO.Kind.BEIBOOT: 1}
const COUNT_STATS := {HelperUFO.Kind.DRONE: &"drone_count", HelperUFO.Kind.PATROL: &"patrol_count", HelperUFO.Kind.BEIBOOT: &"beiboot_count"}

@onready var ground: WorldGround = $WorldGround
@onready var targets_root: Node2D = $Targets
@onready var helpers: Node2D = $Helpers
@onready var laser: LaserSatellite = $LaserSatellite
@onready var effects: EffectsLayer = $Effects
@onready var ufo: PlayerUFO = $UFO
@onready var mothership: Mothership = $Mothership
@onready var camera: ScreenShakeCamera = $Camera2D
@onready var spawner: TargetSpawner = $Spawner
@onready var director: EventDirector = $EventDirector
@onready var hud: HUD = $HUD

var field: Rect2 = Rect2(0, 0, 1280, 720)
var _holding: bool = false
var _helper_timer: float = 0.0
var _event_total: float = 0.0
var _event_count: int = 0
var _auto_text_timer: float = 0.0


func _ready() -> void:
	spawner.targets_root = targets_root
	director.spawner = spawner
	spawner.target_spawned.connect(_on_target_spawned)
	spawner.population_changed.connect(hud.set_population)
	GameManager.region_changed.connect(_on_region_changed)
	hud.play_area_changed.connect(_on_play_area_changed)
	hud.mothership_requested.connect(start_mothership_event)
	GameManager.gadget_used.connect(_on_gadget_used)
	GameManager.prestige_requested.connect(_on_prestige_requested)
	GameManager.planet_changed.connect(_on_planet_changed)
	GameManager.game_reset.connect(_on_game_reset)
	GameManager.mothership_ready.connect(_on_mothership_ready)
	GameManager.level_up.connect(func(_l: int) -> void:
		AudioManager.play(&"levelup")
		effects.spawn_effect(&"confetti", ufo.global_position, Color.WHITE))
	GameManager.achievement_unlocked.connect(func(_a: AchievementData) -> void: AudioManager.play(&"achievement"))
	director.helper_requested.connect(_spawn_vacation)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply_planet(false)
	spawner.fill(0.5)
	_sync_helpers()
	if GameManager.get_stat(&"abductions") == 0.0:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: GameManager.comment(&"start"))


func _layout() -> void:
	var vp := get_viewport_rect().size
	camera.position = vp * 0.5
	_on_play_area_changed(hud.play_area())


func _on_play_area_changed(rect: Rect2) -> void:
	field = rect
	spawner.update_field(rect)
	director.field = rect
	ufo.field = rect
	laser.field = rect
	for h in helpers.get_children():
		if h is HelperUFO:
			(h as HelperUFO).field = rect
	ground.layout(get_viewport_rect().size, GameManager.current_planet)


func _apply_planet(clear: bool) -> void:
	spawner.planet = GameManager.current_planet
	spawner.region = GameManager.current_region
	ground.layout(get_viewport_rect().size, GameManager.current_planet)
	if clear:
		spawner.clear_all()
		spawner.fill(0.5)


func _on_region_changed(region: RegionData) -> void:
	spawner.change_region(region)
	GameManager.banner.emit(region.display_name.to_upper(), UIStyle.BLUE, 1.0)
	AudioManager.play(&"whoosh")


# ---------------------------------------------------------------- Eingabe

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_holding = true
			_try_fire()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_5:
			var idx := key - KEY_1
			if idx < GameManager.GADGETS.size():
				if not GameManager.use_gadget(GameManager.GADGETS[idx]["id"]):
					AudioManager.play(&"deny")
		elif key == KEY_M:
			start_mothership_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false


func _process(delta: float) -> void:
	# Gedrückthalten = Dauerfeuer
	if _holding and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire()
	_helper_timer -= delta
	if _helper_timer <= 0.0:
		_helper_timer = 0.5
		_sync_helpers()
	_auto_text_timer -= delta


func _try_fire() -> void:
	var mouse := get_global_mouse_position()
	if ufo.can_fire() and field.has_point(mouse) and not GameManager.event_running:
		ufo.fire(mouse)


# ---------------------------------------------------------------- Entführungen

func _on_target_spawned(t: BaseTarget) -> void:
	t.abducted.connect(_on_target_abducted)


func _on_target_abducted(t: BaseTarget, source: StringName, reward_mult: float) -> void:
	if source == &"prestige":
		return
	var data := t.data
	var pos := t.global_position
	var rewards := GameManager.register_abduction(data, pos, source, reward_mult * t.bonus_mult, t.capture_context())
	var credits: float = rewards["credits"]
	var is_player := source == &"player"
	var is_event := source == &"mothership"
	if is_event:
		_event_total += credits
		_event_count += 1
		if _event_count % 4 == 0:
			hud.fly_resource(_to_screen(pos), ResourceManager.CREDITS, 1)
		return
	# Floating Text
	var show_text := is_player or data.is_golden or data.is_boss or _auto_text_timer <= 0.0
	if show_text:
		if not is_player:
			_auto_text_timer = 0.12
		var size := 24 if is_player else 16
		var color := UIStyle.GOLD
		var txt := "+" + MathUtils.format_number(credits, true)
		if rewards["crit"]:
			txt = "KRITISCH! " + txt
			color = UIStyle.PINK
			size += 8
			GameManager.shake(4.0)
		if data.is_golden:
			size = 34
		GameManager.float_text(pos + Vector2(0, -30), txt, color, size)
		if rewards["biomass"] > 0.0 and is_player:
			GameManager.float_text(pos + Vector2(28, -8), "+%s Bio" % MathUtils.format_number(rewards["biomass"], true), UIStyle.CURRENCY_COLORS[&"biomass"], 15)
		if rewards["data"] > 0.0:
			GameManager.float_text(pos + Vector2(-28, -8), "+%d Daten" % int(rewards["data"]), UIStyle.BLUE, 17)
		if rewards["flee_bonus"] and is_player:
			GameManager.float_text(pos + Vector2(0, -62), "IM LAUF GEFANGEN! +%d %%" % int(round((GameManager.FLEE_BONUS - 1.0) * 100.0)), UIStyle.ACCENT, 16)
	# Leer gefegt: alle sichtbaren Ziele sind eingesaugt
	if is_player and spawner.population() == 0 and not GameManager.event_running:
		GameManager._inc(&"field_cleared")
		GameManager.banner.emit("LEER GEFEGT!", UIStyle.ACCENT, 0.9)
	# Partikel & Sound
	var anchor_pos := pos
	if data.is_golden:
		effects.spawn_effect(&"gold", anchor_pos, UIStyle.GOLD)
		GameManager.banner.emit("GOLD! +" + MathUtils.format_number(credits), UIStyle.GOLD, 0.9)
		GameManager.shake(10.0)
		camera.punch_zoom(0.06)
		_slowmo(0.3, 0.3)
	elif data.is_boss:
		effects.spawn_effect(&"confetti", anchor_pos, Color.WHITE)
		GameManager.banner.emit("RIESENKUH ENTFÜHRT!\n+" + MathUtils.format_number(credits), Color(1, 0.8, 1), 1.6)
		GameManager.shake(20.0)
		camera.punch_zoom(0.1, 0.8)
	elif data.is_rare:
		effects.spawn_effect(&"gold", anchor_pos, UIStyle.BLUE)
		_slowmo(0.5, 0.2)
	else:
		effects.spawn_effect(&"burst", anchor_pos, GameManager.beam_color())
	if is_player:
		AudioManager.play_abduct(data, int(rewards["combo"]))
		if data.weight >= 1.5:
			ufo.squash(0.2)
		hud.fly_resource(_to_screen(pos), ResourceManager.CREDITS, clampi(int(data.credits), 1, 4) + (6 if data.is_golden else 0))
		if rewards["biomass"] > 0.0:
			hud.fly_resource(_to_screen(pos), ResourceManager.BIOMASS, 1)
	else:
		AudioManager.play(data.sound, randf_range(1.1, 1.3), -16.0, 0.08)
		if randf() < 0.25:
			hud.fly_resource(_to_screen(pos), ResourceManager.CREDITS, 1)
	if rewards["data"] > 0.0:
		hud.fly_resource(_to_screen(pos), ResourceManager.DATA, 1)
	# Lockstoff: neue Ziele strömen herbei
	if rewards["lure"] and spawner.count() < spawner.max_targets() + 10:
		for i in randi_range(1, 2):
			spawner.spawn_random()


func _to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _slowmo(time_scale: float, real_seconds: float) -> void:
	if GameManager.event_running:
		return
	Engine.time_scale = time_scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- Helfer (Automatisierung)

func _sync_helpers() -> void:
	for kind in MAX_VISIBLE:
		var owned := int(UpgradeManager.stat(COUNT_STATS[kind]))
		var visible_n := mini(owned, MAX_VISIBLE[kind])
		var existing: Array[HelperUFO] = []
		for h in helpers.get_children():
			var hu := h as HelperUFO
			if hu and hu.kind == kind and hu.is_processing():
				existing.append(hu)
		while existing.size() < visible_n:
			var nh: HelperUFO = HELPER_SCENE.instantiate()
			nh.kind = kind
			nh.field = field
			nh.position = Vector2(randf_range(field.position.x, field.end.x), field.position.y - 40.0)
			helpers.add_child(nh)
			existing.append(nh)
		while existing.size() > visible_n:
			existing.pop_back().queue_free()
		var eff := float(owned) / float(maxi(1, visible_n))
		for h in existing:
			h.efficiency = eff


func _spawn_vacation(duration: float) -> void:
	var h: HelperUFO = HELPER_SCENE.instantiate()
	h.kind = HelperUFO.Kind.VACATION
	h.field = field
	h.position = Vector2(field.get_center().x, field.position.y - 60.0)
	helpers.add_child(h)
	var hid := h.get_instance_id()
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		var obj := instance_from_id(hid) as HelperUFO
		if is_instance_valid(obj):
			obj.fly_away())


# ---------------------------------------------------------------- Gadgets

func _on_gadget_used(id: StringName) -> void:
	AudioManager.play(&"buy", 0.8)
	camera.punch_zoom(0.03)
	match id:
		&"double":
			spawner.spawn_burst(18)
			GameManager.banner.emit("ZIELVERDOPPLUNG!", UIStyle.BLUE, 0.8)
		&"gold_rush":
			if spawner.planet.golden_target:
				for i in 2:
					spawner.spawn(spawner.planet.golden_target)
			GameManager.banner.emit("GOLDRAUSCH!", UIStyle.GOLD, 0.8)
		&"overload":
			GameManager.banner.emit("ÜBERLADUNG!", UIStyle.PINK, 0.8)
			ufo.squash(0.35)
		&"slowmo":
			GameManager.banner.emit("ZEITLUPE", Color(0.7, 0.9, 1.0), 0.8)
		&"instant_charge":
			GameManager.banner.emit("SOFORTAUFLADUNG!", UIStyle.PURPLE, 0.8)


# ---------------------------------------------------------------- Mutterschiff-Event

func _on_mothership_ready() -> void:
	AudioManager.play(&"ready")
	if UpgradeManager.flag(&"auto_mothership"):
		get_tree().create_timer(1.5).timeout.connect(start_mothership_event)


func start_mothership_event() -> void:
	if GameManager.event_running or not GameManager.mothership_is_ready():
		return
	GameManager.event_running = true
	_holding = false
	ufo.active = false
	spawner.paused = true
	_event_total = 0.0
	_event_count = 0
	hud.set_event_mode(true)
	var stage := GameManager.mothership_stage()
	AudioManager.play(&"event")
	GameManager.comment(&"mothership")
	GameManager.banner.emit("SAUGRUF!", UIStyle.PINK, 0.7)
	# Phase 1 – Saugruf: Himmel verdunkeln, Ziele strömen herbei, alle werden markiert
	create_tween().tween_property(ground, "darkness", 1.0, 0.8)
	camera.zoom_to(1.04, 0.8)
	var extra := int(stage["extra"] + UpgradeManager.stat(&"event_extra"))
	spawner.spawn_burst(extra)
	if stage["cars"] and GameManager.get_target(&"car"):
		for i in 6:
			spawner.spawn(GameManager.get_target(&"car"))
	for n in targets_root.get_children():
		var t := n as BaseTarget
		if t and t.is_catchable():
			t.marked = true
			t.freeze(5.0)
	await get_tree().create_timer(1.0).timeout
	# Phase 2 – Mutterschiff senkt sich
	AudioManager.play(&"rumble")
	GameManager.shake(10.0)
	await mothership.appear(field).finished
	GameManager.banner.emit(String(stage["name"]) + "!", UIStyle.ACCENT, 1.0)
	GameManager.shake(16.0)
	await mothership.set_beam(true).finished
	# Phase 3 – alles wird eingesaugt
	var victims: Array[BaseTarget] = []
	for n in targets_root.get_children():
		var t := n as BaseTarget
		if t and t.is_catchable():
			victims.append(t)
	victims.shuffle()
	for i in victims.size():
		var t := victims[i]
		if is_instance_valid(t) and t.is_catchable():
			t.start_lift(mothership.anchor, &"mothership", randf_range(0.9, 1.6), false, float(stage["mult"]))
		if i % 5 == 4:
			GameManager.shake(5.0)
			await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.9).timeout
	# Phase 4 – Auswertung & Abflug
	GameManager.complete_mothership()
	effects.spawn_effect(&"confetti", field.get_center(), Color.WHITE)
	GameManager.banner.emit("%s!\n%d Ziele  +%s Credits" % [stage["name"], _event_count, MathUtils.format_number(_event_total)], UIStyle.GOLD, 2.2)
	AudioManager.play(&"gold", 0.8)
	camera.zoom_to(1.0, 1.0)
	create_tween().tween_property(ground, "darkness", 0.0, 1.0)
	await mothership.leave().finished
	spawner.paused = false
	# nach dem Massenbeam ist die Karte leer – der Nachschub rollt an
	spawner.fill(0.2)
	spawner.call_resupply()
	ufo.active = true
	hud.set_event_mode(false)
	GameManager.event_running = false


# ---------------------------------------------------------------- Planetenraub (Prestige)

func _on_prestige_requested(destination: PlanetData) -> void:
	if GameManager.event_running:
		return
	GameManager.event_running = true
	_holding = false
	ufo.active = false
	spawner.paused = true
	hud.set_panels_visible(false)
	AudioManager.play(&"event", 0.7)
	GameManager.banner.emit("PLANETENRAUB!", UIStyle.BLUE, 1.5)
	create_tween().tween_property(ground, "darkness", 0.8, 1.0)
	spawner.spawn_burst(30)
	await mothership.appear(field).finished
	await mothership.set_beam(true).finished
	for n in targets_root.get_children():
		var t := n as BaseTarget
		if t and t.is_catchable():
			t.start_lift(mothership.anchor, &"prestige", randf_range(0.6, 1.4), false)
	# Der Planet selbst wird eingesaugt: Boden schrumpft Richtung Mutterschiff
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ground, "scale", Vector2(0.05, 0.05), 2.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(ground, "position", mothership.anchor.global_position, 2.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(ground, "rotation", 3.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for i in 10:
		GameManager.shake(8.0 + i * 1.5)
		await get_tree().create_timer(0.22).timeout
	await tw.finished
	await hud.flash_screen(Color.WHITE, 0.4)
	GameManager.perform_prestige(destination)
	ground.scale = Vector2.ONE
	ground.position = Vector2.ZERO
	ground.rotation = 0.0
	ground.darkness = 0.0
	effects.spawn_effect(&"confetti", field.get_center(), Color.WHITE)
	await mothership.leave().finished
	hud.set_panels_visible(true)
	spawner.paused = false
	ufo.active = true
	GameManager.event_running = false


func _on_planet_changed(_p: PlanetData) -> void:
	for h in helpers.get_children():
		h.queue_free()
	_apply_planet(true)
	_sync_helpers()


func _on_game_reset() -> void:
	for h in helpers.get_children():
		h.queue_free()
	GameManager.event_running = false
	ufo.active = true
	spawner.paused = false
	_apply_planet(true)
