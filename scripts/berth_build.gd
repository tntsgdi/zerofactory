extends Node2D
# The berth growing in front of the operator, for an extension bought at the
# terminal (player 2026-10-20: "a scientific, hard-core animation", not just
# longer next time) and for a ship taller than the berth (player 2026-10-20: "a
# horizontal rectangle, and a solar sail comes in: show in detail how the berth
# grows to take it"). The steps a real in-space job would run, only those the
# change needs:
#   iso    the work zone is closed and the tractor field's edge pushed out to the
#          new envelope; the incoming ship's outline is shown where it will lie;
#   lift   the boom is jacked up: a climbing frame on the tower lifts it one stroke,
#          a 3 m standard section slides into the gap and is bolted, and again;
#   drop   the platform is drawn down along guide columns by pull-type strand jacks
#          (in free fall a strand can only pull: the anchors sit below the floor);
#   haul   a tug pushes in the folded truss cassettes;
#   deploy an articulated truss deploys bay by bay out of the canister at the old end;
#   latch  every module interface is latched, then bolted (M20 grade 10.9, 125 kN);
#   weld   the seams are electron-beam welded: EB welding needs a vacuum, which the berth is;
#   test   the service lines are proof-pressurised with helium to 1.5 × working while
#          the floor carries 1.25 × its design load (sag drawn 200 × against L/800);
#   cert   the berth is laid out at its new size: the mouths and the furnace roll to
#          their new places, the field is recalibrated and the lights come up.
# A ship type's second time runs the same steps fast. Any key or click skips to
# the end. Drawn in the dock's own space (px).

const M := 48.0
const MOD := 6.0           # m per truss module (and between two interfaces)
const BAY := 0.6           # m per truss bay
const SECTION := 3.0       # m per tower standard section
const P_PROOF := 1.80      # MPa: 1.5 × the service lines' 1.2 MPa working pressure
const DEFL := 3.1          # mm measured under proof load at mid-module
const DEFL_MAX := 7.5      # mm: L/800 of a 6 m module
const BASE_Y := 9.0        # m: the floor line with nothing dropped
const BASE_RAIL := -10.0   # m: the boom's rail with nothing lifted

var game
var dock
var x_a := 50.0            # m: the old end
var x_b := 88.0            # m: the new end
var lift_a := 0.0
var lift_b := 0.0
var drop_a := 0.0
var drop_b := 0.0
var quick := false
var envelope := Rect2()    # m: the incoming ship's outline (none over the empty berth)
var ship_name := ""
var t := 0.0
var steps: Array = []      # [key, seconds]
var t0: Array = []
var relaid := false
var moves := {}            # what rolls to its new place: key -> [from, to]
var _step := -1
var _flash_t := 0.0
var _last_bay := 0
var _shape := Vector2(-1, -1)
var _sect := 0
# a close-up window under the checklist: a second camera on the same world, held on
# the mechanism the step is about (the climbing frame, a strand jack, the truss tip...)
var inset_vp: SubViewport
var inset_cam: Camera2D
var inset_ui: Control
var _inset_at := Vector2.INF


func setup(g, from: Dictionary, to: Dictionary, fast: bool = false, env: Rect2 = Rect2(), title: String = "") -> void:
	game = g
	dock = g.dock
	x_a = float(from.len)
	x_b = float(to.len)
	lift_a = float(from.lift)
	lift_b = float(to.lift)
	drop_a = float(from.drop)
	drop_b = float(to.drop)
	quick = fast
	envelope = env
	ship_name = title
	var k := 0.3 if quick else 1.0
	steps = [["iso", 2.5]]
	if lift_b > lift_a + 0.1:
		steps.append(["lift", clampf(sections() * 0.45, 3.0, 8.0)])
	if drop_b > drop_a + 0.1:
		steps.append(["drop", clampf((drop_b - drop_a) * 0.12, 3.0, 7.0)])
	if x_b > x_a + 0.1:
		steps.append_array([["haul", 3.5], ["deploy", clampf(float(modules()) * 0.55, 4.0, 9.0)], ["latch", 3.0], ["weld", 3.5]])
	steps.append_array([["test", 4.0], ["cert", 3.0]])
	var acc := 0.0
	for s in steps:
		s[1] = float(s[1]) * k
		t0.append(acc)
		acc += float(s[1])
	_make_inset()


func _make_inset() -> void:
	inset_vp = SubViewport.new()
	inset_vp.size = Vector2i(640, 330)
	inset_vp.world_2d = game.get_viewport().world_2d
	inset_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(inset_vp)
	inset_cam = Camera2D.new()
	inset_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	inset_vp.add_child(inset_cam)
	inset_cam.enabled = true
	var layer := CanvasLayer.new()
	layer.layer = 61
	add_child(layer)
	inset_ui = Control.new()
	inset_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset_ui.draw.connect(_draw_inset)
	layer.add_child(inset_ui)


