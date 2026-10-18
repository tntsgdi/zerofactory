extends SceneTree
# P.8, the terminal's route page and the next goals the header keeps showing,
# three directions as mock-ups for the player (2026-10-18): A a reputation
# ladder with what money buys under it, B four category panels nearest-first,
# C the ships as a line of nodes with what they need hanging off it. The two
# goals are pinned by the player (Jev pin 0.80) and sit in the breadcrumb row.
# In the HMI look; sample data only, no saves touched.
# tools/run_test.sh tests/route_concepts.gd -- a|b|c

const Cap = preload("res://tests/cap.gd")
const W := 1920.0
const H := 1080.0
const REP := 7
const DONE := 4
const MONEY := 41250.0
var sheet: Node2D
var font: Font
var font_b: Font
var font_s: Font
var font_l: Font
var mode := "a"

# [class, name, length m, reputation, needs the berth extension]
const SHIPS := [["WT", "作业艇", 16, 0, false], ["S", "雨燕", 26, 0, false], ["GR", "灰鹭", 42, 0, false], ["CP", "货运吊舱", 22, 0, false],
	["H", "双钩", 38, 6, false], ["M", "鼹鼠", 58, 8, false], ["MED", "缄默", 82, 10, true], ["FR", "霜线", 72, 12, true]]
# [name, price, owned, needs]
const GEAR := [["精密检测套件", 24000.0, true, ""], ["5 吨牵引抓钩", 38000.0, false, ""], ["高效气体回收泵", 22000.0, false, ""], ["工业回收机械臂", 65000.0, false, ""]]
const FAC := [["作业区管理", 20000.0, false, ""], ["碎屑网升级", 18000.0, true, ""], ["可移动炉口", 30000.0, false, ""], ["缓冲平台", 30000.0, false, ""],
	["初级搬运无人机", 45000.0, true, ""], ["第二设备回收口", 50000.0, false, ""], ["第二台搬运无人机", 60000.0, false, "初级搬运无人机"],
	["重型起重机", 150000.0, false, ""], ["船坞扩建（约 88 m）", 240000.0, false, ""]]
# [name, level now, next price]
const SKILLS := [["矢量推进", 1, 63000.0], ["切割功率", 1, 75000.0], ["复合装甲", 0, 9000.0], ["远程读数", 0, 6000.0], ["快拆工法", 0, 8000.0], ["重物牵引", 0, 12000.0]]


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		if a in ["a", "b", "c"]:
			mode = a
	_run()


func _run() -> void:
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	font_l = Fonts.get_font("Light")
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
	for f in 6:
		await process_frame
	Cap.save(root, "res://tests/out/route_%s.png" % mode)
	quit()


func txt(s: String, p: Vector2, size: int, col: Color, f: Font = null, align: int = -1, w: float = -1.0) -> void:
	var fo := f if f != null else font
	var x := p.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	sheet.draw_string(fo, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


func money(v: float) -> String:
	return Pal.money(v)


func green(a: float = 1.0) -> Color:
	return Pal.tint(Pal.FLUID, 0.9 * a, 1.1)


# the header as it is now, the old single goal line gone
func header() -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, W, H), Hmi.BG)
	Hmi.raised(ci, Rect2(0, 0, W, 116), 1.0, Hmi.HEAD)
	Hmi.plate(ci, font_s, Rect2(40, 22, 420, 72), "船坞终端", 28)
	txt("BERTH 07  ·  CHARON-DISPATCH", Vector2(484, 50), 14, Pal.ink(0.6), font_b)
	Hmi.lamp(ci, Vector2(492, 76), Hmi.ok_col(), true, 1.0, 6.0)
	txt("在线", Vector2(508, 82), 15, Pal.ink(0.75), font_b)
	var top := [["资金", money(MONEY), Pal.ink(0.98), Hmi.ok_col()], ["贷款", "$36,000", Pal.heat(1.0, 1.3), Hmi.warn_col()], ["每单应付", "$20,720", Pal.ink(0.9), Hmi.ok_col()], ["声望", "认证", Pal.ink(0.98), Hmi.ok_col()]]
	for i in 4:
		var r := Rect2(W - 40 - (4 - i) * 296 + 16, 18, 280, 80)
		Hmi.readout(ci, font_s, font_b, r, top[i][0], top[i][1], top[i][2], top[i][3], 1.0)
	Hmi.gauge(ci, Rect2(W - 40 - 296 + 16, 101, 280, 10), 0.1, Pal.heat(1.0, 1.3), 1.0, 12)
	txt("距下一级还差 9 点", Vector2(W - 40, 126), 12, Pal.ink(0.5), font, 1)
	crumb()


