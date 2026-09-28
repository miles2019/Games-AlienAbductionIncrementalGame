class_name Reticle
extends Node2D
## Fadenkreuz am Mauszeiger: zeigt Fangradius und Abklingzeit.

var radius: float = 34.0
var cooldown_ratio: float = 0.0
var color: Color = Color(0.45, 1.0, 0.55)
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 40


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var ready_now := cooldown_ratio <= 0.001
	var c := Color(color, 0.7) if ready_now else Color(1, 1, 1, 0.3)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, c, 2.0)
	if not ready_now:
		draw_arc(Vector2.ZERO, radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cooldown_ratio), 32, Color(color, 0.8), 3.0)
	for i in 4:
		var d := Vector2.RIGHT.rotated(_t * 1.4 + i * PI / 2.0)
		draw_line(d * (radius - 7.0), d * (radius + 7.0), c, 2.0)
	draw_circle(Vector2.ZERO, 2.0, c)
