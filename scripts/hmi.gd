class_name Hmi
# The berth terminal's look (P.7, player chose C · industrial HMI, 2026-10-18):
# raised grey panels lit from the top left, dark inset screens for drawings and
# big numbers, black tag plates for titles, status lamps, segmented gauges,
# rocker tabs and industrial push buttons. On site the HUD keeps its own look;
# this is the terminal's. All alpha-aware (a), so the self-test can bring each
# part up.
#
# Lamps: FLUID green = fitted / ready / fine, INK white = can be had, HEAT =
# short of money / warning / chosen.

const BG := Color(0.075, 0.08, 0.088)
const HEAD := Color(0.11, 0.115, 0.125)
const PANEL := Color(0.1, 0.105, 0.115)
const PANEL_HI := Color(0.13, 0.135, 0.15)
const PANEL_LO := Color(0.085, 0.09, 0.1)
const SCREEN := Color(0.02, 0.024, 0.028)
const PLATE := Color(0.02, 0.022, 0.026)

# the lamp test during the self-test: every lamp lit while it runs
static var lamp_test := false


static func ok_col(a: float = 1.0) -> Color:
	return Pal.tint(Pal.FLUID, a, 1.12)


static func warn_col(a: float = 1.0) -> Color:
	return Pal.heat(a, 1.5)


static func can_col(a: float = 1.0) -> Color:
	return Pal.ink(0.9 * a, 1.25)


# a panel standing out of the console: light on its top and left edge, shadow
# on the bottom and right
static func raised(ci: CanvasItem, r: Rect2, a: float = 1.0, fill: Color = PANEL) -> void:
	ci.draw_rect(r, Color(fill.r, fill.g, fill.b, fill.a * a))
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.16 * a), 2.0)
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.12 * a), 2.0)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0, 0, 0, 0.6 * a), 2.0)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(0, 0, 0, 0.6 * a), 2.0)


# pressed into the console (a key held down, a slot)
static func sunk(ci: CanvasItem, r: Rect2, a: float = 1.0, fill: Color = PANEL_LO) -> void:
	ci.draw_rect(r, Color(fill.r, fill.g, fill.b, fill.a * a))
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0, 0, 0, 0.6 * a), 2.0)
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(0, 0, 0, 0.5 * a), 2.0)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(1, 1, 1, 0.1 * a), 1.0)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(1, 1, 1, 0.1 * a), 1.0)


# a dark screen set into a panel, for drawings and the big numbers
static func screen(ci: CanvasItem, r: Rect2, a: float = 1.0, grid: bool = false) -> void:
	ci.draw_rect(r, Color(SCREEN.r, SCREEN.g, SCREEN.b, a))
	if grid:
		var gx := r.position.x + 20.0
		while gx < r.end.x - 4.0:
			ci.draw_line(Vector2(gx, r.position.y + 2), Vector2(gx, r.end.y - 2), Pal.tint(Pal.AIR, 0.05 * a), 1.0)
			gx += 40.0
		var gy := r.position.y + 20.0
		while gy < r.end.y - 4.0:
			ci.draw_line(Vector2(r.position.x + 2, gy), Vector2(r.end.x - 2, gy), Pal.tint(Pal.AIR, 0.05 * a), 1.0)
			gy += 40.0
	ci.draw_rect(r, Color(0, 0, 0, 0.8 * a), false, 2.0)


# a black tag plate with its name stamped on
static func plate(ci: CanvasItem, font: Font, r: Rect2, s: String, size: int, a: float = 1.0, col: Color = Color(0.95, 0.96, 1.0)) -> void:
	ci.draw_rect(r, Color(PLATE.r, PLATE.g, PLATE.b, a))
	ci.draw_rect(r, Color(1, 1, 1, 0.2 * a), false, 1.0)
	ci.draw_string(font, r.position + Vector2(12, r.size.y * 0.5 + size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, size, Color(col.r, col.g, col.b, col.a * a))


# a status lamp; lit in its colour, or dark glass
static func lamp(ci: CanvasItem, p: Vector2, col: Color, on: bool, a: float = 1.0, r: float = 7.0) -> void:
	var lit := on or lamp_test
	ci.draw_circle(p, r + 2.0, Color(0.02, 0.02, 0.02, a))
	if lit:
		ci.draw_circle(p, r, Color(col.r, col.g, col.b, col.a * a))
	else:
		ci.draw_circle(p, r, Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, a))
	ci.draw_arc(p, r + 2.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25 * a), 1.0, true)