# the breadcrumb row: where you are, the way home, and the two pinned goals on the right
func crumb() -> void:
	var ci := sheet
	Hmi.plate(ci, font_s, Rect2(40, 134, 380, 46), "首页 › 路线", 19)
	Hmi.raised(ci, Rect2(436, 134, 190, 46), 1.0)
	txt("← 首页", Vector2(456, 164), 17, Pal.ink(0.9), font_s)
	txt("ESC", Vector2(606, 163), 12, Pal.ink(0.45), font_b, 1)
	var r := Rect2(646, 134, W - 40 - 646, 46)
	Hmi.sunk(ci, r)
	txt("下一个目标", Vector2(r.position.x + 18, r.position.y + 29), 14, Pal.ink(0.55), font_b)
	var goals := [["M-14「鼹鼠」采矿船", "声望 7 / 8", "还差 1 点声望", 7.0 / 8.0], ["第二台搬运无人机", "$41,250 / $60,000", "还差 $18,750", MONEY / 60000.0]]
	var x := r.position.x + 120
	var gw := (r.end.x - x - 12) / 2.0
	for i in 2:
		var g: Array = goals[i]
		var gx := x + i * gw
		Hmi.lamp(ci, Vector2(gx + 10, r.get_center().y), Pal.heat(1.0, 1.6), true, 1.0, 5.0)
		txt("★ " + str(g[0]), Vector2(gx + 26, r.position.y + 22), 15, Pal.ink(0.95), font_s)
		txt(str(g[2]), Vector2(gx + gw - 18, r.position.y + 22), 13, Pal.heat(0.95, 1.2), font_b, 1)
		Hmi.gauge(ci, Rect2(gx + 26, r.position.y + 31, gw - 44, 7), float(g[3]), Pal.heat(1.0, 1.3), 1.0, 20)


func footer(keys: String, btn: String) -> void:
	Hmi.push(sheet, font_s, Rect2(W * 0.5 - 320, 964, 640, 62), btn, true, 0.0, 1.0, 0.0, 0.0, "", "ENTER")
	txt(keys, Vector2(40, H - 14), 15, Pal.ink(0.5), font_b)


func _draw_sheet() -> void:
	header()
	match mode:
		"a": _ladder()
		"b": _panels()
		"c": _nodes()


