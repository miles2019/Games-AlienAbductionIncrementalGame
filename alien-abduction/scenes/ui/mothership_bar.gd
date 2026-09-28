class_name MothershipBar
extends VBoxContainer
## Mutterschiff-Balken mit leuchtender Füllung und pulsierendem Ruf-Button.

signal mothership_requested

var _label: Label
var _bar: Control
var _button: Button
var _combo: Label
var _value: float = 0.0
var _shown: float = 0.0
var _goal: float = 100.0
var _t: float = 0.0
var _combo_shown: int = 0


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UIStyle.label("MUTTERSCHIFF 0 %", 14, Color(0.85, 0.75, 1.0), 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(380, 22)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_button = UIStyle.button("MUTTERSCHIFF RUFEN!  [M]", 20, Color(0.55, 0.2, 0.85))
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.custom_minimum_size = Vector2(300, 46)
	_button.visible = false
	_button.pressed.connect(func() -> void:
		AudioManager.play(&"click")
		mothership_requested.emit())
	add_child(_button)
	_combo = UIStyle.label("", 26, UIStyle.ACCENT, 6)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_combo)
	GameManager.mothership_changed.connect(_on_changed)
	GameManager.combo_changed.connect(_on_combo)
	_on_changed(GameManager.mothership_charge, GameManager.mothership_goal())


func _on_changed(charge: float, goal: float) -> void:
	_value = charge
	_goal = goal
	var ready_now := charge >= goal and not GameManager.event_running
	if ready_now and not _button.visible:
		_button.visible = true
		UIStyle.pop(_button, 1.4, 0.6)
	elif not ready_now:
		_button.visible = false


func _on_combo(combo: int, mult: float) -> void:
	if combo < 3:
		_combo.text = ""
		_combo_shown = combo
		return
	_combo.text = "COMBO x%d   (+%d %%)" % [combo, int(round((mult - 1.0) * 100.0))]
	var heat := clampf(combo / 40.0, 0.0, 1.0)
	_combo.add_theme_color_override("font_color", UIStyle.ACCENT.lerp(UIStyle.PINK, heat))
	_combo.add_theme_font_size_override("font_size", 24 + int(heat * 16.0))
	if combo > _combo_shown:
		UIStyle.pop(_combo, 1.25, 0.3)
	_combo_shown = combo


func _process(delta: float) -> void:
	_t += delta
	_shown = MathUtils.damp(_shown, _value, 10.0, delta)
	_label.text = "%s  %d %%" % [GameManager.mothership_stage()["name"] if _value >= _goal else "MUTTERSCHIFF", int(100.0 * _value / maxf(1.0, _goal))]
	if _button.visible:
		_button.pivot_offset = _button.size * 0.5
		var s := 1.0 + sin(_t * 7.0) * 0.05
		_button.scale = Vector2(s, s)
		if GameManager.event_running:
			_button.visible = false
	_bar.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_style_box(UIStyle.box(Color(0.08, 0.04, 0.16, 0.9), Color(0.7, 0.5, 1.0, 0.6), 10, 2, 0), r)
	var f := clampf(_shown / maxf(1.0, _goal), 0.0, 1.0)
	if f > 0.0:
		var fill := Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * f, r.size.y - 6))
		var c := Color(0.7, 0.4, 1.0)
		if f >= 1.0:
			c = c.lerp(Color(1.0, 0.6, 1.0), 0.5 + 0.5 * sin(_t * 8.0))
		_bar.draw_style_box(UIStyle.box(c, Color(0, 0, 0, 0), 8, 0, 0), fill)
		# Glanzstreifen
		_bar.draw_rect(Rect2(fill.position + Vector2(4, 2), Vector2(maxf(0.0, fill.size.x - 8), 3)), Color(1, 1, 1, 0.35))
		# wandernde Funken
		for i in 3:
			var x := fmod(_t * 90.0 + i * 70.0, maxf(1.0, fill.size.x))
			_bar.draw_rect(Rect2(fill.position + Vector2(x, fill.size.y * 0.5 - 1), Vector2(4, 2)), Color(1, 1, 1, 0.6))
