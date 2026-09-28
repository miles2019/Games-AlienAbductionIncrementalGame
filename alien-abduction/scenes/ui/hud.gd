class_name HUD
extends CanvasLayer
## Setzt die Benutzeroberfläche zusammen und meldet der Welt die freie Spielfläche.

signal play_area_changed(rect: Rect2)
signal mothership_requested

@onready var root: Control = $Root
@onready var top_bar: TopBar = $Root/TopBar
@onready var shop: ShopPanel = $Root/ShopPanel
@onready var mothership_bar: MothershipBar = $Root/MothershipBar
@onready var skill_tree: SkillTreePanel = $Root/SkillTreePanel
@onready var overlay: OverlayPanel = $Root/OverlayPanel

var _gadgets: HudWidgets.GadgetBar
var _toasts: HudWidgets.ToastStack
var _chat: HudWidgets.CrewChat
var _news: HudWidgets.NewsTicker
var _buffs: HudWidgets.BuffBar
var _population: HudWidgets.PopulationPanel
var _pause: HudWidgets.PauseOverlay
var _banner: Label
var _coin_layer: Control
var _flash: ColorRect
var _sun_tint: ColorRect
var _flyers: Array = []   # {from, ctrl, t, dur, delay, type}
var _coin_sound_cd: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun_tint = ColorRect.new()
	_sun_tint.color = Color(1.0, 0.55, 0.1, 0.0)
	_sun_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_sun_tint)
	root.move_child(_sun_tint, 0)
	# Mutterschiff-Balken zentriert über der Spielfläche
	mothership_bar.mothership_requested.connect(func() -> void: mothership_requested.emit())
	# Widgets
	_buffs = HudWidgets.BuffBar.new()
	root.add_child(_buffs)
	_population = HudWidgets.PopulationPanel.new()
	root.add_child(_population)
	_news = HudWidgets.NewsTicker.new()
	root.add_child(_news)
	_toasts = HudWidgets.ToastStack.new()
	root.add_child(_toasts)
	_chat = HudWidgets.CrewChat.new()
	root.add_child(_chat)
	_gadgets = HudWidgets.GadgetBar.new()
	root.add_child(_gadgets)
	_banner = UIStyle.label("", 52, Color.WHITE, 12)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_coin_layer = Control.new()
	_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coin_layer.draw.connect(_draw_flyers)
	root.add_child(_coin_layer)
	# Overlays ganz nach oben
	root.move_child(skill_tree, -1)
	root.move_child(overlay, -1)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)
	_pause = HudWidgets.PauseOverlay.new()
	root.add_child(_pause)
	top_bar.menu_requested.connect(_on_menu)
	shop.collapsed_changed.connect(func(_c: bool) -> void: _relayout())
	get_viewport().size_changed.connect(_relayout)
	GameManager.banner.connect(show_banner)
	GameManager.buff_changed.connect(func(id: StringName, remaining: float, _d: float) -> void:
		if id == &"sun":
			_sun_tint.color.a = 0.18 if remaining > 0.0 else 0.0)
	_relayout.call_deferred()
	# Kein Offline-Fortschritt – stattdessen eine kurze Zusammenfassung des letzten Spielstands
	if not GameManager.welcome_summary.is_empty():
		overlay.show_page.call_deferred(&"welcome")


func play_area() -> Rect2:
	var vp := root.get_viewport_rect().size
	var right := shop.current_width() if shop else ShopPanel.WIDTH
	return Rect2(0, TopBar.HEIGHT, vp.x - right, vp.y - TopBar.HEIGHT)


func _relayout() -> void:
	var area := play_area()
	var cx := area.get_center().x
	mothership_bar.position = Vector2(cx - mothership_bar.size.x * 0.5, area.position.y + 8)
	mothership_bar.size.x = 420
	_buffs.position = Vector2(12, area.position.y + 10)
	_population.position = Vector2(area.end.x - _population.size.x - 12.0, area.position.y + 64.0)
	_news.position = Vector2(area.position.x + 20, area.end.y - 120)
	_news.size = Vector2(area.size.x - 40, 30)
	_toasts.position = Vector2(12, area.position.y + 50)
	_chat.position = Vector2(12, area.end.y - 96)
	_gadgets.position = Vector2(area.end.x - _gadgets.size.x - 14, area.end.y - 78)
	_banner.position = Vector2(area.position.x, area.get_center().y - 150)
	_banner.size = Vector2(area.size.x, 200)
	_banner.pivot_offset = _banner.size * 0.5
	play_area_changed.emit(area)


