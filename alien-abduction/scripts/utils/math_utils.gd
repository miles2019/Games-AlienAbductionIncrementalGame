class_name MathUtils
extends RefCounted
## Zahlenformatierung und Skalierungs-Helfer.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"]


static func format_number(value: float, decimals_small: bool = false) -> String:
	if is_nan(value) or is_inf(value):
		return "∞"
	var negative := value < 0.0
	var v := absf(value)
	var text: String
	if v < 1000.0:
		if decimals_small and v < 10.0 and not is_equal_approx(v, floor(v)):
			text = "%.1f" % v
		else:
			text = str(int(floor(v)))
	else:
		var tier := 0
		while v >= 1000.0 and tier < SUFFIXES.size() - 1:
			v /= 1000.0
			tier += 1
		if v < 10.0:
			text = "%.2f%s" % [v, SUFFIXES[tier]]
		elif v < 100.0:
			text = "%.1f%s" % [v, SUFFIXES[tier]]
		else:
			text = "%d%s" % [int(v), SUFFIXES[tier]]
	return ("-" if negative else "") + text


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min %d s" % [floori(s / 60.0), s % 60]
	return "%d h %d min" % [floori(s / 3600.0), floori((s % 3600) / 60.0)]


static func format_percent(fraction: float) -> String:
	return "%d %%" % int(round(fraction * 100.0))


## Weiches Annähern, framerate-unabhängig.
static func damp(current: float, target: float, smoothing: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-smoothing * delta))


static func damp_v(current: Vector2, target: Vector2, smoothing: float, delta: float) -> Vector2:
	return current.lerp(target, 1.0 - exp(-smoothing * delta))


## Quadratische Bezierkurve
static func bezier(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