# what the close-up looks at in this step: [point (m), zoom, caption key]
func inset_focus() -> Array:
	var F := Dock.FLOOR_Y
	var R := Dock.RAIL_Y
	match key():
		"iso":
			return [Vector2(Dock.TOWER_X + 2.0, R + 1.0), 0.9, "bb_c_iso"]
		"lift":
			return [Vector2(Dock.TOWER_X + 0.3, R + 2.4), 1.25, "bb_c_lift"]
		"drop":
			var xs := jack_xs()
			var jx: float = xs[mini(1, xs.size() - 1)]
			return [Vector2(jx, F + 1.6), 1.15, "bb_c_drop"]
		"haul":
			return [Vector2(x_a + 3.0, F + 1.2), 0.85, "bb_c_haul"]
		"deploy":
			return [Vector2(x_a + front(), F + 0.3), 1.5, "bb_c_deploy"]
		"latch":
			return [Vector2(x_a, F + 0.3), 1.6, "bb_c_latch"]
		"weld":
			var j := 0
			for q in modules() + 1:
				if joint_k("weld", q) < 1.0:
					j = q
					break
			return [Vector2(minf(x_a + j * MOD, x_b) + 0.2, F + 0.3), 1.8, "bb_c_weld"]
		"test":
			return [Vector2(x_b - 1.5, F + 1.0), 1.3, "bb_c_test"]
	return [Dock.ZONES.hazard.pos + Vector2(0.0, -1.0), 0.9, "bb_c_cert"]


func inset_rect() -> Rect2:
	var bar := 70.0
	var y := bar + 26.0 + 66.0 + steps.size() * 50.0 + 16.0
	return Rect2(48.0, y, 640.0, minf(330.0, 1080.0 - bar - 24.0 - y))


func _draw_inset() -> void:
	var r := inset_rect()
	if r.size.y < 120.0:
		return
	var k_in := clampf(t / 0.4, 0.0, 1.0) * clampf((total() - t) / 0.35, 0.0, 1.0)
	inset_ui.draw_rect(r.grow(4.0), Color(0.02, 0.022, 0.026, 0.92 * k_in))
	inset_ui.draw_texture_rect_region(inset_vp.get_texture(), r, Rect2(Vector2.ZERO, r.size), Color(1, 1, 1, k_in))
	inset_ui.draw_rect(r, Pal.heat(0.6 * k_in, 1.1), false, 1.4)
	# corner ticks and a centre cross, like a camera's finder
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		inset_ui.draw_line(p + d * 6.0, p + d * 6.0 + Vector2(22.0 * d.x, 0), Pal.ink(0.8 * k_in), 2.0)
		inset_ui.draw_line(p + d * 6.0, p + d * 6.0 + Vector2(0, 22.0 * d.y), Pal.ink(0.8 * k_in), 2.0)
	var font: Font = Fonts.get_font("Medium")
	var f: Array = inset_focus()
	var cap := Txt.t("bb_close") + " · " + Txt.t(str(f[2]))
	inset_ui.draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0, 24)), Color(0.02, 0.022, 0.026, 0.85 * k_in))
	inset_ui.draw_string(font, r.position + Vector2(20, 27), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.heat(0.95 * k_in, 1.2))
	inset_ui.draw_string(font, Vector2(r.end.x - 70, r.end.y - 12), "×%.1f" % (float(f[1]) / maxf(0.02, game.cam_zoom())), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.6 * k_in))


func total() -> float:
	return float(t0[-1]) + float(steps[-1][1])


func modules() -> int:
	return maxi(1, ceili((x_b - x_a) / MOD - 0.01))


func bays() -> int:
	return maxi(1, int(round((x_b - x_a) / BAY)))


func sections() -> int:
	return maxi(1, ceili((lift_b - lift_a) / SECTION - 0.01))


func cassettes() -> int:
	return clampi(modules(), 2, 7)


func idx(key: String) -> int:
	for i in steps.size():
		if steps[i][0] == key:
			return i
	return -1


func current() -> int:
	for i in range(steps.size() - 1, -1, -1):
		if t >= float(t0[i]):
			return i
	return 0


func key() -> String:
	return str(steps[current()][0])


func k(i: int) -> float:
	if i < 0:
		return 0.0
	return clampf((t - float(t0[i])) / float(steps[i][1]), 0.0, 1.0)


func kk(key_: String) -> float:
	return k(idx(key_))


func passed(key_: String) -> bool:
	var i := idx(key_)
	return i >= 0 and t >= float(t0[i])


func front() -> float:
	return (x_b - x_a) * Pal.ease_io(kk("deploy"))


# the boom's lift now: one climbing stroke per section (the cylinders push for the
# first 60 % of a cycle, then the new section slides into the gap)
func lift_now() -> float:
	if not passed("lift"):
		return lift_a
	var n := sections()
	var u := kk("lift") * n
	var i := mini(int(u), n - 1)
	var f := u - i if kk("lift") < 1.0 else 1.0
	return minf(lift_b, lift_a + (i + Pal.ease_io(clampf(f / 0.6, 0.0, 1.0))) * (lift_b - lift_a) / n)


func drop_now() -> float:
	if not passed("drop"):
		return drop_a
	return drop_a + (drop_b - drop_a) * Pal.ease_io(kk("drop"))


# how far each interface is through latching / welding (j from the old end out)
func joint_k(key_: String, j: int) -> float:
	var n := float(modules())
	return clampf(kk(key_) * 1.6 - float(j) / n * 0.6, 0.0, 1.0)


func pressure() -> float:
	return P_PROOF * Pal.ease_out(clampf(kk("test") / 0.6, 0.0, 1.0))


