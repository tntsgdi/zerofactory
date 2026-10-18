extends SceneTree
# P.7 concept sheet (2026-10-18): the berth terminal's contract market redone
# in an industrial-terminal style, three directions, the same sample data in
# each (the pinned story contract and two offers, the second chosen), plus the
# power-on self-test drawn frame by frame. Nothing here is the game's own UI:
# it is a mock-up for the player to choose from. No saves are touched.
# tools/run_test.sh tests/terminal_concepts.gd -- a|b|c|boot

const Cap = preload("res://tests/cap.gd")
const W := 1920.0
const H := 1080.0
var sheet: Node2D
var font: Font
var font_l: Font
var font_b: Font
var font_s: Font
var style := "a"
var t := 1.0            # the self-test's clock, for "boot"
var ships := {}

const TOP := [["资金", "$41,250", false], ["贷款", "$36,000", true], ["每单应付", "$20,720", false], ["声望", "认证", false]]
const TABS := ["合同市场", "设备商店", "船坞管理", "技能书"]
const CARDS := [
	{"pin": true, "id": "S09-001", "ship": "s09", "name": "雨燕级维修穿梭机", "len": 26, "value": "$82,000", "fee": "$0", "time": "14 分钟"},
	{"scope": "完整拆解", "stars": 1, "risk": "低风险", "id": "003-S-62", "ship": "s09", "name": "S-62 · 雨燕级维修穿梭机 · 26 m", "net": "$72,000", "rate": "$5,140", "time": "14", "badge": "净赚最高",
		"value": "$82,000", "fee": "−$10,000", "due": "−$0", "task": "拆完整艘船：指定设备完整送设备口，其余分类送对回收口", "cargo": "CRATE-1 工业金属 · CRATE-2 精密仪器"},
	{"scope": "分段拆解", "stars": 1, "risk": "低风险", "id": "003-CP-27", "ship": "pod", "name": "CP-27 · 货运吊舱 · 21 m", "net": "$45,800", "rate": "$5,730", "time": "8", "badge": "每分钟最划算",
		"value": "$52,300", "fee": "−$6,500", "due": "−$0", "task": "只拆 27 号肋位以后的区段（D、E 舱、发动机和尾部船壳）", "cargo": "CG-1 电子设备 · CG-2 工业金属 · CG-3 HEAVY"},
]
const SEL := 1


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		if a in ["a", "b", "c", "boot"]:
			style = a
	_run()


func _run() -> void:
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	for id in ["s09", "pod"]:
		ships[id] = Ship.load_data(id)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lv in 7:
		env.set_glow_level(lv, [0.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.0][lv])
	we.environment = env
	root.add_child(we)
	sheet = Node2D.new()
	sheet.draw.connect(_draw_sheet)
	root.add_child(sheet)
	if style == "boot":
		var marks := [0.15, 0.45, 0.8, 1.15, 1.5, 2.2]
		for i in marks.size():
			t = marks[i]
			sheet.queue_redraw()
			for f in 3:
				await process_frame
			Cap.save(root, "res://tests/out/termc_boot_%d.png" % i)
	else:
		for f in 6:
			await process_frame
		Cap.save(root, "res://tests/out/termc_%s.png" % style)
	quit()


func _draw_sheet() -> void:
	match style:
		"a": _style_a(9.0)
		"b": _style_b()
		"c": _style_c()
		"boot": _style_a(t)


# ---------------------------------------------------------------- shared

