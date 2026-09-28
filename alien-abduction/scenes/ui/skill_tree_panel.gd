class_name SkillTreePanel
extends Control
## Vollbild-Skilltree mit vier Ästen. Knoten federn, Verbindungen schwingen wie Gummiseile.
## Ziehen = verschieben, Mausrad = zoomen, ESC/Rechtsklick = schließen.

const BRANCHES: Array[Dictionary] = [
	{"name": "SAUGTECHNIK", "color": Color(0.42, 1.0, 0.55), "dir": Vector2(0, -1)},
	{"name": "TARNUNG", "color": Color(0.35, 0.78, 1.0), "dir": Vector2(1, 0)},
	{"name": "ALIEN-WIRTSCHAFT", "color": Color(1.0, 0.84, 0.25), "dir": Vector2(0, 1)},
	{"name": "MUTTERSCHIFF-TECH", "color": Color(0.8, 0.5, 1.0), "dir": Vector2(-1, 0)},
	{"name": "", "color": Color(1, 1, 1), "dir": Vector2.ZERO},
]

var _canvas: Control
var _nodes: Dictionary = {}     # id -> SkillNode
var _tooltip: PanelContainer
var _tip_title: Label
var _tip_body: Label
var _tip_cost: Label
var _sp_label: Label
var _hovered: SkillNode
var _dragging: bool = false
var _zoom: float = 1.0
var _zoom_target: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _jelly: float = 0.0
var _jelly_v: float = 0.0
var _t: float = 0.0
var _stars: Array[Vector3] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for i in 140:
		_stars.append(Vector3(randf(), randf(), randf()))
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_connections)
	add_child(_canvas)
	# Kopfzeile
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 20
	header.offset_right = -20
	header.offset_top = 14
	header.add_theme_constant_override("separation", 16)
	add_child(header)
	header.add_child(UIStyle.label("SKILLTREE", 30, UIStyle.PURPLE, 8))
	_sp_label = UIStyle.label("", 20, Color.WHITE, 5)
	_sp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_sp_label)
	var hint := UIStyle.label("Ziehen = verschieben · Mausrad = zoomen · ESC = schließen", 13, UIStyle.TEXT_DIM, 3)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hint)
	var close := UIStyle.button("✕ Schließen", 16, Color(0.5, 0.15, 0.25))
	close.pressed.connect(close_panel)
	header.add_child(close)
	# Tooltip
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UIStyle.box(Color(0.1, 0.08, 0.18, 0.97), UIStyle.PURPLE, 10, 2, 12))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size = Vector2(280, 0)
	_tooltip.visible = false
	_tooltip.z_index = 10
	var tvb := VBoxContainer.new()
	tvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(tvb)
	_tip_title = UIStyle.label("", 18, Color.WHITE, 4)
	_tip_body = UIStyle.label("", 14, UIStyle.TEXT, 3)
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body.custom_minimum_size = Vector2(260, 0)
	_tip_cost = UIStyle.label("", 14, UIStyle.PURPLE, 3)
	tvb.add_child(_tip_title)
	tvb.add_child(_tip_body)
	tvb.add_child(_tip_cost)
	add_child(_tooltip)
	_build_nodes()
	UpgradeManager.levels_changed.connect(_refresh)
	ResourceManager.resource_changed.connect(func(t: StringName, _a: float, _d: float) -> void:
		if t == ResourceManager.SKILL_POINTS:
			_refresh())
	_refresh()


func _build_nodes() -> void:
	for u in UpgradeManager.by_category(UpgradeData.Category.SKILL):
		var n := SkillNode.new()
		var b: Dictionary = BRANCHES[clampi(u.branch, 0, BRANCHES.size() - 1)]
		n.setup(u, b["color"])
		n.clicked.connect(_on_node_clicked)
		n.hovered.connect(_on_node_hovered)
		_canvas.add_child(n)
		_nodes[u.id] = n


func open() -> void:
	visible = true
	_refresh()
	modulate.a = 0.0
	_zoom_target = clampf(minf(size.x / 1400.0, (size.y - 80.0) / 1200.0), 0.45, 1.0)
	_zoom = _zoom_target * 0.7
	_pan = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	var i := 0
	for id in _nodes:
		var n: SkillNode = _nodes[id]
		n.pop_in(0.02 * i + n.base_position.length() * 0.0006)
		i += 1
	AudioManager.play(&"whoosh", 1.2)


func close_panel() -> void:
	AudioManager.play(&"whoosh", 0.9)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void: visible = false)
	_tooltip.visible = false