func deflection() -> float:
	return DEFL * Pal.ease_out(clampf(kk("test") / 0.6, 0.0, 1.0))


# the tractor field's inner edge for a berth of this size (m)
static func field(len_: float, lift: float, drop: float) -> Rect2:
	var b := Rect2(-6.8, -15.0 - lift, 63.0 + len_ - 50.0, 24.0 + lift + drop)
	return Rect2(b.position + Vector2(0.0, 2.0), b.size - Vector2(2.5, 2.0))


# the heading line: what changes
func head() -> String:
	var parts: Array = []
	if x_b > x_a + 0.1:
		parts.append(Txt.t("bb_h_len") % [x_a, x_b])
	if lift_b > lift_a + 0.1:
		parts.append(Txt.t("bb_h_lift") % (lift_b - lift_a))
	if drop_b > drop_a + 0.1:
		parts.append(Txt.t("bb_h_drop") % (drop_b - drop_a))
	return Txt.t("bb_head") % " · ".join(parts)


# the live line for the step in hand (the HUD's checklist)
func detail(i: int) -> String:
	match str(steps[i][0]):
		"iso":
			var f0 := field(x_a, lift_a, drop_a)
			var f1 := field(x_b, lift_b, drop_b)
			var e := Pal.ease_io(k(i))
			return Txt.t("bb_iso") % [lerpf(f0.size.x, f1.size.x, e), lerpf(f0.size.y, f1.size.y, e)]
		"lift":
			var done := mini(sections(), int(k(i) * sections() + 0.4))
			return Txt.t("bb_lift") % [done, sections(), lift_now() - lift_a]
		"drop":
			var cr := 0.3 + 1.2 * absf(sin(t * 3.1))
			return Txt.t("bb_drop") % [drop_now() - drop_a, drop_b - drop_a, jack_count(), cr]
		"haul":
			return Txt.t("bb_haul") % [cassettes(), x_b - x_a]
		"deploy":
			return Txt.t("bb_deploy") % [mini(bays(), int(front() / BAY + 0.001)), bays()]
		"latch":
			var nl := 0
			for j in modules() + 1:
				if joint_k("latch", j) >= 1.0:
					nl += 1
			return Txt.t("bb_latch") % [nl, modules() + 1]
		"weld":
			var nw := 0
			for j in modules() + 1:
				if joint_k("weld", j) >= 1.0:
					nw += 1
			return Txt.t("bb_weld") % [nw, modules() + 1]
		"test":
			return Txt.t("bb_test") % [pressure(), deflection(), DEFL_MAX]
		"cert":
			return Txt.t("bb_cert") % x_b
	return ""


# the strand jacks' columns along the floor (m)
func jack_xs() -> Array:
	var xs: Array = []
	var x := Dock.TOWER_X + 3.0
	var end := maxf(x_a, Dock.FLOOR_X1) - 2.0
	var n := maxi(2, ceili((end - x) / 30.0))
	for i in n + 1:
		xs.append(lerpf(x, end, float(i) / n))
	return xs


func jack_count() -> int:
	return jack_xs().size()


# where the camera looks, and how close: [centre px, zoom]
func cam(vs: Vector2) -> Array:
	var kname := key()
	var lo := x_a - 16.0
	var hi := x_a + 28.0
	var top := Dock.RAIL_Y - 3.0
	var bot := Dock.FLOOR_Y + 6.5
	if kname in ["iso", "lift", "drop"]:
		# the whole berth and the envelope it grows to
		lo = Dock.TOWER_X - 4.0
		hi = maxf(x_b, x_a) + 8.0
		top = minf(BASE_RAIL - lift_b, Dock.RAIL_Y) - 6.0
		bot = maxf(BASE_Y + drop_b, Dock.FLOOR_Y) + 9.0
		if envelope.size != Vector2.ZERO:
			hi = maxf(hi, envelope.end.x + 4.0)
			top = minf(top, envelope.position.y - 4.0)
			bot = maxf(bot, envelope.end.y + 4.0)
	elif kname == "deploy":
		lo = x_a - 12.0
		hi = x_a + maxf(28.0, front() + 14.0)
	elif kname in ["latch", "weld", "test"]:
		lo = x_a - 12.0 if x_b > x_a + 0.1 else Dock.TOWER_X - 4.0
		hi = x_b + 8.0
	elif kname == "cert":
		lo = Dock.TOWER_X - 2.0
		hi = x_b + 8.0
	hi = minf(hi, maxf(x_b, envelope.end.x + 4.0) + 8.0)
	if not kname in ["iso", "lift", "drop", "cert"] and bot - top > 40.0:
		# a very tall berth: the work on the floor
		top = Dock.FLOOR_Y - 16.0
		bot = Dock.FLOOR_Y + 8.0
	var z := clampf(minf((vs.x - 720.0) / ((hi - lo) * M), (vs.y - 200.0) / ((bot - top) * M)), 0.015, 1.4)
	# the checklist sits on the left: the work a little right of the middle
	return [Vector2((lo + hi) * 0.5 * M - 330.0 / z, (top + bot) * 0.5 * M), z]