func _process(delta: float) -> void:
	_t += delta
	_coin_sound_cd -= delta
	# Gadget-Leiste mittig halten (Breite ändert sich bei Freischaltung)
	var area := play_area()
	_gadgets.position = Vector2(area.end.x - _gadgets.size.x - 14, area.end.y - 78)
	mothership_bar.position.x = area.get_center().x - mothership_bar.size.x * 0.5
	_population.position = Vector2(area.end.x - _population.size.x - 12.0, area.position.y + 64.0)
	_chat.position.y = area.end.y - _chat.size.y - 12
	# fliegende Münzen
	for f in _flyers:
		f["t"] += delta
	var arrived := _flyers.filter(func(f: Dictionary) -> bool: return f["t"] >= f["delay"] + f["dur"])
	for f in arrived:
		top_bar.pulse_resource(f["type"])
	if not arrived.is_empty() and _coin_sound_cd <= 0.0:
		AudioManager.play(&"coin", randf_range(0.95, 1.15), -10.0)
		_coin_sound_cd = 0.05
	_flyers = _flyers.filter(func(f: Dictionary) -> bool: return f["t"] < f["delay"] + f["dur"])
	_coin_layer.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_T:
			if GameManager.has_feature(&"skilltree") and not skill_tree.visible:
				skill_tree.open()
		KEY_B:
			shop.toggle_collapsed()


# ---------------------------------------------------------------- Menüs

func _on_menu(page: StringName) -> void:
	if page == &"skilltree":
		skill_tree.open()
	else:
		overlay.show_page(page)


func set_panels_visible(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(shop, "modulate:a", 1.0 if on else 0.0, 0.3)
	tw.tween_property(mothership_bar, "modulate:a", 1.0 if on else 0.0, 0.3)
	tw.tween_property(_gadgets, "modulate:a", 1.0 if on else 0.0, 0.3)
	shop.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


## Während Events: Balken & Gadgets ausblenden
func set_event_mode(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mothership_bar, "modulate:a", 0.0 if on else 1.0, 0.3)
	tw.tween_property(_gadgets, "modulate:a", 0.0 if on else 1.0, 0.3)


func flash_screen(color: Color, duration: float) -> Signal:
	_flash.color = Color(color, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 1.0, duration * 0.4)
	tw.tween_property(_flash, "color:a", 0.0, duration * 0.6)
	return get_tree().create_timer(duration * 0.4).timeout


func show_banner(text: String, color: Color, duration: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.scale = Vector2(0.3, 0.3)
	_banner.rotation = randf_range(-0.06, 0.06)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.35)


# ---------------------------------------------------------------- Fliegende Ressourcen

func fly_resource(screen_pos: Vector2, type: StringName, count: int) -> void:
	count = mini(count, 12)
	if _flyers.size() > 120:
		return
	for i in count:
		var ctrl := screen_pos + Vector2(randf_range(-140, 140), randf_range(-150, 40))
		_flyers.append({"from": screen_pos, "ctrl": ctrl, "t": 0.0, "dur": randf_range(0.45, 0.75), "delay": i * 0.035, "type": type})


func _draw_flyers() -> void:
	for f in _flyers:
		var t: float = (f["t"] - f["delay"]) / f["dur"]
		if t < 0.0:
			continue
		t = clampf(t, 0.0, 1.0)
		var e := t * t
		var to := top_bar.resource_target(f["type"])
		var p := MathUtils.bezier(f["from"], f["ctrl"], to, e)
		var tex := ResourceManager.icon(f["type"])
		var squash := absf(cos(f["t"] * 14.0))
		var sz := Vector2(22 * (0.35 + 0.65 * squash), 22) * (1.0 - e * 0.3)
		_coin_layer.draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false)


# ---------------------------------------------------------------- Population

func set_population(info: Dictionary) -> void:
	if _population:
		_population.set_info(info)