# a segmented bar gauge: how full (0..1) in col, the rest dark; `to` (when
# above frac) is drawn after it in heat, what buying would bring
static func gauge(ci: CanvasItem, r: Rect2, frac: float, col: Color, a: float = 1.0, segs: int = 10, to: float = -1.0) -> void:
	ci.draw_rect(r, Color(SCREEN.r, SCREEN.g, SCREEN.b, a))
	var sw := (r.size.x - 6.0) / segs
	for i in segs:
		var sr := Rect2(r.position.x + 3.0 + i * sw, r.position.y + 3.0, sw - 4.0, r.size.y - 6.0)
		var m := (i + 0.5) / segs
		var c := Color(0.06, 0.064, 0.07, a)
		if m <= frac:
			c = Color(col.r, col.g, col.b, col.a * a)
		elif to > frac and m <= to:
			c = Pal.heat(0.95 * a, 1.35)
		ci.draw_rect(sr, c)


# the industrial push button: a lamp-ringed button at the left, the label
# stamped beside it, sunk while pressed, shaken (sideways) when it can't act
static func push(ci: CanvasItem, font: Font, r: Rect2, label: String, ok: bool, hover: float, a: float, t: float, shake: float = 0.0, note: String = "", key: String = "ENTER", down: float = 0.0) -> void:
	r.position.x += sin(t * 70.0) * 9.0 * shake * shake
	r.position.y += 3.0 * down
	if down > 0.5:
		sunk(ci, r, a, PANEL_HI)
	else:
		raised(ci, r, a, PANEL_HI.lerp(Color(0.16, 0.165, 0.18), hover if ok else 0.0))
	var cc := r.position + Vector2(r.size.y * 0.5 + 12.0, r.size.y * 0.5)
	var br := r.size.y * 0.34
	ci.draw_circle(cc, br + 5.0, Color(0.02, 0.02, 0.02, a))
	var lc := (ok_col(a) if ok else Pal.ink(0.22 * a)) if shake < 0.05 else warn_col(a)
	ci.draw_circle(cc, br, lc)
	if ok and hover > 0.0:
		ci.draw_arc(cc, br + 5.0 + 4.0 * hover, 0.0, TAU, 28, Pal.tint(Pal.FLUID, 0.5 * hover * a, 1.5), 1.5, true)
	ci.draw_arc(cc, br + 5.0, 0.0, TAU, 28, Color(1, 1, 1, 0.3 * a), 2.0, true)
	var lx := cc.x + br + 22.0
	var lh := 30 if r.size.y >= 64.0 else 22
	ci.draw_string(font, Vector2(lx, r.position.y + r.size.y * 0.5 + lh * 0.36 - (8.0 if note != "" else 0.0)), label, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - lx - 90.0, lh, Pal.ink((0.98 if ok else 0.5) * a))
	if note != "":
		ci.draw_string(font, Vector2(lx, r.position.y + r.size.y * 0.5 + 22.0), note, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - lx - 20.0, 14, Pal.heat(0.9 * a, 1.2))
	if key != "" and ok:
		var kw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		ci.draw_string(font, Vector2(r.end.x - 20.0 - kw, r.position.y + r.size.y * 0.5 + 6.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.5 * a))


# a rocker tab: lamp, number and name; the open one raised and lit with a heat foot
static func rocker(ci: CanvasItem, font: Font, r: Rect2, label: String, on: bool, hover: float, a: float, down: float = 0.0) -> void:
	r.position.y += 3.0 * down
	if down > 0.5:
		sunk(ci, r, a, Color(0.16, 0.165, 0.18))
	else:
		raised(ci, r, a, Color(0.16, 0.165, 0.18) if on else PANEL.lerp(PANEL_HI, hover))
	if on:
		ci.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), Pal.heat(a, 1.4))
	lamp(ci, r.position + Vector2(22, r.size.y * 0.5), Pal.heat(1.0, 1.8), on, a, 6.0)
	ci.draw_string(font, r.position + Vector2(42, r.size.y * 0.5 + 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 50.0, 20, Pal.ink((0.98 if on else (0.85 if hover > 0.5 else 0.68)) * a))


# a readout box in the header: label, the figure, its lamp
static func readout(ci: CanvasItem, font_s: Font, font: Font, r: Rect2, label: String, value: String, col: Color, lamp_col: Color, a: float, size: int = 32) -> void:
	raised(ci, r, a, Color(0.06, 0.064, 0.07))
	ci.draw_string(font, r.position + Vector2(14, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.6 * a))
	var vw := font_s.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font_s, Vector2(r.end.x - 14 - vw, r.end.y - 14), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, col.a * a))
	lamp(ci, r.position + Vector2(r.size.x - 18, 18), lamp_col, true, a, 6.0)
