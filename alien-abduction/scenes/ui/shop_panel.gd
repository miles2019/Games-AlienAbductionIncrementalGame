class_name ShopPanel
extends PanelContainer
## Seitlicher Shop mit Tabs: UFO, Crew, Bio-Labor, Forschung, Deko.

signal collapsed_changed(collapsed: bool)

const WIDTH := 372.0
const SHOP_ITEM := preload("res://scenes/ui/shop_item.tscn")
const TABS: Array[Dictionary] = [
	{"id": &"ufo", "name": "UFO", "feature": &"", "cats": [UpgradeData.Category.UFO]},
	{"id": &"crew", "name": "Crew", "feature": &"crew", "cats": [UpgradeData.Category.CREW, UpgradeData.Category.CREW_MEMBER]},
	{"id": &"bio", "name": "Bio-Labor", "feature": &"biolab", "cats": [UpgradeData.Category.BIOLAB]},
	{"id": &"research", "name": "Forschung", "feature": &"research", "cats": [UpgradeData.Category.RESEARCH]},
	{"id": &"deco", "name": "Deko", "feature": &"cosmetic", "cats": [UpgradeData.Category.COSMETIC]},
]

var collapsed: bool = false
var current_tab: StringName = &"ufo"
var amount_mode: int = 1

var _tab_buttons: Dictionary = {}
var _amount_buttons: Array[Button] = []
var _amount_row: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _items: Array[ShopItem] = []
var _refresh_timer: float = 0.0
var _toggle: Button
var _collapsible: Array[Control] = []
const COLLAPSED_WIDTH := 58.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.08, 0.06, 0.14, 0.94), Color(1, 1, 1, 0.1), 0, 2, 10))
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH
	offset_top = TopBar.HEIGHT
	offset_right = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	clip_contents = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var header := HBoxContainer.new()
	vb.add_child(header)
	var title := UIStyle.label("SHOP", 20, UIStyle.ACCENT, 5)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# Tabs
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	vb.add_child(tabs)
	_collapsible.append(tabs)
	_collapsible.append(title)
	for tab in TABS:
		var b := UIStyle.button(tab["name"], 14)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(func() -> void:
			AudioManager.play(&"click")
			select_tab(tab["id"]))
		tabs.add_child(b)
		_tab_buttons[tab["id"]] = b
	# Mengen-Auswahl
	_amount_row = HBoxContainer.new()
	_amount_row.add_theme_constant_override("separation", 4)
	vb.add_child(_amount_row)
	_amount_row.add_child(UIStyle.label("Kaufen:", 13, UIStyle.TEXT_DIM, 2))
	for m in [1, 10, 100, -1]:
		var ab := UIStyle.button("MAX" if m < 0 else "x%d" % m, 13)
		ab.toggle_mode = true
		ab.custom_minimum_size = Vector2(52, 26)
		ab.button_pressed = m == 1
		ab.pressed.connect(func() -> void:
			amount_mode = m
			for other in _amount_buttons:
				other.button_pressed = other == ab
			AudioManager.play(&"click")
			_refresh_items())
		_amount_row.add_child(ab)
		_amount_buttons.append(ab)
	# Liste
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_collapsible.append(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	# Ein-/Ausklappen
	_toggle = UIStyle.button("»", 20)
	_toggle.custom_minimum_size = Vector2(34, 30)
	_toggle.tooltip_text = "Shop ein-/ausklappen"
	_toggle.pressed.connect(toggle_collapsed)
	header.add_child(_toggle)
	UpgradeManager.levels_changed.connect(_rebuild)
	GameManager.feature_unlocked.connect(func(_f: StringName) -> void: _refresh_tabs())
	GameManager.cosmetics_changed.connect(func() -> void:
		if current_tab == &"deco":
			_rebuild()
		else:
			_refresh_items())
	GameManager.game_reset.connect(func() -> void: select_tab(&"ufo"))
	_refresh_tabs()
	select_tab(&"ufo")


func select_tab(id: StringName) -> void:
	current_tab = id
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).button_pressed = k == id
	_amount_row.visible = id in [&"ufo", &"crew", &"bio"]
	_rebuild()
	_scroll.scroll_vertical = 0


func _tab(id: StringName) -> Dictionary:
	for t in TABS:
		if t["id"] == id:
			return t
	return TABS[0]


