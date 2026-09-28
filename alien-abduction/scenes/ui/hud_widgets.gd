class_name HudWidgets
extends RefCounted
## Kleine HUD-Bausteine: Gadget-Leiste, Toasts, Crew-Funk, Nachrichtenticker, Buff-Anzeige.


class GadgetBar extends HBoxContainer:
	var _buttons: Dictionary = {}

	func _ready() -> void:
		add_theme_constant_override("separation", 8)
		alignment = BoxContainer.ALIGNMENT_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var i := 0
		for g in GameManager.GADGETS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 64)
			b.focus_mode = Control.FOCUS_NONE
			b.icon = load(g["icon"])
			b.expand_icon = true
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.tooltip_text = "[%d] %s – %s\nKosten: %d Energie" % [i + 1, g["name"], g["desc"], int(g["cost"])]
			var id: StringName = g["id"]
			var cost: float = g["cost"]
			var key := i + 1
			b.pressed.connect(func() -> void:
				if GameManager.use_gadget(id):
					UIStyle.pop(b, 1.3, 0.4)
				else:
					AudioManager.play(&"deny")
					UIStyle.shake_x(b, 5.0))
			b.draw.connect(func() -> void:
				var cd := GameManager.gadget_cooldown(id)
				var total := 1.0
				for gg in GameManager.GADGETS:
					if gg["id"] == id:
						total = gg["cooldown"]
				if cd > 0.0:
					var f := cd / total
					b.draw_rect(Rect2(0, b.size.y * (1.0 - f), b.size.x, b.size.y * f), Color(0, 0, 0, 0.6))
				elif ResourceManager.energy < cost:
					b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(0.2, 0, 0.1, 0.45))
				var font := ThemeDB.fallback_font
				b.draw_string_outline(font, Vector2(5, 15), str(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
				b.draw_string(font, Vector2(5, 15), str(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
				b.draw_string_outline(font, Vector2(5, b.size.y - 5), "%d⚡" % int(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
				b.draw_string(font, Vector2(5, b.size.y - 5), "%d⚡" % int(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.5)))
			add_child(b)
			_buttons[id] = b
			i += 1

	func _process(_delta: float) -> void:
		visible = GameManager.has_feature(&"gadgets")
		if not visible:
			return
		for g in GameManager.GADGETS:
			var b: Button = _buttons[g["id"]]
			b.visible = GameManager.gadget_available(g)
			b.queue_redraw()


class ToastStack extends VBoxContainer:
	func _ready() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameManager.toast.connect(add_toast)

	func add_toast(text: String, icon: Texture2D, color: Color) -> void:
		if get_child_count() >= 5:
			get_child(0).queue_free()
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", UIStyle.box(Color(0.1, 0.08, 0.18, 0.95), color, 10, 2, 10))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		p.add_child(hb)
		if icon:
			hb.add_child(UIStyle.icon_rect(icon, 26))
		var l := UIStyle.label(text, 15, color, 4)
		hb.add_child(l)
		add_child(p)
		p.modulate.a = 0.0
		p.position.x = -300
		var tw := p.create_tween()
		tw.tween_property(p, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(p, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.8)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.tween_callback(p.queue_free)


class CrewChat extends PanelContainer:
	var _portrait: TextureRect
	var _name: Label
	var _text: Label
	var _queue: Array = []
	var _showing: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UIStyle.box(Color(0.08, 0.14, 0.1, 0.93), UIStyle.ACCENT, 12, 2, 10))
		custom_minimum_size = Vector2(360, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		add_child(hb)
		_portrait = UIStyle.icon_rect(null, 48)
		hb.add_child(_portrait)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		hb.add_child(vb)
		_name = UIStyle.label("", 13, UIStyle.ACCENT, 3)
		vb.add_child(_name)
		_text = UIStyle.label("", 14, UIStyle.TEXT, 3)
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size = Vector2(280, 0)
		vb.add_child(_text)
		visible = false
		GameManager.crew_comment.connect(func(speaker: StringName, text: String) -> void:
			if _queue.size() < 3:
				_queue.append([speaker, text]))

	func _process(delta: float) -> void:
		if _showing:
			_t += delta
			_text.visible_ratio = minf(1.0, _t * 40.0 / maxf(1.0, _text.text.length()))
			if _t > 3.5 + _text.text.length() * 0.03:
				_showing = false
				var tw := create_tween()
				tw.tween_property(self, "modulate:a", 0.0, 0.3)
				tw.tween_callback(func() -> void: visible = false)
		elif not _queue.is_empty() and not visible:
			var m: Array = _queue.pop_front()
			var sp: Dictionary = GameManager.SPEAKERS.get(m[0], GameManager.SPEAKERS[&"computer"])
			_portrait.texture = load(sp["icon"])
			_name.text = sp["name"] + " funkt:"
			_text.text = m[1]
			_text.visible_ratio = 0.0
			_t = 0.0
			_showing = true
			visible = true
			modulate.a = 1.0
			UIStyle.pop(_portrait, 1.4, 0.5)
			AudioManager.play(&"click", 0.7, -8.0)


class NewsTicker extends PanelContainer:
	var _label: Label
	var _remaining: float = 0.0
	var _clip: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UIStyle.box(Color(0.6, 0.05, 0.1, 0.95), Color(1, 1, 1, 0.3), 6, 2, 6))
		var hb := HBoxContainer.new()
		add_child(hb)
		hb.add_child(UIStyle.label(" BREAKING NEWS ", 15, Color.WHITE, 4))
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_clip.custom_minimum_size = Vector2(0, 22)
		hb.add_child(_clip)
		_label = UIStyle.label("", 15, Color(1, 0.95, 0.8), 3)
		_clip.add_child(_label)
		visible = false
		GameManager.news_requested.connect(show_news)

	func show_news(text: String, duration: float) -> void:
		_label.text = text + "   +++   " + text
		_label.position.x = _clip.size.x
		_remaining = duration
		visible = true
		UIStyle.pop(self, 1.1, 0.4)

	func _process(delta: float) -> void:
		if not visible:
			return
		_remaining -= delta
		_label.position.x -= 90.0 * delta
		if _label.position.x < -_label.size.x * 0.5:
			_label.position.x += _label.size.x * 0.5
		if _remaining <= 0.0:
			visible = false


class BuffBar extends HBoxContainer:
	const NAMES := {&"overload": "Überladung", &"slowmo": "Zeitlupe", &"gold_rush": "Goldrausch", &"news": "Medienrummel x2",
		&"sun": "SONNE x5", &"parade": "Kuh-Parade"}
	var _labels: Dictionary = {}

	func _ready() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameManager.buff_changed.connect(_on_buff)

	func _on_buff(id: StringName, remaining: float, _duration: float) -> void:
		if remaining <= 0.0:
			if _labels.has(id):
				(_labels[id] as Control).queue_free()
				_labels.erase(id)
			return
		if not _labels.has(id):
			var l := UIStyle.label("", 14, UIStyle.GOLD, 4)
			l.add_theme_stylebox_override("normal", UIStyle.box(Color(0.15, 0.1, 0.25, 0.9), UIStyle.GOLD, 8, 2, 6))
			add_child(l)
			_labels[id] = l
			UIStyle.pop(l, 1.3, 0.4)
		(_labels[id] as Label).text = "%s %ds" % [NAMES.get(id, String(id)), int(ceil(remaining))]


## Kleine Anzeige: Region, aktuelle Zielpopulation, erwarteter Nachschub, seltene Ziele, Kartografie.
## Mit den Pfeilen wird zwischen freigeschalteten Regionen gewechselt.
class PopulationPanel extends PanelContainer:
	var _region: Label
	var _prev: Button
	var _next: Button
	var _bar: ProgressBar
	var _pop: Label
	var _supply: Label
	var _rare: Label
	var _map: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(260, 0)
		add_theme_stylebox_override("panel", UIStyle.box(Color(0.08, 0.06, 0.14, 0.82), Color(1, 1, 1, 0.08), 10, 2, 8))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		add_child(vb)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		vb.add_child(head)
		_prev = _arrow("◀", -1)
		head.add_child(_prev)
		_region = UIStyle.label("", 15, UIStyle.BLUE, 4)
		_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_region.mouse_filter = Control.MOUSE_FILTER_PASS
		head.add_child(_region)
		_next = _arrow("▶", 1)
		head.add_child(_next)
		_pop = UIStyle.label("", 13, UIStyle.TEXT, 3)
		vb.add_child(_pop)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(0, 7)
		_bar.show_percentage = false
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(_bar)
		_supply = UIStyle.label("", 12, UIStyle.TEXT_DIM, 3)
		vb.add_child(_supply)
		_rare = UIStyle.label("", 12, UIStyle.GOLD, 3)
		_rare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_rare)
		_map = UIStyle.label("", 12, UIStyle.TEXT_DIM, 3)
		vb.add_child(_map)

	func _arrow(text: String, step: int) -> Button:
		var b := UIStyle.button(text, 12)
		b.custom_minimum_size = Vector2(26, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _switch(step))
		return b

	## Nächste freigeschaltete Region in Richtung step
	func _switch(step: int) -> void:
		var p := GameManager.current_planet
		if p == null or p.regions.size() < 2 or GameManager.event_running:
			AudioManager.play(&"deny")
			return
		var idx := p.regions.find(GameManager.current_region)
		for i in range(1, p.regions.size()):
			var r: RegionData = p.regions[posmod(idx + step * i, p.regions.size())]
			if GameManager.region_unlocked(r):
				GameManager.set_region(r.id)
				AudioManager.play(&"click")
				return
		AudioManager.play(&"deny")
		GameManager.toast.emit("Weitere Regionen ab Level %d" % _next_unlock_level(), null, UIStyle.BLUE)

	func _next_unlock_level() -> int:
		var best := 999
		for r in GameManager.current_planet.regions:
			if not GameManager.region_unlocked(r):
				best = mini(best, r.unlock_level)
		return best

	func set_info(info: Dictionary) -> void:
		var r: RegionData = info.get("region")
		var p := GameManager.current_planet
		var multi := p != null and p.regions.size() > 1
		_prev.visible = multi
		_next.visible = multi
		if r:
			_region.text = r.display_name
			var val := "  ·  Wert x%s" % MathUtils.format_number(r.value_multiplier, true) if r.value_multiplier != 1.0 else ""
			_region.tooltip_text = "%s%s\nKapazität x%s, Nachschub x%s" % [r.description, val, MathUtils.format_number(r.capacity, true), MathUtils.format_number(r.resupply, true)]
			_map.text = "Kartografiert: %d %%" % int(GameManager.region_map_progress(r) * 100.0)
			_map.visible = true
		else:
			_region.text = p.display_name if p else ""
			_map.visible = false
		var pop: int = info.get("population", 0)
		var cap: int = info.get("capacity", 1)
		_pop.text = "Zielpopulation: %d / %d" % [pop, cap]
		_bar.max_value = cap
		_bar.value = pop
		if info.get("incoming", false):
			_supply.text = "Nachschub unterwegs: %s" % info.get("transport", "")
			_supply.add_theme_color_override("font_color", UIStyle.BLUE)
		elif info.get("lull", false):
			_supply.text = "Kurze Ruhe – Nachschub folgt gleich"
			_supply.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
		elif float(info.get("resupply", 0.0)) > 0.0:
			_supply.text = "Erwarteter Nachschub: +%s / s" % MathUtils.format_number(float(info["resupply"]), true)
			_supply.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		else:
			_supply.text = "Region voll besetzt"
			_supply.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		var rare: Array = info.get("rare", [])
		_rare.visible = not rare.is_empty()
		_rare.text = "✦ Selten: " + ", ".join(PackedStringArray(rare))


## Pause (Taste P): hält das Spiel komplett an – ohne Fortschritt. Drohnen zeigen nur Deko-Aktivität.
class PauseOverlay extends Control:
	var _dim: ColorRect
	var _box: VBoxContainer

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		_dim = ColorRect.new()
		_dim.color = Color(0.02, 0.01, 0.06, 0.45)
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_dim)
		_box = VBoxContainer.new()
		_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_box.grow_vertical = Control.GROW_DIRECTION_BOTH
		_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_box.add_theme_constant_override("separation", 10)
		add_child(_box)
		var title := UIStyle.label("PAUSE", 56, Color.WHITE, 12)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(title)
		var sub := UIStyle.label("Die Crew macht Kaffeepause. Während der Pause gibt es keinen Fortschritt –\nkeine Credits, keine Entführungen, keine Automatisierung.", 15, UIStyle.TEXT_DIM, 3)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(sub)
		var b := UIStyle.button("WEITER  [P]", 20, Color(0.2, 0.55, 0.3))
		b.custom_minimum_size = Vector2(220, 50)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(toggle)
		_box.add_child(b)

	func _unhandled_key_input(event: InputEvent) -> void:
		if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_P:
			toggle()
			get_viewport().set_input_as_handled()

	func toggle() -> void:
		if GameManager.event_running and not get_tree().paused:
			return
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		Engine.time_scale = 1.0
		if visible:
			AudioManager.play(&"whoosh", 0.8)
			GameManager.save_game()
