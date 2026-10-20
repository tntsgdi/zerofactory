extends Node2D
# The berth extended in front of the operator (player 2026-10-20: "the berth's
# extension should be a scientific, hard-core animation", not just longer next
# time). Bought at the terminal, the extension is built on site the next time
# the berth is in view (Jev A 0.63 / 0.45), in the order a real in-space truss
# job runs:
#   1 the work zone is closed and the tractor field's edge pushed out past the new end;
#   2 a tug pushes in the folded truss cassettes;
#   3 an articulated truss deploys bay by bay out of the canister at the old end, each
#     bay's battens snapping square and locking before the next one unfolds;
#   4 every module interface is latched, then bolted (M20 grade 10.9, 125 kN preload);
#   5 the seams are electron-beam welded: EB welding needs a vacuum, which the berth is;
#   6 the service lines are proof-pressurised with helium to 1.5 × their working
#     pressure and leak-checked while the new floor carries 1.25 × its design load
#     (deflection drawn 200 × exaggerated against its L/800 limit);
#   7 the berth is re-laid at its new length: the mouths and the furnace roll out to
#     their new places, the field is recalibrated and the lights come up.
# Any key or click skips to the end. Drawn in the dock's own space (px).

const M := 48.0
const MOD := 6.0           # m per truss module (and between two interfaces)
const BAY := 0.6           # m per truss bay
const P_PROOF := 1.80      # MPa: 1.5 × the service lines' 1.2 MPa working pressure
const DEFL := 3.1          # mm measured under proof load at mid-module
const DEFL_MAX := 7.5      # mm: L/800 of a 6 m module

var game
var dock
var x_a := 50.0            # m: the old end
var x_b := 88.0            # m: the new end
var t := 0.0
var steps: Array = []      # [key, seconds]
var t0: Array = []
var relaid := false
var moves := {}            # what rolls to its new place: key -> [from, to]
var _step := -1
var _flash_t := 0.0
var _last_bay := 0


func setup(g, a: float, b: float) -> void:
	game = g
	dock = g.dock
	x_a = a
	x_b = b
	var td := clampf(float(modules()) * 0.55, 4.0, 9.0)
	steps = [["iso", 2.5], ["haul", 3.5], ["deploy", td], ["latch", 3.0], ["weld", 3.5], ["test", 4.0], ["cert", 3.0]]
	var acc := 0.0
	for s in steps:
		t0.append(acc)
		acc += float(s[1])


func total() -> float:
	return float(t0[-1]) + float(steps[-1][1])


func modules() -> int:
	return maxi(1, ceili((x_b - x_a) / MOD - 0.01))


func bays() -> int:
	return maxi(1, int(round((x_b - x_a) / BAY)))


func cassettes() -> int:
	return clampi(modules(), 2, 7)


func current() -> int:
	for i in range(steps.size() - 1, -1, -1):
		if t >= float(t0[i]):
			return i
	return 0


func k(i: int) -> float:
	return clampf((t - float(t0[i])) / float(steps[i][1]), 0.0, 1.0)


func front() -> float:
	return (x_b - x_a) * Pal.ease_io(k(2))


# how far each interface is through latching / welding (j from the old end out)
func joint_k(step: int, j: int) -> float:
	var n := float(modules())
	return clampf(k(step) * 1.6 - float(j) / n * 0.6, 0.0, 1.0)


func pressure() -> float:
	return P_PROOF * Pal.ease_out(clampf(k(5) / 0.6, 0.0, 1.0))


func deflection() -> float:
	return DEFL * Pal.ease_out(clampf(k(5) / 0.6, 0.0, 1.0))


