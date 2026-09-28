class_name OverlayPanel
extends Control
## Modales Fenster für Erfolge, Statistik, Planeten/Prestige, Optionen und Offline-Einnahmen.

const SHOP_ITEM := preload("res://scenes/ui/shop_item.tscn")

var _dim: ColorRect
var _window: PanelContainer
var _title: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _page: StringName = &""
var _refresh_timer: float = 0.0
var _reset_armed: float = 0.0
var _dynamic: Array[Callable] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.06, 0.7)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and _page != &"offline":
			close())
	add_child(_dim)
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", UIStyle.box(Color(0.09, 0.07, 0.16, 0.98), UIStyle.PURPLE, 14, 3, 18))
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.custom_minimum_size = Vector2(820, 560)
	_window.offset_left = -410
	_window.offset_right = 410
	_window.offset_top = -280
	_window.offset_bottom = 280
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_window)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_window.add_child(vb)
	var header := HBoxContainer.new()
	vb.add_child(header)
	_title = UIStyle.label("", 26, UIStyle.ACCENT, 6)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_b := UIStyle.button("✕", 18, Color(0.5, 0.15, 0.25))
	close_b.custom_minimum_size = Vector2(40, 36)
	close_b.pressed.connect(close)
	header.add_child(close_b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)


func show_page(page: StringName) -> void:
	_page = page
	_dynamic.clear()
	for c in _content.get_children():
		c.queue_free()
	match page:
		&"achievements":
			_build_achievements()
		&"stats":
			_build_stats()
		&"planets":
			_build_planets()
		&"options":
			_build_options()
		&"offline":
			_build_offline()
	visible = true
	_scroll.scroll_vertical = 0
	_window.pivot_offset = _window.size * 0.5
	_window.scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_window, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	AudioManager.play(&"whoosh", 1.1)


func close() -> void:
	if _page == &"offline":
		GameManager.collect_offline()
	_page = &""
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void: visible = false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	_reset_armed = maxf(0.0, _reset_armed - delta)
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.3
		for f in _dynamic:
			f.call()


# ---------------------------------------------------------------- Erfolge

func _build_achievements() -> void:
	var got := GameManager.unlocked_achievements.size()
	_title.text = "ERFOLGE  %d/%d" % [got, GameManager.achievements.size()]
	_content.add_child(UIStyle.label("Jeder Erfolg gibt dauerhaft Bonus-Credits. Aktueller Bonus: +%d %%" % int(round(GameManager.achievement_bonus() * 100.0)), 14, UIStyle.TEXT_DIM, 3))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for a in GameManager.achievements:
		var done := GameManager.unlocked_achievements.has(a.id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(380, 76)
		card.add_theme_stylebox_override("panel", UIStyle.box(Color(0.18, 0.15, 0.1, 0.95) if done else Color(0.12, 0.1, 0.18, 0.9), UIStyle.GOLD if done else Color(1, 1, 1, 0.06), 10, 2, 10))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)
		var ic := UIStyle.icon_rect(a.icon if (done or not a.secret) else load("res://assets/icons/lock.png"), 40)
		ic.modulate = Color.WHITE if done else Color(0.5, 0.5, 0.6)
		hb.add_child(ic)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		hb.add_child(vb)
		var secret_hidden := a.secret and not done
		vb.add_child(UIStyle.label("???" if secret_hidden else a.display_name, 15, UIStyle.GOLD if done else UIStyle.TEXT, 3))
		var d := UIStyle.label("Geheimer Erfolg" if secret_hidden else a.description, 12, UIStyle.TEXT_DIM, 2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(d)
		if not done and not secret_hidden:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 8)
			bar.show_percentage = false
			bar.max_value = a.threshold
			bar.value = minf(GameManager.get_stat_value(a.stat), a.threshold)
			vb.add_child(bar)
		grid.add_child(card)


# ---------------------------------------------------------------- Statistik

