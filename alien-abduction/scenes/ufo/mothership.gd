class_name Mothership
extends Node2D
## Das Mutterschiff: erscheint beim Massenbeam-Event, saugt alles auf dem Bildschirm ein.

@onready var sprite: Sprite2D = $Sprite2D
@onready var anchor: Marker2D = $Anchor
@onready var beam_overlay: MassBeamOverlay = $MassBeamOverlay

var _t: float = 0.0


func _ready() -> void:
	visible = false
	z_index = 45
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if visible:
		sprite.position.y = sin(_t * 1.5) * 4.0


## Senkt sich ins Bild. Gibt den Tween zurück (await tween.finished).
func appear(field: Rect2) -> Tween:
	var w := field.size.x * 0.72
	var s := w / float(sprite.texture.get_width())
	sprite.scale = Vector2(s, s)
	anchor.position = Vector2(0, sprite.texture.get_height() * s * 0.4)
	beam_overlay.position = anchor.position
	beam_overlay.half_top = w * 0.18
	beam_overlay.half_bottom = field.size.x * 0.6
	beam_overlay.length = field.end.y - (field.position.y + 90.0)
	beam_overlay.alpha = 0.0
	global_position = Vector2(field.get_center().x, -sprite.texture.get_height() * s)
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", field.position.y + 30.0 + sprite.texture.get_height() * s * 0.5, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


func set_beam(on: bool) -> Tween:
	var tw := create_tween()
	tw.tween_property(beam_overlay, "alpha", 1.0 if on else 0.0, 0.35)
	return tw


func leave() -> Tween:
	var tw := create_tween()
	tw.tween_property(beam_overlay, "alpha", 0.0, 0.25)
	tw.tween_property(self, "global_position:y", -400.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)
	return tw