# one frame: true when it is done
func step(dt: float) -> bool:
	t += dt
	var i := current()
	var kname := key()
	if i != _step:
		_step = i
		var snd: String = {"iso": "holo", "lift": "clamp", "drop": "hiss", "haul": "launch", "deploy": "clank", "latch": "clamp", "weld": "arc", "test": "hiss", "cert": "ok"}.get(kname, "ok")
		game.sfx.play(snd, Vector2.INF, 0.8)
		if kname == "test" and not relaid:
			_relay()
	# the berth's shape follows the jacks
	if not relaid:
		var sh := Vector2(lift_now(), drop_now())
		if sh.distance_to(_shape) > 0.01:
			_shape = sh
			game._layout_shape(x_a, sh.x, sh.y)
	_flash_t -= dt
	var vis: Vector2 = dock._vis_x() / M
	var F := Dock.FLOOR_Y
	if kname == "lift":
		var s := mini(sections(), int(kk("lift") * sections()))
		if s > _sect:
			_sect = s
			var p := Vector2(Dock.TOWER_X + 0.3, Dock.RAIL_Y + 2.0) * M
			game.fx.flash(p, 26.0, 0.2, Pal.ink(0.8, 1.8))
			game.sfx.play("clamp", p, 0.5, 1.2)
	if kname == "deploy":
		# every bay that locks: a snap of light where it squared up
		var nb := int(front() / BAY + 0.001)
		if nb > _last_bay and _flash_t <= 0.0:
			_flash_t = 0.07
			var fx := x_a + nb * BAY
			game.fx.flash(Vector2(fx, F + 0.3) * M, 18.0, 0.18, Pal.ink(0.8, 1.8))
			game.sfx.play("clank", Vector2(fx, F) * M, 0.35, 1.3)
		_last_bay = nb
	if kname == "weld":
		# sparks off the beads being welded in view
		var shown := 0
		for j in modules() + 1:
			var kj := joint_k("weld", j)
			var jx := minf(x_a + j * MOD, x_b)
			if kj > 0.0 and kj < 1.0 and jx > vis.x and jx < vis.y and shown < 5 and randf() < 0.5:
				shown += 1
				var p := Vector2(jx, F + 0.6 * kj) * M
				game.fx.sparks(p, Vector2.from_angle(randf_range(-PI, 0.0)), 2, Pal.ink(1.0, 2.2), 180.0, 0.3, 1.2)
	if kname == "cert" and relaid:
		var e := Pal.ease_io(kk("cert"))
		for key_ in moves:
			var mv: Array = moves[key_]
			_put(key_, mv[0], mv[1], e)
	# the close-up glides to what this step is about
	var f: Array = inset_focus()
	var at: Vector2 = (f[0] as Vector2) * M
	_inset_at = at if _inset_at == Vector2.INF else _inset_at.lerp(at, 1.0 - exp(-6.0 * dt))
	inset_cam.position = _inset_at
	inset_cam.zoom = inset_cam.zoom.lerp(Vector2.ONE * float(f[1]), 1.0 - exp(-4.0 * dt))
	inset_ui.queue_redraw()
	queue_redraw()
	return t >= total()


# skip or finish: everything where it ends up
func finish() -> void:
	if not relaid:
		_relay()
	for key_ in moves:
		_put(key_, moves[key_][0], moves[key_][1], 1.0)


# the berth laid out at its new size; what moves remembers where it was
func _relay() -> void:
	relaid = true
	var old := {"hazard": Dock.ZONES.hazard.pos, "metal": Dock.metal_home}
	for id in Dock.equip_x:
		old["equip:" + id] = Dock.equip_x[id]
	game._relayout_berth()
	moves = {}
	moves["hazard"] = [old.hazard, Dock.ZONES.hazard.pos]
	moves["metal"] = [old.metal, Dock.metal_home]
	for id in Dock.equip_x:
		moves["equip:" + id] = [old.get("equip:" + id, Dock.equip_x[id]), Dock.equip_x[id]]
	for key_ in moves:
		_put(key_, moves[key_][0], moves[key_][1], 0.0)


func _put(key_: String, from, to, e: float) -> void:
	if key_ == "hazard":
		Dock.ZONES.hazard.pos = (from as Vector2).lerp(to, e)
	elif key_ == "metal":
		Dock.metal_x = lerpf(from, to, e)
		dock.mouth_target = Dock.metal_x
	elif key_.begins_with("equip:"):
		var id := key_.substr(6)
		Dock.equip_x[id] = lerpf(from, to, e)
		dock.equip_goal[id] = Dock.equip_x[id]


# ---------------------------------------------------------------- drawing

func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float = 14.0, gap: float = 10.0) -> void:
	var L := a.distance_to(b)
	if L < 0.5:
		return
	var s := 0.0
	var pts := PackedVector2Array()
	while s < L:
		pts.append_array([a.lerp(b, s / L), a.lerp(b, minf(s + dash, L) / L)])
		s += dash + gap
	draw_multiline(pts, col, w)


func _dashed_rect(r: Rect2, col: Color, w: float, dash: float = 14.0, gap: float = 10.0) -> void:
	_dashed(r.position, Vector2(r.end.x, r.position.y), col, w, dash, gap)
	_dashed(Vector2(r.end.x, r.position.y), r.end, col, w, dash, gap)
	_dashed(r.end, Vector2(r.position.x, r.end.y), col, w, dash, gap)
	_dashed(Vector2(r.position.x, r.end.y), r.position, col, w, dash, gap)