# ---------------------------------------------------------------- A · reputation ladder
func _ladder() -> void:
	var ci := sheet
	var levels := [["见习", 0], ["认证", 6], ["资深", 16], ["首席", 30]]
	var area := Rect2(40, 200, W - 80, 500)
	var gap := 20.0
	var cw := (area.size.x - gap * 3.0) / 4.0
	# what opens at each level: [kind, name, state 0 open / 1 next / 2 later, note]
	var rows := [
		[["船", "作业艇 · 雨燕 · 灰鹭 · 货运吊舱", 0, "已开放"], ["市场", "风险最高 ★★", 0, "已开放"], ["技能", "所有技能第 I 卷", 0, "已开放"]],
		[["船", "H 双钩 · 38 m", 0, "声望 6 ✓"], ["船", "M-14 鼹鼠 · 58 m", 1, "声望 8 · 还差 1 点"], ["船", "MED-47 缄默 · 82 m", 2, "声望 10 · 要船坞扩建"], ["船", "FR-26 霜线 · 72 m", 2, "声望 12 · 要船坞扩建"], ["技能", "第 II 卷", 0, "3 单 ✓ · 声望 6 ✓"]],
		[["市场", "风险最高 ★★★", 2, "声望 16 · 还差 9 点"], ["技能", "第 III 卷", 2, "8 单 · 还差 4 单"]],
		[["…", "以后的船和合同", 2, "后续阶段开放"]],
	]
	for i in 4:
		var r := Rect2(area.position.x + i * (cw + gap), area.position.y, cw, area.size.y)
		var here := i == 1
		Hmi.raised(ci, r, 1.0 if i <= 1 else 0.8, Hmi.PANEL_HI if here else Hmi.PANEL)
		if here:
			ci.draw_rect(r.grow(4), Pal.heat(1.0, 1.4), false, 4.0)
		var pr := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 54)
		Hmi.plate(ci, font_s, pr, str(levels[i][0]), 24)
		txt("声望 %d" % int(levels[i][1]), Vector2(pr.end.x - 16, pr.position.y + 35), 15, Pal.ink(0.6), font_b, 1)
		if here:
			txt("你在这里 · 声望 7", Vector2(r.position.x + 22, r.position.y + 100), 16, Pal.heat(1.0, 1.3), font_s)
			Hmi.gauge(ci, Rect2(r.position.x + 22, r.position.y + 112, r.size.x - 44, 9), 0.1, Pal.heat(1.0, 1.3), 1.0, 10)
			txt("到「资深」还差 9 点", Vector2(r.end.x - 22, r.position.y + 100), 13, Pal.ink(0.55), font, 1)
		elif i == 0:
			txt("✓ 已达到", Vector2(r.position.x + 22, r.position.y + 100), 16, green(), font_s)
		else:
			txt("还差 %d 点" % (int(levels[i][1]) - REP), Vector2(r.position.x + 22, r.position.y + 100), 16, Pal.ink(0.5), font_b)
		var y := r.position.y + 150
		for row in rows[i]:
			var st: int = row[2]
			var rr := Rect2(r.position.x + 18, y, r.size.x - 36, 58)
			if st == 1:
				Hmi.sunk(ci, rr, 1.0)
				ci.draw_rect(rr, Pal.heat(0.9, 1.3), false, 2.0)
			txt(str(row[0]), Vector2(rr.position.x + 12, rr.position.y + 24), 12, Pal.ink(0.5), font_b)
			txt(str(row[1]), Vector2(rr.position.x + 58, rr.position.y + 24), 16, Pal.ink(0.95 if st < 2 else 0.6), font_s)
			var nc := green() if st == 0 else (Pal.heat(1.0, 1.25) if st == 1 else Pal.ink(0.45))
			txt(str(row[3]), Vector2(rr.position.x + 58, rr.position.y + 46), 13, nc, font_b)
			if st == 1:
				txt("★ 已钉", Vector2(rr.end.x - 12, rr.position.y + 24), 13, Pal.heat(1.0, 1.4), font_b, 1)
			y += 66
	# under the ladder: what only money buys, cheapest first
	var sr := Rect2(40, 718, W - 80, 226)
	Hmi.raised(ci, sr, 1.0)
	Hmi.plate(ci, font_s, Rect2(sr.position.x + 18, sr.position.y + 16, 520, 40), "钱能买的 · 便宜的在前", 18)
	var buy := []
	for it in GEAR + FAC:
		if not it[2]:
			buy.append(it)
	buy.sort_custom(func(p, q): return float(p[1]) < float(q[1]))
	var n := 7
	var bw := (sr.size.x - 36 - 12.0 * (n - 1)) / n
	for i in n:
		var it: Array = buy[i]
		var br := Rect2(sr.position.x + 18 + i * (bw + 12), sr.position.y + 72, bw, 136)
		var pinned: bool = it[0] == "第二台搬运无人机"
		Hmi.sunk(ci, br)
		if pinned:
			ci.draw_rect(br, Pal.heat(0.9, 1.3), false, 2.0)
		txt(str(it[0]), Vector2(br.position.x + 12, br.position.y + 30), 15, Pal.ink(0.95), font_s, -1, bw - 20)
		txt(money(it[1]), Vector2(br.position.x + 12, br.position.y + 64), 22, Pal.ink(0.95), font_b)
		var can: bool = MONEY >= float(it[1])
		Hmi.gauge(ci, Rect2(br.position.x + 12, br.position.y + 80, bw - 24, 8), minf(1.0, MONEY / float(it[1])), green() if can else Pal.heat(1.0, 1.2), 1.0, 12)
		txt("买得起" if can else "还差 " + money(float(it[1]) - MONEY), Vector2(br.position.x + 12, br.position.y + 112), 13, green() if can else Pal.ink(0.55), font_b)
		if pinned:
			txt("★", Vector2(br.end.x - 12, br.position.y + 30), 15, Pal.heat(1.0, 1.4), font_b, 1)
	footer("← → ↑ ↓ 选择 · Enter 钉为目标 / 取消（最多 2 个）· Esc 回首页", "★ 钉为目标：M-14「鼹鼠」 · 已钉")


