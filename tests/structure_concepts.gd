extends SceneTree
# The terminal's structure, three directions as mock-ups for the player
# (2026-10-18, after a look at Hardspace: Shipbreaker, Ship Graveyard
# Simulator, Car Mechanic Simulator, PowerWash Simulator): A a device with app
# tiles (the same device on site, what can't be used there locked with the
# reason), B a hub of stations on the berth's drawing, C four tabs. In the
# chosen HMI look; sample data only, no saves touched.
# tools/run_test.sh tests/structure_concepts.gd -- a|a_site|b|c

const Cap = preload("res://tests/cap.gd")
const Art = preload("res://scripts/drone_art.gd")
const W := 1920.0
const H := 1080.0
var sheet: Node2D
var font: Font
var font_b: Font
var font_s: Font
var font_l: Font
var mode := "a"


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		if a in ["a", "a_site", "b", "c"]:
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
	Cap.save(root, "res://tests/out/struct_%s.png" % mode)
	quit()


func txt(s: String, p: Vector2, size: int, col: Color, f: Font = null, align: int = -1, w: float = -1.0) -> void:
	var fo := f if f != null else font
	var x := p.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	sheet.draw_string(fo, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


func header(subtitle: String) -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, W, H), Hmi.BG)
	Hmi.raised(ci, Rect2(0, 0, W, 116), 1.0, Hmi.HEAD)
	Hmi.plate(ci, font_s, Rect2(40, 22, 420, 72), "船坞终端", 28)
	txt("BERTH 07  ·  CHARON-DISPATCH", Vector2(484, 50), 14, Pal.ink(0.6), font_b)
	Hmi.lamp(ci, Vector2(492, 76), Hmi.ok_col(), true, 1.0, 6.0)
	txt(subtitle, Vector2(508, 82), 15, Pal.ink(0.75), font_b)
	var top := [["资金", "$41,250", Pal.ink(0.98), Hmi.ok_col()], ["贷款", "$36,000", Pal.heat(1.0, 1.3), Hmi.warn_col()], ["每单应付", "$20,720", Pal.ink(0.9), Hmi.ok_col()], ["声望", "认证", Pal.ink(0.98), Hmi.ok_col()]]
	for i in 4:
		var r := Rect2(W - 40 - (4 - i) * 296 + 16, 18, 280, 80)
		Hmi.readout(ci, font_s, font_b, r, top[i][0], top[i][1], top[i][2], top[i][3], 1.0)


# the "next goal" strip every layout carries (P.8)
func goal_strip(y: float) -> void:
	var r := Rect2(40, y, W - 80, 44)
	Hmi.sunk(sheet, r)
	Hmi.lamp(sheet, Vector2(r.position.x + 22, r.get_center().y), Pal.heat(1.0, 1.6), true, 1.0, 6.0)
	txt("下一个目标", Vector2(r.position.x + 40, r.position.y + 29), 15, Pal.ink(0.6), font_b)
	txt("攒够 $21,750 买「矢量推进 II」  ·  再拆 2 艘船解锁 M-14「鼹鼠」采矿船  ·  声望再 6 点升「资深」", Vector2(r.position.x + 150, r.position.y + 29), 17, Pal.ink(0.92), font_s)


func _draw_sheet() -> void:
	match mode:
		"a": _tablet(false)
		"a_site": _tablet(true)
		"b": _hub()
		"c": _tabs()


# ---------------------------------------------------------------- A · one device, app tiles
func _tablet(site: bool) -> void:
	var ci := sheet
	if site:
		# over the berth: the game dimmed behind
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.035, 0.04))
		for i in 30:
			ci.draw_line(Vector2(i * 70, 0), Vector2(i * 70 - 400, H), Color(1, 1, 1, 0.02), 1.0)
		var dev := Rect2(260, 90, 1400, 900)
		Hmi.raised(ci, dev.grow(18), 1.0, Hmi.HEAD)
		ci.draw_rect(dev, Hmi.BG)
		Hmi.plate(ci, font_s, Rect2(dev.position.x + 24, dev.position.y + 20, 520, 56), "船坞终端  ·  现场", 24)
		txt("作业中  ·  游戏已暂停  ·  按 B 或 Esc 回到作业", Vector2(dev.position.x + 570, dev.position.y + 56), 16, Pal.ink(0.7), font_b)
		_tiles(Rect2(dev.position.x + 24, dev.position.y + 110, dev.size.x - 48, dev.size.y - 140), true)
		return
	header("首页")
	goal_strip(130)
	_tiles(Rect2(40, 196, W - 80, H - 236), false)