func txt(s: String, p: Vector2, size: int, col: Color, f: Font = null, align: int = -1, w: float = -1.0) -> void:
	var fo := f if f != null else font
	var x := p.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	sheet.draw_string(fo, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


func tw(s: String, size: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# a ship's outline from its file, fitted into r
func ship_outline(id: String, r: Rect2, col: Color, w: float = 1.0) -> void:
	var d: Dictionary = ships[id]
	var bb := Rect2()
	var first := true
	var polys: Array = []
	for pd in d.pieces:
		if pd.kind in ["hull", "hatch", "keel", "beam", "deck", "bulkhead", "strut", "rail"]:
			var pts := PackedVector2Array()
			for q in pd.poly:
				pts.append(Vector2(q[0], q[1]))
				bb = Rect2(pts[pts.size() - 1], Vector2.ZERO) if first else bb.expand(pts[pts.size() - 1])
				first = false
			polys.append(pts)
	var s := minf(r.size.x / maxf(bb.size.x, 0.01), r.size.y / maxf(bb.size.y, 0.01)) * 0.92
	var off := r.get_center() - bb.get_center() * s
	for pts in polys:
		var out := PackedVector2Array()
		for q in pts:
			out.append(q * s + off)
		out.append(out[0])
		sheet.draw_polyline(out, col, w, true)


# a chamfered rectangle (corners cut by c)
func chamfer(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c), Vector2(r.end.x, r.end.y - c),
		Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c)])


func closed(p: PackedVector2Array) -> PackedVector2Array:
	var o := p.duplicate()
	o.append(p[0])
	return o


# part of a closed outline, frac 0..1 of its length, with the pen's bright point
func draw_on(p: PackedVector2Array, frac: float, col: Color, w: float) -> void:
	var pts := closed(p)
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := total * clampf(frac, 0.0, 1.0)
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			out.append(pts[i].lerp(pts[i + 1], left / maxf(seg, 0.001)))
			break
		out.append(pts[i + 1])
		left -= seg
	if out.size() >= 2:
		sheet.draw_polyline(out, col, w, true)
		if frac < 1.0:
			sheet.draw_circle(out[out.size() - 1], w + 1.5, Pal.tint(Pal.AIR, 1.0, 2.4))


func stripes(r: Rect2, a: float, gap: float = 14.0) -> void:
	sheet.draw_rect(r, Color(0.02, 0.02, 0.02, a))
	var x := r.position.x - r.size.y
	var i := 0
	while x < r.end.x:
		if i % 2 == 0:
			var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + gap, r.position.y), Vector2(x + gap, r.end.y)])
			for j in pts.size():
				pts[j] = Vector2(clampf(pts[j].x, r.position.x, r.end.x), pts[j].y)
			sheet.draw_colored_polygon(pts, Pal.heat(0.85 * a, 1.0))
		x += gap
		i += 1


func stars(n: int, p: Vector2, col: Color, dim: Color) -> void:
	for i in 3:
		var c := p + Vector2(i * 20, 0)
		var pts := PackedVector2Array()
		for k in 10:
			pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * (7.0 if k % 2 == 0 else 3.0))
		if i < n:
			sheet.draw_colored_polygon(pts, col)
		else:
			sheet.draw_polyline(closed(pts), dim, 1.0, true)


# ---------------------------------------------------------------- A · HEAVY CONSOLE