func _draw() -> void:
	var F := Dock.FLOOR_Y
	var R := Dock.RAIL_Y
	var kname := key()
	var vis: Vector2 = dock._vis_x() / M
	var blink := 0.5 + 0.5 * sin(t * 6.0)
	var z: float = maxf(0.02, game.cam_zoom())
	var px := 1.0 / z               # one screen pixel in canvas px
	# the incoming ship's outline where it will lie, while the berth grows round it
	if envelope.size != Vector2.ZERO and not passed("haul") and not passed("test"):
		var er := Rect2(envelope.position * M, envelope.size * M)
		_dashed_rect(er, Pal.heat(0.55, 1.2), -1.0, 16.0 * px, 10.0 * px)
	# the tractor field's edge pushed out to the new envelope (until the berth is laid out anew)
	if not relaid:
		var e := Pal.ease_io(kk("iso"))
		var f0 := field(x_a, lift_a, drop_a)
		var f1 := field(x_b, lift_b, drop_b)
		var fr := Rect2(f0.position.lerp(f1.position, e), f0.size.lerp(f1.size, e))
		var fpx := Rect2(fr.position * M, fr.size * M)
		_dashed(fpx.position, Vector2(fpx.end.x, fpx.position.y), Pal.tint(Pal.AIR, 0.55, 1.3), -1.0, 12.0 * px, 9.0 * px)
		_dashed(Vector2(fpx.end.x, fpx.position.y), fpx.end, Pal.tint(Pal.AIR, 0.55, 1.3), -1.0, 12.0 * px, 9.0 * px)
		_dashed(fpx.end, Vector2(fpx.position.x, fpx.end.y), Pal.tint(Pal.AIR, 0.55, 1.3), -1.0, 12.0 * px, 9.0 * px)
		for c in [fpx.position, Vector2(fpx.end.x, fpx.position.y), fpx.end]:
			draw_circle(c, minf(4.0 * px, 12.0), Pal.tint(Pal.AIR, 0.5 + 0.5 * blink, 1.6))
		# amber beacons on the corners that are about to move
		for bp in [Vector2(Dock.TOWER_X + 0.3, R - 0.3), Vector2(x_a, F + 0.3), Vector2(x_a, R - 0.3)]:
			draw_circle(bp * M, minf(4.0 * px, 12.0), Pal.heat(0.4 + 0.6 * blink, 1.8))
	if passed("lift"):
		_draw_lift(R, F, px)
	if passed("drop"):
		_draw_drop(R, F, px, vis)
	if x_b > x_a + 0.1 and not relaid:
		_draw_extension(R, F, vis, blink)
	if relaid:
		_draw_tests(F, vis)


# the climbing frame on the tower and the standard section going into the gap
func _draw_lift(R: float, F: float, px: float) -> void:
	var tx := Dock.TOWER_X
	var lk := kk("lift")
	var n := sections()
	var u := lk * n
	var f := u - floorf(u) if lk < 1.0 else 1.0
	var active := key() == "lift"
	# the sections added so far, ticked off up the tower
	var added := mini(n, int(u + 0.001))
	for s in added:
		var y := R + 2.0 + (s + 0.5) * SECTION
		if y > F:
			break
		draw_rect(Rect2(Vector2(tx + 0.62, y - SECTION * 0.5 + 0.05) * M, Vector2(0.12, SECTION - 0.1) * M), Pal.tint(Pal.FLUID, 0.35, 1.1))
		draw_circle(Vector2(tx + 0.68, y - SECTION * 0.5) * M, 0.08 * M, Pal.tint(Pal.FLUID, 0.9, 1.4))
	if not active:
		return
	# the climbing frame: a collar round the mast under the boom, two jacking cylinders
	var top := R + 0.3
	var stroke := SECTION * Pal.ease_io(clampf(f / 0.6, 0.0, 1.0))
	var foot := top + SECTION + 0.6 - stroke
	var col := Pal.heat(0.85, 1.3)
	draw_rect(Rect2(Vector2(tx - 0.5, top) * M, Vector2(1.6, 0.35) * M), Color(0.09, 0.093, 0.105))
	draw_rect(Rect2(Vector2(tx - 0.5, top) * M, Vector2(1.6, 0.35) * M), col, false, -1.0)
	draw_rect(Rect2(Vector2(tx - 0.5, foot) * M, Vector2(1.6, 0.35) * M), Color(0.09, 0.093, 0.105))
	draw_rect(Rect2(Vector2(tx - 0.5, foot) * M, Vector2(1.6, 0.35) * M), col, false, -1.0)
	for cx: float in [tx - 0.35, tx + 0.95]:
		draw_line(Vector2(cx, foot) * M, Vector2(cx, foot - 1.6) * M, Color(0.12, 0.125, 0.14), 0.14 * M)
		draw_line(Vector2(cx, foot - 1.6) * M, Vector2(cx, top + 0.35) * M, Pal.ink(0.8), -1.0)
	# the gap the stroke opened, and the new section sliding in from the trolley beside it
	if f >= 0.6:
		var g := Pal.ease_io(clampf((f - 0.6) / 0.35, 0.0, 1.0))
		var sx := lerpf(tx - 4.5, tx, g)
		var sy := top + 0.35
		draw_rect(Rect2(Vector2(sx, sy) * M, Vector2(0.6, SECTION) * M), Color(0.07, 0.074, 0.084))
		draw_rect(Rect2(Vector2(sx, sy) * M, Vector2(0.6, SECTION) * M), Pal.tint(Pal.FLUID, 0.9, 1.3), false, -1.0)
		draw_line(Vector2(sx, sy) * M, Vector2(sx + 0.6, sy + SECTION) * M, Pal.ink(0.4), -1.0)
		draw_line(Vector2(sx + 0.6, sy) * M, Vector2(sx, sy + SECTION) * M, Pal.ink(0.4), -1.0)
		draw_line(Vector2(tx - 4.6, sy - 0.2) * M, Vector2(tx, sy - 0.2) * M, Pal.ink(0.35), -1.0)
		if g >= 1.0:
			for by: float in [sy, sy + SECTION]:
				for bx: float in [tx + 0.1, tx + 0.5]:
					draw_circle(Vector2(bx, by) * M, 0.08 * M, Pal.tint(Pal.FLUID, 0.95, 1.6))


