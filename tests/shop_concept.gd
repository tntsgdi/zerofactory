extends SceneTree
# P.7 (2026-10-18): the equipment shop as a mock-up in the chosen direction,
# C · industrial HMI, for the player to review before it is built. Sample data
# only; no saves are touched. tools/run_test.sh tests/shop_concept.gd

const Cap = preload("res://tests/cap.gd")
const Art = preload("res://scripts/drone_art.gd")
const W := 1920.0
const H := 1080.0
const TOP := [["资金", "$41,250", false], ["贷款", "$36,000", true], ["每单应付", "$20,720", false], ["声望", "认证", false]]
const TABS := ["合同市场", "设备商店", "船坞管理", "技能书"]
var sheet: Node2D
var font: Font
var font_b: Font
var font_s: Font


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _run() -> void:
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
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
	sheet.draw.connect(_draw_shop)
	root.add_child(sheet)
	for f in 6:
		await process_frame
	Cap.save(root, "res://tests/out/termc_shop.png")
	quit()


func txt(s: String, p: Vector2, size: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := p.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	sheet.draw_string(fo, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func raised(r: Rect2, fill: Color) -> void:
	sheet.draw_rect(r, fill)
	sheet.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.16), 2.0)
	sheet.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.12), 2.0)
	sheet.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0, 0, 0, 0.6), 2.0)
	sheet.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(0, 0, 0, 0.6), 2.0)


func tag(r: Rect2, s: String, size: int, col: Color = Color(0.95, 0.96, 1.0)) -> void:
	sheet.draw_rect(r, Color(0.02, 0.022, 0.026))
	sheet.draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)
	txt(s, r.position + Vector2(10, r.size.y * 0.5 + size * 0.36), size, col, font_s)


func lamp(p: Vector2, col: Color, on: bool) -> void:
	sheet.draw_circle(p, 9.0, Color(0.02, 0.02, 0.02))
	sheet.draw_circle(p, 7.0, col if on else Color(col.r * 0.25, col.g * 0.25, col.b * 0.25))
	sheet.draw_arc(p, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0, true)


func closed(p: PackedVector2Array) -> PackedVector2Array:
	var o := p.duplicate()
	o.append(p[0])
	return o