# chamfered steel plates with heavy edges, stencil tags, big numbers, warning
# stripes on what is chosen, keys with depth that sink when pressed.
# k: the self-test clock (9 = done)
func _style_a(k: float) -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.022, 0.024, 0.028))
	# the bay wall: faint plate seams and rivets
	var gx := 0.0
	while gx < W:
		ci.draw_line(Vector2(gx, 0), Vector2(gx, H), Color(1, 1, 1, 0.018), 1.0)
		gx += 160.0
	var u := func(a: float, b: float) -> float: return clampf((k - a) / maxf(b - a, 0.001), 0.0, 1.0)
	# power-on: a heat line across, the frame unfolding from it
	if k < 0.4:
		var e: float = u.call(0.0, 0.3)
		ci.draw_rect(Rect2(W * 0.5 - W * 0.5 * e, H * 0.5 - 1, W * e, 2), Pal.heat(1.0, 2.6))
		_self_test(k)
		return
	# --- top bar: the berth's name plate and four readouts
	var tb: float = u.call(0.35, 0.75)
	var plate := Rect2(40, 28, 520, 92)
	draw_on(chamfer(plate, 16), tb, Pal.ink(0.9), 2.5)
	if tb > 0.5:
		ci.draw_colored_polygon(chamfer(plate.grow(-6), 12), Color(0.06, 0.064, 0.072, u.call(0.5, 0.8)))
		stripes(Rect2(plate.position.x + 14, plate.position.y + 14, 40, plate.size.y - 28), u.call(0.55, 0.85), 10.0)
		txt("BERTH 07  ·  CHARON-DISPATCH", plate.position + Vector2(70, 34), 15, Pal.ink(0.6 * u.call(0.6, 0.9)), font_b)
		txt("船坞终端", plate.position + Vector2(70, 74), 34, Pal.ink(0.98 * u.call(0.65, 0.95)), font_s)
	for i in TOP.size():
		var r := Rect2(620 + i * 320, 28, 300, 92)
		var ki: float = u.call(0.45 + i * 0.08, 0.85 + i * 0.08)
		draw_on(chamfer(r, 12), ki, Pal.ink(0.55), 2.0)
		if ki > 0.6:
			var col := Pal.heat(1.0, 1.3) if TOP[i][2] else Pal.ink(0.98)
			txt(TOP[i][0], r.position + Vector2(18, 30), 15, Pal.ink(0.55), font_b)
			# numbers roll up as they come on
			var shown: String = TOP[i][1]
			if ki < 1.0 and shown.begins_with("$"):
				var digits := shown.replace("$", "").replace(",", "")
				shown = Pal.money(snappedf(float(digits) * Pal.ease_out(ki), 10.0))
			txt(shown, r.position + Vector2(r.size.x - 18, 76), 38, col, font_s, 1)
			if TOP[i][2]:
				ci.draw_rect(Rect2(r.position.x + 18, r.end.y - 12, 60, 4), Pal.heat(0.9, 1.4))
	# --- tabs: four keycaps with depth; the chosen one pressed in
	for i in TABS.size():
		var r := Rect2(40 + i * 250, 150, 230, 58)
		var kt: float = u.call(0.7 + i * 0.06, 1.0 + i * 0.06)
		if kt <= 0.0:
			continue
		var down := i == 0
		var depth := 3.0 if down else 8.0
		ci.draw_colored_polygon(chamfer(Rect2(r.position + Vector2(0, depth), r.size), 10), Color(0.0, 0.0, 0.0, 0.8 * kt))
		var top := Rect2(r.position + Vector2(0, 8.0 - depth), r.size)
		ci.draw_colored_polygon(chamfer(top, 10), Color(0.12, 0.125, 0.14, kt) if down else Color(0.075, 0.078, 0.088, kt))
		ci.draw_polyline(closed(chamfer(top, 10)), Pal.heat(kt, 1.4) if down else Pal.ink(0.4 * kt), 2.0 if down else 1.5, true)
		var cap := Rect2(top.position + Vector2(12, 12), Vector2(34, 34))
		ci.draw_rect(cap, Pal.heat(0.9 * kt, 1.2) if down else Pal.ink(0.12 * kt))
		txt(str(i + 1), cap.get_center() + Vector2(0, 8), 20, Color(0.05, 0.05, 0.05, kt) if down else Pal.ink(0.9 * kt), font_s, 0)
		txt(TABS[i], top.position + Vector2(60, 38), 22, Pal.ink((0.98 if down else 0.7) * kt), font_s)
	# --- the cards
	for i in CARDS.size():
		var r := Rect2(40 + i * 620, 240, 600, 650)
		var kc: float = u.call(0.9 + i * 0.12, 1.5 + i * 0.12)
		if kc <= 0.0:
			continue
		_card_a(CARDS[i], r, kc, i == SEL)
	# --- the take key under the chosen card
	var kb: float = u.call(1.6, 1.9)
	if kb > 0.0:
		var br := Rect2(40 + SEL * 620, 912, 600, 84)
		ci.draw_colored_polygon(chamfer(Rect2(br.position + Vector2(0, 10), br.size), 14), Color(0, 0, 0, 0.85 * kb))
		ci.draw_colored_polygon(chamfer(br, 14), Pal.heat(0.92 * kb, 1.05))
		ci.draw_polyline(closed(chamfer(br, 14)), Pal.heat(kb, 1.8), 2.0, true)
		stripes(Rect2(br.position.x + 18, br.position.y + 18, 70, br.size.y - 36), 0.0)
		txt("接单", br.position + Vector2(40, 56), 34, Color(0.04, 0.04, 0.045, kb), font_s)
		var kr := Rect2(br.end.x - 170, br.position.y + 18, 140, 48)
		ci.draw_rect(kr, Color(0.04, 0.04, 0.045, 0.9 * kb))
		txt("ENTER ⏎", kr.get_center() + Vector2(0, 9), 22, Pal.heat(kb, 1.4), font_s, 0)
	# the keys line, stencilled
	txt("1–4 页面   ←→ 选择   ENTER 确认   O 设置   ESC 返回标题", Vector2(40, 1052), 16, Pal.ink(0.45), font_b)
	if k < 2.0:
		_self_test(k)