# guide columns, pull-type strand jacks under the floor and their anchors below
func _draw_drop(R: float, F: float, px: float, vis: Vector2) -> void:
	var y0 := BASE_Y + drop_a + 0.6
	var anchor := BASE_Y + drop_b + 3.0
	var active := key() == "drop"
	var a := 1.0 if active else clampf(1.0 - (t - float(t0[idx("drop")]) - float(steps[idx("drop")][1])) / 1.5, 0.0, 1.0)
	if a <= 0.0:
		return
	var cycle := fposmod(drop_now() / 0.25, 2.0)
	for x: float in jack_xs():
		if x < vis.x - 2.0 or x > vis.y + 2.0:
			continue
		# the guide column, from where the floor was to past where it goes
		draw_line(Vector2(x - 0.25, y0) * M, Vector2(x - 0.25, anchor) * M, Pal.ink(0.3 * a), -1.0)
		draw_line(Vector2(x + 0.25, y0) * M, Vector2(x + 0.25, anchor) * M, Pal.ink(0.3 * a), -1.0)
		var y := y0
		while y < anchor:
			draw_line(Vector2(x - 0.25, y) * M, Vector2(x + 0.25, y + 1.0) * M, Pal.ink(0.15 * a), -1.0)
			y += 1.0
		# the jack on the floor's underside, its two clamps taking the strand in turns
		var jy := F + 0.62
		draw_rect(Rect2(Vector2(x - 0.4, jy) * M, Vector2(0.8, 0.5) * M), Color(0.1, 0.104, 0.115, a))
		draw_rect(Rect2(Vector2(x - 0.4, jy) * M, Vector2(0.8, 0.5) * M), Pal.heat(0.8 * a, 1.2), false, -1.0)
		draw_circle(Vector2(x - 0.2, jy + 0.1) * M, 0.08 * M, Pal.tint(Pal.FLUID, (0.95 if cycle < 1.0 else 0.25) * a, 1.5))
		draw_circle(Vector2(x + 0.2, jy + 0.4) * M, 0.08 * M, Pal.tint(Pal.FLUID, (0.25 if cycle < 1.0 else 0.95) * a, 1.5))
		# the strand bundle down to the anchor
		for sx: float in [-0.08, 0.0, 0.08]:
			draw_line(Vector2(x + sx, jy + 0.5) * M, Vector2(x + sx, anchor) * M, Pal.ink(0.55 * a), -1.0)
		draw_rect(Rect2(Vector2(x - 0.5, anchor) * M, Vector2(1.0, 0.4) * M), Color(0.09, 0.093, 0.105, a))
		draw_rect(Rect2(Vector2(x - 0.5, anchor) * M, Vector2(1.0, 0.4) * M), Pal.ink(0.5 * a), false, -1.0)