# ---------------------------------------------------------------- B · four category panels
func _panels() -> void:
	var ci := sheet
	var area := Rect2(40, 200, W - 80, 744)
	var gap := 20.0
	var cw := (area.size.x - gap * 3.0) / 4.0
	# [name, condition line, progress 0..1, done, pinned, nearest]
	var ships := []
	for s in SHIPS:
		var need := []
		if int(s[3]) > REP:
			need.append("声望 %d · 还差 %d" % [s[3], int(s[3]) - REP])
		if s[4]:
			need.append("要船坞扩建")
		var p := 1.0 if need.is_empty() else float(REP) / float(s[3]) * (0.5 if s[4] else 1.0)
		ships.append(["%s %s · %d m" % [s[0], s[1], s[2]], "已开放" if need.is_empty() else " · ".join(need), p, need.is_empty(), s[1] == "鼹鼠", s[1] == "鼹鼠"])
	ships.sort_custom(func(p, q): return float(p[2]) > float(q[2]) if p[3] == q[3] else q[3])
	var gear := []
	for it in GEAR:
		gear.append([it[0], "已装备" if it[2] else ("买得起" if MONEY >= float(it[1]) else "还差 " + money(float(it[1]) - MONEY)), 1.0 if it[2] else minf(1.0, MONEY / float(it[1])), it[2], false, it[0] == "5 吨牵引抓钩", money(it[1])])
	var fac := []
	for it in FAC:
		var note: String = "已建" if it[2] else ("买得起" if MONEY >= float(it[1]) else "还差 " + money(float(it[1]) - MONEY))
		if it[3] != "":
			note += " · 先要" + str(it[3]) + " ✓"
		fac.append([it[0], note, 1.0 if it[2] else minf(1.0, MONEY / float(it[1])), it[2], it[0] == "第二台搬运无人机", it[0] == "作业区管理", money(it[1])])
	var skills := []
	for it in SKILLS:
		var lv: int = it[1]
		var nt := ""
		if lv >= 1:
			nt = "第 II 卷 · 3 单 ✓ 声望 6 ✓ · 还差 " + money(float(it[2]) - MONEY)
		else:
			nt = "第 I 卷 · 买得起"
		skills.append([str(it[0]) + "  " + ["", "I", "II"][lv] + " → " + ["I", "II", "III"][lv], nt, 1.0 if lv == 0 else MONEY / float(it[2]), false, false, it[0] == "远程读数", money(it[2])])
	var panels := [["船", "4 / 8 已开放", ships], ["设备", "1 / 4 已装备", gear], ["设施与船坞", "2 / 9 已建", fac], ["技能", "3 / 51 级", skills]]
	for i in 4:
		var r := Rect2(area.position.x + i * (cw + gap), area.position.y, cw, area.size.y)
		Hmi.raised(ci, r, 1.0)
		var pr := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 50)
		Hmi.plate(ci, font_s, pr, str(panels[i][0]), 22)
		txt(str(panels[i][1]), Vector2(pr.end.x - 16, pr.position.y + 32), 14, Pal.ink(0.6), font_b, 1)
		var list: Array = panels[i][2]
		# what isn't reached first, nearest at the top; what's done folds into one line at the bottom
		var open := list.filter(func(x): return not x[3])
		open.sort_custom(func(p, q): return float(p[2]) > float(q[2]))
		var done := list.filter(func(x): return x[3])
		var y := r.position.y + 86
		for row in open.slice(0, 7):
			var rr := Rect2(r.position.x + 18, y, r.size.x - 36, 74)
			var sel: bool = i == 0 and row[4]
			Hmi.sunk(ci, rr, 1.0, Hmi.PANEL_LO if not sel else Hmi.PANEL_HI)
			if sel:
				ci.draw_rect(rr.grow(3), Pal.heat(1.0, 1.4), false, 3.0)
			elif row[5]:
				ci.draw_rect(rr, green(0.8), false, 1.5)
			txt(str(row[0]), Vector2(rr.position.x + 14, rr.position.y + 26), 16, Pal.ink(0.95), font_s, -1, rr.size.x - 120)
			if row.size() > 6:
				txt(str(row[6]), Vector2(rr.end.x - 14, rr.position.y + 26), 15, Pal.ink(0.85), font_b, 1)
			var can: bool = float(row[2]) >= 1.0
			Hmi.gauge(ci, Rect2(rr.position.x + 14, rr.position.y + 36, rr.size.x - 28, 7), float(row[2]), green() if can else Pal.heat(1.0, 1.2), 1.0, 16)
			txt(str(row[1]), Vector2(rr.position.x + 14, rr.position.y + 63), 13, green() if can else Pal.ink(0.6), font_b, -1, rr.size.x - 70)
			if row[4]:
				txt("★ 已钉", Vector2(rr.end.x - 14, rr.position.y + 63), 13, Pal.heat(1.0, 1.4), font_b, 1)
			elif row[5]:
				txt("最近", Vector2(rr.end.x - 14, rr.position.y + 63), 13, green(), font_b, 1)
			y += 84
		if not done.is_empty():
			var names := done.map(func(x): return str(x[0]).split(" · ")[0])
			txt("✓ " + "、".join(names), Vector2(r.position.x + 22, r.end.y - 22), 13, green(0.8), font_b, -1, r.size.x - 44)
	footer("← → 换栏 · ↑ ↓ 选择 · Enter 钉为目标 / 取消（最多 2 个）· Esc 回首页", "★ 钉为目标：M-14「鼹鼠」 · 已钉")


