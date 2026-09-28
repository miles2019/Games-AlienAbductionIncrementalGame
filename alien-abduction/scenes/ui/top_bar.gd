class_name TopBar
extends PanelContainer
## Obere Leiste: Währungen (laufen sichtbar hoch), Energie, Level/XP und Menü-Buttons.

signal menu_requested(page: StringName)

const HEIGHT := 58.0

var _values: Dictionary = {}      # type -> Label
var _rates: Dictionary = {}       # type -> Label
var _boxes: Dictionary = {}       # type -> Control
var _icons: Dictionary = {}       # type -> TextureRect
var _display: Dictionary = {}     # type -> float (angezeigter Wert)
var _energy_box: Control
var _energy_bar: ProgressBar
var _energy_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _planet_label: Label
var _buttons: Dictionary = {}
var _sp_badge: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.07, 0.05, 0.13, 0.95), Color(1, 1, 1, 0.08), 0, 0, 10))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	add_child(hb)
	for type in ResourceManager.ALL:
		var box := _make_resource_box(type)
		hb.add_child(box)
	# Energie
	_energy_box = VBoxContainer.new()
	_energy_box.add_theme_constant_override("separation", 0)
	_energy_label = UIStyle.label("ENERGIE 0/100", 12, Color(1.0, 0.95, 0.5), 3)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(120, 12)
	_energy_bar.show_percentage = false
	_energy_bar.add_theme_stylebox_override("fill", UIStyle.box(Color(1.0, 0.9, 0.3), Color(0, 0, 0, 0), 5, 0, 0))
	_energy_box.add_child(_energy_label)
	_energy_box.add_child(_energy_bar)
	hb.add_child(_energy_box)
	# Level
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	_level_label = UIStyle.label("LEVEL 1", 14, UIStyle.PURPLE, 3)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(110, 10)
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.PURPLE, Color(0, 0, 0, 0), 5, 0, 0))
	lv.add_child(_level_label)
	lv.add_child(_xp_bar)
	hb.add_child(lv)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	_planet_label = UIStyle.label("", 13, UIStyle.TEXT_DIM, 3)
	_planet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_planet_label)
	# Menü-Buttons
	for entry in [[&"skilltree", "Skilltree", "res://assets/icons/skillpoint.png"], [&"achievements", "Erfolge", "res://assets/icons/trophy.png"],
			[&"planets", "Planeten", "res://assets/icons/planet_earth.png"], [&"stats", "Statistik", "res://assets/icons/eye.png"], [&"options", "", "res://assets/icons/lock.png"]]:
		var b := UIStyle.button(entry[1], 14)
		b.icon = load(entry[2])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 20)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if entry[0] == &"options":
			b.text = "⚙"
			b.icon = null
			b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void:
			AudioManager.play(&"click")
			UIStyle.pop(b, 1.15)
			menu_requested.emit(entry[0]))
		hb.add_child(b)
		_buttons[entry[0]] = b
	_sp_badge = UIStyle.label("", 12, Color.WHITE, 3)
	_sp_badge.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PINK, Color(0, 0, 0, 0), 8, 0, 4))
	_sp_badge.position = Vector2(-6, -8)
	(_buttons[&"skilltree"] as Button).add_child(_sp_badge)
	for type in ResourceManager.ALL:
		_display[type] = ResourceManager.get_amount(type)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	GameManager.xp_changed.connect(func(_x: float, _n: float, _l: int) -> void: _refresh_level())
	GameManager.level_up.connect(func(_l: int) -> void: UIStyle.pop(_level_label, 1.5, 0.6))
	GameManager.feature_unlocked.connect(func(_f: StringName) -> void: refresh_visibility())
	GameManager.planet_changed.connect(func(_p: PlanetData) -> void: refresh_visibility())
	GameManager.game_reset.connect(func() -> void:
		for type in ResourceManager.ALL:
			_display[type] = 0.0
		refresh_visibility())
	refresh_visibility()
	_refresh_level()