# the new length: tug and cassettes, the truss deploying, latches, bolts and welds
func _draw_extension(R: float, F: float, vis: Vector2, blink: float) -> void:
	var sx := x_a + 0.4
	while sx < minf(x_b, vis.y):
		if sx > vis.x - 1.0:
			draw_line(Vector2(sx, F + 1.6) * M, Vector2(sx + 0.5, F + 1.3) * M, Pal.heat(0.35, 1.1), 2.0)
		sx += 1.2
	var di := idx("deploy")
	# the tug and its train of cassettes
	if passed("haul") and not passed("latch"):
		var cn := cassettes()
		var arrive := Pal.ease_out(kk("haul"))
		var on_deploy := key() == "deploy"
		var leave := Pal.ease_in(clampf(kk("deploy") * 2.0, 0.0, 1.0)) if on_deploy else 0.0
		var gone := int(floor(float(cn) * kk("deploy"))) if on_deploy else 0
		var train_x := lerpf(x_a + 45.0, x_a + 0.2, arrive)
		var tug_x := train_x + cn * 1.3 + 0.2 + leave * 60.0
		var ty := F + 2.4 + leave * 6.0
		for c in range(gone, cn):
			var cx := train_x + c * 1.3
			if c == 0 and on_deploy:
				continue
			draw_rect(Rect2(Vector2(cx, ty - 0.55) * M, Vector2(1.15, 1.1) * M), Color(0.07, 0.073, 0.082))
			draw_rect(Rect2(Vector2(cx, ty - 0.55) * M, Vector2(1.15, 1.1) * M), Pal.ink(0.55), false, 1.2)
			for q in 4:
				draw_line(Vector2(cx + 0.12 + q * 0.27, ty - 0.45) * M, Vector2(cx + 0.12 + q * 0.27, ty + 0.45) * M, Pal.ink(0.2), 1.0)
		dock._tug(Vector2(tug_x, ty) * M, self)
	if di < 0 or not passed("deploy"):
		return
	# the canister at the old end the truss deploys out of
	draw_rect(Rect2(Vector2(x_a + 0.05, F - 0.3) * M, Vector2(1.0, 1.2) * M), Color(0.07, 0.073, 0.082))
	draw_rect(Rect2(Vector2(x_a + 0.05, F - 0.3) * M, Vector2(1.0, 1.2) * M), Pal.ink(0.6), false, 1.4)
	# the deployed truss (floor), the rail girder over it, the bay unfolding at the tip
	var fr := front()
	var full := floorf(fr / BAY) * BAY
	_truss(x_a, x_a + full, F, 0.6, vis)
	var part := fr - full
	if part > 0.01 and fr < x_b - x_a - 0.01:
		var x0 := x_a + full
		var x1 := x_a + fr
		draw_line(Vector2(x0, F) * M, Vector2(x1, F) * M, Pal.ink(0.7), 1.6)
		draw_line(Vector2(x0, F + 0.6) * M, Vector2(x1, F + 0.6) * M, Pal.ink(0.4), 1.2)
		draw_line(Vector2(x0, F) * M, Vector2(x1, F + 0.6) * M, Pal.heat(0.8, 1.5), 1.6)
		draw_line(Vector2(x1, F) * M, Vector2(x1 - (BAY - part) * 0.6, F + 0.6) * M, Pal.heat(0.8, 1.5), 1.6)
	var ra := x_a - 0.9
	var rb := x_b - 0.9
	var rk := ra + (rb - ra) * (fr / maxf(0.01, x_b - x_a))
	_truss(ra, rk, R - 0.4, 0.4, vis)
	draw_line(Vector2(ra, R) * M + Vector2(0, 2), Vector2(rk, R) * M + Vector2(0, 2), Pal.ink(0.5), 2.0)
	# interfaces: latches close, then bolts come up one by one; the back-wall posts rise
	if passed("latch"):
		var low := -5.0 - Dock.LIFT
		for j in modules() + 1:
			var jx := minf(x_a + j * MOD, x_b)
			if jx < vis.x - 2.0 or jx > vis.y + 2.0:
				continue
			var kl := joint_k("latch", j)
			var shut := Pal.ease_out(clampf(kl * 2.0, 0.0, 1.0))
			for cy: float in [F, F + 0.6]:
				var o := (1.0 - shut) * 0.3
				draw_line(Vector2(jx - 0.25 - o, cy - 0.15) * M, Vector2(jx, cy) * M, Pal.ink(0.75), 2.0)
				draw_line(Vector2(jx + 0.25 + o, cy - 0.15) * M, Vector2(jx, cy) * M, Pal.ink(0.75), 2.0)
			var nb := int(clampf(kl * 2.0 - 1.0, 0.0, 1.0) * 4.0 + 0.001)
			for q in 4:
				var bc := Vector2(jx + (0.12 if q % 2 == 0 else -0.12), F + 0.12 + float(q >> 1) * 0.36) * M
				draw_circle(bc, 2.2, Pal.tint(Pal.FLUID, 0.95, 1.4) if q < nb else Pal.ink(0.25))
			var rise := Pal.ease_io(kl)
			draw_line(Vector2(jx, F) * M, Vector2(jx, lerpf(F, low, rise)) * M, Pal.ink(0.12), 2.0)
		# the main interface to the old berth: a flange with its bolt circle
		if x_a > vis.x - 2.0 and x_a < vis.y + 2.0:
			var kl0 := joint_k("latch", 0)
			draw_rect(Rect2(Vector2(x_a - 0.12, F - 0.25) * M, Vector2(0.24, 1.1) * M), Color(0.09, 0.093, 0.105))
			draw_rect(Rect2(Vector2(x_a - 0.12, F - 0.25) * M, Vector2(0.24, 1.1) * M), Pal.ink(0.6), false, 1.2)
			for q in 6:
				var on := kl0 * 6.0 > float(q) + 0.5
				draw_circle(Vector2(x_a, F - 0.15 + q * 0.18) * M, 2.4, Pal.tint(Pal.FLUID, 0.95, 1.5) if on else Pal.ink(0.3))
	# the welds: a white-hot bead runs down each seam and leaves it cooling
	if passed("weld"):
		var wi := idx("weld")
		for j in modules() + 1:
			var jx := minf(x_a + j * MOD, x_b)
			if jx < vis.x - 1.0 or jx > vis.y + 1.0:
				continue
			var kw := joint_k("weld", j)
			if kw <= 0.0:
				continue
			var by := F + 0.6 * kw
			var cool := clampf((t - float(t0[wi]) - (float(j) / float(modules())) * 0.5 * float(steps[wi][1])) / 6.0, 0.0, 1.0)
			draw_line(Vector2(jx + 0.18, F) * M, Vector2(jx + 0.18, by) * M, Pal.heat(0.9 - 0.6 * cool, 1.6 - 0.7 * cool), 2.4)
			if kw < 1.0:
				draw_circle(Vector2(jx + 0.18, by) * M, 4.0, Pal.ink(1.0, 2.6))


