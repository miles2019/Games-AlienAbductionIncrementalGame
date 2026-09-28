class_name SkillNode
extends Control
## Ein Skilltree-Knoten mit Feder-Physik (Hover, Kauf-Impuls, Nachbarn wackeln mit).

signal clicked(node: SkillNode)
signal hovered(node: SkillNode, is_hovering: bool)

const SIZE := 62.0
const STIFFNESS := 220.0
const DAMPING := 11.0

var upgrade: UpgradeData
var branch_color: Color = Color.WHITE
var base_position: Vector2 = Vector2.ZERO

var _s: float = 0.0          # aktuelle Skalierung
var _sv: float = 0.0         # Skalierungs-Geschwindigkeit
var _target_s: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _offset_v: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _phase: float = 0.0
var _hover: bool = false
var _ring: float = 0.0       # Kauf-Welle
var _icon_tex: Texture2D


func setup(u: UpgradeData, color: Color) -> void:
	upgrade = u
	branch_color = color
	base_position = u.tree_position
	_icon_tex = u.icon


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_phase = randf() * TAU
	mouse_entered.connect(func() -> void:
		_hover = true
		_target_s = 1.22
		impulse(2.0)
		AudioManager.play(&"pop", 1.4 + randf() * 0.2, -14.0, 0.03)
		hovered.emit(self, true))
	mouse_exited.connect(func() -> void:
		_hover = false
		_target_s = 1.0
		hovered.emit(self, false))


func center() -> Vector2:
	return position + size * 0.5


## Stoß: Skalierung federt, Position wackelt
func impulse(strength: float, dir: Vector2 = Vector2.ZERO) -> void:
	_sv += strength
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	_offset_v += dir.normalized() * strength * 40.0


func pop_in(delay: float) -> void:
	_s = 0.0
	_sv = 0.0
	get_tree().create_timer(delay).timeout.connect(func() -> void: _sv = 9.0)


func celebrate() -> void:
	_ring = 1.0
	impulse(7.0)


func _process(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 0.033)
	# Feder für Skalierung
	var acc := (_target_s - _s) * STIFFNESS - _sv * DAMPING
	_sv += acc * dt
	_s += _sv * dt
	# Feder für Positions-Wackeln
	var acc_o := -_offset * STIFFNESS * 0.6 - _offset_v * DAMPING * 0.8
	_offset_v += acc_o * dt
	_offset += _offset_v * dt
	var idle := Vector2(sin(_t * 1.3 + _phase) * 2.5, cos(_t * 1.1 + _phase) * 3.0)
	position = base_position - size * 0.5 + _offset + idle
	scale = Vector2.ONE * maxf(0.0, _s)
	_ring = maxf(0.0, _ring - delta * 1.6)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func state() -> StringName:
	var lvl := UpgradeManager.level(upgrade.id)
	if UpgradeManager.is_maxed(upgrade):
		return &"maxed"
	if lvl > 0:
		return &"owned"
	if UpgradeManager.requirements_met(upgrade):
		return &"available"
	return &"locked"


func _draw() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5 - 4.0
	var st := state()
	var lvl := UpgradeManager.level(upgrade.id)
	var affordable := st != &"maxed" and st != &"locked" and UpgradeManager.can_buy(upgrade)
	var bg := Color(0.12, 0.1, 0.2)
	var ring_c := Color(1, 1, 1, 0.15)
	match st:
		&"available":
			bg = branch_color.darkened(0.7)
			ring_c = Color(branch_color, 0.6)
		&"owned":
			bg = branch_color.darkened(0.35)
			ring_c = branch_color
		&"maxed":
			bg = branch_color.darkened(0.2)
			ring_c = UIStyle.GOLD
	if upgrade.secret and st == &"locked":
		bg = Color(0.05, 0.04, 0.08)
	# Glühen wenn kaufbar
	if affordable:
		var g := 0.5 + 0.5 * sin(_t * 5.0)
		draw_circle(c, r + 6.0 + g * 3.0, Color(branch_color, 0.18 + g * 0.12))
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, bg)
	draw_arc(c, r, 0, TAU, 40, ring_c, 3.0 if st != &"locked" else 2.0)
	if _hover:
		draw_arc(c, r + 3.0, 0, TAU, 40, Color(1, 1, 1, 0.7), 2.0)
	# Icon
	var tex := _icon_tex
	if upgrade.secret and st == &"locked":
		tex = load("res://assets/icons/lock.png")
	if tex:
		var isz := Vector2(34, 34)
		draw_texture_rect(tex, Rect2(c - isz * 0.5, isz), false, Color(1, 1, 1, 0.35) if st == &"locked" else Color.WHITE)
	# Rang
	if upgrade.max_level != 1:
		var txt := "%d/%d" % [lvl, upgrade.max_level] if upgrade.max_level > 0 else str(lvl)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var p := c + Vector2(-w * 0.5 - 4, r - 6)
		draw_rect(Rect2(p, Vector2(w + 8, 16)), Color(0.05, 0.03, 0.1, 0.9))
		draw_string(font, p + Vector2(4, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GOLD if st == &"maxed" else Color.WHITE)
	# Kauf-Welle
	if _ring > 0.0:
		draw_arc(c, r + (1.0 - _ring) * 40.0, 0, TAU, 40, Color(branch_color.lightened(0.4), _ring), 4.0 * _ring)