func _tiles(area: Rect2, site: bool) -> void:
	var ci := sheet
	# [name, line 1, line 2, lamp, open on site, why not]
	var apps := [
		["合同", "3 份报价 · 主线 S09-001 置顶", "挑下一单", Hmi.warn_col(), false, "合同只在两单之间签"],
		["装备", "升级 4 · 消耗品 4 · 船坞设施 8", "买设备、设施、补给", Hmi.can_col(), false, "设备和设施下一单生效：两单之间开放"],
		["技能书", "已掌握 3 / 51 级", "当场装配", Hmi.ok_col(), true, ""],
		["消耗品", "维修包 ×0 · 切割环 ×1 · 情报 ×2", "现场买的直接进本单库存", Hmi.can_col(), true, ""],
		["账本", "贷款 $36,000 · 每单应付 $20,720", "还款、看收支", Hmi.warn_col(), false, "两单之间开放"],
		["路线", "下一艘新船：M-14「鼹鼠」还差 2 单", "能解锁什么、还差多少", Hmi.can_col(), true, ""],
		["无线电", "梁工 · 3 条未读", "回看对话和记录", Hmi.ok_col(), true, ""],
		["训练舱", "TS-1 六课", "随时重玩训练", Hmi.can_col(), false, "两单之间开放"],
	]
	if site:
		# on site the device shows what can be used now first
		apps = apps.filter(func(x): return x[4]) + apps.filter(func(x): return not x[4])
	var cols := 4
	var gap := 22.0
	var tw := (area.size.x - gap * (cols - 1)) / cols
	var th := (area.size.y - gap) / 2.0
	for i in apps.size():
		var a: Array = apps[i]
		var r := Rect2(area.position.x + (i % cols) * (tw + gap), area.position.y + (i / cols) * (th + gap), tw, th)
		var locked: bool = site and not a[4]
		var sel := i == (0 if site else 0)
		Hmi.raised(ci, r, 1.0 if not locked else 0.6, Hmi.PANEL_HI if sel and not locked else Hmi.PANEL)
		if sel and not locked:
			ci.draw_rect(r.grow(4), Pal.heat(1.0, 1.4), false, 4.0)
		var sc := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, r.size.y * 0.5)
		Hmi.screen(ci, sc, 1.0 if not locked else 0.6)
		_icon(a[0], sc.get_center(), 1.0 if not locked else 0.35)
		Hmi.lamp(ci, Vector2(r.end.x - 30, sc.end.y + 30), a[3] if not locked else Pal.ink(0.3), not locked)
		txt(a[0], Vector2(r.position.x + 22, sc.end.y + 42), 30, Pal.ink(0.98 if not locked else 0.45), font_s)
		txt(a[1], Vector2(r.position.x + 22, sc.end.y + 76), 16, Pal.ink(0.8 if not locked else 0.4), font_b)
		if locked:
			txt("锁定 · " + a[5], Vector2(r.position.x + 22, sc.end.y + 104), 15, Pal.heat(0.9, 1.2), font_b, -1, r.size.x - 44)
		else:
			txt(a[2], Vector2(r.position.x + 22, sc.end.y + 104), 15, Pal.tint(Pal.AIR, 0.9, 1.2), font_b)
	var key := "← → ↑ ↓ 选择   ENTER 打开   B 现场呼出   ESC 返回" if site else "← → ↑ ↓ 选择   ENTER 打开   1–8 直达   ESC 返回标题"
	txt(key, Vector2(area.position.x, area.end.y + (24 if not site else 22)), 15, Pal.ink(0.5), font_b)


func _icon(name: String, c: Vector2, a: float) -> void:
	var ci := sheet
	var col := Pal.tint(Pal.AIR, 0.95 * a, 1.3)
	match name:
		"合同":
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-70 + k * 50, -36 + k * 6), Vector2(44, 64)), col, false, 2.0)
		"装备":
			var xf := Transform2D(0.0, Vector2(2.6, 2.6), 0.0, c)
			ci.draw_set_transform_matrix(xf)
			Art.tint = Color(Pal.AIR.r * a, Pal.AIR.g * a, Pal.AIR.b * a)
			Art.draw(ci, "arrowring", {"heading": -0.3, "tool": 0, "open": 0.4, "t": 1.0, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
			Art.tint = Color(1, 1, 1)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		"技能书":
			ci.draw_rect(Rect2(c + Vector2(-40, -40), Vector2(80, 80)), col, false, 2.0)
			for k in 4:
				ci.draw_line(c + Vector2(-26, -22 + k * 14), c + Vector2(26, -22 + k * 14), col, 1.6)
		"消耗品":
			ci.draw_arc(c, 30.0, 0.0, TAU, 28, Pal.heat(a, 1.4), 3.0, true)
			ci.draw_rect(Rect2(c + Vector2(-6, -20), Vector2(12, 40)), col)
			ci.draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 12)), col)
		"账本":
			for k in 5:
				ci.draw_rect(Rect2(c + Vector2(-60 + k * 26, 30 - k * 12), Vector2(18, 10 + k * 12)), col)
		"路线":
			var pts := PackedVector2Array([c + Vector2(-80, 20), c + Vector2(-30, -10), c + Vector2(20, 14), c + Vector2(80, -24)])
			ci.draw_polyline(pts, col, 2.0, true)
			for q in pts:
				ci.draw_circle(q, 6.0, col)
		"无线电":
			for k in 3:
				ci.draw_arc(c + Vector2(-30, 0), 16.0 + k * 16, -0.8, 0.8, 12, col, 2.0, true)
			ci.draw_circle(c + Vector2(-30, 0), 6.0, col)
		"训练舱":
			ci.draw_rect(Rect2(c + Vector2(-60, -30), Vector2(120, 60)), col, false, 2.0)
			ci.draw_circle(c, 10.0, col)