func _card_a(c: Dictionary, r: Rect2, k: float, on: bool) -> void:
	var ci := sheet
	var u := func(a: float) -> float: return clampf((k - a) / 0.35, 0.0, 1.0)
	var shape := chamfer(r, 22)
	if on:
		ci.draw_colored_polygon(chamfer(r.grow(6), 26), Pal.heat(0.12 * k, 1.0))
	ci.draw_colored_polygon(shape, Color(0.045, 0.048, 0.055, 0.97 * u.call(0.25)))
	draw_on(shape, clampf(k / 0.4, 0.0, 1.0), Pal.heat(1.0, 1.5) if on else (Pal.heat(0.75, 1.1) if c.get("pin", false) else Pal.ink(0.6)), 3.0 if on else 2.0)
	if k < 0.35:
		return
	var a: float = u.call(0.35)
	var x := r.position.x + 34
	var y := r.position.y
	# the header strip: stripes for the chosen or the pinned card, a stencil tag
	var hr := Rect2(r.position.x + 22, y + 22, r.size.x - 44, 46)
	if on or c.get("pin", false):
		stripes(Rect2(hr.position, Vector2(56, hr.size.y)), a, 12.0)
	var head: String = "主线合同 · 置顶" if c.get("pin", false) else c.scope
	txt(head, hr.position + Vector2(72, 32), 24, Pal.ink(0.98 * a), font_s)
	txt("MKT-%02d" % (CARDS.find(c) + 1), Vector2(hr.end.x, hr.position.y + 30), 15, Pal.ink(0.45 * a), font_b, 1)
	ci.draw_line(Vector2(r.position.x + 22, y + 82), Vector2(r.end.x - 22, y + 82), Pal.ink(0.18 * a), 2.0)
	if c.get("pin", false):
		txt(c.id, Vector2(x, y + 150), 54, Pal.ink(0.98 * a), font_l)
		txt(c.name, Vector2(x, y + 190), 22, Pal.ink(0.8 * a), font_s)
		ship_outline(c.ship, Rect2(x, y + 220, r.size.x - 68, 110), Pal.ink(0.75 * a), 1.4)
		var rows := [["船长", "%d m" % c.len], ["预估可回收价值", c.value], ["合同费", c.fee], ["工期", c.time]]
		for i in rows.size():
			var yy := y + 380 + i * 50
			txt(rows[i][0], Vector2(x, yy), 18, Pal.ink(0.55 * a), font_b)
			txt(rows[i][1], Vector2(r.end.x - 34, yy), 26, Pal.ink(0.95 * a), font_s, 1)
		txt("随时可接 · 一直留在这里", Vector2(x, r.end.y - 40), 18, Pal.heat(0.9 * a, 1.2), font_b)
		return
	stars(c.stars, Vector2(x + 6, y + 118), Pal.heat(a, 1.5), Pal.ink(0.4 * a))
	txt(c.risk, Vector2(x + 72, y + 126), 18, Pal.ink(0.75 * a), font_b)
	txt(c.id, Vector2(r.end.x - 34, y + 126), 16, Pal.ink(0.5 * a), font_b, 1)
	txt(c.name, Vector2(x, y + 166), 22, Pal.ink(0.9 * a), font_s)
	# the big number
	txt("预计净赚", Vector2(x, y + 212), 17, Pal.ink(0.55 * a), font_b)
	var net := String(c.net)
	if k < 1.0:
		net = Pal.money(snappedf(float(net.replace("$", "").replace(",", "")) * Pal.ease_out(k), 100.0))
	txt(net, Vector2(x - 4, y + 292), 84, Pal.ink(0.99 * a, 1.05), font_l)
	txt(c.rate + " / 分钟", Vector2(r.end.x - 34, y + 240), 22, Pal.ink(0.92 * a), font_s, 1)
	txt(c.time + " 分钟", Vector2(r.end.x - 34, y + 272), 18, Pal.ink(0.6 * a), font_b, 1)
	var bw := tw(c.badge, 17, font_s) + 26.0
	ci.draw_rect(Rect2(x, y + 310, bw, 32), Pal.tint(Pal.FLUID, 0.9 * a, 1.0))
	txt(c.badge, Vector2(x + 13, y + 333), 17, Color(0.03, 0.05, 0.03, a), font_s)
	ship_outline(c.ship, Rect2(x, y + 356, r.size.x - 68, 96), Pal.ink(0.7 * a), 1.3)
	var rows := [["预估可回收价值", c.value], ["合同费", c.fee], ["本单分期与利息", c.due]]
	for i in rows.size():
		var yy := y + 492 + i * 36
		txt(rows[i][0], Vector2(x, yy), 17, Pal.ink(0.55 * a), font_b)
		txt(rows[i][1], Vector2(r.end.x - 34, yy), 22, Pal.ink(0.92 * a), font_s, 1)
	txt(c.cargo, Vector2(x, r.end.y - 34), 16, Pal.ink(0.6 * a), font_b)