# ---------------------------------------------------------------- C · the ships as a line of nodes
func _nodes() -> void:
	var ci := sheet
	var scr := Rect2(40, 200, W - 80, 520)
	Hmi.screen(ci, scr, 1.0, true)
	var y0 := scr.position.y + 290
	var x0 := scr.position.x + 120
	var dx := (scr.size.x - 240) / 7.0
	var pos := []
	for i in SHIPS.size():
		pos.append(Vector2(x0 + i * dx, y0))
	# the line: lit as far as it is open
	ci.draw_line(pos[0], pos[4], green(), 4.0)
	ci.draw_line(pos[4], pos[5], Pal.heat(0.9, 1.3), 3.0)
	ci.draw_line(pos[5], pos[7], Pal.ink(0.25), 2.0)
	for i in SHIPS.size():
		var s: Array = SHIPS[i]
		var p: Vector2 = pos[i]
		var open: bool = REP >= int(s[3]) and not s[4]
		var next := i == 5
		ci.draw_circle(p, 26.0, Color(0.02, 0.024, 0.028))
		if open:
			ci.draw_circle(p, 18.0, green())
		ci.draw_arc(p, 26.0, 0.0, TAU, 36, green() if open else (Pal.heat(1.0, 1.5) if next else Pal.ink(0.4)), 3.0 if next else 2.0, true)
		if next:
			ci.draw_arc(p, 38.0, 0.0, TAU, 40, Pal.heat(0.6, 1.3), 2.0, true)
			ci.draw_rect(Rect2(p - Vector2(72, 92), Vector2(144, 196)), Pal.heat(1.0, 1.4), false, 3.0)
		txt(str(s[0]), p + Vector2(0, -64), 22, Pal.ink(0.95 if open or next else 0.55), font_s, 0)
		txt("%s · %d m" % [s[1], s[2]], p + Vector2(0, -40), 14, Pal.ink(0.8 if open or next else 0.5), font_b, 0)
		var cond := "已开放" if open else ("声望 %d" % s[3])
		txt(cond, p + Vector2(0, 58), 14, green() if open else (Pal.heat(1.0, 1.3) if next else Pal.ink(0.55)), font_b, 0)
		if not open:
			txt("还差 %d 点" % (int(s[3]) - REP), p + Vector2(0, 78), 12, Pal.ink(0.5), font, 0)
	# the berth extension hangs over the two big ships
	var bx := (pos[6] as Vector2).lerp(pos[7], 0.5) + Vector2(0, -170)
	for j in [6, 7]:
		ci.draw_line(bx + Vector2(0, 26), (pos[j] as Vector2) + Vector2(0, -78), Pal.ink(0.35), 2.0)
	_branch(bx, "船坞扩建 88 m", "$240,000 · 还差 $198,750", MONEY / 240000.0, false)
	# the haulers: the first one bought, the second pinned
	var hx := scr.position + Vector2(260, 92)
	_branch(hx, "初级搬运无人机", "已建", 1.0, true)
	ci.draw_line(hx + Vector2(80, 0), hx + Vector2(250, 0), green(0.7), 2.0)
	_branch(hx + Vector2(330, 0), "★ 第二台搬运无人机", "$60,000 · 还差 $18,750", MONEY / 60000.0, false)
	# the skill volumes ride the reputation ruler under the line
	var ry := scr.end.y - 54
	ci.draw_line(Vector2(x0, ry), Vector2(scr.end.x - 120, ry), Pal.ink(0.3), 2.0)
	var rx := func(rep: float) -> float: return x0 + clampf(rep / 16.0, 0.0, 1.0) * (scr.size.x - 240)
	for m in [[0, "见习"], [6, "认证 · 技能第 II 卷（还要 3 单 ✓）"], [16, "资深 · 第 III 卷（还要 8 单）· 风险 ★★★"]]:
		var x: float = rx.call(float(m[0]))
		ci.draw_line(Vector2(x, ry - 8), Vector2(x, ry + 8), Pal.ink(0.6), 2.0)
		txt(str(m[1]), Vector2(x + 8, ry + 28), 13, Pal.ink(0.6), font_b, 1 if m[0] == 16 else -1)
	var me: float = rx.call(float(REP))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(me, ry - 4), Vector2(me - 9, ry - 20), Vector2(me + 9, ry - 20)]), Pal.heat(1.0, 1.6))
	txt("你 · 声望 7", Vector2(me, ry - 28), 14, Pal.heat(1.0, 1.3), font_s, 0)
	# the chosen node's detail under the map
	var dr := Rect2(40, 738, W - 80, 206)
	Hmi.raised(ci, dr, 1.0, Hmi.PANEL_HI)
	Hmi.plate(ci, font_s, Rect2(dr.position.x + 18, dr.position.y + 16, 620, 46), "M-14「鼹鼠」采矿船 · 58 m", 21)
	txt("超重设备、结构拆分、松散矿物", Vector2(dr.position.x + 660, dr.position.y + 46), 16, Pal.ink(0.7), font_b)
	var conds := [["声望", "7 / 8", 7.0 / 8.0, false], ["船坞长度", "50 m 够用", 1.0, true]]
	for i in conds.size():
		var c: Array = conds[i]
		var cx := dr.position.x + 30 + i * 620
		txt(str(c[0]), Vector2(cx, dr.position.y + 104), 15, Pal.ink(0.6), font_b)
		txt(str(c[1]), Vector2(cx + 560, dr.position.y + 104), 18, green() if c[3] else Pal.heat(1.0, 1.3), font_s, 1)
		Hmi.gauge(ci, Rect2(cx, dr.position.y + 118, 560, 10), float(c[2]), green() if c[3] else Pal.heat(1.0, 1.3), 1.0, 16)
	txt("再干干净净做完 1 单（声望 +1）就会出现在合同市场", Vector2(dr.position.x + 30, dr.position.y + 172), 16, Pal.tint(Pal.AIR, 0.95, 1.2), font_b)
	footer("← → 沿线选 · ↑ ↓ 选分支 · Enter 钉为目标 / 取消（最多 2 个）· Esc 回首页", "★ 钉为目标：M-14「鼹鼠」 · 已钉")


func _branch(c: Vector2, name: String, note: String, k: float, done: bool) -> void:
	var r := Rect2(c - Vector2(150, 30), Vector2(300, 64))
	Hmi.raised(sheet, r, 1.0)
	if name.begins_with("★"):
		sheet.draw_rect(r.grow(3), Pal.heat(1.0, 1.4), false, 2.0)
	txt(name, r.position + Vector2(14, 24), 15, Pal.ink(0.95), font_s)
	Hmi.gauge(sheet, Rect2(r.position.x + 14, r.position.y + 32, r.size.x - 28, 6), k, green() if done else Pal.heat(1.0, 1.2), 1.0, 14)
	txt(note, r.position + Vector2(14, 56), 12, green() if done else Pal.ink(0.6), font_b)