# the live line for the step in hand (the HUD's checklist)
func detail(i: int) -> String:
	match str(steps[i][0]):
		"iso":
			var f := lerpf(x_a + 3.7, x_b + 3.7, Pal.ease_io(k(0)))
			return Txt.t("bb_iso") % [x_a + 3.7, f]
		"haul":
			return Txt.t("bb_haul") % [cassettes(), x_b - x_a]
		"deploy":
			return Txt.t("bb_deploy") % [mini(bays(), int(front() / BAY + 0.001)), bays()]
		"latch":
			var nl := 0
			for j in modules() + 1:
				if joint_k(3, j) >= 1.0:
					nl += 1
			return Txt.t("bb_latch") % [nl, modules() + 1]
		"weld":
			var nw := 0
			for j in modules() + 1:
				if joint_k(4, j) >= 1.0:
					nw += 1
			return Txt.t("bb_weld") % [nw, modules() + 1]
		"test":
			return Txt.t("bb_test") % [pressure(), deflection(), DEFL_MAX]
		"cert":
			return Txt.t("bb_cert") % x_b
	return ""


# where the camera looks, and how close: [centre px, zoom]
func cam(vs: Vector2) -> Array:
	var i := current()
	var lo := x_a - 16.0
	var hi := x_a + 28.0
	if i == 2:
		lo = x_a - 12.0
		hi = x_a + maxf(28.0, front() + 14.0)
	elif i in [3, 4, 5]:
		lo = x_a - 12.0
		hi = x_b + 8.0
	elif i == 6:
		lo = Dock.TOWER_X - 2.0
		hi = x_b + 8.0
	hi = minf(hi, x_b + 8.0)
	var top := Dock.RAIL_Y - 3.0
	var bot := Dock.FLOOR_Y + 6.5
	var z := clampf(minf((vs.x - 720.0) / ((hi - lo) * M), (vs.y - 200.0) / ((bot - top) * M)), 0.02, 1.4)
	# the checklist sits on the left: the work a little right of the middle
	return [Vector2((lo + hi) * 0.5 * M - 330.0 / z, (top + bot) * 0.5 * M), z]


# one frame: true when it is done
func step(dt: float) -> bool:
	t += dt
	var i := current()
	if i != _step:
		_step = i
		var snd: String = ["holo", "launch", "clank", "clamp", "arc", "hiss", "ok"][i]
		game.sfx.play(snd, Vector2.INF, 0.8)
		if i == 5 and not relaid:
			_relay()
	_flash_t -= dt
	var vis: Vector2 = dock._vis_x() / M
	var F := Dock.FLOOR_Y
	if i == 2:
		# every bay that locks: a snap of light where it squared up
		var nb := int(front() / BAY + 0.001)
		if nb > _last_bay and _flash_t <= 0.0:
			_flash_t = 0.07
			var fx := x_a + nb * BAY
			game.fx.flash(Vector2(fx, F + 0.3) * M, 18.0, 0.18, Pal.ink(0.8, 1.8))
			game.sfx.play("clank", Vector2(fx, F) * M, 0.35, 1.3)
		_last_bay = nb
	if i == 4:
		# sparks off the beads being welded in view
		var shown := 0
		for j in modules() + 1:
			var kj := joint_k(4, j)
			var jx := minf(x_a + j * MOD, x_b)
			if kj > 0.0 and kj < 1.0 and jx > vis.x and jx < vis.y and shown < 5 and randf() < 0.5:
				shown += 1
				var p := Vector2(jx, F + 0.6 * kj) * M
				game.fx.sparks(p, Vector2.from_angle(randf_range(-PI, 0.0)), 2, Pal.ink(1.0, 2.2), 180.0, 0.3, 1.2)
	if i == 6 and relaid:
		var e := Pal.ease_io(k(6))
		for key in moves:
			var mv: Array = moves[key]
			_put(key, mv[0], mv[1], e)
	queue_redraw()
	return t >= total()


# skip or finish: everything where it ends up
func finish() -> void:
	if not relaid:
		_relay()
	for key in moves:
		_put(key, moves[key][0], moves[key][1], 1.0)


# the berth re-laid at its new length; what moves remembers where it was
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
	for key in moves:
		_put(key, moves[key][0], moves[key][1], 0.0)


