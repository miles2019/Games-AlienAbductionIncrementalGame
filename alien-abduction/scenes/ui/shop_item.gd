class_name ShopItem
extends PanelContainer
## Eine Zeile im Shop: Icon, Name, Stufe, Beschreibung, Kosten. Klick = kaufen.

signal buy_pressed(item: ShopItem)

var upgrade: UpgradeData
var amount_mode: int = 1

var _icon: TextureRect
var _name: Label
var _level: Label
var _desc: Label
var _cost_icon: TextureRect
var _cost: Label
var _hover: bool = false
var _style_normal: StyleBoxFlat
var _style_ok: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_locked: StyleBoxFlat


func setup(u: UpgradeData) -> void:
	upgrade = u


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 70)
	_style_normal = UIStyle.box(Color(0.15, 0.12, 0.25, 0.95), Color(1, 1, 1, 0.08), 10, 2, 8)
	_style_ok = UIStyle.box(Color(0.17, 0.16, 0.3, 0.98), Color(UIStyle.ACCENT, 0.55), 10, 2, 8)
	_style_hover = UIStyle.box(Color(0.22, 0.2, 0.38, 1.0), UIStyle.ACCENT, 10, 2, 8)
	_style_locked = UIStyle.box(Color(0.1, 0.08, 0.16, 0.8), Color(1, 1, 1, 0.04), 10, 2, 8)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	_icon = UIStyle.icon_rect(upgrade.icon, 44.0)
	hb.add_child(_icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)
	_name = UIStyle.label(upgrade.display_name, 16, UIStyle.TEXT, 4)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	title.add_child(_name)
	_level = UIStyle.label("", 14, UIStyle.ACCENT, 3)
	title.add_child(_level)
	_desc = UIStyle.label(upgrade.description, 12, UIStyle.TEXT_DIM, 2)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(200, 0)
	vb.add_child(_desc)
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_row)
	_cost_icon = UIStyle.icon_rect(ResourceManager.icon(upgrade.currency), 16.0)
	cost_row.add_child(_cost_icon)
	_cost = UIStyle.label("", 14, UIStyle.GOLD, 3)
	cost_row.add_child(_cost)
	mouse_entered.connect(func() -> void:
		_hover = true
		refresh())
	mouse_exited.connect(func() -> void:
		_hover = false
		refresh())
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		buy_pressed.emit(self)
		accept_event()


func is_locked() -> bool:
	return not UpgradeManager.requirements_met(upgrade)


func refresh() -> void:
	if _name == null:
		return
	var lvl := UpgradeManager.level(upgrade.id)
	var locked := is_locked()
	var maxed := UpgradeManager.is_maxed(upgrade)
	var cosmetic := upgrade.category == UpgradeData.Category.COSMETIC
	var amount := UpgradeManager.resolve_amount(upgrade, amount_mode)
	var price := UpgradeManager.cost(upgrade, amount)
	var afford := ResourceManager.can_afford(upgrade.currency, price)
	if locked and upgrade.secret:
		_name.text = "???"
		_desc.text = "Noch geheim."
		_icon.texture = load("res://assets/icons/lock.png")
	else:
		_name.text = upgrade.display_name
		_desc.text = upgrade.description
		_icon.texture = upgrade.icon
	_icon.modulate = Color(0.4, 0.4, 0.5) if locked else Color.WHITE
	# Stufen-/Status-Anzeige
	if cosmetic:
		var owned := GameManager.cosmetic_owned(upgrade.id)
		var equipped := String(upgrade.id) == str(GameManager.settings.get("skin")) or String(upgrade.id) == str(GameManager.settings.get("beam"))
		_level.text = "AUSGERÜSTET" if equipped else ("BESITZT" if owned else "")
		maxed = owned
	elif upgrade.category == UpgradeData.Category.CREW:
		_level.text = ("x%d/%d" % [lvl, upgrade.max_level]) if upgrade.max_level > 0 else ("x%d" % lvl)
	elif upgrade.is_one_time():
		_level.text = "✓" if lvl > 0 else ""
	else:
		_level.text = "Lv %d%s" % [lvl, ("/%d" % upgrade.max_level) if upgrade.max_level > 0 else ""]
	# Kosten
	_cost_icon.visible = not maxed and not locked
	if locked:
		_cost.text = "Benötigt: " + _requirement_text()
		_cost.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	elif maxed:
		_cost.text = "Klicken zum Ausrüsten" if cosmetic else ("ERFORSCHT" if upgrade.category == UpgradeData.Category.RESEARCH else ("ANGEHEUERT" if upgrade.category == UpgradeData.Category.CREW_MEMBER else "MAXIMUM ERREICHT"))
		_cost.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		_cost.text = MathUtils.format_number(price) + ("  (x%d)" % amount if amount > 1 else "")
		_cost.add_theme_color_override("font_color", UIStyle.CURRENCY_COLORS.get(upgrade.currency, UIStyle.GOLD) if afford else Color(1, 0.45, 0.45))
	var style := _style_normal
	if locked or (maxed and not cosmetic):
		style = _style_locked
	elif _hover:
		style = _style_hover
	elif afford and not maxed:
		style = _style_ok
	add_theme_stylebox_override("panel", style)
	# Maximum erreicht: ausgegraut, Kaufen nicht mehr möglich
	modulate.a = 0.75 if locked else (0.6 if maxed and not cosmetic else 1.0)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if (maxed and not cosmetic) or locked else Control.CURSOR_POINTING_HAND


func _requirement_text() -> String:
	var parts: PackedStringArray = []
	for req in upgrade.requirements:
		var p := req.split(":")
		var u := UpgradeManager.get_upgrade(StringName(p[0]))
		var nm := u.display_name if u else p[0]
		parts.append(nm + (" x%s" % p[1] if p.size() > 1 else ""))
	return ", ".join(parts)


func bounce() -> void:
	UIStyle.pop(self, 1.06, 0.35)
	UIStyle.pop(_icon, 1.4, 0.45)


func deny() -> void:
	UIStyle.shake_x(_cost, 6.0)