# helium in the service lines, the proof load, then the lights coming up
func _draw_tests(F: float, vis: Vector2) -> void:
	var kname := key()
	var xa := x_a if x_b > x_a + 0.1 else Dock.TOWER_X + 1.0
	var ly := F + 0.72
	draw_line(Vector2(xa - 2.0, ly) * M, Vector2(x_b - 1.0, ly) * M, Pal.tint(Pal.AIR, 0.45), 1.6)
	draw_line(Vector2(xa - 2.0, ly + 0.1) * M, Vector2(x_b - 1.0, ly + 0.1) * M, Pal.tint(Pal.FLUID, 0.35), 1.6)
	if kname == "test":
		var x := xa - 2.0 + fposmod(t * 18.0, 3.0)
		while x < minf(x_b - 1.0, vis.y):
			if x > vis.x:
				draw_circle(Vector2(x, ly) * M, 2.6, Pal.tint(Pal.AIR, 0.9, 1.6))
			x += 3.0
		var gc := Vector2(x_b - 1.0, F + 1.4) * M
		draw_arc(gc, 16.0, PI * 0.75, PI * 2.25, 24, Pal.ink(0.6), 1.6)
		var na := PI * 0.75 + PI * 1.5 * (pressure() / (P_PROOF * 1.2))
		draw_line(gc, gc + Vector2.from_angle(na) * 13.0, Pal.tint(Pal.AIR, 0.95, 1.4), 2.0)
		var ma := PI * 0.75 + PI * 1.5 / 1.2
		draw_line(gc + Vector2.from_angle(ma) * 12.0, gc + Vector2.from_angle(ma) * 18.0, Pal.heat(0.9, 1.3), 2.0)
		# the proof load: jacks pressing on each module, the floor's sag drawn 200 × over
		var sag := PackedVector2Array()
		var sx2 := maxf(xa, vis.x)
		while sx2 <= minf(x_b, vis.y):
			var u := fposmod(sx2 - xa, MOD) / MOD
			sag.append(Vector2(sx2, F + 0.62 + deflection() / 1000.0 * 200.0 * sin(u * PI)) * M)
			sx2 += 0.5
		if sag.size() > 1:
			draw_polyline(sag, Pal.heat(0.7, 1.3), 1.4)
		var nm := maxi(1, int((x_b - xa) / MOD))
		var stride := maxi(1, nm / 24)
		for j in range(0, nm, stride):
			var mx := xa + (j + 0.5) * MOD
			if mx > x_b or mx < vis.x or mx > vis.y:
				continue
			var push := 0.25 + 0.06 * sin(t * 9.0 + j)
			draw_line(Vector2(mx, F - 1.2) * M, Vector2(mx, F - 0.05) * M, Pal.heat(0.75, 1.3), 2.2)
			draw_colored_polygon(PackedVector2Array([Vector2(mx, F - 0.02) * M, Vector2(mx - push * 0.6, F - 0.3) * M, Vector2(mx + push * 0.6, F - 0.3) * M]), Pal.heat(0.85, 1.4))
	if kname == "cert":
		# the lights come up along the floor, chasing out to the end
		var e := Pal.ease_io(kk("cert"))
		var lx := xa
		while lx < xa + (x_b - xa) * e:
			if lx > vis.x and lx < vis.y:
				draw_circle(Vector2(lx, F) * M + Vector2(0, -2), 3.0, Pal.heat(0.9, 2.0))
			lx += 2.0


# a plated girder like the berth's own: chords, posts, diagonals (clipped to the view)
func _truss(x0: float, x1: float, y: float, h: float, vis: Vector2) -> void:
	var a := maxf(x0, vis.x - 1.0)
	var b := minf(x1, vis.y + 1.0)
	if b <= a:
		return
	draw_rect(Rect2(Vector2(a, y) * M, Vector2(b - a, h) * M), Color(0.052, 0.055, 0.062))
	draw_rect(Rect2(Vector2(a, y) * M, Vector2(b - a, h * 0.22) * M), Color(0.075, 0.079, 0.088))
	var posts := PackedVector2Array()
	var braces := PackedVector2Array()
	var x := x0 + floorf((a - x0) / h) * h
	var kk_ := int(floorf((a - x0) / h))
	while x < b:
		var nx := minf(x + h, x1)
		posts.append_array([Vector2(x, y) * M, Vector2(x, y + h) * M])
		if kk_ % 2 == 0:
			braces.append_array([Vector2(x, y) * M, Vector2(nx, y + h) * M])
		else:
			braces.append_array([Vector2(x, y + h) * M, Vector2(nx, y) * M])
		x = nx
		kk_ += 1
	if not posts.is_empty():
		draw_multiline(posts, Pal.ink(0.14), 1.0)
		draw_multiline(braces, Pal.ink(0.2), 1.2)
	draw_line(Vector2(a, y) * M, Vector2(b, y) * M, Pal.ink(0.65), 1.6)
	draw_line(Vector2(a, y + h) * M, Vector2(b, y + h) * M, Pal.ink(0.3), 1.2)