func _put(key: String, from, to, e: float) -> void:
	if key == "hazard":
		Dock.ZONES.hazard.pos = (from as Vector2).lerp(to, e)
	elif key == "metal":
		Dock.metal_x = lerpf(from, to, e)
		dock.mouth_target = Dock.metal_x
	elif key.begins_with("equip:"):
		var id := key.substr(6)
		Dock.equip_x[id] = lerpf(from, to, e)
		dock.equip_goal[id] = Dock.equip_x[id]


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var F := Dock.FLOOR_Y
	var R := Dock.RAIL_Y
	var i := current()
	var vis: Vector2 = dock._vis_x() / M
	var blink := 0.5 + 0.5 * sin(t * 6.0)
	if not relaid:
		# the work zone: amber beacons on the old end, the field's edge pushed out
		var fe := lerpf(x_a + 3.7, x_b + 3.7, Pal.ease_io(k(0)))
		var y := R - 4.0
		while y < F + 3.0:
			draw_line(Vector2(fe, y) * M, Vector2(fe, minf(y + 0.6, F + 3.0)) * M, Pal.tint(Pal.AIR, 0.55, 1.3), 1.6)
			y += 1.1
		for by: float in [R - 0.3, F + 0.3]:
			draw_circle(Vector2(x_a, by) * M, 4.0, Pal.heat(0.4 + 0.6 * blink, 1.8))
		var sx := x_a + 0.4
		while sx < minf(x_b, vis.y):
			if sx > vis.x - 1.0:
				draw_line(Vector2(sx, F + 1.6) * M, Vector2(sx + 0.5, F + 1.3) * M, Pal.heat(0.35, 1.1), 2.0)
			sx += 1.2
		# the tug and its train of cassettes
		if i <= 2:
			var cn := cassettes()
			var arrive := Pal.ease_out(k(1))
			var leave := Pal.ease_in(clampf(k(2) * 2.0, 0.0, 1.0)) if i == 2 else 0.0
			var left := x_a + 0.2
			var gone := int(floor(float(cn) * k(2))) if i == 2 else 0
			var train_x := lerpf(x_a + 45.0, left, arrive)
			var tug_x := train_x + cn * 1.3 + 0.2 + leave * 60.0
			var ty := F + 2.4 + leave * 6.0
			if i >= 1:
				for c in range(gone, cn):
					var cx := train_x + c * 1.3
					if c == 0 and i == 2:
						continue
					draw_rect(Rect2(Vector2(cx, ty - 0.55) * M, Vector2(1.15, 1.1) * M), Color(0.07, 0.073, 0.082))
					draw_rect(Rect2(Vector2(cx, ty - 0.55) * M, Vector2(1.15, 1.1) * M), Pal.ink(0.55), false, 1.2)
					for q in 4:
						draw_line(Vector2(cx + 0.12 + q * 0.27, ty - 0.45) * M, Vector2(cx + 0.12 + q * 0.27, ty + 0.45) * M, Pal.ink(0.2), 1.0)
				dock._tug(Vector2(tug_x, ty) * M, self)
		# the canister at the old end the truss deploys out of
		if i >= 2:
			draw_rect(Rect2(Vector2(x_a + 0.05, F - 0.3) * M, Vector2(1.0, 1.2) * M), Color(0.07, 0.073, 0.082))
			draw_rect(Rect2(Vector2(x_a + 0.05, F - 0.3) * M, Vector2(1.0, 1.2) * M), Pal.ink(0.6), false, 1.4)
		# the deployed truss (floor), the rail girder over it, the bay unfolding at the tip
		if i >= 2:
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
		if i >= 3:
			var low := -5.0 - Dock.LIFT
			for j in modules() + 1:
				var jx := minf(x_a + j * MOD, x_b)
				if jx < vis.x - 2.0 or jx > vis.y + 2.0:
					continue
				var kl := joint_k(3, j)
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
				var kl0 := joint_k(3, 0)
				draw_rect(Rect2(Vector2(x_a - 0.12, F - 0.25) * M, Vector2(0.24, 1.1) * M), Color(0.09, 0.093, 0.105))
				draw_rect(Rect2(Vector2(x_a - 0.12, F - 0.25) * M, Vector2(0.24, 1.1) * M), Pal.ink(0.6), false, 1.2)
				for q in 6:
					var on := kl0 * 6.0 > float(q) + 0.5
					draw_circle(Vector2(x_a, F - 0.15 + q * 0.18) * M, 2.4, Pal.tint(Pal.FLUID, 0.95, 1.5) if on else Pal.ink(0.3))
		# the welds: a white-hot bead runs down each seam and leaves it cooling
		if i >= 4:
			for j in modules() + 1:
				var jx := minf(x_a + j * MOD, x_b)
				if jx < vis.x - 1.0 or jx > vis.y + 1.0:
					continue
				var kw := joint_k(4, j)
				if kw <= 0.0:
					continue
				var by := F + 0.6 * kw
				var cool := clampf((t - float(t0[4]) - (float(j) / float(modules())) * 0.5 * float(steps[4][1])) / 6.0, 0.0, 1.0)
				draw_line(Vector2(jx + 0.18, F) * M, Vector2(jx + 0.18, by) * M, Pal.heat(0.9 - 0.6 * cool, 1.6 - 0.7 * cool), 2.4)
				if kw < 1.0:
					draw_circle(Vector2(jx + 0.18, by) * M, 4.0, Pal.ink(1.0, 2.6))
	else:
		# helium in the service lines: pulses running out to the new end, the gauge at it
		var ly := F + 0.72
		var ph := fposmod(t * 18.0, 3.0)
		var x := x_a - 2.0 + ph
		draw_line(Vector2(x_a - 2.0, ly) * M, Vector2(x_b - 1.0, ly) * M, Pal.tint(Pal.AIR, 0.45), 1.6)
		draw_line(Vector2(x_a - 2.0, ly + 0.1) * M, Vector2(x_b - 1.0, ly + 0.1) * M, Pal.tint(Pal.FLUID, 0.35), 1.6)
		if i == 5:
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
			var sx2 := maxf(x_a, vis.x)
			while sx2 <= minf(x_b, vis.y):
				var u := fposmod(sx2 - x_a, MOD) / MOD
				sag.append(Vector2(sx2, F + 0.62 + deflection() / 1000.0 * 200.0 * sin(u * PI)) * M)
				sx2 += 0.5
			if sag.size() > 1:
				draw_polyline(sag, Pal.heat(0.7, 1.3), 1.4)
			for j in modules():
				var mx := x_a + (j + 0.5) * MOD
				if mx > x_b or mx < vis.x or mx > vis.y:
					continue
				var push := 0.25 + 0.06 * sin(t * 9.0 + j)
				draw_line(Vector2(mx, F - 1.2) * M, Vector2(mx, F - 0.05) * M, Pal.heat(0.75, 1.3), 2.2)
				draw_colored_polygon(PackedVector2Array([Vector2(mx, F - 0.02) * M, Vector2(mx - push * 0.6, F - 0.3) * M, Vector2(mx + push * 0.6, F - 0.3) * M]), Pal.heat(0.85, 1.4))
		if i == 6:
			# the lights come up along the new floor, chasing out to the new end
			var e := Pal.ease_io(k(6))
			var lx := x_a
			while lx < x_a + (x_b - x_a) * e:
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
	var kk := int(floorf((a - x0) / h))
	while x < b:
		var nx := minf(x + h, x1)
		posts.append_array([Vector2(x, y) * M, Vector2(x, y + h) * M])
		if kk % 2 == 0:
			braces.append_array([Vector2(x, y) * M, Vector2(nx, y + h) * M])
		else:
			braces.append_array([Vector2(x, y + h) * M, Vector2(nx, y) * M])
		x = nx
		kk += 1
	if not posts.is_empty():
		draw_multiline(posts, Pal.ink(0.14), 1.0)
		draw_multiline(braces, Pal.ink(0.2), 1.2)
	draw_line(Vector2(a, y) * M, Vector2(b, y) * M, Pal.ink(0.65), 1.6)
	draw_line(Vector2(a, y + h) * M, Vector2(b, y + h) * M, Pal.ink(0.3), 1.2)
