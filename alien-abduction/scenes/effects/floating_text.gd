class_name FloatingText
extends Label
## Schwebender Text mit Pop + Bounce: "+10", "KRITISCH!", "HUP!" ...

static var _settings_cache: Dictionary = {}


func popup(world_pos: Vector2, p_text: String, color: Color, font_size: int = 20) -> void:
	text = p_text
	label_settings = _get_settings(font_size)
	modulate = color
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	reset_size()
	size = get_minimum_size()
	position = world_pos - size * 0.5
	pivot_offset = size * 0.5
	scale = Vector2(0.2, 0.2)
	rotation = randf_range(-0.12, 0.12)
	var start_y := position.y
	var drift := randf_range(-18.0, 18.0)
	var tw := create_tween()
	# Pop
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Hüpfen: hoch, fällt federnd zurück, dann nach oben ausblenden
	tw.parallel().tween_property(self, "position:y", start_y - 34.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", start_y - 18.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:x", position.x + drift, 0.5)
	tw.tween_property(self, "position:y", start_y - 60.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(self, "rotation", 0.0, 0.3)
	tw.tween_callback(queue_free)


static func _get_settings(font_size: int) -> LabelSettings:
	if _settings_cache.has(font_size):
		return _settings_cache[font_size]
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = Color.WHITE
	ls.outline_size = maxi(4, int(font_size / 4.0))
	ls.outline_color = Color(0.06, 0.03, 0.12)
	ls.shadow_size = 0
	_settings_cache[font_size] = ls
	return ls
