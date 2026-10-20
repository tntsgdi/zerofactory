extends RefCounted
# The fleet's shared equipment art (2026-10-20 rework, player: "not a pile of boxes
# inside boxes"): every kind drawn as the real machine it stands for -- a pump is its
# volute, impeller, coupling and motor; a switchboard its busbars, meters and breaker
# stacks; a battery its cells, busbars and BMS. Each drawing picks a layout from its
# piece's shape (wide / tall / square) and its detail from its size: a small one gets
# the few strokes that say what it is, a big one repeats its units (cells, breakers,
# fins, racks) at their real pitch, capped so ARK-01's two thousand pieces stay cheap.
# White ink only. Art space is the piece's rectangle (0,0)-(w,h) in pixels (1 m = 48).

const M := 48.0
const SMALL := 30.0      # under this (px, the short side) only the outline strokes

# a piece kind's name decides the drawing where one art id covers several machines
const BY_NAME := {
	"p_heat_exchanger": "hx", "p_hx": "hx",
	"p_ark_duct_fan": "duct_fan", "p_deck_fan": "duct_fan",
	"p_chiller": "chiller",
	"p_ark_transformer": "transformer",
	"p_inverter": "inverter",
	"p_fuel_cell": "fuelcell", "p_fuelcell": "fuelcell",
	"p_hpu": "hpu", "p_door_hpu": "hpu",
	"p_galley": "galley", "p_ark_galley": "galley", "p_crew_mess": "galley",
	"p_workbench": "bench", "p_dr_workbench": "bench", "p_dr_lab_bench": "bench",
	"p_main_valves": "manifold",
	"p_grow_lamp": "growlamp", "p_bl_grow_light": "growlamp",
	"p_dc_tray": "tray",
	"p_ark_condensate_trap": "trap",
	"p_junction": "junction",
	"p_tool_wall": "toolwall",
	"p_ark_shelf": "shelf", "p_parts_rack": "shelf",
	"p_ark_table": "table",
	"p_ark_medcab": "medcab",
	"p_ark_desk": "desk",
	"p_bay_charger": "charger", "p_ark_charger": "charger",
	"p_ark_fire_bottle": "extinguisher", "p_foam": "extinguisher", "p_co2_bottle": "extinguisher",
	"p_ob_actuator": "actuator", "p_clamp_act": "actuator",
	"p_hg_relief": "relief", "p_psv": "relief",
	"p_stator_coil": "stator",
	"p_strain_gauge": "gauge_box", "p_pos_sensor": "gauge_box", "p_weight_sensor": "gauge_box",
	"p_beacon": "beacon",
	"p_ark_spares_box": "crate", "p_crate": "crate", "p_lc_crate": "crate", "p_lc_crate_small": "crate", "p_cargo_box": "crate",
	"p_container": "container", "p_cold_pallet": "container",
}

# ------------------------------------------------------------------ primitives

# Drawing these is a few hundred strokes a piece, too many to redo every time a strip
# of a big ship redraws: the first time a piece is drawn its strokes are recorded
# (lines bucketed by width, dots and fills as triangles, text as it is), and every
# redraw after replays them in a handful of calls.
static var _rec := false
static var _lines := {}          # width -> [points Array, colors Array]
static var _tp: Array = []       # triangles: points, colors, indices
static var _tc: Array = []
static var _ti: Array = []
static var _texts: Array = []    # [font, pos, text, width, size, color]
static var _cache := {}
static var ext = null          # art_ships.gd: each ship's signature machines (set by Art)
const CACHE_MAX := 9000


static func _seg(a: Vector2, b: Vector2, col: Color, wd: float) -> void:
	var k: float = snappedf(wd, 0.2)
	if not _lines.has(k):
		_lines[k] = [[], []]
	var e: Array = _lines[k]
	e[0].append(a)
	e[0].append(b)
	e[1].append(col)


static func _poly_segs(pts: PackedVector2Array, col: Color, wd: float) -> void:
	for i in pts.size() - 1:
		_seg(pts[i], pts[i + 1], col, wd)


static func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / n)) * r)
	return pts


static func _tri_fan(pts: PackedVector2Array, col: Color) -> void:
	var base := _tp.size()
	for q in pts:
		_tp.append(q)
		_tc.append(col)
	for k in range(1, pts.size() - 1):
		_ti.append(base)
		_ti.append(base + k)
		_ti.append(base + k + 1)


static func L(ci: CanvasItem, a: Vector2, b: Vector2, al: float = 0.5, wd: float = 1.0) -> void:
	if _rec:
		_seg(a, b, Pal.ink(al), wd)
	else:
		ci.draw_line(a, b, Pal.ink(al), wd, true)


static func R(ci: CanvasItem, r: Rect2, al: float = 0.5, wd: float = 1.0) -> void:
	if _rec:
		var col := Pal.ink(al)
		var q := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			_seg(q[i], q[(i + 1) % 4], col, wd)
	else:
		ci.draw_rect(r, Pal.ink(al), false, wd)


static func F(ci: CanvasItem, r: Rect2, al: float = 0.08) -> void:
	if _rec:
		_tri_fan(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), Pal.ink(al))
	else:
		ci.draw_rect(r, Pal.ink(al))


static func O(ci: CanvasItem, c: Vector2, r: float, al: float = 0.5, wd: float = 1.0) -> void:
	var n := clampi(int(r * 1.2) + 8, 10, 40)
	if _rec:
		_poly_segs(_arc_pts(c, r, 0.0, TAU, n), Pal.ink(al), wd)
	else:
		ci.draw_arc(c, r, 0.0, TAU, n, Pal.ink(al), wd, true)


static func A(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, al: float = 0.5, wd: float = 1.0) -> void:
	var n := clampi(int(r * absf(a1 - a0) * 0.2) + 4, 4, 32)
	if _rec:
		_poly_segs(_arc_pts(c, r, a0, a1, n), Pal.ink(al), wd)
	else:
		ci.draw_arc(c, r, a0, a1, n, Pal.ink(al), wd, true)


static func D(ci: CanvasItem, c: Vector2, r: float = 1.1, al: float = 0.5) -> void:
	if _rec:
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(c + Vector2.from_angle(TAU * k / 6.0) * r)
		_tri_fan(pts, Pal.ink(al))
	else:
		ci.draw_circle(c, r, Pal.ink(al))


static func P(ci: CanvasItem, pts: PackedVector2Array, al: float = 0.5, wd: float = 1.0) -> void:
	if pts.size() < 2:
		return
	if _rec:
		_poly_segs(pts, Pal.ink(al), wd)
	else:
		ci.draw_polyline(pts, Pal.ink(al), wd, true)


# a batch of loose segments (pairs of points): one draw call
static func S(ci: CanvasItem, segs: PackedVector2Array, al: float = 0.3, wd: float = 1.0) -> void:
	if segs.size() < 2:
		return
	if _rec:
		var col := Pal.ink(al)
		for i in range(0, segs.size() - 1, 2):
			_seg(segs[i], segs[i + 1], col, wd)
	else:
		ci.draw_multiline(segs, Pal.ink(al), wd, true)


static func T(ci: CanvasItem, font: Font, at: Vector2, text: String, width: float, fs: int, al: float) -> void:
	if _rec:
		_texts.append([font, at, text, width, fs, Pal.ink(al)])
	else:
		ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, Pal.ink(al))


static func _record(ci: CanvasItem, art: String, r: Rect2, p, font: Font) -> Array:
	_rec = true
	_lines = {}
	_tp = []
	_tc = []
	_ti = []
	_texts = []
	_draw_art(ci, art, r, p, font)
	_rec = false
	var lines: Array = []
	for k in _lines:
		lines.append([k, PackedVector2Array(_lines[k][0]), PackedColorArray(_lines[k][1])])
	var out := [lines, PackedVector2Array(_tp), PackedColorArray(_tc), PackedInt32Array(_ti), _texts]
	_lines = {}
	_tp = []
	_tc = []
	_ti = []
	_texts = []
	return out


static func _replay(ci: CanvasItem, rec: Array) -> void:
	for e in rec[0]:
		ci.draw_multiline_colors(e[1], e[2], e[0], true)
	if not rec[3].is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), rec[3], rec[1], rec[2])
	for t in rec[4]:
		ci.draw_string(t[0], t[1], t[2], HORIZONTAL_ALIGNMENT_LEFT, t[3], t[4], t[5])


