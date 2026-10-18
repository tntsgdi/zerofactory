extends SceneTree
# The drone redesign's concept sheet (2026-10-17): three airframe directions,
# each shown idle, with the laser, the grapple, the meter, the wrench, and
# flat out (thrust and dash), big enough to judge, plus at game size. Drawn by
# scripts/drone_art.gd with the game's own glow.
# tools/run_test.sh tests/drone_concepts.gd -- [t=seconds]

const Cap = preload("res://tests/cap.gd")
const Art = preload("res://scripts/drone_art.gd")
const SETS := {
	"abc": [["gimbal", "A · 环核  GIMBAL", "圆核 + 旋转外环；四个喷舱装在支杆上，随推力方向偏转"],
		["wedge", "B · 楔形  WEDGE", "箭头形机身指向瞄准方向；两侧收着机械臂，尾部双主推，鼻部微调喷口"],
		["tripod", "C · 三爪  TRIPOD", "六边形核心 + 三条关节机械爪，飞行时轻微屈伸；喷口装在肘关节"]],
	"mix": [["arrowring", "H1 · 箭环  ARROW-RING", "箭头底盘托着旋转环核；翼尖双主推，翼侧两个偏转喷舱管侧推和刹车；鼻部两侧两条口器式机械爪，夹着工具头，抓钩/维护时前伸张开"],
		["coreclaw", "H2 · 核爪  CORE-CLAW", "环核居中，箭头护鼻；尾部两个偏转喷舱就是双主推；鼻部两侧两条口器式机械爪，抓钩/维护时前伸张开"]],
}
var DESIGNS: Array = SETS.abc
const STATES := [["待机", 0, 0.0, Vector2.ZERO, false], ["激光", 2, 1.0, Vector2.ZERO, false], ["抓钩", 3, 1.0, Vector2.ZERO, false],
	["测量", 1, 1.0, Vector2.ZERO, false], ["维护", 4, 1.0, Vector2.ZERO, false], ["冲刺", 3, 0.0, Vector2(1, 0), true]]
const SCALE := 3.2
var sheet: Node2D
var font: Font
var font_b: Font
var t := 1.3
var out := "res://tests/out/drone_concepts.png"


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("t="):
			t = float(a.substr(2))
		if SETS.has(a):
			DESIGNS = SETS[a]
			out = "res://tests/out/drone_concepts_%s.png" % a
	_run()


func _run() -> void:
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
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
	for i in 6:
		await process_frame
	Cap.save(root, out)
	quit()


func _draw_sheet() -> void:
	var ci := sheet
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.018, 0.02, 0.024))
	var x := 0.0
	while x < 1920.0:
		ci.draw_line(Vector2(x, 0), Vector2(x, 1080), Color(1, 1, 1, 0.025), 1.0)
		x += 40.0
	var y := 0.0
	while y < 1080.0:
		ci.draw_line(Vector2(0, y), Vector2(1920, y), Color(1, 1, 1, 0.025), 1.0)
		y += 40.0
	ci.draw_string(font_b, Vector2(60, 64), "R-02 无人机 · 外形重设计 · " + ("三个方向" if DESIGNS.size() == 3 else "混合方案：A 环核 + B 箭头机身 + C 机械爪 + 光圈镜头"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.95))
	ci.draw_string(font, Vector2(60, 96), "同一套线稿画法与辉光；每行：待机 / 激光 / 抓钩 / 测量 / 维护 / 冲刺（放大 3.2 倍），左边是游戏里的实际大小。碰撞体不变（半径 20）。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	var cw := 250.0
	var rh := 300.0 if DESIGNS.size() == 3 else 420.0
	for r in DESIGNS.size():
		var d: Array = DESIGNS[r]
		var y0 := 140.0 + r * rh
		ci.draw_line(Vector2(60, y0), Vector2(1860, y0), Pal.ink(0.12), 1.0)
		ci.draw_string(font_b, Vector2(60, y0 + 40), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink(0.95))
		ci.draw_multiline_string(font, Vector2(60, y0 + 66), d[2], HORIZONTAL_ALIGNMENT_LEFT, 320, 14, -1, Pal.ink(0.55))
		# at game size
		ci.draw_rect(Rect2(60, y0 + 120, 220, 140), Color(0.03, 0.032, 0.036))
		ci.draw_rect(Rect2(60, y0 + 120, 220, 140), Pal.ink(0.15), false, 1.0)
		ci.draw_string(font, Vector2(70, y0 + 140), "游戏里 1:1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
		_one(ci, d[0], Vector2(130, y0 + 200), 1.0, STATES[1], -0.4)
		_one(ci, d[0], Vector2(220, y0 + 200), 1.0, STATES[5], 0.0)
		for c in STATES.size():
			var cx := 420.0 + c * cw + cw * 0.5
			var cy := y0 + rh * 0.52
			_one(ci, d[0], Vector2(cx, cy), SCALE, STATES[c], -0.35)
			ci.draw_string(font, Vector2(cx - 40, y0 + rh - 22), STATES[c][0], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Pal.ink(0.6))


func _one(ci: CanvasItem, design: String, at: Vector2, s: float, state: Array, heading: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
	ci.draw_set_transform_matrix(xf)
	var st := {"design": design, "heading": heading, "tool": state[1], "open": state[2], "t": t, "thrust": state[3], "dash": state[4], "base_xf": xf}
	if state[4]:
		# afterimages behind it at full burn
		for i in range(5, 0, -1):
			var k := 1.0 - i / 6.0
			ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, at - Vector2(9.0 * i * s, 0)))
			ci.draw_circle(Vector2.ZERO, 16.0 * (0.6 + 0.4 * k), Pal.ink(0.04 * k))
		ci.draw_set_transform_matrix(xf)
	Art.draw(ci, design, st)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
