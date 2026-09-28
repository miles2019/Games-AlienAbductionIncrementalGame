class_name ScreenShakeCamera
extends Camera2D
## Trauma-basierter Screenshake (Stärke² → sanftes Abklingen) + Zoom-Punch.

@export var max_offset: float = 22.0
@export var decay: float = 1.6

var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _t: float = 0.0
var _zoom_tween: Tween


func _ready() -> void:
	_noise.frequency = 3.0
	GameManager.shake_requested.connect(add_shake)


## amount ~ Pixel (2 = leicht, 20 = heftig)
func add_shake(amount: float) -> void:
	trauma = clampf(trauma + amount / 25.0, 0.0, 1.0)


func punch_zoom(amount: float = 0.05, duration: float = 0.4) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	zoom = Vector2.ONE * (1.0 + amount)
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func zoom_to(value: float, duration: float) -> Tween:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * value, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _zoom_tween


func _process(delta: float) -> void:
	_t += delta * 60.0
	trauma = maxf(0.0, trauma - decay * delta)
	var s := trauma * trauma
	offset = Vector2(_noise.get_noise_2d(_t, 0.0), _noise.get_noise_2d(0.0, _t)) * max_offset * s * 2.0
	rotation = _noise.get_noise_2d(_t, _t) * 0.03 * s
