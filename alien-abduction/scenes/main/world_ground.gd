class_name WorldGround
extends Node2D
## Top-Down-Boden des aktuellen Planeten (Wiese, Sand, Schnee, Metall, Süßigkeiten).

const PX := 3.0   # Pixelraster

var planet: PlanetData
var size: Vector2 = Vector2(1280, 720)
var darkness: float = 0.0:
	set(v):
		darkness = v
		queue_redraw()
var tint: Color = Color(1, 1, 1, 0):
	set(v):
		tint = v
		queue_redraw()
var _patches: Array[Vector4] = []
var _details: Array[Vector4] = []   # x, y, variant, seed


func _ready() -> void:
	z_index = -100


func layout(p_size: Vector2, p_planet: PlanetData) -> void:
	size = p_size
	planet = p_planet
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(planet.id)) if planet else 1
	_patches.clear()
	_details.clear()
	for i in int(size.x * size.y / 30000.0):
		_patches.append(Vector4(rng.randf() * size.x, rng.randf() * size.y, rng.randf_range(40, 120), rng.randf_range(0.5, 1.0)))
	for i in int(size.x * size.y / 2600.0):
		_details.append(Vector4(snappedf(rng.randf() * size.x, PX), snappedf(rng.randf() * size.y, PX), rng.randi() % 6, rng.randf()))
	queue_redraw()


func _draw() -> void:
	if planet == null:
		return
	var margin := 120.0
	var base := planet.ground_color
	draw_rect(Rect2(-margin, -margin, size.x + margin * 2.0, size.y + margin * 2.0), base)
	# weiche Flecken
	for p in _patches:
		var c := planet.ground_color_2
		c.a = 0.55 * p.w
		_blob(Vector2(p.x, p.y), p.z, c)
	match planet.detail_style:
		&"sand":
			_draw_sand()
		&"snow":
			_draw_snow()
		&"metal":
			_draw_metal()
		&"candy":
			_draw_candy()
		_:
			_draw_grass()
	if darkness > 0.0:
		draw_rect(Rect2(-margin, -margin, size.x + margin * 2.0, size.y + margin * 2.0), Color(0.05, 0.02, 0.12, darkness * 0.65))
	if tint.a > 0.0:
		draw_rect(Rect2(-margin, -margin, size.x + margin * 2.0, size.y + margin * 2.0), tint)


func _blob(center: Vector2, r: float, c: Color) -> void:
	# pixelige Ellipse aus Rechtecken
	var step := PX * 3.0
	var ry := r * 0.55
	var y := -ry
	while y <= ry:
		var w := r * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry)))
		draw_rect(Rect2(snappedf(center.x - w, step), snappedf(center.y + y, step), snappedf(w * 2.0, step), step), c)
		y += step


func _draw_grass() -> void:
	for d in _details:
		var p := Vector2(d.x, d.y)
		match int(d.z):
			0, 1, 2:
				draw_rect(Rect2(p, Vector2(PX, PX * 2)), planet.detail_color)
				draw_rect(Rect2(p + Vector2(PX * 2, -PX), Vector2(PX, PX * 3)), planet.detail_color)
			3:
				draw_rect(Rect2(p, Vector2(PX, PX)), planet.detail_color_2)
				draw_rect(Rect2(p + Vector2(PX, -PX), Vector2(PX, PX)), Color(1, 0.9, 0.3))
			4:
				draw_rect(Rect2(p, Vector2(PX * 3, PX * 2)), Color(0.55, 0.55, 0.55, 0.6))
			_:
				pass


func _draw_sand() -> void:
	for d in _details:
		var p := Vector2(d.x, d.y)
		match int(d.z):
			0, 1:
				draw_rect(Rect2(p, Vector2(PX * 4, PX)), planet.detail_color)
			2:
				draw_rect(Rect2(p, Vector2(PX * 2, PX * 2)), planet.detail_color_2)
			3:
				draw_rect(Rect2(p, Vector2(PX, PX * 3)), Color(0.35, 0.6, 0.3))
				draw_rect(Rect2(p + Vector2(-PX, PX), Vector2(PX * 3, PX)), Color(0.35, 0.6, 0.3))
			_:
				pass


func _draw_snow() -> void:
	for d in _details:
		var p := Vector2(d.x, d.y)
		match int(d.z):
			0, 1, 2:
				draw_rect(Rect2(p, Vector2(PX, PX)), planet.detail_color_2)
			3:
				draw_rect(Rect2(p, Vector2(PX * 6, PX * 2)), Color(planet.detail_color, 0.6))
			_:
				pass


func _draw_metal() -> void:
	var grid := 72.0
	var x := 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, PX, size.y), planet.detail_color)
		x += grid
	var y := 0.0
	while y < size.y:
		draw_rect(Rect2(0, y, size.x, PX), planet.detail_color)
		y += grid
	for d in _details:
		if int(d.z) == 0:
			draw_rect(Rect2(snappedf(d.x, grid) + 6, snappedf(d.y, grid) + 6, PX, PX), planet.detail_color_2)


func _draw_candy() -> void:
	var cols := [Color(1, 0.4, 0.6), Color(0.5, 0.8, 1), Color(1, 0.95, 0.4), Color(0.6, 1, 0.6), Color(0.8, 0.5, 1)]
	for d in _details:
		var p := Vector2(d.x, d.y)
		if int(d.z) < 3:
			var c: Color = cols[int(d.w * cols.size()) % cols.size()]
			if d.w > 0.5:
				draw_rect(Rect2(p, Vector2(PX * 3, PX)), c)
			else:
				draw_rect(Rect2(p, Vector2(PX, PX * 3)), c)