# the power-on self-test: a log typing in at the lower left while it comes up
func _self_test(k: float) -> void:
	var lines := ["CHARON-DISPATCH TERMINAL  v4.12", "POWER ......................... OK", "LINK  BERTH 07 ................ OK",
		"LEDGER  funds / loan / dues ... OK", "MARKET FEED  3 contracts ...... OK", "READY"]
	var a := clampf((2.0 - k) / 0.4, 0.0, 1.0)
	for i in lines.size():
		var start := 0.05 + i * 0.22
		var n := int(clampf((k - start) / 0.2, 0.0, 1.0) * lines[i].length())
		if n <= 0:
			continue
		var col := Pal.tint(Pal.AIR, 0.9 * a, 1.4) if i < lines.size() - 1 else Pal.heat(a, 2.0)
		txt(lines[i].substr(0, n), Vector2(60, H * 0.5 + 40 + i * 26 if k < 0.4 else H - 220 + i * 24), 17, col, font_b)


# ---------------------------------------------------------------- B · DISPATCH CRT

# amber phosphor on black, fixed columns, bracketed fields, an inverted bar
# for what is chosen, function keys along the bottom, scanlines over it all
func _style_b() -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.012, 0.01, 0.006))
	var amber := Color(1.0, 0.62, 0.22)
	var am := func(a: float, k: float = 1.0) -> Color: return Color(amber.r * k, amber.g * k, amber.b * k, a)
	# the frame: ascii-style double rule with corner ticks
	var fr := Rect2(30, 24, W - 60, H - 48)
	ci.draw_rect(fr, am.call(0.55), false, 2.0)
	ci.draw_rect(fr.grow(-6), am.call(0.25), false, 1.0)
	txt("╡ CHARON-DISPATCH // BERTH 07 // 船坞终端 ╞", Vector2(W * 0.5, 34), 20, am.call(0.95, 1.2), font_s, 0)
	# the ledger line
	var lx := 70.0
	for i in TOP.size():
		var lab: String = TOP[i][0]
		var v: String = TOP[i][1]
		txt(lab + " [", Vector2(lx, 100), 22, am.call(0.6), font_b)
		var vx := lx + tw(lab + " [", 22, font_b)
		txt(v, Vector2(vx, 100), 30, am.call(1.0, 1.5) if TOP[i][2] else am.call(0.95, 1.15), font_s)
		txt("]", Vector2(vx + tw(v, 30, font_s) + 4, 100), 22, am.call(0.6), font_b)
		lx += 440
	ci.draw_line(Vector2(50, 124), Vector2(W - 50, 124), am.call(0.35), 1.0)
	txt("> 合同市场  ·  3 份报价  ·  1 份主线置顶_", Vector2(70, 166), 22, am.call(0.85, 1.1), font_b)
	# three columns of fields
	for i in CARDS.size():
		var c: Dictionary = CARDS[i]
		var x := 70.0 + i * 600
		var y := 200.0
		var on := i == SEL
		var colw := 560.0
		if on:
			ci.draw_rect(Rect2(x - 12, y, colw + 24, 46), am.call(0.95, 1.2))
		var head: String = ("[主线·置顶] " + c.id) if c.get("pin", false) else ("[%s] %s" % [c.scope, c.id])
		txt(head, Vector2(x, y + 33), 24, Color(0.05, 0.03, 0.0) if on else am.call(0.95, 1.2), font_s)
		ci.draw_rect(Rect2(x - 12, y, colw + 24, 690), am.call(0.6 if on else 0.25), false, 1.5 if on else 1.0)
		var rows: Array = []
		if c.get("pin", false):
			rows = [["船型", c.name], ["船长", "%d m" % c.len], ["估值", c.value], ["合同费", c.fee], ["工期", c.time]]
		else:
			rows = [["船型", c.name], ["风险", "★".repeat(c.stars) + "☆".repeat(3 - c.stars) + "  " + c.risk], ["每分钟", c.rate], ["工期", c.time + " 分钟"],
				["估值", c.value], ["合同费", c.fee], ["分期", c.due]]
		var yy := y + 90
		if not c.get("pin", false):
			txt("预计净赚", Vector2(x, yy), 20, am.call(0.6), font_b)
			txt(c.net, Vector2(x, yy + 76), 76, am.call(1.0, 1.6) if on else am.call(0.95, 1.2), font_l)
			txt("▲ " + c.badge, Vector2(x + colw, yy + 70), 20, Pal.tint(Pal.FLUID, 0.95, 1.3), font_s, 1)
			yy += 110
		else:
			yy += 10
		ship_outline(c.ship, Rect2(x, yy, colw, 80), am.call(0.75, 1.1), 1.2)
		yy += 120
		for row in rows:
			txt(row[0], Vector2(x, yy), 20, am.call(0.55), font_b)
			var dots := ".".repeat(maxi(2, int((colw - tw(row[0], 20, font_b) - tw(row[1], 22, font_s)) / tw(".", 20, font_b)) - 2))
			txt(dots, Vector2(x + tw(row[0], 20, font_b) + 6, yy), 20, am.call(0.25), font_b)
			txt(row[1], Vector2(x + colw, yy), 22, am.call(0.95, 1.15), font_s, 1)
			yy += 40
	# function keys along the bottom, the chosen tab lit
	for i in TABS.size():
		var r := Rect2(70 + i * 300, 930, 280, 56)
		var lit := i == 0
		ci.draw_rect(r, am.call(0.95, 1.2) if lit else am.call(0.08))
		ci.draw_rect(r, am.call(0.7), false, 1.5)
		txt("F%d %s" % [i + 1, TABS[i]], r.get_center() + Vector2(0, 10), 24, Color(0.05, 0.03, 0.0) if lit else am.call(0.9, 1.1), font_s, 0)
	var kr := Rect2(1330, 930, 520, 56)
	ci.draw_rect(kr, am.call(0.15))
	ci.draw_rect(kr, am.call(0.95, 1.4), false, 2.5)
	txt("[ ENTER ]  接单 → " + CARDS[SEL].id, kr.get_center() + Vector2(0, 10), 24, am.call(1.0, 1.5), font_s, 0)
	txt("← → 选择   O 设置   ESC 返回标题", Vector2(70, 1030), 18, am.call(0.5), font_b)
	# scanlines and a soft vignette
	var y2 := 0.0
	while y2 < H:
		ci.draw_line(Vector2(0, y2), Vector2(W, y2), Color(0, 0, 0, 0.28), 1.0)
		y2 += 3.0
	for i in 8:
		var g := float(i) * 14.0
		ci.draw_rect(Rect2(g, g, W - 2 * g, H - 2 * g), Color(0, 0, 0, 0.05), false, 14.0)


