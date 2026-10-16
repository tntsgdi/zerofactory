class_name Pal
# Near-black ground, white ink, and one cutting-heat orange that belongs to the
# laser, to hot metal and to warnings. Three pale signal tints (air, volts,
# fluid) only show while something is being measured or going wrong.
# Values above 1.0 feed the HDR additive passes.

const BG := Color(0.035, 0.037, 0.042)
const DEEP := Color(0.055, 0.058, 0.066)
const PLATE := Color(0.082, 0.086, 0.096)
const INK := Color(0.925, 0.93, 0.94)
const HEAT := Color(1.0, 0.353, 0.122)
const AIR := Color(0.56, 0.83, 0.9)
const VOLT := Color(0.66, 0.68, 1.0)
const FLUID := Color(0.62, 0.88, 0.62)


static func ink(a: float = 1.0, k: float = 1.0) -> Color:
	return Color(INK.r * k, INK.g * k, INK.b * k, a)


# Brightness above 1 mostly goes into red so the orange never washes pink.
static func heat(a: float = 1.0, k: float = 1.0) -> Color:
	if k <= 1.0:
		return Color(HEAT.r * k, HEAT.g * k, HEAT.b * k, a)
	return Color(HEAT.r * k, HEAT.g * (1.0 + (k - 1.0) * 0.32), HEAT.b * (1.0 + (k - 1.0) * 0.12), a)


static func tint(c: Color, a: float = 1.0, k: float = 1.0) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, a)


static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


static func ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func back(x: float, k: float = 1.7) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + x * x * ((k + 1.0) * x + k)


static func damp(v: float, to: float, rate: float, dt: float) -> float:
	return lerpf(v, to, 1.0 - exp(-rate * dt))


static func damp2(v: Vector2, to: Vector2, rate: float, dt: float) -> Vector2:
	return v.lerp(to, 1.0 - exp(-rate * dt))


static func money(v: float) -> String:
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("−$" if v < -0.5 else "$") + out


# A band of light that fades out at both ends (selection / hover highlight).
static func band(ci: CanvasItem, r: Rect2, a: float, c: Color = INK) -> void:
	var l := r.position.x
	var m := r.get_center().x
	var e := r.end.x
	var t := r.position.y
	var b := r.end.y
	var c0 := Color(c.r, c.g, c.b, 0.0)
	var c1 := Color(c.r, c.g, c.b, a)
	ci.draw_polygon(PackedVector2Array([Vector2(l, t), Vector2(m, t), Vector2(m, b), Vector2(l, b)]), PackedColorArray([c0, c1, c1, c0]))
	ci.draw_polygon(PackedVector2Array([Vector2(m, t), Vector2(e, t), Vector2(e, b), Vector2(m, b)]), PackedColorArray([c1, c0, c0, c1]))