func _make_resource_box(type: StringName) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	var ic := UIStyle.icon_rect(ResourceManager.icon(type), 30.0 if type == ResourceManager.CREDITS else 24.0)
	ic.tooltip_text = ResourceManager.display_name(type)
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	var big := type == ResourceManager.CREDITS
	var val := UIStyle.label("0", 28 if big else 19, UIStyle.CURRENCY_COLORS[type], 6 if big else 4)
	vb.add_child(val)
	var rate := UIStyle.label("", 11, UIStyle.TEXT_DIM, 3)
	vb.add_child(rate)
	hb.add_child(vb)
	hb.tooltip_text = ResourceManager.display_name(type)
	_values[type] = val
	_rates[type] = rate
	_boxes[type] = hb
	_icons[type] = ic
	return hb


func refresh_visibility() -> void:
	(_boxes[ResourceManager.BIOMASS] as Control).visible = GameManager.has_feature(&"biolab")
	(_boxes[ResourceManager.DATA] as Control).visible = GameManager.has_feature(&"research")
	(_boxes[ResourceManager.SKILL_POINTS] as Control).visible = GameManager.has_feature(&"skilltree")
	(_boxes[ResourceManager.RUF] as Control).visible = ResourceManager.lifetime_total(ResourceManager.RUF) > 0.0
	_energy_box.visible = GameManager.has_feature(&"gadgets")
	(_buttons[&"skilltree"] as Control).visible = GameManager.has_feature(&"skilltree")
	(_buttons[&"achievements"] as Control).visible = GameManager.has_feature(&"achievements")
	(_buttons[&"planets"] as Control).visible = GameManager.has_feature(&"planets")
	if GameManager.current_planet:
		_planet_label.text = GameManager.current_planet.display_name
		(_buttons[&"planets"] as Button).icon = GameManager.current_planet.icon


func _on_resource_changed(type: StringName, _amount: float, delta: float) -> void:
	if delta > 0.0 and _values.has(type) and type != ResourceManager.CREDITS:
		UIStyle.pop(_values[type], 1.15, 0.25)
	if type == ResourceManager.RUF or type == ResourceManager.SKILL_POINTS:
		refresh_visibility()


func _process(delta: float) -> void:
	for type in ResourceManager.ALL:
		var target := ResourceManager.get_amount(type)
		var shown: float = _display[type]
		if absf(target - shown) < 0.5 or target < shown:
			shown = target
		else:
			shown = MathUtils.damp(shown, target, 8.0, delta)
		_display[type] = shown
		(_values[type] as Label).text = MathUtils.format_number(shown)
	(_rates[ResourceManager.CREDITS] as Label).text = "%s/s" % MathUtils.format_number(GameManager.cps, true) if GameManager.cps > 0.0 else ""
	(_rates[ResourceManager.BIOMASS] as Label).text = ""
	var sp := ResourceManager.get_amount(ResourceManager.SKILL_POINTS)
	_sp_badge.visible = sp >= 1.0
	_sp_badge.text = " %d " % int(sp)
	if _energy_box.visible:
		var m := ResourceManager.energy_max()
		_energy_bar.max_value = m
		_energy_bar.value = ResourceManager.energy
		_energy_label.text = "ENERGIE %d/%d" % [int(ResourceManager.energy), int(m)]


func _refresh_level() -> void:
	_level_label.text = "LEVEL %d" % GameManager.level
	_xp_bar.max_value = GameManager.xp_needed()
	_xp_bar.value = GameManager.xp


## Bildschirmposition des Währungs-Icons (Ziel für fliegende Münzen)
func resource_target(type: StringName) -> Vector2:
	var ic: Control = _icons.get(type)
	if ic and ic.is_visible_in_tree():
		return ic.get_global_rect().get_center()
	return (_icons[ResourceManager.CREDITS] as Control).get_global_rect().get_center()


func pulse_resource(type: StringName) -> void:
	if _icons.has(type):
		UIStyle.pop(_icons[type], 1.3, 0.3)
