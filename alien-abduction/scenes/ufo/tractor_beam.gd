class_name TractorBeam
extends Line2D
## Traktorstrahl als Line2D: biegt sich leicht zum Ziel, pulsiert, saugt Partikel nach oben.
## Folgt einem BaseTarget solange es angehoben wird, oder blitzt kurz zu einem Punkt.

const WIDTH := 26.0
const SEGMENTS := 14

var source: Node2D
var source_offset: Vector2 = Vector2(0, 14)
var target: BaseTarget
var target_point: Vector2
var beam_color: Color = Color(0.45, 1.0, 0.55)
var is_flash: bool = false
var flash_time: float = 0.18

var _t: float = 0.0
var _last_from: Vector2
var _dying: bool = false
var _core: Line2D
var _particles: CPUParticles2D


func setup(p_source: Node2D, p_target: BaseTarget, p_point: Vector2, p_color: Color, p_flash: bool = false, p_width: float = WIDTH) -> void:
	source = p_source
	target = p_target
	target_point = p_point
	beam_color = p_color
	is_flash = p_flash
	width = p_width
	if is_instance_valid(source):
		_last_from = source.global_position + source_offset


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 12
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	width_curve = curve
	gradient = Gradient.new()
	_core = Line2D.new()
	_core.width = maxf(3.0, width * 0.18)
	_core.joint_mode = Line2D.LINE_JOINT_ROUND
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_core)
	if not is_flash and GameManager.settings.get("particles", true):
		_particles = CPUParticles2D.new()
		_particles.local_coords = false
		_particles.amount = 10
		_particles.lifetime = 0.45
		_particles.texture = load("res://assets/sprites/pixel.png")
		_particles.scale_amount_min = 0.6
		_particles.scale_amount_max = 1.2
		_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_particles.emission_sphere_radius = 14.0
		_particles.gravity = Vector2.ZERO
		_particles.spread = 8.0
		add_child(_particles)
	_update_colors()
	var full := width
	width = 0.0
	var tw := create_tween()
	tw.tween_property(self, "width", full, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_points()


func _process(delta: float) -> void:
	_t += delta
	if is_flash:
		if _t >= flash_time:
			die()
		modulate.a = 1.0 - _t / flash_time
	elif not is_instance_valid(target) or not target.is_lifting():
		die()
	_update_colors()
	_update_points()


func _update_colors() -> void:
	var c := beam_color
	if GameManager.COSMETICS.get(StringName(GameManager.settings.get("beam", "")), {}).get("rainbow", false):
		c = GameManager.beam_color(_t + get_instance_id() * 0.01)
	var pulse := 0.85 + sin(_t * 18.0) * 0.15
	gradient.set_color(0, Color(c.lightened(0.3), 0.85 * pulse))
	gradient.set_color(1, Color(c, 0.3 * pulse))
	_core.default_color = Color(1, 1, 1, 0.7 * pulse)
	if _particles:
		_particles.color = c.lightened(0.5)


func _update_points() -> void:
	var from := _last_from
	if is_instance_valid(source):
		from = source.global_position + source_offset
		_last_from = from
	var to := target_point
	if is_instance_valid(target):
		to = target.body_center()
		target_point = to
	# Kontrollpunkt: Strahl biegt sich Richtung Ziel und schwingt leicht
	var ctrl := Vector2(lerpf(from.x, to.x, 0.15) + sin(_t * 9.0) * 6.0, lerpf(from.y, to.y, 0.55))
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(MathUtils.bezier(from, ctrl, to, t) + Vector2(sin(_t * 20.0 + t * 7.0) * 1.5 * t, 0))
	points = pts
	_core.points = pts
	if _particles:
		_particles.global_position = to
		var dir := from - to
		_particles.direction = dir.normalized()
		var v := dir.length() / _particles.lifetime
		_particles.initial_velocity_min = v * 0.8
		_particles.initial_velocity_max = v


func die() -> void:
	if _dying:
		return
	_dying = true
	set_process(false)
	if _particles:
		_particles.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "width", 0.0, 0.14)
	tw.tween_property(_core, "width", 0.0, 0.14)
	tw.chain().tween_callback(queue_free)