func _refresh() -> void:
	_sp_label.text = "Skillpunkte: %d" % int(ResourceManager.get_amount(ResourceManager.SKILL_POINTS))
	if _hovered:
		_update_tooltip(_hovered)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_zoom = MathUtils.damp(_zoom, _zoom_target, 10.0, delta)
	# Wackelpudding-Feder für den ganzen Baum
	var acc := -_jelly * 180.0 - _jelly_v * 9.0
	_jelly_v += acc * minf(delta, 0.033)
	_jelly += _jelly_v * minf(delta, 0.033)
	var s := _zoom * (1.0 + _jelly * 0.04)
	_canvas.scale = Vector2(s, s * (1.0 - _jelly * 0.03))
	_canvas.position = size * 0.5 + Vector2(0, 20) + _pan
	if _tooltip.visible:
		var mp := get_local_mouse_position() + Vector2(22, 14)
		mp.x = minf(mp.x, size.x - _tooltip.size.x - 10)
		mp.y = minf(mp.y, size.y - _tooltip.size.y - 10)
		_tooltip.position = mp
	_canvas.queue_redraw()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			close_panel()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_target = clampf(_zoom_target * 1.1, 0.45, 1.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_target = clampf(_zoom_target / 1.1, 0.45, 1.6)
	elif event is InputEventMouseMotion and _dragging:
		_pan += (event as InputEventMouseMotion).relative


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()


func _on_node_hovered(node: SkillNode, is_hovering: bool) -> void:
	if is_hovering:
		_hovered = node
		_update_tooltip(node)
		_tooltip.visible = true
	elif _hovered == node:
		_hovered = null
		_tooltip.visible = false


func _update_tooltip(node: SkillNode) -> void:
	var u := node.upgrade
	var st := node.state()
	if u.secret and st == &"locked":
		_tip_title.text = "???"
		_tip_body.text = "Ein geheimer Knoten. Schalte den Vorgänger frei."
		_tip_cost.text = ""
		return
	var lvl := UpgradeManager.level(u.id)
	_tip_title.text = u.display_name
	_tip_title.add_theme_color_override("font_color", node.branch_color)
	_tip_body.text = u.description
	if st == &"maxed":
		_tip_cost.text = "✓ Maximal ausgebaut"
	elif st == &"locked":
		var parts: PackedStringArray = []
		for r in u.requirements:
			var p := UpgradeManager.get_upgrade(StringName(r.split(":")[0]))
			if p:
				parts.append(p.display_name)
		_tip_cost.text = "Benötigt: " + ", ".join(parts)
	else:
		_tip_cost.text = "Rang %d%s · Kosten: %d Skillpunkt%s" % [lvl, ("/%d" % u.max_level) if u.max_level > 0 else "",
			int(UpgradeManager.cost(u)), "e" if UpgradeManager.cost(u) > 1.0 else ""]


func _on_node_clicked(node: SkillNode) -> void:
	var u := node.upgrade
	if UpgradeManager.buy(u.id):
		AudioManager.play(&"levelup", 1.2)
		node.celebrate()
		_jelly_v += 6.0
		# Nachbarn wackeln mit
		for id in _nodes:
			var other: SkillNode = _nodes[id]
			if other == node:
				continue
			var d := other.base_position - node.base_position
			var dist := d.length()
			if dist < 320.0:
				other.impulse(4.0 * (1.0 - dist / 320.0), d)
		_update_tooltip(node)
	else:
		AudioManager.play(&"deny")
		node.impulse(-3.0, Vector2.RIGHT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.96))
	for s in _stars:
		var tw := 0.4 + 0.6 * absf(sin(_t * (0.5 + s.z) + s.z * 20.0))
		draw_rect(Rect2(Vector2(s.x * size.x, s.y * size.y) + _pan * 0.15 * s.z, Vector2(2, 2)), Color(1, 1, 1, tw * 0.6))


func _draw_connections() -> void:
	# Ast-Beschriftungen
	var font := ThemeDB.fallback_font
	for b in BRANCHES:
		if b["name"] == "":
			continue
		var dir: Vector2 = b["dir"]
		var txt: String = b["name"]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var pos := dir * 650.0 + Vector2(-w * 0.5, 6)
		draw_string_outline_on(font, pos, txt, 18, Color(b["color"], 0.85))
	# Gummiseile zwischen den Knoten
	for id in _nodes:
		var child: SkillNode = _nodes[id]
		for req in child.upgrade.requirements:
			var parent: SkillNode = _nodes.get(StringName(req.split(":")[0]))
			if parent == null:
				continue
			var a := parent.center()
			var b := child.center()
			var lit := UpgradeManager.has(parent.upgrade.id)
			var owned := UpgradeManager.has(child.upgrade.id)
			var col := Color(child.branch_color, 0.9) if owned else (Color(child.branch_color, 0.45) if lit else Color(1, 1, 1, 0.12))
			var mid := (a + b) * 0.5
			var normal := (b - a).orthogonal().normalized()
			var sag := sin(_t * 2.0 + a.x * 0.01) * 6.0
			var ctrl := mid + normal * sag + Vector2(0, 8)
			var pts := PackedVector2Array()
			for i in 17:
				pts.append(MathUtils.bezier(a, ctrl, b, i / 16.0))
			_canvas.draw_polyline(pts, Color(0, 0, 0, 0.4), 8.0 if owned else 5.0)
			_canvas.draw_polyline(pts, col, 5.0 if owned else 3.0)
			if owned:
				# Energie fließt entlang des Seils
				var f := fmod(_t * 0.8 + a.x * 0.003, 1.0)
				_canvas.draw_circle(MathUtils.bezier(a, ctrl, b, f), 4.0, Color(1, 1, 1, 0.8))


func draw_string_outline_on(font: Font, pos: Vector2, txt: String, fsize: int, color: Color) -> void:
	_canvas.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 6, Color(0, 0, 0, 0.8))
	_canvas.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