func _refresh_tabs() -> void:
	for tab in TABS:
		var f: StringName = tab["feature"]
		var b: Button = _tab_buttons[tab["id"]]
		var was := b.visible
		b.visible = f == &"" or GameManager.has_feature(f)
		if b.visible and not was:
			UIStyle.pop(b, 1.4, 0.6)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_items.clear()
	var tab := _tab(current_tab)
	for cat in tab["cats"]:
		var ups := UpgradeManager.by_category(cat)
		if cat == UpgradeData.Category.CREW_MEMBER and not ups.is_empty():
			var sep := UIStyle.label("— CREW-MITGLIEDER —", 13, UIStyle.PINK, 3)
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_list.add_child(sep)
		var teaser_shown := false
		for u in ups:
			var met := UpgradeManager.requirements_met(u)
			if not met:
				if teaser_shown:
					continue
				teaser_shown = true
			var item: ShopItem = SHOP_ITEM.instantiate()
			item.setup(u)
			item.amount_mode = amount_mode
			item.buy_pressed.connect(_on_buy)
			_list.add_child(item)
			_items.append(item)
	if current_tab == &"deco":
		_add_reward_cosmetics()


## Kosmetik aus Erfolgen: nicht käuflich, nur freischaltbar
func _add_reward_cosmetics() -> void:
	var sep := UIStyle.label("— ERFOLGS-BELOHNUNGEN —", 13, UIStyle.PINK, 3)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(sep)
	for id in GameManager.achievement_cosmetics():
		var c: Dictionary = GameManager.COSMETICS[id]
		var owned := GameManager.cosmetic_owned(id)
		var equipped := String(id) == str(GameManager.settings.get("skin")) or String(id) == str(GameManager.settings.get("beam"))
		var b := UIStyle.button("", 13)
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var ach := GameManager.achievement_by_id(c["achievement"])
		if owned:
			b.text = "%s%s" % [GameManager.cosmetic_name(id), "  ✓ AUSGERÜSTET" if equipped else "  – ausrüsten"]
			if c["type"] == "beam":
				b.add_theme_color_override("font_color", c["color"])
			b.pressed.connect(func() -> void:
				GameManager.equip_cosmetic(id)
				AudioManager.play(&"pop"))
		else:
			var unknown := ach == null or (ach.secret and not GameManager.unlocked_achievements.has(ach.id))
			b.text = "🔒 %s  (Erfolg: %s)" % [GameManager.cosmetic_name(id), "???" if unknown else ach.display_name]
			b.disabled = true
		_list.add_child(b)


func _refresh_items() -> void:
	for it in _items:
		if is_instance_valid(it):
			it.amount_mode = amount_mode
			it.refresh()
	# Tab-Hinweise: "!" wenn etwas kaufbar ist
	for tab in TABS:
		var b: Button = _tab_buttons[tab["id"]]
		var any := false
		for cat in tab["cats"]:
			for u in UpgradeManager.by_category(cat):
				if u.category != UpgradeData.Category.COSMETIC and UpgradeManager.can_buy(u):
					any = true
					break
			if any:
				break
		b.text = tab["name"] + (" !" if any and tab["id"] != current_tab else "")


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		_refresh_items()


func _on_buy(item: ShopItem) -> void:
	var u := item.upgrade
	if u.category == UpgradeData.Category.COSMETIC and GameManager.cosmetic_owned(u.id):
		GameManager.equip_cosmetic(u.id)
		AudioManager.play(&"pop")
		item.bounce()
		return
	if item.is_locked():
		AudioManager.play(&"deny")
		item.deny()
		return
	var amount := UpgradeManager.resolve_amount(u, amount_mode)
	if UpgradeManager.buy(u.id, amount):
		AudioManager.play(&"buy", 1.0 + minf(UpgradeManager.level(u.id), 40) * 0.015)
		item.bounce()
		if u.category == UpgradeData.Category.COSMETIC:
			GameManager.equip_cosmetic(u.id)
		_refresh_items()
	else:
		AudioManager.play(&"deny")
		item.deny()


func toggle_collapsed() -> void:
	collapsed = not collapsed
	AudioManager.play(&"whoosh")
	var tw := create_tween()
	if collapsed:
		for c in _collapsible:
			c.visible = false
		_amount_row.visible = false
	tw.tween_property(self, "offset_left", -COLLAPSED_WIDTH if collapsed else -WIDTH, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not collapsed:
		tw.tween_callback(func() -> void:
			for c in _collapsible:
				c.visible = true
			_amount_row.visible = current_tab in [&"ufo", &"crew", &"bio"])
	_toggle.text = "«" if collapsed else "»"
	collapsed_changed.emit(collapsed)


func current_width() -> float:
	return COLLAPSED_WIDTH if collapsed else WIDTH