func _draw_shop() -> void:
	var ci := sheet
	# the frame every page shares
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.075, 0.08, 0.088))
	raised(Rect2(0, 0, W, 130), Color(0.11, 0.115, 0.125))
	tag(Rect2(40, 30, 380, 70), "船坞终端  BERTH 07", 30)
	lamp(Vector2(460, 65), Pal.tint(Pal.FLUID, 1.0, 1.6), true)
	txt("在线", Vector2(480, 72), 18, Pal.ink(0.8), font_b)
	for i in TOP.size():
		var r := Rect2(620 + i * 320, 26, 300, 78)
		raised(r, Color(0.06, 0.064, 0.07))
		txt(TOP[i][0], r.position + Vector2(14, 24), 15, Pal.ink(0.6), font_b)
		txt(TOP[i][1], r.position + Vector2(r.size.x - 14, 64), 34, Pal.heat(1.0, 1.3) if TOP[i][2] else Pal.ink(0.98), font_s, 1)
		lamp(r.position + Vector2(r.size.x - 20, 20), Pal.heat(1.0, 1.6) if TOP[i][2] else Pal.tint(Pal.FLUID, 1.0, 1.4), true)
	for i in TABS.size():
		var r := Rect2(40 + i * 250, 156, 232, 56)
		var on := i == 1
		raised(r, Color(0.16, 0.165, 0.18) if on else Color(0.1, 0.105, 0.115))
		if on:
			ci.draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Pal.heat(1.0, 1.4))
		lamp(r.position + Vector2(24, 28), Pal.heat(1.0, 1.8), on)
		txt("%d  %s" % [i + 1, TABS[i]], r.position + Vector2(48, 37), 22, Pal.ink(0.98 if on else 0.7), font_s)
	txt("1–4 页面   ←→ 选择   ↑↓ 数量   ENTER 购买   O 设置   ESC 返回标题", Vector2(40, 1052), 16, Pal.ink(0.5), font_b)
	# ---- the schematic: the drone and the berth on a screen, each upgrade on the part it replaces
	var sp := Rect2(40, 240, 1100, 520)
	raised(sp, Color(0.1, 0.105, 0.115))
	tag(Rect2(sp.position.x + 20, sp.position.y + 16, 380, 40), "设备示意  ·  R-02 与 BERTH 07", 18)
	var scr := Rect2(sp.position.x + 20, sp.position.y + 68, sp.size.x - 40, sp.size.y - 110)
	ci.draw_rect(scr, Color(0.02, 0.024, 0.028))
	ci.draw_rect(scr, Color(0, 0, 0, 0.8), false, 2.0)
	var gx := scr.position.x + 20.0
	while gx < scr.end.x:
		ci.draw_line(Vector2(gx, scr.position.y), Vector2(gx, scr.end.y), Pal.tint(Pal.AIR, 0.05), 1.0)
		gx += 40.0
	var gy := scr.position.y + 20.0
	while gy < scr.end.y:
		ci.draw_line(Vector2(scr.position.x, gy), Vector2(scr.end.x, gy), Pal.tint(Pal.AIR, 0.05), 1.0)
		gy += 40.0
	var dc := scr.position + Vector2(300, 210)
	var xf := Transform2D(0.0, Vector2(4.2, 4.2), 0.0, dc)
	ci.draw_set_transform_matrix(xf)
	Art.tint = Color(Pal.AIR.r * 1.1, Pal.AIR.g * 1.1, Pal.AIR.b * 1.1)
	Art.draw(ci, "arrowring", {"heading": -0.25, "tool": 1, "open": 1.0, "t": 1.3, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	txt("R-02", dc + Vector2(-26, 140), 20, Pal.tint(Pal.AIR, 0.9, 1.2), font_s)
	var bx := scr.position.x + 640
	ci.draw_rect(Rect2(bx, scr.position.y + 120, 380, 14), Pal.tint(Pal.AIR, 0.35))
	ci.draw_line(Vector2(bx + 380, scr.position.y + 120), Vector2(bx + 380, scr.end.y - 30), Pal.tint(Pal.AIR, 0.5), 2.0)
	ci.draw_rect(Rect2(bx + 140, scr.position.y + 150, 90, 40), Pal.tint(Pal.AIR, 0.5), false, 1.5)
	ci.draw_line(Vector2(bx + 185, scr.position.y + 190), Vector2(bx + 185, scr.position.y + 270), Pal.tint(Pal.AIR, 0.5), 1.5)
	ci.draw_rect(Rect2(bx + 270, scr.position.y + 230, 40, 40), Pal.tint(Pal.AIR, 0.5), false, 1.5)
	txt("BERTH 07", Vector2(bx, scr.position.y + 110), 16, Pal.tint(Pal.AIR, 0.7), font_b)
	var ups := [["精密检测套件", "$24,000", "", Vector2(30, 24), dc + Vector2(64, -20), "sel"],
		["5 吨牵引抓钩", "$38,000", "", Vector2(30, 300), dc + Vector2(-40, 40), ""],
		["工业回收机械臂", "$65,000", "还差 $23,750", Vector2(660, 300), Vector2(bx + 185, scr.position.y + 230), "short"],
		["高效气体回收泵", "已安装", "", Vector2(660, 14), Vector2(bx + 290, scr.position.y + 230), "have"]]
	for u in ups:
		var r := Rect2(scr.position + (u[3] as Vector2), Vector2(330, 74))
		var sel: bool = u[5] == "sel"
		var to: Vector2 = u[4]
		ci.draw_line(Vector2(r.end.x if to.x > r.end.x else r.position.x, r.get_center().y), to, Pal.tint(Pal.AIR, 0.6), 1.2, true)
		ci.draw_circle(to, 4.0, Pal.tint(Pal.AIR, 0.9, 1.4))
		raised(r, Color(0.13, 0.135, 0.15) if sel else Color(0.09, 0.095, 0.105))
		if sel:
			ci.draw_rect(r.grow(3), Pal.heat(1.0, 1.4), false, 3.0)
		var lc := Pal.tint(Pal.FLUID, 1.0, 1.6) if u[5] == "have" else (Pal.heat(1.0, 1.6) if u[5] == "short" else Pal.ink(0.9, 1.3))
		lamp(r.position + Vector2(22, 37), lc, u[5] != "")
		txt(u[0], r.position + Vector2(44, 30), 20, Pal.ink(0.95), font_s)
		txt(u[1], r.position + Vector2(44, 60), 20, Pal.tint(Pal.FLUID, 0.95, 1.2) if u[5] == "have" else Pal.ink(0.85), font_s)
		if u[2] != "":
			txt(u[2], Vector2(r.end.x - 12, r.position.y + 60), 16, Pal.heat(1.0, 1.3), font_b, 1)
	var ly := sp.end.y - 14
	for i in 3:
		var lx := sp.position.x + 40 + i * 200
		lamp(Vector2(lx, ly - 6), [Pal.tint(Pal.FLUID, 1.0, 1.6), Pal.ink(0.9, 1.3), Pal.heat(1.0, 1.6)][i], true)
		txt(["已安装", "买得起", "差钱"][i], Vector2(lx + 18, ly), 15, Pal.ink(0.7), font_b)
	# ---- consumables: raised tiles with stock counters
	tag(Rect2(40, 780, 420, 34), "消耗品  ·  用完即止，可以囤", 16)
	var items := [["维修包", "$3,000", 0], ["爆破切割环", "$9,000", 1], ["备用无人机", "$15,000", 0], ["情报包", "$6,000", 2]]
	for i in items.size():
		var r := Rect2(40 + i * 280, 826, 262, 184)
		raised(r, Color(0.1, 0.105, 0.115))
		var ic := r.position + Vector2(44, 52)
		match i:
			0:
				ci.draw_rect(Rect2(ic - Vector2(6, 18), Vector2(12, 36)), Pal.ink(0.9))
				ci.draw_rect(Rect2(ic - Vector2(18, 6), Vector2(36, 12)), Pal.ink(0.9))
			1:
				ci.draw_arc(ic, 18.0, 0.0, TAU, 24, Pal.heat(1.0, 1.4), 3.0, true)
				for k in 8:
					ci.draw_line(ic + Vector2.from_angle(k * PI / 4) * 20, ic + Vector2.from_angle(k * PI / 4) * 27, Pal.heat(1.0, 1.4), 2.0)
			2:
				var pp := PackedVector2Array()
				for v in Art.ARROW:
					pp.append(ic + (v as Vector2) * 0.9)
				ci.draw_polyline(closed(pp), Pal.ink(0.9), 2.0, true)
			3:
				ci.draw_rect(Rect2(ic - Vector2(14, 20), Vector2(28, 40)), Pal.ink(0.9), false, 2.0)
				for k in 3:
					ci.draw_line(ic + Vector2(-8, -8 + k * 8), ic + Vector2(8, -8 + k * 8), Pal.ink(0.8), 1.5)
		var sw := Rect2(r.end.x - 100, r.position.y + 22, 80, 58)
		ci.draw_rect(sw, Color(0.01, 0.012, 0.014))
		ci.draw_rect(sw, Color(0, 0, 0, 0.8), false, 2.0)
		var n: int = items[i][2]
		txt("×%d" % n, sw.get_center() + Vector2(0, 14), 36, Pal.tint(Pal.AIR, 0.95, 1.4) if n > 0 else Pal.ink(0.35), font_s, 0)
		txt(items[i][0], r.position + Vector2(20, 128), 21, Pal.ink(0.95), font_s)
		txt(items[i][1], r.position + Vector2(20, 162), 20, Pal.ink(0.75), font_s)
	# ---- the detail: what the chosen thing changes, and the buy button
	var dp := Rect2(1170, 240, 710, 770)
	raised(dp, Color(0.1, 0.105, 0.115))
	tag(Rect2(dp.position.x + 20, dp.position.y + 20, dp.size.x - 40, 48), "升级 · 永久生效", 20, Pal.tint(Pal.AIR, 0.95, 1.2))
	lamp(Vector2(dp.end.x - 44, dp.position.y + 44), Pal.ink(0.9, 1.3), true)
	var x := dp.position.x + 30
	txt("精密检测套件", Vector2(x, dp.position.y + 130), 42, Pal.ink(0.98), font_s)
	txt("检查设备时显示完好度，能发现结构暗伤", Vector2(x, dp.position.y + 172), 19, Pal.ink(0.8), font_b)
	var gauges := [["设备完好度读数", "无", "显示"], ["结构暗伤", "看不到", "能发现"]]
	for i in gauges.size():
		var gy2 := dp.position.y + 230 + i * 96
		txt(gauges[i][0], Vector2(x, gy2), 18, Pal.ink(0.7), font_b)
		txt(gauges[i][1] + "  →  " + gauges[i][2], Vector2(dp.end.x - 30, gy2), 20, Pal.ink(0.95), font_s, 1)
		var bar := Rect2(x, gy2 + 16, dp.size.x - 60, 26)
		ci.draw_rect(bar, Color(0.02, 0.022, 0.026))
		for seg in 10:
			var sr := Rect2(bar.position.x + 3 + seg * (bar.size.x - 6) / 10.0, bar.position.y + 3, (bar.size.x - 6) / 10.0 - 4, bar.size.y - 6)
			ci.draw_rect(sr, Pal.heat(1.0, 1.3) if seg < 8 else Color(0.06, 0.064, 0.07))
	var sc := Rect2(x - 10, dp.position.y + 430, dp.size.x - 40, 110)
	ci.draw_rect(sc, Color(0.02, 0.024, 0.028))
	txt("改变的打法", sc.position + Vector2(14, 32), 16, Pal.ink(0.6), font_b)
	txt("先判断值不值得完整拆，再决定切还是拆", sc.position + Vector2(14, 74), 22, Pal.tint(Pal.AIR, 0.95, 1.2), font_s)
	var rows := [["价格", "$24,000"], ["买后余额", "$17,250"], ["下一单合同费", "仍够付（最低 $1,000）"]]
	for i in rows.size():
		var ry := dp.position.y + 590 + i * 40
		txt(rows[i][0], Vector2(x, ry), 18, Pal.ink(0.6), font_b)
		txt(rows[i][1], Vector2(dp.end.x - 30, ry), 22, Pal.ink(0.95), font_s, 1)
	var bc := Rect2(dp.position.x + 20, dp.end.y - 96, dp.size.x - 40, 80)
	raised(bc, Color(0.13, 0.135, 0.145))
	var cc := bc.position + Vector2(56, 40)
	ci.draw_circle(cc, 28.0, Color(0.02, 0.02, 0.02))
	ci.draw_circle(cc, 23.0, Pal.tint(Pal.FLUID, 0.95, 1.25))
	ci.draw_arc(cc, 28.0, 0.0, TAU, 28, Color(1, 1, 1, 0.3), 2.0, true)
	txt("购买  $24,000", bc.position + Vector2(108, 52), 32, Pal.ink(0.98), font_s)
	txt("ENTER", Vector2(bc.end.x - 24, bc.position.y + 52), 20, Pal.ink(0.55), font_b, 1)
