class_name UIStyle
extends RefCounted
## Zentrales UI-Theme (Farben, Panels, Buttons) – wird einmal im HUD gesetzt.

const BG := Color(0.1, 0.08, 0.17, 0.92)
const BG_LIGHT := Color(0.17, 0.14, 0.28, 0.96)
const BORDER := Color(1, 1, 1, 0.12)
const ACCENT := Color(0.42, 1.0, 0.55)
const GOLD := Color(1.0, 0.84, 0.25)
const PINK := Color(1.0, 0.4, 0.75)
const BLUE := Color(0.35, 0.78, 1.0)
const PURPLE := Color(0.72, 0.45, 1.0)
const TEXT := Color(0.95, 0.94, 1.0)
const TEXT_DIM := Color(0.68, 0.66, 0.8)
const OUTLINE := Color(0.04, 0.02, 0.08)

const CURRENCY_COLORS := {
	&"credits": Color(1.0, 0.84, 0.25),
	&"biomass": Color(0.45, 0.95, 0.4),
	&"data": Color(0.35, 0.78, 1.0),
	&"skill_points": Color(0.8, 0.5, 1.0),
	&"ruf": Color(0.36, 1.0, 0.92),
}

static var _theme: Theme


static func box(color: Color = BG, border: Color = BORDER, radius: int = 10, border_w: int = 2, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = maxf(4, margin * 0.7)
	sb.content_margin_bottom = maxf(4, margin * 0.7)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := BG_LIGHT
		var b := BORDER
		match state:
			"hover":
				c = BG_LIGHT.lightened(0.12); b = ACCENT
			"pressed":
				c = BG_LIGHT.darkened(0.2); b = ACCENT
			"disabled":
				c = BG_LIGHT.darkened(0.35)
		if state == "focus":
			t.set_stylebox(state, "Button", StyleBoxEmpty.new())
		else:
			t.set_stylebox(state, "Button", box(c, b, 8, 2, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 3)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 3)
	t.set_stylebox("panel", "TooltipPanel", box(BG_LIGHT, ACCENT, 8, 2, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	# Scrollbar
	var grab := box(Color(1, 1, 1, 0.25), Color(0, 0, 0, 0), 6, 0, 0)
	var grab_h := box(ACCENT, Color(0, 0, 0, 0), 6, 0, 0)
	var track := box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 6, 0, 0)
	for n in ["grabber", "grabber_highlight", "grabber_pressed", "scroll"]:
		var sbx: StyleBox = track
		if n == "grabber":
			sbx = grab
		elif n != "scroll":
			sbx = grab_h
		t.set_stylebox(n, "VScrollBar", sbx)
	# Slider
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.35), BORDER, 6, 1, 3))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.2), Color(0, 0, 0, 0), 6, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 6, 0, 3))
	# CheckButton / ProgressBar
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.4), BORDER, 6, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 6, 0, 0))
	_theme = t
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func icon_rect(tex: Texture2D, size: float = 24.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, size: int = 15, color: Color = BG_LIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	if color != BG_LIGHT:
		b.add_theme_stylebox_override("normal", box(color, BORDER, 8, 2, 8))
		b.add_theme_stylebox_override("hover", box(color.lightened(0.15), ACCENT, 8, 2, 8))
		b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), ACCENT, 8, 2, 8))
	return b


## Federnder "Pop" – für Buttons, Zahlen, Panels
static func pop(node: CanvasItem, strength: float = 1.2, duration: float = 0.35) -> void:
	if node is Control:
		var c: Control = node
		c.pivot_offset = c.size * 0.5
	node.scale = Vector2(strength, strength)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func shake_x(node: Control, amount: float = 8.0) -> void:
	var start := node.position.x
	var tw := node.create_tween()
	for i in 4:
		tw.tween_property(node, "position:x", start + (amount if i % 2 == 0 else -amount), 0.04)
	tw.tween_property(node, "position:x", start, 0.04)