func _build_stats() -> void:
	_title.text = "STATISTIK"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	var rows: Array = [
		["Entführungen gesamt", &"abductions"], ["davon per Klick", &"player_abductions"], ["Klicks", &"clicks"],
		["Goldene Ziele", &"golden"], ["Kritische Entführungen", &"crits"], ["Beste Combo", &"best_combo"],
		["Entkommene Ziele", &"escapes"], ["Riesenkühe", &"boss_kills"], ["Mutterschiff-Rufe", &"mothership_calls"],
		["Planetenraube", &"prestiges"], ["Zufallsereignisse", &"events"], ["Gadgets benutzt", &"gadgets_used"],
		["Credits (gesamt)", &"credits_total"], ["Credits (dieser Planet)", &"credits_run"], ["Biomasse (gesamt)", &"biomass_total"],
		["Alien-Daten (gesamt)", &"data_total"], ["Kosmischer Ruf (gesamt)", &"ruf_total"], ["Level", &"level"],
		["Skill-Ränge", &"skill_ranks"], ["Forschungen", &"research"], ["Erfolge", &"achievements"],
	]
	for r in rows:
		grid.add_child(UIStyle.label(r[0], 15, UIStyle.TEXT_DIM, 2))
		var v := UIStyle.label("", 15, UIStyle.GOLD, 3)
		grid.add_child(v)
		var key: StringName = r[1]
		var upd := func() -> void: v.text = MathUtils.format_number(GameManager.get_stat_value(key))
		upd.call()
		_dynamic.append(upd)
	grid.add_child(UIStyle.label("Spielzeit", 15, UIStyle.TEXT_DIM, 2))
	grid.add_child(UIStyle.label(MathUtils.format_time(GameManager.get_stat(&"play_time")), 15, UIStyle.GOLD, 3))
	grid.add_child(UIStyle.label("Credit-Multiplikator", 15, UIStyle.TEXT_DIM, 2))
	grid.add_child(UIStyle.label("x" + MathUtils.format_number(GameManager.credit_multiplier(), true), 15, UIStyle.GOLD, 3))
	var per_second := UIStyle.label("", 15, UIStyle.GOLD, 3)
	grid.add_child(UIStyle.label("Credits/s (Automatisierung)", 15, UIStyle.TEXT_DIM, 2))
	grid.add_child(per_second)
	_dynamic.append(func() -> void: per_second.text = MathUtils.format_number(GameManager.auto_cps, true))


# ---------------------------------------------------------------- Planeten & Prestige

