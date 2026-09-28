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