# ---------------------------------------------------------------- B · stations on the berth
func _hub() -> void:
	var ci := sheet
	header("首页 · 选一个站")
	goal_strip(130)
	var scr := Rect2(40, 196, W - 80, H - 280)
	Hmi.screen(ci, scr, 1.0, true)
	# the berth drawn faint: floor, boom, the drone bay
	var M := 12.0
	ci.draw_line(scr.position + Vector2(60, scr.size.y - 60), scr.end - Vector2(60, 60), Pal.tint(Pal.AIR, 0.4), 2.0)
	ci.draw_line(scr.position + Vector2(60, 70), Vector2(scr.end.x - 400, scr.position.y + 70), Pal.tint(Pal.AIR, 0.4), 2.0)
	var stations := [["合同板", "3 份报价 · 主线置顶", Vector2(0.18, 0.35)], ["装备台", "升级 · 消耗品 · 设施", Vector2(0.42, 0.62)], ["技能书", "3 / 51 级", Vector2(0.62, 0.3)], ["账本", "贷款 $36,000", Vector2(0.82, 0.6)], ["路线", "还差 2 单解锁 M-14", Vector2(0.5, 0.18)], ["训练舱", "TS-1", Vector2(0.12, 0.72)]]
	for i in stations.size():
		var s: Array = stations[i]
		var p: Vector2 = scr.position + scr.size * (s[2] as Vector2)
		ci.draw_circle(p, 30.0, Color(0.02, 0.024, 0.028))
		ci.draw_arc(p, 30.0, 0.0, TAU, 32, Pal.heat(1.0, 1.4) if i == 0 else Pal.tint(Pal.AIR, 0.9, 1.3), 3.0, true)
		Hmi.lamp(ci, p, Pal.heat(1.0, 1.6) if i == 0 else Hmi.ok_col(), true, 1.0, 9.0)
		var r := Rect2(p + Vector2(44, -34), Vector2(300, 70))
		Hmi.raised(ci, r, 1.0, Hmi.PANEL_HI if i == 0 else Hmi.PANEL)
		if i == 0:
			ci.draw_rect(r.grow(3), Pal.heat(1.0, 1.4), false, 3.0)
		txt(s[0], r.position + Vector2(16, 32), 24, Pal.ink(0.98), font_s)
		txt(s[1], r.position + Vector2(16, 58), 15, Pal.ink(0.75), font_b)
	var xf := Transform2D(0.0, Vector2(3.0, 3.0), 0.0, scr.position + scr.size * Vector2(0.3, 0.5))
	ci.draw_set_transform_matrix(xf)
	Art.tint = Color(Pal.AIR.r * 0.7, Pal.AIR.g * 0.7, Pal.AIR.b * 0.7)
	Art.draw(ci, "arrowring", {"heading": 0.2, "tool": 0, "open": 0.4, "t": 1.0, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	txt("← → 选站   ENTER 打开   现场：按 B 或靠近电脑，同一张图，用不了的站熄灯并写原因", Vector2(40, H - 52), 16, Pal.ink(0.55), font_b)


# ---------------------------------------------------------------- C · four tabs
func _tabs() -> void:
	var ci := sheet
	header("合同")
	var names := ["1  合同", "2  装备", "3  技能书", "4  账本"]
	for i in 4:
		Hmi.rocker(ci, font_s, Rect2(40 + i * 244, 132, 230, 50), names[i], i == 0, 0.0, 1.0)
	txt("路线 / 无线电 / 训练：右上角按钮", Vector2(W - 40, 164), 15, Pal.ink(0.55), font_b, 1)
	goal_strip(198)
	for i in 3:
		var r := Rect2(40 + i * 620, 262, 600, 690)
		Hmi.raised(ci, r, 1.0, Hmi.PANEL_HI if i == 1 else Hmi.PANEL)
		if i == 1:
			ci.draw_rect(r.grow(4), Pal.heat(1.0, 1.4), false, 4.0)
		Hmi.plate(ci, font_s, Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 46), ["主线合同 · 置顶", "完整拆解", "分段拆解"][i], 21)
		var sc := Rect2(r.position.x + 18, r.position.y + 80, r.size.x - 36, 260)
		Hmi.screen(ci, sc)
		txt(["S09-001", "$72,000", "$45,800"][i], sc.position + Vector2(16, 100), 64, Pal.tint(Pal.AIR, 1.0, 1.35), font_l)
		for k in 5:
			txt(["船长", "预估价值", "合同费", "工期", "风险"][k], Vector2(r.position.x + 30, r.position.y + 400 + k * 44), 16, Pal.ink(0.6), font)
	Hmi.push(ci, font_s, Rect2(660, 968, 600, 62), "接单", true, 0.0, 1.0, 0.0)
	txt("现场：按 B 或靠近电脑，打开同一个终端，「合同」「装备」「账本」标签熄灯并写原因，停在技能书", Vector2(40, H - 14), 15, Pal.ink(0.55), font_b)