func _build_planets() -> void:
	_title.text = "PLANETENRAUB"
	var p := GameManager.current_planet
	var info := UIStyle.label("Aktueller Planet: %s  (Credits x%s)\n%s" % [p.display_name, MathUtils.format_number(p.credit_multiplier), p.rule_text], 15, UIStyle.TEXT, 3)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info)
	var expl := UIStyle.label("Beim Planetenraub saugt das Mutterschiff den ganzen Planeten ein. Credits, Biomasse, UFO-Upgrades, Crew und Bio-Labor werden zurückgesetzt. Du behältst Forschung, Skilltree, Level, Erfolge und Alien-Daten – und bekommst Kosmischen Ruf (jeder Punkt: dauerhaft +10 % Credits, außerdem Währung für den Ruf-Shop).", 13, UIStyle.TEXT_DIM, 2)
	expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(expl)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.show_percentage = false
	_content.add_child(progress)
	var status := UIStyle.label("", 16, UIStyle.BLUE, 4)
	_content.add_child(status)
	# Ziel-Planet wählen
	_content.add_child(UIStyle.label("ZIEL WÄHLEN", 16, UIStyle.ACCENT, 4))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	_content.add_child(row)
	var chosen := {"planet": _default_destination()}
	var cards: Array[Button] = []
	for planet in GameManager.planets:
		var reachable := GameManager.planet_unlocked_after_prestige(planet)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(250, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = planet.icon
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\nCredits x%s\n%s" % [planet.display_name, MathUtils.format_number(planet.credit_multiplier), planet.rule_text if reachable else "Nach %d Planetenrauben" % planet.order]
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = not reachable
		b.button_pressed = planet == chosen["planet"]
		b.pressed.connect(func() -> void:
			chosen["planet"] = planet
			for c in cards:
				c.button_pressed = c == b
			AudioManager.play(&"click"))
		cards.append(b)
		row.add_child(b)
	var go := UIStyle.button("PLANETENRAUB STARTEN", 20, Color(0.2, 0.35, 0.75))
	go.custom_minimum_size = Vector2(0, 52)
	go.pressed.connect(func() -> void:
		if GameManager.can_prestige():
			close()
			GameManager.request_prestige(chosen["planet"])
		else:
			AudioManager.play(&"deny")
			UIStyle.shake_x(go))
	_content.add_child(go)
	var upd := func() -> void:
		var run := ResourceManager.run_total(ResourceManager.CREDITS)
		var req := GameManager.prestige_requirement()
		progress.max_value = req
		progress.value = minf(run, req)
		if GameManager.can_prestige():
			status.text = "Bereit! Du erhältst +%s Kosmischen Ruf." % MathUtils.format_number(GameManager.ruf_gain())
			go.disabled = false
		else:
			status.text = "Verdiene %s Credits auf diesem Planeten (%s / %s)" % [MathUtils.format_number(req), MathUtils.format_number(run), MathUtils.format_number(req)]
			go.disabled = true
	upd.call()
	_dynamic.append(upd)
	# Ruf-Shop
	_content.add_child(UIStyle.label("RUF-SHOP  (Ruf: %s)" % MathUtils.format_number(ResourceManager.get_amount(ResourceManager.RUF)), 16, UIStyle.CURRENCY_COLORS[&"ruf"], 4))
	for u in UpgradeManager.by_category(UpgradeData.Category.RUF):
		var item: ShopItem = SHOP_ITEM.instantiate()
		item.setup(u)
		item.buy_pressed.connect(func(it: ShopItem) -> void:
			if UpgradeManager.buy(it.upgrade.id):
				AudioManager.play(&"buy")
				it.bounce()
			else:
				AudioManager.play(&"deny")
				it.deny())
		_content.add_child(item)
		_dynamic.append(func() -> void:
			if is_instance_valid(item):
				item.refresh())


func _default_destination() -> PlanetData:
	var best := GameManager.planets[0]
	for p in GameManager.planets:
		if GameManager.planet_unlocked_after_prestige(p) and p.order > best.order:
			best = p
	return best


# ---------------------------------------------------------------- Optionen

func _build_options() -> void:
	_title.text = "OPTIONEN"
	for entry in [["Gesamtlautstärke", "master_volume"], ["Soundeffekte", "sfx_volume"], ["Musik", "music_volume"]]:
		var hb := HBoxContainer.new()
		var lab := UIStyle.label(entry[0], 16, UIStyle.TEXT, 3)
		lab.custom_minimum_size = Vector2(220, 0)
		hb.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(GameManager.settings.get(entry[1], 1.0))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(0, 24)
		sl.value_changed.connect(func(v: float) -> void: GameManager.set_setting(entry[1], v))
		hb.add_child(sl)
		_content.add_child(hb)
	for entry in [["Bildschirmwackeln", "screenshake"], ["Partikeleffekte", "particles"]]:
		var cb := CheckBox.new()
		cb.text = entry[0]
		cb.add_theme_font_size_override("font_size", 16)
		cb.button_pressed = bool(GameManager.settings.get(entry[1], true))
		cb.toggled.connect(func(on: bool) -> void: GameManager.set_setting(entry[1], on))
		_content.add_child(cb)
	var fs := CheckBox.new()
	fs.text = "Vollbild"
	fs.add_theme_font_size_override("font_size", 16)
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_content.add_child(fs)
	var help := UIStyle.label("Steuerung: Klicken oder gedrückt halten = Traktorstrahl · 1–5 = Gadgets · M = Mutterschiff · ESC = Fenster schließen", 13, UIStyle.TEXT_DIM, 2)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(help)
	var save_b := UIStyle.button("Jetzt speichern", 16)
	save_b.pressed.connect(func() -> void:
		GameManager.save_game()
		save_b.text = "Gespeichert ✓"
		AudioManager.play(&"pop"))
	_content.add_child(save_b)
	var reset_b := UIStyle.button("Spielstand komplett löschen", 16, Color(0.5, 0.12, 0.2))
	reset_b.pressed.connect(func() -> void:
		if _reset_armed > 0.0:
			GameManager.reset_game()
			close()
		else:
			_reset_armed = 3.0
			reset_b.text = "Wirklich? Nochmal klicken!"
			UIStyle.shake_x(reset_b))
	_content.add_child(reset_b)


# ---------------------------------------------------------------- Offline

func _build_offline() -> void:
	_title.text = "WILLKOMMEN ZURÜCK!"
	var o := GameManager.pending_offline
	var t := UIStyle.label("Du warst %s weg. Deine Flotte hat fleißig weiter entführt:" % MathUtils.format_time(float(o.get("seconds", 0.0))), 17, UIStyle.TEXT, 3)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(t)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.add_child(UIStyle.icon_rect(ResourceManager.icon(ResourceManager.CREDITS), 40))
	hb.add_child(UIStyle.label("+" + MathUtils.format_number(float(o.get("credits", 0.0))), 34, UIStyle.GOLD, 7))
	_content.add_child(hb)
	if float(o.get("biomass", 0.0)) > 0.0:
		var hb2 := HBoxContainer.new()
		hb2.add_child(UIStyle.icon_rect(ResourceManager.icon(ResourceManager.BIOMASS), 30))
		hb2.add_child(UIStyle.label("+" + MathUtils.format_number(float(o.get("biomass", 0.0))), 24, UIStyle.CURRENCY_COLORS[&"biomass"], 5))
		_content.add_child(hb2)
	_content.add_child(UIStyle.label("(max. %d h, %d %% Effizienz – verbessere das im Skilltree)" % [int(UpgradeManager.stat(&"offline_hours")), int(UpgradeManager.stat(&"offline_mult") * 100.0)], 13, UIStyle.TEXT_DIM, 2))
	var b := UIStyle.button("EINSAMMELN", 22, Color(0.2, 0.55, 0.3))
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func() -> void:
		AudioManager.play(&"gold")
		close())
	_content.add_child(b)
	GameManager.comment(&"offline")
