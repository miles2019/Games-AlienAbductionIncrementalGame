extends Node2D
## Nachschub-Transport: fährt quer über das Feld und lädt unterwegs neue Ziele ab.
## Erklärt sichtbar, warum neue Menschen, Tiere und Fahrzeuge erscheinen. Nicht entführbar.

signal drop(world_pos: Vector2)

const SPEED := 190.0
const STYLES := {
	&"bus": {"body": Color(1.0, 0.8, 0.2), "trim": Color(0.35, 0.25, 0.1), "cars": 1, "len": 96.0},
	&"train": {"body": Color(0.85, 0.3, 0.3), "trim": Color(0.25, 0.2, 0.25), "cars": 3, "len": 64.0},
	&"truck": {"body": Color(0.45, 0.6, 0.4), "trim": Color(0.2, 0.25, 0.2), "cars": 1, "len": 84.0},
	&"caravan": {"body": Color(0.75, 0.55, 0.35), "trim": Color(0.4, 0.28, 0.15), "cars": 3, "len": 40.0},
}

var transport: StringName = &"bus"
var label: String = "Nachschub"
var drops: int = 6
var field: Rect2 = Rect2(0, 0, 1280, 720)

var _dir: float = 1.0
var _drop_xs: Array[float] = []
var _t: float = 0.0
var _style: Dictionary


func _ready() -> void:
	_style = STYLES.get(transport, STYLES[&"bus"])
	_dir = 1.0 if randf() < 0.5 else -1.0
	var y := randf_range(field.position.y + field.size.y * 0.45, field.end.y - 30.0)
	position = Vector2(field.position.x - _length() if _dir > 0.0 else field.end.x + _length(), y)
	z_index = 5
	# Haltestellen gleichmäßig über das Feld verteilt
	for i in drops:
		var k := (i + 0.5) / float(drops)
		var x := lerpf(field.position.x + field.size.x * 0.12, field.end.x - field.size.x * 0.12, k)
		_drop_xs.append(x)
	if _dir < 0.0:
		_drop_xs.reverse()


func _length() -> float:
	return float(_style["len"]) * int(_style["cars"]) + 10.0 * (int(_style["cars"]) - 1)


func _process(delta: float) -> void:
	_t += delta
	position.x += SPEED * _dir * delta
	while not _drop_xs.is_empty() and (position.x - _drop_xs[0]) * _dir >= 0.0:
		_drop_xs.pop_front()
		drop.emit(global_position + Vector2(-_dir * 20.0, 0))
	var gone := position.x > field.end.x + _length() + 20.0 if _dir > 0.0 else position.x < field.position.x - _length() - 20.0
	if gone and _drop_xs.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	var body: Color = _style["body"]
	var trim: Color = _style["trim"]
	var n: int = _style["cars"]
	var l: float = _style["len"]
	var bounce := absf(sin(_t * 14.0)) * 1.5
	for i in n:
		# Wagen hinter der Lok (entgegen der Fahrtrichtung)
		var x0 := -_dir * i * (l + 10.0) - l * 0.5
		var r := Rect2(x0, -34.0 - bounce, l, 30.0)
		draw_rect(Rect2(r.position + Vector2(4, 34), Vector2(l - 8, 6)), Color(0, 0, 0, 0.2))
		draw_rect(r, body)
		draw_rect(r, trim, false, 2.0)
		# Fenster
		var w := 12.0
		var x := r.position.x + 8.0
		while x + w < r.end.x - 6.0:
			draw_rect(Rect2(x, r.position.y + 5.0, w, 10.0), Color(0.75, 0.9, 1.0, 0.9))
			x += w + 6.0
		# Räder
		draw_circle(Vector2(r.position.x + 12.0, -3.0), 5.0, Color(0.12, 0.1, 0.12))
		draw_circle(Vector2(r.end.x - 12.0, -3.0), 5.0, Color(0.12, 0.1, 0.12))
		if i < n - 1:
			# Kupplung zum nächsten Wagen
			var gap_start := x0 - 10.0 if _dir > 0.0 else x0 + l
			draw_line(Vector2(gap_start, -18.0), Vector2(gap_start + 10.0, -18.0), trim, 3.0)
	# Blinklicht & Beschriftung
	if int(_t * 5.0) % 2 == 0:
		draw_circle(Vector2(_dir * l * 0.5 - _dir * 6.0, -36.0 - bounce), 4.0, Color(1.0, 0.4, 0.3))
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(font, Vector2(-tw * 0.5, -44.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.05, 0.03, 0.1))
	draw_string(font, Vector2(-tw * 0.5, -44.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
