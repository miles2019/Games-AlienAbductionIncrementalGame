class_name MassBeamOverlay
extends Node2D
## Riesiger Traktorstrahl des Mutterschiffs (Kegel mit aufsteigenden Ringen).

var half_top: float = 150.0
var half_bottom: float = 600.0
var length: float = 500.0
var alpha: float = 0.0:
	set(v):
		alpha = v
		queue_redraw()
var color: Color = Color(0.5, 1.0, 0.7)
var _t: float = 0.0


func _ready() -> void:
	z_index = -1
	show_behind_parent = true


func _process(delta: float) -> void:
	_t += delta
	if alpha > 0.0:
		queue_redraw()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var pts := PackedVector2Array([Vector2(-half_top, 0), Vector2(half_top, 0), Vector2(half_bottom, length), Vector2(-half_bottom, length)])
	var top_c := Color(color, 0.5 * alpha)
	var bot_c := Color(color, 0.12 * alpha)
	draw_polygon(pts, PackedColorArray([top_c, top_c, bot_c, bot_c]))
	for k in 6:
		var t := fmod(_t * 0.9 + k / 6.0, 1.0)
		var y := lerpf(length, 0.0, t)
		var hw := lerpf(half_bottom, half_top, t)
		draw_line(Vector2(-hw, y), Vector2(hw, y), Color(0.9, 1.0, 0.95, 0.4 * alpha * (1.0 - t * 0.5)), 3.0)
	for i in 14:
		var px := sin(i * 12.9898 + floor(_t * 3.0)) * half_bottom * 0.8
		var py := fmod(i * 73.0 + _t * 300.0, length)
		var f := py / length
		draw_rect(Rect2(px * lerpf(half_top / half_bottom, 1.0, f), length - py, 4, 4), Color(1, 1, 1, 0.6 * alpha))