# ---------------------------------------------------------------- C · INDUSTRIAL HMI

# raised grey panels like a plant's control screen: tag plates, status lamps,
# bar gauges, push buttons; amber outlines what is chosen
func _style_c() -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.075, 0.08, 0.088))
	var raised := func(r: Rect2, fill: Color) -> void:
		ci.draw_rect(r, fill)
		ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.16), 2.0)
		ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.12), 2.0)
		ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0, 0, 0, 0.6), 2.0)
		ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(0, 0, 0, 0.6), 2.0)
	var tag := func(r: Rect2, s: String, size: int) -> void:
		ci.draw_rect(r, Color(0.02, 0.022, 0.026))
		ci.draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)
		txt(s, r.position + Vector2(10, r.size.y * 0.5 + size * 0.36), size, Pal.ink(0.95), font_s)
	var lamp := func(p: Vector2, col: Color, on: bool) -> void:
		ci.draw_circle(p, 9.0, Color(0.02, 0.02, 0.02))
		ci.draw_circle(p, 7.0, col if on else Color(col.r * 0.25, col.g * 0.25, col.b * 0.25))
		ci.draw_arc(p, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0, true)
	# header bar
	raised.call(Rect2(0, 0, W, 130), Color(0.11, 0.115, 0.125))
	tag.call(Rect2(40, 30, 380, 70), "船坞终端  BERTH 07", 30)
	lamp.call(Vector2(460, 65), Pal.tint(Pal.FLUID, 1.0, 1.6), true)
	txt("在线", Vector2(480, 72), 18, Pal.ink(0.8), font_b)
	for i in TOP.size():
		var r := Rect2(620 + i * 320, 26, 300, 78)
		raised.call(r, Color(0.06, 0.064, 0.07))
		txt(TOP[i][0], r.position + Vector2(14, 24), 15, Pal.ink(0.6), font_b)
		txt(TOP[i][1], r.position + Vector2(r.size.x - 14, 64), 34, Pal.heat(1.0, 1.3) if TOP[i][2] else Pal.ink(0.98), font_s, 1)
		lamp.call(r.position + Vector2(r.size.x - 20, 20), Pal.heat(1.0, 1.6) if TOP[i][2] else Pal.tint(Pal.FLUID, 1.0, 1.4), true)
	# tabs as rocker switches
	for i in TABS.size():
		var r := Rect2(40 + i * 250, 156, 232, 56)
		var on := i == 0
		raised.call(r, Color(0.16, 0.165, 0.18) if on else Color(0.1, 0.105, 0.115))
		if on:
			ci.draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Pal.heat(1.0, 1.4))
		lamp.call(r.position + Vector2(24, 28), Pal.heat(1.0, 1.8), on)
		txt("%d  %s" % [i + 1, TABS[i]], r.position + Vector2(48, 37), 22, Pal.ink(0.98 if on else 0.7), font_s)
	for i in CARDS.size():
		var c: Dictionary = CARDS[i]
		var r := Rect2(40 + i * 620, 240, 600, 650)
		var on := i == SEL
		raised.call(r, Color(0.1, 0.105, 0.115))
		if on:
			ci.draw_rect(r.grow(4), Pal.heat(1.0, 1.4), false, 4.0)
		var head: String = "主线合同 · 置顶" if c.get("pin", false) else c.scope
		tag.call(Rect2(r.position.x + 20, r.position.y + 20, r.size.x - 40, 48), head, 22)
		lamp.call(Vector2(r.end.x - 44, r.position.y + 44), Pal.heat(1.0, 1.8) if c.get("pin", false) else Pal.tint(Pal.FLUID, 1.0, 1.5), true)
		var x := r.position.x + 30
		var y := r.position.y + 90
		var screen := Rect2(r.position.x + 20, y, r.size.x - 40, 300)
		ci.draw_rect(screen, Color(0.02, 0.024, 0.028))
		ci.draw_rect(screen, Color(0, 0, 0, 0.8), false, 2.0)
		if c.get("pin", false):
			txt(c.id, Vector2(x + 10, y + 70), 50, Pal.ink(0.98), font_l)
			txt(c.name, Vector2(x + 10, y + 108), 20, Pal.ink(0.8), font_s)
			ship_outline(c.ship, Rect2(x + 10, y + 140, r.size.x - 80, 140), Pal.tint(Pal.AIR, 0.85, 1.2), 1.4)
			var rows := [["船长", "%d m" % c.len], ["估值", c.value], ["合同费", c.fee], ["工期", c.time]]
			for j in rows.size():
				var yy := y + 350 + j * 48
				txt(rows[j][0], Vector2(x, yy), 18, Pal.ink(0.6), font_b)
				txt(rows[j][1], Vector2(r.end.x - 30, yy), 24, Pal.ink(0.95), font_s, 1)
			continue
		txt("预计净赚", Vector2(x + 10, y + 34), 16, Pal.ink(0.6), font_b)
		txt(c.net, Vector2(x + 6, y + 112), 76, Pal.tint(Pal.AIR, 1.0, 1.35), font_l)
		txt(c.rate + " / 分钟  ·  " + c.time + " 分钟", Vector2(r.end.x - 40, y + 40), 18, Pal.ink(0.85), font_s, 1)
		ship_outline(c.ship, Rect2(x + 10, y + 140, r.size.x - 80, 140), Pal.tint(Pal.AIR, 0.85, 1.2), 1.4)
		# gauges: risk and value share
		var gy := y + 330
		txt("风险", Vector2(x, gy), 17, Pal.ink(0.6), font_b)
		for s in 3:
			var seg := Rect2(x + 70 + s * 70, gy - 16, 62, 20)
			ci.draw_rect(seg, Pal.heat(1.0, 1.3) if s < c.stars else Color(0.04, 0.04, 0.045))
			ci.draw_rect(seg, Color(0, 0, 0, 0.6), false, 1.0)
		txt(c.risk, Vector2(x + 300, gy), 17, Pal.ink(0.8), font_b)
		var rows2 := [["预估价值", c.value], ["合同费", c.fee], ["分期与利息", c.due]]
		for j in rows2.size():
			var yy := gy + 50 + j * 40
			txt(rows2[j][0], Vector2(x, yy), 17, Pal.ink(0.6), font_b)
			txt(rows2[j][1], Vector2(r.end.x - 30, yy), 22, Pal.ink(0.95), font_s, 1)
		var bw := tw(c.badge, 16, font_s) + 24.0
		ci.draw_rect(Rect2(x, r.end.y - 62, bw, 30), Pal.tint(Pal.FLUID, 0.9, 1.0))
		txt(c.badge, Vector2(x + 12, r.end.y - 41), 16, Color(0.03, 0.05, 0.03), font_s)
	# the push button
	var bc := Vector2(40 + SEL * 620 + 300, 950)
	raised.call(Rect2(bc.x - 300, bc.y - 44, 600, 88), Color(0.12, 0.125, 0.135))
	ci.draw_circle(bc + Vector2(-220, 0), 30.0, Color(0.02, 0.02, 0.02))
	ci.draw_circle(bc + Vector2(-220, 0), 25.0, Pal.tint(Pal.FLUID, 1.0, 1.5))
	ci.draw_arc(bc + Vector2(-220, 0), 30.0, 0.0, TAU, 28, Color(1, 1, 1, 0.3), 2.0, true)
	txt("接单  START", bc + Vector2(-160, 12), 32, Pal.ink(0.98), font_s)
	txt("ENTER", bc + Vector2(270, 12), 20, Pal.ink(0.55), font_b, 1)
	txt("1–4 页面   ←→ 选择   ENTER 确认   O 设置   ESC 返回标题", Vector2(40, 1052), 16, Pal.ink(0.5), font_b)