static func sub(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(r.position + Vector2(r.size.x * x0, r.size.y * y0), Vector2(r.size.x * (x1 - x0), r.size.y * (y1 - y0)))


static func inset(r: Rect2, d: float) -> Rect2:
	return r.grow(-minf(d, minf(r.size.x, r.size.y) * 0.45))


# parallel lines across a rectangle at a pitch: vertical lines when vert
static func hatch(ci: CanvasItem, r: Rect2, pitch: float, vert: bool, al: float = 0.22, cap: int = 120) -> void:
	var segs := PackedVector2Array()
	var span: float = r.size.x if vert else r.size.y
	var n := mini(int(span / maxf(pitch, 2.0)), cap)
	for i in n:
		var t: float = (i + 0.5) * span / n
		if vert:
			segs.append(Vector2(r.position.x + t, r.position.y))
			segs.append(Vector2(r.position.x + t, r.end.y))
		else:
			segs.append(Vector2(r.position.x, r.position.y + t))
			segs.append(Vector2(r.end.x, r.position.y + t))
	S(ci, segs, al)


# slanted louvre slats
static func louvres(ci: CanvasItem, r: Rect2, al: float = 0.3) -> void:
	var segs := PackedVector2Array()
	var n := clampi(int(r.size.y / 4.0), 1, 30)
	for i in n:
		var y: float = r.position.y + (i + 0.5) * r.size.y / n
		segs.append(Vector2(r.position.x, y - 1.2))
		segs.append(Vector2(r.end.x, y + 1.2))
	S(ci, segs, al)


# zigzag pleats (a filter's media); vert: the folds run up and down
static func pleats(ci: CanvasItem, r: Rect2, pitch: float, vert: bool, al: float = 0.35) -> void:
	var pts := PackedVector2Array()
	var span: float = r.size.x if vert else r.size.y
	var n := clampi(int(span / maxf(pitch, 2.5)), 2, 90)
	for i in n + 1:
		var t: float = i * span / n
		var side: bool = i % 2 == 0
		if vert:
			pts.append(Vector2(r.position.x + t, r.position.y if side else r.end.y))
		else:
			pts.append(Vector2(r.position.x if side else r.end.x, r.position.y + t))
	P(ci, pts, al)


# a row of bolt heads between two points
static func bolts(ci: CanvasItem, a: Vector2, b: Vector2, n: int, al: float = 0.5, rad: float = 1.0) -> void:
	for i in n:
		D(ci, a.lerp(b, (i + 0.5) / n), rad, al)


static func corner_bolts(ci: CanvasItem, r: Rect2, d: float = 3.0, al: float = 0.5) -> void:
	for q in [r.position + Vector2(d, d), Vector2(r.end.x - d, r.position.y + d), r.end - Vector2(d, d), Vector2(r.position.x + d, r.end.y - d)]:
		D(ci, q, 1.0, al)


# a round dial: bezel, ticks, needle
static func gauge(ci: CanvasItem, c: Vector2, rad: float, al: float = 0.55) -> void:
	O(ci, c, rad, al)
	if rad >= 4.0:
		var segs := PackedVector2Array()
		for i in 5:
			var a: float = PI * 0.75 + i * PI * 0.375
			segs.append(c + Vector2.from_angle(a) * rad * 0.72)
			segs.append(c + Vector2.from_angle(a) * rad * 0.9)
		S(ci, segs, al * 0.7)
	L(ci, c, c + Vector2.from_angle(-0.7) * rad * 0.75, al)


# a handwheel: rim and spokes
static func wheel(ci: CanvasItem, c: Vector2, rad: float, al: float = 0.5) -> void:
	O(ci, c, rad, al)
	var segs := PackedVector2Array()
	for i in 3:
		var a: float = i * PI / 3.0 + 0.3
		segs.append(c + Vector2.from_angle(a) * rad)
		segs.append(c - Vector2.from_angle(a) * rad)
	S(ci, segs, al * 0.7)


# a fan or rotor seen along its shaft: casing, hub, swept blades
static func fan(ci: CanvasItem, c: Vector2, rad: float, n: int = 6, al: float = 0.5) -> void:
	O(ci, c, rad, al)
	O(ci, c, rad * 0.22, al)
	for i in n:
		var a: float = TAU * i / n
		var pts := PackedVector2Array()
		for k in 5:
			var t: float = k / 4.0
			pts.append(c + Vector2.from_angle(a + t * 0.9) * lerpf(rad * 0.24, rad * 0.88, t))
		P(ci, pts, al * 0.75)


# a centrifugal impeller: hub and backward-curved vanes
static func impeller(ci: CanvasItem, c: Vector2, rad: float, al: float = 0.45) -> void:
	O(ci, c, rad * 0.2, al)
	D(ci, c, 1.2, al)
	var n := 7 if rad > 14.0 else 5
	for i in n:
		var a: float = TAU * i / n
		var pts := PackedVector2Array()
		for k in 4:
			var t: float = k / 3.0
			pts.append(c + Vector2.from_angle(a - t * 1.1) * lerpf(rad * 0.22, rad, t))
		P(ci, pts, al)


# a volute casing: the spiral round the impeller and its throat out to a flange
# (up when out_up, else to the right); returns the flange centre
static func volute(ci: CanvasItem, c: Vector2, rad: float, out_up: bool = true, al: float = 0.6) -> Vector2:
	var pts := PackedVector2Array()
	var a0: float = -PI * 0.5 if out_up else 0.0
	for k in 21:
		var t: float = k / 20.0
		pts.append(c + Vector2.from_angle(a0 + PI * 0.12 + t * TAU * 0.86) * rad * (0.74 + 0.26 * t))
	P(ci, pts, al, 1.2)
	impeller(ci, c, rad * 0.62, al * 0.75)
	var end: Vector2 = pts[pts.size() - 1]
	var tip: Vector2
	if out_up:
		var x_in: float = c.x + rad * 0.12
		tip = Vector2((x_in + end.x) * 0.5 + rad * 0.1, c.y - rad * 1.32)
		L(ci, Vector2(x_in, c.y - rad * 0.74), Vector2(x_in, tip.y), al)
		L(ci, end, Vector2(end.x, tip.y), al)
		flange(ci, tip, Vector2.UP, absf(end.x - x_in) * 0.5 + 2.0, al)
	else:
		var y_in: float = c.y + rad * 0.12
		tip = Vector2(c.x + rad * 1.32, (y_in + end.y) * 0.5)
		L(ci, Vector2(c.x + rad * 0.74, y_in), Vector2(tip.x, y_in), al)
		L(ci, end, Vector2(tip.x, end.y), al)
		flange(ci, tip, Vector2.RIGHT, absf(end.y - y_in) * 0.5 + 2.0, al)
	return tip


# a pipe flange pair at c facing dir: two thick lips, bolts across them
static func flange(ci: CanvasItem, c: Vector2, dir: Vector2, half: float, al: float = 0.55) -> void:
	var t: Vector2 = dir.orthogonal()
	L(ci, c - t * half, c + t * half, al, 2.0)
	L(ci, c + dir * 2.2 - t * half, c + dir * 2.2 + t * half, al * 0.8, 1.4)
	if half > 5.0:
		D(ci, c + dir * 1.1 - t * (half - 1.5), 0.9, al)
		D(ci, c + dir * 1.1 + t * (half - 1.5), 0.9, al)


# a TEFC electric motor lying along x in r: fan cowl at the far end, the finned
# frame, the terminal box on top, its feet; the shaft leaves toward shaft_left
static func motor(ci: CanvasItem, r: Rect2, shaft_left: bool = true, al: float = 0.5) -> void:
	var cy: float = r.get_center().y
	var bh: float = r.size.y
	var cowl: float = minf(r.size.x * 0.18, bh * 0.45)
	var body := Rect2(r.position.x + (0.0 if shaft_left else cowl), r.position.y + bh * 0.08, r.size.x - cowl, bh * 0.84)
	R(ci, body, al)
	# the cooling fins along the frame
	if bh >= 14.0:
		hatch(ci, Rect2(body.position.x + 3.0, body.position.y + 2.0, body.size.x - 6.0, body.size.y - 4.0), maxf(3.2, bh / 9.0), false, 0.18, 24)
	# the fan cowl: rounded, its grille
	var cx: float = body.end.x if shaft_left else body.position.x
	var dirx: float = 1.0 if shaft_left else -1.0
	P(ci, PackedVector2Array([Vector2(cx, body.position.y + 1.0), Vector2(cx + dirx * cowl * 0.8, body.position.y + bh * 0.08), Vector2(cx + dirx * cowl, cy), Vector2(cx + dirx * cowl * 0.8, body.end.y - bh * 0.08), Vector2(cx, body.end.y - 1.0)]), al)
	if cowl > 5.0:
		L(ci, Vector2(cx + dirx * cowl * 0.45, body.position.y + bh * 0.15), Vector2(cx + dirx * cowl * 0.45, body.end.y - bh * 0.15), al * 0.5)
	# terminal box and its gland
	var tb_w: float = minf(body.size.x * 0.3, bh * 0.6)
	var tb := Rect2(body.get_center().x - tb_w * 0.5, body.position.y - bh * 0.22, tb_w, bh * 0.22)
	R(ci, tb, al)
	if tb_w > 8.0:
		D(ci, tb.position + Vector2(tb_w * 0.5, tb.size.y * 0.5), 1.2, al)
	# the shaft and the end bell
	var sx: float = body.position.x if shaft_left else body.end.x
	L(ci, Vector2(sx, cy), Vector2(sx - dirx * minf(6.0, r.size.x * 0.06), cy), al, 1.6)
	# feet
	L(ci, Vector2(body.position.x + body.size.x * 0.15, body.end.y), Vector2(body.position.x + body.size.x * 0.15, r.end.y), al * 0.8, 1.4)
	L(ci, Vector2(body.end.x - body.size.x * 0.15, body.end.y), Vector2(body.end.x - body.size.x * 0.15, r.end.y), al * 0.8, 1.4)


# a breaker module: its case, the toggle in its slot, the rating window
static func breaker(ci: CanvasItem, r: Rect2, on: bool = true, al: float = 0.45) -> void:
	R(ci, r, al)
	var c: Vector2 = r.get_center()
	var sl := Rect2(c.x - r.size.x * 0.12, r.position.y + r.size.y * 0.2, r.size.x * 0.24, r.size.y * 0.6)
	if r.size.x >= 10.0 and r.size.y >= 6.0:
		R(ci, sl, al * 0.7)
		var ty: float = sl.position.y + (sl.size.y * 0.15 if on else sl.size.y * 0.55)
		F(ci, Rect2(sl.position.x, ty, sl.size.x, sl.size.y * 0.3), al * 0.9)
		if r.size.x >= 18.0:
			L(ci, Vector2(r.position.x + r.size.x * 0.1, c.y), Vector2(sl.position.x - 2.0, c.y), al * 0.5)
	else:
		L(ci, Vector2(c.x, r.position.y + 1.0), Vector2(c.x, r.end.y - 1.0), al)


# a display face showing something: 0 trend, 1 bars, 2 a schematic, 3 text
static func screen_face(ci: CanvasItem, r: Rect2, kind: int, al: float = 0.4) -> void:
	R(ci, r, al + 0.1)
	var q := inset(r, 2.5)
	if q.size.x < 6.0 or q.size.y < 4.0:
		return
	match kind % 4:
		0:
			var pts := PackedVector2Array()
			for k in 9:
				var t: float = k / 8.0
				pts.append(Vector2(q.position.x + q.size.x * t, q.position.y + q.size.y * (0.55 + 0.3 * sin(t * 7.0 + kind) * (1.0 - t * 0.5))))
			P(ci, pts, al)
			L(ci, Vector2(q.position.x, q.end.y), q.end, al * 0.5)
		1:
			var segs := PackedVector2Array()
			var n := clampi(int(q.size.x / 4.0), 2, 10)
			for k in n:
				var x: float = q.position.x + (k + 0.5) * q.size.x / n
				segs.append(Vector2(x, q.end.y))
				segs.append(Vector2(x, q.end.y - q.size.y * (0.25 + 0.6 * fposmod(k * 0.37 + kind * 0.21, 1.0))))
			S(ci, segs, al)
		2:
			R(ci, sub(q, 0.1, 0.2, 0.35, 0.8), al * 0.8)
			R(ci, sub(q, 0.6, 0.2, 0.9, 0.5), al * 0.8)
			P(ci, PackedVector2Array([q.position + q.size * Vector2(0.35, 0.5), q.position + q.size * Vector2(0.48, 0.5), q.position + q.size * Vector2(0.48, 0.35), q.position + q.size * Vector2(0.6, 0.35)]), al * 0.7)
			D(ci, q.position + q.size * Vector2(0.75, 0.75), 1.4, al)
		_:
			var segs := PackedVector2Array()
			var n := clampi(int(q.size.y / 4.0), 1, 8)
			for k in n:
				var y: float = q.position.y + (k + 0.5) * q.size.y / n
				segs.append(Vector2(q.position.x, y))
				segs.append(Vector2(q.position.x + q.size.x * (0.4 + 0.5 * fposmod(k * 0.53 + kind * 0.3, 1.0)), y))
			S(ci, segs, al * 0.8)


# a pressure vessel standing up in r: shell, dished heads; returns the shell rect
static func vessel_v(ci: CanvasItem, r: Rect2, al: float = 0.55) -> Rect2:
	var dh: float = minf(r.size.x * 0.25, r.size.y * 0.2)
	var shell := Rect2(r.position.x, r.position.y + dh, r.size.x, r.size.y - 2.0 * dh)
	L(ci, shell.position, Vector2(shell.position.x, shell.end.y), al)
	L(ci, Vector2(shell.end.x, shell.position.y), shell.end, al)
	_head(ci, Vector2(shell.get_center().x, shell.position.y), r.size.x * 0.5, dh, true, al)
	_head(ci, Vector2(shell.get_center().x, shell.end.y), r.size.x * 0.5, dh, false, al)
	if shell.size.y > 10.0:
		L(ci, shell.position, Vector2(shell.end.x, shell.position.y), al * 0.4)
		L(ci, Vector2(shell.position.x, shell.end.y), shell.end, al * 0.4)
	return shell


# lying down
static func vessel_h(ci: CanvasItem, r: Rect2, al: float = 0.55) -> Rect2:
	var dh: float = minf(r.size.y * 0.25, r.size.x * 0.2)
	var shell := Rect2(r.position.x + dh, r.position.y, r.size.x - 2.0 * dh, r.size.y)
	L(ci, shell.position, Vector2(shell.end.x, shell.position.y), al)
	L(ci, Vector2(shell.position.x, shell.end.y), shell.end, al)
	_head_h(ci, Vector2(shell.position.x, shell.get_center().y), r.size.y * 0.5, dh, true, al)
	_head_h(ci, Vector2(shell.end.x, shell.get_center().y), r.size.y * 0.5, dh, false, al)
	if shell.size.x > 10.0:
		L(ci, shell.position, Vector2(shell.position.x, shell.end.y), al * 0.4)
		L(ci, Vector2(shell.end.x, shell.position.y), shell.end, al * 0.4)
	return shell


static func _head(ci: CanvasItem, c: Vector2, rx: float, ry: float, up: bool, al: float) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var a: float = PI * k / 12.0
		pts.append(c + Vector2(-cos(a) * rx, (-sin(a) if up else sin(a)) * ry))
	P(ci, pts, al)


static func _head_h(ci: CanvasItem, c: Vector2, ry: float, rx: float, left: bool, al: float) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var a: float = PI * k / 12.0
		pts.append(c + Vector2((-sin(a) if left else sin(a)) * rx, -cos(a) * ry))
	P(ci, pts, al)


# a nameplate: its frame and, where it's big enough to read, the tag
static func plate(ci: CanvasItem, r: Rect2, text: String, font: Font, al: float = 0.45) -> void:
	if r.size.x < 14.0 or r.size.y < 5.0:
		return
	R(ci, r, al * 0.8)
	if text != "" and font != null and r.size.y >= 9.0 and r.size.x >= text.length() * 4.6:
		var fs: int = clampi(int(r.size.y * 0.72), 7, 10)
		T(ci, font, Vector2(r.position.x + 2.0, r.position.y + r.size.y * 0.5 + fs * 0.36), text, r.size.x - 3.0, fs, al + 0.1)
	elif r.size.x >= 10.0:
		L(ci, Vector2(r.position.x + 2.0, r.get_center().y), Vector2(r.end.x - 2.0, r.get_center().y), al * 0.6)


static func tag_of(p) -> String:
	return p.tag if p != null else ""


# a door leaf: inset panel, hinges down one side, handle down the other
static func door_leaf(ci: CanvasItem, r: Rect2, hinge_left: bool, al: float = 0.42) -> void:
	R(ci, r, al)
	var q := inset(r, minf(3.0, r.size.x * 0.12))
	if q.size.x > 6.0 and q.size.y > 10.0:
		R(ci, q, al * 0.5)
	var hx: float = r.position.x + 0.5 if hinge_left else r.end.x - 0.5
	for f in [0.12, 0.88]:
		L(ci, Vector2(hx, r.position.y + r.size.y * f - 2.0), Vector2(hx, r.position.y + r.size.y * f + 2.0), al + 0.1, 2.0)
	var gx: float = r.end.x - r.size.x * 0.16 if hinge_left else r.position.x + r.size.x * 0.16
	var gl: float = clampf(r.size.y * 0.12, 3.0, 12.0)
	L(ci, Vector2(gx, r.get_center().y - gl * 0.5), Vector2(gx, r.get_center().y + gl * 0.5), al + 0.15, 1.6)


# ------------------------------------------------------------------ dispatch

# true if it drew the art
static func draw(ci: CanvasItem, art: String, w: float, h: float, p, font: Font) -> bool:
	if p != null:
		var alt: String = ""
		if ext != null and ext.BY_NAME.has(p.name_key):
			alt = ext.BY_NAME[p.name_key]
		elif BY_NAME.has(p.name_key):
			alt = BY_NAME[p.name_key]
		if alt != "" and alt != art and _has(alt):
			art = alt
	if not _has(art):
		return false
	var key := "%s|%d|%d|%s|%s|%d" % [art, roundi(w * 2.0), roundi(h * 2.0), p.name_key if p != null else "", p.tag if p != null else "", 1 if p != null and p.fragile >= 0.85 else 0]
	var rec = _cache.get(key)
	if rec == null:
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		rec = _record(ci, art, Rect2(0, 0, w, h), p, font)
		_cache[key] = rec
	_replay(ci, rec)
	return true


static func _draw_art(ci: CanvasItem, art: String, r: Rect2, p, font: Font) -> void:
	match art:
		"pump": pump(ci, r)
		"cabinet": cabinet(ci, r, p, font)
		"swb": swb(ci, r)
		"battery": battery(ci, r, p, font)
		"gen": gen(ci, r, p, font)
		"env": env(ci, r)
		"filter": filter(ci, r)
		"trap": trap(ci, r)
		"locker": locker(ci, r)
		"console": console(ci, r)
		"nav_rack": nav_rack(ci, r)
		"module": module(ci, r, p, font)
		"aux": aux(ci, r)
		"panel": panel(ci, r, p, font)
		"junction": junction(ci, r)
		"insp": insp(ci, r)
		"sensor": sensor(ci, r)
		"overhead": overhead(ci, r)
		"growlamp": growlamp(ci, r)
		"tray": tray(ci, r)
		"pipe": pipe(ci, r)
		"cargo": cargo(ci, r, p, font)
		"crate": crate(ci, r, p, font)
		"container": container(ci, r, p, font)
		"gastank": gastank(ci, r)
		"extinguisher": extinguisher(ci, r)
		"water": water(ci, r, p, font)
		"fueltank": fueltank(ci, r, p, font)
		"cap": cap(ci, r)
		"screen": screen(ci, r)
		"nav": nav(ci, r)
		"o2cab": o2cab(ci, r, p, font)
		"bunk": bunk(ci, r)
		"blackbox": blackbox(ci, r)
		"table": table(ci, r)
		"shelf": shelf(ci, r)
		"desk": desk(ci, r)
		"toolwall": toolwall(ci, r)
		"fridge": fridge(ci, r)
		"medcab": medcab(ci, r)
		"galley": galley(ci, r)
		"bench": bench(ci, r)
		"radiator": radiator(ci, r)
		"hx": hx(ci, r)
		"duct_fan": duct_fan(ci, r)
		"chiller": chiller(ci, r)
		"transformer": transformer(ci, r)
		"inverter": inverter(ci, r)
		"fuelcell": fuelcell(ci, r)
		"hpu": hpu(ci, r)
		"manifold": manifold(ci, r)
		"charger": charger(ci, r)
		"actuator": actuator(ci, r)
		"relief": relief(ci, r)
		"stator": stator(ci, r)
		"gauge_box": gauge_box(ci, r)
		"beacon": beacon(ci, r)
		"lamp": lamp(ci, r)
		"eng_core": eng_core(ci, r)
		"nozzle": nozzle(ci, r)
		"reel": reel(ci, r)
		"drum": drum(ci, r)
		"hook": hook(ci, r)
		"sphere_tank": sphere_tank(ci, r, p, font)
		"rcs_quad": rcs_quad(ci, r)
		"radar": radar(ci, r)
		"eng_front": eng_front(ci, r)
		"engine_s": engine_s(ci, r)
		"brake": brake(ci, r)
		"arm": arm(ci, r)
		"dock": dock(ci, r)
		"freezer": freezer(ci, r, p, font)
		"barrel": barrel(ci, r)
		"turret": turret(ci, r)
		"launcher": launcher(ci, r)
		"ciws": ciws(ci, r)
		"gun_mount": gun_mount(ci, r)
		"decoy": decoy(ci, r)
		_:
			if ext != null:
				ext._draw_art(ci, art, r, p, font)


const DRAWN := ["pump", "cabinet", "swb", "battery", "gen", "env", "filter", "trap", "locker", "console", "nav_rack", "module", "aux", "panel", "junction", "insp", "sensor", "overhead", "growlamp", "tray", "pipe", "cargo", "crate", "container", "gastank", "extinguisher", "water", "fueltank", "cap", "screen", "nav", "o2cab", "bunk", "blackbox", "table", "shelf", "desk", "toolwall", "fridge", "medcab", "galley", "bench", "radiator", "hx", "duct_fan", "chiller", "transformer", "inverter", "fuelcell", "hpu", "manifold", "charger", "actuator", "relief", "stator", "gauge_box", "beacon", "lamp", "eng_core", "nozzle", "reel", "drum", "hook", "sphere_tank", "rcs_quad", "radar", "eng_front", "engine_s", "brake", "arm", "dock", "freezer", "barrel", "turret", "launcher", "ciws", "gun_mount", "decoy"]


static func _has(art: String) -> bool:
	return art in DRAWN or (ext != null and art in ext.DRAWN)


# ------------------------------------------------------------------ pump

# a centrifugal pump set: end-suction volute, bearing frame, coupling under its
# guard, motor, all on one baseplate; a long skid carries several; a tall one is a
# vertical inline pump (motor on top, lantern, casing with its flanges in line)
static func pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL:
		var c := Vector2(w * 0.32, h * 0.52)
		var rad: float = minf(w, h) * 0.3
		O(ci, c, rad, 0.55)
		impeller(ci, c, rad * 0.7, 0.4)
		R(ci, Rect2(w * 0.62, h * 0.3, w * 0.3, h * 0.44), 0.45)
		L(ci, Vector2(c.x + rad, c.y), Vector2(w * 0.62, c.y), 0.4)
		return
	if h > w * 1.3:
		_pump_inline(ci, r)
		return
	var n := clampi(int(w / (h * 2.4)), 1, 4)
	var sw: float = w / n
	for i in n:
		_pump_set(ci, Rect2(sw * i, 0, sw, h))
	if n > 1:
		# the common discharge header the sets feed
		L(ci, Vector2(sw * 0.2, h * 0.07), Vector2(w - sw * 0.5, h * 0.07), 0.45, 1.6)


static func _pump_set(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var x0 := r.position.x
	var base := Rect2(x0 + w * 0.03, h * 0.88, w * 0.94, h * 0.07)
	R(ci, base, 0.45)
	if w > 80.0:
		bolts(ci, base.position + Vector2(0, base.size.y * 0.5), Vector2(base.end.x, base.position.y + base.size.y * 0.5), clampi(int(w / 40.0), 2, 8), 0.4)
	var rad: float = minf(h * 0.3, w * 0.15)
	var c := Vector2(x0 + w * 0.06 + rad * 1.25, h * 0.52)
	volute(ci, c, rad, true, 0.6)
	# the suction nozzle, end-on: its flange ring out the front
	O(ci, c, rad * 0.32, 0.45)
	# the casing foot
	L(ci, Vector2(c.x - rad * 0.5, c.y + rad * 0.9), Vector2(c.x - rad * 0.6, base.position.y), 0.45)
	L(ci, Vector2(c.x + rad * 0.5, c.y + rad * 0.9), Vector2(c.x + rad * 0.6, base.position.y), 0.45)
	# bearing frame with its oil sight glass
	var bf := Rect2(c.x + rad * 0.98, c.y - rad * 0.32, rad * 1.1, rad * 0.64)
	R(ci, bf, 0.5)
	D(ci, bf.get_center() + Vector2(0, rad * 0.12), 1.4, 0.5)
	L(ci, Vector2(bf.position.x + bf.size.x * 0.3, bf.end.y), Vector2(bf.position.x + bf.size.x * 0.2, base.position.y), 0.4)
	# coupling guard, meshed
	var cg := Rect2(bf.end.x, c.y - rad * 0.42, rad * 0.75, rad * 0.84)
	R(ci, cg, 0.4)
	var segs := PackedVector2Array()
	var k := 0.0
	while k < cg.size.x + cg.size.y:
		segs.append(cg.position + Vector2(minf(k, cg.size.x), maxf(0.0, k - cg.size.x)))
		segs.append(cg.position + Vector2(maxf(0.0, k - cg.size.y), minf(k, cg.size.y)))
		k += 4.0
	S(ci, segs, 0.15)
	L(ci, Vector2(bf.end.x - 2.0, c.y), Vector2(cg.end.x + 2.0, c.y), 0.55, 1.6)
	# motor to the end of the skid
	var mx0: float = cg.end.x
	var mx1: float = x0 + w * 0.96
	var mh: float = minf(rad * 1.7, h * 0.62)
	if mx1 - mx0 > mh * 2.6:
		mx1 = mx0 + mh * 2.6
	motor(ci, Rect2(mx0, c.y - mh * 0.5, mx1 - mx0, mh * 0.5 + (base.position.y - c.y)), true, 0.5)


static func _pump_inline(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	# motor standing on top, fins down its length
	var mw: float = w * 0.62
	var mot := Rect2(cx - mw * 0.5, h * 0.1, mw, h * 0.36)
	R(ci, mot, 0.5)
	hatch(ci, inset(mot, 3.0), maxf(3.2, mw / 8.0), true, 0.18, 20)
	P(ci, PackedVector2Array([Vector2(mot.position.x + 1, mot.position.y), Vector2(cx - mw * 0.36, h * 0.03), Vector2(cx + mw * 0.36, h * 0.03), Vector2(mot.end.x - 1, mot.position.y)]), 0.45)
	R(ci, Rect2(mot.end.x, mot.position.y + mot.size.y * 0.3, w * 0.12, mot.size.y * 0.25), 0.45)
	# lantern with its window onto the coupling
	var ln := Rect2(cx - mw * 0.32, mot.end.y, mw * 0.64, h * 0.16)
	P(ci, PackedVector2Array([ln.position, Vector2(ln.position.x + ln.size.x * 0.15, ln.end.y), Vector2(ln.end.x - ln.size.x * 0.15, ln.end.y), Vector2(ln.end.x, ln.position.y)]), 0.45)
	R(ci, Rect2(cx - mw * 0.12, ln.position.y + ln.size.y * 0.2, mw * 0.24, ln.size.y * 0.55), 0.35)
	L(ci, Vector2(cx, ln.position.y), Vector2(cx, ln.end.y + h * 0.04), 0.55, 1.4)
	# casing: the volute seen side-on, its in-line nozzles and flanges
	var cs := Rect2(w * 0.12, ln.end.y, w * 0.76, h * 0.26)
	P(ci, PackedVector2Array([Vector2(cx - mw * 0.36, cs.position.y), Vector2(cs.position.x + cs.size.x * 0.08, cs.position.y + cs.size.y * 0.35), Vector2(cs.position.x + cs.size.x * 0.08, cs.end.y - cs.size.y * 0.2), Vector2(cx, cs.end.y), Vector2(cs.end.x - cs.size.x * 0.08, cs.end.y - cs.size.y * 0.2), Vector2(cs.end.x - cs.size.x * 0.08, cs.position.y + cs.size.y * 0.35), Vector2(cx + mw * 0.36, cs.position.y)]), 0.55, 1.2)
	impeller(ci, cs.get_center(), minf(cs.size.y * 0.32, cs.size.x * 0.2), 0.4)
	var ny: float = cs.get_center().y + cs.size.y * 0.1
	var nh: float = cs.size.y * 0.22
	for sgn in [-1.0, 1.0]:
		var xa: float = cx + sgn * cs.size.x * 0.42
		L(ci, Vector2(xa, ny - nh), Vector2(cx + sgn * w * 0.5 - sgn * 3.0, ny - nh), 0.45)
		L(ci, Vector2(xa, ny + nh), Vector2(cx + sgn * w * 0.5 - sgn * 3.0, ny + nh), 0.45)
		flange(ci, Vector2(cx + sgn * w * 0.5 - sgn * 3.0, ny), Vector2(sgn, 0), nh + 2.0, 0.55)
	# foot ring and anchor bolts
	L(ci, Vector2(w * 0.22, h * 0.95), Vector2(w * 0.78, h * 0.95), 0.5, 1.6)
	L(ci, Vector2(cx - w * 0.18, cs.end.y), Vector2(w * 0.26, h * 0.95), 0.4)
	L(ci, Vector2(cx + w * 0.18, cs.end.y), Vector2(w * 0.74, h * 0.95), 0.4)


# ------------------------------------------------------------------ cabinet

# a steel service cabinet: plinth, top rail, a door per bay (hinges, inset panel,
# handle, vent louvres, card holder); a low wide one is a bank of drawers
static func cabinet(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL:
		L(ci, Vector2(w * 0.5, 3), Vector2(w * 0.5, h - 3), 0.4)
		L(ci, Vector2(w * 0.4, h * 0.45), Vector2(w * 0.4, h * 0.6), 0.6, 1.4)
		L(ci, Vector2(w * 0.6, h * 0.45), Vector2(w * 0.6, h * 0.6), 0.6, 1.4)
		return
	var pl: float = clampf(h * 0.06, 2.5, 8.0)
	L(ci, Vector2(2, h - pl), Vector2(w - 2, h - pl), 0.45)
	hatch(ci, Rect2(4, h - pl + 1.0, w - 8, pl - 2.0), 6.0, true, 0.15, 40)
	L(ci, Vector2(1, pl * 0.7), Vector2(w - 1, pl * 0.7), 0.4)
	var body := Rect2(3, pl * 0.7 + 2.0, w - 6, h - pl - pl * 0.7 - 4.0)
	if h < 0.95 * M and w > h * 1.5:
		_drawers(ci, body)
		return
	# bays of double doors about a metre wide, a vent panel across the top of each
	var n := clampi(roundi(body.size.x / (1.0 * M)), 1, 30)
	var bw: float = body.size.x / n
	for i in n:
		var bay := Rect2(body.position.x + i * bw + 1.0, body.position.y, bw - 2.0, body.size.y)
		var vh: float = bay.size.y * 0.14 if bay.size.y > 50.0 else 0.0
		if vh > 0.0:
			R(ci, Rect2(bay.position, Vector2(bay.size.x, vh)), 0.35)
			louvres(ci, inset(Rect2(bay.position, Vector2(bay.size.x, vh)), 3.0), 0.25)
		var d := Rect2(bay.position.x, bay.position.y + vh, bay.size.x, bay.size.y - vh)
		if d.size.x > 0.6 * M:
			door_leaf(ci, Rect2(d.position, Vector2(d.size.x * 0.5, d.size.y)), true, 0.42)
			door_leaf(ci, Rect2(d.position + Vector2(d.size.x * 0.5, 0), Vector2(d.size.x * 0.5, d.size.y)), false, 0.42)
		else:
			door_leaf(ci, d, i % 2 == 0, 0.42)
		if d.size.y > 40.0:
			R(ci, Rect2(d.get_center().x - minf(8.0, d.size.x * 0.2), d.position.y + d.size.y * 0.08, minf(16.0, d.size.x * 0.4), minf(6.0, d.size.y * 0.06)), 0.3)
	if w > 1.8 * M and h > 1.2 * M:
		plate(ci, Rect2(w * 0.5 - 22.0, 1.0, 44.0, maxf(5.0, pl * 0.7)), tag_of(p), font, 0.4)


static func _drawers(ci: CanvasItem, body: Rect2) -> void:
	var rows := clampi(int(body.size.y / 12.0), 1, 4)
	var cols := clampi(roundi(body.size.x / (0.8 * M)), 1, 30)
	var dw: float = body.size.x / cols
	var dh: float = body.size.y / rows
	for i in cols:
		for k in rows:
			var d := Rect2(body.position.x + i * dw + 1.0, body.position.y + k * dh + 1.0, dw - 2.0, dh - 2.0)
			R(ci, d, 0.4)
			var c := d.get_center()
			L(ci, Vector2(c.x - minf(8.0, dw * 0.2), c.y + dh * 0.12), Vector2(c.x + minf(8.0, dw * 0.2), c.y + dh * 0.12), 0.55, 1.6)
			if dh > 10.0 and dw > 24.0:
				R(ci, Rect2(c.x - 5.0, d.position.y + 2.0, 10.0, minf(4.0, dh * 0.25)), 0.3)


# ------------------------------------------------------------------ switchboard

# a switchboard front: the busbar chamber across the top (three phases), and per
# section its meter panel (dials, pilot lamps), a stack of moulded-case breakers,
# and the gland plate the cables come up through
static func swb(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL * 0.8:
		var n0 := clampi(int(h / 8.0), 2, 6)
		for i in n0:
			breaker(ci, Rect2(w * 0.2, h * (0.08 + i * 0.86 / n0), w * 0.6, h * 0.86 / n0 - 2.0), i != 1, 0.4)
		return
	var bus_h: float = clampf(h * 0.11, 5.0, 18.0)
	var bus := Rect2(2, 2, w - 4, bus_h)
	R(ci, bus, 0.4)
	var segs := PackedVector2Array()
	for k in 3:
		var y: float = bus.position.y + bus_h * (0.25 + k * 0.25)
		segs.append(Vector2(bus.position.x + 3.0, y))
		segs.append(Vector2(bus.end.x - 3.0, y))
	S(ci, segs, 0.5)
	var sec_w: float = clampf(0.6 * M, 18.0, 40.0)
	var n := clampi(roundi((w - 4) / sec_w), 1, 24)
	var sw: float = (w - 4) / n
	var top: float = bus.end.y + 2.0
	var gl_h: float = clampf(h * 0.08, 4.0, 12.0)
	for i in n:
		var s := Rect2(2 + i * sw, top, sw, h - top - 2.0)
		R(ci, s, 0.35)
		# the busbar drops into this section
		D(ci, Vector2(s.get_center().x, bus.end.y - bus_h * 0.25), 1.0, 0.5)
		var y: float = s.position.y + 3.0
		var meter_h: float = s.size.y * 0.24 if s.size.y > 70.0 else 0.0
		if meter_h > 0.0 and (i % 2 == 0 or n == 1):
			var mr: float = minf(meter_h * 0.3, sw * 0.22)
			gauge(ci, Vector2(s.position.x + sw * 0.3, y + meter_h * 0.42), mr, 0.5)
			gauge(ci, Vector2(s.position.x + sw * 0.7, y + meter_h * 0.42), mr, 0.5)
			for k in 3:
				D(ci, Vector2(s.position.x + sw * (0.3 + k * 0.2), y + meter_h * 0.85), 1.3, 0.55)
			y += meter_h
			L(ci, Vector2(s.position.x + 2, y), Vector2(s.end.x - 2, y), 0.3)
		elif meter_h > 0.0:
			# a bus-coupler / incomer: one big air breaker
			var acb := Rect2(s.position.x + sw * 0.15, y + 2.0, sw * 0.7, meter_h - 4.0)
			R(ci, acb, 0.45)
			R(ci, sub(acb, 0.3, 0.2, 0.7, 0.45), 0.4)
			D(ci, acb.position + acb.size * Vector2(0.5, 0.72), 1.6, 0.5)
			y += meter_h
			L(ci, Vector2(s.position.x + 2, y), Vector2(s.end.x - 2, y), 0.3)
		var avail: float = s.end.y - gl_h - y - 2.0
		var bh: float = clampf(avail / 6.0, 6.0, 14.0)
		var nb := clampi(int(avail / bh), 1, 14)
		for k in nb:
			breaker(ci, Rect2(s.position.x + sw * 0.14, y + k * bh + 1.0, sw * 0.72, bh - 2.0), (k + i) % 5 != 3, 0.42)
		# gland plate and the cables
		var gy: float = s.end.y - gl_h
		L(ci, Vector2(s.position.x + 1, gy), Vector2(s.end.x - 1, gy), 0.35)
		var ng := clampi(int(sw / 8.0), 1, 4)
		for k in ng:
			var gx: float = s.position.x + (k + 0.5) * sw / ng
			O(ci, Vector2(gx, gy + gl_h * 0.45), minf(2.2, gl_h * 0.3), 0.4)
			L(ci, Vector2(gx, gy + gl_h * 0.45 + 2.0), Vector2(gx, s.end.y), 0.3)


# ------------------------------------------------------------------ battery

# a battery pack: modules along its length, each a row (or two) of cells with the
# series busbars across their terminals, the inter-module links, a cooling plate
# under the cells, and at one end the BMS board and the main contactor
static func battery(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w * 1.2
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	if th < SMALL * 0.7:
		var nc := clampi(int(ln / 7.0), 2, 30)
		for i in nc:
			var a: float = 2.0 + i * (ln - 4.0) / nc
			var b: float = a + (ln - 4.0) / nc - 2.0
			R(ci, Rect2(X.call(a, th * 0.2), X.call(b, th * 0.85) - X.call(a, th * 0.2)).abs(), 0.35)
		return
	# the pack end: BMS board and the contactor box
	var end_l: float = clampf(ln * 0.14, 10.0, 0.7 * M)
	var bms := Rect2(X.call(ln - end_l, th * 0.12), X.call(end_l - 3.0, th * 0.4) - X.call(0, 0)).abs()
	if vert:
		bms = Rect2(Vector2(th * 0.12, ln - end_l), Vector2(th * 0.4, end_l - 3.0))
	R(ci, bms, 0.5)
	for k in 3:
		var cq: Vector2 = bms.position + bms.size * Vector2(0.2 + k * 0.28, 0.5)
		R(ci, Rect2(cq - Vector2(2, 2), Vector2(4, 4)), 0.45)
	var ctr := Rect2(Vector2(th * 0.58, ln - end_l), Vector2(th * 0.32, end_l - 3.0)) if vert else Rect2(Vector2(ln - end_l, th * 0.58), Vector2(end_l - 3.0, th * 0.32))
	R(ci, ctr, 0.5)
	L(ci, ctr.position + ctr.size * 0.2, ctr.position + ctr.size * 0.8, 0.45)
	# modules
	var mod_l: float = clampf(0.8 * M, 24.0, 60.0)
	var nm := clampi(int((ln - end_l) / mod_l), 1, 16)
	var ml: float = (ln - end_l) / nm
	var rows := 2 if th > 1.4 * M else 1
	var cell_p: float = clampf(th * 0.12, 4.5, 8.0)
	var harness := PackedVector2Array()
	for i in nm:
		var a: float = i * ml + 2.0
		var b: float = a + ml - 4.0
		var box := Rect2(X.call(a, th * 0.1), X.call(b, th * 0.92) - X.call(a, th * 0.1)).abs()
		R(ci, box, 0.45)
		# cooling plate along the bottom
		L(ci, X.call(a + 2.0, th * 0.86), X.call(b - 2.0, th * 0.86), 0.3)
		var nc := clampi(int((b - a - 4.0) / cell_p), 2, 24)
		var cp: float = (b - a - 4.0) / nc
		var bars := PackedVector2Array()
		var cells := PackedVector2Array()
		for rw in rows:
			var v0: float = th * (0.22 + rw * 0.33)
			var v1: float = v0 + th * (0.6 / rows) - 2.0
			for k in nc:
				var u: float = a + 2.0 + k * cp + 0.6
				var u1: float = u + cp - 1.2
				for e in [[u, v0, u, v1], [u1, v0, u1, v1], [u, v1, u1, v1]]:
					cells.append(X.call(e[0], e[1]))
					cells.append(X.call(e[2], e[3]))
				# the terminal nub
				cells.append(X.call(u + cp * 0.3, v0 - 1.0))
				cells.append(X.call(u1 - cp * 0.3, v0 - 1.0))
				if k % 2 == 0 and k + 1 < nc:
					bars.append(X.call(u + cp * 0.5, v0 - 1.5))
					bars.append(X.call(u + cp * 1.5, v0 - 1.5))
		S(ci, cells, 0.3)
		S(ci, bars, 0.55, 1.8)
		# module terminals and the link to the next
		D(ci, X.call(a + 3.0, th * 0.15), 1.4, 0.55)
		D(ci, X.call(b - 3.0, th * 0.15), 1.4, 0.55)
		L(ci, X.call(b - 3.0, th * 0.15), X.call(b + 7.0, th * 0.15), 0.55, 1.8)
		harness.append(X.call(a + ml * 0.5, th * 0.1))
		harness.append(X.call(a + ml * 0.5, th * 0.04))
	S(ci, harness, 0.3)
	L(ci, X.call(ml * 0.5, th * 0.04), X.call(ln - end_l * 0.5, th * 0.04), 0.3)
	if th > 1.0 * M and ln > 2.0 * M and not vert:
		plate(ci, Rect2(ln - end_l, th * 0.76, end_l - 4.0, minf(10.0, th * 0.12)), tag_of(p), font, 0.4)


# ------------------------------------------------------------------ generator

# a generating set: radiator and fan, the engine block (its heads, exhaust
# manifold, turbo), the alternator cut across (finned frame, stator slots with
# their windings, the salient-pole rotor), exciter, terminal box and the control
# panel, on a base frame with its anti-vibration mounts. Square or tall: the
# alternator section alone with its exciter, terminal box and panel.
static func gen(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h - clampf(h * 0.09, 3.0, 10.0)
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.5, 1.4)
	if minf(w, h) < SMALL:
		var c0 := Vector2(w * 0.35, h * 0.48)
		O(ci, c0, minf(w, h) * 0.3, 0.5)
		O(ci, c0, minf(w, h) * 0.17, 0.4)
		R(ci, Rect2(w * 0.68, h * 0.25, w * 0.24, h * 0.5), 0.45)
		return
	# anti-vibration mounts
	var segs := PackedVector2Array()
	for i in clampi(int(w / 30.0), 2, 10):
		var x: float = w * (0.08 + 0.84 * i / maxf(1.0, float(clampi(int(w / 30.0), 2, 10) - 1)))
		segs.append(Vector2(x - 2.5, base_y + 2.0))
		segs.append(Vector2(x + 2.5, base_y + 4.0))
		segs.append(Vector2(x + 2.5, base_y + 4.0))
		segs.append(Vector2(x - 2.5, base_y + 6.0))
	S(ci, segs, 0.35)
	var wide: bool = w > h * 1.8
	var ar: float = minf(h * 0.36, w * (0.16 if wide else 0.3))
	var ac := Vector2(w * (0.62 if wide else 0.36), base_y - ar - h * 0.06)
	_alternator(ci, ac, ar)
	# exciter and the terminal box on top
	var ex := Rect2(ac.x + ar * 1.08, ac.y - ar * 0.35, ar * 0.45, ar * 0.7)
	R(ci, ex, 0.45)
	hatch(ci, inset(ex, 2.0), 3.5, true, 0.18, 8)
	var tb := Rect2(ac.x - ar * 0.4, ac.y - ar * 1.32, ar * 0.8, ar * 0.3)
	R(ci, tb, 0.5)
	for k in 3:
		D(ci, tb.position + Vector2(tb.size.x * (0.25 + k * 0.25), tb.size.y * 0.5), 1.1, 0.55)
	# the control panel at the end
	var cp_x: float = ex.end.x + 4.0
	var cp := Rect2(cp_x, h * 0.12, maxf(8.0, w - cp_x - 4.0), base_y - h * 0.14)
	if cp.size.x > 10.0:
		R(ci, cp, 0.45)
		var nr := clampi(int(cp.size.x / 14.0), 1, 3)
		for k in nr:
			gauge(ci, Vector2(cp.position.x + (k + 0.5) * cp.size.x / nr, cp.position.y + cp.size.y * 0.18), minf(cp.size.x / nr * 0.32, 6.0), 0.5)
		screen_face(ci, sub(cp, 0.15, 0.32, 0.85, 0.5), 0, 0.35)
		for k in 3:
			D(ci, cp.position + cp.size * Vector2(0.25 + k * 0.25, 0.62), 1.3, 0.55)
		breaker(ci, sub(cp, 0.3, 0.7, 0.7, 0.88), true, 0.45)
	if wide:
		_engine(ci, Rect2(w * 0.04, h * 0.14, ac.x - ar * 1.1 - w * 0.04, base_y - h * 0.16))
	if w > 2.2 * M and h > 1.2 * M:
		plate(ci, Rect2(cp.position.x if cp.size.x > 30.0 else 4.0, base_y - 12.0, minf(52.0, maxf(30.0, cp.size.x - 2.0)), 9.0), tag_of(p), font, 0.4)


static func _alternator(ci: CanvasItem, c: Vector2, ar: float) -> void:
	O(ci, c, ar, 0.6, 1.2)
	var segs := PackedVector2Array()
	var nf := clampi(int(ar * TAU / 5.0), 12, 48)
	for i in nf:
		var a: float = TAU * i / nf
		segs.append(c + Vector2.from_angle(a) * ar)
		segs.append(c + Vector2.from_angle(a) * ar * 1.08)
	S(ci, segs, 0.35)
	O(ci, c, ar * 0.84, 0.4)
	O(ci, c, ar * 0.6, 0.45)
	# the stator slots and their coil sides
	var ns := clampi(int(ar * TAU * 0.6 / 4.0), 12, 36)
	segs = PackedVector2Array()
	for i in ns:
		var a: float = TAU * i / ns
		segs.append(c + Vector2.from_angle(a) * ar * 0.6)
		segs.append(c + Vector2.from_angle(a) * ar * 0.78)
	S(ci, segs, 0.3)
	if ar > 18.0:
		for i in ns:
			D(ci, c + Vector2.from_angle(TAU * (i + 0.5) / ns) * ar * 0.68, 0.9, 0.4)
	# rotor: four salient poles with their field coils
	for i in 4:
		var a: float = PI * 0.25 + i * PI * 0.5
		var d := Vector2.from_angle(a)
		var t := d.orthogonal()
		var p0: Vector2 = c + d * ar * 0.18
		var p1: Vector2 = c + d * ar * 0.52
		P(ci, PackedVector2Array([p0 - t * ar * 0.1, p1 - t * ar * 0.1, p1 - t * ar * 0.2 + d * ar * 0.03, p1 + t * ar * 0.2 + d * ar * 0.03, p1 + t * ar * 0.1, p0 + t * ar * 0.1]), 0.45)
		if ar > 14.0:
			L(ci, c + d * ar * 0.24 - t * ar * 0.16, c + d * ar * 0.44 - t * ar * 0.16, 0.3)
			L(ci, c + d * ar * 0.24 + t * ar * 0.16, c + d * ar * 0.44 + t * ar * 0.16, 0.3)
	O(ci, c, ar * 0.1, 0.55)


# an engine block side-on: the cooling radiator and fan at the front, the block
# with its row of heads and rocker covers, the exhaust manifold to a turbocharger
static func _engine(ci: CanvasItem, r: Rect2) -> void:
	if r.size.x < 16.0:
		return
	var rad_w: float = minf(r.size.x * 0.18, r.size.y * 0.35)
	var rd := Rect2(r.position.x, r.position.y, rad_w, r.size.y)
	R(ci, rd, 0.45)
	hatch(ci, inset(rd, 2.0), 3.0, false, 0.2, 40)
	fan(ci, Vector2(rd.end.x + rad_w * 0.35, rd.get_center().y), minf(rad_w * 0.3, r.size.y * 0.25), 5, 0.4)
	var blk := Rect2(rd.end.x + rad_w * 0.8, r.position.y + r.size.y * 0.3, r.end.x - rd.end.x - rad_w * 0.8, r.size.y * 0.62)
	R(ci, blk, 0.5)
	var nc := clampi(int(blk.size.x / 16.0), 2, 8)
	var cw: float = blk.size.x / nc
	for i in nc:
		var hd := Rect2(blk.position.x + i * cw + 1.0, r.position.y + r.size.y * 0.12, cw - 2.0, r.size.y * 0.18)
		R(ci, hd, 0.45)
		D(ci, hd.get_center(), 1.0, 0.5)
		L(ci, Vector2(hd.get_center().x, hd.end.y), Vector2(hd.get_center().x, blk.position.y), 0.3)
	# exhaust manifold along the side to the turbo
	L(ci, Vector2(blk.position.x + 2.0, blk.position.y + blk.size.y * 0.2), Vector2(blk.end.x - 6.0, blk.position.y + blk.size.y * 0.2), 0.45, 1.4)
	var tc := Vector2(blk.end.x - blk.size.x * 0.1, blk.position.y - r.size.y * 0.02)
	O(ci, tc, minf(blk.size.y * 0.18, 7.0), 0.5)
	# the sump and crankcase line
	L(ci, Vector2(blk.position.x, blk.position.y + blk.size.y * 0.62), Vector2(blk.end.x, blk.position.y + blk.size.y * 0.62), 0.3)
	P(ci, PackedVector2Array([Vector2(blk.position.x + blk.size.x * 0.1, blk.end.y), Vector2(blk.position.x + blk.size.x * 0.15, blk.end.y + r.size.y * 0.06), Vector2(blk.end.x - blk.size.x * 0.15, blk.end.y + r.size.y * 0.06), Vector2(blk.end.x - blk.size.x * 0.1, blk.end.y)]), 0.4)


# ------------------------------------------------------------------ air handling

# an air handling unit along its airflow: intake damper, pleated filter, cooling
# coil over its drain pan, the centrifugal fan in its scroll with the motor and
# belt, the discharge plenum with its dampers. Tall: the same, rising.
static func env(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL:
		fan(ci, Vector2(w * 0.32, h * 0.5), minf(w, h) * 0.3, 5, 0.5)
		hatch(ci, Rect2(w * 0.62, h * 0.2, w * 0.3, h * 0.6), 3.0, true, 0.3, 10)
		return
	var vert: bool = h > w * 1.3
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, ln - u) if vert else Vector2(u, v)
	var B := func(u0: float, v0: float, u1: float, v1: float) -> Rect2: return Rect2(X.call(u0, v0), X.call(u1, v1) - X.call(u0, v0)).abs()
	var fan_l: float = minf(th * 0.9, ln * 0.4)
	var rest: float = ln - fan_l
	var cuts := [0.0, rest * 0.12, rest * 0.3, rest * 0.62, rest * 0.62 + fan_l, ln]
	for k in range(1, cuts.size() - 1):
		var u: float = cuts[k]
		L(ci, X.call(u, 2.0), X.call(u, th - 2.0), 0.4)
	# intake damper blades
	var segs := PackedVector2Array()
	var nb := clampi(int(th * 0.8 / 6.0), 2, 14)
	for k in nb:
		var v: float = th * 0.1 + (k + 0.5) * th * 0.8 / nb
		segs.append(X.call(cuts[0] + 3.0, v - 2.0))
		segs.append(X.call(cuts[1] - 3.0, v + 2.0))
	S(ci, segs, 0.35)
	# filter: pleats across the airflow
	var fl: Rect2 = B.call(cuts[1] + 3.0, th * 0.08, cuts[2] - 3.0, th * 0.92)
	pleats(ci, fl, 4.0, vert, 0.35)
	# cooling coil: tube passes, fins, the drain pan under it
	var cl: Rect2 = B.call(cuts[2] + 3.0, th * 0.08, cuts[3] - 3.0, th * 0.78)
	R(ci, cl, 0.4)
	hatch(ci, inset(cl, 1.5), 3.0, not vert, 0.15, 60)
	var npass := clampi(int(th * 0.7 / 7.0), 2, 12)
	for k in npass:
		var v: float = th * 0.1 + (k + 0.5) * th * 0.66 / npass
		var a: float = cuts[2] + 3.0 + (cuts[3] - cuts[2]) * 0.1
		var b: float = cuts[3] - 3.0 - (cuts[3] - cuts[2]) * 0.1
		D(ci, X.call(a, v), 1.2, 0.5)
		D(ci, X.call(b, v), 1.2, 0.5)
	P(ci, PackedVector2Array([X.call(cuts[2] + 2.0, th * 0.82), X.call(cuts[2] + 4.0, th * 0.9), X.call(cuts[3] - 4.0, th * 0.9), X.call(cuts[3] - 2.0, th * 0.82)]), 0.45)
	L(ci, X.call((cuts[2] + cuts[3]) * 0.5, th * 0.9), X.call((cuts[2] + cuts[3]) * 0.5, th - 1.0), 0.4)
	# the fan: wheel in its scroll, motor below on a belt
	var fc: Vector2 = X.call(cuts[3] + fan_l * 0.48, th * 0.42)
	var fr: float = minf(fan_l * 0.34, th * 0.3)
	var sc := PackedVector2Array()
	for k in 17:
		var t: float = k / 16.0
		sc.append(fc + Vector2.from_angle(-PI * 0.5 + t * TAU * 0.82) * fr * (1.05 + 0.3 * t))
	P(ci, sc, 0.5)
	fan(ci, fc, fr * 0.85, 8, 0.4)
	var mc: Vector2 = X.call(cuts[3] + fan_l * 0.75, th * 0.84)
	O(ci, mc, minf(fr * 0.32, 8.0), 0.5)
	L(ci, fc + (mc - fc).normalized().orthogonal() * fr * 0.2, mc + (mc - fc).normalized().orthogonal() * minf(fr * 0.32, 8.0), 0.3)
	L(ci, fc - (mc - fc).normalized().orthogonal() * fr * 0.2, mc - (mc - fc).normalized().orthogonal() * minf(fr * 0.32, 8.0), 0.3)
	# discharge plenum: opposed-blade dampers
	segs = PackedVector2Array()
	for k in nb:
		var v: float = th * 0.15 + (k + 0.5) * th * 0.7 / nb
		var u: float = (cuts[4] + cuts[5]) * 0.5
		var hw: float = minf((cuts[5] - cuts[4]) * 0.3, 6.0)
		var sgn: float = 1.0 if k % 2 == 0 else -1.0
		segs.append(X.call(u - hw, v - sgn * 1.5))
		segs.append(X.call(u + hw, v + sgn * 1.5))
	S(ci, segs, 0.35)


# ------------------------------------------------------------------ filters

# a cartridge filter housing: the vessel cut away to show its pleated element, the
# nozzles in and out, the differential pressure gauge, the drain valve and legs;
# a wide one is a bank of housings on common headers
static func filter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL * 0.8:
		R(ci, inset(r, 2.0), 0.4)
		pleats(ci, inset(r, 4.0), 3.0, w >= h, 0.35)
		return
	if w > h * 1.4:
		var n := clampi(roundi(w / (h * 0.75)), 2, 10)
		var hw: float = w / n
		L(ci, Vector2(hw * 0.3, h * 0.14), Vector2(w - hw * 0.3, h * 0.14), 0.5, 1.6)
		L(ci, Vector2(hw * 0.7, h * 0.86), Vector2(w - hw * 0.7, h * 0.86), 0.5, 1.6)
		for i in n:
			_filter_one(ci, Rect2(i * hw + hw * 0.15, h * 0.04, hw * 0.7, h * 0.9), i)
		return
	_filter_one(ci, Rect2(w * 0.18, h * 0.03, w * 0.56, h * 0.9), 0)
	# the gauge on its bracket
	var gc := Vector2(w * 0.86, h * 0.25)
	gauge(ci, gc, minf(w * 0.1, 7.0), 0.55)
	L(ci, Vector2(w * 0.74, h * 0.2), Vector2(gc.x, h * 0.2), 0.35)
	L(ci, Vector2(w * 0.74, h * 0.62), Vector2(gc.x, h * 0.62), 0.35)
	L(ci, Vector2(gc.x, h * 0.62), gc + Vector2(0, minf(w * 0.1, 7.0)), 0.35)


static func _filter_one(ci: CanvasItem, r: Rect2, _i: int) -> void:
	var sh := vessel_v(ci, r, 0.55)
	# the cutaway element
	var el := Rect2(sh.position.x + sh.size.x * 0.2, sh.position.y + 2.0, sh.size.x * 0.6, sh.size.y - 4.0)
	R(ci, el, 0.3)
	pleats(ci, Rect2(el.position.x + 1.0, el.position.y + 1.0, el.size.x - 2.0, el.size.y - 2.0), 3.5, false, 0.28)
	L(ci, Vector2(el.get_center().x, el.position.y), Vector2(el.get_center().x, el.end.y), 0.35)
	# the body flange where the head comes off
	L(ci, Vector2(r.position.x - 2.0, sh.position.y + 1.0), Vector2(r.end.x + 2.0, sh.position.y + 1.0), 0.5, 1.6)
	# nozzles: in near the top, out near the bottom
	var ny: float = sh.position.y + sh.size.y * 0.1
	L(ci, Vector2(r.position.x - r.size.x * 0.2, ny), Vector2(r.position.x, ny), 0.5)
	flange(ci, Vector2(r.position.x - r.size.x * 0.2, ny), Vector2.LEFT, minf(r.size.x * 0.12, 6.0), 0.5)
	var oy: float = sh.end.y - sh.size.y * 0.12
	L(ci, Vector2(r.end.x, oy), Vector2(r.end.x + r.size.x * 0.2, oy), 0.5)
	flange(ci, Vector2(r.end.x + r.size.x * 0.2, oy), Vector2.RIGHT, minf(r.size.x * 0.12, 6.0), 0.5)
	# drain valve and legs
	var bx: float = r.get_center().x
	L(ci, Vector2(bx, r.end.y - 1.0), Vector2(bx, r.end.y + r.size.y * 0.03), 0.45)
	L(ci, Vector2(r.position.x + r.size.x * 0.15, sh.end.y), Vector2(r.position.x + r.size.x * 0.05, r.end.y + r.size.y * 0.06), 0.45)
	L(ci, Vector2(r.end.x - r.size.x * 0.15, sh.end.y), Vector2(r.end.x - r.size.x * 0.05, r.end.y + r.size.y * 0.06), 0.45)


# a condensate trap: the inverted-bucket body, the bucket inside with its vent hole,
# the lever to the seat, the strainer leg and the test valve
static func trap(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bw: float = minf(w * 0.44, h * 0.6)
	var body := Rect2(w * 0.5 - bw * 0.5, h * 0.12, bw, h * 0.76)
	var sh := vessel_v(ci, body, 0.55)
	L(ci, Vector2(0, h * 0.24), Vector2(body.position.x, h * 0.24), 0.5)
	L(ci, Vector2(body.end.x, h * 0.24), Vector2(w, h * 0.24), 0.5)
	if minf(w, h) < SMALL * 0.7:
		return
	# the bucket upside down, its vent
	P(ci, PackedVector2Array([Vector2(sh.position.x + sh.size.x * 0.2, sh.end.y - 2.0), Vector2(sh.position.x + sh.size.x * 0.2, sh.position.y + sh.size.y * 0.3), Vector2(sh.end.x - sh.size.x * 0.2, sh.position.y + sh.size.y * 0.3), Vector2(sh.end.x - sh.size.x * 0.2, sh.end.y - 2.0)]), 0.4)
	D(ci, Vector2(sh.get_center().x, sh.position.y + sh.size.y * 0.3), 1.0, 0.5)
	L(ci, Vector2(sh.get_center().x, sh.position.y + sh.size.y * 0.3), Vector2(sh.end.x - 2.0, sh.position.y + 2.0), 0.4)
	# the strainer leg off the inlet
	L(ci, Vector2(w * 0.14, h * 0.24), Vector2(w * 0.08, h * 0.6), 0.45)
	L(ci, Vector2(w * 0.04, h * 0.6), Vector2(w * 0.12, h * 0.6), 0.45, 1.4)
	wheel(ci, Vector2(w * 0.86, h * 0.1), minf(w * 0.08, 5.0), 0.45)


# ------------------------------------------------------------------ lockers

# personal lockers: a narrow door each with its vent slots top and bottom, the
# number card and the hasp; a low wide run is a row of small compartments
static func locker(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL * 0.7:
		var n0 := clampi(int(w / 10.0), 1, 20)
		for i in n0:
			R(ci, Rect2(i * w / n0 + 1.0, 2, w / n0 - 2.0, h - 4), 0.35)
		return
	var low: bool = h < 1.1 * M and w > h * 1.5
	var dw: float = (0.5 if low else 0.4) * M
	var n := clampi(roundi((w - 4.0) / dw), 1, 60)
	dw = (w - 4.0) / n
	var rows := 2 if (not low and h > 2.6 * M) else 1
	var dh: float = (h - 4.0) / rows
	var slots := PackedVector2Array()
	for k in rows:
		for i in n:
			var d := Rect2(2.0 + i * dw + 1.0, 2.0 + k * dh + 1.0, dw - 2.0, dh - 2.0)
			R(ci, d, 0.42)
			# vent slots
			var ns := clampi(int(d.size.y * 0.12 / 3.0), 1, 5)
			for e in [0.06, 0.82]:
				for s in ns:
					var y: float = d.position.y + d.size.y * e + s * 3.0
					slots.append(Vector2(d.position.x + d.size.x * 0.25, y))
					slots.append(Vector2(d.end.x - d.size.x * 0.25, y))
			# hasp and number card
			var hy: float = d.position.y + d.size.y * 0.42
			L(ci, Vector2(d.end.x - d.size.x * 0.2, hy), Vector2(d.end.x - d.size.x * 0.2, hy + minf(10.0, d.size.y * 0.12)), 0.6, 1.6)
			if d.size.x > 10.0:
				O(ci, Vector2(d.end.x - d.size.x * 0.2, hy + minf(10.0, d.size.y * 0.12) + 2.5), 1.8, 0.45)
				R(ci, Rect2(d.position.x + d.size.x * 0.2, d.position.y + d.size.y * 0.24, d.size.x * 0.35, minf(5.0, d.size.y * 0.06)), 0.3)
	S(ci, slots, 0.28)


# ------------------------------------------------------------------ console

# an operator console: pedestal with its kick plate and vents, the desk, the
# sloped upper panel with its displays, keyboard, trackball and a joystick
static func console(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var desk_y: float = h * 0.52
	var top_y: float = h * 0.06
	# the sloped instrument panel rises from the desk's back edge
	P(ci, PackedVector2Array([Vector2(w * 0.04, h), Vector2(w * 0.04, desk_y), Vector2(w * 0.3, desk_y), Vector2(w * 0.5, top_y), Vector2(w * 0.97, top_y), Vector2(w * 0.97, h)]), 0.5)
	L(ci, Vector2(w * 0.02, desk_y), Vector2(w * 0.3, desk_y), 0.6, 1.6)
	if minf(w, h) < SMALL:
		R(ci, Rect2(w * 0.55, h * 0.12, w * 0.36, h * 0.3), 0.45)
		return
	# displays along the upper panel
	var ns := clampi(roundi((w * 0.42) / (0.9 * M)), 1, 6)
	var pw: float = w * 0.44 / ns
	for i in ns:
		screen_face(ci, Rect2(w * 0.52 + i * pw + 1.5, top_y + h * 0.06, pw - 3.0, h * 0.3), i, 0.4)
	# the slope's switch row
	for i in clampi(int(w * 0.18 / 6.0), 2, 10):
		var t: float = (i + 0.5) / float(clampi(int(w * 0.18 / 6.0), 2, 10))
		D(ci, Vector2(w * 0.3, desk_y).lerp(Vector2(w * 0.5, top_y), 0.35) + Vector2(w * 0.17 * t, 0), 1.1, 0.5)
	# keyboard and trackball on the desk, the joystick
	var kb := Rect2(w * 0.07, desk_y - h * 0.06, w * 0.14, h * 0.05)
	R(ci, kb, 0.4)
	hatch(ci, kb, 3.0, true, 0.22, 24)
	O(ci, Vector2(w * 0.25, desk_y - h * 0.035), minf(3.0, h * 0.03), 0.5)
	L(ci, Vector2(w * 0.34, h * 0.42), Vector2(w * 0.34, h * 0.32), 0.55, 1.4)
	D(ci, Vector2(w * 0.34, h * 0.31), 1.8, 0.55)
	# pedestal: drawers and vents, the kick plate, the lower panel
	R(ci, Rect2(w * 0.08, desk_y + h * 0.08, w * 0.18, h * 0.3), 0.35)
	L(ci, Vector2(w * 0.12, desk_y + h * 0.23), Vector2(w * 0.22, desk_y + h * 0.23), 0.5, 1.4)
	louvres(ci, Rect2(w * 0.55, h * 0.58, w * 0.36, h * 0.24), 0.25)
	L(ci, Vector2(w * 0.04, h * 0.94), Vector2(w * 0.97, h * 0.94), 0.35)


# ------------------------------------------------------------------ racks

# 19-inch equipment racks: posts with their hole rows, and stacked in them a
# patch panel, a network switch with its ports and lights, 1U and 2U servers with
# drive bays and vents, the UPS at the foot; a wide one is a row of racks
static func nav_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var rw: float = clampf(0.62 * M, 22.0, 32.0)
	var n := clampi(roundi(w / rw), 1, 20)
	var cw: float = w / n
	for i in n:
		_rack(ci, Rect2(i * cw + 1.0, 1.0, cw - 2.0, h - 2.0), i)


static func _rack(ci: CanvasItem, r: Rect2, sd: int) -> void:
	var px: float = clampf(r.size.x * 0.1, 2.0, 4.0)
	L(ci, Vector2(r.position.x + px, r.position.y), Vector2(r.position.x + px, r.end.y), 0.45)
	L(ci, Vector2(r.end.x - px, r.position.y), Vector2(r.end.x - px, r.end.y), 0.45)
	var x0: float = r.position.x + px + 1.0
	var x1: float = r.end.x - px - 1.0
	var u: float = clampf(r.size.y / 18.0, 4.0, 7.0)
	var y: float = r.position.y + 2.0
	var kinds := [0, 1, 2, 2, 3, 2, 3, 2, 2, 3, 2, 3, 2, 2]
	var k := 0
	var leds := PackedVector2Array()
	while y < r.end.y - 2.6 * u:
		var kind: int = kinds[(k + sd * 3) % kinds.size()]
		var uh: float = u * (2.0 if kind == 3 else 1.0)
		var b := Rect2(x0, y, x1 - x0, uh - 1.0)
		R(ci, b, 0.38)
		match kind:
			0, 1:
				# patch panel / switch: a row of ports
				var np := clampi(int(b.size.x / 3.2), 2, 24)
				for e in np:
					leds.append(Vector2(b.position.x + (e + 0.5) * b.size.x / np - 0.6, b.get_center().y))
					leds.append(Vector2(b.position.x + (e + 0.5) * b.size.x / np + 0.6, b.get_center().y))
				if kind == 1:
					D(ci, Vector2(b.end.x - 2.0, b.position.y + 1.6), 0.8, 0.7)
			2:
				# 1U server: drive bays left, a light right
				var nd := clampi(int(b.size.x * 0.55 / 4.0), 1, 6)
				for e in nd:
					leds.append(Vector2(b.position.x + 2.0 + e * 4.0, b.get_center().y))
					leds.append(Vector2(b.position.x + 4.5 + e * 4.0, b.get_center().y))
				D(ci, Vector2(b.end.x - 2.5, b.get_center().y), 0.8, 0.7)
			_:
				# 2U server: vents and a handle each side
				hatch(ci, Rect2(b.position.x + b.size.x * 0.25, b.position.y + 1.0, b.size.x * 0.5, b.size.y - 2.0), 2.6, true, 0.2, 16)
				L(ci, Vector2(b.position.x + 1.5, b.position.y + 1.5), Vector2(b.position.x + 1.5, b.end.y - 1.5), 0.5)
				L(ci, Vector2(b.end.x - 1.5, b.position.y + 1.5), Vector2(b.end.x - 1.5, b.end.y - 1.5), 0.5)
		y += uh
		k += 1
	S(ci, leds, 0.45)
	# the UPS at the foot with its display
	var ups := Rect2(x0, maxf(y, r.end.y - 2.6 * u), x1 - x0, r.end.y - maxf(y, r.end.y - 2.6 * u) - 1.0)
	if ups.size.y > 4.0:
		R(ci, ups, 0.45)
		R(ci, sub(ups, 0.1, 0.25, 0.4, 0.7), 0.4)
		hatch(ci, sub(ups, 0.5, 0.2, 0.92, 0.8), 2.6, true, 0.2, 12)


# ------------------------------------------------------------------ modules

# an orbital replacement unit: a sealed box made to be swapped whole -- the two grab
# handles, captive fasteners round its lid, the blind-mate connectors on its face,
# the cold-plate fins along its base, the status window
static func module(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL * 0.6:
		R(ci, inset(r, 2.0), 0.4)
		D(ci, Vector2(w * 0.3, h * 0.5), 1.2, 0.5)
		D(ci, Vector2(w * 0.7, h * 0.5), 1.2, 0.5)
		return
	var n := clampi(roundi(w / maxf(h * 1.8, 1.2 * M)), 1, 12)
	var uw: float = w / n
	for i in n:
		_oru(ci, Rect2(i * uw + 2.0, 2.0, uw - 4.0, h - 4.0), i)
	if w > 2.0 * M and h > 0.9 * M:
		plate(ci, Rect2(6.0, h * 0.62, minf(48.0, uw * 0.4), 9.0), tag_of(p), font, 0.4)


static func _oru(ci: CanvasItem, r: Rect2, _i: int) -> void:
	var lid := inset(r, minf(4.0, r.size.y * 0.12))
	R(ci, lid, 0.42)
	var nb := clampi(int(lid.size.x / 14.0), 2, 10)
	bolts(ci, lid.position + Vector2(0, 2.0), Vector2(lid.end.x, lid.position.y + 2.0), nb, 0.5, 0.9)
	bolts(ci, Vector2(lid.position.x, lid.end.y - 2.0), lid.end - Vector2(0, 2.0), nb, 0.5, 0.9)
	# grab handles: U shapes standing off the face
	var hh: float = minf(lid.size.y * 0.35, 10.0)
	for f in [0.12, 0.88]:
		var cx: float = lid.position.x + lid.size.x * f
		P(ci, PackedVector2Array([Vector2(cx - 3.0, lid.position.y + lid.size.y * 0.3), Vector2(cx - 3.0, lid.position.y + lid.size.y * 0.3 + hh), Vector2(cx + 3.0, lid.position.y + lid.size.y * 0.3 + hh), Vector2(cx + 3.0, lid.position.y + lid.size.y * 0.3)]), 0.55, 1.4)
	# connectors and status window
	var cr: float = clampf(lid.size.y * 0.12, 1.6, 4.5)
	for k in 3:
		var c := Vector2(lid.position.x + lid.size.x * (0.32 + k * 0.12), lid.position.y + lid.size.y * 0.42)
		O(ci, c, cr, 0.5)
		if cr > 3.0:
			D(ci, c, 0.8, 0.5)
	R(ci, Rect2(lid.position.x + lid.size.x * 0.7, lid.position.y + lid.size.y * 0.3, lid.size.x * 0.1, lid.size.y * 0.25), 0.4)
	# a big one: the access window onto its card cage (boards, ejector tabs)
	if lid.size.y > 60.0 and lid.size.x > 60.0:
		var cg := Rect2(lid.position.x + lid.size.x * 0.24, lid.position.y + lid.size.y * 0.56, lid.size.x * 0.52, lid.size.y * 0.2)
		R(ci, cg, 0.35)
		var nc := clampi(int(cg.size.x / 5.0), 2, 40)
		var cs := PackedVector2Array()
		for k in nc:
			var x: float = cg.position.x + (k + 0.5) * cg.size.x / nc
			cs.append(Vector2(x, cg.position.y + 2.0))
			cs.append(Vector2(x, cg.end.y - 2.0))
		S(ci, cs, 0.28)
		L(ci, cg.position + Vector2(1.0, 4.0), Vector2(cg.end.x - 1.0, cg.position.y + 4.0), 0.4)
	# the base fins to the cold plate
	if r.size.y > 18.0:
		hatch(ci, Rect2(lid.position.x + 2.0, lid.end.y - lid.size.y * 0.22, lid.size.x - 4.0, lid.size.y * 0.15), 3.0, true, 0.2, 60)


# a control valve on its run: the globe body, the bonnet, the diaphragm actuator's
# dome, its yoke and positioner, flanges each side
static func aux(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vy: float = h * 0.72
	var c := Vector2(w * 0.5, vy)
	var bs: float = minf(h * 0.24, w * 0.18)
	L(ci, Vector2(1, vy - bs * 0.45), Vector2(c.x - bs, vy - bs * 0.45), 0.5)
	L(ci, Vector2(1, vy + bs * 0.45), Vector2(c.x - bs, vy + bs * 0.45), 0.5)
	L(ci, Vector2(c.x + bs, vy - bs * 0.45), Vector2(w - 1, vy - bs * 0.45), 0.5)
	L(ci, Vector2(c.x + bs, vy + bs * 0.45), Vector2(w - 1, vy + bs * 0.45), 0.5)
	# the globe body as a bow tie
	P(ci, PackedVector2Array([c + Vector2(-bs, -bs * 0.7), c + Vector2(bs, bs * 0.7), c + Vector2(bs, -bs * 0.7), c + Vector2(-bs, bs * 0.7), c + Vector2(-bs, -bs * 0.7)]), 0.55, 1.2)
	flange(ci, Vector2(c.x - bs, vy), Vector2.LEFT, bs * 0.75, 0.5)
	flange(ci, Vector2(c.x + bs, vy), Vector2.RIGHT, bs * 0.75, 0.5)
	if minf(w, h) < SMALL * 0.6:
		L(ci, c, Vector2(c.x, h * 0.15), 0.5)
		return
	# bonnet, yoke, stem
	var top: float = h * 0.08
	var dome_r: float = minf(w * 0.3, h * 0.2)
	L(ci, c, Vector2(c.x, top + dome_r), 0.5, 1.4)
	L(ci, Vector2(c.x - bs * 0.5, vy - bs * 0.75), Vector2(c.x - dome_r * 0.5, top + dome_r * 1.1), 0.4)
	L(ci, Vector2(c.x + bs * 0.5, vy - bs * 0.75), Vector2(c.x + dome_r * 0.5, top + dome_r * 1.1), 0.4)
	A(ci, Vector2(c.x, top + dome_r), dome_r, PI, TAU, 0.55, 1.2)
	L(ci, Vector2(c.x - dome_r, top + dome_r), Vector2(c.x + dome_r, top + dome_r), 0.55, 1.4)
	# the positioner and its air line
	var pz := Rect2(c.x + dome_r * 0.7, top + dome_r * 1.4, minf(w * 0.18, 12.0), minf(h * 0.14, 9.0))
	R(ci, pz, 0.45)
	L(ci, Vector2(pz.get_center().x, pz.position.y), Vector2(pz.get_center().x, top + dome_r * 0.5), 0.3)


# ------------------------------------------------------------------ enclosures

# a wall-hung control enclosure: the door with its hinges and quarter-turn latches,
# the window onto the indicator row, the warning label, glands and cables below;
# a long low one is a row of them on a cable trunking
static func panel(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	if w > h * 2.6:
		var n := clampi(roundi(w / (h * 1.4)), 2, 16)
		var ew: float = w / n
		L(ci, Vector2(1, h * 0.12), Vector2(w - 1, h * 0.12), 0.4, 1.4)
		for i in n:
			_enclosure(ci, Rect2(i * ew + ew * 0.1, h * 0.2, ew * 0.8, h * 0.72), i)
			L(ci, Vector2(i * ew + ew * 0.5, h * 0.12), Vector2(i * ew + ew * 0.5, h * 0.2), 0.4)
		return
	_enclosure(ci, Rect2(w * 0.08, h * 0.06, w * 0.84, h * 0.76), 0)
	# glands and the cables dropping out
	var segs := PackedVector2Array()
	var ng := clampi(int(w * 0.7 / 6.0), 1, 6)
	for k in ng:
		var gx: float = w * 0.2 + (k + 0.5) * w * 0.6 / ng
		segs.append(Vector2(gx, h * 0.82))
		segs.append(Vector2(gx + (k - ng * 0.5) * 0.8, h - 1.0))
	S(ci, segs, 0.35)
	if h > 1.2 * M and w > 0.8 * M:
		plate(ci, Rect2(w * 0.2, h * 0.58, w * 0.6, 8.0), tag_of(p), font, 0.4)


static func _enclosure(ci: CanvasItem, r: Rect2, _i: int) -> void:
	R(ci, r, 0.48)
	var d := inset(r, minf(2.5, r.size.x * 0.1))
	R(ci, d, 0.3)
	if minf(r.size.x, r.size.y) < 14.0:
		D(ci, r.get_center(), 1.1, 0.5)
		return
	for f in [0.2, 0.8]:
		L(ci, Vector2(r.position.x, r.position.y + r.size.y * f - 2.0), Vector2(r.position.x, r.position.y + r.size.y * f + 2.0), 0.6, 2.0)
		D(ci, Vector2(r.end.x - r.size.x * 0.12, r.position.y + r.size.y * f), 1.4, 0.55)
	# indicator row behind a window
	var win := Rect2(r.position.x + r.size.x * 0.22, r.position.y + r.size.y * 0.16, r.size.x * 0.5, r.size.y * 0.2)
	R(ci, win, 0.4)
	var nl := clampi(int(win.size.x / 5.0), 1, 5)
	for k in nl:
		D(ci, Vector2(win.position.x + (k + 0.5) * win.size.x / nl, win.get_center().y), 1.1, 0.6)
	# the warning triangle
	var tc := Vector2(r.get_center().x - r.size.x * 0.05, r.position.y + r.size.y * 0.58)
	var ts: float = minf(r.size.x * 0.12, 5.0)
	P(ci, PackedVector2Array([tc + Vector2(0, -ts), tc + Vector2(ts, ts * 0.7), tc + Vector2(-ts, ts * 0.7), tc + Vector2(0, -ts)]), 0.45)


# a junction box: the lid on its four corner screws, the earth stud, the cable
# glands with their cables in and out
static func junction(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.14, h * 0.1, w * 0.72, h * 0.62)
	R(ci, b, 0.5)
	R(ci, inset(b, 2.0), 0.25)
	corner_bolts(ci, b, minf(3.0, b.size.y * 0.2), 0.55)
	# the lid's raised terminal hump and the earth mark
	L(ci, Vector2(b.position.x + b.size.x * 0.3, b.get_center().y), Vector2(b.end.x - b.size.x * 0.3, b.get_center().y), 0.35)
	if b.size.x > 18.0:
		L(ci, Vector2(b.get_center().x, b.get_center().y - 3.0), Vector2(b.get_center().x, b.get_center().y), 0.45)
		L(ci, Vector2(b.get_center().x - 2.5, b.get_center().y), Vector2(b.get_center().x + 2.5, b.get_center().y), 0.45)
		L(ci, Vector2(b.get_center().x - 1.5, b.get_center().y + 1.2), Vector2(b.get_center().x + 1.5, b.get_center().y + 1.2), 0.45)
	# glands below, the cables going out each side
	for f in [0.3, 0.7]:
		var gx: float = w * f
		R(ci, Rect2(gx - 2.0, b.end.y, 4.0, h * 0.12), 0.45)
		L(ci, Vector2(gx, b.end.y + h * 0.12), Vector2(gx + (w * 0.5 - gx) * -0.6, h - 1.0), 0.4)


# a field instrument: its housing with the display window, the process connection
# and the cable gland, on a bracket
static func insp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if h > w * 1.2:
		# a transmitter on its stem: round head with the dial window, the neck, the
		# process flange, the conduit out the side
		var hr: float = minf(w * 0.4, h * 0.22)
		var hc := Vector2(w * 0.5, h * 0.08 + hr)
		O(ci, hc, hr, 0.55, 1.2)
		gauge(ci, hc, hr * 0.62, 0.5)
		R(ci, Rect2(w * 0.5 - hr * 0.35, hc.y + hr, hr * 0.7, h * 0.08), 0.45)
		L(ci, Vector2(w * 0.5, hc.y + hr + h * 0.08), Vector2(w * 0.5, h * 0.9), 0.5, 1.6)
		flange(ci, Vector2(w * 0.5, h * 0.92), Vector2.DOWN, minf(w * 0.3, hr), 0.5)
		L(ci, Vector2(w * 0.5 + hr, hc.y), Vector2(w, hc.y + 4.0), 0.35)
		return
	# a camera in its housing: sun shield, lens and wiper, the pan-tilt head on its
	# wall arm, the cable
	var cl: float = minf(w * 0.62, maxf(h * 2.2, 0.6 * M))
	var chh: float = minf(h * 0.42, cl * 0.4)
	var hd := Rect2(w * 0.5 - cl * 0.4, h * 0.22, cl, chh)
	R(ci, hd, 0.5)
	P(ci, PackedVector2Array([Vector2(hd.position.x - 3.0, hd.position.y + 2.0), Vector2(hd.position.x - 3.0, hd.position.y - 2.0), Vector2(hd.end.x + 6.0, hd.position.y - 2.0), Vector2(hd.end.x + 6.0, hd.position.y + 3.0)]), 0.45)
	var lens := Vector2(hd.end.x, hd.get_center().y)
	L(ci, lens + Vector2(0, -chh * 0.38), lens + Vector2(0, chh * 0.38), 0.6, 1.6)
	O(ci, lens + Vector2(-chh * 0.3, 0), chh * 0.24, 0.45)
	if hd.size.x > 30.0:
		hatch(ci, Rect2(hd.position.x + 3.0, hd.position.y + 2.0, hd.size.x * 0.3, hd.size.y - 4.0), 3.0, true, 0.2, 10)
	var pt := Vector2(hd.position.x + hd.size.x * 0.4, hd.end.y + chh * 0.3)
	R(ci, Rect2(pt - Vector2(chh * 0.3, chh * 0.3), Vector2(chh * 0.6, chh * 0.6)), 0.45)
	L(ci, Vector2(pt.x, hd.end.y), Vector2(pt.x, pt.y - chh * 0.3), 0.45)
	L(ci, pt + Vector2(0, chh * 0.3), Vector2(pt.x, h * 0.9), 0.5, 1.4)
	L(ci, Vector2(pt.x - chh * 0.5, h * 0.9), Vector2(pt.x + chh * 0.5, h * 0.9), 0.5, 1.6)
	P(ci, PackedVector2Array([Vector2(hd.position.x, hd.end.y - 2.0), Vector2(hd.position.x - 5.0, hd.end.y + 4.0), Vector2(hd.position.x - 5.0, h * 0.95)]), 0.3)


# a sensor node: the perforated sensing head, its body, status light, conduit
static func sensor(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.55)
	var rad: float = minf(w * 0.3, h * 0.4)
	A(ci, c, rad, PI, TAU, 0.55, 1.2)
	L(ci, c + Vector2(-rad, 0), c + Vector2(rad, 0), 0.55)
	var segs := PackedVector2Array()
	for k in 3:
		var a: float = PI + (k + 1) * PI / 4.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.35)
		segs.append(c + Vector2.from_angle(a) * rad * 0.85)
	S(ci, segs, 0.35)
	R(ci, Rect2(c.x - rad * 0.8, c.y, rad * 1.6, minf(rad * 0.7, h - c.y - 1.0)), 0.45)
	D(ci, Vector2(c.x + rad * 0.45, c.y + rad * 0.3), 0.9, 0.7)
	L(ci, Vector2(c.x - rad * 0.8, c.y + rad * 0.35), Vector2(1, c.y + rad * 0.35), 0.35)


# ------------------------------------------------------------------ overhead runs

# the services under a deckhead: a cable ladder with its rungs and the cables lying
# in it, a light fitting every few metres, sprinkler heads, a supply-air diffuser
static func overhead(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w < h:
		hatch(ci, Rect2(w * 0.25, 0, w * 0.5, h), 6.0, false, 0.35, 40)
		return
	tray(ci, Rect2(0, 0, w, h * 0.42))
	var fy: float = h * 0.62
	var n := clampi(int(w / (3.0 * M)) + 1, 1, 12)
	for i in n:
		var x: float = (i + 0.5) * w / n
		# the light: housing, diffuser
		var lw: float = minf(1.2 * M, w / n * 0.5)
		L(ci, Vector2(x, h * 0.42), Vector2(x, fy - 2.0), 0.35)
		R(ci, Rect2(x - lw * 0.5, fy - 2.0, lw, h * 0.16), 0.5)
		L(ci, Vector2(x - lw * 0.45, fy + h * 0.16), Vector2(x + lw * 0.45, fy + h * 0.16), 0.6, 1.4)
		# a sprinkler head between lights
		var sx: float = x + w / n * 0.5
		if sx < w - 4.0:
			L(ci, Vector2(sx, h * 0.42), Vector2(sx, h * 0.85), 0.3)
			P(ci, PackedVector2Array([Vector2(sx - 2.5, h * 0.92), Vector2(sx, h * 0.85), Vector2(sx + 2.5, h * 0.92)]), 0.5)


# LED grow lights: the hanger wires, the finned heat sink, the diode row and lens
static func growlamp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (1.2 * M)), 1, 16)
	var bw: float = w / n
	for i in n:
		var b := Rect2(i * bw + bw * 0.06, h * 0.35, bw * 0.88, h * 0.4)
		L(ci, Vector2(b.position.x + b.size.x * 0.15, 0), Vector2(b.position.x + b.size.x * 0.15, b.position.y), 0.3)
		L(ci, Vector2(b.end.x - b.size.x * 0.15, 0), Vector2(b.end.x - b.size.x * 0.15, b.position.y), 0.3)
		R(ci, b, 0.5)
		hatch(ci, Rect2(b.position.x + 2.0, b.position.y, b.size.x - 4.0, b.size.y * 0.55), 3.0, true, 0.25, 40)
		var nd := clampi(int(b.size.x / 5.0), 2, 30)
		for k in nd:
			D(ci, Vector2(b.position.x + (k + 0.5) * b.size.x / nd, b.end.y - b.size.y * 0.22), 0.9, 0.65)
		L(ci, Vector2(b.position.x, b.end.y + 1.0), Vector2(b.end.x, b.end.y + 1.0), 0.4)


# a cable ladder: side rails, rungs, the cables bundled in it, the hangers
static func tray(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var y0: float = r.position.y + h * 0.3
	var y1: float = r.end.y - h * 0.1
	L(ci, Vector2(r.position.x, y0), Vector2(r.end.x, y0), 0.45, 1.2)
	L(ci, Vector2(r.position.x, y1), Vector2(r.end.x, y1), 0.45, 1.2)
	var segs := PackedVector2Array()
	var n := clampi(int(w / 12.0), 1, 160)
	for i in n:
		var x: float = r.position.x + (i + 0.5) * w / n
		segs.append(Vector2(x, y0))
		segs.append(Vector2(x, y1))
	S(ci, segs, 0.2)
	# the cables lying in it, one bundle low and a strand above
	L(ci, Vector2(r.position.x + 1.0, lerpf(y0, y1, 0.78)), Vector2(r.end.x - 1.0, lerpf(y0, y1, 0.78)), 0.45, 1.4)
	L(ci, Vector2(r.position.x + 1.0, lerpf(y0, y1, 0.55)), Vector2(r.end.x - 1.0, lerpf(y0, y1, 0.55)), 0.3)
	var nh := clampi(int(w / (2.0 * M)) + 1, 2, 30)
	for i in nh:
		var x: float = r.position.x + (i + 0.5) * w / nh
		L(ci, Vector2(x, r.position.y), Vector2(x, y0), 0.35, 1.2)


# ------------------------------------------------------------------ pipes

# a run of pipe: its walls, a flange pair every few metres with bolts, insulation
# lagging bands, the hangers it rides in, a flow arrow, a valve on a long run
static func pipe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	L(ci, X.call(0, th * 0.18), X.call(ln, th * 0.18), 0.55)
	L(ci, X.call(0, th * 0.82), X.call(ln, th * 0.82), 0.55)
	var nf := maxi(1, int(ln / (2.5 * M)))
	var segs := PackedVector2Array()
	for i in nf + 1:
		var u: float = clampf(ln * float(i) / nf, 2.0, ln - 2.0)
		segs.append(X.call(u - 1.5, 0))
		segs.append(X.call(u - 1.5, th))
		segs.append(X.call(u + 1.5, 0))
		segs.append(X.call(u + 1.5, th))
	S(ci, segs, 0.45)
	# lagging bands where it's insulated
	if th > 12.0:
		segs = PackedVector2Array()
		var nb := clampi(int(ln / 24.0), 0, 200)
		for i in nb:
			var u: float = (i + 0.5) * ln / nb
			segs.append(X.call(u, th * 0.18))
			segs.append(X.call(u, th * 0.82))
			segs.append(X.call(u + 2.0, th * 0.18))
			segs.append(X.call(u + 2.0, th * 0.82))
		S(ci, segs, 0.14)
	# hangers between flanges
	for i in nf:
		var u: float = ln * (i + 0.5) / nf
		L(ci, X.call(u - th * 0.3, th * 0.86), X.call(u + th * 0.3, th * 0.86), 0.4)
	# flow arrow
	if ln > 1.5 * M:
		var u0: float = ln * 0.5 / nf
		L(ci, X.call(u0 - 10.0, th * 0.5), X.call(u0, th * 0.5), 0.45)
		P(ci, PackedVector2Array([X.call(u0 - 4.0, th * 0.36), X.call(u0, th * 0.5), X.call(u0 - 4.0, th * 0.64)]), 0.45)
	if ln > 8.0 * M:
		var uc: float = ln * 0.5 + ln * 0.25 / nf
		var vs: float = th * 0.35
		P(ci, PackedVector2Array([X.call(uc - vs, th * 0.5 - vs), X.call(uc + vs, th * 0.5 + vs), X.call(uc + vs, th * 0.5 - vs), X.call(uc - vs, th * 0.5 + vs), X.call(uc - vs, th * 0.5 - vs)]), 0.5)


# ------------------------------------------------------------------ cargo

# whatever cargo isn't named: a container if it's container-sized, else crates
static func cargo(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	if r.size.x > 4.0 * M and r.size.y > 1.6 * M:
		container(ci, r, p, font)
	else:
		crate(ci, r, p, font)


# timber-framed crates: the frame boards round each face, its planks, a diagonal
# brace, the corner brackets, the stencilled tag; a long low run is a row of them
static func crate(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 1.3, 0.9 * M)), 1, 30)
	var cw: float = w / n
	var fragile: bool = p != null and p.fragile >= 0.85
	for i in n:
		var c := Rect2(i * cw + 1.5, 1.5, cw - 3.0, h - 3.0)
		var fb: float = clampf(minf(c.size.x, c.size.y) * 0.1, 2.0, 6.0)
		R(ci, c, 0.45)
		R(ci, inset(c, fb), 0.35)
		var q := inset(c, fb)
		if q.size.y > 12.0:
			hatch(ci, q, maxf(4.0, q.size.y / 5.0), false, 0.14, 12)
		L(ci, q.position, q.end, 0.35, 1.4)
		if minf(c.size.x, c.size.y) > 20.0:
			for corner in [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]:
				var sx: float = 1.0 if corner.x < c.get_center().x else -1.0
				var sy: float = 1.0 if corner.y < c.get_center().y else -1.0
				P(ci, PackedVector2Array([corner + Vector2(sx * fb * 1.6, 0), corner, corner + Vector2(0, sy * fb * 1.6)]), 0.6, 1.6)
		if i == 0 and p != null and c.size.x > 34.0 and c.size.y > 22.0:
			var tr := Rect2(c.position.x + c.size.x * 0.18, c.get_center().y - 6.0, c.size.x * 0.64, 12.0)
			F(ci, tr, 0.9 * 0.06)
			plate(ci, tr, p.tag, font, 0.5)
		if fragile and c.size.x > 20.0 and c.size.y > 20.0:
			# the up arrows of a this-way-up stencil
			var ac := Vector2(c.end.x - fb * 2.5, c.position.y + fb * 2.5)
			P(ci, PackedVector2Array([ac + Vector2(-2.5, 2.5), ac, ac + Vector2(2.5, 2.5)]), 0.55)
			L(ci, ac, ac + Vector2(0, 6), 0.55)


# an ISO container side: top and bottom rails, corner castings with their twist-lock
# holes, the corrugated side, the door end with its locking bars; a reefer has its
# refrigeration unit at the other end
static func container(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 2.3, 2.0 * M)), 1, 12)
	var cw: float = w / n
	var reefer: bool = p != null and p.name_key == "p_cold_pallet"
	for i in n:
		var c := Rect2(i * cw + 1.0, 1.0, cw - 2.0, h - 2.0)
		var rail: float = clampf(c.size.y * 0.07, 2.0, 7.0)
		R(ci, c, 0.5)
		L(ci, c.position + Vector2(0, rail), Vector2(c.end.x, c.position.y + rail), 0.45)
		L(ci, Vector2(c.position.x, c.end.y - rail), c.end - Vector2(0, rail), 0.45)
		var cc: float = rail * 1.4
		for q in [c.position, Vector2(c.end.x - cc, c.position.y), Vector2(c.position.x, c.end.y - cc), c.end - Vector2(cc, cc)]:
			R(ci, Rect2(q, Vector2(cc, cc)), 0.55)
			if cc > 5.0:
				O(ci, q + Vector2(cc, cc) * 0.5, cc * 0.22, 0.5)
		var door_w: float = minf(c.size.x * 0.22, c.size.y * 0.7)
		var side := Rect2(c.position.x + cc, c.position.y + rail, c.size.x - door_w - cc * 2.0, c.size.y - rail * 2.0)
		if reefer:
			var ru := Rect2(c.position.x + 2.0, c.position.y + rail + 2.0, door_w, c.size.y - rail * 2.0 - 4.0)
			R(ci, ru, 0.5)
			fan(ci, ru.position + ru.size * Vector2(0.5, 0.3), minf(ru.size.x, ru.size.y) * 0.24, 5, 0.45)
			louvres(ci, sub(ru, 0.12, 0.6, 0.88, 0.92), 0.3)
			side.position.x += door_w
			side.size.x -= door_w
		hatch(ci, side, clampf(c.size.y * 0.05, 3.5, 7.0), true, 0.16, 80)
		# the door end: two leaves, four locking bars with their handles
		var de := Rect2(c.end.x - door_w - cc * 0.5, c.position.y + rail, door_w, c.size.y - rail * 2.0)
		L(ci, Vector2(de.position.x, de.position.y), Vector2(de.position.x, de.end.y), 0.45)
		L(ci, Vector2(de.get_center().x, de.position.y), Vector2(de.get_center().x, de.end.y), 0.4)
		for k in 4:
			var x: float = de.position.x + de.size.x * (0.15 + k * 0.23)
			L(ci, Vector2(x, de.position.y + 1.0), Vector2(x, de.end.y - 1.0), 0.45)
			L(ci, Vector2(x, de.get_center().y + 3.0), Vector2(x + de.size.x * 0.1, de.get_center().y + 3.0), 0.5, 1.4)
		if i == 0 and p != null and side.size.x > 50.0:
			plate(ci, Rect2(side.position.x + 4.0, side.position.y + 4.0, minf(56.0, side.size.x * 0.5), 10.0), p.tag, font, 0.55)


# ------------------------------------------------------------------ bottles and tanks

# gas cylinders: the shouldered body, its neck ring and the valve with handwheel,
# the colour bands, the wall straps; a wide one is a racked bank on a manifold
static func gastank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	if w > h * 1.2 and h < 0.9 * M:
		# lying down: a cylinder bank seen from its side, all heads one way
		var nl := clampi(roundi(h / maxf(w * 0.18, 10.0)), 1, 8)
		var lh: float = h / nl
		for i in nl:
			_bottle(ci, Rect2(o + Vector2(2, i * lh + 1.0), Vector2(w - 4, lh - 2.0)), false)
		return
	var n := clampi(roundi(w / maxf(h * 0.3, 10.0)), 1, 16)
	var bw: float = w / n
	for i in n:
		_bottle(ci, Rect2(o + Vector2(i * bw + bw * 0.08, 1.0), Vector2(bw * 0.84, h - 2.0)), true)
	if n > 1:
		L(ci, o + Vector2(bw * 0.5, h * 0.05), o + Vector2(w - bw * 0.5, h * 0.05), 0.5, 1.4)
	for f in [0.42, 0.78]:
		L(ci, o + Vector2(1, h * f), o + Vector2(w - 1, h * f), 0.35)


static func _bottle(ci: CanvasItem, r: Rect2, up: bool) -> void:
	var dia: float = r.size.x if up else r.size.y
	var ln: float = r.size.y if up else r.size.x
	var X := func(u: float, v: float) -> Vector2: return r.position + (Vector2(v, u) if up else Vector2(ln - u, v))
	var head: float = minf(dia * 0.9, ln * 0.18)
	var sh0: float = head + dia * 0.35
	# body and its rounded shoulder
	var pts := PackedVector2Array([X.call(ln - 1.0, dia * 0.06), X.call(sh0, dia * 0.06)])
	for k in 7:
		var a: float = PI * 0.5 * k / 6.0
		pts.append(X.call(sh0 - sin(a) * dia * 0.35, dia * 0.5 - cos(a) * dia * 0.44))
	for k in 7:
		var a: float = PI * 0.5 * (6 - k) / 6.0
		pts.append(X.call(sh0 - sin(a) * dia * 0.35, dia * 0.5 + cos(a) * dia * 0.44))
	pts.append(X.call(sh0, dia * 0.94))
	pts.append(X.call(ln - 1.0, dia * 0.94))
	P(ci, pts, 0.55)
	L(ci, X.call(ln - 1.0, dia * 0.06), X.call(ln - 1.0, dia * 0.94), 0.55)
	# neck, valve, handwheel / guard
	var nk: float = head
	L(ci, X.call(nk, dia * 0.38), X.call(sh0 - dia * 0.35, dia * 0.38), 0.5)
	L(ci, X.call(nk, dia * 0.62), X.call(sh0 - dia * 0.35, dia * 0.62), 0.5)
	if dia > 9.0:
		R(ci, Rect2(X.call(head * 0.45, dia * 0.3), X.call(nk, dia * 0.7) - X.call(head * 0.45, dia * 0.3)).abs(), 0.5)
		L(ci, X.call(head * 0.2, dia * 0.25), X.call(head * 0.2, dia * 0.75), 0.55, 1.6)
		L(ci, X.call(head * 0.2, dia * 0.5), X.call(head * 0.45, dia * 0.5), 0.45)
		D(ci, X.call(head * 0.7, dia * 0.82), 1.2, 0.5)
	# the colour bands
	if ln > 30.0:
		L(ci, X.call(sh0 + ln * 0.04, dia * 0.06), X.call(sh0 + ln * 0.04, dia * 0.94), 0.35)
		L(ci, X.call(sh0 + ln * 0.08, dia * 0.06), X.call(sh0 + ln * 0.08, dia * 0.94), 0.35)
		L(ci, X.call(ln - 4.0, dia * 0.06), X.call(ln - 4.0, dia * 0.94), 0.3)


# fire extinguishing bottles: the cylinder, its discharge head with the gauge and
# the solenoid actuator, the flexible hose off to the pipework, the wall bracket
static func extinguisher(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 0.32, 10.0)), 1, 12)
	var bw: float = w / n
	for i in n:
		var b := Rect2(i * bw + bw * 0.12, h * 0.16, bw * 0.76, h * 0.83)
		_bottle(ci, b, true)
		var hc := Vector2(b.get_center().x, h * 0.1)
		R(ci, Rect2(hc.x - bw * 0.22, hc.y - h * 0.05, bw * 0.44, h * 0.08), 0.5)
		if bw > 12.0:
			O(ci, Vector2(hc.x + bw * 0.3, hc.y), minf(bw * 0.12, 3.5), 0.5)
			R(ci, Rect2(hc.x - bw * 0.42, hc.y - h * 0.08, bw * 0.16, h * 0.06), 0.45)
		P(ci, PackedVector2Array([Vector2(hc.x, hc.y - h * 0.05), Vector2(hc.x, h * 0.02), Vector2(hc.x + bw * 0.5, h * 0.02)]), 0.35)
		L(ci, Vector2(b.position.x - 1.0, h * 0.55), Vector2(b.end.x + 1.0, h * 0.55), 0.45, 1.4)


# a water tank: its walls, the bolted manway and the vent gooseneck on top, the
# baffles inside, the water line, the sight-glass gauge, the outlet valve
static func water(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var t := Rect2(w * 0.06, h * 0.12, w * 0.84, h * 0.8)
	R(ci, t, 0.55)
	var lv: float = t.position.y + t.size.y * 0.32
	# the water line, rippled, and faint fill below
	var pts := PackedVector2Array()
	var nw := clampi(int(t.size.x / 6.0), 2, 80)
	for k in nw + 1:
		pts.append(Vector2(t.position.x + t.size.x * k / nw, lv + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.45)
	F(ci, Rect2(t.position.x, lv, t.size.x, t.end.y - lv), 0.035)
	if minf(w, h) < SMALL:
		return
	# baffles
	var nb := clampi(int(t.size.x / (1.5 * M)), 0, 10)
	for k in nb:
		var x: float = t.position.x + (k + 1) * t.size.x / (nb + 1)
		L(ci, Vector2(x, t.position.y + t.size.y * (0.0 if k % 2 == 0 else 0.15)), Vector2(x, t.end.y - t.size.y * (0.15 if k % 2 == 0 else 0.0)), 0.25)
	# manway, vent
	var mw: float = minf(t.size.x * 0.24, 0.6 * M)
	var mx: float = t.position.x + t.size.x * 0.3
	R(ci, Rect2(mx - mw * 0.5, t.position.y - h * 0.06, mw, h * 0.06), 0.5)
	bolts(ci, Vector2(mx - mw * 0.5, t.position.y - h * 0.03), Vector2(mx + mw * 0.5, t.position.y - h * 0.03), clampi(int(mw / 6.0), 2, 8), 0.5, 0.9)
	var vx: float = t.end.x - t.size.x * 0.15
	P(ci, PackedVector2Array([Vector2(vx, t.position.y), Vector2(vx, h * 0.03), Vector2(vx + 6.0, h * 0.03), Vector2(vx + 6.0, h * 0.08)]), 0.45)
	# sight glass on the side
	var gx: float = t.end.x + w * 0.04
	L(ci, Vector2(t.end.x, t.position.y + t.size.y * 0.1), Vector2(gx, t.position.y + t.size.y * 0.1), 0.4)
	L(ci, Vector2(t.end.x, t.end.y - t.size.y * 0.1), Vector2(gx, t.end.y - t.size.y * 0.1), 0.4)
	R(ci, Rect2(gx - 1.5, t.position.y + t.size.y * 0.1, 3.0, t.size.y * 0.8), 0.45)
	L(ci, Vector2(gx - 1.5, lv), Vector2(gx + 1.5, lv), 0.7, 1.4)
	# outlet and valve
	var oy: float = t.end.y - t.size.y * 0.08
	L(ci, Vector2(t.position.x, oy), Vector2(1, oy), 0.5)
	if t.size.y > 40.0:
		wheel(ci, Vector2(t.position.x * 0.5, oy - 6.0), minf(4.0, t.position.x * 0.4), 0.45)
	if w > 1.6 * M and h > 1.2 * M:
		plate(ci, Rect2(t.position.x + t.size.x * 0.55, t.position.y + t.size.y * 0.6, minf(52.0, t.size.x * 0.35), 9.0), tag_of(p), font, 0.4)


# a propellant / process tank: the pressure vessel lying in its saddles, its
# baffle rings inside, nozzles and valves on top, the level transmitter, a manway
static func fueltank(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w * 1.2
	var sh: Rect2
	if vert:
		sh = vessel_v(ci, Rect2(w * 0.08, h * 0.04, w * 0.84, h * 0.88), 0.55)
	else:
		sh = vessel_h(ci, Rect2(w * 0.02, h * 0.1, w * 0.96, h * 0.74), 0.55)
	if minf(w, h) < SMALL * 0.7:
		return
	# baffle rings (a gap at the middle for the propellant to pass)
	var ln: float = sh.size.y if vert else sh.size.x
	var nb := clampi(int(ln / (1.4 * M)), 1, 12)
	var segs := PackedVector2Array()
	for k in nb:
		var u: float = (k + 1) * ln / (nb + 1)
		if vert:
			segs.append(Vector2(sh.position.x + 1.0, sh.position.y + u))
			segs.append(Vector2(sh.get_center().x - sh.size.x * 0.12, sh.position.y + u))
			segs.append(Vector2(sh.get_center().x + sh.size.x * 0.12, sh.position.y + u))
			segs.append(Vector2(sh.end.x - 1.0, sh.position.y + u))
		else:
			segs.append(Vector2(sh.position.x + u, sh.position.y + 1.0))
			segs.append(Vector2(sh.position.x + u, sh.get_center().y - sh.size.y * 0.12))
			segs.append(Vector2(sh.position.x + u, sh.get_center().y + sh.size.y * 0.12))
			segs.append(Vector2(sh.position.x + u, sh.end.y - 1.0))
	S(ci, segs, 0.3)
	if vert:
		for f in [0.25, 0.75]:
			L(ci, Vector2(w * f, sh.end.y), Vector2(w * f + (w * 0.06 if f > 0.5 else -w * 0.06), h - 1.0), 0.5, 1.4)
		return
	# saddles
	for f in [0.22, 0.78]:
		var sx: float = sh.position.x + sh.size.x * f
		P(ci, PackedVector2Array([Vector2(sx - h * 0.18, h - 2.0), Vector2(sx - h * 0.1, sh.end.y - 1.0), Vector2(sx + h * 0.1, sh.end.y - 1.0), Vector2(sx + h * 0.18, h - 2.0)]), 0.5)
		L(ci, Vector2(sx - h * 0.22, h - 2.0), Vector2(sx + h * 0.22, h - 2.0), 0.5, 1.4)
	# nozzles and their valves along the top
	for f in [0.35, 0.5, 0.65]:
		var nx: float = sh.position.x + sh.size.x * f
		L(ci, Vector2(nx, sh.position.y), Vector2(nx, 2.0), 0.5)
		flange(ci, Vector2(nx, sh.position.y - 1.0), Vector2.UP, 3.0, 0.5)
		if h > 50.0 and f != 0.5:
			wheel(ci, Vector2(nx, h * 0.04), 2.5, 0.45)
	# the level transmitter's stilling well
	var lx: float = sh.position.x + sh.size.x * 0.85
	L(ci, Vector2(lx, sh.position.y + 2.0), Vector2(lx, sh.end.y - 3.0), 0.35)
	R(ci, Rect2(lx - 3.0, sh.position.y - 6.0, 6.0, 6.0), 0.45)
	if w > 2.4 * M and h > 1.0 * M:
		plate(ci, Rect2(sh.position.x + sh.size.x * 0.06, sh.get_center().y - 5.0, minf(54.0, sh.size.x * 0.3), 10.0), tag_of(p), font, 0.45)


# a capacitor bank: the cans standing in a row, two terminals each, the busbars
# tying them, the discharge resistor, the high-voltage sign
static func cap(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 0.45, 9.0)), 1, 24)
	var cw: float = w / n
	var top: float = h * 0.22
	for i in n:
		var c := Rect2(i * cw + cw * 0.14, top, cw * 0.72, h * 0.74)
		R(ci, c, 0.5)
		A(ci, Vector2(c.get_center().x, c.position.y), c.size.x * 0.5, PI, TAU, 0.4)
		if c.size.y > 20.0:
			L(ci, Vector2(c.position.x, c.position.y + c.size.y * 0.12), Vector2(c.end.x, c.position.y + c.size.y * 0.12), 0.3)
		for f in [0.3, 0.7]:
			L(ci, Vector2(c.position.x + c.size.x * f, c.position.y - c.size.x * 0.4), Vector2(c.position.x + c.size.x * f, h * 0.1), 0.5)
	if n > 1:
		L(ci, Vector2(cw * 0.3, h * 0.1), Vector2(w - cw * 0.3, h * 0.1), 0.55, 1.8)
		L(ci, Vector2(cw * 0.7, h * 0.05), Vector2(w - cw * 0.7, h * 0.05), 0.45, 1.4)
	if minf(w, h) > SMALL:
		var tc := Vector2(w - cw * 0.5, top + h * 0.38)
		var ts: float = minf(cw * 0.22, 6.0)
		P(ci, PackedVector2Array([tc + Vector2(0, -ts), tc + Vector2(ts, ts * 0.8), tc + Vector2(-ts, ts * 0.8), tc + Vector2(0, -ts)]), 0.6)
		L(ci, tc + Vector2(0.8, -ts * 0.4), tc + Vector2(-0.8, ts * 0.3), 0.6)


# ------------------------------------------------------------------ displays, avionics

# a wall of displays, each showing something different
static func screen(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.02, h * 0.06, w * 0.96, h * 0.88), 0.45)
	var rows := clampi(roundi(h / (0.7 * M)), 1, 4)
	var cols := clampi(roundi(w / maxf(h / rows * 1.6, 0.9 * M)), 1, 12)
	var cw: float = w * 0.94 / cols
	var rh: float = h * 0.8 / rows
	for k in rows:
		for i in cols:
			screen_face(ci, Rect2(w * 0.03 + i * cw + 1.5, h * 0.1 + k * rh + 1.5, cw - 3.0, rh - 3.0), i * 3 + k * 2, 0.35)


# an avionics unit: the front panel with its two handles, a small display, the
# rotary selectors, the connectors along the bottom, the cooling slots on top
static func nav(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 1.6, 1.0 * M)), 1, 8)
	var uw: float = w / n
	for i in n:
		var b := Rect2(i * uw + 2.0, 2.0, uw - 4.0, h - 4.0)
		R(ci, b, 0.48)
		if minf(b.size.x, b.size.y) < 16.0:
			D(ci, b.get_center(), 1.2, 0.5)
			continue
		for f in [0.06, 0.94]:
			var hx: float = b.position.x + b.size.x * f
			P(ci, PackedVector2Array([Vector2(hx, b.position.y + b.size.y * 0.25), Vector2(hx + (3.0 if f < 0.5 else -3.0), b.position.y + b.size.y * 0.3), Vector2(hx + (3.0 if f < 0.5 else -3.0), b.position.y + b.size.y * 0.7), Vector2(hx, b.position.y + b.size.y * 0.75)]), 0.55, 1.4)
		hatch(ci, Rect2(b.position.x + b.size.x * 0.2, b.position.y + 2.0, b.size.x * 0.6, b.size.y * 0.1), 3.0, true, 0.22, 30)
		screen_face(ci, Rect2(b.position.x + b.size.x * 0.16, b.position.y + b.size.y * 0.2, b.size.x * 0.36, b.size.y * 0.42), i + 1, 0.4)
		var kr: float = minf(b.size.y * 0.1, 5.0)
		for k in 2:
			var kc := Vector2(b.position.x + b.size.x * (0.64 + k * 0.16), b.position.y + b.size.y * 0.38)
			O(ci, kc, kr, 0.5)
			L(ci, kc, kc + Vector2.from_angle(-1.2 + k) * kr, 0.5)
		# connectors: trapezoid shells
		for k in 3:
			var cx: float = b.position.x + b.size.x * (0.25 + k * 0.25)
			var cy: float = b.end.y - b.size.y * 0.16
			var cs: float = minf(b.size.x * 0.08, 7.0)
			P(ci, PackedVector2Array([Vector2(cx - cs, cy - cs * 0.4), Vector2(cx + cs, cy - cs * 0.4), Vector2(cx + cs * 0.75, cy + cs * 0.4), Vector2(cx - cs * 0.75, cy + cs * 0.4), Vector2(cx - cs, cy - cs * 0.4)]), 0.45)


# an emergency oxygen cabinet: the door with its window, two cylinders inside,
# the regulator and its gauge, the mask on its coiled hose
static func o2cab(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Rect2(w * 0.06, h * 0.04, w * 0.88, h * 0.92)
	R(ci, c, 0.45)
	var win := Rect2(c.position.x + c.size.x * 0.1, c.position.y + c.size.y * 0.08, c.size.x * 0.8, c.size.y * 0.62)
	R(ci, win, 0.35)
	var nb := clampi(roundi(win.size.x / (win.size.y * 0.4)), 1, 6)
	var bw: float = win.size.x / nb
	for i in nb:
		_bottle(ci, Rect2(win.position.x + i * bw + bw * 0.1, win.position.y + win.size.y * 0.12, bw * 0.8, win.size.y * 0.84), true)
	gauge(ci, Vector2(c.get_center().x, win.position.y + win.size.y * 0.08), minf(c.size.x * 0.1, 4.0), 0.5)
	# the mask and its coiled hose below the window
	var mc := Vector2(c.position.x + c.size.x * 0.32, c.position.y + c.size.y * 0.84)
	A(ci, mc, minf(c.size.x * 0.14, 6.0), 0.2, PI - 0.2, 0.5)
	L(ci, mc - Vector2(minf(c.size.x * 0.14, 6.0), 0), mc + Vector2(minf(c.size.x * 0.14, 6.0), 0), 0.5)
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(Vector2(c.position.x + c.size.x * (0.48 + k * 0.05), c.position.y + c.size.y * (0.8 + (0.04 if k % 2 == 0 else 0.0))))
	P(ci, pts, 0.35)
	L(ci, Vector2(c.end.x - c.size.x * 0.1, c.position.y + c.size.y * 0.76), Vector2(c.end.x - c.size.x * 0.1, c.position.y + c.size.y * 0.9), 0.6, 1.6)
	if p != null and p.label != "":
		T(ci, font, Vector2(c.position.x + 2.0, c.end.y - 2.0), p.label, -1, 7, 0.5)


# a crew berth: the sleeping bag on its restraint straps, the pillow, the
# reading light and the air vent, the privacy curtain gathered at one end; a tall
# one is two tiers
static func bunk(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tiers := 2 if h > 1.4 * M else 1
	var th: float = h / tiers
	for k in tiers:
		var b := Rect2(2.0, k * th + 1.0, w - 4.0, th - 2.0)
		L(ci, Vector2(b.position.x, b.end.y - 1.0), Vector2(b.end.x, b.end.y - 1.0), 0.5, 1.4)
		# bag
		var bag := Rect2(b.position.x + b.size.x * 0.12, b.position.y + b.size.y * 0.45, b.size.x * 0.8, b.size.y * 0.42)
		P(ci, PackedVector2Array([bag.position + Vector2(bag.size.y * 0.5, 0), Vector2(bag.end.x - 2.0, bag.position.y + bag.size.y * 0.1), Vector2(bag.end.x, bag.get_center().y), Vector2(bag.end.x - 2.0, bag.end.y - bag.size.y * 0.1), Vector2(bag.position.x + bag.size.y * 0.5, bag.end.y), Vector2(bag.position.x, bag.get_center().y), bag.position + Vector2(bag.size.y * 0.5, 0)]), 0.45)
		L(ci, Vector2(bag.position.x + bag.size.x * 0.25, bag.get_center().y), Vector2(bag.end.x - 4.0, bag.get_center().y), 0.3)
		for f in [0.35, 0.7]:
			L(ci, Vector2(bag.position.x + bag.size.x * f, bag.position.y - 2.0), Vector2(bag.position.x + bag.size.x * f, bag.end.y + 2.0), 0.5, 1.4)
		# pillow
		R(ci, Rect2(b.position.x + 2.0, bag.position.y + bag.size.y * 0.1, b.size.x * 0.09, bag.size.y * 0.8), 0.4)
		if b.size.y < 18.0:
			continue
		# reading light and vent on the back wall
		R(ci, Rect2(b.position.x + b.size.x * 0.04, b.position.y + b.size.y * 0.1, b.size.x * 0.08, b.size.y * 0.1), 0.5)
		hatch(ci, Rect2(b.position.x + b.size.x * 0.4, b.position.y + b.size.y * 0.12, b.size.x * 0.1, b.size.y * 0.14), 2.5, true, 0.3, 10)
		# curtain rail and the gathered curtain
		L(ci, Vector2(b.position.x, b.position.y + 2.0), Vector2(b.end.x, b.position.y + 2.0), 0.4)
		var cx: float = b.end.x - b.size.x * 0.06
		var pts := PackedVector2Array()
		for e in 7:
			pts.append(Vector2(cx + (1.5 if e % 2 == 0 else -1.5), b.position.y + 2.0 + e * (b.size.y - 4.0) / 6.0))
		P(ci, pts, 0.4)


# a flight recorder: the chassis, its armoured crash-survivable memory drum with
# ribs, the underwater locator beacon, the carry handle and connector
static func blackbox(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.04, h * 0.5, w * 0.92, h * 0.44)
	R(ci, ch, 0.6)
	hatch(ci, sub(ch, 0.06, 0.3, 0.45, 0.8), 3.0, true, 0.25, 20)
	var mem := Rect2(w * 0.5, h * 0.12, w * 0.4, h * 0.38)
	R(ci, mem, 0.7, 1.2)
	hatch(ci, inset(mem, 2.0), 3.5, true, 0.35, 16)
	O(ci, Vector2(w * 0.25, h * 0.36), minf(w * 0.08, h * 0.12), 0.55)
	L(ci, Vector2(w * 0.25 - minf(w * 0.08, h * 0.12), h * 0.36), Vector2(w * 0.25 - minf(w * 0.08, h * 0.12), h * 0.5), 0.5)
	L(ci, Vector2(w * 0.25 + minf(w * 0.08, h * 0.12), h * 0.36), Vector2(w * 0.25 + minf(w * 0.08, h * 0.12), h * 0.5), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.55, h * 0.12), Vector2(w * 0.58, h * 0.03), Vector2(w * 0.82, h * 0.03), Vector2(w * 0.85, h * 0.12)]), 0.55)
	R(ci, Rect2(ch.end.x - w * 0.16, ch.get_center().y - h * 0.07, w * 0.1, h * 0.14), 0.5)


# ------------------------------------------------------------------ furniture

# a mess / chart table: its top on a single pedestal, the foot bar to hook a foot
# under, the screen let into its top, cups held in their clips
static func table(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.32
	L(ci, Vector2(w * 0.02, ty), Vector2(w * 0.98, ty), 0.6, 2.0)
	R(ci, Rect2(w * 0.3, ty - h * 0.05, w * 0.4, h * 0.04), 0.45)
	var n := clampi(roundi(w / (1.6 * M)), 1, 4)
	for i in n:
		var x: float = (i + 0.5) * w / n
		L(ci, Vector2(x - 3.0, ty), Vector2(x - 3.0, h * 0.92), 0.45)
		L(ci, Vector2(x + 3.0, ty), Vector2(x + 3.0, h * 0.92), 0.45)
		L(ci, Vector2(x - w * 0.12 / n, h * 0.96), Vector2(x + w * 0.12 / n, h * 0.96), 0.5, 1.6)
	L(ci, Vector2(w * 0.08, h * 0.72), Vector2(w * 0.92, h * 0.72), 0.35)
	for f in [0.12, 0.85]:
		R(ci, Rect2(w * f, ty - h * 0.12, w * 0.04, h * 0.1), 0.4)


# open shelving: the uprights, the shelves with their lips, boxes and bins of all
# sizes held on by restraint straps
static func shelf(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var nb := clampi(roundi(w / (1.0 * M)), 1, 20)
	var bw: float = w / nb
	for i in nb + 1:
		L(ci, Vector2(clampf(i * bw, 1.0, w - 1.0), 1.0), Vector2(clampf(i * bw, 1.0, w - 1.0), h - 1.0), 0.5)
	var ns := clampi(roundi(h / (0.5 * M)), 1, 10)
	var sh: float = h / ns
	var segs := PackedVector2Array()
	for k in ns:
		var y: float = (k + 1) * sh - 1.5
		L(ci, Vector2(1.0, y), Vector2(w - 1.0, y), 0.5, 1.4)
		for i in nb:
			# a few boxes on this shelf bay
			var x: float = i * bw + 3.0
			var e := 0
			while x < (i + 1) * bw - 6.0 and e < 6:
				var bx: float = minf(bw * (0.18 + 0.14 * fposmod((i * 7 + k * 3 + e) * 0.37, 1.0)), (i + 1) * bw - x - 3.0)
				var by: float = sh * (0.4 + 0.4 * fposmod((i * 5 + k * 11 + e) * 0.29, 1.0))
				if bx < 3.0:
					break
				R(ci, Rect2(x, y - by, bx, by), 0.35)
				if by > 8.0:
					segs.append(Vector2(x + 1.0, y - by * 0.6))
					segs.append(Vector2(x + bx - 1.0, y - by * 0.6))
				x += bx + 2.0
				e += 1
		L(ci, Vector2(2.0, y - sh * 0.45), Vector2(w - 2.0, y - sh * 0.45), 0.3)
	S(ci, segs, 0.2)


# a work desk: the top, a drawer pedestal, a monitor on its arm, the foot rail
static func desk(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.42
	L(ci, Vector2(w * 0.02, ty), Vector2(w * 0.98, ty), 0.6, 2.0)
	var pd := Rect2(w * 0.62, ty + 2.0, w * 0.32, h * 0.56)
	R(ci, pd, 0.45)
	for k in 3:
		var dy: float = pd.position.y + (k + 0.5) * pd.size.y / 3.0
		L(ci, Vector2(pd.position.x, pd.position.y + (k + 1) * pd.size.y / 3.0), Vector2(pd.end.x, pd.position.y + (k + 1) * pd.size.y / 3.0), 0.35)
		L(ci, Vector2(pd.get_center().x - 4.0, dy), Vector2(pd.get_center().x + 4.0, dy), 0.55, 1.4)
	L(ci, Vector2(w * 0.06, ty), Vector2(w * 0.06, h * 0.98), 0.45)
	screen_face(ci, Rect2(w * 0.2, h * 0.04, w * 0.34, h * 0.26), 0, 0.4)
	L(ci, Vector2(w * 0.37, h * 0.3), Vector2(w * 0.37, ty), 0.45)
	R(ci, Rect2(w * 0.12, ty - 3.0, w * 0.2, 2.5), 0.4)


# a tool wall: the pegboard and its holes, tools hung on it in their outlines
static func toolwall(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	R(ci, inset(r, 2.0), 0.4)
	var segs := PackedVector2Array()
	var px := 6.0
	var ny := clampi(int((h - 6.0) / px), 1, 40)
	var nx := clampi(int((w - 6.0) / px), 1, 40)
	for j in ny:
		for i in nx:
			var q := o + Vector2(3.0 + (i + 0.5) * (w - 6.0) / nx, 3.0 + (j + 0.5) * (h - 6.0) / ny)
			segs.append(q)
			segs.append(q + Vector2(0.6, 0))
	S(ci, segs, 0.25)
	# tools: a wrench, a hammer, screwdrivers, a coil of cable, a parts bin
	var u: float = minf(w, h)
	var c := o + Vector2(w * 0.25, h * 0.3)
	L(ci, c + Vector2(0, -u * 0.12), c + Vector2(0, u * 0.2), 0.55, 1.6)
	A(ci, c + Vector2(0, -u * 0.15), u * 0.05, PI * 0.2, PI * 1.8, 0.55)
	var hm := o + Vector2(w * 0.55, h * 0.25)
	L(ci, hm, hm + Vector2(0, u * 0.3), 0.55, 1.6)
	R(ci, Rect2(hm + Vector2(-u * 0.08, -u * 0.03), Vector2(u * 0.16, u * 0.05)), 0.55)
	for k in 3:
		var sx: float = w * (0.72 + k * 0.08)
		L(ci, o + Vector2(sx, h * 0.18), o + Vector2(sx, h * 0.28), 0.6, 2.0)
		L(ci, o + Vector2(sx, h * 0.28), o + Vector2(sx, h * 0.42), 0.45)
	O(ci, o + Vector2(w * 0.4, h * 0.7), u * 0.12, 0.45)
	O(ci, o + Vector2(w * 0.4, h * 0.7), u * 0.08, 0.35)
	R(ci, Rect2(o + Vector2(w * 0.65, h * 0.6), Vector2(w * 0.25, h * 0.25)), 0.4)


# a refrigerator: the two doors (freezer above) with their gaskets and handles,
# the compressor bay grille at the foot, the condenser coil behind
static func fridge(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.08, h * 0.02, w * 0.84, h * 0.86)
	R(ci, b, 0.5)
	var split: float = b.position.y + b.size.y * 0.32
	L(ci, Vector2(b.position.x, split), Vector2(b.end.x, split), 0.5)
	R(ci, inset(Rect2(b.position, Vector2(b.size.x, split - b.position.y)), 2.0), 0.25)
	R(ci, inset(Rect2(Vector2(b.position.x, split), Vector2(b.size.x, b.end.y - split)), 2.0), 0.25)
	L(ci, Vector2(b.end.x - b.size.x * 0.14, split - b.size.y * 0.12), Vector2(b.end.x - b.size.x * 0.14, split - b.size.y * 0.04), 0.6, 1.6)
	L(ci, Vector2(b.end.x - b.size.x * 0.14, split + b.size.y * 0.04), Vector2(b.end.x - b.size.x * 0.14, split + b.size.y * 0.2), 0.6, 1.6)
	louvres(ci, Rect2(b.position.x + 3.0, b.end.y + 1.0, b.size.x - 6.0, h * 0.1), 0.3)


# a medicine cabinet: glazed doors with their glints, shelves of bottles and boxes,
# the cross on the frieze
static func medcab(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.06, h * 0.14, w * 0.88, h * 0.82)
	R(ci, b, 0.5)
	L(ci, Vector2(b.get_center().x, b.position.y), Vector2(b.get_center().x, b.end.y), 0.4)
	var cc := Vector2(w * 0.5, h * 0.07)
	var cs: float = minf(h * 0.05, w * 0.08)
	P(ci, PackedVector2Array([cc + Vector2(-cs * 0.35, -cs), cc + Vector2(cs * 0.35, -cs), cc + Vector2(cs * 0.35, -cs * 0.35), cc + Vector2(cs, -cs * 0.35), cc + Vector2(cs, cs * 0.35), cc + Vector2(cs * 0.35, cs * 0.35), cc + Vector2(cs * 0.35, cs), cc + Vector2(-cs * 0.35, cs), cc + Vector2(-cs * 0.35, cs * 0.35), cc + Vector2(-cs, cs * 0.35), cc + Vector2(-cs, -cs * 0.35), cc + Vector2(-cs * 0.35, -cs * 0.35), cc + Vector2(-cs * 0.35, -cs)]), 0.6)
	var ns := 3
	for k in ns:
		var y: float = b.position.y + (k + 1) * b.size.y / (ns + 0.4)
		L(ci, Vector2(b.position.x + 2.0, y), Vector2(b.end.x - 2.0, y), 0.4)
		var n := clampi(int(b.size.x / 7.0), 2, 12)
		for i in n:
			var bh: float = b.size.y / (ns + 0.4) * (0.35 + 0.3 * fposmod(i * 0.41 + k * 0.17, 1.0))
			var bw: float = b.size.x / n * 0.6
			var x: float = b.position.x + 2.0 + i * (b.size.x - 4.0) / n
			R(ci, Rect2(x, y - bh, bw, bh), 0.3)
	L(ci, Vector2(b.position.x + b.size.x * 0.1, b.end.y - b.size.y * 0.1), Vector2(b.position.x + b.size.x * 0.3, b.position.y + b.size.y * 0.15), 0.2)
	L(ci, Vector2(b.position.x + b.size.x * 0.6, b.end.y - b.size.y * 0.1), Vector2(b.position.x + b.size.x * 0.8, b.position.y + b.size.y * 0.15), 0.2)


# a galley: the worktop, the oven with its window, the food warmer drawers, the
# water dispenser, the cupboards under it with their catches
static func galley(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.45
	L(ci, Vector2(1, ty), Vector2(w - 1, ty), 0.6, 2.0)
	var n := clampi(roundi(w / (0.8 * M)), 1, 16)
	var uw: float = w / n
	for i in n:
		var b := Rect2(i * uw + 1.5, ty + 3.0, uw - 3.0, h - ty - 5.0)
		match i % 4:
			0:
				# oven: door, window, handle
				R(ci, b, 0.45)
				R(ci, sub(b, 0.15, 0.3, 0.85, 0.75), 0.35)
				L(ci, b.position + b.size * Vector2(0.2, 0.15), b.position + b.size * Vector2(0.8, 0.15), 0.6, 1.6)
			1:
				# warmer drawers
				for k in 3:
					var d := Rect2(b.position.x, b.position.y + k * b.size.y / 3.0 + 1.0, b.size.x, b.size.y / 3.0 - 2.0)
					R(ci, d, 0.4)
					L(ci, d.get_center() + Vector2(-4.0, 0), d.get_center() + Vector2(4.0, 0), 0.55, 1.4)
			2:
				door_leaf(ci, b, true, 0.4)
			_:
				door_leaf(ci, b, false, 0.4)
	# above the worktop: the dispenser and the stowage lockers
	var dx: float = w * 0.5
	R(ci, Rect2(dx - uw * 0.25, ty - h * 0.24, uw * 0.5, h * 0.2), 0.45)
	L(ci, Vector2(dx, ty - h * 0.04), Vector2(dx, ty - h * 0.01), 0.55, 1.4)
	var nl := clampi(n - 1, 1, 12)
	for i in nl:
		var x: float = (i + 0.5) * w / nl - uw * 0.4
		if absf(x + uw * 0.4 - dx) < uw * 0.6:
			continue
		R(ci, Rect2(x, h * 0.04, uw * 0.8, h * 0.26), 0.35)
		L(ci, Vector2(x + uw * 0.4, h * 0.22), Vector2(x + uw * 0.4, h * 0.28), 0.55, 1.4)


# a workbench: the steel top, the vice at one end with its jaws and screw, the
# drawers under, the tool board behind with the task light on its arm
static func bench(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.5
	L(ci, Vector2(1, ty), Vector2(w - 1, ty), 0.6, 2.2)
	var vx: float = w * 0.08
	R(ci, Rect2(vx, ty - h * 0.12, w * 0.08, h * 0.12), 0.5)
	L(ci, Vector2(vx - w * 0.04, ty - h * 0.06), Vector2(vx, ty - h * 0.06), 0.55, 1.4)
	D(ci, Vector2(vx - w * 0.04, ty - h * 0.06), 1.4, 0.55)
	var dr := Rect2(w * 0.6, ty + 3.0, w * 0.34, h * 0.44)
	R(ci, dr, 0.45)
	for k in 4:
		var d := Rect2(dr.position.x, dr.position.y + k * dr.size.y / 4.0, dr.size.x, dr.size.y / 4.0)
		R(ci, d, 0.35)
		L(ci, d.get_center() + Vector2(-5, 0), d.get_center() + Vector2(5, 0), 0.55, 1.4)
	L(ci, Vector2(w * 0.04, ty), Vector2(w * 0.04, h * 0.98), 0.45, 1.4)
	L(ci, Vector2(w * 0.04, h * 0.85), Vector2(dr.position.x, h * 0.85), 0.35)
	if w > 1.2 * M and h > 1.2 * M:
		toolwall(ci, Rect2(w * 0.24, h * 0.04, w * 0.5, h * 0.36))
	else:
		R(ci, Rect2(w * 0.24, h * 0.06, w * 0.5, h * 0.34), 0.35)
	P(ci, PackedVector2Array([Vector2(w * 0.86, ty), Vector2(w * 0.86, h * 0.12), Vector2(w * 0.78, h * 0.06)]), 0.45)
	A(ci, Vector2(w * 0.76, h * 0.1), minf(w, h) * 0.05, PI * 0.2, PI * 1.1, 0.5)


# ------------------------------------------------------------------ heat

# a radiator panel: the supply and return headers along both ends, the flow tubes
# between them, the fin sheet hatched faintly, the hinge fittings to its boom
static func radiator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var hd: float = clampf(th * 0.06, 2.5, 8.0)
	for v in [hd, th - hd]:
		L(ci, X.call(1.0, v), X.call(ln - 1.0, v), 0.55, 1.8)
	var segs := PackedVector2Array()
	var pitch: float = clampf(ln / 40.0, 6.0, 12.0)
	var n := clampi(int(ln / pitch), 2, 140)
	for i in n:
		var u: float = (i + 0.5) * ln / n
		segs.append(X.call(u, hd))
		segs.append(X.call(u, th - hd))
	S(ci, segs, 0.3)
	if th > 24.0:
		var fs := PackedVector2Array()
		for i in n:
			var u: float = (i + 0.5) * ln / n + pitch * 0.5
			if u > ln - 1.0:
				break
			fs.append(X.call(u, hd + 2.0))
			fs.append(X.call(u, th - hd - 2.0))
		S(ci, fs, 0.1)
	# the hinge fittings
	for f in [0.2, 0.8]:
		var q: Vector2 = X.call(ln * f, 0.0)
		O(ci, q + (Vector2(2.5, 0) if vert else Vector2(0, 2.5)), 2.0, 0.5)


# a shell-and-tube heat exchanger: the shell on its saddles, the channel heads with
# their pass partition, the tube sheets, the tubes, the segmental baffles, the
# nozzles in and out of shell and tubes
static func hx(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w * 1.2
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var ch: float = minf(ln * 0.14, th * 0.5)
	var s0: float = ch
	var s1: float = ln - ch
	var v0: float = th * 0.16
	var v1: float = th * 0.8
	L(ci, X.call(s0, v0), X.call(s1, v0), 0.55)
	L(ci, X.call(s0, v1), X.call(s1, v1), 0.55)
	# tube sheets and the channel heads
	for u in [s0, s1]:
		L(ci, X.call(u, v0 - 3.0), X.call(u, v1 + 3.0), 0.6, 2.0)
	P(ci, PackedVector2Array([X.call(s0, v0 + 2.0), X.call(ch * 0.25, v0 + 2.0), X.call(2.0, (v0 + v1) * 0.5), X.call(ch * 0.25, v1 - 2.0), X.call(s0, v1 - 2.0)]), 0.5)
	L(ci, X.call(2.0, (v0 + v1) * 0.5), X.call(s0, (v0 + v1) * 0.5), 0.4)
	P(ci, PackedVector2Array([X.call(s1, v0 + 2.0), X.call(ln - ch * 0.4, v0 + 2.0), X.call(ln - 2.0, (v0 + v1) * 0.5), X.call(ln - ch * 0.4, v1 - 2.0), X.call(s1, v1 - 2.0)]), 0.5)
	if minf(w, h) < SMALL * 0.8:
		return
	# tubes
	var segs := PackedVector2Array()
	var nt := clampi(int((v1 - v0) / 4.5), 2, 14)
	for k in nt:
		var v: float = v0 + (k + 0.5) * (v1 - v0) / nt
		segs.append(X.call(s0, v))
		segs.append(X.call(s1, v))
	S(ci, segs, 0.2)
	# baffles, alternately from top and bottom
	segs = PackedVector2Array()
	var nb := clampi(int((s1 - s0) / maxf(th * 0.5, 10.0)), 1, 16)
	for k in nb:
		var u: float = s0 + (k + 0.5) * (s1 - s0) / nb
		var top: bool = k % 2 == 0
		segs.append(X.call(u, v0 if top else v1))
		segs.append(X.call(u, lerpf(v0, v1, 0.72 if top else 0.28)))
	S(ci, segs, 0.45)
	# nozzles: shell side top and bottom near the ends, tube side on the head
	for nz in [[s0 + (s1 - s0) * 0.12, v0, -1.0], [s1 - (s1 - s0) * 0.12, v1, 1.0], [ch * 0.5, v0, -1.0], [ch * 0.5, v1, 1.0]]:
		var u: float = nz[0]
		var vv: float = nz[1]
		var d: float = nz[2]
		var tip: float = clampf(vv + d * th * 0.14, 1.5, th - 1.5)
		L(ci, X.call(u - 2.5, vv), X.call(u - 2.5, tip), 0.5)
		L(ci, X.call(u + 2.5, vv), X.call(u + 2.5, tip), 0.5)
		L(ci, X.call(u - 4.5, tip), X.call(u + 4.5, tip), 0.55, 1.6)
	if not vert:
		for f in [0.25, 0.75]:
			var x: float = s0 + (s1 - s0) * f
			P(ci, PackedVector2Array([Vector2(x - th * 0.12, th - 1.0), Vector2(x - th * 0.06, v1), Vector2(x + th * 0.06, v1), Vector2(x + th * 0.12, th - 1.0)]), 0.45)


# an axial duct fan: the duct with its flanges, the motor in its fairing on the
# centreline, the blades, the straightener vanes behind, the terminal box outside
static func duct_fan(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL or absf(w - h) < minf(w, h) * 0.25:
		# end-on: the casing ring, the rotor, the motor hub, the support struts
		var c := r.get_center()
		var rad: float = minf(w, h) * 0.44
		O(ci, c, rad, 0.55)
		fan(ci, c, rad * 0.88, 7, 0.45)
		var segs := PackedVector2Array()
		for k in 3:
			var a: float = PI * 0.5 + k * TAU / 3.0
			segs.append(c + Vector2.from_angle(a) * rad * 0.24)
			segs.append(c + Vector2.from_angle(a) * rad)
		S(ci, segs, 0.3)
		return
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	L(ci, X.call(2.0, th * 0.08), X.call(ln - 2.0, th * 0.08), 0.55)
	L(ci, X.call(2.0, th * 0.92), X.call(ln - 2.0, th * 0.92), 0.55)
	for u in [2.0, ln - 2.0]:
		L(ci, X.call(u, 0.0), X.call(u, th), 0.55, 2.0)
	# the motor in its fairing
	var m0: float = ln * 0.42
	var m1: float = ln * 0.78
	P(ci, PackedVector2Array([X.call(m0, th * 0.4), X.call(m0 + (m1 - m0) * 0.15, th * 0.32), X.call(m1, th * 0.32), X.call(m1, th * 0.68), X.call(m0 + (m1 - m0) * 0.15, th * 0.68), X.call(m0, th * 0.6), X.call(m0, th * 0.4)]), 0.5)
	hatch(ci, Rect2(X.call(m0 + (m1 - m0) * 0.2, th * 0.36), X.call(m1 - 2.0, th * 0.64) - X.call(m0 + (m1 - m0) * 0.2, th * 0.36)).abs(), 3.5, not vert, 0.18, 30)
	# blades (side-on, raked) just ahead of the motor
	var segs := PackedVector2Array()
	for k in 2:
		var u: float = m0 - ln * 0.05
		var sg: float = 1.0 if k == 0 else -1.0
		segs.append(X.call(u - ln * 0.03, th * 0.5 - sg * th * 0.1))
		segs.append(X.call(u + ln * 0.03, th * 0.5 - sg * th * 0.4))
	S(ci, segs, 0.55)
	O(ci, X.call(m0 - ln * 0.05, th * 0.5), th * 0.1, 0.5)
	# straightener vanes
	segs = PackedVector2Array()
	for k in 3:
		var u: float = ln * (0.84 + k * 0.035)
		segs.append(X.call(u, th * 0.1))
		segs.append(X.call(u, th * 0.3))
		segs.append(X.call(u, th * 0.7))
		segs.append(X.call(u, th * 0.9))
	S(ci, segs, 0.35)
	R(ci, Rect2(X.call(ln * 0.55, 0.0), X.call(ln * 0.65, th * 0.08) - X.call(ln * 0.55, 0.0)).abs(), 0.45)


# a water chiller: the screw compressor on top with its motor, the condenser shell
# above the evaporator shell, the expansion valve between, the control panel
static func chiller(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL:
		vessel_h(ci, Rect2(w * 0.05, h * 0.5, w * 0.7, h * 0.4), 0.5)
		R(ci, Rect2(w * 0.2, h * 0.1, w * 0.4, h * 0.34), 0.45)
		return
	var pw: float = minf(w * 0.18, h * 0.5)
	var body_w: float = w - pw - 6.0
	var cond := vessel_h(ci, Rect2(2.0, h * 0.42, body_w, h * 0.24), 0.5)
	var evap := vessel_h(ci, Rect2(2.0, h * 0.7, body_w, h * 0.24), 0.5)
	for sh in [cond, evap]:
		hatch(ci, inset(sh, 2.0), 4.0, false, 0.15, 8)
	# compressor: rotor housing and motor
	var cp := Rect2(body_w * 0.12, h * 0.1, body_w * 0.32, h * 0.26)
	R(ci, cp, 0.55)
	for k in 2:
		var cy: float = cp.position.y + cp.size.y * (0.33 + k * 0.34)
		var segs := PackedVector2Array()
		var nl := clampi(int(cp.size.x / 5.0), 2, 20)
		for i in nl:
			var x: float = cp.position.x + 2.0 + i * (cp.size.x - 4.0) / nl
			segs.append(Vector2(x, cy - cp.size.y * 0.12))
			segs.append(Vector2(x + 3.0, cy + cp.size.y * 0.12))
		S(ci, segs, 0.3)
	motor(ci, Rect2(cp.end.x, cp.position.y + cp.size.y * 0.1, body_w * 0.36, cp.size.y * 0.8), true, 0.5)
	L(ci, Vector2(cp.position.x + cp.size.x * 0.3, cp.end.y), Vector2(cp.position.x + cp.size.x * 0.3, cond.position.y), 0.5, 1.4)
	L(ci, Vector2(cp.position.x + cp.size.x * 0.1, cp.end.y), Vector2(cp.position.x + cp.size.x * 0.1, evap.position.y), 0.4)
	# expansion valve between the shells
	var ex := Vector2(cond.end.x - cond.size.x * 0.1, (cond.end.y + evap.position.y) * 0.5)
	P(ci, PackedVector2Array([ex + Vector2(-3, -3), ex + Vector2(3, 3), ex + Vector2(3, -3), ex + Vector2(-3, 3), ex + Vector2(-3, -3)]), 0.55)
	# water nozzles on the shell ends
	for sh in [cond, evap]:
		for d in [-1.0, 1.0]:
			L(ci, Vector2(sh.position.x - 2.0, sh.get_center().y + d * sh.size.y * 0.2), Vector2(1.0, sh.get_center().y + d * sh.size.y * 0.2), 0.45)
	# control panel
	var pn := Rect2(w - pw - 2.0, h * 0.1, pw, h * 0.84)
	R(ci, pn, 0.45)
	screen_face(ci, sub(pn, 0.15, 0.08, 0.85, 0.3), 1, 0.35)
	for k in 3:
		D(ci, pn.position + pn.size * Vector2(0.3 + k * 0.2, 0.38), 1.2, 0.55)
	louvres(ci, sub(pn, 0.2, 0.55, 0.8, 0.9), 0.25)


# ------------------------------------------------------------------ power

# a dry-type transformer: the three-limb core with its yokes, a winding on each limb
# (low voltage inside, high outside, the cooling ducts between), the HV terminals on
# top, the clamping frame and the enclosure louvres
static func transformer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var yk: float = clampf(h * 0.1, 3.0, 10.0)
	var core := Rect2(w * 0.08, h * 0.16, w * 0.84, h * 0.72)
	R(ci, Rect2(core.position, Vector2(core.size.x, yk)), 0.55)
	R(ci, Rect2(Vector2(core.position.x, core.end.y - yk), Vector2(core.size.x, yk)), 0.55)
	for k in 3:
		var cx: float = core.position.x + core.size.x * (0.17 + k * 0.33)
		var lw: float = core.size.x * 0.06
		R(ci, Rect2(cx - lw * 0.5, core.position.y + yk, lw, core.size.y - 2.0 * yk), 0.45)
		var cw: float = core.size.x * 0.27
		var coil := Rect2(cx - cw * 0.5, core.position.y + yk + 2.0, cw, core.size.y - 2.0 * yk - 4.0)
		R(ci, coil, 0.55)
		R(ci, Rect2(cx - cw * 0.3, coil.position.y + 2.0, cw * 0.6, coil.size.y - 4.0), 0.35)
		if coil.size.y > 20.0:
			hatch(ci, Rect2(coil.position.x + 1.0, coil.position.y + 2.0, cw * 0.18, coil.size.y - 4.0), 3.0, false, 0.2, 30)
			hatch(ci, Rect2(coil.end.x - cw * 0.18 - 1.0, coil.position.y + 2.0, cw * 0.18, coil.size.y - 4.0), 3.0, false, 0.2, 30)
		# the HV terminal bushing on top
		L(ci, Vector2(cx, core.position.y), Vector2(cx, h * 0.03), 0.5)
		for e in 3:
			var by: float = h * (0.05 + e * 0.035)
			L(ci, Vector2(cx - 3.0, by), Vector2(cx + 3.0, by), 0.45, 1.4)
	if minf(w, h) > SMALL:
		louvres(ci, Rect2(w * 0.02, h * 0.3, w * 0.04, h * 0.4), 0.3)
		louvres(ci, Rect2(w * 0.94, h * 0.3, w * 0.04, h * 0.4), 0.3)
	L(ci, Vector2(w * 0.05, h * 0.95), Vector2(w * 0.95, h * 0.95), 0.5, 1.4)


# an inverter: the IGBT modules bolted to their finned heat sink, the DC-link
# capacitor cans, the output filter choke, the fans on top, the display
static func inverter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if minf(w, h) < SMALL:
		hatch(ci, Rect2(w * 0.1, h * 0.15, w * 0.4, h * 0.7), 3.0, true, 0.3, 12)
		R(ci, Rect2(w * 0.6, h * 0.25, w * 0.3, h * 0.5), 0.45)
		return
	var n := clampi(roundi(w / maxf(h * 0.6, 0.8 * M)), 1, 10)
	var cw: float = w / n
	for i in n:
		var c := Rect2(i * cw + 2.0, 2.0, cw - 4.0, h - 4.0)
		R(ci, c, 0.45)
		# fans on top
		for k in 2:
			fan(ci, Vector2(c.position.x + c.size.x * (0.3 + k * 0.4), c.position.y + c.size.y * 0.1), minf(c.size.x * 0.15, c.size.y * 0.07), 5, 0.4)
		# heat sink fins with the modules on them
		var hs := sub(c, 0.08, 0.22, 0.55, 0.62)
		hatch(ci, hs, 3.0, true, 0.22, 40)
		for k in 3:
			var m := Rect2(hs.position.x + hs.size.x * 0.1, hs.position.y + hs.size.y * (0.08 + k * 0.31), hs.size.x * 0.8, hs.size.y * 0.24)
			F(ci, m, 0.06)
			R(ci, m, 0.55)
			for e in 3:
				D(ci, m.position + m.size * Vector2(0.2 + e * 0.3, 0.5), 1.0, 0.6)
		# DC-link capacitors
		var cr := sub(c, 0.62, 0.22, 0.92, 0.62)
		var nc := clampi(int(cr.size.y / 10.0), 1, 6)
		for k in nc:
			var cc := Vector2(cr.get_center().x, cr.position.y + (k + 0.5) * cr.size.y / nc)
			O(ci, cc, minf(cr.size.x * 0.35, cr.size.y / nc * 0.42), 0.5)
			D(ci, cc, 0.8, 0.5)
		# the choke: a core with its coil
		var ck := sub(c, 0.1, 0.68, 0.55, 0.92)
		R(ci, ck, 0.45)
		R(ci, sub(ck, 0.25, 0.15, 0.75, 0.85), 0.5)
		hatch(ci, sub(ck, 0.27, 0.18, 0.73, 0.82), 2.5, true, 0.25, 20)
		screen_face(ci, sub(c, 0.62, 0.7, 0.92, 0.84), i, 0.4)


# a fuel cell stack: the end plates and the tie rods with their nuts, the hundreds
# of bipolar plates between, the gas and coolant manifold ports, the air blower
# and the humidifier beside it
static func fuelcell(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var st := Rect2(w * 0.06, h * 0.18, w * 0.6, h * 0.64)
	var ep: float = clampf(st.size.x * 0.07, 3.0, 12.0)
	R(ci, Rect2(st.position, Vector2(ep, st.size.y)), 0.6)
	R(ci, Rect2(Vector2(st.end.x - ep, st.position.y), Vector2(ep, st.size.y)), 0.6)
	hatch(ci, Rect2(st.position.x + ep, st.position.y + 2.0, st.size.x - 2.0 * ep, st.size.y - 4.0), 2.2, true, 0.3, 140)
	for y in [st.position.y - 2.0, st.end.y + 2.0]:
		L(ci, Vector2(st.position.x - 3.0, y), Vector2(st.end.x + 3.0, y), 0.5)
		D(ci, Vector2(st.position.x - 3.0, y), 1.4, 0.55)
		D(ci, Vector2(st.end.x + 3.0, y), 1.4, 0.55)
	for k in 3:
		O(ci, Vector2(st.position.x + ep * 0.5, st.position.y + st.size.y * (0.25 + k * 0.25)), minf(ep * 0.35, 4.0), 0.5)
	if minf(w, h) < SMALL:
		return
	# blower and humidifier
	var bc := Vector2(w * 0.83, h * 0.3)
	var br: float = minf(w * 0.12, h * 0.2)
	O(ci, bc, br, 0.5)
	impeller(ci, bc, br * 0.8, 0.4)
	L(ci, bc + Vector2(-br, 0), Vector2(st.end.x, bc.y), 0.4)
	var hm := Rect2(w * 0.72, h * 0.56, w * 0.24, h * 0.3)
	R(ci, hm, 0.45)
	hatch(ci, inset(hm, 2.0), 3.0, false, 0.2, 20)
	L(ci, Vector2(hm.position.x, hm.get_center().y), Vector2(st.end.x, hm.get_center().y), 0.4)


# a hydraulic power unit: the reservoir with its sight glass and breather, the
# motor-pump standing on its lid, the accumulators, the valve block with its
# solenoids, the pressure gauge and the return filter
static func hpu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tk := Rect2(w * 0.04, h * 0.5, w * 0.62, h * 0.46)
	R(ci, tk, 0.55)
	L(ci, Vector2(tk.position.x, tk.position.y + tk.size.y * 0.3), Vector2(tk.end.x, tk.position.y + tk.size.y * 0.3), 0.25)
	R(ci, Rect2(tk.position.x + tk.size.x * 0.06, tk.position.y + tk.size.y * 0.2, 4.0, tk.size.y * 0.6), 0.45)
	D(ci, Vector2(tk.position.x + tk.size.x * 0.06 + 2.0, tk.position.y + tk.size.y * 0.32), 1.0, 0.6)
	R(ci, Rect2(tk.end.x - tk.size.x * 0.15, tk.position.y - h * 0.05, tk.size.x * 0.08, h * 0.05), 0.45)
	# motor standing, pump below it
	var mw: float = tk.size.x * 0.3
	var mot := Rect2(tk.position.x + tk.size.x * 0.25, h * 0.06, mw, h * 0.32)
	R(ci, mot, 0.5)
	hatch(ci, inset(mot, 2.0), 3.2, true, 0.18, 20)
	R(ci, Rect2(mot.position.x + mw * 0.2, mot.end.y, mw * 0.6, tk.position.y - mot.end.y), 0.45)
	if minf(w, h) < SMALL:
		return
	# accumulators
	for k in 2:
		_bottle(ci, Rect2(w * (0.7 + k * 0.13), h * 0.2, w * 0.1, h * 0.76), true)
	# valve block with solenoids
	var vb := Rect2(tk.position.x + tk.size.x * 0.62, h * 0.24, tk.size.x * 0.34, h * 0.2)
	R(ci, vb, 0.5)
	for k in 3:
		R(ci, Rect2(vb.position.x + vb.size.x * (0.06 + k * 0.32), vb.position.y - h * 0.08, vb.size.x * 0.24, h * 0.08), 0.45)
	gauge(ci, Vector2(vb.get_center().x, vb.end.y + h * 0.08), minf(vb.size.y * 0.35, 5.0), 0.5)


# a valve manifold: the header, branches off it each with its isolation valve and
# handwheel, a pressure gauge on the header
static func manifold(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var hy: float = h * 0.78
	L(ci, Vector2(2, hy), Vector2(w - 2, hy), 0.55, 2.2)
	var n := clampi(int(w / maxf(h * 0.6, 12.0)), 1, 12)
	for i in n:
		var x: float = (i + 0.5) * w / n
		L(ci, Vector2(x, hy), Vector2(x, h * 0.04), 0.5, 1.4)
		var vs: float = minf(w / n * 0.2, h * 0.12)
		var vc := Vector2(x, h * 0.45)
		P(ci, PackedVector2Array([vc + Vector2(-vs * 0.7, -vs), vc + Vector2(vs * 0.7, vs), vc + Vector2(-vs * 0.7, vs), vc + Vector2(vs * 0.7, -vs), vc + Vector2(-vs * 0.7, -vs)]), 0.55)
		L(ci, vc, vc + Vector2(vs * 2.0, 0), 0.45)
		wheel(ci, vc + Vector2(vs * 2.4, 0), vs * 0.7, 0.45)
	gauge(ci, Vector2(w * 0.5 / n * 0.4 + 4.0, hy + h * 0.1), minf(h * 0.08, 4.0), 0.5)


# a charging station: the enclosure with its display and status lights, the
# connector on its holster, the cable coiled on the hook
static func charger(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.1, h * 0.05, w * 0.55, h * 0.9)
	R(ci, b, 0.5)
	screen_face(ci, sub(b, 0.15, 0.1, 0.85, 0.35), 1, 0.4)
	for k in 3:
		D(ci, b.position + b.size * Vector2(0.25 + k * 0.25, 0.45), 1.2, 0.6)
	R(ci, sub(b, 0.3, 0.6, 0.7, 0.8), 0.45)
	O(ci, b.position + b.size * Vector2(0.5, 0.7), minf(b.size.x * 0.1, 4.0), 0.5)
	var hk := Vector2(w * 0.8, h * 0.3)
	O(ci, hk + Vector2(0, h * 0.15), minf(w * 0.14, h * 0.16), 0.4)
	O(ci, hk + Vector2(0, h * 0.15), minf(w * 0.1, h * 0.12), 0.35)
	L(ci, Vector2(b.end.x, b.position.y + b.size.y * 0.85), Vector2(hk.x, hk.y + h * 0.15 + minf(w * 0.14, h * 0.16)), 0.4)


# a linear actuator: the motor alongside, the belt drive housing, the ball-screw
# tube, the rod coming out of it, the clevis eyes at both ends
static func actuator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var B := func(u0: float, v0: float, u1: float, v1: float) -> Rect2: return Rect2(X.call(u0, v0), X.call(u1, v1) - X.call(u0, v0)).abs()
	var e: float = minf(th * 0.18, ln * 0.06)
	O(ci, X.call(e + 1.0, th * 0.62), e * 0.8, 0.55)
	O(ci, X.call(ln - e - 1.0, th * 0.62), e * 0.8, 0.55)
	R(ci, B.call(e * 2.0, th * 0.42, ln * 0.62, th * 0.82), 0.55)
	L(ci, X.call(ln * 0.62, th * 0.62), X.call(ln - e * 2.0, th * 0.62), 0.6, 2.0)
	R(ci, B.call(ln * 0.62, th * 0.5, ln * 0.66, th * 0.74), 0.5)
	# motor on top, its belt housing at the back end
	R(ci, B.call(e * 2.6, th * 0.06, ln * 0.4, th * 0.38), 0.5)
	if th > 14.0:
		hatch(ci, B.call(e * 3.0, th * 0.1, ln * 0.38, th * 0.34), 3.2, not vert, 0.2, 30)
	R(ci, B.call(e * 2.0, th * 0.04, e * 2.6, th * 0.82), 0.45)
	if ln > 40.0:
		var segs := PackedVector2Array()
		var ns := clampi(int(ln * 0.5 / 5.0), 2, 40)
		for k in ns:
			var u: float = e * 2.5 + (k + 0.5) * (ln * 0.62 - e * 3.0) / ns
			segs.append(X.call(u, th * 0.56))
			segs.append(X.call(u + 2.0, th * 0.68))
		S(ci, segs, 0.2)


# a pressure relief valve: the angle body, the inlet flange below, the outlet out
# the side, the bonnet with its spring, the cap and the lifting lever
static func relief(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.42
	var bw: float = minf(w * 0.4, h * 0.3)
	var by: float = h * 0.62
	P(ci, PackedVector2Array([Vector2(cx - bw * 0.5, h * 0.92), Vector2(cx - bw * 0.5, by - bw * 0.3), Vector2(cx - bw * 0.3, by - bw * 0.5), Vector2(cx + bw * 0.3, by - bw * 0.5), Vector2(cx + bw * 0.5, by - bw * 0.3), Vector2(cx + bw * 0.5, h * 0.92)]), 0.55, 1.2)
	flange(ci, Vector2(cx, h * 0.94), Vector2.DOWN, bw * 0.6, 0.55)
	var ox: float = minf(w - 3.0, cx + bw * 2.2)
	L(ci, Vector2(cx + bw * 0.5, by - bw * 0.15), Vector2(ox, by - bw * 0.15), 0.5)
	L(ci, Vector2(cx + bw * 0.5, by + bw * 0.25), Vector2(ox, by + bw * 0.25), 0.5)
	flange(ci, Vector2(ox, by + bw * 0.05), Vector2.RIGHT, bw * 0.4, 0.5)
	# bonnet and spring
	var bn := Rect2(cx - bw * 0.3, h * 0.14, bw * 0.6, by - bw * 0.5 - h * 0.14)
	R(ci, bn, 0.5)
	if bn.size.y > 10.0:
		var pts := PackedVector2Array()
		var nz := clampi(int(bn.size.y / 3.0), 3, 16)
		for k in nz + 1:
			pts.append(Vector2(bn.position.x + (2.0 if k % 2 == 0 else bn.size.x - 2.0), bn.position.y + 2.0 + k * (bn.size.y - 4.0) / nz))
		P(ci, pts, 0.35)
	R(ci, Rect2(cx - bw * 0.18, h * 0.06, bw * 0.36, h * 0.08), 0.5)
	L(ci, Vector2(cx + bw * 0.18, h * 0.1), Vector2(cx + bw * 0.7, h * 0.16), 0.5, 1.4)


# a stator coil segment: the laminated core with its slots, the coil sides in the
# slots, the end turns curling out at both ends
static func stator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var core := Rect2(w * 0.15, h * 0.2, w * 0.7, h * 0.6)
	R(ci, core, 0.55)
	hatch(ci, core, 2.5, true, 0.15, 120)
	var ns := clampi(int(core.size.y / 6.0), 2, 12)
	for k in ns:
		var y: float = core.position.y + (k + 0.5) * core.size.y / ns
		L(ci, Vector2(core.position.x - w * 0.08, y), Vector2(core.end.x + w * 0.08, y), 0.5, 1.6)
	for side in [-1.0, 1.0]:
		var x: float = core.position.x - w * 0.08 if side < 0 else core.end.x + w * 0.08
		for k in ns / 2:
			var y0: float = core.position.y + (2 * k + 0.5) * core.size.y / ns
			var y1: float = core.position.y + (2 * k + 1.5) * core.size.y / ns
			A(ci, Vector2(x, (y0 + y1) * 0.5), (y1 - y0) * 0.5, PI * 0.5 if side < 0 else -PI * 0.5, PI * 1.5 if side < 0 else PI * 0.5, 0.45)


# a load cell / strain-gauge sensor: the flexure body with its gauge window and
# the foil grid, the cable and the mounting bolts
static func gauge_box(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.08, h * 0.25, w * 0.84, h * 0.5)
	R(ci, b, 0.55)
	O(ci, b.position + b.size * Vector2(0.38, 0.5), minf(b.size.y * 0.3, b.size.x * 0.12), 0.45)
	O(ci, b.position + b.size * Vector2(0.62, 0.5), minf(b.size.y * 0.3, b.size.x * 0.12), 0.45)
	L(ci, b.position + b.size * Vector2(0.38, 0.5), b.position + b.size * Vector2(0.62, 0.5), 0.4)
	D(ci, b.position + b.size * Vector2(0.1, 0.5), 1.1, 0.55)
	D(ci, b.position + b.size * Vector2(0.9, 0.5), 1.1, 0.55)
	L(ci, Vector2(b.end.x, b.get_center().y), Vector2(w, h * 0.95), 0.35)


# a rotating beacon: the base, the ribbed lens dome, the lamp inside
static func beacon(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.7)
	var rad: float = minf(w * 0.32, h * 0.55)
	A(ci, c, rad, PI, TAU, 0.55, 1.2)
	var segs := PackedVector2Array()
	for k in 4:
		var a: float = PI + (k + 0.5) * PI / 4.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.2)
		segs.append(c + Vector2.from_angle(a) * rad)
	S(ci, segs, 0.3)
	D(ci, c - Vector2(0, rad * 0.35), 1.6, 0.7)
	R(ci, Rect2(c.x - rad * 1.1, c.y, rad * 2.2, h * 0.22), 0.5)


# a light fitting: the housing, the diffuser and the row of diodes behind it
static func lamp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(3, h * 0.6), Vector2(w - 3, h * 0.6), 0.5)
	if h < 5.0 or w < 14.0:
		return
	var n := clampi(int(w / 5.0), 2, 40)
	var segs := PackedVector2Array()
	for k in n:
		var x: float = 4.0 + (k + 0.5) * (w - 8.0) / n
		segs.append(Vector2(x - 0.6, h * 0.35))
		segs.append(Vector2(x + 0.6, h * 0.35))
	S(ci, segs, 0.6)
	L(ci, Vector2(2, h * 0.15), Vector2(2, h * 0.85), 0.4)
	L(ci, Vector2(w - 2, h * 0.15), Vector2(w - 2, h * 0.85), 0.4)


# ------------------------------------------------------------------ propulsion

# a rocket engine's powerhead, exhaust to the right: the thrust frame and gimbal
# at the back, the turbopump (two pump volutes on one shaft with the turbine
# between) above, the gas generator, the ducts down to the injector dome, the
# combustion chamber in its regenerative cooling jacket, converging to the throat
static func eng_core(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.58
	var cr: float = h * 0.24
	var x_inj: float = w * 0.46
	var x_conv: float = w * 0.82
	# chamber and its convergent section to the throat at the right edge
	var top := PackedVector2Array([Vector2(x_inj, ay - cr), Vector2(x_conv, ay - cr), Vector2(w - 1.0, ay - cr * 0.5)])
	var bot := PackedVector2Array([Vector2(x_inj, ay + cr), Vector2(x_conv, ay + cr), Vector2(w - 1.0, ay + cr * 0.5)])
	P(ci, top, 0.6, 1.2)
	P(ci, bot, 0.6, 1.2)
	# the injector dome
	A(ci, Vector2(x_inj, ay), cr, PI * 0.5, PI * 1.5, 0.55, 1.2)
	L(ci, Vector2(x_inj, ay - cr), Vector2(x_inj, ay + cr), 0.45)
	if minf(w, h) < SMALL:
		return
	# regen jacket: coolant channels along the chamber
	var segs := PackedVector2Array()
	var nch := clampi(int(cr * 2.0 / 4.0), 3, 14)
	for k in nch:
		var f: float = -0.85 + 1.7 * (k + 0.5) / nch
		segs.append(Vector2(x_inj + 2.0, ay + f * cr))
		segs.append(Vector2(x_conv, ay + f * cr))
		segs.append(Vector2(x_conv, ay + f * cr))
		segs.append(Vector2(w - 2.0, ay + f * cr * 0.5))
	S(ci, segs, 0.18)
	# the coolant inlet manifold ring at the throat end
	L(ci, Vector2(x_conv - 3.0, ay - cr - 3.0), Vector2(x_conv - 3.0, ay + cr + 3.0), 0.5, 1.8)
	# turbopump above: fuel pump, turbine, oxidiser pump on one shaft
	var ty: float = h * 0.2
	var pr: float = minf(h * 0.12, w * 0.07)
	var p1 := Vector2(w * 0.3, ty)
	var p2 := Vector2(w * 0.66, ty)
	O(ci, p1, pr, 0.55)
	impeller(ci, p1, pr * 0.75, 0.4)
	O(ci, p2, pr, 0.55)
	impeller(ci, p2, pr * 0.75, 0.4)
	L(ci, p1, p2, 0.45, 1.4)
	var tb := Rect2(w * 0.43, ty - pr * 0.8, w * 0.1, pr * 1.6)
	R(ci, tb, 0.5)
	hatch(ci, inset(tb, 2.0), 3.0, true, 0.3, 10)
	# the turbine exhaust duct up and out
	P(ci, PackedVector2Array([Vector2(tb.get_center().x, tb.position.y), Vector2(tb.get_center().x, h * 0.03), Vector2(tb.end.x + w * 0.12, h * 0.03)]), 0.4)
	# gas generator feeding the turbine
	var gg := Rect2(w * 0.12, h * 0.36, w * 0.08, h * 0.16)
	vessel_v(ci, gg, 0.5)
	L(ci, Vector2(gg.get_center().x, gg.position.y), Vector2(tb.position.x, ty + pr * 0.5), 0.4)
	# pump discharges down to the injector, with their main valves
	for pc in [p1, p2]:
		var down_x: float = x_inj + (cr * 0.4 if pc == p1 else -cr * 0.1)
		P(ci, PackedVector2Array([pc + Vector2(0, pr), Vector2(pc.x, ay - cr * 1.3), Vector2(down_x, ay - cr * 1.3), Vector2(down_x, ay - cr)]), 0.45, 1.2)
		var vc := Vector2((pc.x + down_x) * 0.5, ay - cr * 1.3)
		P(ci, PackedVector2Array([vc + Vector2(-3, -3), vc + Vector2(3, 3), vc + Vector2(3, -3), vc + Vector2(-3, 3), vc + Vector2(-3, -3)]), 0.55)
	# propellant inlets from the tanks
	L(ci, Vector2(p1.x, 0.0), Vector2(p1.x, ty - pr), 0.45, 1.2)
	L(ci, Vector2(p2.x + pr * 0.5, 0.0), Vector2(p2.x + pr * 0.5, ty - pr * 0.8), 0.45, 1.2)
	# the thrust frame and gimbal block at the back
	var gb := Vector2(w * 0.06, ay)
	O(ci, gb, minf(h * 0.06, 6.0), 0.6)
	for e in [-1.0, 1.0]:
		L(ci, gb, Vector2(x_inj - cr * 0.6, ay + e * cr * 0.8), 0.45, 1.2)
		L(ci, gb, Vector2(w * 0.02, ay + e * h * 0.3), 0.4)
	# a gimbal actuator
	L(ci, Vector2(w * 0.02, h * 0.92), Vector2(x_inj + cr * 0.5, ay + cr), 0.45, 1.6)


# a bell nozzle (its outline is the piece): the stiffener rings, the coolant tubes
# running its length, the inlet manifold at the throat and the exit ring
static func nozzle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var hh := func(t: float) -> float: return lerpf(0.75, 1.5, t) / 3.0 * h * 0.96
	var segs := PackedVector2Array()
	for i in 5:
		var t := (i + 1) / 6.0
		var x := w * t
		segs.append(Vector2(x, h * 0.5 - hh.call(t)))
		segs.append(Vector2(x, h * 0.5 + hh.call(t)))
	S(ci, segs, 0.28)
	if minf(w, h) >= SMALL:
		var nt := clampi(int(h / 9.0), 3, 12)
		for k in nt:
			var f: float = -0.85 + 1.7 * (k + 0.5) / nt
			var pts := PackedVector2Array()
			for e in 7:
				var t: float = e / 6.0
				pts.append(Vector2(w * t, h * 0.5 + f * hh.call(t)))
			P(ci, pts, 0.14)
	L(ci, Vector2(2.0, h * 0.5 - hh.call(0.0) - 2.0), Vector2(2.0, h * 0.5 + hh.call(0.0) + 2.0), 0.55, 2.0)
	L(ci, Vector2(w - 2.0, h * 0.5 - hh.call(1.0)), Vector2(w - 2.0, h * 0.5 + hh.call(1.0)), 0.5, 1.8)


# a winch / cable reel end-on: the flange with its lightening holes, the drum, the
# turns of cable wound on it, the hub, the cable paying off; beside a wide one,
# its gearmotor and the band brake
static func reel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var rad: float = minf(w, h) * 0.44
	var c := Vector2(w - rad - 2.0 if w > h * 1.3 else w * 0.5, h * 0.5)
	O(ci, c, rad, 0.55, 1.2)
	O(ci, c, rad * 0.45, 0.5)
	if rad > 10.0:
		for k in 4:
			O(ci, c, rad * (0.52 + k * 0.08), 0.2)
		for k in 6:
			O(ci, c + Vector2.from_angle(TAU * k / 6.0 + 0.3) * rad * 0.9, rad * 0.05, 0.35)
	O(ci, c, rad * 0.14, 0.55)
	D(ci, c, 1.4, 0.6)
	L(ci, c + Vector2(0, -rad * 0.76), Vector2(c.x - rad * 1.2, c.y - rad * 0.76), 0.5, 1.4)
	if w > h * 1.3:
		var gl: float = minf(c.x - rad - 10.0, h * 1.2)
		var gm := Rect2(c.x - rad - 6.0 - gl, h * 0.25, gl, h * 0.5)
		motor(ci, gm, false, 0.5)
		L(ci, Vector2(gm.end.x, c.y), c, 0.5, 1.6)


# a roller / drum end-on: the shell, the bearing ring, the hub and its bolt circle
static func drum(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.42
	O(ci, c, rad, 0.55, 1.2)
	O(ci, c, rad * 0.78, 0.3)
	O(ci, c, rad * 0.4, 0.5)
	O(ci, c, rad * 0.15, 0.55)
	var n := 6 if rad > 10.0 else 4
	for i in n:
		D(ci, c + Vector2.from_angle(TAU * i / n) * rad * 0.28, 0.9, 0.5)
		if rad > 14.0:
			O(ci, c + Vector2.from_angle(TAU * (i + 0.5) / n) * rad * 0.6, rad * 0.1, 0.3)


# a hook block: the cheek plates round the sheaves, the swivel, the hook with its
# safety latch
static func hook(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bw: float = minf(w * 0.7, h * 0.7)
	var blk := Rect2(w * 0.5 - bw * 0.5, h * 0.04, bw, h * 0.4)
	R(ci, blk, 0.55)
	var ns := 2 if bw > 20.0 else 1
	for k in ns:
		var sc := Vector2(blk.position.x + blk.size.x * (0.5 if ns == 1 else 0.3 + k * 0.4), blk.position.y + blk.size.y * 0.45)
		O(ci, sc, minf(blk.size.x * 0.18, blk.size.y * 0.36), 0.5)
		D(ci, sc, 1.0, 0.55)
	R(ci, Rect2(w * 0.5 - bw * 0.1, blk.end.y, bw * 0.2, h * 0.1), 0.5)
	L(ci, Vector2(w * 0.5, blk.end.y + h * 0.1), Vector2(w * 0.5, h * 0.66), 0.55, 1.6)
	var hr: float = minf(w * 0.22, h * 0.16)
	A(ci, Vector2(w * 0.5, h * 0.66 + hr), hr, -PI * 0.5, PI * 1.15, 0.6, 1.6)
	L(ci, Vector2(w * 0.5, h * 0.66), Vector2(w * 0.5 + hr * 0.9, h * 0.66 + hr * 0.6), 0.45)


# a spherical pressure tank: its girth weld and the mounting tabs round its
# equator, the propellant management vanes fanning up from the outlet, the
# fill-and-drain valve on top
static func sphere_tank(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.44
	O(ci, c, rad, 0.6, 1.2)
	L(ci, c + Vector2(-rad, 0), c + Vector2(rad, 0), 0.4)
	for e in [-1.0, 1.0]:
		R(ci, Rect2(c.x + e * rad - (6.0 if e < 0 else 0.0), c.y - 2.0, 6.0, 4.0), 0.5)
	if rad > 14.0:
		# the vanes run up the wall from the outlet, the sponge over the outlet
		A(ci, c, rad * 0.86, PI * 0.5 + 0.12, PI * 0.5 + 2.0, 0.3)
		A(ci, c, rad * 0.86, PI * 0.5 - 2.0, PI * 0.5 - 0.12, 0.3)
		hatch(ci, Rect2(c.x - rad * 0.18, c.y + rad * 0.66, rad * 0.36, rad * 0.2), 3.0, true, 0.3, 12)
		bolts(ci, c + Vector2(-rad * 0.9, 0), c + Vector2(rad * 0.9, 0), clampi(int(rad / 6.0), 3, 20), 0.35, 0.8)
	L(ci, c + Vector2(0, rad), Vector2(c.x, minf(h - 1.0, c.y + rad + 6.0)), 0.5, 1.4)
	L(ci, c + Vector2(0, -rad), Vector2(c.x, maxf(1.0, c.y - rad - 6.0)), 0.5, 1.4)
	if rad > 30.0 and p != null:
		plate(ci, Rect2(c.x - 26.0, c.y + rad * 0.3, 52.0, 10.0), p.tag, font, 0.4)


# a reaction control thruster quad: the mounting block with its heater pad, four
# small thrusters pointing out its sides, their valves
static func rcs_quad(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var s: float = minf(w, h)
	var blk := Rect2(c - Vector2(w * 0.2, h * 0.25), Vector2(w * 0.4, h * 0.5))
	R(ci, blk, 0.55)
	hatch(ci, inset(blk, 2.0), 3.0, true, 0.2, 10)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var base: Vector2 = c + d * Vector2(w * 0.2, h * 0.25).abs()
		var t: Vector2 = d.orthogonal()
		var ln: float = (w * 0.28 if d.x != 0.0 else h * 0.22)
		var nw: float = s * 0.08
		P(ci, PackedVector2Array([base + t * nw * 0.5, base + d * ln + t * nw * 1.4, base + d * ln - t * nw * 1.4, base - t * nw * 0.5]), 0.55)
		D(ci, base - d * 2.0, 0.9, 0.55)


# a dish antenna on its pedestal: the reflector's profile, the feed horn held on
# its struts at the focus, the subreflector, the elevation and azimuth axes
static func radar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w > h * 2.5:
		# a flat phased array: the radiating elements in rows, the T/R modules behind
		R(ci, Rect2(2, h * 0.15, w - 4, h * 0.7), 0.5)
		var segs := PackedVector2Array()
		var nx := clampi(int(w / 6.0), 2, 80)
		for i in nx:
			var x: float = 2.0 + (i + 0.5) * (w - 4.0) / nx
			segs.append(Vector2(x, h * 0.2))
			segs.append(Vector2(x, h * 0.5))
		S(ci, segs, 0.3)
		hatch(ci, Rect2(4, h * 0.56, w - 8, h * 0.25), 8.0, true, 0.2, 40)
		return
	var s: float = minf(w, h)
	var vx: float = w * 0.62
	var dr: float = h * 0.46
	var pts := PackedVector2Array()
	for k in 13:
		var t: float = -1.0 + 2.0 * k / 12.0
		pts.append(Vector2(vx - dr * 0.35 * t * t, h * 0.5 + t * dr))
	P(ci, pts, 0.6, 1.4)
	var fx: float = vx - dr * 0.95
	L(ci, Vector2(vx - dr * 0.35, h * 0.5 - dr), Vector2(fx, h * 0.5), 0.35)
	L(ci, Vector2(vx - dr * 0.35, h * 0.5 + dr), Vector2(fx, h * 0.5), 0.35)
	A(ci, Vector2(fx - s * 0.03, h * 0.5), s * 0.07, -0.9, 0.9, 0.55)
	R(ci, Rect2(vx - s * 0.03, h * 0.5 - s * 0.06, s * 0.08, s * 0.12), 0.5)
	# the pedestal
	L(ci, Vector2(vx + s * 0.05, h * 0.5), Vector2(w * 0.86, h * 0.5), 0.5, 1.4)
	O(ci, Vector2(w * 0.86, h * 0.5), s * 0.06, 0.55)
	R(ci, Rect2(w * 0.8, h * 0.5, w * 0.12, h * 0.46), 0.45)


# ------------------------------------------------------------------ the older kinds

# an engine's front end (its powerhead): the two propellant feed lines in through
# their gimbal bellows and main valves, the turbopump between them, the injector
# manifold dome where it meets the chamber (to the right)
static func eng_front(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.5
	# injector dome on the right
	var dr: float = minf(h * 0.36, w * 0.13)
	var dx: float = w - dr - 2.0
	A(ci, Vector2(dx, ay), dr, -PI * 0.5, PI * 0.5, 0.6, 1.4)
	L(ci, Vector2(dx, ay - h * 0.36), Vector2(dx, ay + h * 0.36), 0.55, 1.4)
	L(ci, Vector2(w * 0.9, ay - h * 0.2), Vector2(w * 0.9, ay + h * 0.2), 0.3)
	# turbopump
	var tc := Vector2(w * 0.5, ay)
	var tr: float = minf(h * 0.18, w * 0.14)
	O(ci, tc, tr, 0.6, 1.2)
	impeller(ci, tc, tr * 0.72, 0.45)
	R(ci, Rect2(tc.x - tr * 0.5, tc.y - tr * 2.0, tr, tr * 1.0), 0.45)
	E_hatch(ci, Rect2(tc.x - tr * 0.45, tc.y - tr * 1.95, tr * 0.9, tr * 0.9))
	# the two feed lines with bellows and valves
	for sg in [-1.0, 1.0]:
		var y: float = ay + sg * h * 0.34
		L(ci, Vector2(1, y - 3.0), Vector2(minf(w * 0.8, dx), y - 3.0), 0.5)
		L(ci, Vector2(1, y + 3.0), Vector2(minf(w * 0.8, dx), y + 3.0), 0.5)
		var segs := PackedVector2Array()
		for k in 5:
			var x: float = w * 0.12 + k * 3.0
			segs.append(Vector2(x, y - 4.5))
			segs.append(Vector2(x, y + 4.5))
		S(ci, segs, 0.4)
		var vc := Vector2(w * 0.32, y)
		P(ci, PackedVector2Array([vc + Vector2(-4, -4), vc + Vector2(4, 4), vc + Vector2(4, -4), vc + Vector2(-4, 4), vc + Vector2(-4, -4)]), 0.6)
		L(ci, Vector2(w * 0.8, y), Vector2(dx, y - sg * h * 0.1), 0.45, 1.4)
		L(ci, Vector2(tc.x, y), tc + Vector2(0, sg * tr), 0.4)


static func E_hatch(ci: CanvasItem, r: Rect2) -> void:
	hatch(ci, r, 3.0, true, 0.25, 20)


# a small pressure-fed engine: the valves on its feed lines, the injector head, the
# combustion chamber and its bell (exhaust right), the gimbal mount
static func engine_s(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 1.6, 1.0)), 1, 6)
	var uw: float = w / n
	for i in n:
		var x0: float = i * uw
		var ay: float = h * 0.5
		var cr: float = h * 0.2
		var cx0: float = x0 + uw * 0.3
		var cx1: float = x0 + uw * 0.55
		R(ci, Rect2(x0 + uw * 0.22, ay - cr * 1.1, uw * 0.08, cr * 2.2), 0.55)
		P(ci, PackedVector2Array([Vector2(cx0, ay - cr), Vector2(cx1, ay - cr), Vector2(cx1 + uw * 0.06, ay - cr * 0.5), Vector2(x0 + uw * 0.98, ay - h * 0.46), ]), 0.6, 1.2)
		P(ci, PackedVector2Array([Vector2(cx0, ay + cr), Vector2(cx1, ay + cr), Vector2(cx1 + uw * 0.06, ay + cr * 0.5), Vector2(x0 + uw * 0.98, ay + h * 0.46), ]), 0.6, 1.2)
		L(ci, Vector2(x0 + uw * 0.98, ay - h * 0.46), Vector2(x0 + uw * 0.98, ay + h * 0.46), 0.45)
		var segs := PackedVector2Array()
		for k in 4:
			var t: float = (k + 1) / 5.0
			var x: float = lerpf(cx1 + uw * 0.06, x0 + uw * 0.98, t)
			var hh: float = lerpf(cr * 0.5, h * 0.46, t)
			segs.append(Vector2(x, ay - hh))
			segs.append(Vector2(x, ay + hh))
		S(ci, segs, 0.22)
		for sg in [-1.0, 1.0]:
			var y: float = ay + sg * cr * 0.6
			L(ci, Vector2(x0 + 2.0, y), Vector2(x0 + uw * 0.22, y), 0.45)
			var vc := Vector2(x0 + uw * 0.12, y)
			P(ci, PackedVector2Array([vc + Vector2(-3, -2.5), vc + Vector2(3, 2.5), vc + Vector2(3, -2.5), vc + Vector2(-3, 2.5), vc + Vector2(-3, -2.5)]), 0.55)
		O(ci, Vector2(x0 + uw * 0.26, ay - cr * 1.3), 1.8, 0.55)


# a disc brake caliper on the edge of its disc: the disc's rim, the caliper body
# straddling it, the pistons and pads, the hydraulic line
static func brake(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var dy: float = h * 0.5
	L(ci, Vector2(1, dy - h * 0.12), Vector2(w - 1, dy - h * 0.12), 0.45)
	L(ci, Vector2(1, dy + h * 0.12), Vector2(w - 1, dy + h * 0.12), 0.45)
	var segs := PackedVector2Array()
	for k in clampi(int(w / 5.0), 2, 60):
		var x: float = 2.0 + k * 5.0
		segs.append(Vector2(x, dy - h * 0.12))
		segs.append(Vector2(x + 2.0, dy + h * 0.12))
	S(ci, segs, 0.15)
	var n := clampi(int(w / (h * 1.8)), 1, 6)
	for i in n:
		var cx: float = (i + 0.5) * w / n
		var cw: float = minf(w / n * 0.7, h * 1.2)
		R(ci, Rect2(cx - cw * 0.5, h * 0.04, cw, h * 0.92), 0.6, 1.2)
		R(ci, Rect2(cx - cw * 0.35, dy - h * 0.2, cw * 0.7, h * 0.06), 0.55)
		R(ci, Rect2(cx - cw * 0.35, dy + h * 0.14, cw * 0.7, h * 0.06), 0.55)
		for f in [0.3, 0.7]:
			O(ci, Vector2(cx - cw * 0.5 + cw * f, h * 0.16), minf(cw * 0.12, h * 0.08), 0.45)
		L(ci, Vector2(cx + cw * 0.5, h * 0.12), Vector2(cx + cw * 0.5 + 4.0, h * 0.04), 0.4)


# a manipulator arm folded at rest: its base and turntable, the shoulder, the
# upper and lower arm with their actuator cylinders, the wrist, the gripper
static func arm(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(th - v, ln - u) if vert else Vector2(u, v)
	var base: Vector2 = X.call(ln * 0.08, th * 0.82)
	R(ci, Rect2(X.call(1.0, th * 0.9), X.call(ln * 0.2, th - 1.0) - X.call(1.0, th * 0.9)).abs(), 0.6, 1.2)
	O(ci, base, minf(th, ln) * 0.12, 0.6, 1.2)
	var elbow: Vector2 = X.call(ln * 0.55, th * 0.28)
	var wrist: Vector2 = X.call(ln * 0.86, th * 0.62)
	for seg in [[base, elbow, 0.14], [elbow, wrist, 0.1]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var t: Vector2 = (b - a).normalized().orthogonal() * minf(th, ln) * float(seg[2]) * 0.5
		P(ci, PackedVector2Array([a + t, b + t, b - t, a - t, a + t]), 0.55, 1.2)
		L(ci, a.lerp(b, 0.15) + t * 1.8, a.lerp(b, 0.7) + t * 1.8, 0.45, 1.4)
	O(ci, elbow, minf(th, ln) * 0.09, 0.6)
	O(ci, wrist, minf(th, ln) * 0.07, 0.6)
	var d: Vector2 = (wrist - elbow).normalized()
	var g: Vector2 = wrist + d * minf(th, ln) * 0.12
	L(ci, wrist, g, 0.55, 1.6)
	for s in [-1.0, 1.0]:
		var o: Vector2 = d.orthogonal() * s * minf(th, ln) * 0.07
		P(ci, PackedVector2Array([g + o * 0.4, g + o, g + o + d * minf(th, ln) * 0.1]), 0.6, 1.4)


# a docking port: the ring flange with its bolt circle, the capture latches and the
# guide petals standing proud of it, the seal, the hatch behind
static func dock(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	L(ci, X.call(ln * 0.06, th * 0.4), X.call(ln * 0.94, th * 0.4), 0.65, 2.0)
	L(ci, X.call(ln * 0.06, th * 0.55), X.call(ln * 0.94, th * 0.55), 0.5, 1.4)
	bolts(ci, X.call(ln * 0.08, th * 0.475), X.call(ln * 0.92, th * 0.475), clampi(int(ln / 7.0), 3, 16), 0.5, 0.9)
	# guide petals and latches out the face (v toward 0)
	for f in [0.12, 0.88]:
		P(ci, PackedVector2Array([X.call(ln * (f - 0.08), th * 0.4), X.call(ln * f, th * 0.04), X.call(ln * (f + 0.08), th * 0.4)]), 0.55, 1.2)
	for f in [0.35, 0.65]:
		L(ci, X.call(ln * f, th * 0.4), X.call(ln * f, th * 0.18), 0.55, 1.4)
		L(ci, X.call(ln * f, th * 0.18), X.call(ln * f + (2.5 if f < 0.5 else -2.5), th * 0.22), 0.55, 1.4)
	# the hatch and the tunnel behind
	L(ci, X.call(ln * 0.18, th * 0.55), X.call(ln * 0.18, th * 0.96), 0.45)
	L(ci, X.call(ln * 0.82, th * 0.55), X.call(ln * 0.82, th * 0.96), 0.45)
	L(ci, X.call(ln * 0.24, th * 0.8), X.call(ln * 0.76, th * 0.8), 0.5, 1.4)
	O(ci, X.call(ln * 0.5, th * 0.8), minf(ln, th) * 0.08, 0.5)


# an ultra-low freezer: the insulated door with its gasket and lever handle, the
# controller with its temperature readout, the compressor bay grille at the foot;
# a wide one is a bank of them
static func freezer(ci: CanvasItem, r: Rect2, p, font: Font) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / maxf(h * 0.6, 0.8 * M)), 1, 8)
	var uw: float = w / n
	for i in n:
		var b := Rect2(i * uw + 1.5, 1.5, uw - 3.0, h - 3.0)
		R(ci, b, 0.55)
		var dr := Rect2(b.position.x + b.size.x * 0.06, b.position.y + b.size.y * 0.16, b.size.x * 0.88, b.size.y * 0.66)
		R(ci, dr, 0.5)
		R(ci, E_inset(dr, 2.5), 0.25)
		L(ci, Vector2(dr.end.x - dr.size.x * 0.1, dr.get_center().y - dr.size.y * 0.15), Vector2(dr.end.x - dr.size.x * 0.1, dr.get_center().y + dr.size.y * 0.15), 0.65, 2.0)
		var disp := Rect2(b.position.x + b.size.x * 0.2, b.position.y + b.size.y * 0.03, b.size.x * 0.6, b.size.y * 0.1)
		R(ci, disp, 0.5)
		if font != null and disp.size.y >= 8.0 and disp.size.x >= 24.0:
			T(ci, font, Vector2(disp.position.x + 2.0, disp.end.y - 2.0), "-80°C", disp.size.x - 3.0, clampi(int(disp.size.y * 0.8), 7, 9), 0.55)
		louvres(ci, Rect2(b.position.x + b.size.x * 0.15, b.end.y - b.size.y * 0.15, b.size.x * 0.7, b.size.y * 0.12), 0.3)


static func E_inset(r: Rect2, d: float) -> Rect2:
	return inset(r, d)


# a drum (barrel) standing: its rolling hoops, the chime, the bung; a long thin one
# is a gun barrel (the bore, the rifling, the muzzle brake, the bore evacuator)
static func barrel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w > h * 4.0:
		L(ci, Vector2(1, h * 0.2), Vector2(w * 0.9, h * 0.25), 0.6, 1.2)
		L(ci, Vector2(1, h * 0.8), Vector2(w * 0.9, h * 0.75), 0.6, 1.2)
		L(ci, Vector2(1, h * 0.5), Vector2(w, h * 0.5), 0.2)
		R(ci, Rect2(w * 0.4, h * 0.1, w * 0.08, h * 0.8), 0.5)
		R(ci, Rect2(w * 0.9, 1, w * 0.1 - 1.0, h - 2.0), 0.6)
		for f in [0.93, 0.97]:
			L(ci, Vector2(w * f, 2), Vector2(w * f, h - 2), 0.45)
		return
	var n := clampi(roundi(w / maxf(h * 0.7, 6.0)), 1, 12)
	var dw: float = w / n
	for i in n:
		var d := Rect2(i * dw + dw * 0.08, 1.5, dw * 0.84, h - 3.0)
		R(ci, d, 0.55)
		for f in [0.33, 0.66]:
			L(ci, Vector2(d.position.x, d.position.y + d.size.y * f), Vector2(d.end.x, d.position.y + d.size.y * f), 0.45, 1.4)
		L(ci, Vector2(d.position.x, d.position.y + 2.0), Vector2(d.end.x, d.position.y + 2.0), 0.35)
		O(ci, Vector2(d.position.x + d.size.x * 0.75, d.position.y + 1.0), 1.5, 0.55)


# a naval gun turret: the faceted gunhouse, the barrel out of its mantlet, the
# trunnion, the ring and the ammunition hoist below
static func turret(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	P(ci, PackedVector2Array([Vector2(w * 0.08, h * 0.7), Vector2(w * 0.14, h * 0.18), Vector2(w * 0.5, h * 0.08), Vector2(w * 0.62, h * 0.3), Vector2(w * 0.62, h * 0.7), Vector2(w * 0.08, h * 0.7)]), 0.65, 1.4)
	R(ci, Rect2(w * 0.58, h * 0.3, w * 0.06, h * 0.22), 0.55)
	L(ci, Vector2(w * 0.64, h * 0.38), Vector2(w * 0.99, h * 0.36), 0.6, 1.4)
	L(ci, Vector2(w * 0.64, h * 0.44), Vector2(w * 0.99, h * 0.42), 0.6, 1.4)
	O(ci, Vector2(w * 0.5, h * 0.41), h * 0.08, 0.5)
	R(ci, Rect2(w * 0.94, h * 0.32, w * 0.05, h * 0.14), 0.5)
	L(ci, Vector2(w * 0.06, h * 0.72), Vector2(w * 0.66, h * 0.72), 0.55, 1.8)
	bolts(ci, Vector2(w * 0.08, h * 0.76), Vector2(w * 0.64, h * 0.76), 8, 0.45, 0.9)
	R(ci, Rect2(w * 0.28, h * 0.78, w * 0.12, h * 0.2), 0.5)
	hatch(ci, Rect2(w * 0.29, h * 0.8, w * 0.1, h * 0.16), 2.5, false, 0.3, 10)


# a box missile launcher: the canisters side by side, each with its frangible
# cover, the blast vents along the base
static func launcher(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(int(w / maxf(h * 1.2, 6.0)), 2, 40)
	var cw: float = w / n
	for i in n:
		R(ci, Rect2(i * cw + 0.8, 1, cw - 1.6, h - 2.0), 0.5)
		L(ci, Vector2(i * cw + 2.0, 2.0), Vector2((i + 1) * cw - 2.0, h - 2.0), 0.25)


# a close-in weapon system: the rotary gun, its radar dome above, the mount
static func ciws(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	A(ci, Vector2(w * 0.5, h * 0.42), w * 0.22, PI, TAU, 0.6, 1.4)
	R(ci, Rect2(w * 0.28, h * 0.42, w * 0.44, h * 0.3), 0.6, 1.2)
	for k in 3:
		L(ci, Vector2(w * 0.04, h * (0.54 + k * 0.05)), Vector2(w * 0.28, h * (0.54 + k * 0.05)), 0.5, 1.2)
	R(ci, Rect2(w * 0.02, h * 0.5, w * 0.04, h * 0.16), 0.55)
	R(ci, Rect2(w * 0.72, h * 0.48, w * 0.14, h * 0.2), 0.5)
	L(ci, Vector2(w * 0.24, h * 0.96), Vector2(w * 0.76, h * 0.96), 0.55, 1.8)
	L(ci, Vector2(w * 0.4, h * 0.72), Vector2(w * 0.36, h * 0.96), 0.5)
	L(ci, Vector2(w * 0.6, h * 0.72), Vector2(w * 0.64, h * 0.96), 0.5)


# a gun mount: the slewing ring with its roller race and the training gear, the base
static func gun_mount(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	A(ci, Vector2(w * 0.5, 0), w * 0.4, 0.0, PI, 0.55, 1.4)
	L(ci, Vector2(w * 0.08, h * 0.5), Vector2(w * 0.92, h * 0.5), 0.55, 1.6)
	var segs := PackedVector2Array()
	for k in clampi(int(w * 0.8 / 4.0), 3, 60):
		var x: float = w * 0.1 + k * 4.0
		segs.append(Vector2(x, h * 0.5))
		segs.append(Vector2(x, h * 0.56))
	S(ci, segs, 0.35)
	for k in 7:
		O(ci, Vector2(w * (0.14 + k * 0.12), h * 0.66), minf(h * 0.06, 3.0), 0.45)
	R(ci, Rect2(w * 0.08, h * 0.76, w * 0.84, h * 0.2), 0.5)
	O(ci, Vector2(w * 0.86, h * 0.4), h * 0.1, 0.5)


# a decoy launcher: the tubes at their elevation, the cartridges' caps
static func decoy(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for i in 3:
		var x := w * (0.2 + i * 0.3)
		var a := Vector2(x, h * 0.95)
		var b := Vector2(x + w * 0.12, h * 0.1)
		var t: Vector2 = (b - a).normalized().orthogonal() * 3.0
		P(ci, PackedVector2Array([a + t, b + t, b - t, a - t]), 0.55)
		L(ci, b + t * 1.3, b - t * 1.3, 0.65, 1.6)
	L(ci, Vector2(1, h * 0.96), Vector2(w - 1, h * 0.96), 0.5, 1.4)
